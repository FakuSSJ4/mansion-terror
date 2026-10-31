--!strict
-- Atajos de QA. Solo existen en Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Systems = script.Parent
local Items = require(Systems:WaitForChild("Items"))
local Killer = require(Systems:WaitForChild("Killer"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))
local Weather = require(Systems:WaitForChild("Weather"))

-- Paradas de la tecla T: alce, rinoceronte, puma, teclado y umbral del primer piso.
local TOUR_STOPS: { [any]: Vector3 } = {
	tour1 = Vector3.new(94, 10, 25),
	tour2 = Vector3.new(146, 10, 25),
	tour3 = Vector3.new(68, 24, 80),
	tour4 = Vector3.new(173.5, 8, 93.5),
	tour5 = Vector3.new(16, 26, 0),
	tour6 = Vector3.new(88, 27, 8),
}

local DebugTools = {}

function DebugTools.start(refs: Mansion.MansionRefs)
	if not RunService:IsStudio() then
		return
	end
	Remotes.get("Debug").OnServerEvent:Connect(function(player, command)
		if command == "devmode" then
			local on = not player:GetAttribute("GodMode")
			player:SetAttribute("GodMode", on)
			Vitality.applyDevCollision(player)
			if on then
				for n = 1, Config.KeyCount do
					Round.addKey(player, n)
				end
			end
			Remotes.get("Notify"):FireClient(
				player,
				if on
					then "Modo desarrollador: W A S D vuela, Espacio sube, Ctrl baja, doble Espacio deja de volar"
					else "Modo desarrollador apagado"
			)
		elseif command == "keys" then
			for n = 1, Config.KeyCount do
				Round.addKey(player, n)
			end
		elseif command == "books" then
			for n = 1, Config.BookCount do
				Round.addBook(player, `book{n}`)
			end
		elseif command == "next" then
			local root = Vitality.rootOf(player)
			if not root then
				return
			end
			local current = Vitality.getRoom(player)
			local n = current and tonumber(string.match(current, "room(%d+)")) or 0
			local target = if current == "attic"
				then "hall"
				elseif n >= 12 then "attic"
				else `room{n + 1}`
			root.CFrame = CFrame.new(refs.rooms[target].center + Vector3.new(4, 4, 4))
		elseif command == "stairs" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(10, 4, -56)
			end
		elseif command == "library" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(-32, 4, 12)
			end
		elseif command == "pedestal" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(refs.taserPedestal.Position + Vector3.new(0, 2.5, -4))
			end
		elseif TOUR_STOPS[command] then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(TOUR_STOPS[command])
			end
		elseif command == "gear" then
			Items.debugGive(player)
		elseif command == "status" then
			print(`[QA] {Killer.debugStatus()} jugador={Vitality.getRoom(player)}`)
		elseif command == "summon" then
			local room = Vitality.getRoom(player)
			if room then
				Killer.debugTeleport(1, refs.rooms[room].center + Vector3.new(10, 0, 10))
			end
		elseif command == "summon2" then
			local room = Vitality.getRoom(player)
			if room then
				Killer.debugTeleport(2, refs.rooms[room].center + Vector3.new(10, 0, 10))
			end
		elseif command == "summon3" then
			local room = Vitality.getRoom(player)
			if room then
				Killer.debugTeleport(3, refs.rooms[room].center + Vector3.new(10, 0, 10))
			end
		elseif command == "lightning" then
			Weather.strike()
		elseif command == "damage" then
			Vitality.damage(player, Config.Killers.main.damage)
		end
	end)
end

return DebugTools
