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
local Profile = require(Systems:WaitForChild("Profile"))
local Vitality = require(Systems:WaitForChild("Vitality"))
local Weather = require(Systems:WaitForChild("Weather"))

local Round = {}

local wonEvent = Instance.new("BindableEvent")
local lostEvent = Instance.new("BindableEvent")
Round.Lost = lostEvent.Event
local escapingEvent = Instance.new("BindableEvent")
Round.Escaping = escapingEvent.Event
local resetEvent = Instance.new("BindableEvent")
Round.Won = wonEvent.Event
local startedEvent = Instance.new("BindableEvent")
-- Se dispara con los jugadores de la partida cuando ya se los mandó a la mansión.
Round.Started = startedEvent.Event
Round.Reset = resetEvent.Event

local refs: Mansion.MansionRefs
local progress = Progress.new(Config.BookCount)
local phase = "Lobby"
local difficulty = "normal"
local difficultyChosen = false
-- Cambia en cada reinicio para que una fuga vieja no gane la partida nueva.
local escapeId = 0
-- Jugadores de la partida en curso; los demás están en el lobby.
local participants: { [Player]: boolean } = {}
local lobbySpawn: SpawnLocation? = nil
-- Códigos de las habitaciones de esta partida (tres cifras) y cuáles ya se encontraron.
local codes: { number } = {}
local foundCodes: { [number]: boolean } = {}
local lastGuess: { [Player]: number } = {}

-- Avisa solo a los que están jugando.
local function notifyAll(text: string)
	for player in participants do
		Remotes.get("Notify"):FireClient(player, text)
	end
end

function Round.participants(): { Player }
	local list = {}
	for player in participants do
		table.insert(list, player)
	end
	return list
end

function Round.isRunning(): boolean
	return phase ~= "Lobby"
end

function Round.setLobbySpawn(spawn: SpawnLocation)
	lobbySpawn = spawn
end

local function publish()
	workspace:SetAttribute("Keys", progress.keyCount)
	workspace:SetAttribute("Books", progress.bookCount)
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute(
		"ExitOpen",
		refs ~= nil and refs.doors.exit ~= nil and refs.doors.exit.unlocked
	)
	workspace:SetAttribute("Difficulty", difficulty)
	workspace:SetAttribute("DifficultyChosen", difficultyChosen)
	for n = 1, Config.KeyCount do
		workspace:SetAttribute(`Key{n}`, progress.keys[n] == true)
	end
	for n = 1, Config.BookCount do
		-- El código solo se publica cuando alguien encontró su nota.
		workspace:SetAttribute(`Code{n}`, if foundCodes[n] then codes[n] else nil)
	end
end

function Round.addCode(player: Player, n: number)
	if foundCodes[n] then
		return
	end
	foundCodes[n] = true
	notifyAll(`{player.DisplayName} encontró el código de la Caja fuerte {n}: {codes[n]}`)
	publish()
end

-- Solo para los atajos de QA: el código de una habitación de esta partida.
function Round.debugCode(n: number): number?
	return codes[n]
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
			notifyAll("Llevá los pergaminos a la estatua de lobo, al fondo del sótano")
		end
		publish()
	end
end

local function spawnRoundItems()
	Items.spawnAll(
		refs,
		{ onKey = Round.addKey, onBook = Round.addBook, onCode = Round.addCode },
		Loot.counts(difficulty, Config)
	)
end

-- Conecta las puertas nuevas de cada partida (se arma más abajo).
local bindDoors: () -> ()

-- Deja la mansión lista para una partida nueva: sortea todo, reparte los objetos y reinicia el
-- progreso del equipo.
local function prepare()
	progress = Progress.new(Config.BookCount)
	escapeId += 1
	-- Un código distinto de tres cifras para cada habitación.
	codes, foundCodes = {}, {}
	for n = 1, Config.BookCount do
		local code = math.random(100, 999)
		while table.find(codes, code) do
			code = math.random(100, 999)
		end
		codes[n] = code
	end
	-- Primero se sortea todo lo de la partida (puertas con llave, muebles, trofeos): las llaves y
	-- los objetos se esconden según esa distribución.
	Mansion.rerollRound()
	bindDoors()
	for _, door in refs.doors do
		Mansion.setDoorUnlocked(door, false)
	end
	Mansion.setDrawerOpen(false)
	Blood.clear()
	spawnRoundItems()
	publish()
	resetEvent:Fire()
end

-- Manda a un jugador al lobby o a la mansión y le recarga el personaje (pierde lo que llevaba).
local function sendTo(player: Player, toLobby: boolean, index: number?)
	player:SetAttribute("InLobby", toLobby)
	player:SetAttribute("InTutorial", false)
	player:SetAttribute("Entering", false)
	if toLobby then
		player.RespawnLocation = lobbySpawn
	else
		local spawns = refs.spawns
		player.RespawnLocation = spawns[((index or 1) - 1) % #spawns + 1]
	end
	Vitality.resetPlayer(player)
end

-- Arranca la partida con estos jugadores y esa dificultad. Devuelve false si ya hay una en curso.
function Round.startMatch(players: { Player }, chosen: string): boolean
	if phase ~= "Lobby" or #players == 0 then
		return false
	end
	difficulty = if Loot.isValid(chosen) then chosen else "normal"
	difficultyChosen = true
	participants = {}
	for _, player in players do
		participants[player] = true
	end
	phase = "Playing"
	prepare()
	Weather.beginMatch()
	for index, player in players do
		sendTo(player, false, index)
	end
	startedEvent:Fire(players)
	return true
end

-- Termina la partida: todos vuelven al lobby y no queda nadie jugando.
local function endMatch()
	Weather.endMatch()
	phase = "Lobby"
	escapeId += 1
	local leaving = participants
	participants = {}
	publish()
	for player in leaving do
		if player.Parent then
			sendTo(player, true)
		end
	end
end

local function win()
	if phase ~= "Playing" and phase ~= "Escaping" then
		return
	end
	phase = "Won"
	-- Ganar en Normal acerca cada jugador a desbloquear Pesadilla.
	if difficulty == "normal" then
		for player in participants do
			Profile.addNormalWin(player)
		end
	end
	publish()
	wonEvent:Fire()
	task.delay(Config.VictorySeconds, function()
		-- Si el servidor quedó vacío ya se reinició; no borrar la partida nueva.
		if phase == "Won" then
			endMatch()
		end
	end)
end

-- Cruzar la puerta principal abierta arranca la secuencia de fuga; al terminar se gana.
local function beginEscape(player: Player)
	if phase ~= "Playing" then
		return
	end
	phase = "Escaping"
	escapeId += 1
	local id = escapeId
	player:SetAttribute("Escaping", true)
	publish()
	escapingEvent:Fire(player)
	task.delay(Config.EscapeSeconds, function()
		if phase == "Escaping" and id == escapeId then
			win()
		end
	end)
end

-- Solo para el atajo de QA que prueba la fuga sin juntar todo.
Round.beginEscape = beginEscape

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
			endMatch()
		end
	end)
end

-- Las puertas de los pasillos se rehacen en cada partida: se conectan una sola vez cada una.
local boundDoors: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

bindDoors = function()
	for key, door in refs.doors do
		if boundDoors[door] then
			continue
		end
		boundDoors[door] = true
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
			-- Habitaciones con código: el cliente abre el teclado y contesta por "Keypad".
			local vaultIndex = tonumber(string.match(key, "^vault(%d+)$"))
			if vaultIndex then
				Remotes.get("Keypad"):FireClient(player, vaultIndex)
				return
			end
			if Progress.isDoorOpen(progress, key, Config) then
				Mansion.setDoorUnlocked(door, true)
			else
				local name = Config.KeyColors[Config.DoorKeys[key]].name
				Remotes.get("Notify"):FireClient(player, `Necesitás la llave {name}`)
			end
		end)
	end
end

-- El altar y la zona de salida no se rehacen: se conectan una vez.
local function setupFixed()
	Remotes.get("Keypad").OnServerEvent:Connect(function(player, index: any, guess: any)
		if typeof(index) ~= "number" or typeof(guess) ~= "number" or phase ~= "Playing" then
			return
		end
		local vault = refs.vaults[index]
		-- Un intento por segundo por jugador, y solo desde cerca de la puerta.
		if
			not vault
			or vault.door.unlocked
			or os.clock() - (lastGuess[player] or 0) < 1
			or not Vitality.canReach(player, vault.door.position)
		then
			return
		end
		lastGuess[player] = os.clock()
		if guess == codes[index] then
			Mansion.setDoorUnlocked(vault.door, true)
			Remotes.get("Notify"):FireClient(player, `Caja fuerte {index} abierta`)
		else
			Remotes.get("Notify"):FireClient(player, "Código incorrecto")
		end
	end)

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
			beginEscape(player)
		end
	end)
end

function Round.start(mansionRefs: Mansion.MansionRefs)
	refs = mansionRefs
	bindDoors()
	setupFixed()
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

	Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
		task.defer(function()
			if phase == "Lobby" then
				return
			end
			if next(participants) == nil then
				endMatch()
			elseif not Vitality.anyAlive() then
				lose()
			end
		end)
	end)
end

return Round
