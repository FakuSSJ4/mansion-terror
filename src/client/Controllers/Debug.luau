--!strict
-- Atajos de QA, solo en Studio: 5 modo desarrollador, K llaves, J pergaminos, = pieza siguiente, 4 rayo, H daño, 6 estado del asesino, 7 traerlo, 8 linterna y escalera, 9 ir a la gran escalera, 0 girar la vista.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local KEYS = {
	[Enum.KeyCode.Five] = "devmode",
	[Enum.KeyCode.K] = "keys",
	[Enum.KeyCode.J] = "books",
	[Enum.KeyCode.Equals] = "next",
	[Enum.KeyCode.Four] = "lightning",
	[Enum.KeyCode.H] = "damage",
	[Enum.KeyCode.Six] = "status",
	[Enum.KeyCode.Seven] = "summon",
	[Enum.KeyCode.Eight] = "gear",
	[Enum.KeyCode.Nine] = "stairs",
	[Enum.KeyCode.V] = "escape",
	[Enum.KeyCode.F] = "play",
	[Enum.KeyCode.R] = "lobbyTour",
	[Enum.KeyCode.KeypadPlus] = "gems",
	[Enum.KeyCode.KeypadMultiply] = "buy",
	[Enum.KeyCode.Home] = "aerial",
	[Enum.KeyCode.PageDown] = "soundCheck",
	[Enum.KeyCode.Insert] = "linkTest",
	[Enum.KeyCode.KeypadZero] = "wolfRoom",
	[Enum.KeyCode.KeypadOne] = "vault",
	[Enum.KeyCode.F8] = "cure",
	[Enum.KeyCode.Backspace] = "cinema",
	[Enum.KeyCode.KeypadPeriod] = "diffMenu",
	[Enum.KeyCode.KeypadDivide] = "coneChase",
	[Enum.KeyCode.KeypadMinus] = "shop",
	[Enum.KeyCode.N] = "lobby",
	[Enum.KeyCode.U] = "nextAnimal",
	[Enum.KeyCode.Y] = "nextHead",
	[Enum.KeyCode.G] = "viewArcade",
	[Enum.KeyCode.Z] = "viewBar",
	[Enum.KeyCode.X] = "viewSeal",
	[Enum.KeyCode.P] = "pedestal",
	[Enum.KeyCode.L] = "library",
	[Enum.KeyCode.M] = "summon2",
	[Enum.KeyCode.B] = "summon3",
	[Enum.KeyCode.KeypadTwo] = "cinema",
}

-- Hacia dónde mirar tras U (animal), Y (cabeza) y G (arcades).
local VIEW_AIMS = {
	nextAnimal = Vector3.new(1, -0.12, 0),
	nextHead = Vector3.new(1, 0.05, 1),
	viewArcade = Vector3.new(0, -0.12, -1),
	viewBar = Vector3.new(-1, -0.1, 0),
}

local Debug = {}

local function aim(direction: Vector3)
	local camera = workspace.CurrentCamera
	local position = camera.CFrame.Position
	camera.CFrame = CFrame.lookAt(position, position + direction)
end

-- Hacia dónde mirar en cada parada de la tecla T: alce, rinoceronte, puma, teclado, umbral, cama,
-- sótano largo, mesa de carnicero, sala de juegos y bar.
local TOUR_AIMS = {
	Vector3.new(1, 0.03, -1),
	Vector3.new(-1, 0.03, -1),
	Vector3.xAxis,
	Vector3.new(1, -0.8, 1),
	Vector3.new(1, -0.25, 0),
	Vector3.new(1, -0.45, 1),
	Vector3.new(1, -0.08, 0),
	Vector3.new(1, -0.3, -0.8),
	Vector3.new(-0.6, -0.2, 1),
	Vector3.new(-1, -0.3, -0.5),
	-Vector3.xAxis,
	Vector3.new(0, 0.25, -1),
	Vector3.new(0, 0.2, 1),
	-Vector3.zAxis,
}
local tourStop = 0

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
			elseif
				command == "viewSeal"
				or command == "wolfRoom"
				or command == "vault"
				or command == "cure"
				or command == "lobbyTour"
				or command == "shop"
				or command == "aerial"
			then
				task.delay(0.3, function()
					local look = Players.LocalPlayer:GetAttribute("QAAim")
					if typeof(look) == "Vector3" then
						aim(look)
					end
				end)
			elseif VIEW_AIMS[command] then
				task.delay(0.3, aim, VIEW_AIMS[command])
			end
		elseif input.KeyCode == Enum.KeyCode.T then
			tourStop = tourStop % #TOUR_AIMS + 1
			Remotes.get("Debug"):FireServer(`tour{tourStop}`)
			task.delay(0.3, aim, TOUR_AIMS[tourStop])
		elseif input.KeyCode == Enum.KeyCode.Zero then
			local look = workspace.CurrentCamera.CFrame.LookVector
			aim(Vector3.new(-look.Z, 0, look.X))
		end
	end)
end

return Debug
