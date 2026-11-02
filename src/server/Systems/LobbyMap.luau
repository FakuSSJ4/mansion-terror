--!strict
-- El lobby: una cabaña cálida y luminosa, lo opuesto a la mansión. Madera clara, chimenea, sillones,
-- faroles, plantas y ventanales al atardecer. Tiene 4 círculos para armar partidas (cada uno con su
-- consola de dificultad y de cantidad de jugadores) y una tienda donde se gastan las gemas.
-- Se arma lejos de la mansión; el cliente cambia la luz del mundo cuando el jugador está acá.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Courtyard = require(script.Parent:WaitForChild("Courtyard"))

local LobbyMap = {}

export type Pad = {
	center: Vector3,
	radius: number,
	color: Color3,
	label: TextLabel,
	difficultyPrompt: ProximityPrompt,
	playersPrompt: ProximityPrompt,
}

export type Stall = { id: string, prompt: ProximityPrompt, label: TextLabel }

export type Refs = {
	origin: Vector3,
	spawns: { SpawnLocation },
	pads: { Pad },
	stalls: { Stall },
}

-- El lobby es el patio delantero de la mansión: se arma alrededor de la fuente.
LobbyMap.Origin = Vector3.new(Courtyard.CenterX, 0, Courtyard.CenterZ)

local WOOD_LIGHT = Color3.fromRGB(184, 134, 88)
local WOOD_MID = Color3.fromRGB(140, 96, 60)
local WOOD_DARK = Color3.fromRGB(94, 62, 40)
local CREAM = Color3.fromRGB(246, 236, 214)
local WARM = Color3.fromRGB(255, 206, 150)
local TEXT = Color3.fromRGB(70, 44, 28)

local PAD_COLORS = {
	Color3.fromRGB(255, 140, 120),
	Color3.fromRGB(120, 220, 170),
	Color3.fromRGB(130, 190, 255),
	Color3.fromRGB(255, 218, 110),
}

function LobbyMap.build(): Refs
	local origin = LobbyMap.Origin
	local model = Instance.new("Model")
	model.Name = "Lobby"

	local function part(props: { [string]: any }): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for key, value in props do
			(p :: any)[key] = value
		end
		if props.Position then
			p.Position = origin + props.Position
		elseif props.CFrame then
			p.CFrame = CFrame.new(origin) * props.CFrame
		end
		p.Parent = model
		return p
	end
	-- Decorativa: no choca ni molesta a nada.
	local function deco(props: { [string]: any }): Part
		props.CanCollide = false
		props.CanQuery = false
		props.CastShadow = false
		return part(props)
	end
	local function light(parent: Instance, range: number, brightness: number, color: Color3?)
		local l = Instance.new("PointLight")
		l.Color = color or WARM
		l.Range = range
		l.Brightness = brightness
		l.Shadows = false
		l.Parent = parent
	end
	local function disc(
		name: string,
		position: Vector3,
		diameter: number,
		height: number,
		color: Color3,
		material: Enum.Material,
		collide: boolean?
	): Part
		return part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, diameter, diameter),
			CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = material,
			CanCollide = collide ~= false,
		})
	end
	local function billboard(
		position: Vector3,
		size: Vector2,
		text: string,
		textColor: Color3,
		textSize: number
	): TextLabel
		local anchor = deco({
			Name = "Cartel",
			Size = Vector3.new(0.4, 0.4, 0.4),
			Position = position,
			Transparency = 1,
		})
		local gui = Instance.new("BillboardGui")
		-- Tamaño en studs (no en pixeles): se achica con la distancia y no se pisan entre sí.
		gui.Size = UDim2.fromScale(size.X, size.Y)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		gui.Parent = anchor
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = CREAM
		back.BackgroundTransparency = 0.08
		back.BorderSizePixel = 0
		back.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = back
		local stroke = Instance.new("UIStroke")
		stroke.Color = WOOD_MID
		stroke.Thickness = 3
		stroke.Parent = back
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -16, 1, -8)
		label.Position = UDim2.fromOffset(8, 4)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextSize = textSize
		label.TextColor3 = textColor
		label.TextWrapped = true
		label.Text = text
		label.Parent = back
		return label
	end

	-- Cartel de bienvenida, sobre el camino que lleva a la puerta.
	billboard(
		Vector3.new(0, 13, 13),
		Vector2.new(18, 3.6),
		"Mansión de Terror\nElegí un círculo para armar tu partida",
		TEXT,
		26
	)

	-- El agua de la fuente, de fondo.
	local water = deco({
		Name = "SonidoFuente",
		Size = Vector3.one,
		Position = Vector3.new(0, 3, 0),
		Transparency = 1,
	})
	local waterSound = Instance.new("Sound")
	waterSound.SoundId = Sounds.Fountain
	waterSound.Looped = true
	waterSound.Volume = 0.5
	waterSound.RollOffMinDistance = 12
	waterSound.RollOffMaxDistance = 50
	waterSound.Parent = water
	waterSound:Play()
	-- Fuera del modelo del lobby: el agua sigue sonando cuando los círculos se ocultan.

	-- Guirnaldas de lucecitas cálidas entre los faroles: lo que hace acogedor el patio.
	for _, z in { 18.5, -17.5 } do
		for i = 0, 24 do
			local alpha = i / 24
			local x = -24 + alpha * 48
			local sag = 3.2 * math.sin(alpha * math.pi)
			local bulb = deco({
				Name = "Lucecita",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.6,
				Position = Vector3.new(x, 14.6 - sag, z),
				Color = WARM,
				Material = Enum.Material.Neon,
			})
			if i % 4 == 0 then
				light(bulb, 14, 0.5)
			end
		end
	end

	-- Bancos de madera a los costados del camino, de cara a la fuente.
	for _, z in { 24, -28 } do
		for _, side in { -1, 1 } do
			local x = side * 14
			part({
				Name = "Banco",
				Size = Vector3.new(1.6, 0.5, 6),
				Position = Vector3.new(x, 1.5, z),
				Color = WOOD_LIGHT,
				Material = Enum.Material.WoodPlanks,
			})
			part({
				Name = "RespaldoBanco",
				Size = Vector3.new(0.4, 1.8, 6),
				Position = Vector3.new(x + side * 0.8, 2.6, z),
				Color = WOOD_MID,
				Material = Enum.Material.WoodPlanks,
			})
			for _, end_ in { -2.4, 2.4 } do
				part({
					Name = "PataBanco",
					Size = Vector3.new(1.2, 1.3, 0.4),
					Position = Vector3.new(x, 0.85, z + end_),
					Color = WOOD_DARK,
					Material = Enum.Material.Wood,
				})
			end
		end
	end

	-- Cuatro círculos de partida sobre el lado oeste del patio.
	local pads: { Pad } = {}
	local padZ = { -24, -8, 8, 24 }
	for index, z in padZ do
		local color = PAD_COLORS[index]
		local center = Vector3.new(-30, 0, z)
		disc(
			`Base_{index}`,
			center + Vector3.new(0, 0.3, 0),
			13,
			0.6,
			WOOD_DARK,
			Enum.Material.Wood
		)
		disc(
			`Aro_{index}`,
			center + Vector3.new(0, 0.62, 0),
			12,
			0.1,
			color,
			Enum.Material.Neon,
			false
		)
		disc(
			`Centro_{index}`,
			center + Vector3.new(0, 0.68, 0),
			10.4,
			0.1,
			CREAM,
			Enum.Material.SmoothPlastic,
			false
		)
		disc(
			`Marca_{index}`,
			center + Vector3.new(0, 0.74, 0),
			5,
			0.1,
			color:Lerp(CREAM, 0.35),
			Enum.Material.SmoothPlastic,
			false
		)
		local glow = deco({
			Name = "LuzCirculo",
			Size = Vector3.new(1, 1, 1),
			Position = center + Vector3.new(0, 2, 0),
			Transparency = 1,
		})
		light(glow, 18, 0.8, color)
		-- Cartel flotante con el estado de la partida.
		local label = billboard(
			center + Vector3.new(0, 10.5, 0),
			Vector2.new(8.5, 3.6),
			`Partida {index}`,
			TEXT,
			22
		)
		-- Atril con las dos consolas: dificultad (E) y cantidad de jugadores (F).
		local deskPos = center + Vector3.new(7.8, 0, 4)
		part({
			Name = "Atril",
			Size = Vector3.new(2.4, 3.4, 2),
			Position = deskPos + Vector3.new(0, 1.7, 0),
			Color = WOOD_MID,
			Material = Enum.Material.Wood,
		})
		part({
			Name = "TapaAtril",
			Size = Vector3.new(3, 0.4, 2.6),
			CFrame = CFrame.new(deskPos + Vector3.new(0, 3.5, 0))
				* CFrame.Angles(math.rad(-14), 0, 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
		})
		local difficulty = Instance.new("ProximityPrompt")
		difficulty.ActionText = "Elegir dificultad"
		difficulty.ObjectText = `Partida {index}`
		difficulty.KeyboardKeyCode = Enum.KeyCode.E
		difficulty.MaxActivationDistance = 9
		difficulty.RequiresLineOfSight = false
		difficulty.UIOffset = Vector2.new(0, -40)
		difficulty.Parent = part({
			Name = "ConsolaDificultad",
			Size = Vector3.new(0.6, 0.6, 0.6),
			Position = deskPos + Vector3.new(0, 4, 0),
			Transparency = 1,
			CanCollide = false,
		})
		local players = Instance.new("ProximityPrompt")
		players.ActionText = "Cambiar jugadores"
		players.ObjectText = `Partida {index}`
		players.KeyboardKeyCode = Enum.KeyCode.F
		players.MaxActivationDistance = 9
		players.RequiresLineOfSight = false
		players.UIOffset = Vector2.new(0, 40)
		players.Parent = part({
			Name = "ConsolaJugadores",
			Size = Vector3.new(0.6, 0.6, 0.6),
			Position = deskPos + Vector3.new(0, 4.2, 0),
			Transparency = 1,
			CanCollide = false,
		})
		table.insert(pads, {
			center = origin + center,
			radius = 6,
			color = color,
			label = label,
			difficultyPrompt = difficulty,
			playersPrompt = players,
		})
	end

	-- Tienda contra la pared este: mostrador, toldo a rayas y dos productos con su cartel.
	local stalls: { Stall } = {}
	local shopX = 33
	part({
		Name = "Mostrador",
		Size = Vector3.new(5, 4, 28),
		Position = Vector3.new(shopX, 2, 4),
		Color = WOOD_MID,
		Material = Enum.Material.Wood,
	})
	part({
		Name = "TapaMostrador",
		Size = Vector3.new(6, 0.5, 29),
		Position = Vector3.new(shopX, 4.25, 4),
		Color = WOOD_LIGHT,
		Material = Enum.Material.WoodPlanks,
	})
	for i = 0, 13 do
		deco({
			Name = "Toldo",
			Size = Vector3.new(7, 0.5, 2.2),
			CFrame = CFrame.new(Vector3.new(shopX + 0.4, 13.6 - i * 0.02, -9.2 + i * 2.2 + 1.1))
				* CFrame.Angles(0, 0, math.rad(8)),
			Color = if i % 2 == 0 then Color3.fromRGB(214, 80, 70) else CREAM,
			Material = Enum.Material.Fabric,
		})
	end
	for _, z in { -10, 18 } do
		deco({
			Name = "PosteToldo",
			Size = Vector3.new(0.8, 13.6, 0.8),
			Position = Vector3.new(shopX - 2.4, 6.8, z),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
		})
	end
	billboard(Vector3.new(shopX - 1, 17, 4), Vector2.new(14, 3.4), "Tienda de ventajas", TEXT, 28)
	local products = {
		{ id = "armor", z = -2 },
		{ id = "stamina", z = 10 },
	}
	for _, product in products do
		local item = Config.Shop[product.id]
		local at = Vector3.new(shopX, 4.5, product.z)
		-- Pedestal y objeto en exhibición.
		disc("Pedestal", at + Vector3.new(0, 0.4, 0), 4, 0.8, WOOD_DARK, Enum.Material.Wood, false)
		if product.id == "armor" then
			-- Peto de metal con hombreras y un brillo celeste.
			deco({
				Name = "Peto",
				Size = Vector3.new(2.6, 3, 1.4),
				Position = at + Vector3.new(0, 2.6, 0),
				Color = Color3.fromRGB(170, 180, 196),
				Material = Enum.Material.Metal,
			})
			for _, side in { -1, 1 } do
				deco({
					Name = "Hombrera",
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(1.4, 1.2, 1.4),
					Position = at + Vector3.new(side * 1.7, 3.8, 0),
					Color = Color3.fromRGB(190, 198, 212),
					Material = Enum.Material.Metal,
				})
			end
			deco({
				Name = "EscudoPeto",
				Size = Vector3.new(0.4, 1.4, 0.2),
				Position = at + Vector3.new(0, 2.8, 0.75),
				Color = Color3.fromRGB(110, 200, 255),
				Material = Enum.Material.Neon,
			})
		else
			-- Poción verde con corcho: la barra de estamina.
			local liquid = deco({
				Name = "Pocion",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 2.4,
				Position = at + Vector3.new(0, 2.2, 0),
				Color = Color3.fromRGB(110, 230, 140),
				Material = Enum.Material.Neon,
			})
			deco({
				Name = "Cuello",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.6, 0.8, 0.8),
				CFrame = CFrame.new(at + Vector3.new(0, 3.9, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(190, 230, 210),
				Material = Enum.Material.Glass,
				Transparency = 0.4,
			})
			deco({
				Name = "Corcho",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.6, 0.9, 0.9),
				CFrame = CFrame.new(at + Vector3.new(0, 4.9, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(190, 150, 100),
				Material = Enum.Material.Wood,
			})
			light(liquid, 10, 0.6, Color3.fromRGB(120, 255, 160))
		end
		local label =
			billboard(at + Vector3.new(-1, 7, 0), Vector2.new(12, 5.4), item.name, TEXT, 20)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Comprar"
		prompt.ObjectText = `{item.name} ({item.price} gemas)`
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = deco({
			Name = "PuntoCompra",
			Size = Vector3.new(1, 1, 1),
			Position = at + Vector3.new(0, 2.5, 0),
			Transparency = 1,
		})
		table.insert(stalls, { id = product.id, prompt = prompt, label = label })
	end

	-- Dónde aparecen los jugadores: junto a la alfombra, mirando a los círculos.
	local spawns: { SpawnLocation } = {}
	for i = 1, 6 do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = `SpawnLobby{i}`
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Size = Vector3.new(4, 0.2, 4)
		spawn.Position = origin + Vector3.new((i - 3.5) * 3.6, 0.35, 20)
		spawn.Parent = model
		table.insert(spawns, spawn)
	end

	water.Parent = workspace
	model.Parent = workspace
	return { origin = origin, spawns = spawns, pads = pads, stalls = stalls }
end

return LobbyMap
