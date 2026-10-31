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
end

function Round.getProgress(): Progress.State
	return progress
end

function Round.addKey(player: Player, n: number)
	if Progress.addKey(progress, n) then
		notifyAll(
			`{player.DisplayName} encontró la llave {n} ({progress.keyCount}/{Config.KeyCount})`
		)
		publish()
	end
end

function Round.addBook(player: Player, id: string)
	if Progress.addBook(progress, id) then
		notifyAll(
			`{player.DisplayName} encontró un escrito ({progress.bookCount}/{Config.BookCount})`
		)
		if Progress.isExitOpen(progress) then
			notifyAll("¡La salida se puede abrir!")
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
	task.delay(Config.VictorySeconds, Round.reset)
end

local function setupDoors()
	for key, door in refs.doors do
		local position = door.closedCFrame.Position
		door.prompt.Triggered:Connect(function(player)
			if door.unlocked or not Vitality.canReach(player, position) then
				return
			end
			if key == "exit" then
				if Progress.isExitOpen(progress) then
					Mansion.setDoorUnlocked(door, true)
					notifyAll("¡La salida está abierta! Corré")
				else
					local missing = Config.BookCount - progress.bookCount
					Remotes.get("Notify"):FireClient(player, `Faltan {missing} escritos`)
				end
				return
			end
			local room = tonumber(string.match(key, "%d+")) :: number
			if Progress.isDoorOpen(progress, room) then
				Mansion.setDoorUnlocked(door, true)
			else
				Remotes.get("Notify"):FireClient(player, `Necesitás la llave {room - 1}`)
			end
		end)
	end

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
	Items.setupTaserPedestal(refs.taserPedestal)
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
