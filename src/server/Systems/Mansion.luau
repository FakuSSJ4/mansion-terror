--!strict
-- Genera la mansión por código: planta baja, sótano, primer piso y altillo sobre una grilla.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapDef = require(Shared:WaitForChild("Rules"):WaitForChild("MapDef"))
local Placement = require(Shared:WaitForChild("Rules"):WaitForChild("Placement"))
local Routes = require(Shared:WaitForChild("Rules"):WaitForChild("Routes"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local Courtyard = require(script.Parent:WaitForChild("Courtyard"))
local GrandHall = require(script.Parent:WaitForChild("GrandHall"))

-- Cada pieza mide 68 de lado (antes 56): un 47% más de piso.
local ROOM_SIZE = 68
local HALF = ROOM_SIZE / 2
local LEVEL_HEIGHT = 20
local CEILING = 18
-- Distancia entre centros de piezas vecinas: la pieza más 24 de pasillo.
local CORRIDOR_GAP = 24
local PITCH = ROOM_SIZE + CORRIDOR_GAP
local WALL = 1
local CORRIDOR_WIDTH = 12
local DOOR_WIDTH = 10
local DOOR_HEIGHT = 12
local CORRIDOR_HEIGHT = DOOR_HEIGHT + 2
local REFUGE_WIDTH = 24
local REFUGE_DEPTH = 18
local RAIN_SLANT_DEGREES = 24

local CELLAR_Y = -LEVEL_HEIGHT
local GROUND_Y = 0
local UPPER_Y = LEVEL_HEIGHT
local ATTIC_Y = 2 * LEVEL_HEIGHT

-- La escalera ocupa este rectángulo, separada de la pared oeste para poder rodearla, subiendo hacia +Z.
local STAIR = { x0 = -20, x1 = -4, z0 = -18, z1 = 20 }
-- Trampilla del altillo, contra el lado sur.
local HATCH = { x0 = -5, x1 = 5, z0 = 14, z1 = 24 }

local WALL_COLOR = Color3.fromRGB(205, 205, 198)
local FLOOR_COLOR = Color3.fromRGB(98, 30, 26)
local CEILING_COLOR = Color3.fromRGB(58, 34, 20)
local WOOD_COLOR = Color3.fromRGB(52, 33, 22)
local FABRIC_COLOR = Color3.fromRGB(70, 40, 42)
local GOLD_COLOR = Color3.fromRGB(170, 135, 60)
local CANDLE_LIGHT = Color3.fromRGB(255, 222, 190)
local REFUGE_LIGHT = Color3.fromRGB(120, 170, 255)

type RoomPlan = { col: number, row: number, y: number }
type Hole = { x0: number, x1: number, z0: number, z1: number }
type Opening = { width: number, bottom: number, top: number }

local WEST_WING_COL = -1.8
local WEST_WING = { gameRoom = true, bar = true }
-- Tramo que alarga el sótano hacia el este; más bajo que la pieza, porque arriba está el pasto.
local CELLAR_WING_LENGTH = 56
local CELLAR_WING_HEIGHT = 14.5
-- Sala del lobo, al fondo del sótano, y el túnel de fuga que sale de ella.
local WOLF_ROOM_LENGTH = 44
local TUNNEL_FLAT = 36
local TUNNEL_WIDTH = 12
local TUNNEL_HEIGHT = 12
local TUNNEL_STEPS = 20
local TUNNEL_STEP_RUN = 2

local PLAN: { [string]: RoomPlan } = {
	hall = { col = 0, row = 0, y = GROUND_Y },
	room1 = { col = 1, row = 0, y = GROUND_Y }, -- Living
	room2 = { col = 2, row = 0, y = GROUND_Y }, -- Comedor
	room3 = { col = 2, row = 1, y = GROUND_Y }, -- Sala de música
	room4 = { col = 1, row = 1, y = GROUND_Y }, -- Cocina
	room5 = { col = 1, row = 1, y = CELLAR_Y },
	room6 = { col = 2, row = 1, y = CELLAR_Y },
	room7 = { col = 0, row = 0, y = UPPER_Y },
	room8 = { col = 1, row = 0, y = UPPER_Y }, -- Dormitorio
	room9 = { col = 2, row = 0, y = UPPER_Y },
	room10 = { col = 2, row = 1, y = UPPER_Y },
	room11 = { col = 1, row = 1, y = UPPER_Y },
	room12 = { col = 0, row = 1, y = UPPER_Y },
	attic = { col = 0, row = 1, y = ATTIC_Y },
	-- Ala oeste: su pared este queda a un pasillo de la del hall, que no sigue la grilla.
	gameRoom = { col = WEST_WING_COL, row = 0, y = GROUND_Y },
	bar = { col = WEST_WING_COL, row = 0, y = UPPER_Y },
}

-- Pasillos, puertas con llave y a qué pieza cuelga cada refugio salen de MapDef.
local LINKS = MapDef.corridors()

-- Qué pasillos están tapiados y dónde va cada puerta con llave en esta partida (se sortea).
local currentLayout: MapDef.Layout = MapDef.DefaultLayout
-- Centro y orientación de cada pasillo, para poder poner o sacar puertas y tablones entre partidas.
local corridorSpots: { [string]: { middle: Vector3, across: Vector3 } } = {}
local corridorDoorFolders: { [string]: Folder } = {}
local corridorBarrierFolders: { [string]: Folder } = {}

-- Hacia dónde mira la salida de cada refugio; la pieza viene de MapDef.
-- Todos hacia el norte: las paredes sur de las piezas 1 y 8 llevan un pasillo a la 4 y a la 11.
local REFUGE_DIRS = {
	refuge1 = Vector3.new(0, 0, -1),
	refuge2 = Vector3.new(0, 0, -1),
	refuge3 = Vector3.new(0, 0, -1),
}
local REFUGES: { [string]: { room: string, dir: Vector3 } } = {}
for id, room in MapDef.Refuges do
	REFUGES[id] = { room = room, dir = REFUGE_DIRS[id] }
end
local FLOOR_HOLES: { [string]: Hole } = { room4 = STAIR, attic = HATCH }
local CEILING_HOLES: { [string]: Hole } = { room5 = STAIR, room12 = HATCH }
local STAIR_ROOMS = { room4 = true, room5 = true }
local CHANDELIER_ROOMS =
	{ room1 = true, room2 = true, room8 = true, room10 = true, gameRoom = true, bar = true }
-- Los construye GrandHall.
local GRAND_ROOMS = { hall = true, room7 = true }

export type Door = {
	leaves: { { part: BasePart, closed: CFrame, open: CFrame } },
	blocker: BasePart,
	position: Vector3,
	-- La otra reja de la escalera imperial: se abren juntas.
	twin: any,
	unlocked: boolean,
	swung: boolean,
	prompt: ProximityPrompt,
	-- Eje fino de las hojas: hacia dónde se sacuden con un golpe.
	normal: Vector3,
	-- Puerta de hierro: al abrirse suena distinto que una de madera.
	metal: boolean,
}

export type Tunnel = {
	door: Vector3,
	out: Vector3,
	stairStart: Vector3,
	exit: Vector3,
	floorY: number,
}

export type MansionRefs = {
	-- `box` es el centro del rectángulo cuando no coincide con `center`.
	rooms: { [string]: { center: Vector3, size: Vector3, box: Vector3? } },
	doors: { [string]: Door },
	routes: { [string]: { Vector3 } },
	hidingSpots: { [string]: { Vector3 } },
	refugeDoors: { [string]: Vector3 },
	taserPedestal: BasePart,
	exitZone: BasePart,
	hatchPoint: BasePart,
	-- Dónde aparecen los jugadores al empezar la partida.
	spawns: { SpawnLocation },
	ladderCFrame: CFrame,
	ladderSize: Vector3,
	flashlightSpot: Vector3,
	-- Túnel de fuga: la puerta (al piso), hacia dónde sigue, el pie de la escalera y la salida al bosque.
	tunnel: Tunnel,
	-- Habitaciones con código: la puerta, y dónde queda el pergamino de adentro.
	vaults: { { room: string, scrollSpot: Vector3, door: Door } },
	altar: {
		prompt: ProximityPrompt,
		drawer: BasePart,
		closedCFrame: CFrame,
		openCFrame: CFrame,
		position: Vector3,
		keySpot: Vector3,
	},
}

local Mansion = {}

local world: Model
local refs: MansionRefs

-- Sonido en el espacio: se oye más fuerte cuanto más cerca está el jugador de `parent`.
local function makeSoundAt(parent: BasePart, id: string, volume: number, range: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = range
	sound.Parent = parent
	return sound
end

-- Suena una vez desde `parent` y se borra solo.
local function playAt(parent: BasePart, id: string, volume: number)
	local sound = makeSoundAt(parent, id, volume, 90)
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Suena en bucle desde `parent`.
local function loopAt(parent: BasePart, id: string, volume: number, range: number)
	local sound = makeSoundAt(parent, id, volume, range)
	sound.Looped = true
	sound:Play()
end

-- Mientras vale, lo que se arma va a esta carpeta en vez de ir directo al mundo.
local buildParent: Instance? = nil
-- Variantes de cada partida: se arman todas y se muestra una; los muebles se rearman.
local animalFolders: { [string]: Folder } = {}
local headFolders: { [string]: { [string]: Folder } } = {}
local furnitureFolders: { [string]: Folder } = {}
local furnishedCount: { [string]: number } = {}
local extraSpots: { [string]: { Vector3 } } = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = props.Parent or buildParent or world
	return p
end

-- Arma con `build` todo dentro de una carpeta nueva, que queda sin padre (oculta).
local function inFolder(name: string, build: () -> ()): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	local previous = buildParent
	buildParent = folder
	build()
	buildParent = previous
	return folder
end

-- Pieza decorativa: no choca ni molesta a los rayos de línea de vista.
local function decor(props: { [string]: any }): Part
	props.CanCollide = false
	props.CanQuery = false
	props.CastShadow = false
	return part(props)
end

local function cellCenter(id: string): Vector3
	local plan = PLAN[id]
	-- La columna 0 es el hall; las demás arrancan a un pasillo de su pared este, y el ala oeste a un
	-- pasillo de su pared oeste (el hall no cambia de tamaño al agrandar las piezas).
	local x
	if WEST_WING[id] then
		x = GrandHall.X0 - CORRIDOR_GAP - HALF
	elseif plan.col >= 1 then
		x = GrandHall.X1 + CORRIDOR_GAP + HALF + (plan.col - 1) * PITCH
	else
		x = plan.col * PITCH
	end
	return Vector3.new(x, plan.y, plan.row * PITCH)
end

local function addRoute(a: string, b: string, points: { Vector3 })
	local forward, backward = Routes.both(points, cellCenter(a), cellCenter(b))
	refs.routes[`{a}>{b}`] = forward
	refs.routes[`{b}>{a}`] = backward
end

-- Pared de `length` centrada en `center` a lo largo de `along`, con un hueco central opcional.
local function wall(center: Vector3, along: Vector3, length: number, height: number, hole: Opening?)
	local function segment(offset: number, size: number, bottom: number, top: number)
		if size <= 0 or top <= bottom then
			return
		end
		local sizeVector = if math.abs(along.X) > 0
			then Vector3.new(size, top - bottom, WALL)
			else Vector3.new(WALL, top - bottom, size)
		part({
			Name = "Pared",
			Size = sizeVector,
			Position = center + along * offset + Vector3.new(0, (bottom + top) / 2, 0),
			Color = WALL_COLOR,
			Material = Enum.Material.Concrete,
		})
	end

	if not hole then
		segment(0, length, 0, height)
		return
	end
	local side = (length - hole.width) / 2
	segment(-(hole.width + side) / 2, side, 0, height)
	segment((hole.width + side) / 2, side, 0, height)
	segment(0, hole.width, hole.top, height)
	segment(0, hole.width, 0, hole.bottom)
end

-- Placa cuadrada de piso o techo, opcionalmente con un agujero rectangular.
local function plate(
	center: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	hole: Hole?
)
	local function rect(x0: number, x1: number, z0: number, z1: number)
		if x1 - x0 <= 0 or z1 - z0 <= 0 then
			return
		end
		part({
			Name = "Placa",
			Size = Vector3.new(x1 - x0, thickness, z1 - z0),
			Position = center + Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2),
			Color = color,
			Material = material,
		})
	end
	if not hole then
		rect(-HALF, HALF, -HALF, HALF)
		return
	end
	rect(-HALF, hole.x0, -HALF, HALF)
	rect(hole.x1, HALF, -HALF, HALF)
	rect(hole.x0, hole.x1, -HALF, hole.z0)
	rect(hole.x0, hole.x1, hole.z1, HALF)
end

local function candle(position: Vector3, lightColor: Color3)
	if not Config.CandlesLit then
		return
	end
	decor({
		Name = "Vela",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.1, 0.35, 0.35),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(225, 215, 190),
		Material = Enum.Material.SmoothPlastic,
	})
	local flame = decor({
		Name = "Llama",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.3, 0.45, 0.3),
		Position = position + Vector3.new(0, 0.75, 0),
		Color = lightColor,
		Material = Enum.Material.Neon,
	})
	flame:AddTag("CandleFlame")
	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Range = 26
	light.Brightness = 0.3
	light.Shadows = true
	light.Parent = flame
end

local function chandelier(center: Vector3, grand: boolean?)
	local top = center + Vector3.new(0, CEILING, 0)
	decor({
		Name = "Cadena",
		Size = Vector3.new(0.25, 3, 0.25),
		Position = top - Vector3.new(0, 1.5, 0),
		Color = GOLD_COLOR,
		Material = Enum.Material.Metal,
	})
	decor({
		Name = "Candelabro",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 5, 5),
		CFrame = CFrame.new(top - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GOLD_COLOR,
		Material = Enum.Material.Metal,
	})
	if not Config.CandlesLit then
		return
	end
	for i = 1, 4 do
		local angle = i * math.pi / 2
		decor({
			Name = "Llama",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.3, 0.45, 0.3),
			Position = top + Vector3.new(math.cos(angle) * 2.2, -2.4, math.sin(angle) * 2.2),
			Color = CANDLE_LIGHT,
			Material = Enum.Material.Neon,
		})
	end
	local core = decor({
		Name = "Llama",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = top - Vector3.new(0, 3.6, 0),
		Transparency = 1,
	})
	core:AddTag("CandleFlame")
	-- El del hall alumbra un ambiente enorme: llega más lejos y no se apaga con la distancia.
	core:SetAttribute("NoFade", grand == true)
	local light = Instance.new("PointLight")
	light.Color = CANDLE_LIGHT
	light.Range = if grand then 60 else 34
	light.Brightness = 0.3
	light.Parent = core
end

-- Cuadro medieval armado con piezas; `inward` apunta hacia adentro de la pieza.
local function painting(position: Vector3, inward: Vector3, kind: number)
	local base = CFrame.lookAt(position, position + inward)
	decor({
		Name = "Marco",
		Size = Vector3.new(8, 6, 0.3),
		CFrame = base,
		Color = GOLD_COLOR,
		Material = Enum.Material.Metal,
	})
	local function paint(x: number, y: number, w: number, h: number, color: Color3, depth: number?)
		decor({
			Name = "Pintura",
			Size = Vector3.new(w, h, 0.05),
			CFrame = base * CFrame.new(x, y, -0.18 - (depth or 0)),
			Color = color,
			Material = Enum.Material.Fabric,
		})
	end
	local sky = Color3.fromRGB(60, 70, 88)
	local stone = Color3.fromRGB(95, 92, 88)
	if kind == 1 then -- Castillo
		paint(0, 0, 7.2, 5.2, sky)
		paint(0, -2, 7.2, 1.2, Color3.fromRGB(44, 60, 40), 0.03)
		paint(0, -0.5, 3, 2, stone, 0.03)
		paint(-1.8, 0, 0.9, 3, stone, 0.03)
		paint(1.8, 0, 0.9, 3, stone, 0.03)
		paint(0, -1, 0.8, 1, Color3.fromRGB(20, 16, 14), 0.06)
	elseif kind == 2 then -- Caballero
		paint(0, 0, 7.2, 5.2, Color3.fromRGB(70, 28, 28))
		paint(0, -0.9, 2, 2.8, stone, 0.03)
		paint(0, 1, 1.1, 1.2, stone, 0.03)
		paint(0, 1.05, 0.8, 0.14, Color3.new(0, 0, 0), 0.06)
		paint(1.7, -0.5, 0.2, 3.6, Color3.fromRGB(190, 190, 195), 0.03)
		paint(1.7, 0.5, 1, 0.2, GOLD_COLOR, 0.06)
	else -- Escudo de armas
		paint(0, 0, 7.2, 5.2, Color3.fromRGB(28, 34, 62))
		paint(0, 0.3, 3, 3, GOLD_COLOR, 0.03)
		paint(0, -1.5, 1.8, 0.9, GOLD_COLOR, 0.03)
		paint(0, 0.3, 0.5, 2.8, Color3.fromRGB(110, 16, 18), 0.06)
		paint(0, 0.6, 2.6, 0.5, Color3.fromRGB(110, 16, 18), 0.06)
	end
end

local function rug(center: Vector3, width: number, depth: number, color: Color3)
	decor({
		Name = "Alfombra",
		Size = Vector3.new(width + 1.2, 0.06, depth + 1.2),
		Position = center + Vector3.new(0, 0.03, 0),
		Color = GOLD_COLOR,
		Material = Enum.Material.Fabric,
	})
	-- Orilla más oscura, campo del color elegido y un rombo dorado al centro.
	decor({
		Name = "Alfombra",
		Size = Vector3.new(width, 0.08, depth),
		Position = center + Vector3.new(0, 0.05, 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.35),
		Material = Enum.Material.Fabric,
	})
	decor({
		Name = "Alfombra",
		Size = Vector3.new(width - 3, 0.1, depth - 3),
		Position = center + Vector3.new(0, 0.06, 0),
		Color = color,
		Material = Enum.Material.Fabric,
	})
	local medallion = math.min(width, depth) * 0.3
	decor({
		Name = "Alfombra",
		Size = Vector3.new(medallion, 0.12, medallion),
		CFrame = CFrame.new(center + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = color:Lerp(GOLD_COLOR, 0.55),
		Material = Enum.Material.Fabric,
	})
	decor({
		Name = "Alfombra",
		Size = Vector3.new(medallion * 0.55, 0.14, medallion * 0.55),
		CFrame = CFrame.new(center + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = color:Lerp(Color3.new(0, 0, 0), 0.3),
		Material = Enum.Material.Fabric,
	})
end

local function solid(
	base: CFrame,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
)
	return part({
		Name = name,
		Size = size,
		CFrame = base * offset,
		Color = color,
		Material = material or Enum.Material.Wood,
	})
end

-- Muebles para las esquinas: reciben la base y devuelven sus escondites.
local FURNITURE: { [string]: (CFrame) -> { Vector3 } } = {
	wardrobe = function(base)
		solid(
			base,
			"Ropero",
			Vector3.new(7, 12, 3.5),
			CFrame.new(0, 6, 0),
			WOOD_COLOR,
			Enum.Material.WoodPlanks
		)
		return {
			(base * CFrame.new(0, 0.3, 3.2)).Position,
			(base * CFrame.new(-4.4, 0.3, 0)).Position,
		}
	end,
	table = function(base)
		solid(base, "Mesa", Vector3.new(9, 0.6, 5), CFrame.new(0, 3.3, 0), WOOD_COLOR)
		for _, x in { -4, 4 } do
			for _, z in { -2, 2 } do
				solid(base, "Pata", Vector3.new(0.5, 3, 0.5), CFrame.new(x, 1.5, z), WOOD_COLOR)
			end
		end
		return { (base * CFrame.new(-1, 0.3, 0)).Position, (base * CFrame.new(2, 3.85, 1)).Position }
	end,
	bookcase = function(base)
		solid(
			base,
			"Biblioteca",
			Vector3.new(10, 8, 2),
			CFrame.new(0, 4, 0),
			WOOD_COLOR,
			Enum.Material.WoodPlanks
		)
		return {
			(base * CFrame.new(3, 8.3, 0)).Position,
			(base * CFrame.new(-5.8, 0.3, 0.5)).Position,
		}
	end,
	bed = function(base)
		solid(
			base,
			"Cama",
			Vector3.new(6, 1, 10),
			CFrame.new(0, 2.2, 0),
			FABRIC_COLOR,
			Enum.Material.Fabric
		)
		for _, x in { -2.7, 2.7 } do
			for _, z in { -4.7, 4.7 } do
				solid(base, "Pata", Vector3.new(0.5, 1.7, 0.5), CFrame.new(x, 0.85, z), WOOD_COLOR)
			end
		end
		return {
			(base * CFrame.new(0, 0.3, 1)).Position,
			(base * CFrame.new(1.5, 2.95, -3)).Position,
		}
	end,
	chest = function(base)
		solid(base, "Baul", Vector3.new(5, 3, 3), CFrame.new(0, 1.5, 0), Color3.fromRGB(44, 30, 20))
		return {
			(base * CFrame.new(0, 3.3, 0)).Position,
			(base * CFrame.new(3.4, 0.3, 2.4)).Position,
		}
	end,
	sofa = function(base)
		local velvet = Color3.fromRGB(46, 28, 72)
		solid(
			base,
			"Sillon",
			Vector3.new(11, 1.8, 4),
			CFrame.new(0, 1.3, 0),
			velvet,
			Enum.Material.Fabric
		)
		solid(
			base,
			"Respaldo",
			Vector3.new(11, 3.5, 1),
			CFrame.new(0, 3, 1.6),
			velvet,
			Enum.Material.Fabric
		)
		for _, x in { -5.6, 5.6 } do
			solid(
				base,
				"Apoyabrazos",
				Vector3.new(1, 2.8, 4),
				CFrame.new(x, 1.9, 0),
				GOLD_COLOR,
				Enum.Material.Wood
			)
		end
		return {
			(base * CFrame.new(-3, 2.5, -0.5)).Position,
			(base * CFrame.new(0, 0.3, 3)).Position,
		}
	end,
	fireplace = function(base)
		local stone = Color3.fromRGB(120, 112, 104)
		solid(
			base,
			"Chimenea",
			Vector3.new(14, 11, 3),
			CFrame.new(0, 5.5, 1),
			stone,
			Enum.Material.Cobblestone
		)
		solid(
			base,
			"Hogar",
			Vector3.new(7, 5, 0.3),
			CFrame.new(0, 2.5, -0.6),
			Color3.new(0.02, 0.01, 0.01)
		)
		solid(base, "Repisa", Vector3.new(15, 0.6, 2), CFrame.new(0, 7, -1), WOOD_COLOR)
		return { (base * CFrame.new(4, 7.6, -1)).Position, (base * CFrame.new(-8, 0.3, 0)).Position }
	end,
	counter = function(base)
		solid(
			base,
			"Mesada",
			Vector3.new(16, 4, 3),
			CFrame.new(0, 2, 0),
			Color3.fromRGB(150, 145, 138),
			Enum.Material.Marble
		)
		solid(
			base,
			"Alacena",
			Vector3.new(16, 4, 1.6),
			CFrame.new(0, 10, 0.8),
			WOOD_COLOR,
			Enum.Material.WoodPlanks
		)
		return { (base * CFrame.new(-5, 4.3, 0)).Position, (base * CFrame.new(6, 0.3, -2)).Position }
	end,
	stove = function(base)
		solid(
			base,
			"Horno",
			Vector3.new(6, 5, 4),
			CFrame.new(0, 2.5, 0),
			Color3.fromRGB(32, 32, 34),
			Enum.Material.Metal
		)
		solid(
			base,
			"Puerta",
			Vector3.new(4.5, 2.4, 0.2),
			CFrame.new(0, 2, -2.05),
			Color3.fromRGB(70, 60, 50),
			Enum.Material.Metal
		)
		solid(
			base,
			"Olla",
			Vector3.new(2, 1.4, 2),
			CFrame.new(1, 5.7, 0),
			Color3.fromRGB(90, 62, 38),
			Enum.Material.Metal
		)
		return {
			(base * CFrame.new(-1.6, 5.3, 0)).Position,
			(base * CFrame.new(3.8, 0.3, 1)).Position,
		}
	end,
	doubleBed = function(base)
		local linen = Color3.fromRGB(120, 28, 36)
		local sheet = Color3.fromRGB(220, 215, 200)
		local dark = Color3.fromRGB(38, 24, 16)
		local fabric = Enum.Material.Fabric
		-- Bastidor de madera, colchón, sábana doblada y acolchado que cae por los costados.
		solid(
			base,
			"Bastidor",
			Vector3.new(11.6, 0.9, 13),
			CFrame.new(0, 1.4, 0),
			dark,
			Enum.Material.Wood
		)
		solid(base, "Colchon", Vector3.new(11, 1, 12.4), CFrame.new(0, 2.35, 0), sheet, fabric)
		solid(base, "Acolchado", Vector3.new(11.5, 0.5, 8.6), CFrame.new(0, 3, -1.9), linen, fabric)
		solid(
			base,
			"SabanaDoblada",
			Vector3.new(11.55, 0.55, 1.4),
			CFrame.new(0, 3.05, 2),
			sheet,
			fabric
		)
		for _, x in { -5.75, 5.75 } do
			solid(
				base,
				"CaidaAcolchado",
				Vector3.new(0.25, 2, 8.6),
				CFrame.new(x, 2, -1.9),
				linen,
				fabric
			)
		end
		solid(base, "CaidaPie", Vector3.new(11.5, 2, 0.25), CFrame.new(0, 2, -6.2), linen, fabric)
		-- Cabecera tallada con tres paneles y piecera más baja.
		solid(
			base,
			"Cabecera",
			Vector3.new(12.4, 6.5, 0.7),
			CFrame.new(0, 3.25, 6.7),
			dark,
			Enum.Material.Wood
		)
		for _, x in { -4, 0, 4 } do
			solid(
				base,
				"PanelCabecera",
				Vector3.new(3.4, 3.8, 0.15),
				CFrame.new(x, 4.3, 6.3),
				WOOD_COLOR,
				Enum.Material.Wood
			)
		end
		solid(
			base,
			"Piecera",
			Vector3.new(12.4, 3.2, 0.5),
			CFrame.new(0, 1.6, -6.7),
			dark,
			Enum.Material.Wood
		)
		-- Dos almohadas y un almohadón, y postes con remate dorado en las cuatro esquinas.
		for _, x in { -2.8, 2.8 } do
			solid(
				base,
				"Almohada",
				Vector3.new(4.2, 0.9, 2.4),
				CFrame.new(x, 3.3, 4.6),
				sheet,
				fabric
			)
		end
		solid(base, "Almohadon", Vector3.new(2.6, 0.8, 1.4), CFrame.new(0, 3.5, 3.4), linen, fabric)
		for _, x in { -6, 6 } do
			for _, post in { { 6.7, 8 }, { -6.7, 5 } } do
				solid(
					base,
					"Poste",
					Vector3.new(0.7, post[2], 0.7),
					CFrame.new(x, post[2] / 2, post[1]),
					dark,
					Enum.Material.Wood
				)
				solid(
					base,
					"Remate",
					Vector3.new(0.8, 0.8, 0.8),
					CFrame.new(x, post[2] + 0.2, post[1]),
					GOLD_COLOR,
					Enum.Material.Metal
				)
			end
		end
		return { (base * CFrame.new(0, 0.3, 0)).Position, (base * CFrame.new(2, 3.2, -3)).Position }
	end,
	nightstand = function(base)
		solid(base, "MesaDeLuz", Vector3.new(4, 3, 3), CFrame.new(0, 1.5, 0), WOOD_COLOR)
		solid(
			base,
			"Florero",
			Vector3.new(0.9, 1.6, 0.9),
			CFrame.new(-1, 3.8, 0),
			GOLD_COLOR,
			Enum.Material.Marble
		)
		return {
			(base * CFrame.new(0.8, 3.3, 0)).Position,
			(base * CFrame.new(2.8, 0.3, 1.5)).Position,
		}
	end,
	piano = function(base)
		-- Piano de cola negro laqueado: cuerpo, tapa abierta con su vara, atril, patas y pedales.
		local lacquer = Color3.fromRGB(8, 8, 10)
		local function black(name: string, size: Vector3, offset: CFrame)
			local p = solid(base, name, size, offset, lacquer, Enum.Material.SmoothPlastic)
			p.Reflectance = 0.28
			return p
		end
		black("CuerpoPiano", Vector3.new(9, 2, 6), CFrame.new(0, 4, 0.5))
		black("ColaPiano", Vector3.new(6, 2, 3), CFrame.new(-1.5, 4, 5))
		black("TapaTeclado", Vector3.new(9, 1.1, 1), CFrame.new(0, 4.55, -3))
		black("BaseTeclado", Vector3.new(9, 0.6, 1.6), CFrame.new(0, 3.3, -3.3))
		for _, x in { -3.9, 3.9 } do
			black("Costado", Vector3.new(0.5, 1.5, 1.8), CFrame.new(x, 3.95, -3.2))
		end
		-- Tapa inclinada, sostenida por la vara.
		black(
			"TapaPiano",
			Vector3.new(9, 0.25, 8.6),
			CFrame.new(0, 7.2, 2.4) * CFrame.Angles(math.rad(-22), 0, 0)
		)
		black("VaraTapa", Vector3.new(0.18, 3.2, 0.18), CFrame.new(3.8, 6.2, -0.6))
		black(
			"Atril",
			Vector3.new(5.5, 1.7, 0.15),
			CFrame.new(0, 5.8, -1.8) * CFrame.Angles(math.rad(-14), 0, 0)
		)
		-- Patas y lira con tres pedales dorados.
		for _, leg in { { -4, -3 }, { 4, -3 }, { -1.5, 6 } } do
			black("PataPiano", Vector3.new(0.7, 3, 0.7), CFrame.new(leg[1], 1.5, leg[2]))
		end
		black("LiraPiano", Vector3.new(0.3, 2.5, 0.3), CFrame.new(0, 1.5, -1.2))
		black("CajaPedales", Vector3.new(1.8, 0.6, 0.9), CFrame.new(0, 0.3, -1.2))
		for _, x in { -0.55, 0, 0.55 } do
			solid(
				base,
				"Pedal",
				Vector3.new(0.3, 0.12, 0.7),
				CFrame.new(x, 0.25, -1.9),
				GOLD_COLOR,
				Enum.Material.Metal
			)
		end

		candle((base * CFrame.new(3.6, 5.6, -2.6)).Position, CANDLE_LIGHT)

		-- Teclado de piezas reales: blancas separadas y negras más altas, agrupadas de a 2 y de a 3.
		local whites = 26
		local keyboard = 7.2
		local pitch = keyboard / whites
		local pattern = { true, true, false, true, true, true, false }
		for i = 1, whites do
			local x = -keyboard / 2 + (i - 0.5) * pitch
			decor({
				Name = "TeclaBlanca",
				Size = Vector3.new(pitch - 0.035, 0.25, 1.5),
				CFrame = base * CFrame.new(x, 3.725, -3.35),
				Color = Color3.fromRGB(250, 252, 255),
				Material = Enum.Material.SmoothPlastic,
			})
			if i < whites and pattern[(i - 1) % 7 + 1] then
				decor({
					Name = "TeclaNegra",
					Size = Vector3.new(pitch * 0.55, 0.2, 0.95),
					CFrame = base * CFrame.new(x + pitch / 2, 3.9, -3.075),
					Color = Color3.fromRGB(10, 10, 12),
					Material = Enum.Material.SmoothPlastic,
				})
			end
		end
		return {
			(base * CFrame.new(1, 0.3, 2)).Position,
			(base * CFrame.new(-3, 5.3, 1.5)).Position,
		}
	end,
	barrels = function(base)
		for _, offset in { Vector3.new(-2, 0, 0), Vector3.new(2.5, 0, 1), Vector3.new(0, 0, 3.2) } do
			part({
				Name = "Barril",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(5, 3.6, 3.6),
				CFrame = base
					* CFrame.new(offset + Vector3.new(0, 2.5, 0))
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(70, 44, 26),
				Material = Enum.Material.WoodPlanks,
			})
		end
		return {
			(base * CFrame.new(-2, 5.3, 0)).Position,
			(base * CFrame.new(4.6, 0.3, 3.6)).Position,
		}
	end,
	crates = function(base)
		solid(
			base,
			"Cajon",
			Vector3.new(5, 5, 5),
			CFrame.new(0, 2.5, 0),
			Color3.fromRGB(88, 66, 42),
			Enum.Material.WoodPlanks
		)
		solid(
			base,
			"Cajon",
			Vector3.new(3.4, 3.4, 3.4),
			CFrame.new(0.5, 6.7, 0) * CFrame.Angles(0, 0.4, 0),
			Color3.fromRGB(78, 58, 38),
			Enum.Material.WoodPlanks
		)
		return {
			(base * CFrame.new(-1.2, 5.3, -1.2)).Position,
			(base * CFrame.new(3.6, 0.3, 2)).Position,
		}
	end,
}

local GENERIC_KINDS = { "wardrobe", "table", "bookcase", "bed", "chest", "nightstand" }

-- Esquinas: { +X+Z, -X+Z, +X-Z, -X-Z }.
local THEMES: { [string]: { string } } = {
	room1 = { "sofa", "fireplace", "sofa", "bookcase" },
	room2 = { "wardrobe", "chest", "bookcase", "nightstand" },
	room3 = { "piano", "bookcase", "chest", "table" },
	room4 = { "counter", "stove" },
	room5 = { "barrels", "crates" },
	room6 = { "crates", "barrels", "barrels", "crates" },
	room8 = { "doubleBed", "nightstand", "wardrobe", "nightstand" },
	attic = { "chest", "crates", "wardrobe", "chest" },
	gameRoom = { "sofa", "bookcase", "sofa", "chest" },
	bar = { "sofa", "barrels", "sofa", "barrels" },
}

local CORNERS =
	{ Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) }
local EAST_CORNERS = { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1) }

-- Muebles que puede tener cada pieza en una partida; los que no se repiten van una sola vez.
local POOLS: { [string]: { string } } = {
	room1 = { "sofa", "sofa", "fireplace", "bookcase", "chest", "table", "wardrobe" },
	room2 = { "wardrobe", "chest", "bookcase", "nightstand", "table", "sofa" },
	room3 = { "piano", "bookcase", "chest", "table", "sofa", "wardrobe" },
	room8 = { "doubleBed", "bed", "nightstand", "nightstand", "wardrobe", "chest", "bookcase" },
	attic = { "chest", "crates", "wardrobe", "barrels", "chest" },
	gameRoom = { "sofa", "sofa", "bookcase", "chest", "table", "barrels" },
	bar = { "sofa", "barrels", "table", "chest", "barrels" },
}
local ONLY_ONE = { fireplace = true, piano = true, doubleBed = true, stove = true, counter = true }

local function pickTheme(id: string, random: Random): { string }?
	local pool = POOLS[id]
	if not pool then
		return nil
	end
	local theme: { string } = {}
	local used: { [string]: boolean } = {}
	while #theme < 4 do
		local kind = pool[random:NextInteger(1, #pool)]
		if not (ONLY_ONE[kind] and used[kind]) then
			used[kind] = true
			table.insert(theme, kind)
		end
	end
	return theme
end

-- Arma el mobiliario de las esquinas dentro de una carpeta propia. Con `reroll` borra el de la
-- partida anterior y sortea otro; los escondites de objetos se actualizan con los muebles nuevos.
local function furnishRoom(id: string, random: Random, reroll: boolean?)
	local center = cellCenter(id)
	local corners = if STAIR_ROOMS[id] then EAST_CORNERS else CORNERS
	local theme = pickTheme(id, random) or THEMES[id]
	local old = furnitureFolders[id]
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = `Mobiliario_{id}`
	folder.Parent = world
	furnitureFolders[id] = folder
	buildParent = folder
	local spots = {}
	for i, corner in corners do
		local position = center + corner * (HALF - 9)
		local base = CFrame.lookAt(position, center)
		local kind = theme and theme[i] or GENERIC_KINDS[random:NextInteger(1, #GENERIC_KINDS)]
		for _, spot in FURNITURE[kind](base) do
			table.insert(spots, spot)
		end
	end
	buildParent = nil
	if reroll then
		for _, extra in extraSpots[id] or {} do
			table.insert(spots, extra)
		end
	else
		furnishedCount[id] = #spots
	end
	refs.hidingSpots[id] = spots
end

-- Pieza de un animal disecado; no choca, salvo el pedestal que se arma aparte.
local function stuffed(
	base: CFrame,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	return decor({
		Name = name,
		Size = size,
		CFrame = base * offset,
		Color = color,
		Shape = shape or Enum.PartType.Block,
		Material = material or Enum.Material.Fabric,
	})
end

-- Luz tenue y fija, para distinguirlos en la penumbra sin agregar una vela a la vista.
local function trophyLight(position: Vector3)
	local holder = decor({
		Name = "LuzTrofeo",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = position,
		Transparency = 1,
	})
	local light = Instance.new("PointLight")
	light.Color = CANDLE_LIGHT
	light.Range = 13
	light.Brightness = 1.1
	light.Shadows = false
	light.Parent = holder
end

-- Escudo de madera donde se cuelgan las cabezas.
local function trophyPlaque(base: CFrame)
	trophyLight((base * CFrame.new(0, 3, -10)).Position)
	stuffed(
		base,
		"Escudo",
		Vector3.new(5, 6.5, 0.3),
		CFrame.new(0, 0, -0.15),
		WOOD_COLOR,
		nil,
		Enum.Material.Wood
	)
end

-- `base` está sobre la pared y su -Z apunta hacia adentro de la pieza.
local function mooseHead(base: CFrame)
	local fur = Color3.fromRGB(62, 45, 32)
	local face = Color3.fromRGB(96, 76, 58)
	local nose = Color3.fromRGB(58, 44, 36)
	local antler = Color3.fromRGB(178, 164, 138)
	local ball = Enum.PartType.Ball
	trophyPlaque(base)
	stuffed(base, "Cuello", Vector3.new(5, 6.4, 4), CFrame.new(0, -1, -1.6), fur, ball)
	stuffed(
		base,
		"Nuca",
		Vector3.new(3, 3.2, 3.6),
		CFrame.new(0, 1, -3) * CFrame.Angles(math.rad(-12), 0, 0),
		fur
	)
	stuffed(
		base,
		"Cabeza",
		Vector3.new(2.4, 2.2, 3.4),
		CFrame.new(0, 1.2, -5.2) * CFrame.Angles(math.rad(-18), 0, 0),
		face
	)
	stuffed(
		base,
		"Hocico",
		Vector3.new(2, 1.7, 2.6),
		CFrame.new(0, 0.1, -7.4) * CFrame.Angles(math.rad(-25), 0, 0),
		face
	)
	stuffed(base, "Nariz", Vector3.new(2.1, 1.6, 1.6), CFrame.new(0, -0.5, -8.6), nose, ball)
	stuffed(base, "Barba", Vector3.new(0.7, 1.8, 0.7), CFrame.new(0, -1.1, -5.4), fur)
	for _, side in { -1, 1 } do
		stuffed(
			base,
			"Ojo",
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(side * 1.2, 1.6, -5.4),
			Color3.new(0.02, 0.02, 0.02),
			ball,
			Enum.Material.SmoothPlastic
		)
		stuffed(
			base,
			"Oreja",
			Vector3.new(0.5, 1.6, 1),
			CFrame.new(side * 1.8, 2.5, -3.8) * CFrame.Angles(0, 0, math.rad(side * -50)),
			fur
		)
		-- Asta: tronco, palma ancha y puntas hacia arriba.
		local bone = Enum.Material.Concrete
		stuffed(
			base,
			"Asta",
			Vector3.new(3.4, 0.55, 0.7),
			CFrame.new(side * 2.6, 3.2, -3.6) * CFrame.Angles(0, 0, math.rad(side * 15)),
			antler,
			nil,
			bone
		)
		stuffed(
			base,
			"Palma",
			Vector3.new(3.6, 2.2, 0.35),
			CFrame.new(side * 5.2, 4.4, -3.6) * CFrame.Angles(0, 0, math.rad(side * 28)),
			antler,
			nil,
			bone
		)
		for i = 1, 4 do
			stuffed(
				base,
				"Punta",
				Vector3.new(0.3, 1.7, 0.3),
				CFrame.new(side * (3.7 + i * 0.75), 4.8 + i * 0.42, -3.6)
					* CFrame.Angles(0, 0, math.rad(side * -10)),
				antler,
				nil,
				bone
			)
		end
	end
end

local function rhinoHead(base: CFrame)
	local hide = Color3.fromRGB(92, 90, 86)
	local fold = Color3.fromRGB(72, 70, 67)
	local horn = Color3.fromRGB(150, 138, 116)
	trophyPlaque(base)
	stuffed(
		base,
		"Cuello",
		Vector3.new(5, 5.4, 4),
		CFrame.new(0, -0.6, -1.6),
		hide,
		Enum.PartType.Ball,
		Enum.Material.Slate
	)
	stuffed(
		base,
		"Pliegue",
		Vector3.new(4, 0.5, 3.4),
		CFrame.new(0, 1.2, -2.6),
		fold,
		nil,
		Enum.Material.Slate
	)
	stuffed(
		base,
		"Cabeza",
		Vector3.new(3.2, 3, 4.4),
		CFrame.new(0, 0.1, -4.8) * CFrame.Angles(math.rad(-15), 0, 0),
		hide,
		nil,
		Enum.Material.Slate
	)
	stuffed(
		base,
		"Hocico",
		Vector3.new(2.8, 2.2, 2.6),
		CFrame.new(0, -1, -7.6) * CFrame.Angles(math.rad(-15), 0, 0),
		hide,
		nil,
		Enum.Material.Slate
	)
	-- Cuernos hechos con tramos cada vez más finos.
	local tilt = CFrame.Angles(math.rad(25), 0, 0)
	for i, section in { { 1.2, 1.2, 0 }, { 0.8, 1.2, 1 }, { 0.42, 1.3, 2.1 } } do
		stuffed(
			base,
			`Cuerno{i}`,
			Vector3.new(section[1], section[2], section[1]),
			CFrame.new(0, 0.1, -8.2) * tilt * CFrame.new(0, section[3], 0),
			horn,
			nil,
			Enum.Material.Concrete
		)
	end
	stuffed(
		base,
		"CuernoChico",
		Vector3.new(0.7, 1.1, 0.7),
		CFrame.new(0, 1.8, -5.8) * tilt,
		horn,
		nil,
		Enum.Material.Concrete
	)
	for _, side in { -1, 1 } do
		stuffed(
			base,
			"Ojo",
			Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(side * 1.62, 0.3, -5.6),
			Color3.new(0.02, 0.02, 0.02),
			Enum.PartType.Ball,
			Enum.Material.SmoothPlastic
		)
		stuffed(
			base,
			"Oreja",
			Vector3.new(0.5, 1.5, 0.9),
			CFrame.new(side * 1.9, 2.1, -3.2) * CFrame.Angles(0, 0, math.rad(side * -25)),
			fold,
			nil,
			Enum.Material.Slate
		)
	end
end

-- Cabeza de cocodrilo con la boca entreabierta, dientes, crestas en el lomo del hocico y ojos
-- saltones. `base` está sobre la pared y su -Z apunta hacia adentro de la pieza.
local function crocodileHead(base: CFrame)
	local skin = Color3.fromRGB(62, 86, 48)
	local ridge = Color3.fromRGB(40, 58, 34)
	local belly = Color3.fromRGB(168, 176, 118)
	local tooth = Color3.fromRGB(236, 230, 208)
	local slate = Enum.Material.Slate
	trophyPlaque(base)
	stuffed(base, "Craneo", Vector3.new(3.8, 2.6, 3.2), CFrame.new(0, 0.5, -2.4), skin, nil, slate)
	-- Hocico largo que se angosta, con la punta ensanchada.
	stuffed(base, "Hocico", Vector3.new(3, 1.5, 3.4), CFrame.new(0, 0.3, -5.2), skin, nil, slate)
	stuffed(base, "Hocico", Vector3.new(2.2, 1.2, 3.2), CFrame.new(0, 0.1, -8), skin, nil, slate)
	stuffed(base, "Punta", Vector3.new(2.7, 1.4, 1.5), CFrame.new(0, 0.05, -9.9), skin, nil, slate)
	for _, side in { -1, 1 } do
		stuffed(
			base,
			"Nariz",
			Vector3.new(0.5, 0.35, 0.55),
			CFrame.new(side * 0.55, 0.85, -10.3),
			Color3.fromRGB(14, 18, 12),
			Enum.PartType.Ball,
			Enum.Material.SmoothPlastic
		)
		-- Ojo saltón con pupila vertical, sobre una ceja de escamas.
		stuffed(
			base,
			"Ceja",
			Vector3.new(1.1, 0.7, 1.3),
			CFrame.new(side * 1.45, 1.95, -3.4),
			ridge,
			Enum.PartType.Ball,
			slate
		)
		stuffed(
			base,
			"Ojo",
			Vector3.new(0.9, 0.9, 0.9),
			CFrame.new(side * 1.45, 2.05, -3.75),
			Color3.fromRGB(184, 156, 40),
			Enum.PartType.Ball,
			Enum.Material.SmoothPlastic
		)
		stuffed(
			base,
			"Pupila",
			Vector3.new(0.14, 0.62, 0.12),
			CFrame.new(side * 1.45, 2.05, -4.2),
			Color3.new(0.02, 0.02, 0.02),
			nil,
			Enum.Material.SmoothPlastic
		)
	end
	-- Escamas: dos hileras de placas por el lomo del hocico.
	for i = 0, 9 do
		for _, side in { -1, 1 } do
			stuffed(
				base,
				"Escama",
				Vector3.new(0.55, 0.22, 0.5),
				CFrame.new(side * 0.55, 1.08 - i * 0.07, -3.2 - i * 0.7),
				ridge,
				nil,
				slate
			)
		end
	end
	-- Mandíbula de abajo, abierta unos grados desde la bisagra del cráneo.
	local hinge = base * CFrame.new(0, -0.9, -3.4) * CFrame.Angles(math.rad(-11), 0, 0)
	stuffed(
		hinge,
		"Mandibula",
		Vector3.new(2.7, 0.8, 6.8),
		CFrame.new(0, 0, -3.4),
		belly,
		nil,
		slate
	)
	stuffed(
		hinge,
		"Barbilla",
		Vector3.new(2.3, 0.7, 1.4),
		CFrame.new(0, -0.05, -6.9),
		belly,
		nil,
		slate
	)
	-- Dientes: los de arriba cuelgan y los de abajo asoman, de distinto largo.
	for i = 0, 7 do
		local z = -4.4 - i * 0.82
		local tall = if i % 2 == 0 then 0.7 else 0.45
		for _, side in { -1, 1 } do
			stuffed(
				base,
				"Diente",
				Vector3.new(0.2, tall, 0.26),
				CFrame.new(side * (1.45 - i * 0.04), -0.4 - tall / 2, z),
				tooth,
				nil,
				Enum.Material.SmoothPlastic
			)
			stuffed(
				hinge,
				"Diente",
				Vector3.new(0.2, tall * 0.9, 0.26),
				CFrame.new(side * (1.25 - i * 0.04), 0.4 + tall * 0.45, z + 3.4),
				tooth,
				nil,
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Lengua oscura entre las dos mandíbulas.
	stuffed(
		hinge,
		"Lengua",
		Vector3.new(1.4, 0.15, 4.4),
		CFrame.new(0, 0.42, -4.4),
		Color3.fromRGB(120, 54, 60),
		nil,
		Enum.Material.Fabric
	)
end

-- Pedestal del centro de la pieza, por donde pasan los asesinos: a ellos no los frena.
-- Devuelve el punto del pedestal donde se apoya el animal; `base` está en el piso.
local function animalPlinth(base: CFrame): CFrame
	local plinth =
		solid(base, "Pedestal", Vector3.new(9, 1.5, 3.4), CFrame.new(0, 0.75, 0), WOOD_COLOR)
	plinth.CollisionGroup = "KillerPass"
	solid(
		base,
		"PlacaPedestal",
		Vector3.new(1.6, 0.5, 0.1),
		CFrame.new(0, 0.75, -1.72),
		GOLD_COLOR,
		Enum.Material.Metal
	).CollisionGroup =
		"KillerPass"
	local top = base * CFrame.new(0, 1.5, 0)
	trophyLight((top * CFrame.new(0, 7, 0)).Position)
	return top
end

type CatLook = {
	coat: Color3,
	pale: Color3,
	dark: Color3,
	eye: Color3,
	-- "none", "rosettes" (jaguar) o "stripes" (tigre).
	pattern: string,
}

-- Felino entero caminando sobre el pedestal, con la cabeza hacia +X.
local function catOnPlinth(top: CFrame, look: CatLook)
	local coat, pale, dark = look.coat, look.pale, look.dark
	stuffed(top, "Cuerpo", Vector3.new(4.4, 1.6, 1.5), CFrame.new(0, 2.2, 0), coat)
	stuffed(top, "Lomo", Vector3.new(1.7, 1.8, 1.6), CFrame.new(-1.9, 2.3, 0), coat)
	stuffed(top, "Pecho", Vector3.new(1.5, 1.9, 1.5), CFrame.new(1.9, 2.2, 0), coat)
	stuffed(top, "Panza", Vector3.new(3.2, 0.3, 1.2), CFrame.new(0, 1.35, 0), pale)
	for _, leg in
		{ { 2.2, -0.5, 0.5 }, { 1.6, 0.5, -0.4 }, { -2.2, -0.5, -0.4 }, { -1.6, 0.5, 0.5 } }
	do
		stuffed(
			top,
			"Pata",
			Vector3.new(0.55, 1.7, 0.55),
			CFrame.new(leg[1], 0.85, leg[2]) * CFrame.Angles(0, 0, math.rad(leg[3] * 16)),
			coat
		)
		stuffed(
			top,
			"Garra",
			Vector3.new(0.8, 0.25, 0.65),
			CFrame.new(leg[1] + 0.1, 0.12, leg[2]),
			pale
		)
		if look.pattern == "stripes" then
			stuffed(
				top,
				"RayaPata",
				Vector3.new(0.58, 0.1, 0.58),
				CFrame.new(leg[1] + leg[3] * 0.06, 1.15, leg[2]),
				dark
			)
		end
	end
	stuffed(
		top,
		"CuelloFelino",
		Vector3.new(1.3, 1, 1),
		CFrame.new(3, 2.7, 0) * CFrame.Angles(0, 0, math.rad(25)),
		coat
	)
	stuffed(top, "Cabeza", Vector3.new(1.3, 1.1, 1.2), CFrame.new(3.8, 3.1, 0), coat)
	stuffed(top, "Hocico", Vector3.new(0.6, 0.55, 0.7), CFrame.new(4.65, 2.9, 0), pale)
	stuffed(
		top,
		"Nariz",
		Vector3.new(0.12, 0.2, 0.28),
		CFrame.new(4.98, 3.05, 0),
		Color3.fromRGB(70, 36, 36),
		nil,
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		stuffed(top, "Oreja", Vector3.new(0.35, 0.45, 0.3), CFrame.new(3.6, 3.8, side * 0.42), coat)
		stuffed(
			top,
			"Ojo",
			Vector3.new(0.1, 0.2, 0.2),
			CFrame.new(4.46, 3.3, side * 0.34),
			look.eye,
			nil,
			Enum.Material.SmoothPlastic
		)
		stuffed(
			top,
			"Pupila",
			Vector3.new(0.04, 0.16, 0.06),
			CFrame.new(4.52, 3.3, side * 0.34),
			Color3.new(0.02, 0.02, 0.02),
			nil,
			Enum.Material.SmoothPlastic
		)
		-- Bigotes.
		for _, tilt in { -8, 8 } do
			stuffed(
				top,
				"Bigote",
				Vector3.new(0.7, 0.03, 0.03),
				CFrame.new(4.85, 2.88, side * 0.35)
					* CFrame.Angles(math.rad(tilt), math.rad(side * 25), 0),
				pale,
				nil,
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Cola larga que baja y levanta la punta.
	stuffed(
		top,
		"Cola",
		Vector3.new(2.2, 0.35, 0.35),
		CFrame.new(-3.5, 2, 0) * CFrame.Angles(0, 0, math.rad(40)),
		coat
	)
	stuffed(
		top,
		"PuntaCola",
		Vector3.new(1, 0.38, 0.38),
		CFrame.new(-4.7, 1.45, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		dark
	)

	if look.pattern == "rosettes" then
		-- Rosetas: anillo oscuro con el centro más claro, por el lomo y los costados.
		local function rosette(x: number, y: number, z: number, onTop: boolean)
			local ring = if onTop
				then Vector3.new(0.42, 0.06, 0.42)
				else Vector3.new(0.42, 0.42, 0.06)
			local dot = if onTop
				then Vector3.new(0.18, 0.08, 0.18)
				else Vector3.new(0.18, 0.18, 0.08)
			stuffed(
				top,
				"Roseta",
				ring,
				CFrame.new(x, y, z),
				dark,
				nil,
				Enum.Material.SmoothPlastic
			)
			stuffed(
				top,
				"CentroRoseta",
				dot,
				CFrame.new(x, y, z),
				look.coat:Lerp(Color3.new(1, 1, 1), 0.12),
				nil,
				Enum.Material.SmoothPlastic
			)
		end
		for i, x in { -2.3, -1.4, -0.5, 0.4, 1.3, 2.2 } do
			local zig = if i % 2 == 0 then 0.35 else -0.35
			local height = if x < -1 then 3.22 elseif x > 1.2 then 3.17 else 3.03
			rosette(x, height, zig, true)
			rosette(x + 0.25, 2.7 - (i % 3) * 0.3, 0.83, false)
			rosette(x - 0.2, 2.1 + (i % 2) * 0.35, 0.83, false)
			rosette(x + 0.25, 2.7 - ((i + 1) % 3) * 0.3, -0.83, false)
			rosette(x - 0.2, 2.1 + ((i + 1) % 2) * 0.35, -0.83, false)
		end
		for _, side in { -1, 1 } do
			stuffed(
				top,
				"ManchaCabeza",
				Vector3.new(0.18, 0.18, 0.06),
				CFrame.new(3.7, 3.45, side * 0.62),
				dark,
				Enum.PartType.Ball,
				Enum.Material.SmoothPlastic
			)
			stuffed(
				top,
				"ManchaCabeza",
				Vector3.new(0.16, 0.16, 0.06),
				CFrame.new(4.05, 3.3, side * 0.62),
				dark,
				Enum.PartType.Ball,
				Enum.Material.SmoothPlastic
			)
		end
	elseif look.pattern == "stripes" then
		-- Rayas negras cruzando el lomo y los costados, más una máscara blanca en la cara.
		for i = 0, 8 do
			local x = -2.1 + i * 0.55
			local height = if x < -1 then 3.23 elseif x > 1.2 then 3.18 else 3.04
			stuffed(
				top,
				"Raya",
				Vector3.new(0.17, 0.06, 1.5),
				CFrame.new(x, height, 0),
				dark,
				nil,
				Enum.Material.SmoothPlastic
			)
			for _, side in { -1, 1 } do
				stuffed(
					top,
					"Raya",
					Vector3.new(0.14, 1.05, 0.06),
					CFrame.new(x + (i % 2) * 0.12, 2.35 + (i % 3) * 0.08, side * 0.83)
						* CFrame.Angles(0, 0, math.rad(side * 9)),
					dark,
					nil,
					Enum.Material.SmoothPlastic
				)
			end
		end
		for _, side in { -1, 1 } do
			stuffed(
				top,
				"Mejilla",
				Vector3.new(0.55, 0.4, 0.2),
				CFrame.new(4.2, 2.85, side * 0.55),
				look.pale
			)
			stuffed(
				top,
				"RayaCara",
				Vector3.new(0.4, 0.07, 0.06),
				CFrame.new(3.85, 3.35, side * 0.62),
				dark,
				nil,
				Enum.Material.SmoothPlastic
			)
		end
		for _, x in { -3.2, -3.9, -4.5 } do
			stuffed(
				top,
				"AnilloCola",
				Vector3.new(0.18, 0.4, 0.4),
				CFrame.new(x, 2 - (x + 3.2) * -0.35, 0) * CFrame.Angles(0, 0, math.rad(35)),
				dark
			)
		end
	end
end

type BearLook = {
	coat: Color3,
	belly: Color3,
	muzzle: Color3,
	claw: Color3,
	hump: boolean,
	material: Enum.Material?,
}

-- Oso entero caminando sobre el pedestal, con la cabeza hacia +X. El grizzly lleva joroba.
local function bearOnPlinth(top: CFrame, look: BearLook)
	local coat = look.coat
	local function fur(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		shape: Enum.PartType?,
		material: Enum.Material?
	): Part
		return stuffed(top, name, size, offset, color, shape, material or look.material)
	end
	fur("Cuerpo", Vector3.new(4.6, 2.6, 2.3), CFrame.new(0, 3, 0), coat)
	fur("Anca", Vector3.new(2.4, 2.5, 2.3), CFrame.new(-1.9, 2.9, 0), coat)
	fur("Hombros", Vector3.new(2, 2.7, 2.2), CFrame.new(1.5, 3.1, 0), coat)
	if look.hump then
		fur(
			"Joroba",
			Vector3.new(2.2, 1.5, 2.1),
			CFrame.new(1, 4.35, 0),
			look.coat:Lerp(Color3.new(0.2, 0.15, 0.1), 0.15),
			Enum.PartType.Ball
		)
	end
	fur("Panza", Vector3.new(3.4, 0.35, 1.9), CFrame.new(0, 1.7, 0), look.belly)
	for _, leg in { { 1.8, 0.7 }, { 1.4, -0.7 }, { -1.9, 0.7 }, { -1.5, -0.7 } } do
		fur("Pata", Vector3.new(1, 2, 1), CFrame.new(leg[1], 1, leg[2]), coat)
		fur(
			"Pata",
			Vector3.new(1.15, 0.35, 1.1),
			CFrame.new(leg[1] + 0.12, 0.17, leg[2]),
			look.belly
		)
		for _, dz in { -0.3, 0, 0.3 } do
			fur(
				"Garra",
				Vector3.new(0.35, 0.12, 0.1),
				CFrame.new(leg[1] + 0.78, 0.1, leg[2] + dz),
				look.claw,
				nil,
				Enum.Material.SmoothPlastic
			)
		end
	end
	fur(
		"Cuello",
		Vector3.new(1.7, 1.7, 1.7),
		CFrame.new(2.6, 3.4, 0) * CFrame.Angles(0, 0, math.rad(-12)),
		coat,
		Enum.PartType.Ball
	)
	fur("Cabeza", Vector3.new(1.7, 1.5, 1.6), CFrame.new(3.5, 3.3, 0), coat, Enum.PartType.Ball)
	fur("Hocico", Vector3.new(1.2, 0.8, 0.95), CFrame.new(4.35, 3.05, 0), look.muzzle)
	fur(
		"Nariz",
		Vector3.new(0.3, 0.38, 0.55),
		CFrame.new(4.95, 3.18, 0),
		Color3.fromRGB(14, 12, 12),
		nil,
		Enum.Material.SmoothPlastic
	)
	fur(
		"Boca",
		Vector3.new(0.9, 0.05, 0.1),
		CFrame.new(4.4, 2.72, 0),
		Color3.fromRGB(30, 14, 14),
		nil,
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		fur(
			"Oreja",
			Vector3.new(0.55, 0.55, 0.3),
			CFrame.new(3.3, 4.2, side * 0.7),
			coat,
			Enum.PartType.Ball
		)
		fur(
			"Ojo",
			Vector3.new(0.18, 0.18, 0.18),
			CFrame.new(4.1, 3.55, side * 0.5),
			Color3.fromRGB(10, 8, 8),
			Enum.PartType.Ball,
			Enum.Material.SmoothPlastic
		)
	end
	fur("Cola", Vector3.new(0.6, 0.6, 0.6), CFrame.new(-3.2, 3.2, 0), coat, Enum.PartType.Ball)
end

type AnimalMaker = (CFrame) -> ()

local ANIMALS: { [string]: AnimalMaker } = {
	puma = function(top)
		catOnPlinth(top, {
			coat = Color3.fromRGB(170, 126, 80),
			pale = Color3.fromRGB(214, 190, 156),
			dark = Color3.fromRGB(42, 30, 22),
			eye = Color3.fromRGB(190, 150, 50),
			pattern = "none",
		})
	end,
	jaguar = function(top)
		catOnPlinth(top, {
			coat = Color3.fromRGB(196, 142, 58),
			pale = Color3.fromRGB(232, 214, 176),
			dark = Color3.fromRGB(26, 18, 12),
			eye = Color3.fromRGB(200, 170, 40),
			pattern = "rosettes",
		})
	end,
	tiger = function(top)
		catOnPlinth(top, {
			coat = Color3.fromRGB(218, 112, 30),
			pale = Color3.fromRGB(242, 236, 224),
			dark = Color3.fromRGB(18, 14, 12),
			eye = Color3.fromRGB(210, 180, 40),
			pattern = "stripes",
		})
	end,
	polar = function(top)
		bearOnPlinth(top, {
			coat = Color3.fromRGB(236, 238, 242),
			belly = Color3.fromRGB(214, 220, 228),
			muzzle = Color3.fromRGB(226, 228, 232),
			claw = Color3.fromRGB(70, 66, 62),
			hump = false,
			material = Enum.Material.SmoothPlastic,
		})
	end,
	grizzly = function(top)
		bearOnPlinth(top, {
			coat = Color3.fromRGB(98, 64, 40),
			belly = Color3.fromRGB(78, 50, 32),
			muzzle = Color3.fromRGB(148, 108, 74),
			claw = Color3.fromRGB(226, 212, 180),
			hump = true,
		})
	end,
}
local ANIMAL_ORDER = { "puma", "jaguar", "tiger", "polar", "grizzly" }

-- Mesa de pool con paño, troneras, bolas y tacos. Corrida del centro, por donde pasan los asesinos.
local function poolTable(base: CFrame)
	local felt = Color3.fromRGB(24, 92, 56)
	local black = Color3.fromRGB(8, 8, 8)
	local ball = Enum.PartType.Ball
	local plastic = Enum.Material.SmoothPlastic
	solid(
		base,
		"MesaPool",
		Vector3.new(14, 1, 7.4),
		CFrame.new(0, 3, 0),
		WOOD_COLOR,
		Enum.Material.Wood
	)
	for _, x in { -5.8, 5.8 } do
		for _, z in { -2.8, 2.8 } do
			solid(
				base,
				"Pata",
				Vector3.new(1, 2.5, 1),
				CFrame.new(x, 1.25, z),
				WOOD_COLOR,
				Enum.Material.Wood
			)
		end
	end
	stuffed(base, "Pano", Vector3.new(12.6, 0.1, 6), CFrame.new(0, 3.53, 0), felt)
	for _, x in { -6.1, 0, 6.1 } do
		for _, z in { -2.8, 2.8 } do
			stuffed(
				base,
				"Tronera",
				Vector3.new(0.75, 0.04, 0.75),
				CFrame.new(x, 3.6, z),
				black,
				nil,
				plastic
			)
		end
	end
	local colors = {
		Color3.fromRGB(220, 190, 40),
		Color3.fromRGB(30, 60, 170),
		Color3.fromRGB(180, 30, 30),
		Color3.fromRGB(90, 30, 130),
		Color3.fromRGB(210, 100, 30),
		Color3.fromRGB(20, 110, 60),
		Color3.fromRGB(110, 25, 25),
		black,
		Color3.fromRGB(190, 170, 60),
		Color3.fromRGB(40, 90, 180),
	}
	-- Triángulo armado, con la bola blanca enfrentada.
	local n = 1
	for row = 0, 3 do
		for i = 0, row do
			stuffed(
				base,
				"Bola",
				Vector3.one * 0.5,
				CFrame.new(2.4 + row * 0.45, 3.83, (i - row / 2) * 0.52),
				colors[n],
				ball,
				plastic
			)
			n += 1
		end
	end
	stuffed(
		base,
		"BolaBlanca",
		Vector3.one * 0.5,
		CFrame.new(-3.2, 3.83, 0.3),
		Color3.fromRGB(235, 232, 220),
		ball,
		plastic
	)
	stuffed(
		base,
		"Taco",
		Vector3.new(7.5, 0.13, 0.13),
		CFrame.new(-1, 3.8, 1.9) * CFrame.Angles(0, math.rad(9), 0),
		Color3.fromRGB(150, 105, 60),
		nil,
		Enum.Material.Wood
	)
end

-- Dibujos de pixeles para las pantallas: cada letra "x" es un pixel encendido.
local PIXEL_ART: { [string]: { string } } = {
	invader = {
		"..x.....x..",
		"...x...x...",
		"..xxxxxxx..",
		".xx.xxx.xx.",
		"xxxxxxxxxxx",
		"x.xxxxxxx.x",
		"x.x.....x.x",
		"...xx.xx...",
	},
	ghost = {
		"...xxxxx...",
		"..xxxxxxx..",
		".xxxxxxxxx.",
		".xx.xxx.xx.",
		".xx.xxx.xx.",
		".xxxxxxxxx.",
		".xxxxxxxxx.",
		".x.xx.xx.x.",
	},
	skull = {
		"..xxxxxxx..",
		".xxxxxxxxx.",
		"xxx..x..xxx",
		"xxx..x..xxx",
		"xxxxxxxxxxx",
		".xxx.x.xxx.",
		"..x.xxx.x..",
		"..xxxxxxx..",
	},
	car = {
		"...........",
		"...xxxxx...",
		"..xxxxxxx..",
		".xxxxxxxxx.",
		"xxxxxxxxxxx",
		"xx.xxxxx.xx",
		"xx.......xx",
		"...........",
	},
}

-- Pantalla de pixeles dentro de un SurfaceGui: fondo oscuro, dibujo grande y un cartel abajo.
local function arcadeScreen(face: BasePart, art: string, ink: Color3, caption: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = face
	local pattern = PIXEL_ART[art]
	local columns, rows = #pattern[1], #pattern
	local cell = 7
	local startX = (face.Size.X * 40 - columns * cell) / 2
	for y, line in pattern do
		for x = 1, columns do
			if string.sub(line, x, x) == "x" then
				local pixel = Instance.new("Frame")
				pixel.BorderSizePixel = 0
				pixel.BackgroundColor3 = ink
				pixel.Size = UDim2.fromOffset(cell, cell)
				pixel.Position = UDim2.fromOffset(startX + (x - 1) * cell, 14 + (y - 1) * cell)
				pixel.Parent = gui
			end
		end
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(0, 14 + rows * cell + 6)
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = Enum.Font.Arcade
	label.TextSize = 14
	label.TextColor3 = ink
	label.Text = caption
	label.Parent = gui
	-- Filas de barrido, como un monitor de tubo.
	for line = 0, 9 do
		local scan = Instance.new("Frame")
		scan.BorderSizePixel = 0
		scan.BackgroundColor3 = Color3.new(0, 0, 0)
		scan.BackgroundTransparency = 0.8
		scan.Size = UDim2.new(1, 0, 0, 2)
		scan.Position = UDim2.fromOffset(0, line * 12)
		scan.Parent = gui
	end
end

-- Máquina arcade: gabinete con los laterales de color, pantalla de pixeles con luz propia, cartel
-- iluminado, tablero inclinado con palanca y botones, y la monedera abajo. Mira hacia -Z.
local function arcadeCabinet(base: CFrame, tint: Color3, title: string, art: string)
	local plastic = Enum.Material.SmoothPlastic
	local body = Color3.fromRGB(22, 22, 28)
	local trim = Color3.fromRGB(8, 8, 10)
	-- Laterales con una franja de neón y el zócalo.
	for _, side in { -1, 1 } do
		solid(
			base,
			"Lateral",
			Vector3.new(0.35, 7.6, 3.4),
			CFrame.new(side * 1.72, 3.8, 0),
			tint:Lerp(trim, 0.55),
			plastic
		)
		stuffed(
			base,
			"FranjaLateral",
			Vector3.new(0.08, 6.6, 0.18),
			CFrame.new(side * 1.92, 3.7, -1.45),
			tint,
			nil,
			Enum.Material.Neon
		)
		stuffed(
			base,
			"FranjaLateral",
			Vector3.new(0.08, 0.18, 2.8),
			CFrame.new(side * 1.92, 1.2, 0),
			tint,
			nil,
			Enum.Material.Neon
		)
	end
	solid(base, "CuerpoBajo", Vector3.new(3.1, 3.1, 3), CFrame.new(0, 1.55, 0.1), body, plastic)
	solid(base, "Zocalo", Vector3.new(3.1, 0.35, 3.1), CFrame.new(0, 0.18, 0), trim, plastic)
	-- Monitor: caja trasera, marco negro y pantalla hundida.
	solid(base, "CajaMonitor", Vector3.new(3.1, 4.1, 1.8), CFrame.new(0, 5.4, 0.6), body, plastic)
	local bezel = CFrame.new(0, 5.35, -0.31)
	stuffed(base, "MarcoPantalla", Vector3.new(3, 3.1, 0.1), bezel, trim, nil, plastic)
	local screen = stuffed(
		base,
		"Pantalla",
		Vector3.new(2.6, 2.7, 0.06),
		CFrame.new(0, 5.35, -0.4),
		Color3.fromRGB(6, 10, 22),
		nil,
		Enum.Material.Neon
	)
	arcadeScreen(screen, art, tint:Lerp(Color3.new(1, 1, 1), 0.35), title)
	local glow = Instance.new("PointLight")
	glow.Color = tint:Lerp(Color3.fromRGB(120, 160, 255), 0.4)
	glow.Range = 11
	glow.Brightness = 0.9
	glow.Shadows = false
	glow.Parent = screen
	-- Cartel de arriba, iluminado, con el nombre del juego.
	local marquee = solid(
		base,
		"CartelMaquina",
		Vector3.new(3.1, 1, 1.9),
		CFrame.new(0, 7.95, 0.55),
		tint,
		Enum.Material.Neon
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = marquee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.Text = title
	label.TextColor3 = Color3.fromRGB(15, 15, 22)
	label.Parent = gui
	-- Tablero inclinado de comandos.
	solid(
		base,
		"Tablero",
		Vector3.new(3.1, 0.4, 1.7),
		CFrame.new(0, 3.35, -1.7) * CFrame.Angles(math.rad(-14), 0, 0),
		trim,
		plastic
	)
	local deck = base * CFrame.new(0, 3.62, -1.7) * CFrame.Angles(math.rad(-14), 0, 0)
	-- Palanca: base, varilla y bola roja.
	stuffed(
		deck,
		"BasePalanca",
		Vector3.new(0.12, 0.5, 0.5),
		CFrame.new(-0.7, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(40, 40, 44),
		Enum.PartType.Cylinder,
		Enum.Material.Metal
	)
	stuffed(
		deck,
		"VarillaPalanca",
		Vector3.new(0.12, 0.7, 0.12),
		CFrame.new(-0.7, 0.42, 0),
		Color3.fromRGB(190, 190, 198),
		nil,
		Enum.Material.Metal
	)
	stuffed(
		deck,
		"BolaPalanca",
		Vector3.new(0.42, 0.42, 0.42),
		CFrame.new(-0.7, 0.85, 0),
		Color3.fromRGB(210, 30, 36),
		Enum.PartType.Ball,
		plastic
	)
	-- Botones de colores en dos filas.
	local buttons = {
		Color3.fromRGB(220, 40, 44),
		Color3.fromRGB(240, 200, 40),
		Color3.fromRGB(50, 110, 230),
		Color3.fromRGB(60, 190, 90),
	}
	for i, color in buttons do
		local row = if i <= 2 then -0.28 else 0.3
		local column = 0.1 + ((i - 1) % 2) * 0.55
		stuffed(
			deck,
			"Boton",
			Vector3.new(0.1, 0.3, 0.3),
			CFrame.new(column + 0.2, 0.07, row) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			Enum.PartType.Cylinder,
			plastic
		)
	end
	for _, x in { 0.95, 1.2 } do
		stuffed(
			deck,
			"BotonInicio",
			Vector3.new(0.08, 0.2, 0.2),
			CFrame.new(x, 0.06, 0.55) * CFrame.Angles(0, 0, math.rad(90)),
			tint,
			Enum.PartType.Cylinder,
			Enum.Material.Neon
		)
	end
	-- Monedera con dos ranuras que brillan.
	stuffed(
		base,
		"Monedera",
		Vector3.new(1.2, 1.5, 0.12),
		CFrame.new(0, 1.9, -1.56),
		Color3.fromRGB(70, 70, 76),
		nil,
		Enum.Material.Metal
	)
	for _, x in { -0.3, 0.3 } do
		stuffed(
			base,
			"RanuraMoneda",
			Vector3.new(0.12, 0.5, 0.06),
			CFrame.new(x, 2.1, -1.63),
			Color3.fromRGB(255, 70, 50),
			nil,
			Enum.Material.Neon
		)
	end
	stuffed(
		base,
		"PuertaCaja",
		Vector3.new(1.4, 0.5, 0.08),
		CFrame.new(0, 1.0, -1.55),
		trim,
		nil,
		plastic
	)
end

local function barStool(position: Vector3)
	local base = CFrame.new(position)
	local turn = CFrame.Angles(0, 0, math.rad(90))
	stuffed(
		base,
		"PataBanqueta",
		Vector3.new(2.7, 0.3, 0.3),
		CFrame.new(0, 1.35, 0) * turn,
		Color3.fromRGB(60, 60, 64),
		Enum.PartType.Cylinder,
		Enum.Material.Metal
	)
	stuffed(
		base,
		"AsientoBanqueta",
		Vector3.new(0.4, 1.6, 1.6),
		CFrame.new(0, 2.85, 0) * turn,
		FABRIC_COLOR,
		Enum.PartType.Cylinder
	)
end

-- Botella de pie con la base en `at`: vidrio con el líquido adentro, etiqueta, cuello y tapón.
-- `kind`: 1 vino (alta y fina), 2 whisky (ancha y corta), 3 botellón redondo.
local function bottle(at: Vector3, kind: number, liquid: Color3)
	local base = CFrame.new(at)
	local up = CFrame.Angles(0, 0, math.rad(90))
	local cylinder = Enum.PartType.Cylinder
	local glassTint = liquid:Lerp(Color3.new(1, 1, 1), 0.2)
	-- Cilindro vertical: `height` de alto y `width` de diámetro, con el centro en `y`.
	local function tube(
		name: string,
		height: number,
		width: number,
		y: number,
		color: Color3,
		material: Enum.Material
	): Part
		return stuffed(
			base,
			name,
			Vector3.new(height, width, width),
			CFrame.new(0, y, 0) * up,
			color,
			cylinder,
			material
		)
	end
	local function glassOf(piece: Part)
		piece.Transparency = 0.45
		piece.Reflectance = 0.25
	end
	local bodyHeight, bodyWidth, neckHeight, neckWidth
	if kind == 1 then
		bodyHeight, bodyWidth, neckHeight, neckWidth = 1.05, 0.5, 0.6, 0.2
	elseif kind == 2 then
		bodyHeight, bodyWidth, neckHeight, neckWidth = 0.8, 0.66, 0.3, 0.26
	else
		bodyHeight, bodyWidth, neckHeight, neckWidth = 0.55, 0.8, 0.65, 0.24
	end
	if kind == 3 then
		-- Botellón panzón: esfera de vidrio con el líquido adentro.
		glassOf(
			stuffed(
				base,
				"Vidrio",
				Vector3.one * bodyWidth,
				CFrame.new(0, bodyWidth / 2, 0),
				glassTint,
				Enum.PartType.Ball,
				Enum.Material.Glass
			)
		)
		stuffed(
			base,
			"Licor",
			Vector3.one * (bodyWidth * 0.86),
			CFrame.new(0, bodyWidth * 0.46, 0),
			liquid,
			Enum.PartType.Ball,
			Enum.Material.SmoothPlastic
		)
		bodyHeight = bodyWidth
	else
		glassOf(
			tube("Vidrio", bodyHeight, bodyWidth, bodyHeight / 2, glassTint, Enum.Material.Glass)
		)
		tube(
			"Licor",
			bodyHeight * 0.82,
			bodyWidth * 0.86,
			bodyHeight * 0.45,
			liquid,
			Enum.Material.SmoothPlastic
		)
		-- Hombro que se angosta hacia el cuello.
		glassOf(
			tube(
				"Hombro",
				0.16,
				(bodyWidth + neckWidth) / 2,
				bodyHeight + 0.08,
				glassTint,
				Enum.Material.Glass
			)
		)
	end
	glassOf(
		tube(
			"Cuello",
			neckHeight,
			neckWidth,
			bodyHeight + neckHeight / 2 + 0.1,
			glassTint,
			Enum.Material.Glass
		)
	)
	-- Tapón: corcho en el vino, tapa dorada en el resto.
	local capY = bodyHeight + neckHeight + 0.17
	if kind == 1 then
		tube(
			"Corcho",
			0.22,
			neckWidth * 0.9,
			capY,
			Color3.fromRGB(176, 140, 96),
			Enum.Material.Wood
		)
	else
		tube("Tapa", 0.2, neckWidth + 0.05, capY, GOLD_COLOR, Enum.Material.Metal)
	end
	-- Etiqueta crema con una franja oscura.
	if kind ~= 3 then
		tube(
			"Etiqueta",
			bodyHeight * 0.38,
			bodyWidth + 0.03,
			bodyHeight * 0.45,
			Color3.fromRGB(226, 214, 184),
			Enum.Material.Fabric
		)
		tube(
			"FranjaEtiqueta",
			bodyHeight * 0.1,
			bodyWidth + 0.04,
			bodyHeight * 0.45,
			Color3.fromRGB(60, 26, 22),
			Enum.Material.SmoothPlastic
		)
	else
		stuffed(
			base,
			"Etiqueta",
			Vector3.new(0.42, 0.3, 0.06),
			CFrame.new(0, bodyWidth * 0.5, -bodyWidth * 0.42),
			Color3.fromRGB(226, 214, 184),
			nil,
			Enum.Material.Fabric
		)
	end
end

-- Vaso de vidrio con un dedo de bebida, sobre la barra.
local function drinkingGlass(at: Vector3, liquid: Color3)
	local base = CFrame.new(at)
	local up = CFrame.Angles(0, 0, math.rad(90))
	local cup = stuffed(
		base,
		"Vaso",
		Vector3.new(0.6, 0.5, 0.5),
		CFrame.new(0, 0.3, 0) * up,
		Color3.fromRGB(210, 224, 230),
		Enum.PartType.Cylinder,
		Enum.Material.Glass
	)
	cup.Transparency = 0.5
	cup.Reflectance = 0.2
	stuffed(
		base,
		"Bebida",
		Vector3.new(0.3, 0.4, 0.4),
		CFrame.new(0, 0.17, 0) * up,
		liquid,
		Enum.PartType.Cylinder,
		Enum.Material.SmoothPlastic
	)
end

-- Barra larga con estantes de botellas detrás, banquetas, canilla y dos mesitas.
local function barFittings(center: Vector3)
	local base = CFrame.new(center)
	local lacquer = Color3.fromRGB(44, 24, 14)
	local wood = Enum.Material.Wood
	solid(base, "Barra", Vector3.new(3, 3.4, 22), CFrame.new(-15, 1.7, 0), lacquer, wood)
	solid(
		base,
		"TapaBarra",
		Vector3.new(3.6, 0.3, 22.6),
		CFrame.new(-14.8, 3.55, 0),
		GOLD_COLOR,
		wood
	)
	for _, z in { -8, -4, 0, 4, 8 } do
		barStool(center + Vector3.new(-11.5, 0, z))
	end
	stuffed(
		base,
		"Canilla",
		Vector3.new(0.3, 1.6, 0.3),
		CFrame.new(-15, 4.5, -5),
		GOLD_COLOR,
		nil,
		Enum.Material.Metal
	)
	stuffed(
		base,
		"Pico",
		Vector3.new(0.7, 0.2, 0.2),
		CFrame.new(-14.6, 5.1, -5),
		GOLD_COLOR,
		nil,
		Enum.Material.Metal
	)

	local liquids = {
		Color3.fromRGB(40, 90, 50),
		Color3.fromRGB(150, 90, 30),
		Color3.fromRGB(190, 190, 205),
		Color3.fromRGB(110, 28, 40),
		Color3.fromRGB(200, 150, 50),
		Color3.fromRGB(70, 40, 90),
	}
	solid(base, "FondoEstante", Vector3.new(0.5, 11, 24), CFrame.new(-23, 5.5, 0), lacquer, wood)
	-- Luz cálida detrás de la barra para que el vidrio de las botellas brille en la penumbra.
	local backLight =
		stuffed(base, "LuzBarra", Vector3.new(0.2, 0.2, 0.2), CFrame.new(-19, 10, 0), CANDLE_LIGHT)
	backLight.Transparency = 1
	local warm = Instance.new("PointLight")
	warm.Color = Color3.fromRGB(255, 190, 120)
	warm.Range = 26
	warm.Brightness = 1.1
	warm.Shadows = false
	warm.Parent = backLight
	for shelf, y in { 3.6, 6.2, 8.8 } do
		solid(
			base,
			"Estante",
			Vector3.new(1.6, 0.25, 24),
			CFrame.new(-22.3, y, 0),
			WOOD_COLOR,
			wood
		)
		for i = 1, 9 do
			local z = -10 + (i - 1) * 2.5 + shelf * 0.3
			local kind = (i + shelf) % 3 + 1
			local liquid = liquids[(i * 2 + shelf) % #liquids + 1]
			bottle(center + Vector3.new(-22.2, y + 0.125, z), kind, liquid)
		end
	end
	-- Algunos vasos sobre la barra.
	for index, z in { -7, -2.5, 2, 6.5 } do
		drinkingGlass(center + Vector3.new(-14.6, 3.7, z), liquids[index])
	end
	for _, z in { -15, 15 } do
		local spot = center + Vector3.new(8, 0, z)
		solid(
			CFrame.new(spot),
			"PataMesita",
			Vector3.new(0.6, 3.2, 0.6),
			CFrame.new(0, 1.6, 0),
			lacquer,
			wood
		)
		solid(
			CFrame.new(spot),
			"Mesita",
			Vector3.new(4, 0.3, 4),
			CFrame.new(0, 3.35, 0),
			lacquer,
			wood
		)
		for _, side in { -1, 1 } do
			barStool(spot + Vector3.new(side * 3.2, 0, 0))
		end
	end
end

local HEAD_BUILDERS: { [string]: (CFrame) -> () } = {
	moose = mooseHead,
	rhino = rhinoHead,
	crocodile = crocodileHead,
}

local function placeTrophies(id: string)
	local center = cellCenter(id)
	if id == "gameRoom" then
		poolTable(CFrame.new(center + Vector3.new(0, 0, 13)))
		local cabinets = {
			{ x = -16, tint = Color3.fromRGB(200, 60, 120), title = "GALAXIA", art = "invader" },
			{ x = -11, tint = Color3.fromRGB(60, 190, 230), title = "FANTASMA", art = "ghost" },
			{ x = -6, tint = Color3.fromRGB(230, 150, 30), title = "TURBO", art = "car" },
			{ x = -1, tint = Color3.fromRGB(120, 220, 80), title = "CALAVERA", art = "skull" },
		}
		for _, cabinet in cabinets do
			local spot = center + Vector3.new(cabinet.x, 0, -(HALF - 10))
			arcadeCabinet(
				CFrame.lookAt(spot, spot + Vector3.zAxis),
				cabinet.tint,
				cabinet.title,
				cabinet.art
			)
		end
		table.insert(refs.hidingSpots[id], center + Vector3.new(0, 0.3, 13))
	elseif id == "bar" then
		-- La barra va pegada a la pared oeste, que ahora queda más lejos del centro.
		local barCenter = center - Vector3.new(HALF - 28, 0, 0)
		barFittings(barCenter)
		table.insert(refs.hidingSpots[id], barCenter + Vector3.new(-15, 3.9, 6))
		table.insert(refs.hidingSpots[id], barCenter + Vector3.new(-19, 0.3, 0))
	end
	local function onWall(x: number, z: number, inward: Vector3): CFrame
		local point = center + Vector3.new(x, 11, z)
		return CFrame.lookAt(point, point + inward)
	end
	if id == "room1" or id == "room2" then
		-- Cada cabeza se arma en las dos paredes; por partida queda una sola (ver applyVariants).
		local base = if id == "room1"
			then onWall(HALF - 0.5, 13, -Vector3.xAxis)
			else onWall(-HALF + 0.5, 13, Vector3.xAxis)
		local folders: { [string]: Folder } = {}
		for kind, build in HEAD_BUILDERS do
			folders[kind] = inFolder(`Cabeza_{kind}`, function()
				build(base)
			end)
		end
		headFolders[id] = folders
	elseif id == "room11" then
		-- En el centro, con la cabeza (su +X) hacia el ventanal de +Z. Cambia de animal por partida.
		local top = animalPlinth(CFrame.lookAt(center, center + Vector3.xAxis))
		for _, kind in ANIMAL_ORDER do
			animalFolders[kind] = inFolder(`Animal_{kind}`, function()
				ANIMALS[kind](top)
			end)
		end
	end
end

local lastAnimal: string? = nil

-- Muestra una variante de cada animal y cabeza; las demás quedan guardadas sin padre.
local function applyVariants(random: Random)
	local function showOnly(folders: { [string]: Folder }, keep: string?)
		for kind, folder in folders do
			folder.Parent = if kind == keep then world else nil
		end
	end
	local animal = ANIMAL_ORDER[random:NextInteger(1, #ANIMAL_ORDER)]
	while animal == lastAnimal do
		animal = ANIMAL_ORDER[random:NextInteger(1, #ANIMAL_ORDER)]
	end
	lastAnimal = animal
	showOnly(animalFolders, animal)
	local heads = { "moose", "rhino", "crocodile" }
	local keptRoom = if random:NextInteger(1, 2) == 1 then "room1" else "room2"
	local keptKind = heads[random:NextInteger(1, #heads)]
	for room, folders in headFolders do
		showOnly(folders, if room == keptRoom then keptKind else nil)
	end
end

-- Paletas que se sortean por pieza en cada partida.
local WALL_PALETTE = {
	Color3.fromRGB(205, 205, 198),
	Color3.fromRGB(170, 186, 162),
	Color3.fromRGB(164, 178, 198),
	Color3.fromRGB(204, 172, 166),
	Color3.fromRGB(214, 192, 144),
	Color3.fromRGB(178, 162, 188),
}
local FLOOR_PALETTE = {
	Color3.fromRGB(98, 30, 26),
	Color3.fromRGB(86, 54, 36),
	Color3.fromRGB(62, 42, 32),
	Color3.fromRGB(48, 62, 48),
	Color3.fromRGB(122, 72, 42),
}
local RUG_PALETTE = {
	Color3.fromRGB(60, 80, 150),
	Color3.fromRGB(80, 120, 80),
	Color3.fromRGB(150, 110, 60),
	Color3.fromRGB(130, 50, 60),
	Color3.fromRGB(70, 110, 120),
	Color3.fromRGB(110, 80, 130),
}
local structureFolders: { [string]: Folder } = {}
local decorationFolders: { [string]: Folder } = {}

-- Pinta de nuevo las paredes y el piso de la pieza con colores sorteados.
local function skinRoom(id: string, random: Random)
	local folder = structureFolders[id]
	if not folder then
		return
	end
	local wallColor = WALL_PALETTE[random:NextInteger(1, #WALL_PALETTE)]
	local floorColor = FLOOR_PALETTE[random:NextInteger(1, #FLOOR_PALETTE)]
	for _, item in folder:GetChildren() do
		if item:IsA("BasePart") then
			if item.Name == "Pared" then
				item.Color = wallColor
			elseif item.Name == "Placa" and item.Material == Enum.Material.WoodPlanks then
				item.Color = floorColor
			end
		end
	end
end

-- Alfombra y cuadros de la pieza, en una carpeta propia que se rearma en cada partida.
local function dressRoom(id: string, random: Random)
	if PLAN[id].y == CELLAR_Y then
		return
	end
	local old = decorationFolders[id]
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = `Decoracion_{id}`
	folder.Parent = world
	decorationFolders[id] = folder
	buildParent = folder
	local center = cellCenter(id)
	local rugCenter = if STAIR_ROOMS[id] then center + Vector3.new(8, 0, 0) else center
	rug(
		rugCenter,
		ROOM_SIZE * 0.36,
		ROOM_SIZE * 0.46,
		RUG_PALETTE[random:NextInteger(1, #RUG_PALETTE)]
	)
	local y = center.Y + 9
	local kinds = { 1, 2, 3 }
	local placements = {
		{ Vector3.new(HALF - 8, 0, -HALF + 0.7), Vector3.zAxis },
		{ Vector3.new(-(HALF - 8), 0, HALF - 0.7), -Vector3.zAxis },
		{ Vector3.new(HALF - 0.7, 0, HALF - 8), -Vector3.xAxis },
		{ Vector3.new(-HALF + 0.7, 0, -(HALF - 6)), Vector3.xAxis },
	}
	for i, placement in placements do
		painting(
			Vector3.new(center.X, y, center.Z) + placement[1],
			placement[2],
			kinds[(i + random:NextInteger(0, 2)) % 3 + 1]
		)
	end
	buildParent = nil
end

local function decorateRoom(id: string, random: Random)
	placeTrophies(id)
	local center = cellCenter(id)
	local inCellar = PLAN[id].y == CELLAR_Y
	dressRoom(id, random)
	if id == "room2" then -- Mesa larga de comedor
		local base = CFrame.new(center)
		solid(
			base,
			"MesaComedor",
			Vector3.new(7, 0.8, 20),
			CFrame.new(0, 3.4, 0),
			WOOD_COLOR,
			Enum.Material.Wood
		)
		for _, z in { -8, 8 } do
			for _, x in { -3, 3 } do
				solid(base, "Pata", Vector3.new(0.7, 3, 0.7), CFrame.new(x, 1.5, z), WOOD_COLOR)
			end
		end
		local table_spots = refs.hidingSpots[id]
		table.insert(table_spots, center + Vector3.new(1, 4.1, 5))
		table.insert(table_spots, center + Vector3.new(-1, 0.3, -4))
	end
	if CHANDELIER_ROOMS[id] then
		chandelier(center + (if STAIR_ROOMS[id] then Vector3.new(8, 0, 0) else Vector3.zero))
	end
	if inCellar then
		return
	end
end

-- Da a cada pieza el lenguaje del hall con pocas partes: zócalo, cornisa, pilastras y vigas.
local function styleRoom(id: string, openings: { [string]: Opening })
	local center = cellCenter(id)
	local inCellar = PLAN[id].y == CELLAR_Y
	local trim = if inCellar then Color3.fromRGB(70, 66, 60) else WOOD_COLOR
	local inset = HALF - 0.6
	local sides = {
		{ key = "E", at = Vector3.xAxis, along = Vector3.zAxis },
		{ key = "W", at = -Vector3.xAxis, along = Vector3.zAxis },
		{ key = "S", at = Vector3.zAxis, along = Vector3.xAxis },
		{ key = "N", at = -Vector3.zAxis, along = Vector3.xAxis },
	}
	local function band(
		position: Vector3,
		along: Vector3,
		length: number,
		height: number,
		color: Color3
	)
		decor({
			Name = "Moldura",
			Size = if along.X ~= 0
				then Vector3.new(length, height, 0.5)
				else Vector3.new(0.5, height, length),
			Position = position,
			Color = color,
			Material = Enum.Material.Wood,
		})
	end
	for _, side in sides do
		local wallPoint = center + side.at * inset
		local opening = openings[side.key]
		-- El zócalo se corta donde hay una puerta.
		local baseY = Vector3.new(0, 0.6, 0)
		if opening and opening.bottom == 0 then
			local length = (ROOM_SIZE - opening.width) / 2
			local offset = (opening.width + length) / 2
			band(wallPoint + side.along * offset + baseY, side.along, length, 1.2, trim)
			band(wallPoint - side.along * offset + baseY, side.along, length, 1.2, trim)
		else
			band(wallPoint + baseY, side.along, ROOM_SIZE, 1.2, trim)
		end
		band(wallPoint + Vector3.new(0, CEILING - 0.5, 0), side.along, ROOM_SIZE, 1, GOLD_COLOR)
		-- Papel tapiz: franjas verticales más oscuras y gastadas, salvo donde hay puertas o ventanales.
		local gap = if opening then opening.width / 2 + 1.5 else 0
		for slot = -5, 5 do
			local offset = slot * 6
			if math.abs(offset) > gap then
				decor({
					Name = "Tapiz",
					Size = if side.along.X ~= 0
						then Vector3.new(2.4, CEILING - 3.4, 0.12)
						else Vector3.new(0.12, CEILING - 3.4, 2.4),
					Position = wallPoint
						+ side.along * offset
						+ Vector3.new(0, 1.6 + (CEILING - 3.4) / 2, 0),
					Color = if inCellar
						then Color3.fromRGB(96, 92, 86)
						else Color3.fromRGB(168, 148, 136),
					Material = Enum.Material.Fabric,
				})
			end
		end
		-- (Sin pilastras claras: chocaban con el papel tapiz y con los marcos.)
	end
	-- Vigas del techo, salvo donde lo atraviesa una escalera.
	if not STAIR_ROOMS[id] then
		for _, offset in { -12, 12 } do
			decor({
				Name = "Viga",
				Size = Vector3.new(ROOM_SIZE, 0.9, 1.2),
				Position = center + Vector3.new(0, CEILING - 0.45, offset),
				Color = CEILING_COLOR,
				Material = Enum.Material.Wood,
			})
			decor({
				Name = "Viga",
				Size = Vector3.new(1.2, 0.9, ROOM_SIZE),
				Position = center + Vector3.new(offset, CEILING - 0.45, 0),
				Color = CEILING_COLOR,
				Material = Enum.Material.Wood,
			})
		end
	end
	-- Columnas de piedra que sostienen el sótano.
	if id == "room6" then
		for _, x in { -12, 12 } do
			for _, z in { -12, 12 } do
				part({
					Name = "ColumnaSotano",
					Size = Vector3.new(2.4, CEILING, 2.4),
					Position = center + Vector3.new(x, CEILING / 2, z),
					Color = Color3.fromRGB(96, 92, 84),
					Material = Enum.Material.Cobblestone,
				})
			end
		end
	end
	-- Banco bajo cada ventanal, y una consola con florero en las paredes ciegas.
	if not inCellar then
		for _, side in sides do
			local opening = openings[side.key]
			local spot = center + side.at * (HALF - 2.4)
			local stairSide = STAIR_ROOMS[id] and side.key == "W"
			if opening and opening.bottom > 0 then
				local base = CFrame.lookAt(spot, center)
				solid(
					base,
					"Banco",
					Vector3.new(14, 1.4, 2.6),
					CFrame.new(0, 0.9, 0),
					FABRIC_COLOR,
					Enum.Material.Fabric
				)
			elseif not opening and not stairSide then
				local base = CFrame.lookAt(spot, center)
				solid(base, "Consola", Vector3.new(9, 3, 2.4), CFrame.new(0, 1.5, 0), WOOD_COLOR)
				solid(
					base,
					"Florero",
					Vector3.new(1, 1.8, 1),
					CFrame.new(-2.6, 3.9, 0),
					GOLD_COLOR,
					Enum.Material.Marble
				)
				local spots = refs.hidingSpots[id]
				if spots then
					table.insert(spots, (base * CFrame.new(1.8, 3.3, 0)).Position)
				end
			end
		end
	end
	-- Sillas alrededor de la mesa del comedor.
	if id == "room2" then
		for _, x in { -5.2, 5.2 } do
			for _, z in { -6, 0, 6 } do
				solid(
					CFrame.new(center),
					"Silla",
					Vector3.new(2, 2.2, 2),
					CFrame.new(x, 1.1, z),
					WOOD_COLOR
				)
				solid(
					CFrame.new(center),
					"Respaldo",
					Vector3.new(0.4, 2.6, 2),
					CFrame.new(x + math.sign(x) * 0.9, 3.4, z),
					WOOD_COLOR
				)
			end
		end
	end
end

local function buildRoom(id: string, random: Random, openings: { [string]: Opening })
	local center = cellCenter(id)
	-- Piso, techo y paredes van a una carpeta propia para poder repintarlos en cada partida.
	local structure = Instance.new("Folder")
	structure.Name = `Estructura_{id}`
	structure.Parent = world
	structureFolders[id] = structure
	buildParent = structure
	plate(
		center - Vector3.new(0, 0.5, 0),
		1,
		FLOOR_COLOR,
		Enum.Material.WoodPlanks,
		FLOOR_HOLES[id]
	)
	plate(
		center + Vector3.new(0, CEILING + 0.5, 0),
		1,
		CEILING_COLOR,
		Enum.Material.Wood,
		CEILING_HOLES[id]
	)
	-- Las paredes terminan apenas debajo del piso de arriba, para que no asomen en sus umbrales.
	local wallTop = LEVEL_HEIGHT - 0.2
	wall(center + Vector3.new(HALF, 0, 0), Vector3.zAxis, ROOM_SIZE, wallTop, openings.E)
	wall(center - Vector3.new(HALF, 0, 0), Vector3.zAxis, ROOM_SIZE, wallTop, openings.W)
	wall(center + Vector3.new(0, 0, HALF), Vector3.xAxis, ROOM_SIZE, wallTop, openings.S)
	wall(center - Vector3.new(0, 0, HALF), Vector3.xAxis, ROOM_SIZE, wallTop, openings.N)
	buildParent = nil

	for _, offset in
		{
			Vector3.new(-18, 0, -HALF + 1),
			Vector3.new(18, 0, HALF - 1),
			Vector3.new(-HALF + 1, 0, 19),
			Vector3.new(HALF - 1, 0, -18),
		}
	do
		candle(center + offset + Vector3.new(0, 8, 0), CANDLE_LIGHT)
	end

	if id ~= "hall" then
		furnishRoom(id, random)
	end
	decorateRoom(id, random)
	styleRoom(id, openings)
	skinRoom(id, random)
end

-- Dibuja una cara de la hoja sobre la superficie, sin agregar partes: paneles de madera,
-- picaporte y placa del color de la llave. En las rejas, barrotes de hierro.
local function doorFace(
	leaf: BasePart,
	face: Enum.NormalId,
	emblem: Color3,
	gate: boolean,
	hingeSide: number,
	width: number,
	height: number
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 1
	gui.Parent = leaf
	local function rect(x: number, y: number, w: number, h: number, color: Color3): Frame
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(x, y)
		frame.Size = UDim2.fromScale(w, h)
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Parent = gui
		return frame
	end
	-- El borde libre, lejos de la bisagra, cae a un lado u otro según la cara que se mira.
	local sign = if face == Enum.NormalId.Front or face == Enum.NormalId.Right then -1 else 1
	local freeEdge = 0.5 - hingeSide * sign * 0.5

	if gate then
		local iron = Color3.fromRGB(28, 28, 32)
		local bars = math.max(math.floor(width / 1.2), 3)
		for i = 1, bars do
			rect((i - 0.5) / bars, 0.5, 0.04, 1, iron)
		end
		rect(0.5, 0.03, 1, 0.05, iron)
		rect(0.5, 0.5, 1, 0.04, iron)
		rect(0.5, 0.97, 1, 0.05, iron)
		local badge = rect(math.abs(freeEdge - 0.12), 0.5, 2.2 / width, 1.4 / height, emblem)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(190, 180, 150)
		stroke.Parent = badge
		return
	end

	local shade = Color3.fromRGB(34, 20, 12)
	rect(0.5, 0.27, 0.74, 0.38, shade)
	rect(0.5, 0.74, 0.74, 0.36, shade)
	local knob = rect(math.abs(freeEdge - 0.1), 0.53, 0.5 / width, 0.5 / height, GOLD_COLOR)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = knob
	-- Placa chica con el color de la llave; el contorno distingue también a la negra.
	local badge = rect(0.5, 0.27, 2 / width, 1.2 / height, emblem)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(190, 180, 150)
	stroke.Thickness = 2
	stroke.Parent = badge
end

local function buildDoor(
	key: string,
	position: Vector3,
	along: Vector3,
	actionText: string,
	width: number,
	height: number,
	blockerWidth: number,
	blockerHeight: number,
	style: string?
): Door
	local function sized(w: number, h: number): Vector3
		return if math.abs(along.X) > 0 then Vector3.new(w, h, 0.6) else Vector3.new(0.6, h, w)
	end
	local keyIndex = Config.DoorKeys[key]
	local keyColor = if keyIndex then Config.KeyColors[keyIndex] else nil
	local emblem =
		Color3.fromRGB(table.unpack(if keyColor then keyColor.rgb else Config.GoldKeyRgb))
	local gate = style == "gate"

	-- Una o dos hojas, cada una girando sobre su propia bisagra del marco.
	local leaves = {}
	local double = gate or width >= 14
	local count = if double then 2 else 1
	local leafWidth = width / count
	local faces = if math.abs(along.X) > 0
		then { Enum.NormalId.Front, Enum.NormalId.Back }
		else { Enum.NormalId.Left, Enum.NormalId.Right }
	for i = 1, count do
		local side = if i == 1 then -1 else 1
		local hinge = position + along * side * (width / 2) + Vector3.new(0, height / 2, 0)
		local center = hinge - along * side * (leafWidth / 2)
		local closed = CFrame.new(center)
		local angle = math.rad(side * 100)
		local hingeFrame = CFrame.new(hinge)
		local open = hingeFrame * CFrame.Angles(0, angle, 0) * hingeFrame:Inverse() * closed
		local leaf = part({
			Name = `Puerta_{key}`,
			Size = sized(leafWidth, height),
			CFrame = closed,
			Color = Color3.fromRGB(52, 30, 18),
			Material = Enum.Material.WoodPlanks,
			Transparency = if gate then 1 else 0,
			CanCollide = false,
		})
		for _, face in faces do
			doorFace(leaf, face, emblem, gate, side, leafWidth, height)
		end
		table.insert(leaves, { part = leaf, closed = closed, open = open })
	end

	-- Marco fijo: rellena el resto del hueco; el dintel lleva el color de la llave.
	local jamb = (blockerWidth - width) / 2
	if jamb > 0 then
		for _, side in { -1, 1 } do
			part({
				Name = "Marco",
				Size = sized(jamb, blockerHeight),
				Position = position
					+ along * side * (width / 2 + jamb / 2)
					+ Vector3.new(0, blockerHeight / 2, 0),
				Color = WOOD_COLOR,
				Material = Enum.Material.Wood,
			})
		end
	end
	if blockerHeight > height then
		part({
			Name = "Dintel",
			Size = sized(blockerWidth, blockerHeight - height),
			Position = position + Vector3.new(0, (height + blockerHeight) / 2, 0),
			Color = emblem,
			Material = Enum.Material.Wood,
		})
	end
	-- Sella todo el hueco, aunque sea más ancho y alto que la hoja de la puerta.
	local blocker = part({
		Name = "BloqueoPuerta",
		Size = sized(blockerWidth, blockerHeight),
		CFrame = CFrame.new(position + Vector3.new(0, blockerHeight / 2, 0)),
		Transparency = 1,
		CanQuery = false,
		CollisionGroup = "LockedDoor",
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = if keyColor then `Puerta {keyColor.name}` else "Puerta principal"
	prompt.MaxActivationDistance = Config.InteractRange
	prompt.RequiresLineOfSight = false
	-- En el bloqueo, que no se mueve con las hojas.
	prompt.Parent = blocker
	return {
		leaves = leaves,
		blocker = blocker,
		position = position + Vector3.new(0, height / 2, 0),
		twin = nil,
		unlocked = false,
		swung = false,
		prompt = prompt,
		normal = if math.abs(along.X) > 0 then Vector3.zAxis else Vector3.xAxis,
		metal = key == "exit",
	}
end

local function buildLink(a: string, b: string)
	local ca, cb = cellCenter(a), cellCenter(b)
	local dir = (cb - ca).Unit
	-- El pasillo va de la pared de una pieza a la de la otra. El hall y la galería no miden lo mismo
	-- que las demás: su pared está donde dice GrandHall.
	local function wallOf(id: string, center: Vector3, toward: Vector3): Vector3
		if GRAND_ROOMS[id] then
			return Vector3.new(
				if toward.X > 0 then GrandHall.X1 else GrandHall.X0,
				center.Y,
				center.Z
			)
		end
		return center + toward * HALF
	end
	local wallA = wallOf(a, ca, dir)
	local wallB = wallOf(b, cb, -dir)
	local middle = (wallA + wallB) / 2
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local length = (wallB - wallA).Magnitude
	-- Del lado del hall arranca adentro de la pared, para no coincidir con su cara interna.
	local hallTrim = if GRAND_ROOMS[a] then 0.05 else 0
	local slabMiddle = middle + dir * hallTrim / 2
	local slabLength = length - hallTrim
	local floorSize = if math.abs(dir.X) > 0
		then Vector3.new(slabLength, 1, CORRIDOR_WIDTH + 2)
		else Vector3.new(CORRIDOR_WIDTH + 2, 1, slabLength)
	part({
		Name = "PisoPasillo",
		Size = floorSize,
		Position = slabMiddle - Vector3.new(0, 0.5, 0),
		Color = FLOOR_COLOR,
		Material = Enum.Material.WoodPlanks,
	})
	part({
		Name = "TechoPasillo",
		Size = floorSize,
		-- Un pelo más arriba que el dintel de la pared, para que no se peleen en el mismo plano.
		Position = slabMiddle + Vector3.new(0, CORRIDOR_HEIGHT + 0.55, 0),
		Color = CEILING_COLOR,
		Material = Enum.Material.Wood,
	})
	for _, side in { -1, 1 } do
		wall(middle + across * side * (CORRIDOR_WIDTH / 2 + 0.5), dir, length, CORRIDOR_HEIGHT)
	end
	candle(middle + across * (CORRIDOR_WIDTH / 2 - 0.5) + Vector3.new(0, 7, 0), CANDLE_LIGHT)
	addRoute(a, b, { middle })

	for _, side in { -1, 1 } do
		decor({
			Name = "Zocalo",
			Size = if math.abs(dir.X) > 0
				then Vector3.new(length, 1.2, 0.4)
				else Vector3.new(0.4, 1.2, length),
			Position = middle + across * side * (CORRIDOR_WIDTH / 2 - 0.2) + Vector3.new(0, 0.6, 0),
			Color = WOOD_COLOR,
			Material = Enum.Material.Wood,
		})
	end

	-- La puerta (si este pasillo la lleva en la partida) se pone aparte, en placeCorridorDoors.
	corridorSpots[`{a}|{b}`] = { middle = middle, across = across }
end

-- Tablones clavados que tapian un pasillo: una barrera invisible que frena a todos y encima los
-- tablones cruzados, uno por altura, algo torcidos.
local function buildBarrier(spot: { middle: Vector3, across: Vector3 }): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Tapiado"
	buildParent = folder
	local up = Vector3.yAxis
	local along = Vector3.new(-spot.across.Z, 0, spot.across.X)
	part({
		Name = "BloqueoTapiado",
		Size = Vector3.new(CORRIDOR_WIDTH, CORRIDOR_HEIGHT, 1.6),
		CFrame = CFrame.fromMatrix(spot.middle + up * (CORRIDOR_HEIGHT / 2), spot.across, up),
		Transparency = 1,
		CanQuery = false,
		CollisionGroup = "LockedDoor",
	})
	for i = 1, 6 do
		local y = 1.4 + (i - 1) * 2.1
		local depth = if i % 2 == 0 then 0.35 else -0.3
		local tilt = if i % 2 == 0 then 0.035 else -0.05
		decor({
			Name = "Tablon",
			Size = Vector3.new(CORRIDOR_WIDTH + 0.4, 0.95, 0.4),
			CFrame = CFrame.fromMatrix(spot.middle + up * y + along * depth, spot.across, up)
				* CFrame.Angles(0, 0, tilt),
			Color = Color3.fromRGB(86 - i * 3, 58 - i * 2, 38),
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- Dos tablones en diagonal que cruzan todo, con clavos de hierro en las puntas.
	for _, side in { -1, 1 } do
		decor({
			Name = "TablonDiagonal",
			Size = Vector3.new(CORRIDOR_HEIGHT * 1.15, 0.9, 0.4),
			CFrame = CFrame.fromMatrix(
				spot.middle + up * (CORRIDOR_HEIGHT / 2) + along * 0.75,
				spot.across,
				up
			) * CFrame.Angles(0, 0, math.rad(side * 48)),
			Color = Color3.fromRGB(74, 50, 34),
			Material = Enum.Material.WoodPlanks,
		})
		for _, y in { 2, 7, 12 } do
			decor({
				Name = "Clavo",
				Size = Vector3.new(0.35, 0.35, 0.35),
				Position = spot.middle
					+ up * y
					+ spot.across * side * (CORRIDOR_WIDTH / 2 - 0.6)
					+ along * 0.8,
				Color = Color3.fromRGB(28, 28, 30),
				Material = Enum.Material.Metal,
				Shape = Enum.PartType.Ball,
			})
		end
	end
	buildParent = nil
	return folder
end

-- Saca las puertas y los tablones de la partida anterior y pone los de `layout`.
local function placeCorridorDoors(layout: MapDef.Layout)
	for label, folder in corridorDoorFolders do
		folder:Destroy()
		corridorDoorFolders[label] = nil
		refs.doors[label] = nil
	end
	for key, folder in corridorBarrierFolders do
		folder:Destroy()
		corridorBarrierFolders[key] = nil
	end
	currentLayout = layout
	if RunService:IsStudio() then
		local parts = {}
		for spotKey, label in layout.locks do
			table.insert(parts, `{spotKey}={label}`)
		end
		table.sort(parts)
		local sealed = {}
		for spotKey in layout.sealed do
			table.insert(sealed, spotKey)
		end
		table.sort(sealed)
		print(`[Mapa] tapiados: {table.concat(sealed, " ")} | puertas: {table.concat(parts, "  ")}`)
	end
	for spotKey, label in layout.locks do
		local spot = corridorSpots[spotKey]
		local folder = Instance.new("Folder")
		folder.Name = `Puerta_{label}`
		buildParent = folder
		refs.doors[label] = buildDoor(
			label,
			spot.middle,
			spot.across,
			"Abrir",
			DOOR_WIDTH,
			DOOR_HEIGHT,
			CORRIDOR_WIDTH,
			CORRIDOR_HEIGHT
		)
		buildParent = nil
		folder.Parent = world
		corridorDoorFolders[label] = folder
	end
	for spotKey in layout.sealed do
		local folder = buildBarrier(corridorSpots[spotKey])
		folder.Parent = world
		corridorBarrierFolders[spotKey] = folder
	end
end

-- Sortea la distribución de la partida. Descarta las que no permiten repartir las seis llaves,
-- porque habría una puerta que no se podría abrir.
local function rollDoors(random: Random)
	local function roll(n: number): number
		return random:NextInteger(1, n)
	end
	local function anyRoom(_: string): boolean
		return true
	end
	for _ = 1, 40 do
		local layout = MapDef.rollLayout(roll)
		local needs = MapDef.needs(layout)
		for _ = 1, 10 do
			if Placement.keyRooms(needs, Config.DoorKeys, Config.KeyCount, roll, anyRoom) then
				placeCorridorDoors(layout)
				return
			end
		end
	end
	placeCorridorDoors(MapDef.DefaultLayout)
end

-- Escalera ancha entre `lower` y `upper`, con reja arriba o abajo según `gateAtTop`.
local function buildStairs(lower: string, upper: string, doorKey: string, gateAtTop: boolean)
	local base = cellCenter(lower)
	local xCenter = (STAIR.x0 + STAIR.x1) / 2
	local width = STAIR.x1 - STAIR.x0
	local steps = LEVEL_HEIGHT
	local run = (STAIR.z1 - STAIR.z0) / steps
	for i = 1, steps do
		local z = STAIR.z0 + run * (i - 0.5)
		part({
			Name = "Escalon",
			Size = Vector3.new(width, i, run),
			Position = base + Vector3.new(xCenter, i / 2, z),
			Color = Color3.fromRGB(70, 44, 28),
			Material = Enum.Material.Wood,
		})
	end

	-- Laterales de una pieza en cuña: se ven limpios desde abajo y llegan justo al piso de arriba.
	local stairLength = STAIR.z1 - STAIR.z0
	local stairMidZ = (STAIR.z0 + STAIR.z1) / 2
	for _, x in { STAIR.x0 - 0.5, STAIR.x1 + 0.5 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "LateralEscalera"
		wedge.Anchored = true
		wedge.Size = Vector3.new(1, steps, stairLength)
		wedge.CFrame = CFrame.new(base + Vector3.new(x, steps / 2, stairMidZ))
			* CFrame.Angles(0, math.rad(180), 0)
		wedge.Color = WOOD_COLOR
		wedge.Material = Enum.Material.Wood
		wedge.Parent = world
	end

	-- Baranda recta alrededor del hueco; una pared invisible impide saltarla.
	local rails = {
		{
			Vector3.new(STAIR.x0 - 0.5, LEVEL_HEIGHT, stairMidZ),
			Vector3.new(0.6, 0.5, stairLength + 1),
		},
		{
			Vector3.new(STAIR.x1 + 0.5, LEVEL_HEIGHT, stairMidZ),
			Vector3.new(0.6, 0.5, stairLength + 1),
		},
		{ Vector3.new(xCenter, LEVEL_HEIGHT, STAIR.z0 - 0.5), Vector3.new(width + 2, 0.5, 0.6) },
	}
	for _, rail in rails do
		part({
			Name = "Baranda",
			Size = rail[2],
			Position = base + rail[1] + Vector3.new(0, 3.5, 0),
			Color = WOOD_COLOR,
			Material = Enum.Material.Wood,
		})
		part({
			Name = "ParedInvisible",
			Size = Vector3.new(math.max(rail[2].X, 1), LEVEL_HEIGHT - 2, math.max(rail[2].Z, 1)),
			Position = base + rail[1] + Vector3.new(0, (LEVEL_HEIGHT - 2) / 2, 0),
			Transparency = 1,
			CanQuery = false,
		})
	end
	for _, x in { STAIR.x0 - 0.5, STAIR.x1 + 0.5 } do
		for offset = 0, stairLength, 6 do
			part({
				Name = "Balaustre",
				Size = Vector3.new(0.5, 3.5, 0.5),
				Position = base + Vector3.new(x, LEVEL_HEIGHT + 1.75, STAIR.z0 + offset),
				Color = WOOD_COLOR,
				Material = Enum.Material.Wood,
			})
		end
	end

	local gatePosition = if gateAtTop
		then base + Vector3.new(xCenter, LEVEL_HEIGHT, STAIR.z1 + 0.5)
		else base + Vector3.new(xCenter, 0, STAIR.z0 - 1)
	refs.doors[doorKey] = buildDoor(
		doorKey,
		gatePosition,
		Vector3.xAxis,
		"Abrir",
		width,
		DOOR_HEIGHT,
		width,
		CORRIDOR_HEIGHT,
		"gate"
	)

	local up = LEVEL_HEIGHT
	addRoute(lower, upper, {
		base + Vector3.new(STAIR.x1 + 5, 0, STAIR.z0 - 6),
		base + Vector3.new(xCenter, 0, STAIR.z0 - 6),
		base + Vector3.new(xCenter, up, STAIR.z1 + 3),
		base + Vector3.new(STAIR.x1 + 5, up, STAIR.z1 + 3),
	})
end

local function buildRefuge(id: string, room: string, dir: Vector3)
	local mouth = cellCenter(room) + dir * HALF
	local center = mouth + dir * (REFUGE_DEPTH / 2)
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local size = Vector3.new(
		math.abs(dir.X) * REFUGE_DEPTH + math.abs(across.X) * REFUGE_WIDTH,
		1,
		math.abs(dir.Z) * REFUGE_DEPTH + math.abs(across.Z) * REFUGE_WIDTH
	)
	part({
		Name = `Piso_{id}`,
		Size = size,
		Position = center - Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(32, 36, 48),
		Material = Enum.Material.Fabric,
	})
	part({
		Name = "Techo",
		Size = size,
		Position = center + Vector3.new(0, CORRIDOR_HEIGHT + 0.5, 0),
		Color = CEILING_COLOR,
	})
	wall(mouth + dir * REFUGE_DEPTH, across, REFUGE_WIDTH, CORRIDOR_HEIGHT)
	for _, side in { -1, 1 } do
		wall(center + across * side * (REFUGE_WIDTH / 2), dir, REFUGE_DEPTH, CORRIDOR_HEIGHT)
	end
	candle(center + across * 10 + Vector3.new(0, 6, 0), REFUGE_LIGHT)
	candle(center - across * 10 + Vector3.new(0, 6, 0), REFUGE_LIGHT)

	-- Barrera que solo frena al asesino.
	local barrierCenter = mouth + Vector3.new(0, CORRIDOR_HEIGHT / 2, 0)
	part({
		Name = "BarreraAsesino",
		Size = Vector3.new(CORRIDOR_WIDTH + 2, CORRIDOR_HEIGHT, 2),
		CFrame = CFrame.lookAt(barrierCenter, barrierCenter + dir),
		Transparency = 1,
		CanQuery = false,
		CollisionGroup = "KillerBarrier",
	})
	refs.rooms[id] = { center = center, size = Vector3.new(size.X, CORRIDOR_HEIGHT, size.Z) }
	refs.refugeDoors[id] = mouth - dir * 5
end

local function sideOf(dir: Vector3): string
	if dir.X > 0.5 then
		return "E"
	elseif dir.X < -0.5 then
		return "W"
	elseif dir.Z > 0.5 then
		return "S"
	end
	return "N"
end

local function setupCollisionGroups()
	PhysicsService:RegisterCollisionGroup("Killer")
	PhysicsService:RegisterCollisionGroup("KillerBarrier")
	PhysicsService:RegisterCollisionGroup("LockedDoor")
	PhysicsService:RegisterCollisionGroup("KillerPass")
	PhysicsService:CollisionGroupSetCollidable("KillerPass", "Killer", false)
	PhysicsService:CollisionGroupSetCollidable("KillerBarrier", "Default", false)
	-- El modo desarrollador atraviesa puertas cerradas y barreras.
	PhysicsService:RegisterCollisionGroup("DevPlayer")
	PhysicsService:CollisionGroupSetCollidable("DevPlayer", "LockedDoor", false)
	PhysicsService:CollisionGroupSetCollidable("DevPlayer", "KillerBarrier", false)
end

-- Cadáver tirado en el piso, a lo largo de su Z local, con su charco.
local function lyingCorpse(base: CFrame, skin: Color3)
	local cloth = Color3.fromRGB(58, 52, 46)
	local wound = Color3.fromRGB(96, 14, 18)
	local pool = Color3.fromRGB(58, 6, 8)
	stuffed(
		base,
		"Charco",
		Vector3.new(6, 0.05, 8),
		CFrame.new(0.5, 0.03, 0),
		pool,
		nil,
		Enum.Material.SmoothPlastic
	)
	stuffed(base, "CuerpoTorso", Vector3.new(2, 0.9, 2.6), CFrame.new(0, 0.5, 0), cloth)
	stuffed(
		base,
		"Herida",
		Vector3.new(1.2, 0.08, 1.3),
		CFrame.new(0.1, 0.97, 0.2),
		wound,
		nil,
		Enum.Material.SmoothPlastic
	)
	stuffed(
		base,
		"CuerpoCabeza",
		Vector3.new(1.1, 0.9, 1.1),
		CFrame.new(0.2, 0.5, 2) * CFrame.Angles(0, math.rad(25), 0),
		skin
	)
	for _, side in { -1, 1 } do
		stuffed(
			base,
			"CuerpoPierna",
			Vector3.new(0.75, 0.7, 2.8),
			CFrame.new(side * 0.55, 0.38, -2.6) * CFrame.Angles(0, math.rad(side * 10), 0),
			cloth
		)
		stuffed(
			base,
			"CuerpoBrazo",
			Vector3.new(0.6, 0.55, 2.5),
			CFrame.new(side * 1.7, 0.32, 0.5) * CFrame.Angles(0, math.rad(side * 35), 0),
			skin
		)
	end
end

-- Cadáver colgado de las muñecas con dos cadenas que bajan del techo.
local function hangingCorpse(position: Vector3, height: number, skin: Color3)
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(position.Z * 13 % 360), 0)
	local cloth = Color3.fromRGB(70, 62, 54)
	local wound = Color3.fromRGB(96, 14, 18)
	local chain = Color3.fromRGB(70, 70, 74)
	stuffed(base, "CuerpoTorso", Vector3.new(1.9, 2.5, 1), CFrame.new(0, 5.6, 0), cloth)
	stuffed(
		base,
		"Herida",
		Vector3.new(1, 1.3, 0.08),
		CFrame.new(0, 5.4, -0.52),
		wound,
		nil,
		Enum.Material.SmoothPlastic
	)
	stuffed(
		base,
		"CuerpoCabeza",
		Vector3.new(1, 1, 1),
		CFrame.new(0, 7, -0.35) * CFrame.Angles(math.rad(-30), 0, 0),
		skin
	)
	for _, side in { -1, 1 } do
		stuffed(
			base,
			"CuerpoPierna",
			Vector3.new(0.75, 2.8, 0.8),
			CFrame.new(side * 0.5, 3, 0),
			cloth
		)
		stuffed(
			base,
			"CuerpoBrazo",
			Vector3.new(0.55, 2.6, 0.6),
			CFrame.new(side * 1.1, 7.8, 0) * CFrame.Angles(0, 0, math.rad(side * -14)),
			skin
		)
		-- Eslabones alternados desde la muñeca hasta el techo.
		local y = 9.1
		local i = 0
		while y < height do
			local turn = if i % 2 == 0 then 0 else 90
			stuffed(
				base,
				"Eslabon",
				Vector3.new(0.09, 0.6, 0.28),
				CFrame.new(side * 1.45, y, 0) * CFrame.Angles(0, math.rad(turn), 0),
				chain,
				nil,
				Enum.Material.Metal
			)
			y += 0.48
			i += 1
		end
	end
	stuffed(
		base,
		"Charco",
		Vector3.new(3.4, 0.05, 3.4),
		CFrame.new(0, 0.03, 0),
		Color3.fromRGB(58, 6, 8),
		nil,
		Enum.Material.SmoothPlastic
	)
end

-- Mesa de carnicero toda de metal, con bisturí, serrucho, cuchilla, pinza, martillo y gancho.
local function butcherTable(base: CFrame)
	local steel = Color3.fromRGB(176, 180, 186)
	local dark = Color3.fromRGB(26, 24, 22)
	local blood = Color3.fromRGB(80, 8, 10)
	local metal = Enum.Material.Metal
	local plastic = Enum.Material.SmoothPlastic
	solid(
		base,
		"MesaMetal",
		Vector3.new(13, 0.3, 5),
		CFrame.new(0, 3.5, 0),
		steel,
		Enum.Material.DiamondPlate
	)
	for _, side in { -1, 1 } do
		solid(
			base,
			"Reborde",
			Vector3.new(13, 0.35, 0.2),
			CFrame.new(0, 3.75, side * 2.4),
			steel,
			metal
		)
		solid(
			base,
			"Reborde",
			Vector3.new(0.2, 0.35, 5),
			CFrame.new(side * 6.4, 3.75, 0),
			steel,
			metal
		)
		for _, z in { -2.1, 2.1 } do
			solid(
				base,
				"PataMetal",
				Vector3.new(0.4, 3.4, 0.4),
				CFrame.new(side * 6, 1.7, z),
				steel,
				metal
			)
		end
	end
	solid(base, "EstanteMetal", Vector3.new(12, 0.2, 4.4), CFrame.new(0, 1.2, 0), steel, metal)
	stuffed(
		base,
		"SangreMesa",
		Vector3.new(4.5, 0.03, 2.6),
		CFrame.new(-3, 3.66, 0.3),
		blood,
		nil,
		plastic
	)
	stuffed(
		base,
		"SangrePiso",
		Vector3.new(5, 0.05, 3),
		CFrame.new(-4.5, 0.03, 3),
		blood,
		nil,
		plastic
	)

	local top = base * CFrame.new(0, 3.68, 0)
	-- Bisturí.
	stuffed(
		top,
		"MangoBisturi",
		Vector3.new(0.14, 0.08, 1),
		CFrame.new(1.2, 0.04, -1.3),
		steel,
		nil,
		metal
	)
	stuffed(
		top,
		"HojaBisturi",
		Vector3.new(0.13, 0.04, 0.4),
		CFrame.new(1.2, 0.04, -2),
		Color3.fromRGB(215, 218, 224),
		nil,
		metal
	)
	-- Serrucho.
	stuffed(
		top,
		"Serrucho",
		Vector3.new(0.75, 0.05, 3.2),
		CFrame.new(3.2, 0.03, 0.2) * CFrame.Angles(0, math.rad(12), 0),
		steel,
		nil,
		metal
	)
	stuffed(top, "MangoSerrucho", Vector3.new(0.9, 0.3, 1), CFrame.new(3, 0.15, -1.8), dark)
	-- Cuchilla.
	stuffed(
		top,
		"Cuchilla",
		Vector3.new(1.3, 0.06, 1.6),
		CFrame.new(5, 0.03, -0.9),
		steel,
		nil,
		metal
	)
	stuffed(top, "MangoCuchilla", Vector3.new(0.28, 0.24, 1.2), CFrame.new(5, 0.12, 0.5), dark)
	stuffed(
		top,
		"SangreCuchilla",
		Vector3.new(0.9, 0.02, 0.7),
		CFrame.new(5, 0.07, -1.2),
		blood,
		nil,
		plastic
	)
	-- Pinza.
	for _, side in { -1, 1 } do
		stuffed(
			top,
			"Pinza",
			Vector3.new(0.1, 0.06, 1.5),
			CFrame.new(-0.4 + side * 0.08, 0.03, 1.3) * CFrame.Angles(0, math.rad(side * 6), 0),
			steel,
			nil,
			metal
		)
	end
	-- Martillo.
	stuffed(top, "MangoMartillo", Vector3.new(0.2, 0.16, 1.7), CFrame.new(0.8, 0.08, 1.2), dark)
	stuffed(
		top,
		"CabezaMartillo",
		Vector3.new(0.8, 0.3, 0.32),
		CFrame.new(0.8, 0.15, 0.3),
		steel,
		nil,
		metal
	)
	-- Gancho colgado en el costado.
	stuffed(base, "Gancho", Vector3.new(0.1, 1.2, 0.1), CFrame.new(-6.55, 3, 0), steel, nil, metal)
	stuffed(
		base,
		"PuntaGancho",
		Vector3.new(0.1, 0.1, 0.6),
		CFrame.new(-6.55, 2.45, -0.25),
		steel,
		nil,
		metal
	)
end

-- Sala del lobo, al fondo del sótano: acá se dejan los pergaminos en la estatua y está la puerta del
-- túnel de fuga. Devuelve el centro de la sala, a nivel del piso.
local function buildWolfRoom(east: Vector3): Vector3
	local height = CELLAR_WING_HEIGHT
	local start = east + Vector3.new(CELLAR_WING_LENGTH, 0, 0)
	local middle = start + Vector3.new(WOLF_ROOM_LENGTH / 2, 0, 0)
	local floorY, z = east.Y, east.Z
	local slab = Vector3.new(WOLF_ROOM_LENGTH + 0.5, 1, ROOM_SIZE)
	local stone = Color3.fromRGB(64, 60, 56)
	part({
		Name = "PisoSala",
		Size = slab,
		Position = middle + Vector3.new(0.25, -0.5, 0),
		Color = stone,
		Material = Enum.Material.Cobblestone,
	})
	part({
		Name = "TechoSala",
		Size = slab,
		Position = middle + Vector3.new(0.25, height + 0.5, 0),
		Color = CEILING_COLOR,
		Material = Enum.Material.Wood,
	})
	for _, side in { -1, 1 } do
		wall(middle + Vector3.new(0, 0, side * HALF), Vector3.xAxis, WOLF_ROOM_LENGTH + 1, height)
	end
	local doorX = start.X + WOLF_ROOM_LENGTH
	wall(
		Vector3.new(doorX, floorY, z),
		Vector3.zAxis,
		ROOM_SIZE,
		height,
		{ width = 12, bottom = 0, top = DOOR_HEIGHT }
	)

	-- Círculo ritual en el piso, alrededor de la estatua.
	local altarAt = Vector3.new(start.X + 14, floorY, z)
	for index, ring in { { 26, Color3.fromRGB(40, 36, 34) }, { 22.5, Color3.fromRGB(96, 22, 20) } } do
		decor({
			Name = "CirculoRitual",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.1, ring[1], ring[1]),
			CFrame = CFrame.new(altarAt + Vector3.new(0, 0.05 + index * 0.02, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = ring[2],
			Material = if index == 2 then Enum.Material.Neon else Enum.Material.Slate,
			Transparency = if index == 2 then 0.55 else 0,
		})
	end
	trophyLight(altarAt + Vector3.new(0, 10, 0))
	trophyLight(Vector3.new(doorX - 6, floorY + 8, z))

	-- Cajas contra las esquinas del fondo: detrás se puede esconder uno.
	for _, side in { -1, 1 } do
		local corner = Vector3.new(doorX - 6, floorY, z + side * (HALF - 7))
		solid(CFrame.new(corner), "Caja", Vector3.new(6, 6, 6), CFrame.new(0, 3, 0), WOOD_COLOR)
		solid(
			CFrame.new(corner + Vector3.new(-1, 0, side * 6.5)),
			"Caja",
			Vector3.new(5, 4.5, 5),
			CFrame.new(0, 2.25, 0),
			WOOD_COLOR
		)
		table.insert(refs.hidingSpots.room6, corner + Vector3.new(-5, 0.3, side * 5))
	end

	-- Túnel: recto bajo tierra y después una escalera de piedra que sube hasta el bosque.
	local rock = Color3.fromRGB(68, 64, 58)
	local flatEnd = doorX + TUNNEL_FLAT
	local flatMiddle = doorX + TUNNEL_FLAT / 2
	local wide = TUNNEL_WIDTH + 2
	part({
		Name = "PisoTunel",
		Size = Vector3.new(TUNNEL_FLAT, 1, wide),
		Position = Vector3.new(flatMiddle, floorY - 0.5, z),
		Color = stone,
		Material = Enum.Material.Cobblestone,
	})
	part({
		Name = "TechoTunel",
		Size = Vector3.new(TUNNEL_FLAT, 1, wide),
		Position = Vector3.new(flatMiddle, floorY + TUNNEL_HEIGHT + 0.5, z),
		Color = rock,
		Material = Enum.Material.Slate,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "ParedTunel",
			Size = Vector3.new(TUNNEL_FLAT, TUNNEL_HEIGHT, 1),
			Position = Vector3.new(
				flatMiddle,
				floorY + TUNNEL_HEIGHT / 2,
				z + side * (TUNNEL_WIDTH / 2 + 0.5)
			),
			Color = rock,
			Material = Enum.Material.Slate,
		})
	end
	-- Vigas de madera cada tanto y una luz tenue entre ellas.
	for beam = 1, 3 do
		local x = doorX + beam * 9
		decor({
			Name = "VigaTunel",
			Size = Vector3.new(1, 1, TUNNEL_WIDTH),
			Position = Vector3.new(x, floorY + TUNNEL_HEIGHT - 0.5, z),
			Color = WOOD_COLOR,
			Material = Enum.Material.Wood,
		})
		for _, side in { -1, 1 } do
			decor({
				Name = "PuntalTunel",
				Size = Vector3.new(1, TUNNEL_HEIGHT - 1, 1),
				Position = Vector3.new(
					x,
					floorY + (TUNNEL_HEIGHT - 1) / 2,
					z + side * (TUNNEL_WIDTH / 2 - 0.5)
				),
				Color = WOOD_COLOR,
				Material = Enum.Material.Wood,
			})
		end
	end
	trophyLight(Vector3.new(doorX + 14, floorY + 9, z))
	trophyLight(Vector3.new(doorX + 28, floorY + 9, z))

	for step = 1, TUNNEL_STEPS do
		local x = flatEnd + (step - 0.5) * TUNNEL_STEP_RUN
		part({
			Name = "Escalon",
			Size = Vector3.new(TUNNEL_STEP_RUN, step, wide),
			Position = Vector3.new(x, floorY + step / 2, z),
			Color = stone,
			Material = Enum.Material.Cobblestone,
		})
		-- Los primeros tramos van techados bajo tierra; más arriba la escalera queda a cielo abierto.
		local covered = step <= 7
		local wallTop = if covered then floorY + step + TUNNEL_HEIGHT else 3
		for _, side in { -1, 1 } do
			part({
				Name = "ParedEscalera",
				Size = Vector3.new(TUNNEL_STEP_RUN, wallTop - floorY, 1),
				Position = Vector3.new(
					x,
					(floorY + wallTop) / 2,
					z + side * (TUNNEL_WIDTH / 2 + 0.5)
				),
				Color = rock,
				Material = Enum.Material.Slate,
			})
		end
		if covered then
			part({
				Name = "TechoEscalera",
				Size = Vector3.new(TUNNEL_STEP_RUN, 1, wide),
				Position = Vector3.new(x, floorY + step + TUNNEL_HEIGHT + 0.5, z),
				Color = rock,
				Material = Enum.Material.Slate,
			})
		end
	end

	refs.doors.exit = buildDoor(
		"exit",
		Vector3.new(doorX, floorY, z),
		Vector3.zAxis,
		"Abrir salida",
		10,
		11,
		12,
		DOOR_HEIGHT
	)
	refs.doors.exit.prompt.ObjectText = "Puerta del túnel"
	-- Justo pasando la puerta: al cruzarla arranca la secuencia de fuga.
	refs.exitZone = decor({
		Name = "ZonaSalida",
		Size = Vector3.new(2, 11, TUNNEL_WIDTH),
		Position = Vector3.new(doorX + 2.5, floorY + 5.5, z),
		Transparency = 1,
	})
	refs.exitZone.CanTouch = true

	-- Farol de hierro al salir de la escalera: la luz con la que el jugador ve el bosque al escapar.
	local lampX = flatEnd + TUNNEL_STEPS * TUNNEL_STEP_RUN + 4
	local lampSide = z + TUNNEL_WIDTH / 2 + 3
	part({
		Name = "PosteFarolSalida",
		Size = Vector3.new(0.7, 11, 0.7),
		Position = Vector3.new(lampX, 5.5, lampSide),
		Color = Color3.fromRGB(18, 18, 20),
		Material = Enum.Material.Metal,
	})
	local lamp = decor({
		Name = "LuzFarolSalida",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.8,
		Position = Vector3.new(lampX, 11.6, lampSide),
		Color = Color3.fromRGB(255, 226, 170),
		Material = Enum.Material.Neon,
	})
	local lampLight = Instance.new("PointLight")
	lampLight.Color = Color3.fromRGB(255, 226, 170)
	lampLight.Range = 38
	lampLight.Brightness = 1.4
	lampLight.Shadows = true
	lampLight.Parent = lamp
	loopAt(lamp, Sounds.Wind, 0.6, 90)
	refs.tunnel = {
		door = Vector3.new(doorX, floorY, z),
		out = Vector3.xAxis,
		stairStart = Vector3.new(flatEnd, floorY, z),
		exit = Vector3.new(flatEnd + TUNNEL_STEPS * TUNNEL_STEP_RUN + 14, 0, z),
		floorY = floorY,
	}
	return altarAt
end

-- Decoración macabra del sótano de los carniceros: charcos de sangre, ganchos con carne colgada,
-- cadenas, pilas de huesos, calaveras en repisas, jaulas, manchas y chorreras en las paredes y luces
-- rojizas muy tenues. `origin` es el centro del piso; `halfX` y `halfZ` el medio ancho de la zona.
local function macabreCellar(
	origin: Vector3,
	halfX: number,
	halfZ: number,
	ceilingY: number,
	seed: number,
	wallsX: boolean
)
	local random = Random.new(seed)
	local blood = Color3.fromRGB(86, 8, 10)
	local function spot(margin: number): Vector3
		return origin
			+ Vector3.new(
				random:NextNumber(-halfX + margin, halfX - margin),
				0,
				random:NextNumber(-halfZ + margin, halfZ - margin)
			)
	end
	local function redLight(position: Vector3, range: number, brightness: number)
		local holder = decor({
			Name = "LuzRoja",
			Size = Vector3.one * 0.2,
			Position = position,
			Transparency = 1,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(210, 40, 28)
		light.Range = range
		light.Brightness = brightness
		light.Shadows = false
		light.Parent = holder
	end

	-- Charcos de sangre en el piso, algunos con un reguero que se arrastra.
	for _ = 1, 14 do
		local at = spot(4)
		local size = random:NextNumber(3, 8)
		decor({
			Name = "Charco",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, size, size * random:NextNumber(0.6, 1)),
			CFrame = CFrame.new(at + Vector3.new(0, 0.06, 0))
				* CFrame.Angles(0, random:NextNumber(0, 3), math.rad(90)),
			Color = blood,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.15,
		})
		if random:NextNumber() < 0.4 then
			decor({
				Name = "Reguero",
				Size = Vector3.new(random:NextNumber(5, 12), 0.05, 0.9),
				CFrame = CFrame.new(at + Vector3.new(0, 0.07, 0))
					* CFrame.Angles(0, random:NextNumber(0, 6), 0),
				Color = Color3.fromRGB(70, 6, 8),
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end

	-- Ganchos del techo con trozos de carne colgando de cadenas oxidadas.
	for _ = 1, 8 do
		local at = spot(5)
		local drop = random:NextNumber(4, 6.5)
		decor({
			Name = "Cadena",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(ceilingY - drop, 0.22, 0.22),
			CFrame = CFrame.new(at + Vector3.new(0, drop + (ceilingY - drop) / 2, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(58, 44, 36),
			Material = Enum.Material.Metal,
		})
		decor({
			Name = "Gancho",
			Size = Vector3.new(0.3, 1.1, 0.3),
			Position = at + Vector3.new(0.25, drop - 0.3, 0),
			Color = Color3.fromRGB(70, 52, 40),
			Material = Enum.Material.Metal,
		})
		local meat = decor({
			Name = "Carne",
			Size = Vector3.new(
				random:NextNumber(1.3, 2),
				random:NextNumber(2.6, 4),
				random:NextNumber(0.8, 1.2)
			),
			CFrame = CFrame.new(at + Vector3.new(0.2, drop - 2.4, 0))
				* CFrame.Angles(0, random:NextNumber(0, 6), math.rad(random:NextNumber(-6, 6))),
			Color = Color3.fromRGB(128, 30, 34),
			Material = Enum.Material.SmoothPlastic,
		})
		decor({
			Name = "Grasa",
			Size = Vector3.new(meat.Size.X * 0.9, meat.Size.Y * 0.18, meat.Size.Z + 0.06),
			CFrame = meat.CFrame * CFrame.new(0, meat.Size.Y * 0.3, 0),
			Color = Color3.fromRGB(214, 196, 170),
			Material = Enum.Material.SmoothPlastic,
		})
		-- Gotas que cayeron justo debajo.
		decor({
			Name = "Goteo",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, 1.6, 1.6),
			CFrame = CFrame.new(at + Vector3.new(0.2, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = blood,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.15,
		})
	end

	-- Pilas de huesos y calaveras tiradas.
	for _ = 1, 7 do
		local at = spot(3)
		for _ = 1, random:NextInteger(4, 7) do
			decor({
				Name = "Hueso",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(random:NextNumber(1.2, 2.4), 0.28, 0.28),
				CFrame = CFrame.new(
					at
						+ Vector3.new(
							random:NextNumber(-1.2, 1.2),
							random:NextNumber(0.2, 0.7),
							random:NextNumber(-1.2, 1.2)
						)
				) * CFrame.Angles(
					random:NextNumber(0, 3),
					random:NextNumber(0, 3),
					random:NextNumber(0, 3)
				),
				Color = Color3.fromRGB(206, 196, 172),
				Material = Enum.Material.Slate,
			})
		end
		local skull = CFrame.new(at + Vector3.new(0, 0.6, 0))
			* CFrame.Angles(0, random:NextNumber(0, 6), 0)
		decor({
			Name = "Craneo",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.2, 1.2),
			CFrame = skull,
			Color = Color3.fromRGB(214, 204, 180),
			Material = Enum.Material.Slate,
		})
		for _, side in { -0.25, 0.25 } do
			decor({
				Name = "Cuenca",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.3, 0.34, 0.2),
				CFrame = skull * CFrame.new(side, 0.12, -0.52),
				Color = Color3.fromRGB(14, 10, 8),
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end

	-- Manchas y chorreras de sangre en las paredes, con huellas de manos.
	for side = 1, 4 do
		local normal = ({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis })[side]
		local along = Vector3.new(-normal.Z, 0, normal.X)
		for _ = 1, if wallsX or normal.X == 0 then 4 else 0 do
			local wallAt = origin
				+ normal * (if normal.X ~= 0 then halfX else halfZ)
				+ along * random:NextNumber(-12, 12)
			local top = random:NextNumber(6, ceilingY - 2)
			local length = random:NextNumber(3, top)
			decor({
				Name = "Chorrera",
				Size = if normal.X ~= 0
					then Vector3.new(0.08, length, random:NextNumber(0.4, 1.2))
					else Vector3.new(random:NextNumber(0.4, 1.2), length, 0.08),
				Position = wallAt - normal * 0.62 + Vector3.new(0, top - length / 2, 0),
				Color = Color3.fromRGB(78, 8, 10),
				Material = Enum.Material.SmoothPlastic,
			})
		end
		decor({
			Name = "Mancha",
			Size = if normal.X ~= 0 then Vector3.new(0.08, 5, 7) else Vector3.new(7, 5, 0.08),
			Position = origin
				+ normal * (if normal.X ~= 0 then halfX else halfZ)
				- normal * 0.62
				+ along * random:NextNumber(-10, 10)
				+ Vector3.new(0, 7, 0),
			Color = Color3.fromRGB(62, 6, 8),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25,
		})
	end

	-- Jaulas de barrotes oxidados en dos rincones, con huesos adentro.
	for index = 1, 2 do
		local at = origin
			+ Vector3.new(
				(if index == 1 then -1 else 1) * (halfX - 6),
				0,
				(if index == 1 then 1 else -1) * (halfZ - 6)
			)
		for _, corner in
			{
				Vector3.new(-2.5, 0, -2.5),
				Vector3.new(2.5, 0, -2.5),
				Vector3.new(-2.5, 0, 2.5),
				Vector3.new(2.5, 0, 2.5),
			}
		do
			decor({
				Name = "BarrotCaja",
				Size = Vector3.new(0.25, 6, 0.25),
				Position = at + corner + Vector3.new(0, 3, 0),
				Color = Color3.fromRGB(50, 38, 32),
				Material = Enum.Material.Metal,
			})
		end
		for _, y in { 0.4, 3, 5.8 } do
			for _, side in { -2.5, 2.5 } do
				decor({
					Name = "AroJaula",
					Size = Vector3.new(5.2, 0.2, 0.2),
					Position = at + Vector3.new(0, y, side),
					Color = Color3.fromRGB(50, 38, 32),
					Material = Enum.Material.Metal,
				})
				decor({
					Name = "AroJaula",
					Size = Vector3.new(0.2, 0.2, 5.2),
					Position = at + Vector3.new(side, y, 0),
					Color = Color3.fromRGB(50, 38, 32),
					Material = Enum.Material.Metal,
				})
			end
		end
		decor({
			Name = "HuesosJaula",
			Size = Vector3.new(3, 0.5, 2),
			Position = at + Vector3.new(0, 0.3, 0),
			Color = Color3.fromRGB(196, 186, 160),
			Material = Enum.Material.Slate,
		})
	end

	-- Luces rojizas muy tenues, para que lo rojo se adivine en la oscuridad.
	for _ = 1, 4 do
		redLight(spot(8) + Vector3.new(0, 7, 0), 20, 0.5)
	end
end

-- Alarga room6 hacia el este sin ensancharla: la pared este queda abierta y sigue un tramo igual.
local function buildCellarWing(): Vector3
	local east = cellCenter("room6") + Vector3.new(HALF, 0, 0)
	local middle = east + Vector3.new(CELLAR_WING_LENGTH / 2, 0, 0)
	local height = CELLAR_WING_HEIGHT
	local slab = Vector3.new(CELLAR_WING_LENGTH + 0.5, 1, ROOM_SIZE)
	local slabMiddle = middle + Vector3.new(0.25, 0, 0)
	part({
		Name = "PisoSotano",
		Size = slab,
		Position = slabMiddle - Vector3.new(0, 0.5, 0),
		Color = FLOOR_COLOR,
		Material = Enum.Material.WoodPlanks,
	})
	part({
		Name = "TechoSotano",
		Size = slab,
		Position = slabMiddle + Vector3.new(0, height + 0.5, 0),
		Color = CEILING_COLOR,
		Material = Enum.Material.Wood,
	})
	for _, side in { -1, 1 } do
		wall(middle + Vector3.new(0, 0, side * HALF), Vector3.xAxis, CELLAR_WING_LENGTH + 1, height)
		decor({
			Name = "Moldura",
			Size = Vector3.new(CELLAR_WING_LENGTH, 1.2, 0.5),
			Position = middle + Vector3.new(0, 0.6, side * (HALF - 0.6)),
			Color = Color3.fromRGB(70, 66, 60),
			Material = Enum.Material.Wood,
		})
	end
	-- Al fondo, un arco de paso a la sala del lobo.
	wall(
		middle + Vector3.new(CELLAR_WING_LENGTH / 2, 0, 0),
		Vector3.zAxis,
		ROOM_SIZE,
		height,
		{ width = 14, bottom = 0, top = DOOR_HEIGHT }
	)
	local altarAt = buildWolfRoom(east)

	for _, spot in
		{
			Vector3.new(-16, 7.5, -HALF + 1),
			Vector3.new(16, 7.5, HALF - 1),
			Vector3.new(CELLAR_WING_LENGTH / 2 - 1, 7.5, 0),
		}
	do
		candle(middle + spot, CANDLE_LIGHT)
	end

	-- Luz tenue sobre la mesa y sobre los colgados: el resto queda en penumbra.
	trophyLight(middle + Vector3.new(14, 9, 0))
	trophyLight(middle + Vector3.new(-13, 9, 4))
	trophyLight(middle + Vector3.new(-3, 9, -9))

	local pale = Color3.fromRGB(176, 170, 156)
	local grey = Color3.fromRGB(150, 150, 138)
	hangingCorpse(middle + Vector3.new(-13, 0, 11), height, pale)
	hangingCorpse(middle + Vector3.new(-3, 0, -12), height, grey)
	lyingCorpse(
		CFrame.new(middle + Vector3.new(-16, 0, -17)) * CFrame.Angles(0, math.rad(35), 0),
		pale
	)
	lyingCorpse(
		CFrame.new(middle + Vector3.new(12, 0, 18)) * CFrame.Angles(0, math.rad(100), 0),
		grey
	)
	lyingCorpse(
		CFrame.new(middle + Vector3.new(19, 0, -17)) * CFrame.Angles(0, math.rad(200), 0),
		pale
	)

	local tableBase = CFrame.new(middle + Vector3.new(14, 0, 0))
	butcherTable(tableBase)
	local spots = refs.hidingSpots.room6
	table.insert(spots, (tableBase * CFrame.new(-3, 1.6, 0)).Position)
	table.insert(spots, (tableBase * CFrame.new(-1.5, 4, 1)).Position)
	table.insert(spots, middle + Vector3.new(23, 0.3, 22))

	macabreCellar(middle, 26, 33, height, 11, false)
	macabreCellar(cellCenter("room6"), 32, 32, CEILING, 12, true)

	-- Cajas y barriles repartidos por todo el tramo: refugio para esconderse del carnicero, que se
	-- pierde de vista detrás de ellos.
	for _, cover in
		{
			{ "crates", Vector3.new(-22, 0, 22) },
			{ "barrels", Vector3.new(-6, 0, 25) },
			{ "crates", Vector3.new(6, 0, -25) },
			{ "barrels", Vector3.new(-24, 0, -4) },
			{ "barrels", Vector3.new(24, 0, 27) },
			{ "crates", Vector3.new(-9, 0, 3) },
			{ "crates", Vector3.new(24, 0, -26) },
		}
	do
		local at = middle + cover[2]
		for _, spot in FURNITURE[cover[1]](CFrame.lookAt(at, middle)) do
			table.insert(spots, spot)
		end
	end

	-- La pieza ahora abarca los tres tramos (sótano, tramo largo y sala del lobo), y el asesino la
	-- recorre por el medio.
	local room = refs.rooms.room6
	local whole = cellCenter("room6")
		+ Vector3.new((CELLAR_WING_LENGTH + WOLF_ROOM_LENGTH) / 2, 0, 0)
	room.size =
		Vector3.new(ROOM_SIZE + CELLAR_WING_LENGTH + WOLF_ROOM_LENGTH, LEVEL_HEIGHT, ROOM_SIZE)
	room.box = whole
	room.center = whole
	return altarAt
end

local function buildExterior()
	-- Terreno en cuatro franjas: no tapa el agujero de la escalera del sótano.
	local x0, x1, z0, z1 = -HALF - 2, cellCenter("room2").X + HALF + 2, -HALF - 2, PITCH + HALF + 2
	local far = 500
	local terrain = workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(58, 104, 46))
	local function ground(xa: number, xb: number, za: number, zb: number)
		terrain:FillBlock(
			CFrame.new((xa + xb) / 2, -2, (za + zb) / 2),
			Vector3.new(xb - xa, 4, zb - za),
			Enum.Material.Grass
		)
	end
	-- El hall sobresale al noroeste; las dos esquinas libres también llevan pasto.
	local hallX0, hallZ0 = GrandHall.X0 - 2, GrandHall.Z0 - 2
	-- Debajo del patio delantero no hay pasto: lo taparía su piso de piedra.
	local yardX0, yardX1 = Courtyard.X0 - 2, Courtyard.X1 + 2
	ground(-far, yardX0, -far, hallZ0)
	ground(yardX1, far, -far, hallZ0)
	ground(yardX0, yardX1, -far, Courtyard.Z1 - 6)
	ground(-far, far, z1, far)
	-- El ala oeste tiene piso propio: el pasto la rodea.
	local wingX0 = cellCenter("gameRoom").X - HALF - 2
	local wingZ = HALF + 2
	ground(-far, wingX0, hallZ0, z1)
	ground(wingX0, hallX0, hallZ0, -wingZ)
	ground(wingX0, hallX0, wingZ, z1)
	ground(x1, far, hallZ0, z1)
	ground(GrandHall.X1 + 2, x1, hallZ0, z0)
	ground(hallX0, x0, GrandHall.Z1 + 2, z1)

	-- Bosque: se ven solo árboles hasta perderse en la niebla.
	local random = Random.new(7)
	local midX, midZ = (x0 + x1) / 2, (z0 + z1) / 2
	-- Árboles de bosque tenebroso, de tres clases: abetos (tronco recto y pisos de ramas caídas que se
	-- achican hacia arriba), árboles muertos (retorcidos, pelados, con ramas y ramitas torcidas) y
	-- robles viejos (tronco grueso y copa rala y desprolija). Los cercanos llevan más detalle; los
	-- lejanos, lo justo para que se vea la silueta entre la niebla.
	local function plantTree(x: number, z: number, near: boolean?)
		local height = random:NextNumber(34, 70)
		local turn = random:NextNumber(0, math.pi * 2)
		local lean = math.rad(random:NextNumber(-4, 4))
		local bark = Color3.fromRGB(44, 34, 28)
			:Lerp(Color3.fromRGB(78, 66, 56), random:NextNumber(0, 0.7))
		local frame = CFrame.new(x, 0, z) * CFrame.Angles(0, turn, 0) * CFrame.Angles(lean, 0, 0)
		local function wood(size: Vector3, offset: CFrame, shape: Enum.PartType?)
			decor({
				Name = "Tronco",
				Shape = shape or Enum.PartType.Block,
				Size = size,
				CFrame = frame * offset,
				Color = bark,
				Material = Enum.Material.Wood,
			})
		end
		-- Una rama: cilindro que sale del tronco a `height` con ese rumbo, elevación y largo.
		local function limb(at: number, yaw: number, rise: number, length: number, thick: number)
			wood(
				Vector3.new(length, thick, thick),
				CFrame.new(0, at, 0)
					* CFrame.Angles(0, yaw, 0)
					* CFrame.Angles(0, 0, math.rad(rise))
					* CFrame.new(length / 2, 0, 0),
				Enum.PartType.Cylinder
			)
		end
		local function frond(at: number, yaw: number, length: number, tone: number)
			decor({
				Name = "Fronda",
				Size = Vector3.new(length, 0.3, length * 0.32),
				CFrame = frame * CFrame.new(0, at, 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(
					0,
					0,
					math.rad(-24)
				) * CFrame.new(length / 2, 0, 0),
				Color = Color3.fromRGB(
					math.round(14 + tone * 16),
					math.round(34 + tone * 26),
					math.round(26 + tone * 14)
				),
				Material = Enum.Material.Grass,
			})
		end
		local trunk = height * 0.045
		local kind = random:NextNumber()
		-- Tronco: dos tramos y raíces que se abren sobre el suelo.
		wood(
			Vector3.new(height * 0.55, trunk, trunk),
			CFrame.new(0, height * 0.275, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.PartType.Cylinder
		)
		wood(
			Vector3.new(height * 0.5, trunk * 0.62, trunk * 0.62),
			CFrame.new(0, height * 0.78, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.PartType.Cylinder
		)
		if near then
			for root = 1, 4 do
				limb(trunk * 0.4, root * 1.57 + turn, -35, trunk * 2.6, trunk * 0.5)
			end
		end
		-- Hojas: tarjetas chicas y finas, con distintos verdes y giros, apiñadas alrededor de un punto
		-- para que la copa se vea llena y de hojas, no una bola lisa.
		local function leaves(at: CFrame, spread: number, count: number)
			for _ = 1, count do
				local offset = Vector3.new(
					random:NextNumber(-spread, spread),
					random:NextNumber(-spread * 0.6, spread * 0.6),
					random:NextNumber(-spread, spread)
				)
				local tone = random:NextNumber()
				decor({
					Name = "Hojas",
					Size = Vector3.new(random:NextNumber(3, 5), 0.12, random:NextNumber(2, 3.4)),
					CFrame = frame * at * CFrame.new(offset) * CFrame.Angles(
						random:NextNumber(-0.9, 0.9),
						random:NextNumber(0, math.pi * 2),
						random:NextNumber(-0.9, 0.9)
					),
					Color = Color3.fromRGB(
						math.round(26 + tone * 30),
						math.round(62 + tone * 50),
						math.round(30 + tone * 20)
					),
					Material = Enum.Material.Grass,
				})
			end
		end
		if kind < 0.4 then
			-- Abeto: pisos de ramas caídas, cada vez más cortas, bien cargadas de agujas.
			local levels = if near then 12 else 5
			for level = 1, levels do
				local at = height * (0.2 + 0.78 * level / levels)
				local reach = height * 0.26 * (1.05 - level / (levels + 1))
				for spoke = 1, if near then 4 else 2 do
					frond(at, spoke * (6.28 / 4) + level * 0.9, reach, random:NextNumber(0, 1))
				end
			end
		else
			-- Árbol de hoja ancha: ramas gruesas que se abren, y en cada punta un racimo de hojas; otro,
			-- más grande, arriba de todo. Ninguno queda pelado.
			local branches = if near then 7 else 4
			for branch = 1, branches do
				local yaw = branch * (6.28 / branches) + random:NextNumber(-0.3, 0.3)
				local at = height * random:NextNumber(0.5, 0.85)
				local rise = random:NextNumber(25, 55)
				local length = height * random:NextNumber(0.2, 0.3)
				limb(at, yaw, rise, length, trunk * 0.4)
				local tip = CFrame.new(0, at, 0)
					* CFrame.Angles(0, yaw, 0)
					* CFrame.new(
						length * math.cos(math.rad(rise)),
						length * math.sin(math.rad(rise)),
						0
					)
				leaves(tip, height * 0.13, if near then 14 else 6)
			end
			leaves(CFrame.new(0, height * 0.97, 0), height * 0.17, if near then 22 else 9)
		end
	end
	local planted = 0
	while planted < 300 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local radius = random:NextNumber(70, 420)
		local x, z = midX + math.cos(angle) * radius, midZ + math.sin(angle) * radius
		local onWing = x > wingX0 - 14 and x < hallX0 and z > -wingZ - 14 and z < wingZ + 14
		local onCourtyard = x > Courtyard.X0 - 10
			and x < Courtyard.X1 + 10
			and z > Courtyard.Z1 - 12
			and z < Courtyard.Z0
		-- Solo el camino de la salida del túnel queda despejado; a los costados el bosque se cierra.
		local onTunnel = x > refs.tunnel.stairStart.X - 6
			and x < refs.tunnel.exit.X + 140
			and math.abs(z - refs.tunnel.exit.Z) < 10
		if
			(x < hallX0 - 14 or x > x1 + 14 or z < hallZ0 - 14 or z > z1 + 14)
			and not onWing
			and not onCourtyard
			and not onTunnel
		then
			planted += 1
			plantTree(x, z, radius < 240)
		end
	end

	-- A los costados del camino de salida el bosque es una pared de troncos: se ve eterno en la niebla.
	local tunnel = refs.tunnel
	for step = 0, 40 do
		for _, side in { -1, 1 } do
			for _ = 1, 2 do
				local x = tunnel.exit.X - 18 + step * 5 + random:NextNumber(-3, 3)
				local z = tunnel.exit.Z + side * random:NextNumber(11, 40)
				plantTree(x, z, true)
			end
		end
	end
end

-- Abre en el pasto el hueco de la escalera del túnel, para que suba hasta la superficie.
local function carveTunnel()
	local tunnel = refs.tunnel
	local length = TUNNEL_STEPS * TUNNEL_STEP_RUN + 2
	workspace.Terrain:FillBlock(
		CFrame.new(tunnel.stairStart.X + length / 2 - 1, -2.5, tunnel.stairStart.Z),
		Vector3.new(length, 7, TUNNEL_WIDTH + 4),
		Enum.Material.Air
	)
	-- Camino de tierra que sigue desde la escalera, entre la niebla, hasta donde alcanza la vista.
	-- Sin pasto debajo: el terreno se abre y el camino (de piedra) ocupa su lugar a ras del suelo.
	workspace.Terrain:FillBlock(
		CFrame.new(tunnel.exit.X - 10 + 65, -2.5, tunnel.exit.Z),
		Vector3.new(130, 7, 13),
		Enum.Material.Air
	)
	part({
		Name = "Camino",
		Size = Vector3.new(130, 4, 9),
		Position = Vector3.new(tunnel.exit.X - 10 + 65, -2, tunnel.exit.Z),
		Color = Color3.fromRGB(84, 74, 60),
		Material = Enum.Material.Pebble,
	})
	for step = 0, 6 do
		for _, side in { -1, 1 } do
			decor({
				Name = "FarolCamino",
				Size = Vector3.new(0.5, 7, 0.5),
				Position = Vector3.new(
					tunnel.exit.X + 10 + step * 18,
					3.5,
					tunnel.exit.Z + side * 6
				),
				Color = Color3.fromRGB(26, 24, 22),
				Material = Enum.Material.Wood,
			})
		end
	end
end

-- Lluvia densa justo del otro lado de cada ventanal.
local function rainOutside(window: any)
	local top = window.height / 2 + 14
	-- Cae de costado: inclinada a lo largo del ventanal, así nunca entra a la casa.
	local tilt = CFrame.fromAxisAngle(window.outward, math.rad(RAIN_SLANT_DEGREES))
	local fall = tilt:VectorToWorldSpace(-Vector3.yAxis)
	local cloud = decor({
		Name = "Lluvia",
		Size = if window.horizontal
			then Vector3.new(window.width + 26, 1, window.depth or 10)
			else Vector3.new(window.depth or 10, 1, window.width + 26),
		CFrame = CFrame.new(window.position + window.outward * 7 - fall * top) * tilt,
		Transparency = 1,
	})
	local rain = Instance.new("ParticleEmitter")
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Speed = NumberRange.new(120, 145)
	-- Tiempo justo para llegar del techo hasta el piso, sin atravesarlo.
	rain.Lifetime = NumberRange.new((top + window.height / 2) / 130)
	rain.Rate = 1800
	rain.Size = NumberSequence.new(0.55)
	-- Negativo: alarga la gota en el sentido en que cae.
	rain.Squash = NumberSequence.new(-3)
	rain.Color = ColorSequence.new(Color3.fromRGB(215, 228, 245))
	rain.Transparency = NumberSequence.new(0.1)
	rain.LightInfluence = 0
	rain.LightEmission = 0.6
	rain.Brightness = 3
	rain.Parent = cloud
	-- Roblox limita cada emisor: varias copias dan una lluvia bien tupida.
	for _ = 1, 3 do
		rain:Clone().Parent = cloud
	end
end

-- Calcula las aberturas de cada pieza y guarda dónde van los ventanales.
local function planOpenings(): ({ [string]: { [string]: Opening } }, { any })
	local openings: { [string]: { [string]: Opening } } = {}
	for id in PLAN do
		openings[id] = {}
	end
	local doorHole = { width = CORRIDOR_WIDTH, bottom = 0, top = CORRIDOR_HEIGHT }
	for _, link in LINKS do
		local dir = (cellCenter(link[2]) - cellCenter(link[1])).Unit
		openings[link[1]][sideOf(dir)] = doorHole
		openings[link[2]][sideOf(-dir)] = doorHole
	end
	for _, refuge in REFUGES do
		openings[refuge.room][sideOf(refuge.dir)] = doorHole
	end
	openings.room6.E = { width = ROOM_SIZE - 2, bottom = 0, top = CELLAR_WING_HEIGHT }
	local occupied: { [string]: boolean } = { [`0,1,{GROUND_Y}`] = true }
	for _, plan in PLAN do
		occupied[`{plan.col},{plan.row},{plan.y}`] = true
	end
	local windows = {}
	for id, plan in PLAN do
		if plan.y ~= CELLAR_Y and not GRAND_ROOMS[id] then
			local big = plan.y ~= ATTIC_Y
			local hole = if big
				then { width = 34, bottom = 2.5, top = 16 }
				else { width = 10, bottom = 6, top = 12 }
			for side, delta in { E = { 1, 0 }, W = { -1, 0 }, S = { 0, 1 }, N = { 0, -1 } } do
				local outside = not occupied[`{plan.col + delta[1]},{plan.row + delta[2]},{plan.y}`]
				local blockedByStairs = STAIR_ROOMS[id] and side == "W"
				if outside and not openings[id][side] and not blockedByStairs then
					openings[id][side] = hole
					table.insert(windows, {
						position = cellCenter(id)
							+ Vector3.new(delta[1], 0, delta[2]) * HALF
							+ Vector3.new(0, (hole.bottom + hole.top) / 2, 0),
						width = hole.width,
						height = hole.top - hole.bottom,
						horizontal = delta[2] ~= 0,
						outward = Vector3.new(delta[1], 0, delta[2]),
					})
				end
			end
		end
	end
	return openings, windows
end

-- Mueble con cajón y estatua de lobo, donde se dejan los pergaminos.
local function buildAltar(altarAt: Vector3, hall: Vector3)
	-- En la sala del lobo, mirando hacia la entrada de la sala (el oeste).
	local base = CFrame.lookAt(altarAt, altarAt + Vector3.new(-1, 0, 0))
	-- La mesita de la linterna sigue en el centro del hall, entre los dos tramos de la escalera.
	local midX = GrandHall.CenterX
	local lanternBase =
		CFrame.lookAt(hall + Vector3.new(midX, 0, -18), hall + Vector3.new(midX, 0, -60))
	local cabinet =
		solid(base, "Mueble", Vector3.new(11, 4.5, 4), CFrame.new(0, 2.25, 0), WOOD_COLOR)
	local closedDrawer = base * CFrame.new(0, 2.4, -2.05)
	local drawer = solid(
		CFrame.identity,
		"Cajon",
		Vector3.new(7, 1.8, 3.8),
		closedDrawer * CFrame.new(0, 0, 1.8),
		Color3.fromRGB(72, 46, 28)
	)
	drawer.CanCollide = false
	solid(
		closedDrawer,
		"Manija",
		Vector3.new(1.4, 0.3, 0.3),
		CFrame.new(0, 0, -0.2),
		GOLD_COLOR,
		Enum.Material.Metal
	)

	local stone = Color3.fromRGB(112, 112, 122)
	local top = base * CFrame.new(0, 4.5, 0)
	local function wolf(name: string, size: Vector3, offset: CFrame)
		solid(top, name, size, offset, stone, Enum.Material.Slate)
	end
	wolf("Lomo", Vector3.new(2.2, 2.2, 5), CFrame.new(0, 2.6, 0.4))
	wolf(
		"Pecho",
		Vector3.new(2.5, 2.8, 2),
		CFrame.new(0, 3, -2) * CFrame.Angles(math.rad(-15), 0, 0)
	)
	wolf("Cabeza", Vector3.new(2.2, 2, 2.2), CFrame.new(0, 5, -2.8))
	wolf("Hocico", Vector3.new(1.1, 0.9, 1.6), CFrame.new(0, 4.6, -4.4))
	wolf("OrejaIzquierda", Vector3.new(0.6, 1.2, 0.5), CFrame.new(-0.7, 6.4, -2.6))
	wolf("OrejaDerecha", Vector3.new(0.6, 1.2, 0.5), CFrame.new(0.7, 6.4, -2.6))
	wolf(
		"Cola",
		Vector3.new(0.7, 0.7, 3),
		CFrame.new(0, 3, 3.4) * CFrame.Angles(math.rad(-25), 0, 0)
	)
	for _, x in { -0.8, 0.8 } do
		for _, z in { -2, 2.4 } do
			wolf("Pata", Vector3.new(0.7, 1.8, 0.7), CFrame.new(x, 0.9, z))
		end
	end
	candle((base * CFrame.new(-4.5, 5.1, -0.8)).Position, CANDLE_LIGHT)
	candle((base * CFrame.new(4.5, 5.1, -0.8)).Position, CANDLE_LIGHT)

	-- Mesita al costado del mueble, donde está la linterna al empezar.
	local side = lanternBase * CFrame.new(10, 0, 0)
	solid(side, "MesaLinterna", Vector3.new(5, 0.5, 4), CFrame.new(0, 3.2, 0), WOOD_COLOR)
	solid(side, "PataMesa", Vector3.new(0.8, 3, 0.8), CFrame.new(0, 1.5, 0), WOOD_COLOR)
	solid(side, "BaseMesa", Vector3.new(3, 0.4, 3), CFrame.new(0, 0.2, 0), WOOD_COLOR)
	refs.flashlightSpot = (side * CFrame.new(0, 3.75, 0)).Position
	candle((side * CFrame.new(1.8, 4, 1)).Position, CANDLE_LIGHT)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Dejar pergaminos"
	prompt.ObjectText = "Estatua de lobo"
	prompt.MaxActivationDistance = Config.InteractRange + 4
	prompt.RequiresLineOfSight = false
	-- En el mueble quedaría abajo de la vista si se mira de frente desde cerca.
	local statuePoint = decor({
		Name = "PuntoEstatua",
		Size = Vector3.one,
		Position = (base * CFrame.new(0, 5.5, -3)).Position,
		Transparency = 1,
	})
	prompt.Parent = statuePoint
	-- Goteo lejano en la sala, para que no sea un silencio total.
	loopAt(statuePoint, Sounds.Drip, 0.7, 70)
	refs.altar = {
		prompt = prompt,
		drawer = drawer,
		closedCFrame = drawer.CFrame,
		openCFrame = drawer.CFrame * CFrame.new(0, 0, -2.6),
		position = cabinet.Position,
		keySpot = (closedDrawer * CFrame.new(0, 1, -1)).Position,
	}
end

-- Cajas fuertes con código: una en la pared de cada una de estas piezas, a la altura de los ojos. Son
-- de acero gris martillado, con la puerta embutida, dos bisagras a la derecha, el dial negro de combinación
-- y una manija negra a la izquierda. Al abrirse deja ver el pergamino que guarda adentro. Se arma como una
-- puerta más (hojas, bloqueo y botón) para que abra y cierre con el mismo código del resto.
local vaultFolder: Folder? = nil

-- Ponen o vuelven a poner las cajas fuertes: después de sortear los muebles de la partida, cada una busca en
-- las paredes de su pieza un lugar donde no choque con nada (muebles, consolas, bancos).
local function placeVaults()
	if vaultFolder then
		vaultFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "CajasFuertes"
	folder.Parent = world
	vaultFolder = folder
	buildParent = folder
	refs.vaults = {}
	local sides =
		{ Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0) }
	local pickRandom = Random.new()
	for n, id in Config.VaultRooms do
		local center = cellCenter(id)
		-- Todos los lugares posibles: cuatro paredes por seis posiciones, lejos del centro de la pared
		-- (que es donde van las puertas y ventanales), probados en orden al azar.
		local candidates = {}
		for _, side in sides do
			for _, offset in { 24, -24, 20, -20, 29, -29 } do
				table.insert(candidates, { inward = side, offset = offset })
			end
		end
		for index = #candidates, 2, -1 do
			local swap = pickRandom:NextInteger(1, index)
			candidates[index], candidates[swap] = candidates[swap], candidates[index]
		end
		local chosen = candidates[1]
		local params = OverlapParams.new()
		for _, candidate in candidates do
			local along = Vector3.new(-candidate.inward.Z, 0, candidate.inward.X)
			local at = center
				+ candidate.inward * (HALF - 0.5)
				+ along * candidate.offset
				+ Vector3.new(0, 6.5, 0)
			local spot = CFrame.lookAt(at, at - candidate.inward) * CFrame.new(0, 0, -1.9)
			-- La caja y un poco de aire delante (para llegar a ella). Lo decorativo no cuenta: no tiene
			-- física ni consultas.
			local clash = workspace:GetPartBoundsInBox(spot, Vector3.new(7.6, 6.8, 3.4), params)
			local reach = workspace:GetPartBoundsInBox(
				spot * CFrame.new(0, -3, -3),
				Vector3.new(7, 5, 3),
				params
			)
			if #clash == 0 and #reach == 0 then
				chosen = candidate
				break
			end
		end
		local inward = chosen.inward
		local along = Vector3.new(-inward.Z, 0, inward.X)
		local wallPoint = center
			+ inward * (HALF - 0.5)
			+ along * chosen.offset
			+ Vector3.new(0, 6.5, 0)
		local frame = CFrame.lookAt(wallPoint, wallPoint - inward)
		local hammered = Color3.fromRGB(150, 140, 136)
		local black = Color3.fromRGB(18, 18, 20)
		local width, high, deep = 6.6, 6, 3.2
		local function steelPlate(size: Vector3, offset: CFrame): Part
			return part({
				Name = "CajaFuerte",
				Size = size,
				CFrame = frame * offset,
				Color = hammered,
				-- Slate da el grano áspero del acero martillado.
				Material = Enum.Material.Slate,
			})
		end
		-- Cuerpo hueco: fondo, dos laterales, techo y piso; el frente es un marco con la puerta embutida.
		steelPlate(Vector3.new(width, high, 0.3), CFrame.new(0, 0, -0.15))
		steelPlate(Vector3.new(0.6, high, deep), CFrame.new(-(width - 0.6) / 2, 0, -deep / 2))
		steelPlate(Vector3.new(0.6, high, deep), CFrame.new((width - 0.6) / 2, 0, -deep / 2))
		steelPlate(Vector3.new(width, 0.6, deep), CFrame.new(0, (high - 0.6) / 2, -deep / 2))
		local floor =
			steelPlate(Vector3.new(width, 0.6, deep), CFrame.new(0, -(high - 0.6) / 2, -deep / 2))
		-- Marco del frente (más ancho que la caja, como el borde que rodea la puerta).
		steelPlate(Vector3.new(width, 0.5, 0.5), CFrame.new(0, (high - 0.5) / 2, -deep + 0.1))
		steelPlate(Vector3.new(width, 0.5, 0.5), CFrame.new(0, -(high - 0.5) / 2, -deep + 0.1))
		steelPlate(Vector3.new(0.5, high, 0.5), CFrame.new(-(width - 0.5) / 2, 0, -deep + 0.1))
		steelPlate(Vector3.new(0.5, high, 0.5), CFrame.new((width - 0.5) / 2, 0, -deep + 0.1))
		-- Hoja de la puerta: embutida en el marco, bisagra a la derecha, abre hacia afuera.
		local doorZ = -deep + 0.2
		local closed = frame * CFrame.new(0, 0, doorZ)
		local hingeEdge = (width - 1) / 2
		local hinge = frame * CFrame.new(hingeEdge, 0, doorZ)
		local open = hinge * CFrame.Angles(0, math.rad(-105), 0) * hinge:Inverse() * closed
		local leaf = part({
			Name = "PuertaCajaFuerte",
			Size = Vector3.new(width - 1, high - 1, 0.5),
			CFrame = closed,
			Color = hammered,
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
		local function onLeaf(
			size: Vector3,
			offset: CFrame,
			color: Color3,
			material: Enum.Material?,
			shape: Enum.PartType?
		): Part
			local piece = part({
				Name = "DetalleCajaFuerte",
				Shape = shape or Enum.PartType.Block,
				Size = size,
				CFrame = closed * offset,
				Color = color,
				Material = material or Enum.Material.Metal,
				CanCollide = false,
				CanQuery = false,
			})
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = leaf
			weld.Part1 = piece
			weld.Parent = leaf
			return piece
		end
		local faceForward = CFrame.Angles(0, math.rad(90), 0)
		-- Dial negro de combinación a la derecha: aro, disco con números (marquitas) y perilla central.
		local dialAt = CFrame.new(1.3, 0.5, -0.3)
		onLeaf(
			Vector3.new(0.25, 1.9, 1.9),
			dialAt * faceForward,
			black,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		onLeaf(
			Vector3.new(0.3, 1.5, 1.5),
			dialAt * CFrame.new(0, 0, -0.08) * faceForward,
			Color3.fromRGB(36, 36, 38),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		for tick = 0, 19 do
			local angle = tick / 20 * math.pi * 2
			onLeaf(
				Vector3.new(0.09, 0.2, 0.06),
				dialAt
					* CFrame.new(math.cos(angle) * 0.68, math.sin(angle) * 0.68, -0.22)
					* CFrame.Angles(0, 0, angle - math.pi / 2),
				Color3.fromRGB(226, 214, 170),
				Enum.Material.SmoothPlastic
			)
		end
		onLeaf(
			Vector3.new(0.45, 0.95, 0.95),
			dialAt * CFrame.new(0, 0, -0.18) * faceForward,
			black,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		-- Manija negra a la izquierda: base redonda y barra vertical.
		local handleAt = CFrame.new(-1.7, 0.7, -0.3)
		onLeaf(
			Vector3.new(0.6, 0.9, 0.9),
			handleAt * faceForward,
			black,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		onLeaf(
			Vector3.new(2.6, 0.38, 0.38),
			handleAt * CFrame.new(0, -1.1, -0.45) * CFrame.Angles(0, 0, math.rad(90)),
			black,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		-- Dos bisagras de acero sobre el borde derecho, sobresaliendo del marco.
		for _, y in { 1.9, -1.9 } do
			local pin = part({
				Name = "BisagraCajaFuerte",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.4, 0.45, 0.45),
				CFrame = frame
					* CFrame.new(width / 2 - 0.1, y, doorZ)
					* CFrame.Angles(0, 0, math.rad(90)),
				Color = hammered,
				Material = Enum.Material.Metal,
			})
			pin.CanCollide = false
			steelPlate(Vector3.new(0.9, 1.1, 0.25), CFrame.new(width / 2 - 0.45, y, doorZ - 0.2))
		end
		-- Bloqueo chiquito oculto adentro (no estorba el paso) que lleva el botón.
		local blocker = part({
			Name = "BloqueoCajaFuerte",
			Size = Vector3.new(1, 1, 1),
			CFrame = frame * CFrame.new(0, 0, -deep / 2),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ingresar código"
		prompt.ObjectText = `Caja fuerte {n}`
		prompt.MaxActivationDistance = Config.InteractRange
		prompt.RequiresLineOfSight = false
		prompt.Parent = blocker
		local vaultDoor: Door = {
			leaves = { { part = leaf, closed = closed, open = open } },
			blocker = blocker,
			position = closed.Position,
			twin = nil,
			unlocked = false,
			swung = false,
			prompt = prompt,
			normal = Vector3.zAxis,
			metal = true,
		}
		-- Rótulo sobre la caja.
		local sign = part({
			Name = "CartelCajaFuerte",
			Size = Vector3.new(5, 1, 0.2),
			CFrame = frame * CFrame.new(0, 4, -0.1),
			Color = WOOD_COLOR,
			Material = Enum.Material.Wood,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(226, 196, 120)
		label.Text = `CAJA FUERTE {n}`
		label.Parent = gui

		refs.doors[`vault{n}`] = vaultDoor
		refs.vaults[n] = {
			room = id,
			scrollSpot = (floor.CFrame * CFrame.new(0, 0.7, 0)).Position,
			door = vaultDoor,
		}
	end
	buildParent = nil
end

function Mansion.placeVaults()
	placeVaults()
end

function Mansion.setDrawerOpen(open: boolean)
	local altar = refs.altar
	if open and altar.prompt.Enabled then
		playAt(altar.drawer, Sounds.Drawer, 1.2)
	end
	TweenService:Create(altar.drawer, TweenInfo.new(0.6), {
		CFrame = if open then altar.openCFrame else altar.closedCFrame,
	}):Play()
	altar.prompt.Enabled = not open
end

function Mansion.build(): MansionRefs
	setupCollisionGroups()
	world = Instance.new("Model")
	world.Name = "Mansion"
	refs = {
		rooms = {},
		doors = {},
		routes = {},
		hidingSpots = {},
		refugeDoors = {},
		taserPedestal = nil :: any,
		exitZone = nil :: any,
		hatchPoint = nil :: any,
		spawns = {},
		ladderCFrame = CFrame.identity,
		ladderSize = Vector3.one,
		flashlightSpot = Vector3.zero,
		altar = nil :: any,
		tunnel = nil :: any,
		vaults = {},
	}

	local openings, windows = planOpenings()
	local random = Random.new()
	for id in PLAN do
		if not GRAND_ROOMS[id] then
			refs.rooms[id] = {
				center = cellCenter(id),
				size = Vector3.new(ROOM_SIZE, LEVEL_HEIGHT, ROOM_SIZE),
			}
			buildRoom(id, random, openings[id])
		end
	end
	local hallWidth = GrandHall.X1 - GrandHall.X0
	local hallMidZ = (GrandHall.Z0 + GrandHall.Z1) / 2
	local galleryMidZ = (GrandHall.GalleryZ + GrandHall.Z1) / 2
	refs.rooms.hall = {
		center = cellCenter("hall"),
		size = Vector3.new(hallWidth, LEVEL_HEIGHT, GrandHall.Z1 - GrandHall.Z0),
		box = Vector3.new(GrandHall.CenterX, GROUND_Y, hallMidZ),
	}
	refs.rooms.room7 = {
		center = cellCenter("room7"),
		size = Vector3.new(hallWidth, LEVEL_HEIGHT, GrandHall.Z1 - GrandHall.GalleryZ),
		box = Vector3.new(GrandHall.CenterX, UPPER_Y, galleryMidZ),
	}

	for _, window in windows do
		part({
			Name = "Ventanal",
			Size = if window.horizontal
				then Vector3.new(window.width, window.height, 0.3)
				else Vector3.new(0.3, window.height, window.width),
			Position = window.position,
			-- Vidrio de niebla: casi opaco, no se ve lo que hay afuera.
			Color = Color3.fromRGB(122, 134, 152),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.06,
		})
		-- Marco de madera con parteluces y alféizar.
		local along = if window.horizontal then Vector3.xAxis else Vector3.zAxis
		local bars = if window.width > 20 then { -1 / 3, 0, 1 / 3 } else { 0 }
		for _, offset in bars do
			decor({
				Name = "Parteluz",
				Size = Vector3.new(0.5, window.height, 0.5),
				Position = window.position + along * window.width * offset,
				Color = WOOD_COLOR,
				Material = Enum.Material.Wood,
			})
		end
		for _, y in { -window.height / 2, window.height / 2 } do
			decor({
				Name = "MarcoVentana",
				Size = if window.horizontal
					then Vector3.new(window.width + 1, 0.6, 0.9)
					else Vector3.new(0.9, 0.6, window.width + 1),
				Position = window.position + Vector3.new(0, y, 0),
				Color = WOOD_COLOR,
				Material = Enum.Material.Wood,
			})
		end
		-- Por fuera: alféizar de piedra, postigos de madera entreabiertos y, a veces, enredadera.
		local out = window.outward :: Vector3
		local spanAxis = along * window.width / 2
		decor({
			Name = "Alfeizar",
			Size = if window.horizontal
				then Vector3.new(window.width + 3, 0.9, 2.2)
				else Vector3.new(2.2, 0.9, window.width + 3),
			Position = window.position + out * 1.2 - Vector3.new(0, window.height / 2 + 0.2, 0),
			Color = Color3.fromRGB(96, 92, 86),
			Material = Enum.Material.Concrete,
		})
		for _, side in { -1, 1 } do
			decor({
				Name = "Postigo",
				Size = if window.horizontal
					then Vector3.new(window.width / 3, window.height, 0.35)
					else Vector3.new(0.35, window.height, window.width / 3),
				CFrame = CFrame.new(
					window.position + spanAxis * side * 1.12 + out * (1.3 + window.width * 0.02)
				)
					* CFrame.Angles(0, side * math.rad(if window.horizontal then 28 else -28), 0),
				Color = Color3.fromRGB(34, 52, 40),
				Material = Enum.Material.Wood,
			})
		end
		if (window.position.X * 7 + window.position.Z * 13) % 3 < 1.4 then
			for strand = 1, 5 do
				local drop = 5 + (strand * 37 % 9)
				decor({
					Name = "Enredadera",
					Size = Vector3.new(0.5, drop, 0.5),
					Position = window.position
						+ spanAxis * ((strand - 3) * 0.45)
						+ out * 0.6
						+ Vector3.new(0, window.height / 2 + 1 - drop / 2, 0),
					Color = Color3.fromRGB(38 + strand * 4, 74, 40),
					Material = Enum.Material.Grass,
				})
			end
		end
		-- Las ventanitas del altillo dan sobre los techos: su lluvia caería dentro de los pasillos.
		if window.width > 20 then
			rainOutside(window)
		end
	end

	local altarAt = buildCellarWing()
	for _, link in LINKS do
		buildLink(link[1], link[2])
	end
	buildStairs("room5", "room4", "room5", true)

	-- Hall y galería tienen forma propia; sus centros siguen siendo los del plano.
	GrandHall.build({
		world = world,
		refs = refs,
		part = part,
		decor = decor,
		candle = candle,
		chandelier = chandelier,
		painting = painting,
		rug = rug,
		buildDoor = buildDoor,
		rainOutside = rainOutside,
		FURNITURE = FURNITURE,
		WALL_COLOR = WALL_COLOR,
		FLOOR_COLOR = FLOOR_COLOR,
		CEILING_COLOR = CEILING_COLOR,
		WOOD_COLOR = WOOD_COLOR,
		GOLD_COLOR = GOLD_COLOR,
		CANDLE_LIGHT = CANDLE_LIGHT,
		DOOR_HEIGHT = DOOR_HEIGHT,
		CORRIDOR_HEIGHT = CORRIDOR_HEIGHT,
	})
	local eastX = (GrandHall.FlightEast.x0 + GrandHall.FlightEast.x1) / 2
	addRoute("hall", "room7", {
		Vector3.new(-6, 0, -20),
		Vector3.new(-6, 0, GrandHall.FlightZ0 - 6),
		Vector3.new(eastX, 0, GrandHall.FlightZ0 - 6),
		Vector3.new(eastX, LEVEL_HEIGHT, GrandHall.GalleryZ + 2),
	})

	-- Bajo el primer piso del ala sur no hay pieza: un bloque macizo sostiene el edificio.
	part({
		Name = "Cimiento",
		Size = Vector3.new(ROOM_SIZE, LEVEL_HEIGHT - 1, ROOM_SIZE),
		Position = Vector3.new(0, (LEVEL_HEIGHT - 1) / 2, PITCH),
		Color = WALL_COLOR,
		Material = Enum.Material.Concrete,
	})

	for id, refuge in REFUGES do
		buildRefuge(id, refuge.room, refuge.dir)
	end

	-- Trampilla del altillo: el asesino la cruza apareciendo del otro lado.
	local hatchBelow = cellCenter("room12") + Vector3.new(0, 0, (HATCH.z0 + HATCH.z1) / 2)
	refs.routes["room12>attic"] = { hatchBelow }
	refs.routes["attic>room12"] = { hatchBelow + Vector3.new(0, LEVEL_HEIGHT, -10) }
	refs.hatchPoint = decor({
		Name = "PuntoEscalera",
		Size = Vector3.new(2, 2, 2),
		Position = hatchBelow + Vector3.new(0, 3, 0),
		Transparency = 1,
	})
	refs.ladderSize = Vector3.new(4, LEVEL_HEIGHT + 3, 2)
	refs.ladderCFrame = CFrame.new(hatchBelow + Vector3.new(0, (LEVEL_HEIGHT + 3) / 2, 3))

	-- Puerta principal: ya no es la salida. Los jugadores entran por ella desde el patio y se cierra de
	-- un portazo; no tiene botón porque no se abre más.
	local hall = cellCenter("hall")
	refs.doors.front = buildDoor(
		"front",
		Vector3.new(GrandHall.CenterX, 0, GrandHall.Z0 - 0.5),
		Vector3.xAxis,
		"",
		14,
		15,
		14,
		15
	)
	refs.doors.front.prompt:Destroy()

	-- Los jugadores de cada partida aparecen en el patio, frente a la puerta, y entran caminando.
	for i = 1, 4 do
		local spawnPoint = Instance.new("SpawnLocation")
		spawnPoint.Anchored = true
		spawnPoint.Neutral = true
		spawnPoint.Duration = 0
		spawnPoint.Enabled = true
		spawnPoint.Transparency = 1
		spawnPoint.CanCollide = false
		spawnPoint.Size = Vector3.new(4, 0.2, 4)
		spawnPoint.Position =
			Vector3.new(GrandHall.CenterX - 6 + (i - 1) * 4, 0.35, GrandHall.Z0 - 16)
		spawnPoint.Parent = world
		table.insert(refs.spawns, spawnPoint)
	end
	refs.taserPedestal = part({
		Name = "PedestalTaser",
		Size = Vector3.new(3, 3.6, 3),
		Position = Vector3.new(GrandHall.CenterX + 12, 1.8, GrandHall.Z0 + 22),
		Color = WOOD_COLOR,
		Material = Enum.Material.Marble,
	})

	buildAltar(altarAt, hall)
	placeVaults()
	buildExterior()
	carveTunnel()
	Courtyard.build({ part = part, decor = decor, rainOutside = rainOutside })
	for id, count in furnishedCount do
		local all = refs.hidingSpots[id]
		extraSpots[id] = table.move(all, count + 1, #all, 1, {})
	end
	applyVariants(Random.new())
	rollDoors(Random.new())
	world.Parent = workspace
	return refs
end

-- Solo para los atajos de QA: desde dónde mirar cada pasillo tapiado de esta partida.
function Mansion.debugSealedViews(): { { position: Vector3, look: Vector3 } }
	local views = {}
	for key in currentLayout.sealed do
		local spot = corridorSpots[key]
		local along = Vector3.new(-spot.across.Z, 0, spot.across.X)
		table.insert(
			views,
			{ position = spot.middle - along * 11 + Vector3.new(0, 5, 0), look = along }
		)
	end
	return views
end
-- Puertas con llave que hay que abrir para llegar a cada pieza, con la distribución de esta partida.
function Mansion.currentNeeds(): { [string]: { string } }
	return MapDef.needs(currentLayout)
end

-- Solo para los atajos de QA: pasa al siguiente animal del pedestal y devuelve su nombre.
local debugAnimal = 0
function Mansion.debugCycleAnimal(): string
	debugAnimal = debugAnimal % #ANIMAL_ORDER + 1
	local kind = ANIMAL_ORDER[debugAnimal]
	for name, folder in animalFolders do
		folder.Parent = if name == kind then world else nil
	end
	return kind
end

-- Solo para QA: pasa a la siguiente cabeza (siempre en la pieza 1) y devuelve su nombre.
local debugHead = 0
function Mansion.debugCycleHead(): string
	local heads = { "moose", "rhino", "crocodile" }
	debugHead = debugHead % #heads + 1
	for room, folders in headFolders do
		for name, folder in folders do
			folder.Parent = if room == "room1" and name == heads[debugHead] then world else nil
		end
	end
	return heads[debugHead]
end

-- Una partida nueva: otro animal en el pedestal, una sola cabeza en una de las dos paredes y
-- el mobiliario de las piezas sorteado de nuevo. Hay que llamarla antes de repartir los objetos.
function Mansion.rerollRound()
	local random = Random.new()
	applyVariants(random)
	rollDoors(random)
	-- Paredes, pisos, alfombras y cuadros: cada pieza cambia de aspecto.
	for _, id in
		{
			"room1",
			"room2",
			"room3",
			"room4",
			"room8",
			"room9",
			"room10",
			"room11",
			"room12",
			"attic",
			"gameRoom",
			"bar",
		}
	do
		skinRoom(id, random)
		dressRoom(id, random)
	end
	for _, id in
		{
			"room1",
			"room2",
			"room3",
			"room8",
			"room9",
			"room10",
			"room11",
			"room12",
			"attic",
			"gameRoom",
			"bar",
		}
	do
		furnishRoom(id, random, true)
	end
	-- Los muebles cambiaron de lugar: las cajas fuertes se acomodan de nuevo para no chocar con ninguno.
	placeVaults()
end

-- Pieza que contiene la posición; nil en pasillos.
-- (El tramo largo del sótano cuenta como room6: ver buildCellarWing.)
function Mansion.roomAt(position: Vector3): string?
	for id, room in refs.rooms do
		local delta = position - (room.box or room.center)
		if
			math.abs(delta.X) <= room.size.X / 2
			and math.abs(delta.Z) <= room.size.Z / 2
			and delta.Y >= -1
			and delta.Y < LEVEL_HEIGHT - 1
		then
			return id
		end
	end
	return nil
end

-- Puntos a recorrer para pasar de la pieza `a` a la pieza `b`.
function Mansion.route(a: string, b: string): { Vector3 }?
	return refs.routes[`{a}>{b}`]
end

-- La trampilla del altillo no se camina: el asesino aparece del otro lado.
local hatchOpen = false

function Mansion.setHatchOpen(open: boolean)
	hatchOpen = open
end

-- Si el asesino puede cruzar de `a` a `b`: la puerta abierta o la escalera puesta.
function Mansion.isLinkOpen(a: string, b: string): boolean
	if Mansion.isHatch(a, b) then
		return hatchOpen
	end
	if MapDef.isSealed(a, b, currentLayout) then
		return false
	end
	local doorKey = MapDef.lockOf(a, b, currentLayout)
	return not doorKey or refs.doors[doorKey].unlocked
end

function Mansion.isHatch(a: string, b: string): boolean
	return MapDef.isHatch(a, b)
end

local SWING = TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

function Mansion.swingDoor(door: Door, open: boolean)
	if door.swung == open then
		return
	end
	door.swung = open
	if open then
		playAt(door.blocker, if door.metal then Sounds.MetalDoor else Sounds.DoorCreak, 1.2)
	end
	for _, leaf in door.leaves do
		TweenService:Create(leaf.part, SWING, { CFrame = if open then leaf.open else leaf.closed })
			:Play()
	end
end

local SLAM = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

-- Portazo: las hojas vuelven de golpe y la puerta queda trabada otra vez.
function Mansion.slamDoor(door: Door)
	door.unlocked = false
	door.swung = false
	door.blocker.CanCollide = true
	door.prompt.Enabled = false
	for _, leaf in door.leaves do
		TweenService:Create(leaf.part, SLAM, { CFrame = leaf.closed }):Play()
	end
end

-- Golpe desde adentro: las hojas cerradas se sacuden un instante.
function Mansion.rattleDoor(door: Door, strength: number)
	for _, leaf in door.leaves do
		local push = leaf.closed + door.normal * strength
		TweenService:Create(leaf.part, TweenInfo.new(0.05), { CFrame = push }):Play()
		task.delay(0.06, function()
			TweenService:Create(leaf.part, TweenInfo.new(0.12, Enum.EasingStyle.Bounce), {
				CFrame = leaf.closed,
			}):Play()
		end)
	end
end

function Mansion.setDoorUnlocked(door: Door, unlocked: boolean)
	-- El chasquido de la cerradura, solo cuando de verdad se destraba.
	if unlocked and not door.unlocked then
		playAt(door.blocker, Sounds.DoorUnlock, 0.8)
	end
	door.unlocked = unlocked
	door.blocker.CanCollide = not unlocked
	door.prompt.Enabled = not unlocked
	Mansion.swingDoor(door, unlocked)
	if door.twin and door.twin.unlocked ~= unlocked then
		Mansion.setDoorUnlocked(door.twin, unlocked)
	end
end

return Mansion
