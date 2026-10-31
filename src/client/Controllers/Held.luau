--!strict
-- Lo que se ve en la mano en primera persona y el haz de la linterna, que sigue a la cámara.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Held = {}

local function handPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Metal
	p.Parent = parent
	return p
end

function Held.start()
	local player = Players.LocalPlayer
	local holder = Instance.new("Folder")
	holder.Name = "EnLaMano"
	holder.Parent = workspace

	local taser =
		handPart("Taser", Vector3.new(0.25, 0.3, 0.9), Color3.fromRGB(230, 190, 40), holder)
	local flashlight =
		handPart("Linterna", Vector3.new(0.25, 0.25, 1), Color3.fromRGB(60, 60, 66), holder)
	local beam = Instance.new("SpotLight")
	beam.Range = 50
	beam.Angle = 55
	beam.Brightness = 2
	beam.Face = Enum.NormalId.Front
	beam.Shadows = true
	beam.Parent = flashlight

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			Remotes.get("Flashlight"):FireServer()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local hasTaser = ((player:GetAttribute("TaserCharges") :: number?) or 0) > 0
		local hasFlashlight = player:GetAttribute("HasFlashlight") == true
		local on = player:GetAttribute("FlashlightOn") == true

		taser.Transparency = if hasTaser then 0 else 1
		taser.CFrame = camera.CFrame * CFrame.new(1.6, -1.1, -2.6)
		flashlight.Transparency = if hasFlashlight then 0 else 1
		flashlight.CFrame = camera.CFrame * CFrame.new(-1.6, -1.1, -2.6)
		beam.Enabled = on

		-- La luz que el servidor le pone a la cabeza es para los otros; acá manda el haz local.
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local serverLight = head and head:FindFirstChild("LuzLinterna") :: SpotLight?
		if serverLight then
			serverLight.Enabled = false
		end
	end)
end

return Held
