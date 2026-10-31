--!strict
-- Atajos de QA, solo en Studio: F1 llaves, F2 escritos, F3 pieza siguiente, F4 rayo, F6 daño.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local KEYS = {
	[Enum.KeyCode.F1] = "keys",
	[Enum.KeyCode.F2] = "books",
	[Enum.KeyCode.F3] = "next",
	[Enum.KeyCode.F4] = "lightning",
	[Enum.KeyCode.F6] = "damage",
}

local Debug = {}

function Debug.start()
	if not RunService:IsStudio() then
		return
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		local command = KEYS[input.KeyCode]
		if command and not processed then
			Remotes.get("Debug"):FireServer(command)
		end
	end)
end

return Debug
