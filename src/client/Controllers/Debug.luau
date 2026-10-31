--!strict
-- Atajos de QA, solo en Studio: 1 modo desarrollador, K llaves, 2 pergaminos, 3 pieza siguiente, 4 rayo, 5 daño, 6 estado del asesino, 7 traerlo, 8 linterna y escalera, 9 ir a la gran escalera, 0 girar la vista.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local KEYS = {
	[Enum.KeyCode.One] = "devmode",
	[Enum.KeyCode.K] = "keys",
	[Enum.KeyCode.Two] = "books",
	[Enum.KeyCode.Three] = "next",
	[Enum.KeyCode.Four] = "lightning",
	[Enum.KeyCode.Five] = "damage",
	[Enum.KeyCode.Six] = "status",
	[Enum.KeyCode.Seven] = "summon",
	[Enum.KeyCode.Eight] = "gear",
	[Enum.KeyCode.Nine] = "stairs",
	[Enum.KeyCode.P] = "pedestal",
	[Enum.KeyCode.L] = "library",
}

local Debug = {}

local function aim(direction: Vector3)
	local camera = workspace.CurrentCamera
	local position = camera.CFrame.Position
	camera.CFrame = CFrame.lookAt(position, position + direction)
end

function Debug.start()
	if not RunService:IsStudio() then
		return
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local command = KEYS[input.KeyCode]
		if command then
			Remotes.get("Debug"):FireServer(command)
			if command == "stairs" or command == "pedestal" or command == "library" then
				task.delay(0.3, aim, Vector3.zAxis)
			end
		elseif input.KeyCode == Enum.KeyCode.Zero then
			local look = workspace.CurrentCamera.CFrame.LookVector
			aim(Vector3.new(-look.Z, 0, look.X))
		end
	end)
end

return Debug
