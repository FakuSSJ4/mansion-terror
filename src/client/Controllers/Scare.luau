--!strict
-- Susto al ver al asesino de cerca: sonido fuerte y sacudida de cámara.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local SHAKE_SECONDS = 0.6
local SHAKE_STRENGTH = 0.5

local Scare = {}

local function canSee(camera: Camera, target: Vector3, ignore: { Instance }): boolean
	local _, onScreen = camera:WorldToViewportPoint(target)
	if not onScreen then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	-- Con este grupo el rayo ignora la barrera invisible de los refugios.
	params.CollisionGroup = "Default"
	local origin = camera.CFrame.Position
	return workspace:Raycast(origin, target - origin, params) == nil
end

function Scare.start()
	local player = Players.LocalPlayer
	local scream = Instance.new("Sound")
	scream.SoundId = Sounds.Scare
	scream.Volume = 1.5
	scream.Parent = SoundService

	local armed = true
	local lastSeen = -math.huge
	local shakeUntil = 0
	local clock = 0

	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local now = os.clock()
		if now < shakeUntil then
			local strength = SHAKE_STRENGTH * (shakeUntil - now) / SHAKE_SECONDS
			camera.CFrame *= CFrame.new(
				(math.random() - 0.5) * strength,
				(math.random() - 0.5) * strength,
				0
			)
		end

		clock += dt
		if clock < 0.2 then
			return
		end
		clock = 0

		local character = player.Character
		if not character then
			return
		end
		local seen = false
		for _, killer in CollectionService:GetTagged("Killer") do
			local root = (killer :: Model).PrimaryPart
			if
				root
				and (root.Position - camera.CFrame.Position).Magnitude <= Config.ScareRange
				and canSee(camera, root.Position, { killer, character })
			then
				seen = true
				break
			end
		end
		if seen then
			lastSeen = now
			if armed then
				armed = false
				scream:Play()
				shakeUntil = now + SHAKE_SECONDS
			end
		elseif now - lastSeen >= Config.ScareRearmSeconds then
			armed = true
		end
	end)
end

return Scare
