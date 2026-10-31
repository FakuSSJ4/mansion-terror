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
	local status = label(gui, UDim2.fromOffset(16, 96), UDim2.fromOffset(300, 80), 24)
	status.TextYAlignment = Enum.TextYAlignment.Top

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
		local keys = workspace:GetAttribute("Keys") or 0
		local books = workspace:GetAttribute("Books") or 0
		local charges = player:GetAttribute("TaserCharges") or 0
		status.Text =
			`Llaves: {keys}/{Config.KeyCount}\nEscritos: {books}/{Config.BookCount}\nTaser: {charges}`
	end
	workspace:GetAttributeChangedSignal("Keys"):Connect(refreshStatus)
	workspace:GetAttributeChangedSignal("Books"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("TaserCharges"):Connect(refreshStatus)
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
