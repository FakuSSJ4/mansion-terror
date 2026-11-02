--!strict
-- Piezas comunes de las secuencias de cámara (entrada a la mansión y fuga): suavizado, sonidos sueltos,
-- barras negras de cine con un velo, y encender o apagar los controles del jugador.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Cinematic = {}

local player = Players.LocalPlayer

function Cinematic.ease(alpha: number): number
	local a = math.clamp(alpha, 0, 1)
	return a * a * (3 - 2 * a)
end

function Cinematic.play(id: string, volume: number?)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 1
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

function Cinematic.playLater(delay: number, id: string, volume: number?)
	task.delay(delay, Cinematic.play, id, volume)
end

-- Barras negras de cine y velo negro (para entrar y salir en fundido).
function Cinematic.overlay(name: string): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.fromScale(1, 0)
		bar.Parent = gui
		TweenService:Create(bar, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {
			Size = UDim2.fromScale(1, 0.11),
		}):Play()
	end
	local veil = Instance.new("Frame")
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 5
	veil.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, veil
end

function Cinematic.setControls(enabled: boolean)
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return
	end
	pcall(function()
		local controls = (require(module :: ModuleScript) :: any):GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

return Cinematic
