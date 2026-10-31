--!strict
-- Interfaz: vida, energía, cargas, progreso, avisos, pantalla de victoria y tecla de correr.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Hud = {}

local function label(parent: Instance, position: UDim2, size: UDim2, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Font = Enum.Font.Garamond
	text.TextSize = textSize
	text.TextColor3 = Color3.fromRGB(225, 215, 195)
	text.TextStrokeTransparency = 0.5
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = ""
	text.Parent = parent
	return text
end

local function bar(parent: Instance, y: number, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 16, 1, y)
	back.Size = UDim2.fromOffset(220, 12)
	back.BackgroundColor3 = Color3.fromRGB(20, 16, 16)
	back.BorderSizePixel = 0
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	return fill
end

function Hud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local healthFill = bar(gui, -46, Color3.fromRGB(150, 25, 25))
	local staminaFill = bar(gui, -28, Color3.fromRGB(170, 150, 80))
	local batteryFill = bar(gui, -64, Color3.fromRGB(90, 150, 200))
	local batteryBack = batteryFill.Parent :: Frame
	local status = label(gui, UDim2.fromOffset(16, 122), UDim2.fromOffset(300, 100), 24)
	status.TextYAlignment = Enum.TextYAlignment.Top

	-- Una marca por llave, de su color; se enciende cuando el equipo la encuentra.
	local keyChips: { Frame } = {}
	for n, key in Config.KeyColors do
		local chip = Instance.new("Frame")
		chip.Position = UDim2.fromOffset(16 + (n - 1) * 28, 96)
		chip.Size = UDim2.fromOffset(22, 22)
		chip.BackgroundColor3 = Color3.fromRGB(table.unpack(key.rgb))
		chip.BorderSizePixel = 0
		chip.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(225, 215, 195)
		stroke.Parent = chip
		keyChips[n] = chip
	end

	local notice = label(gui, UDim2.fromScale(0, 0.72), UDim2.new(1, 0, 0, 40), 28)
	notice.TextXAlignment = Enum.TextXAlignment.Center

	local hurt = Instance.new("Frame")
	hurt.Size = UDim2.fromScale(1, 1)
	hurt.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	hurt.BackgroundTransparency = 1
	hurt.BorderSizePixel = 0
	hurt.Parent = gui

	local victory = label(gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 56)
	victory.TextXAlignment = Enum.TextXAlignment.Center
	victory.BackgroundColor3 = Color3.new(0, 0, 0)
	victory.Text = "Escapaste de la mansión"
	victory.Visible = false

	local function refreshStatus()
		local books = workspace:GetAttribute("Books") or 0
		local charges = (player:GetAttribute("TaserCharges") :: number?) or 0
		local taser = if charges > 0 then "sí" else "no"
		local ladder = if player:GetAttribute("HasLadder") then "\nLlevás la escalera" else ""
		local gold = if player:GetAttribute("HasGoldKey") then "\nLlevás la llave dorada" else ""
		local dev = if player:GetAttribute("GodMode") then "\nMODO DESARROLLADOR" else ""
		status.Text = `Pergaminos: {books}/{Config.BookCount}\nTaser: {taser}{ladder}{gold}{dev}`
		batteryBack.Visible = player:GetAttribute("HasFlashlight") == true
		for n, chip in keyChips do
			chip.BackgroundTransparency = if workspace:GetAttribute(`Key{n}`) then 0 else 0.85
		end
	end
	for n = 1, Config.KeyCount do
		workspace:GetAttributeChangedSignal(`Key{n}`):Connect(refreshStatus)
	end
	workspace:GetAttributeChangedSignal("Books"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("HasGoldKey"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("GodMode"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("TaserCharges"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("HasLadder"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("HasFlashlight"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("Battery"):Connect(function()
		batteryFill.Size = UDim2.fromScale((player:GetAttribute("Battery") :: number?) or 0, 1)
	end)
	refreshStatus()

	local function refreshPhase()
		local won = workspace:GetAttribute("Phase") == "Won"
		victory.Visible = won
		victory.BackgroundTransparency = if won then 0.15 else 1
	end
	workspace:GetAttributeChangedSignal("Phase"):Connect(refreshPhase)
	refreshPhase()

	local noticeId = 0
	Remotes.get("Notify").OnClientEvent:Connect(function(text: string)
		noticeId += 1
		local id = noticeId
		notice.Text = text
		task.delay(4, function()
			if id == noticeId then
				notice.Text = ""
			end
		end)
	end)

	Remotes.get("Hit").OnClientEvent:Connect(function()
		hurt.BackgroundTransparency = 0.25
		TweenService:Create(hurt, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	end)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local health = if humanoid then humanoid.Health / humanoid.MaxHealth else 0
		healthFill.Size = UDim2.fromScale(math.clamp(health, 0, 1), 1)
		staminaFill.Size = UDim2.fromScale(((player:GetAttribute("Stamina") :: number?) or 1), 1)
	end)

	ContextActionService:BindAction("Correr", function(_, state)
		if state == Enum.UserInputState.Begin then
			Remotes.get("Run"):FireServer(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			Remotes.get("Run"):FireServer(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift)
end

return Hud
