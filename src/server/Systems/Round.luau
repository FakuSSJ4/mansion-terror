--!strict
-- Estado de la partida: progreso del equipo, puertas, victoria y reinicio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Loot = require(Shared:WaitForChild("Rules"):WaitForChild("Loot"))
local Progress = require(Shared:WaitForChild("Rules"):WaitForChild("Progress"))

local Systems = script.Parent
local Blood = require(Systems:WaitForChild("Blood"))
local Items = require(Systems:WaitForChild("Items"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local Round = {}

local wonEvent = Instance.new("BindableEvent")
local lostEvent = Instance.new("BindableEvent")
Round.Lost = lostEvent.Event
local resetEvent = Instance.new("BindableEvent")
Round.Won = wonEvent.Event
Round.Reset = resetEvent.Event

local refs: Mansion.MansionRefs
local progress = Progress.new(Config.BookCount)
local phase = "Playing"
local difficulty = "normal"
local difficultyChosen = false

local function notifyAll(text: string)
	Remotes.get("Notify"):FireAllClients(text)
end

local function publish()
	workspace:SetAttribute("Keys", progress.keyCount)
	workspace:SetAttribute("Books", progress.bookCount)
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("Difficulty", difficulty)
	workspace:SetAttribute("DifficultyChosen", difficultyChosen)
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
	Items.spawnAll(
		refs,
		{ onKey = Round.addKey, onBook = Round.addBook },
		Loot.counts(difficulty, Config)
	)
end

function Round.reset()
	progress = Progress.new(Config.BookCount)
	phase = "Playing"
	for _, door in refs.doors do
		Mansion.setDoorUnlocked(door, false)
	end
	Mansion.setDrawerOpen(false)
	Blood.clear()
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

-- Una muerte a manos del asesino reinicia la partida para todos.
local function lose()
	if phase ~= "Playing" then
		return
	end
	phase = "Dead"
	publish()
	lostEvent:Fire()
	task.delay(Config.DeathScreenSeconds, function()
		if phase == "Dead" then
			Round.reset()
		end
	end)
end

-- La elige el primero que sale del tutorial y vale hasta que se cierra el servidor.
local function setupDifficulty()
	Remotes.get("SetDifficulty").OnServerEvent:Connect(function(_, choice)
		if difficultyChosen or not Loot.isValid(choice) then
			return
		end
		difficultyChosen = true
		difficulty = choice
		spawnRoundItems()
		publish()
	end)
end

local function setupDoors()
	for key, door in refs.doors do
		local position = door.position
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
	setupDifficulty()
	-- La partida sigue mientras quede alguien vivo; el que murió mira a los demás.
	Vitality.Killed:Connect(function(player: Player)
		if Vitality.anyAlive() then
			notifyAll(`{player.DisplayName} murió. Sus cosas quedaron donde cayó`)
		else
			lose()
		end
	end)
	Items.start(refs)
	spawnRoundItems()
	publish()

	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if #Players:GetPlayers() == 0 then
				Round.reset()
			elseif not Vitality.anyAlive() then
				lose()
			end
		end)
	end)
end

return Round
