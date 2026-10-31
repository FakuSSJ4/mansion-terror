--!strict
-- Atajos de QA, solo en Studio: 1 llaves, 2 escritos, 3 pieza siguiente, 4 rayo, 5 daño, 6 estado del asesino, 7 traerlo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local KEYS = {
	[Enum.KeyCode.One] = "keys",
	[Enum.KeyCode.Two] = "books",
	[Enum.KeyCode.Three] = "next",
	[Enum.KeyCode.Four] = "lightning",
	[Enum.KeyCode.Five] = "damage",
	[Enum.KeyCode.Six] = "status",
	[Enum.KeyCode.Seven] = "summon",
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
