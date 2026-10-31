--!strict
-- Vuelo del modo desarrollador: hacia donde mira la cámara. Solo funciona con GodMode, en Studio.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DevFlight = {}

function DevFlight.start()
	if not RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	local wasFlying = false

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root then
			return
		end
		local flying = player:GetAttribute("GodMode") == true
		if flying ~= wasFlying then
			wasFlying = flying
			humanoid.PlatformStand = flying
		end
		if not flying then
			return
		end

		local view = workspace.CurrentCamera.CFrame
		local move = Vector3.zero
		local function add(key: Enum.KeyCode, direction: Vector3)
			if UserInputService:IsKeyDown(key) then
				move += direction
			end
		end
		add(Enum.KeyCode.W, view.LookVector)
		add(Enum.KeyCode.S, -view.LookVector)
		add(Enum.KeyCode.D, view.RightVector)
		add(Enum.KeyCode.A, -view.RightVector)
		add(Enum.KeyCode.Space, Vector3.yAxis)
		add(Enum.KeyCode.LeftControl, -Vector3.yAxis)

		root.AssemblyLinearVelocity = if move.Magnitude > 0
			then move.Unit * Config.DevFlySpeed
			else Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(
			root.Position,
			root.Position + Vector3.new(view.LookVector.X, 0, view.LookVector.Z)
		)
	end)
end

return DevFlight
