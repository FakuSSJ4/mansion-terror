--!strict
-- Valida y aplica los disparos de taser. El cliente solo pide disparar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Systems = script.Parent
local Killer = require(Systems:WaitForChild("Killer"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local FIRE_COOLDOWN = 0.5

local TaserSystem = {}

function TaserSystem.start()
	local lastFire: { [Player]: number } = {}
	Remotes.get("FireTaser").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastFire[player] or 0) < FIRE_COOLDOWN then
			return
		end
		lastFire[player] = now

		local charges = (player:GetAttribute("TaserCharges") :: number?) or 0
		local root = Vitality.rootOf(player)
		local killerPosition = Killer.getPosition()
		if charges <= 0 or not root or not killerPosition then
			return
		end
		if not Killer.isVisibleFrom(player, Config.TaserRange) then
			Remotes.get("Notify"):FireClient(player, "Está muy lejos")
			return
		end
		-- Durante el aturdimiento o la inmunidad no se gasta la carga.
		if not Killer.stun(now) then
			Remotes.get("Notify"):FireClient(player, "El taser no le hace nada todavía")
			return
		end
		player:SetAttribute("TaserCharges", charges - 1)
		Remotes.get("TaserFx"):FireAllClients(root.Position, killerPosition)
	end)
end

return TaserSystem
