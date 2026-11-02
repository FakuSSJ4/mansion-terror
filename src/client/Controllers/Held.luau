--!strict
-- Lo que se ve en la mano en primera persona y el haz de la linterna, que sigue a la cámara.
-- En la mano va el objeto elegido en la barra (Hotbar); la linterna se prende con clic derecho.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Held = {}

-- Abajo a la derecha de la pantalla, un poco girado hacia el centro.
local HAND = CFrame.new(1.25, -1.05, -2.3) * CFrame.Angles(math.rad(3), math.rad(-7), 0)

local function hold(pieces: { ItemModels.Piece }): Model
	local model = ItemModels.model(pieces)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CastShadow = false
		end
	end
	return model
end

function Held.start()
	local player = Players.LocalPlayer
	local holder = Instance.new("Folder")
	holder.Name = "EnLaMano"
	holder.Parent = workspace

	local taserPieces = ItemModels.taser()
	local flashlightPieces = ItemModels.flashlight()
	local taser = hold(taserPieces)
	local flashlight = hold(flashlightPieces)
	local lens = flashlight:FindFirstChild("Lente") :: Part?

	-- El haz sale de los ojos: desde la mano, lo que estaba cerca quedaba detrás o fuera del cono.
	local beamSource = Instance.new("Part")
	beamSource.Name = "HazLinterna"
	beamSource.Anchored = true
	beamSource.CanCollide = false
	beamSource.CanQuery = false
	beamSource.CanTouch = false
	beamSource.CastShadow = false
	beamSource.Size = Vector3.new(0.1, 0.1, 0.1)
	beamSource.Transparency = 1
	beamSource.Parent = holder
	local beam = Instance.new("SpotLight")
	beam.Range = 60
	beam.Angle = 70
	beam.Brightness = 3
	beam.Face = Enum.NormalId.Front
	beam.Shadows = true
	beam.Parent = beamSource

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton2 then
			Remotes.get("Flashlight"):FireServer()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local equipped = player:GetAttribute("Equipped")
		local hasTaser = ((player:GetAttribute("TaserCharges") :: number?) or 0) > 0
		local hasFlashlight = player:GetAttribute("HasFlashlight") == true
		-- En una secuencia de cámara (la fuga) no se ve nada en la mano ni sale el haz.
		local cinematic = player:GetAttribute("Cinematic") == true
		local on = player:GetAttribute("FlashlightOn") == true and not cinematic

		local showTaser = hasTaser and equipped == "taser" and not cinematic
		local showFlashlight = hasFlashlight and equipped == "flashlight" and not cinematic
		taser.Parent = if showTaser then holder else nil
		flashlight.Parent = if showFlashlight then holder else nil
		-- Un balanceo leve para que no se vea clavado a la cámara.
		local sway = CFrame.new(0, math.sin(os.clock() * 1.6) * 0.012, 0)
		if showTaser then
			taser:PivotTo(camera.CFrame * sway * HAND * taserPieces[1].offset)
		end
		if showFlashlight then
			flashlight:PivotTo(camera.CFrame * sway * HAND * flashlightPieces[1].offset)
		end
		if lens then
			lens.Material = if on then Enum.Material.Neon else Enum.Material.Glass
			lens.Transparency = if on then 0.05 else 0.25
		end
		beamSource.CFrame = camera.CFrame * CFrame.new(0, 0, -0.6)
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
