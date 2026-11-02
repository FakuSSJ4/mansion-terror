--!strict
-- Entrada a la mansión: al empezar la partida los jugadores aparecen en el patio, la puerta principal
-- se abre, entran caminando y se cierra de un portazo detrás de ellos. Ya no hay vuelta atrás: la
-- salida es el túnel del sótano. Los clientes ponen la cámara (ver Controllers/Entrance).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Systems = script.Parent
local Dust = require(Systems:WaitForChild("Dust"))
local GrandHall = require(Systems:WaitForChild("GrandHall"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local Entrance = {}

-- Cuánto se espera a que aparezcan los personajes antes de empezar igual.
local SPAWN_WAIT = 3

local entranceId = 0

local function rootsReady(players: { Player }): boolean
	for _, player in players do
		if not Vitality.rootOf(player) then
			return false
		end
	end
	return true
end

function Entrance.start(refs: Mansion.MansionRefs)
	local door = refs.doors.front
	local doorAt = Vector3.new(GrandHall.CenterX, 0, GrandHall.Z0)

	Round.Started:Connect(function(players: { Player })
		entranceId += 1
		local id = entranceId
		task.spawn(function()
			local deadline = os.clock() + SPAWN_WAIT
			while not rootsReady(players) and os.clock() < deadline do
				task.wait(0.1)
			end
			if id ~= entranceId then
				return
			end

			-- Cada uno camina a su lugar adentro, repartidos a lo ancho del hall.
			local targets: { [Player]: Vector3 } = {}
			for index, player in players do
				local offset = ((index - 1) % 4 - 1.5) * 3
				targets[player] = Vector3.new(GrandHall.CenterX + offset, 0, GrandHall.Z0 + 14)
				player:SetAttribute("Entering", true)
				Remotes.get("Entrance"):FireClient(player, {
					door = doorAt,
					target = targets[player],
					seconds = Config.EntranceSeconds,
				})
			end

			task.wait(Config.EntranceOpenAt)
			if id ~= entranceId then
				return
			end
			Mansion.setDoorUnlocked(door, true)

			task.wait(Config.EntranceSlamAt - Config.EntranceOpenAt)
			if id ~= entranceId then
				return
			end
			-- El que se quedó atrás aparece adentro: nadie queda del lado de afuera.
			for player, target in targets do
				local root = Vitality.rootOf(player)
				if root and root.Position.Z < GrandHall.Z0 + 3 then
					root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0))
				end
			end
			Mansion.slamDoor(door)
			Dust.burst(Vector3.new(doorAt.X, 14.5, doorAt.Z + 0.8), Vector3.new(12, 0, 0), 40)

			task.wait(Config.EntranceSeconds - Config.EntranceSlamAt)
			for player in targets do
				player:SetAttribute("Entering", false)
			end
		end)
	end)
end

return Entrance
