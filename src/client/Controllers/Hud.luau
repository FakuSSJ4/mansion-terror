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

	-- Un ícono de llave por cada una, de su color; se enciende cuando el equipo la encuentra. Va
	-- dibujada con cuadros: anillo a la izquierda, vástago y dos dientes.
	local keyIcons: { (boolean) -> () } = {}
	for n, key in Config.KeyColors do
		local color = Color3.fromRGB(table.unpack(key.rgb))
		local icon = Instance.new("Frame")
		icon.Position = UDim2.fromOffset(16 + (n - 1) * 36, 94)
		icon.Size = UDim2.fromOffset(32, 24)
		icon.BackgroundTransparency = 1
		icon.Parent = gui
		local solids: { Frame } = {}
		local function solid(position: UDim2, size: UDim2): Frame
			local frame = Instance.new("Frame")
			frame.Position = position
			frame.Size = size
			frame.BackgroundColor3 = color
			frame.BorderSizePixel = 0
			frame.Parent = icon
			table.insert(solids, frame)
			return frame
		end
		local ring = Instance.new("Frame")
		ring.Position = UDim2.fromOffset(1, 5)
		ring.Size = UDim2.fromOffset(13, 13)
		ring.BackgroundTransparency = 1
		ring.Parent = icon
		local ringShape = Instance.new("UICorner")
		ringShape.CornerRadius = UDim.new(0.5, 0)
		ringShape.Parent = ring
		local ringStroke = Instance.new("UIStroke")
		ringStroke.Color = color
		ringStroke.Thickness = 3
		ringStroke.Parent = ring
		solid(UDim2.fromOffset(13, 10), UDim2.fromOffset(17, 3))
		solid(UDim2.fromOffset(22, 13), UDim2.fromOffset(3, 6))
		solid(UDim2.fromOffset(27, 13), UDim2.fromOffset(3, 4))
		keyIcons[n] = function(lit: boolean)
			local alpha = if lit then 0 else 0.85
			for _, frame in solids do
				frame.BackgroundTransparency = alpha
			end
			ringStroke.Transparency = alpha
		end
	end

	local notice = label(gui, UDim2.fromScale(0, 0.72), UDim2.new(1, 0, 0, 40), 28)
	notice.TextXAlignment = Enum.TextXAlignment.Center

	-- Qué hacer ahora, según lo que ya tenés: sin sonido ni mapa, es la única guía.
	local objective = label(gui, UDim2.fromScale(0.2, 0.012), UDim2.fromScale(0.6, 0.06), 24)
	objective.TextXAlignment = Enum.TextXAlignment.Center
	local function refreshObjective()
		local phase = workspace:GetAttribute("Phase")
		local playing = (phase == "Playing" or phase == "Escaping")
			and player:GetAttribute("InLobby") ~= true
		objective.Visible = playing
		if not playing then
			return
		end
		local books = (workspace:GetAttribute("Books") :: number?) or 0
		if not player:GetAttribute("HasFlashlight") then
			objective.Text =
				"Buscá la linterna: está sobre la mesita del hall, entre las escaleras"
		elseif workspace:GetAttribute("ExitOpen") then
			objective.Text = "¡La salida está abierta! Corré por la puerta del túnel"
		elseif books < Config.BookCount then
			objective.Text =
				`Explorá: buscá llaves y notas con códigos; cada pergamino ({books}/{Config.BookCount}) está en una caja fuerte con código`
		elseif not player:GetAttribute("HasGoldKey") then
			objective.Text =
				"Llevá los pergaminos a la estatua del lobo, en la sala del fondo del sótano"
		else
			objective.Text = "Abrí la puerta del túnel con la llave dorada y escapá"
		end
	end
	workspace:GetAttributeChangedSignal("Books"):Connect(refreshObjective)
	workspace:GetAttributeChangedSignal("Phase"):Connect(refreshObjective)
	workspace:GetAttributeChangedSignal("ExitOpen"):Connect(refreshObjective)
	player:GetAttributeChangedSignal("HasFlashlight"):Connect(refreshObjective)
	player:GetAttributeChangedSignal("HasGoldKey"):Connect(refreshObjective)
	player:GetAttributeChangedSignal("InLobby"):Connect(refreshObjective)
	refreshObjective()

	-- Aviso de peligro: los bordes de la pantalla se ponen rojos y laten más rápido cuanto más cerca
	-- está un asesino.
	local edges: { Frame } = {}
	for _, spec in
		{
			{ UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.24), 90 },
			{ UDim2.fromScale(0, 0.76), UDim2.fromScale(1, 0.24), 270 },
			{ UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0 },
			{ UDim2.fromScale(0.84, 0), UDim2.fromScale(0.16, 1), 180 },
		}
	do
		local edge = Instance.new("Frame")
		edge.Position = spec[1]
		edge.Size = spec[2]
		edge.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
		edge.BackgroundTransparency = 1
		edge.BorderSizePixel = 0
		edge.ZIndex = 0
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec[3]
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = edge
		edge.Parent = gui
		table.insert(edges, edge)
	end
	RunService.RenderStepped:Connect(function()
		local danger = (player:GetAttribute("Danger") :: number?) or 0
		local pulse = 0.55 + 0.45 * math.sin(os.clock() * (3 + danger * 6))
		-- Desde que hay peligro se nota (0,2) y llega casi al máximo (0,9) con el asesino encima.
		local alpha = if danger <= 0 then 0 else math.clamp((0.2 + 0.8 * danger) * pulse, 0, 0.9)
		local transparency = 1 - alpha
		for _, edge in edges do
			edge.BackgroundTransparency = transparency
		end
	end)
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
		local crouch = if player:GetAttribute("Crouching") then "\nAgachado" else ""
		local gems = `\nGemas: {(player:GetAttribute("Gems") :: number?) or 0}`
		-- Los códigos que el equipo ya encontró (habitación: código); el resto, con signos.
		local codes = ""
		for n = 1, Config.BookCount do
			codes ..= `\nCaja fuerte {n}: {workspace:GetAttribute(`Code{n}`) or "???"}`
		end
		local setting = Config.Difficulties[workspace:GetAttribute("Difficulty")]
		local hard = if setting and setting ~= Config.Difficulties.normal
			then `\nModo {setting.name}`
			else ""
		status.Text =
			`Pergaminos: {books}/{Config.BookCount}\nTaser: {taser}{ladder}{gold}{hard}{crouch}{gems}{codes}{dev}`
		batteryBack.Visible = player:GetAttribute("HasFlashlight") == true
		for n, setLit in keyIcons do
			setLit(workspace:GetAttribute(`Key{n}`) == true)
		end
	end
	for n = 1, Config.KeyCount do
		workspace:GetAttributeChangedSignal(`Key{n}`):Connect(refreshStatus)
	end
	for n = 1, Config.BookCount do
		workspace:GetAttributeChangedSignal(`Code{n}`):Connect(refreshStatus)
	end
	workspace:GetAttributeChangedSignal("Books"):Connect(refreshStatus)
	workspace:GetAttributeChangedSignal("Difficulty"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("HasGoldKey"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("GodMode"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("Crouching"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("Gems"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("TaserCharges"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("HasLadder"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("HasFlashlight"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("Battery"):Connect(function()
		batteryFill.Size = UDim2.fromScale((player:GetAttribute("Battery") :: number?) or 0, 1)
	end)
	refreshStatus()

	local function refreshPhase()
		local phase = workspace:GetAttribute("Phase")
		local over = (phase == "Won" or phase == "Dead") and player:GetAttribute("InLobby") ~= true
		victory.Text = if phase == "Dead"
			then "El asesino te atrapó\nLa partida vuelve a empezar"
			else "Escapaste de la mansión"
		victory.Visible = over
		victory.BackgroundTransparency = if over then 0.15 else 1
	end
	workspace:GetAttributeChangedSignal("Phase"):Connect(refreshPhase)
	player:GetAttributeChangedSignal("InLobby"):Connect(function()
		gui.Enabled = player:GetAttribute("InLobby") ~= true
		refreshPhase()
	end)
	gui.Enabled = player:GetAttribute("InLobby") ~= true
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
