--!strict
-- Efectos locales: parpadeo de velas, lluvia y rayos.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local LightFade = require(Shared:WaitForChild("Rules"):WaitForChild("LightFade"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local RAIN_VOLUME_HALL = 0.5
local RAIN_VOLUME_INSIDE = 0.2

local Ambience = {}

local function makeSound(id: string, looped: boolean, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = looped
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local function flash()
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Brightness = 0.9
	correction.Contrast = 0.3
	correction.Parent = Lighting
	local outdoor = Lighting.OutdoorAmbient
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 200, 240)
	task.delay(0.12, function()
		correction.Brightness = 0.1
	end)
	task.delay(0.22, function()
		correction.Brightness = 0.7
	end)
	task.delay(0.35, function()
		Lighting.OutdoorAmbient = outdoor
		local fade =
			TweenService:Create(correction, TweenInfo.new(0.5), { Brightness = 0, Contrast = 0 })
		fade:Play()
		fade.Completed:Once(function()
			correction:Destroy()
		end)
	end)
end

function Ambience.start()
	local rain = makeSound(Sounds.Rain, true, RAIN_VOLUME_HALL)
	rain:Play()
	local thunder = makeSound(Sounds.Thunder, false, 1)
	local crow = makeSound(Sounds.Crow, false, 0.7)
	Remotes.get("Crow").OnClientEvent:Connect(function()
		crow:Play()
	end)

	Remotes.get("Lightning").OnClientEvent:Connect(function()
		flash()
		task.delay(0.6, function()
			thunder:Play()
		end)
	end)

	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("Room"):Connect(function()
		rain.Volume = if player:GetAttribute("Room") == "hall"
			then RAIN_VOLUME_HALL
			else RAIN_VOLUME_INSIDE
	end)

	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		if clock < 0.07 then
			return
		end
		clock = 0
		local eye = workspace.CurrentCamera.CFrame.Position
		for _, flame in CollectionService:GetTagged("CandleFlame") do
			local light = flame:FindFirstChildOfClass("PointLight")
			if light then
				local flicker = 0.12 + math.noise(flame.Position.X, os.clock() * 3) * 0.07
				if flame:GetAttribute("NoFade") then
					light.Brightness = flicker * 2.5
				else
					light.Brightness = flicker
						* LightFade.factor((flame.Position - eye).Magnitude, Config)
				end
			end
		end
	end)
end

return Ambience
