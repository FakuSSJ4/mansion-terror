--!strict
-- Barra de objetos: 1 taser y 2 linterna. La tecla saca el objeto a la mano (otra vez lo guarda);
-- el atributo "Equipped" del jugador, que solo vive en este cliente, dice cuál está en la mano.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemModels = require(Shared:WaitForChild("ItemModels"))

local Hotbar = {}

local GOLD = Color3.fromRGB(235, 180, 40)
local DIM = Color3.fromRGB(90, 86, 80)
local TEXT = Color3.fromRGB(225, 215, 195)

type Slot = {
	key: Enum.KeyCode,
	number: string,
	item: string,
	frame: Frame,
	stroke: UIStroke,
	shade: Frame,
	tag: TextLabel,
}

local function label(parent: Instance, position: UDim2, size: UDim2, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Font = Enum.Font.Garamond
	text.TextSize = textSize
	text.TextColor3 = TEXT
	text.TextStrokeTransparency = 0.5
	text.Text = ""
	text.ZIndex = 4
	text.Parent = parent
	return text
end

-- Ícono: el mismo modelo 3D que se ve en la mano, visto de costado y desde arriba.
local function icon(parent: Instance, pieces: { ItemModels.Piece })
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(190, 190, 190)
	view.LightColor = Color3.fromRGB(255, 244, 225)
	view.LightDirection = Vector3.new(-1, -1.2, -0.6)
	view.ZIndex = 2
	view.Parent = parent
	local model = ItemModels.model(pieces)
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(1.7, 0.85, 1.1), Vector3.new(0, -0.1, -0.1))
	camera.Parent = view
	view.CurrentCamera = camera
end

function Hotbar.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hotbar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -24)
	bar.Size = UDim2.fromOffset(160, 76)
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = bar

	local function newSlot(
		order: number,
		key: Enum.KeyCode,
		number: string,
		item: string,
		pieces: { ItemModels.Piece }
	): Slot
		local frame = Instance.new("Frame")
		frame.LayoutOrder = order
		frame.Size = UDim2.fromOffset(72, 72)
		frame.BackgroundColor3 = Color3.fromRGB(16, 14, 12)
		frame.BackgroundTransparency = 0.25
		frame.BorderSizePixel = 0
		frame.Parent = bar
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = DIM
		stroke.Thickness = 1
		stroke.Parent = frame
		icon(frame, pieces)
		-- Velo oscuro mientras no se tiene el objeto.
		local shade = Instance.new("Frame")
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 0.45
		shade.BorderSizePixel = 0
		shade.Size = UDim2.fromScale(1, 1)
		shade.ZIndex = 3
		shade.Parent = frame
		local shadeCorner = Instance.new("UICorner")
		shadeCorner.CornerRadius = UDim.new(0, 8)
		shadeCorner.Parent = shade
		local numberLabel = label(frame, UDim2.fromOffset(6, 2), UDim2.fromOffset(20, 20), 20)
		numberLabel.Text = number
		numberLabel.TextXAlignment = Enum.TextXAlignment.Left
		local tag = label(frame, UDim2.new(0, 0, 1, -22), UDim2.new(1, -6, 0, 20), 18)
		tag.TextXAlignment = Enum.TextXAlignment.Right
		return {
			key = key,
			number = number,
			item = item,
			frame = frame,
			stroke = stroke,
			shade = shade,
			tag = tag,
		}
	end

	local slots = {
		newSlot(1, Enum.KeyCode.One, "1", "taser", ItemModels.taser()),
		newSlot(2, Enum.KeyCode.Two, "2", "flashlight", ItemModels.flashlight()),
	}

	local function owns(item: string): boolean
		if item == "taser" then
			return ((player:GetAttribute("TaserCharges") :: number?) or 0) > 0
		end
		return player:GetAttribute("HasFlashlight") == true
	end

	local function refresh()
		-- Si lo que tenía en la mano ya no lo tiene (lo soltó o murió), queda con las manos libres.
		local equipped = player:GetAttribute("Equipped") :: string?
		if equipped and not owns(equipped) then
			player:SetAttribute("Equipped", nil)
			equipped = nil
		end
		for _, slot in slots do
			local has = owns(slot.item)
			-- Hasta que no se agarra el objeto, su casilla ni se muestra.
			slot.frame.Visible = has
			slot.shade.Visible = not has
			local selected = has and equipped == slot.item
			slot.stroke.Color = if selected then GOLD else DIM
			slot.stroke.Thickness = if selected then 2 else 1
			if slot.item == "taser" then
				local charges = (player:GetAttribute("TaserCharges") :: number?) or 0
				slot.tag.Text = if charges > 0 then `x{charges}` else ""
			else
				local on = player:GetAttribute("FlashlightOn") == true
				slot.tag.Text = if on then "ON" else ""
				slot.tag.TextColor3 = Color3.fromRGB(150, 230, 150)
			end
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for _, slot in slots do
			if input.KeyCode == slot.key and owns(slot.item) then
				local already = player:GetAttribute("Equipped") == slot.item
				player:SetAttribute("Equipped", if already then nil else slot.item)
			end
		end
	end)

	-- Lo que recién se levanta pasa directo a la mano.
	local hadTaser = owns("taser")
	local hadFlashlight = owns("flashlight")
	local function onPickups()
		local hasTaser = owns("taser")
		local hasFlashlight = owns("flashlight")
		if hasTaser and not hadTaser then
			player:SetAttribute("Equipped", "taser")
		elseif hasFlashlight and not hadFlashlight then
			player:SetAttribute("Equipped", "flashlight")
		end
		hadTaser, hadFlashlight = hasTaser, hasFlashlight
		refresh()
	end
	for _, name in { "TaserCharges", "HasFlashlight" } do
		player:GetAttributeChangedSignal(name):Connect(onPickups)
	end
	for _, name in { "FlashlightOn", "Equipped" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()

	local function refreshVisible()
		gui.Enabled = player:GetAttribute("InLobby") ~= true
	end
	player:GetAttributeChangedSignal("InLobby"):Connect(refreshVisible)
	refreshVisible()
	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hotbar
