--!strict
-- Secuencia de fuga: el jugador cruza la puerta del túnel, sube corriendo la escalera hasta el bosque
-- y al asesino principal le cierran la puerta en la cara. El servidor mueve al asesino y la puerta; los
-- clientes ponen la cámara y el jugador que escapa se mueve solo en su cliente (ver Controllers/Escape).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local EscapePath = require(Shared:WaitForChild("Rules"):WaitForChild("EscapePath"))

local Systems = script.Parent
local Dust = require(Systems:WaitForChild("Dust"))
local Killer = require(Systems:WaitForChild("Killer"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local Escape = {}

-- Un poco sobre el piso para que el cuerpo del asesino no lo atraviese.
local FLOOR = 0.2

-- Recto por el túnel, escalera arriba y hasta el bosque. Todo sigue el eje X.
local function tunnelPath(start: Vector3, tunnel: Mansion.Tunnel): { EscapePath.Point }
	local z = tunnel.door.Z
	return {
		{ start.X, start.Z },
		{ tunnel.door.X - 2, z },
		{ tunnel.door.X + 6, z },
		{ tunnel.stairStart.X, z },
		{ tunnel.exit.X, z },
		-- Sigue por el camino de tierra hasta perderse en la niebla.
		{ tunnel.exit.X + 75, z },
	}
end

-- Los puntos van al nivel del piso del sótano hasta la escalera; el cliente solo usa X y Z, y el
-- último punto (el bosque) marca dónde queda la cámara al final.
local function toVectors(points: { EscapePath.Point }, floorY: number): { Vector3 }
	local list = {}
	for index, point in points do
		local y = if index == #points then FLOOR else floorY + FLOOR
		table.insert(list, Vector3.new(point[1], y, point[2]))
	end
	return list
end

function Escape.start(refs: Mansion.MansionRefs)
	local door = refs.doors.exit
	local tunnel = refs.tunnel
	local doorPosition = tunnel.door

	Round.Escaping:Connect(function(player: Player)
		local root = Vitality.rootOf(player)
		if not root then
			return
		end
		local path = tunnelPath(root.Position, tunnel)
		-- Solo lo ven los que están jugando; los del lobby siguen en lo suyo.
		local payload = {
			escapee = player,
			door = doorPosition,
			out = tunnel.out,
			exit = tunnel.exit,
			path = toVectors(path, tunnel.floorY),
			pathLength = EscapePath.length(path),
		}
		for _, viewer in Round.participants() do
			Remotes.get("Escape"):FireClient(viewer, payload)
		end

		-- El asesino sale del fondo de la sala y frena contra la puerta ya cerrada.
		local from = Vector3.new(doorPosition.X - 40, tunnel.floorY + FLOOR, doorPosition.Z)
		local stop = Vector3.new(doorPosition.X - 7, tunnel.floorY + FLOOR, doorPosition.Z)
		local lintel = doorPosition + Vector3.new(-0.8, 12.5, 0)
		Killer.playEscape(
			from,
			stop,
			Config.EscapeKillerStart,
			Config.EscapeKillerSpeed,
			Config.EscapeStrikeEvery,
			function()
				Mansion.rattleDoor(door, 0.45)
				Dust.burst(lintel, Vector3.new(0, 0, 12), 12)
			end,
			tunnel.floorY
		)
		task.delay(Config.EscapeSlamAt, function()
			if player:GetAttribute("Escaping") then
				Mansion.slamDoor(door)
				Dust.burst(lintel, Vector3.new(0, 0, 12), 40)
			end
		end)
	end)
end

return Escape
