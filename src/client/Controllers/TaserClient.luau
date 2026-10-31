--!strict
-- Clic para disparar el taser y efecto del rayo eléctrico.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local TaserClient = {}

function TaserClient.start()
	local player = Players.LocalPlayer
	local zap = Instance.new("Sound")
	zap.SoundId = Sounds.Taser
	zap.Parent = SoundService

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local charges = (player:GetAttribute("TaserCharges") :: number?) or 0
		if charges > 0 then
			Remotes.get("FireTaser"):FireServer()
		end
	end)

	Remotes.get("TaserFx").OnClientEvent:Connect(function(from: Vector3, to: Vector3)
		zap:Play()
		local bolt = Instance.new("Part")
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.Material = Enum.Material.Neon
		bolt.Color = Color3.fromRGB(150, 210, 255)
		bolt.Size = Vector3.new(0.12, 0.12, (to - from).Magnitude)
		bolt.CFrame = CFrame.lookAt((from + to) / 2, to)
		bolt.Parent = workspace
		Debris:AddItem(bolt, 0.15)
	end)
end

return TaserClient
