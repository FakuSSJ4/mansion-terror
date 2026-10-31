--!strict
-- Cuando morís y queda alguien vivo: la cámara sigue a otro jugador; clic cambia de jugador.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Spectate = require(Shared:WaitForChild("Rules"):WaitForChild("Spectate"))

local Spectator = {}

local function aliveOthers(): { Player }
	local alive = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			other ~= Players.LocalPlayer
			and humanoid
			and humanoid.Health > 0
			and not other:GetAttribute("Spectating")
		then
			table.insert(alive, other)
		end
	end
	return alive
end

function Spectator.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Espectador"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local banner = Instance.new("TextLabel")
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 40)
	banner.Size = UDim2.new(0.8, 0, 0, 60)
	banner.Font = Enum.Font.Garamond
	banner.TextSize = 28
	banner.TextColor3 = Color3.fromRGB(225, 215, 195)
	banner.TextStrokeTransparency = 0.5
	banner.Visible = false
	banner.Parent = gui

	local target: Player? = nil

	local function watch(nextTarget: Player?)
		target = nextTarget
		local character = nextTarget and nextTarget.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if nextTarget and humanoid then
			local camera = workspace.CurrentCamera
			camera.CameraSubject = humanoid
			banner.Text = `Moriste. Estás mirando a {nextTarget.DisplayName} (clic para cambiar)`
		end
	end

	local function isSpectating(): boolean
		return player:GetAttribute("Spectating") == true
	end

	player:GetAttributeChangedSignal("Spectating"):Connect(function()
		local on = isSpectating()
		banner.Visible = on
		player.CameraMode = if on then Enum.CameraMode.Classic else Enum.CameraMode.LockFirstPerson
		if on then
			watch(Spectate.nextTarget(aliveOthers(), nil))
		else
			target = nil
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed
			and isSpectating()
			and input.UserInputType == Enum.UserInputType.MouseButton1
		then
			watch(Spectate.nextTarget(aliveOthers(), target))
		end
	end)

	-- Si el jugador que mirás muere, pasa solo al siguiente.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if isSpectating() then
				local alive = aliveOthers()
				if not target or not table.find(alive, target) then
					watch(Spectate.nextTarget(alive, nil))
				end
			end
		end
	end)
end

return Spectator
