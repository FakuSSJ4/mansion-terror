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

local RAIN_VOLUME_HALL = 0.13
local RAIN_VOLUME_INSIDE = 0.048
local RAIN_VOLUME_LOBBY = 0.03
local STEPS_VOLUME_WALK = 0.12
local STEPS_VOLUME_RUN = 0.65
local DEV_LIGHT = Color3.fromRGB(170, 170, 170)

local Ambience = {}

local function makeSound(id: string, looped: boolean, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = looped
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

-- Un rayo ilumina todo, también adentro: sube la luz ambiente y la exposición un instante, con dos
-- destellos seguidos, y vuelve a la penumbra.
local function flash()
	local correction = Instance.new("ColorCorrectionEffect")
	correction.Brightness = 0.6
	correction.Contrast = 0.3
	correction.Parent = Lighting
	local ambient, outdoor = Lighting.Ambient, Lighting.OutdoorAmbient
	local exposure, brightness = Lighting.ExposureCompensation, Lighting.Brightness
	local function lit(amount: number)
		Lighting.Ambient = ambient:Lerp(Color3.fromRGB(215, 222, 255), amount)
		Lighting.OutdoorAmbient = outdoor:Lerp(Color3.fromRGB(215, 222, 255), amount)
		Lighting.ExposureCompensation = exposure + amount * 1.4
		Lighting.Brightness = brightness + amount * 2
		correction.Brightness = amount * 0.55
	end
	lit(1)
	task.delay(0.12, function()
		lit(0.15)
	end)
	task.delay(0.22, function()
		lit(0.85)
	end)
	task.delay(0.45, function()
		local fade =
			TweenService:Create(correction, TweenInfo.new(0.7), { Brightness = 0, Contrast = 0 })
		fade:Play()
		fade.Completed:Once(function()
			correction:Destroy()
		end)
		for step = 1, 14 do
			task.delay(step * 0.05, function()
				lit(0.85 * (1 - step / 14))
			end)
		end
		task.delay(0.75, function()
			Lighting.Ambient, Lighting.OutdoorAmbient = ambient, outdoor
			Lighting.ExposureCompensation, Lighting.Brightness = exposure, brightness
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
		if Players.LocalPlayer:GetAttribute("InLobby") then
			return
		end
		flash()
		task.delay(0.6, function()
			thunder:Play()
		end)
	end)

	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("Room"):Connect(function()
		-- En el patio del lobby la lluvia es apenas un fondo: se escucha la música.
		local room = player:GetAttribute("Room")
		rain.Volume = if room == "lobby"
			then RAIN_VOLUME_LOBBY
			elseif room == "hall" then RAIN_VOLUME_HALL
			else RAIN_VOLUME_INSIDE
	end)

	-- En modo desarrollador se ve todo iluminado; al salir vuelve la luz que había.
	local normalLight: { Ambient: Color3, OutdoorAmbient: Color3 }? = nil
	local function applyDevLight()
		local dev = player:GetAttribute("GodMode") == true
		if dev and not normalLight then
			normalLight = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
			Lighting.Ambient = DEV_LIGHT
			Lighting.OutdoorAmbient = DEV_LIGHT
		elseif not dev and normalLight then
			Lighting.Ambient = normalLight.Ambient
			Lighting.OutdoorAmbient = normalLight.OutdoorAmbient
			normalLight = nil
		end
	end
	player:GetAttributeChangedSignal("GodMode"):Connect(applyDevLight)
	applyDevLight()

	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		if clock < 0.07 then
			return
		end
		clock = 0
		-- Roblox crea el sonido de pasos "Running" en cada personaje; caminando suena mucho menos.
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local steps = root and root:FindFirstChild("Running")
			if steps and steps:IsA("Sound") then
				steps.Volume = if other:GetAttribute("Running") == true
					then STEPS_VOLUME_RUN
					else STEPS_VOLUME_WALK
			end
		end
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
