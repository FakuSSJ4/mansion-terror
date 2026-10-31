--!strict
-- Tutorial al entrar: Espacio avanza y Q lo omite. Mientras está abierto, el servidor te protege.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local PAGES = {
	{
		title = "Controles",
		body = "W A S D: moverte\nMouse: mirar\nShift izquierdo: correr (gasta la barra amarilla y se recupera al dejar de correr)\nE: agarrar objetos, abrir puertas y usar la estatua\nClic: disparar el taser\nF: prender o apagar la linterna",
	},
	{
		title = "Cómo escapar",
		body = "1. Buscá las llaves de colores: cada una abre la puerta de su mismo color.\n2. La llave negra abre el sótano, en la cocina. Ahí está la escalera de mano.\n3. La llave amarilla abre la reja de la gran escalera, en el hall.\n4. Poné la escalera bajo la trampilla del primer piso para subir al cobertizo.\n5. Juntá los 4 pergaminos: sótano, cobertizo, planta baja y primer piso.\n6. Llevalos a la estatua de lobo del hall: te da la llave dorada.\n7. Abrí la puerta principal con la llave dorada y escapá.",
	},
	{
		title = "Cómo sobrevivir",
		body = "El asesino te saca 50 de vida por golpe. Las píldoras curan 50.\nEl taser lo deja quieto 10 segundos. Llevás uno solo y desaparece al usarlo.\nLa linterna gasta batería: buscá pilas para recargarla.\nEn las 3 piezas con luz azul el asesino no puede entrar.\nSi estás lejos mucho tiempo, sale a buscarte.\nEl asesino solo cruza las puertas que ya abriste: cada puerta nueva le abre camino.\nSi te mata, la partida vuelve a empezar de cero.",
	},
}

local Tutorial = {}

function Tutorial.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(6, 4, 4)
	back.BorderSizePixel = 0
	back.Parent = gui

	local function text(y: number, height: number, size: number, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, y)
		label.Size = UDim2.fromScale(0.8, height)
		label.Font = Enum.Font.Garamond
		label.TextSize = size
		label.TextColor3 = color
		label.TextWrapped = true
		label.Parent = back
		return label
	end

	local title = text(0.1, 0.12, 48, Color3.fromRGB(190, 50, 45))
	local body = text(0.24, 0.55, 26, Color3.fromRGB(225, 215, 195))
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextXAlignment = Enum.TextXAlignment.Left
	local footer = text(0.84, 0.08, 24, Color3.fromRGB(170, 160, 140))

	local page = 1
	local finished = false

	local function show()
		local current = PAGES[page]
		title.Text = current.title
		body.Text = current.body
		footer.Text = if page < #PAGES
			then `ESPACIO: siguiente ({page}/{#PAGES})     Q: omitir tutorial`
			else "ESPACIO: empezar a jugar"
	end

	local function close()
		finished = true
		gui:Destroy()
		Remotes.get("TutorialDone"):FireServer()
	end

	-- Después del tutorial se elige la dificultad, salvo que otro jugador ya la haya elegido.
	local choosing = false
	local function finish()
		if workspace:GetAttribute("DifficultyChosen") then
			close()
			return
		end
		choosing = true
		title.Text = "Elegí la dificultad"
		body.Text = "N: Normal\n\nH: Difícil, con la mitad de píldoras, pilas y tasers escondidos"
		footer.Text = "Apretá N o H para empezar"
	end

	UserInputService.InputBegan:Connect(function(input)
		if finished then
			return
		end
		if choosing then
			if input.KeyCode == Enum.KeyCode.N or input.KeyCode == Enum.KeyCode.H then
				local choice = if input.KeyCode == Enum.KeyCode.H then "hard" else "normal"
				Remotes.get("SetDifficulty"):FireServer(choice)
				close()
			end
		elseif input.KeyCode == Enum.KeyCode.Q then
			finish()
		elseif input.KeyCode == Enum.KeyCode.Space then
			page += 1
			if page > #PAGES then
				finish()
			else
				show()
			end
		end
	end)

	show()
end

return Tutorial
