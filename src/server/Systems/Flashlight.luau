--!strict
-- Linterna: consumo de batería y luz en la cabeza para que la vean los demás jugadores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Battery = require(Shared:WaitForChild("Rules"):WaitForChild("Battery"))

local Flashlight = {}

local function headLight(player: Player): SpotLight?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local light = head:FindFirstChild("LuzLinterna") :: SpotLight?
	if not light then
		local created = Instance.new("SpotLight")
		created.Name = "LuzLinterna"
		created.Range = 50
		created.Angle = 55
		created.Brightness = 2
		created.Shadows = true
		created.Parent = head
		return created
	end
	return light
end

function Flashlight.start()
	local cooldown: { [Player]: number } = {}
	Remotes.get("Flashlight").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (cooldown[player] or 0) < 0.2 or not player:GetAttribute("HasFlashlight") then
			return
		end
		cooldown[player] = now
		local isOn = player:GetAttribute("FlashlightOn") == true
		local charged = ((player:GetAttribute("Battery") :: number?) or 0) > 0
		player:SetAttribute("FlashlightOn", not isOn and charged)
		if not isOn and not charged then
			Remotes.get("Notify"):FireClient(player, "La linterna no tiene batería")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cooldown[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		local seconds = elapsed
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local on = player:GetAttribute("FlashlightOn") == true
			if on then
				local level =
					Battery.drain((player:GetAttribute("Battery") :: number?) or 0, seconds, Config)
				player:SetAttribute("Battery", level)
				if level <= 0 then
					on = false
					player:SetAttribute("FlashlightOn", false)
					Remotes.get("Notify"):FireClient(player, "Se agotó la batería")
				end
			end
			local light = headLight(player)
			if light then
				light.Enabled = on
			end
		end
	end)
end

return Flashlight
