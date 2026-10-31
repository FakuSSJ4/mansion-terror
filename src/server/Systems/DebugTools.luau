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

local DebugTools = {}

function DebugTools.start(refs: Mansion.MansionRefs)
	if not RunService:IsStudio() then
		return
	end
	Remotes.get("Debug").OnServerEvent:Connect(function(player, command)
		if command == "devmode" then
			local on = not player:GetAttribute("GodMode")
			player:SetAttribute("GodMode", on)
			Remotes.get("Notify"):FireClient(
				player,
				if on
					then "Modo desarrollador: el asesino no te daña"
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
				root.CFrame = CFrame.new(refs.rooms.hall.center + Vector3.new(-20, 4, -24))
			end
		elseif command == "pedestal" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(refs.taserPedestal.Position + Vector3.new(0, 2.5, -4))
			end
		elseif command == "gear" then
			Items.debugGive(player)
		elseif command == "status" then
			print(`[QA] {Killer.debugStatus()} jugador={Vitality.getRoom(player)}`)
		elseif command == "summon" then
			local room = Vitality.getRoom(player)
			if room then
				Killer.debugTeleport(refs.rooms[room].center + Vector3.new(10, 0, 10))
			end
		elseif command == "lightning" then
			Weather.strike()
		elseif command == "damage" then
			Vitality.damage(player, Config.KillerDamage)
		end
	end)
end

return DebugTools
