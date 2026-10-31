--!strict
-- Estado de la partida: progreso del equipo, puertas, victoria y reinicio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Progress = require(Shared:WaitForChild("Rules"):WaitForChild("Progress"))

local Systems = script.Parent
local Items = require(Systems:WaitForChild("Items"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local Round = {}

local wonEvent = Instance.new("BindableEvent")
local resetEvent = Instance.new("BindableEvent")
Round.Won = wonEvent.Event
Round.Reset = resetEvent.Event

local refs: Mansion.MansionRefs
local progress = Progress.new(Config.BookCount)
local phase = "Playing"

local function notifyAll(text: string)
	Remotes.get("Notify"):FireAllClients(text)
end

local function publish()
	workspace:SetAttribute("Keys", progress.keyCount)
	workspace:SetAttribute("Books", progress.bookCount)
	workspace:SetAttribute("Phase", phase)
	for n = 1, Config.KeyCount do
		workspace:SetAttribute(`Key{n}`, progress.keys[n] == true)
	end
end

function Round.getProgress(): Progress.State
	return progress
end

function Round.addKey(player: Player, n: number)
	if Progress.addKey(progress, n) then
		notifyAll(`{player.DisplayName} encontró la llave {Config.KeyColors[n].name}`)
		publish()
	end
end

function Round.addBook(player: Player, id: string)
	if Progress.addBook(progress, id) then
		notifyAll(
			`{player.DisplayName} encontró un pergamino ({progress.bookCount}/{Config.BookCount})`
		)
		if Progress.isExitOpen(progress) then
			notifyAll("Llevá los pergaminos a la estatua de lobo del hall")
		end
		publish()
	end
end

local function spawnRoundItems()
	Items.spawnAll(refs, { onKey = Round.addKey, onBook = Round.addBook })
end

function Round.reset()
	progress = Progress.new(Config.BookCount)
	phase = "Playing"
	for _, door in refs.doors do
		Mansion.setDoorUnlocked(door, false)
	end
	Mansion.setDrawerOpen(false)
	spawnRoundItems()
	publish()
	resetEvent:Fire()
	for _, player in Players:GetPlayers() do
		Vitality.resetPlayer(player)
	end
end

local function win()
	if phase ~= "Playing" then
		return
	end
	phase = "Won"
	publish()
	wonEvent:Fire()
	task.delay(Config.VictorySeconds, function()
		-- Si el servidor quedó vacío ya se reinició; no borrar la partida nueva.
		if phase == "Won" then
			Round.reset()
		end
	end)
end

local function setupDoors()
	for key, door in refs.doors do
		local position = door.closedCFrame.Position
		door.prompt.Triggered:Connect(function(player)
			if door.unlocked or not Vitality.canReach(player, position) then
				return
			end
			if key == "exit" then
				if player:GetAttribute("HasGoldKey") then
					player:SetAttribute("HasGoldKey", false)
					Mansion.setDoorUnlocked(door, true)
					notifyAll("¡La salida está abierta! Corré")
				else
					Remotes.get("Notify"):FireClient(player, "Necesitás la llave dorada del lobo")
				end
				return
			end
			local room = tonumber(string.match(key, "%d+")) :: number
			if Progress.isDoorOpen(progress, room) then
				Mansion.setDoorUnlocked(door, true)
			else
				local name = Config.KeyColors[room - 1].name
				Remotes.get("Notify"):FireClient(player, `Necesitás la llave {name}`)
			end
		end)
	end

	refs.altar.prompt.Triggered:Connect(function(player)
		if not Vitality.canReach(player, refs.altar.position) then
			return
		end
		if not Progress.isExitOpen(progress) then
			local missing = Config.BookCount - progress.bookCount
			Remotes.get("Notify"):FireClient(player, `Faltan {missing} pergaminos`)
			return
		end
		Mansion.setDrawerOpen(true)
		Items.spawnGoldKey(refs.altar.keySpot)
		notifyAll("El cajón se abrió: agarrá la llave dorada")
	end)

	refs.exitZone.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and refs.doors.exit.unlocked and Vitality.rootOf(player) then
			win()
		end
	end)
end

function Round.start(mansionRefs: Mansion.MansionRefs)
	refs = mansionRefs
	setupDoors()
	Items.start(refs)
	spawnRoundItems()
	publish()

	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if #Players:GetPlayers() == 0 then
				Round.reset()
			end
		end)
	end)
end

return Round
