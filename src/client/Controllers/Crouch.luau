--!strict
-- Agacharse con C (o Ctrl izquierdo): se alterna. Agachado sos más bajo, más lento y no corrés.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Crouch = {}

function Crouch.start()
	local player = Players.LocalPlayer
	local crouching = false

	local function set(wants: boolean)
		if crouching == wants then
			return
		end
		crouching = wants
		Remotes.get("Crouch"):FireServer(wants)
	end

	ContextActionService:BindAction("Crouch", function(_, state)
		if state == Enum.UserInputState.Begin then
			set(not crouching)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C, Enum.KeyCode.LeftControl)

	-- Si el servidor lo para (murió, escapa, cinemática), se alinea con él.
	player:GetAttributeChangedSignal("Crouching"):Connect(function()
		crouching = player:GetAttribute("Crouching") == true
	end)
end

return Crouch
