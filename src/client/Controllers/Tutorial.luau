--!strict
-- Tutorial al entrar: Espacio avanza y Q lo omite. Mientras está abierto, el servidor te protege.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local PAGES = {
	{
		title = "Controles",
		body = "W A S D: moverte\nMouse: mirar\nShift izquierdo: correr (gasta la barra amarilla y se recupera al dejar de correr)\nC o Ctrl: agacharte (más bajo y silencioso, para esconderte detrás de los muebles)\nE: agarrar objetos, abrir puertas y usar la estatua\n1 y 2: sacar el taser o la linterna\n3: usar el botiquín que llevás\nClic: disparar el taser\nClic derecho: prender o apagar la linterna",
	},
	{
		title = "Cómo escapar",
		body = "1. Buscá las llaves de colores: cada una abre la puerta de su mismo color.\n2. Las llaves se alternan: la roja abre la gran escalera, y cada llave siguiente te hace cambiar de piso.\n3. La llave negra es la última: abre el sótano, en la cocina. Ahí está la escalera de mano.\n4. Poné la escalera bajo la trampilla del primer piso para subir al cobertizo.\n5. Los 4 pergaminos están en cajas fuertes de las paredes. Cada una pide un código de 3 cifras que está escrito en una nota escondida por la casa.\n6. Llevalos a la estatua de lobo, en la sala del fondo del sótano: te da la llave dorada.\n7. Abrí con ella la puerta del túnel, en esa misma sala, y escapá. La puerta principal se cierra al entrar: por ahí ya no se sale.",
	},
	{
		title = "Cómo sobrevivir",
		body = "El asesino te mata con 3 golpes. En el piso de arriba anda otro, de smoking: es más lento, pero con 2 golpes te mata. Abajo hay dos carniceros con máscara de chancho: son rápidos, recorren todo el sótano y suben por la escalera hasta la cocina (no salen de ahí) y te matan con 5 golpes.\nLos botiquines curan 75 de vida y las vendas 25.\nEl taser lo deja quieto 10 segundos. Llevás uno solo y desaparece al usarlo.\nLa linterna está sobre la mesita del hall, entre las escaleras. Gasta batería: buscá pilas.\nNo hay zonas seguras: el asesino puede entrar a cualquier pieza.\nEl asesino te oye si corrés cerca; agachado casi no hace ruido.\nSi estás lejos mucho tiempo, sale a buscarte.\nCada asesino ve en un cono delante suyo (se nota por su luz roja): quedate fuera del cono o agachate detrás de un mueble y no te ve.\nHay gemas escondidas: juntalas y gastalas en la tienda del lobby.\nEl asesino solo cruza las puertas que ya abriste: cada puerta nueva le abre camino.\nSi te mata, la partida vuelve a empezar de cero.",
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

	-- La dificultad se elige en el lobby, antes de entrar a la mansión.
	local function finish()
		close()
	end

	UserInputService.InputBegan:Connect(function(input)
		if finished then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
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
