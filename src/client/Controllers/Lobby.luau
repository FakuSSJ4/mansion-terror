--!strict
-- Ambiente del lobby: luz de atardecer cálida (lo contrario de la noche de la mansión), el contador
-- de gemas y una guía corta. Todo cambia solo para el jugador que está en el lobby.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Lobby = {}

local TEXT = Color3.fromRGB(255, 240, 214)
local WOOD = Color3.fromRGB(94, 62, 40)

local LOBBY_LIGHT = {
	-- Tarde nublada: luz pareja y gris cálido, sin sol directo.
	ClockTime = 15,
	Brightness = 1.2,
	Ambient = Color3.fromRGB(132, 128, 124),
	OutdoorAmbient = Color3.fromRGB(150, 146, 140),
	FogStart = 100000,
	FogEnd = 100000,
	ExposureCompensation = 0,
}

function Lobby.start()
	local player = Players.LocalPlayer

	-- Calidez de cine para todo lo que se ve desde el lobby.
	local warm = Instance.new("ColorCorrectionEffect")
	warm.Name = "CalidezLobby"
	warm.TintColor = Color3.fromRGB(255, 246, 236)
	warm.Saturation = 0.04
	warm.Contrast = 0.04
	warm.Enabled = false
	warm.Parent = Lighting

	-- Cielo cubierto: nubes densas y grises y un poco de bruma.
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 1
	clouds.Density = 1
	clouds.Color = Color3.fromRGB(168, 170, 176)
	clouds.Enabled = false
	clouds.Parent = workspace.Terrain
	local sky = Instance.new("Atmosphere")
	sky.Density = 0.55
	sky.Offset = 0.1
	sky.Color = Color3.fromRGB(176, 178, 184)
	sky.Decay = Color3.fromRGB(150, 150, 156)
	sky.Glare = 0
	sky.Haze = 4

	local saved: { [string]: any }? = nil
	local function applyLight(inLobby: boolean)
		if inLobby and not saved then
			local copy: { [string]: any } = {}
			for property in LOBBY_LIGHT do
				copy[property] = (Lighting :: any)[property]
			end
			saved = copy
			for property, value in LOBBY_LIGHT do
				(Lighting :: any)[property] = value
			end
		elseif not inLobby and saved then
			for property, value in saved do
				(Lighting :: any)[property] = value
			end
			saved = nil
		end
		warm.Enabled = inLobby
		clouds.Enabled = inLobby
		sky.Parent = if inLobby then Lighting else nil
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local function pill(position: UDim2, size: UDim2, anchor: Vector2): (Frame, TextLabel)
		local back = Instance.new("Frame")
		back.AnchorPoint = anchor
		back.Position = position
		back.Size = size
		back.BackgroundColor3 = WOOD
		back.BackgroundTransparency = 0.18
		back.BorderSizePixel = 0
		back.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = back
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 206, 150)
		stroke.Thickness = 2
		stroke.Parent = back
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = TEXT
		label.TextScaled = true
		label.Parent = back
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 6)
		padding.PaddingBottom = UDim.new(0, 6)
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 12)
		padding.Parent = label
		return back, label
	end

	local _, gemsLabel =
		pill(UDim2.new(1, -20, 0, 20), UDim2.fromOffset(190, 46), Vector2.new(1, 0))
	local _, hint = pill(UDim2.new(0.5, 0, 1, -24), UDim2.fromOffset(620, 44), Vector2.new(0.5, 1))
	hint.Text =
		"Pisá un círculo para armar la partida · E (dificultad) y F (jugadores) en el atril · Tienda al este de la fuente"

	local function refreshGems()
		gemsLabel.Text = `Gemas: {(player:GetAttribute("Gems") :: number?) or 0}`
	end
	player:GetAttributeChangedSignal("Gems"):Connect(function()
		refreshGems()
		TweenService
			:Create(gemsLabel, TweenInfo.new(0.12), { TextColor3 = Color3.fromRGB(140, 230, 255) })
			:Play()
		task.delay(0.25, function()
			TweenService:Create(gemsLabel, TweenInfo.new(0.3), { TextColor3 = TEXT }):Play()
		end)
	end)
	refreshGems()

	-- Cuenta regresiva en grande mientras estás parado en un círculo, del color de ese círculo.
	local countdown = Instance.new("TextLabel")
	countdown.AnchorPoint = Vector2.new(0.5, 0.5)
	countdown.Position = UDim2.fromScale(0.5, 0.3)
	countdown.Size = UDim2.fromOffset(220, 160)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.FredokaOne
	countdown.TextScaled = true
	countdown.TextStrokeColor3 = Color3.fromRGB(50, 30, 18)
	countdown.TextStrokeTransparency = 0
	countdown.Visible = false
	countdown.Parent = gui
	local countdownCaption = Instance.new("TextLabel")
	countdownCaption.AnchorPoint = Vector2.new(0.5, 1)
	countdownCaption.Position = UDim2.new(0.5, 0, 0, -2)
	countdownCaption.Size = UDim2.fromOffset(320, 34)
	countdownCaption.BackgroundTransparency = 1
	countdownCaption.Font = Enum.Font.FredokaOne
	countdownCaption.TextScaled = true
	countdownCaption.TextStrokeColor3 = Color3.fromRGB(50, 30, 18)
	countdownCaption.TextStrokeTransparency = 0
	countdownCaption.Text = "La partida empieza en"
	countdownCaption.Parent = countdown
	local function refreshCountdown()
		local left = player:GetAttribute("LobbyCountdown")
		local color = player:GetAttribute("LobbyCountdownColor")
		if typeof(left) ~= "number" then
			countdown.Visible = false
			return
		end
		local tint = if typeof(color) == "Color3" then color else TEXT
		countdown.TextColor3 = tint
		countdownCaption.TextColor3 = tint
		countdown.Text = tostring(left)
		countdown.Visible = true
		-- Un saltito en cada segundo.
		countdown.Size = UDim2.fromOffset(280, 204)
		TweenService:Create(
			countdown,
			TweenInfo.new(0.25, Enum.EasingStyle.Back),
			{ Size = UDim2.fromOffset(220, 160) }
		):Play()
	end
	player:GetAttributeChangedSignal("LobbyCountdown"):Connect(refreshCountdown)

	-- Menú para elegir cuántos jugadores necesita el círculo: botones 1, 2 y 3 (o las teclas).
	local menu = Instance.new("Frame")
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.45)
	menu.Size = UDim2.fromOffset(420, 190)
	menu.BackgroundColor3 = WOOD
	menu.BackgroundTransparency = 0.08
	menu.BorderSizePixel = 0
	menu.Visible = false
	menu.Parent = gui
	local menuCorner = Instance.new("UICorner")
	menuCorner.CornerRadius = UDim.new(0, 16)
	menuCorner.Parent = menu
	local menuStroke = Instance.new("UIStroke")
	menuStroke.Color = Color3.fromRGB(255, 206, 150)
	menuStroke.Thickness = 3
	menuStroke.Parent = menu
	local menuTitle = Instance.new("TextLabel")
	menuTitle.BackgroundTransparency = 1
	menuTitle.Position = UDim2.fromOffset(10, 8)
	menuTitle.Size = UDim2.new(1, -20, 0, 44)
	menuTitle.Font = Enum.Font.FredokaOne
	menuTitle.TextScaled = true
	menuTitle.TextColor3 = TEXT
	menuTitle.Text = "¿Cuántos jugadores?"
	menuTitle.Parent = menu
	local menuHint = Instance.new("TextLabel")
	menuHint.BackgroundTransparency = 1
	menuHint.Position = UDim2.new(0, 10, 1, -34)
	menuHint.Size = UDim2.new(1, -20, 0, 26)
	menuHint.Font = Enum.Font.FredokaOne
	menuHint.TextScaled = true
	menuHint.TextColor3 = Color3.fromRGB(214, 190, 160)
	menuHint.Text = "Elegí con el clic o con las teclas 1, 2 y 3 · Esc cierra"
	menuHint.Parent = menu

	local openPad: number? = nil
	local function closeMenu()
		openPad = nil
		menu.Visible = false
	end
	local function choose(count: number)
		if openPad then
			Remotes.get("Lobby"):FireServer(openPad, count)
		end
		closeMenu()
	end
	local optionButtons: { TextButton } = {}
	for n = 1, 3 do
		local button = Instance.new("TextButton")
		button.Position = UDim2.fromOffset(20 + (n - 1) * 130, 66)
		button.Size = UDim2.fromOffset(120, 70)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.TextColor3 = Color3.fromRGB(70, 44, 28)
		button.BackgroundColor3 = Color3.fromRGB(246, 236, 214)
		button.Text = `{n}\n{if n == 1 then "jugador" else "jugadores"}`
		button.AutoButtonColor = true
		-- Modal libera el mouse aunque la cámara esté en primera persona.
		button.Modal = true
		button.Parent = menu
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = button
		button.Activated:Connect(function()
			choose(n)
		end)
		optionButtons[n] = button
	end
	Remotes.get("Lobby").OnClientEvent:Connect(function(index: number, current: number, max: number)
		openPad = index
		menuTitle.Text = `Partida {index}: ¿cuántos jugadores?`
		for n, button in optionButtons do
			button.Visible = n <= max
			button.BackgroundColor3 = if n == current
				then Color3.fromRGB(255, 206, 150)
				else Color3.fromRGB(246, 236, 214)
		end
		menu.Visible = true
	end)
	-- Menú de dificultad: Fácil, Normal y Pesadilla (esta última bloqueada hasta ganar 3 veces en Normal).
	local diffMenu = Instance.new("Frame")
	diffMenu.AnchorPoint = Vector2.new(0.5, 0.5)
	diffMenu.Position = UDim2.fromScale(0.5, 0.45)
	diffMenu.Size = UDim2.fromOffset(470, 200)
	diffMenu.BackgroundColor3 = WOOD
	diffMenu.BackgroundTransparency = 0.08
	diffMenu.BorderSizePixel = 0
	diffMenu.Visible = false
	diffMenu.Parent = gui
	local diffCorner = Instance.new("UICorner")
	diffCorner.CornerRadius = UDim.new(0, 16)
	diffCorner.Parent = diffMenu
	local diffStroke = Instance.new("UIStroke")
	diffStroke.Color = Color3.fromRGB(255, 206, 150)
	diffStroke.Thickness = 3
	diffStroke.Parent = diffMenu
	local diffTitle = Instance.new("TextLabel")
	diffTitle.BackgroundTransparency = 1
	diffTitle.Position = UDim2.fromOffset(10, 8)
	diffTitle.Size = UDim2.new(1, -20, 0, 44)
	diffTitle.Font = Enum.Font.FredokaOne
	diffTitle.TextScaled = true
	diffTitle.TextColor3 = TEXT
	diffTitle.Parent = diffMenu
	local diffHint = Instance.new("TextLabel")
	diffHint.BackgroundTransparency = 1
	diffHint.Position = UDim2.new(0, 10, 1, -34)
	diffHint.Size = UDim2.new(1, -20, 0, 26)
	diffHint.Font = Enum.Font.FredokaOne
	diffHint.TextScaled = true
	diffHint.TextColor3 = Color3.fromRGB(214, 190, 160)
	diffHint.Parent = diffMenu

	local diffPad: number? = nil
	local nightmareOpen = false
	local function closeDifficulty()
		diffPad = nil
		diffMenu.Visible = false
	end
	local function chooseDifficulty(id: string)
		if diffPad and (id ~= "nightmare" or nightmareOpen) then
			Remotes.get("SetDifficulty"):FireServer(diffPad, id)
			closeDifficulty()
		end
	end
	local diffButtons: { [string]: TextButton } = {}
	for column, id in { "easy", "normal", "nightmare" } do
		local button = Instance.new("TextButton")
		button.Position = UDim2.fromOffset(20 + (column - 1) * 148, 66)
		button.Size = UDim2.fromOffset(138, 80)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.TextColor3 = Color3.fromRGB(70, 44, 28)
		button.AutoButtonColor = true
		button.Modal = true
		button.Parent = diffMenu
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = button
		button.Activated:Connect(function()
			chooseDifficulty(id)
		end)
		diffButtons[id] = button
	end
	Remotes.get("SetDifficulty").OnClientEvent
		:Connect(function(index: number, current: string, unlocked: boolean, wins: number)
			diffPad = index
			nightmareOpen = unlocked
			diffTitle.Text = `Partida {index}: dificultad`
			for id, button in diffButtons do
				local locked = id == "nightmare" and not unlocked
				button.Text = if locked
					then `Pesadilla\n{wins}/{Config.NightmareUnlockWins} victorias`
					else Config.Difficulties[id].name
				button.BackgroundColor3 = if locked
					then Color3.fromRGB(120, 108, 98)
					elseif id == current then Color3.fromRGB(255, 206, 150)
					else Color3.fromRGB(246, 236, 214)
			end
			diffHint.Text = if unlocked
				then "Clic o teclas 1, 2 y 3 · Esc cierra"
				else `Pesadilla: ganá {Config.NightmareUnlockWins} veces en Normal para desbloquearla`
			diffMenu.Visible = true
		end)
	UserInputService.InputBegan:Connect(function(input)
		if diffPad then
			local ids = {
				[Enum.KeyCode.One] = "easy",
				[Enum.KeyCode.Two] = "normal",
				[Enum.KeyCode.Three] = "nightmare",
			}
			if ids[input.KeyCode] then
				chooseDifficulty(ids[input.KeyCode])
			elseif input.KeyCode == Enum.KeyCode.Escape then
				closeDifficulty()
			end
			return
		end
		if not openPad then
			return
		end
		local picks = {
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
		}
		if picks[input.KeyCode] then
			choose(picks[input.KeyCode])
		elseif input.KeyCode == Enum.KeyCode.Escape then
			closeMenu()
		end
	end)

	-- Al entrar a la mansión el patio queda solo con la fuente: los círculos, la tienda y los adornos del
	-- lobby se ocultan (solo para este jugador).
	local props: Model? = nil
	local function refresh()
		local inLobby = player:GetAttribute("InLobby") == true
		if not inLobby then
			closeDifficulty()
		end
		if props then
			props.Parent = if inLobby then workspace else nil
		end
		if not inLobby then
			closeMenu()
		end
		gui.Enabled = inLobby
		applyLight(inLobby)
	end
	player:GetAttributeChangedSignal("InLobby"):Connect(refresh)
	task.spawn(function()
		props = workspace:WaitForChild("Lobby") :: Model
		refresh()
	end)
	refresh()
end

return Lobby
