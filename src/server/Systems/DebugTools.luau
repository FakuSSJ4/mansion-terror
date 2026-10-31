--!strict
-- Atajos de QA. Solo existen en Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Systems = script.Parent
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
		if command == "keys" then
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
			local target = if n >= 12 then "exit" else `room{n + 1}`
			root.CFrame = CFrame.new(refs.rooms[target].center + Vector3.new(0, 4, 0))
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
