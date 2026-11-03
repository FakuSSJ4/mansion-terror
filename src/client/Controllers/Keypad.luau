--!strict
-- Teclado numérico de las habitaciones con código: el servidor avisa qué habitación se tocó y acá se
-- tipean tres cifras (con los botones o con el teclado). Contesta por el mismo remoto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Keypad = {}

local TEXT = Color3.fromRGB(235, 222, 196)
local WOOD = Color3.fromRGB(38, 26, 18)
local GOLD = Color3.fromRGB(226, 196, 120)

function Keypad.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Keypad"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(300, 410)
	panel.BackgroundColor3 = WOOD
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 8)
	title.Size = UDim2.new(1, -56, 0, 34)
	title.Font = Enum.Font.Garamond
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -8, 0, 8)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextScaled = true
	closeButton.Text = "X"
	closeButton.TextColor3 = TEXT
	closeButton.BackgroundColor3 = Color3.fromRGB(120, 36, 32)
	closeButton.AutoButtonColor = true
	closeButton.Modal = true
	closeButton.ZIndex = 2
	closeButton.Parent = panel
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton
	local closePadding = Instance.new("UIPadding")
	closePadding.PaddingTop = UDim.new(0, 5)
	closePadding.PaddingBottom = UDim.new(0, 5)
	closePadding.PaddingLeft = UDim.new(0, 5)
	closePadding.PaddingRight = UDim.new(0, 5)
	closePadding.Parent = closeButton

	local display = Instance.new("TextLabel")
	display.BackgroundColor3 = Color3.fromRGB(14, 10, 8)
	display.Position = UDim2.fromOffset(40, 52)
	display.Size = UDim2.fromOffset(220, 56)
	display.Font = Enum.Font.Code
	display.TextScaled = true
	display.TextColor3 = Color3.fromRGB(140, 230, 150)
	display.Parent = panel

	local openFor: number? = nil
	local typed = ""

	local function refreshDisplay()
		local shown = typed .. string.rep("_", 3 - #typed)
		display.Text = string.gsub(shown, ".", "%0 ")
	end
	local function close()
		openFor = nil
		typed = ""
		panel.Visible = false
	end
	closeButton.Activated:Connect(close)
	local function submit()
		if openFor and #typed == 3 then
			Remotes.get("Keypad"):FireServer(openFor, tonumber(typed))
			close()
		end
	end
	local function press(digit: string)
		if #typed < 3 then
			typed ..= digit
			refreshDisplay()
		end
	end

	-- Botones 1 al 9, y abajo borrar, 0 y entrar.
	local labels = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK" }
	for index, text in labels do
		local button = Instance.new("TextButton")
		local column, row = (index - 1) % 3, math.floor((index - 1) / 3)
		button.Position = UDim2.fromOffset(40 + column * 76, 122 + row * 66)
		button.Size = UDim2.fromOffset(68, 58)
		button.Font = Enum.Font.Garamond
		button.TextScaled = true
		button.Text = text
		button.TextColor3 = WOOD
		button.BackgroundColor3 = if text == "OK" then GOLD else TEXT
		button.AutoButtonColor = true
		-- Modal libera el mouse aunque la cámara esté en primera persona.
		button.Modal = true
		button.Parent = panel
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 8)
		round.Parent = button
		button.Activated:Connect(function()
			if text == "OK" then
				submit()
			elseif text == "<" then
				typed = string.sub(typed, 1, -2)
				refreshDisplay()
			else
				press(text)
			end
		end)
	end

	Remotes.get("Keypad").OnClientEvent:Connect(function(index: number)
		openFor = index
		typed = ""
		title.Text = `Caja fuerte {index}: ingresá el código`
		refreshDisplay()
		panel.Visible = true
	end)

	UserInputService.InputBegan:Connect(function(input)
		if not openFor then
			return
		end
		local code = input.KeyCode.Value
		-- Dígitos de la fila superior (48-57) y del teclado numérico (256-265).
		if code >= 48 and code <= 57 then
			press(tostring(code - 48))
		elseif code >= 256 and code <= 265 then
			press(tostring(code - 256))
		elseif input.KeyCode == Enum.KeyCode.Backspace then
			typed = string.sub(typed, 1, -2)
			refreshDisplay()
		elseif
			input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter
		then
			submit()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			close()
		end
	end)

	-- Si el jugador se aleja o sale de la partida, el teclado se cierra solo.
	player:GetAttributeChangedSignal("InLobby"):Connect(close)
end

return Keypad
