--!strict
-- Lógica del lobby: los círculos donde se arma cada partida y la tienda. En cada círculo se elige
-- la dificultad y cuántos jugadores se esperan; al pisarlo arranca una cuenta regresiva de 10 s
-- (se cancela si se bajan todos) y la partida empieza para los que estén arriba.
-- Por ahora hay una sola mansión por servidor: mientras hay una partida en curso, los demás
-- círculos esperan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Systems = script.Parent
local LobbyMap = require(Systems:WaitForChild("LobbyMap"))
local Profile = require(Systems:WaitForChild("Profile"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local Lobby = {}

-- Segundos desde que alguien pisa el círculo hasta que arranca la partida.
local COUNTDOWN = 10
local MAX_PLAYERS = 3
local TICK = 0.25

type Slot = {
	pad: LobbyMap.Pad,
	difficulty: string,
	needed: number,
	-- os.clock() en que arranca la partida, o nil si no hay cuenta regresiva.
	startsAt: number?,
}

local function difficultyName(id: string): string
	return Config.Difficulties[id].name
end

local function notify(player: Player, text: string)
	Remotes.get("Notify"):FireClient(player, text)
end

-- Los que están parados sobre el círculo: en el lobby, vivos y con el tutorial ya cerrado.
local function standingOn(pad: LobbyMap.Pad): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = Vitality.rootOf(player)
		if root and player:GetAttribute("InLobby") and not player:GetAttribute("InTutorial") then
			local offset = root.Position - pad.center
			if
				Vector3.new(offset.X, 0, offset.Z).Magnitude <= pad.radius
				and math.abs(offset.Y) < 8
			then
				table.insert(list, player)
			end
		end
	end
	return list
end

function Lobby.start(refs: LobbyMap.Refs)
	local slots: { Slot } = {}
	for _, pad in refs.pads do
		table.insert(slots, { pad = pad, difficulty = "normal", needed = 1, startsAt = nil })
	end

	for index, slot in slots do
		slot.pad.difficultyPrompt.Triggered:Connect(function(player)
			if slot.startsAt or Round.isRunning() then
				notify(player, "Ahora no se puede cambiar")
				return
			end
			-- El cliente muestra Fácil, Normal y Pesadilla (bloqueada hasta ganar 3 veces en Normal).
			Remotes.get("SetDifficulty"):FireClient(
				player,
				index,
				slot.difficulty,
				Profile.nightmareUnlocked(player),
				(player:GetAttribute("NormalWins") :: number?) or 0
			)
		end)
		slot.pad.playersPrompt.Triggered:Connect(function(player)
			if slot.startsAt or Round.isRunning() then
				notify(player, "Ahora no se puede cambiar")
				return
			end
			-- El cliente muestra las opciones y contesta por el remoto "Lobby".
			Remotes.get("Lobby"):FireClient(player, index, slot.needed, MAX_PLAYERS)
		end)
	end

	Remotes.get("SetDifficulty").OnServerEvent:Connect(function(player, index: any, choice: any)
		if typeof(index) ~= "number" or typeof(choice) ~= "string" then
			return
		end
		local slot = slots[index]
		if not slot or not Config.Difficulties[choice] then
			return
		end
		local root = Vitality.rootOf(player)
		if not root or (root.Position - slot.pad.center).Magnitude > 30 then
			return
		end
		if slot.startsAt or Round.isRunning() then
			notify(player, "Ahora no se puede cambiar")
			return
		end
		if choice == "nightmare" and not Profile.nightmareUnlocked(player) then
			notify(
				player,
				`Pesadilla se desbloquea ganando {Config.NightmareUnlockWins} veces en Normal`
			)
			return
		end
		slot.difficulty = choice
		notify(player, `Partida {index}: dificultad {difficultyName(choice)}`)
	end)

	Remotes.get("Lobby").OnServerEvent:Connect(function(player, index: any, wanted: any)
		if typeof(index) ~= "number" or typeof(wanted) ~= "number" then
			return
		end
		local slot = slots[index]
		if not slot or wanted % 1 ~= 0 or wanted < 1 or wanted > MAX_PLAYERS then
			return
		end
		local root = Vitality.rootOf(player)
		if not root or (root.Position - slot.pad.center).Magnitude > 30 then
			return
		end
		if slot.startsAt or Round.isRunning() then
			notify(player, "Ahora no se puede cambiar")
			return
		end
		slot.needed = wanted
		notify(player, `Partida {index}: {wanted} {if wanted == 1 then "jugador" else "jugadores"}`)
	end)

	for _, stall in refs.stalls do
		local item = Config.Shop[stall.id]
		stall.label.Text = `{item.name}\n{item.description}\n{item.price} gemas`
		stall.prompt.Triggered:Connect(function(player)
			local problem = Profile.buy(player, stall.id)
			notify(player, problem or `Compraste: {item.name}`)
		end)
	end

	-- Quién ve la cuenta regresiva en pantalla, para borrársela cuando se baja del círculo.
	local counting: { [Player]: boolean } = {}

	local function refresh()
		local running = Round.isRunning()
		local now = os.clock()
		local launched = false
		local shown: { [Player]: boolean } = {}
		for _, slot in slots do
			local inside = standingOn(slot.pad)
			local count = #inside
			local status
			if running then
				slot.startsAt = nil
				status = "En partida: esperá a que termine"
			elseif launched then
				slot.startsAt = nil
				status = "Esperando"
			elseif count == 0 then
				-- Se bajaron todos: la cuenta se cancela.
				slot.startsAt = nil
				status = "Parate en el círculo"
			else
				-- Al pisar el círculo arranca la cuenta; empiezan los que estén arriba al llegar a cero.
				if not slot.startsAt then
					slot.startsAt = now + COUNTDOWN
				end
				local left = math.ceil(slot.startsAt - now)
				if left <= 0 then
					slot.startsAt = nil
					launched = true
					status = "¡Empieza!"
					Round.startMatch(inside, slot.difficulty)
				else
					status = `Empieza en {left}`
					-- Cada uno ve la cuenta en grande, del color de su círculo.
					for _, player in inside do
						shown[player] = true
						player:SetAttribute("LobbyCountdown", left)
						player:SetAttribute("LobbyCountdownColor", slot.pad.color)
					end
				end
			end
			slot.pad.label.Text =
				`Partida {table.find(slots, slot)}\n{count}/{slot.needed} jugadores · {difficultyName(
					slot.difficulty
				)}\n{status}`
		end
		for player in counting do
			if not shown[player] then
				player:SetAttribute("LobbyCountdown", nil)
			end
		end
		counting = shown
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(refresh)
			if not ok and RunService:IsStudio() then
				warn(`[Lobby] {err}`)
			end
		end
	end)
end

return Lobby
