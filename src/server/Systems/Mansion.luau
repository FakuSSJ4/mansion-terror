--!strict
-- Genera la mansión por código: planta baja, sótano, primer piso y altillo sobre una grilla.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Routes = require(Shared:WaitForChild("Rules"):WaitForChild("Routes"))

local GrandHall = require(script.Parent:WaitForChild("GrandHall"))

local ROOM_SIZE = 56
local HALF = ROOM_SIZE / 2
local LEVEL_HEIGHT = 20
local CEILING = 18
local PITCH = 80
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
local FLOOR_COLOR = Color3.fromRGB(112, 8, 14)
local CEILING_COLOR = Color3.fromRGB(58, 34, 20)
local WOOD_COLOR = Color3.fromRGB(52, 33, 22)
local FABRIC_COLOR = Color3.fromRGB(70, 40, 42)
local GOLD_COLOR = Color3.fromRGB(170, 135, 60)
local CANDLE_LIGHT = Color3.fromRGB(255, 222, 190)
local REFUGE_LIGHT = Color3.fromRGB(120, 170, 255)

type RoomPlan = { col: number, row: number, y: number }
type Hole = { x0: number, x1: number, z0: number, z1: number }
type Opening = { width: number, bottom: number, top: number }

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
}

local LINKS = {
	{ "hall", "room1" },
	{ "room1", "room2" },
	{ "room2", "room3" },
	{ "room3", "room4" },
	{ "room5", "room6" },
	{ "room7", "room8" },
	{ "room8", "room9" },
	{ "room9", "room10" },
	{ "room10", "room11" },
	{ "room11", "room12" },
}

local LOCKED_LINKS = { room2 = true, room3 = true, room9 = true, room11 = true }

local REFUGES = {
	refuge1 = { room = "room1", dir = Vector3.new(0, 0, 1) },
	refuge2 = { room = "room6", dir = Vector3.new(0, 0, -1) },
	refuge3 = { room = "room8", dir = Vector3.new(0, 0, 1) },
}

local FLOOR_HOLES: { [string]: Hole } = { room4 = STAIR, attic = HATCH }
local CEILING_HOLES: { [string]: Hole } = { room5 = STAIR, room12 = HATCH }
local STAIR_ROOMS = { room4 = true, room5 = true }
local CHANDELIER_ROOMS = { room1 = true, room2 = true, room8 = true, room10 = true }
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
	ladderCFrame: CFrame,
	ladderSize: Vector3,
	flashlightSpot: Vector3,
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

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = props.Parent or world
	return p
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
	return Vector3.new(plan.col * PITCH, plan.y, plan.row * PITCH)
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
	decor({
		Name = "Alfombra",
		Size = Vector3.new(width, 0.08, depth),
		Position = center + Vector3.new(0, 0.05, 0),
		Color = color,
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
		solid(
			base,
			"CamaDosPlazas",
			Vector3.new(11, 1.6, 12),
			CFrame.new(0, 2.2, 0),
			linen,
			Enum.Material.Fabric
		)
		solid(
			base,
			"Cabecera",
			Vector3.new(12, 7, 0.8),
			CFrame.new(0, 3.5, 6.2),
			GOLD_COLOR,
			Enum.Material.Wood
		)
		for _, x in { -2.8, 2.8 } do
			solid(
				base,
				"Almohada",
				Vector3.new(4, 0.8, 2.2),
				CFrame.new(x, 3.4, 4.3),
				Color3.fromRGB(220, 215, 200),
				Enum.Material.Fabric
			)
		end
		for _, x in { -5.2, 5.2 } do
			for _, z in { -5.5, 5.5 } do
				solid(base, "Pata", Vector3.new(0.6, 1.4, 0.6), CFrame.new(x, 0.7, z), WOOD_COLOR)
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
}

local CORNERS =
	{ Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) }
local EAST_CORNERS = { Vector3.new(1, 0, 1), Vector3.new(1, 0, -1) }

local function furnishRoom(id: string, random: Random)
	local center = cellCenter(id)
	local corners = if STAIR_ROOMS[id] then EAST_CORNERS else CORNERS
	local theme = THEMES[id]
	local spots = {}
	for i, corner in corners do
		local position = center + corner * 19
		local base = CFrame.lookAt(position, center)
		local kind = theme and theme[i] or GENERIC_KINDS[random:NextInteger(1, #GENERIC_KINDS)]
		for _, spot in FURNITURE[kind](base) do
			table.insert(spots, spot)
		end
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
)
	decor({
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

-- Puma entero caminando sobre un pedestal; `base` está en el piso.
local function pumaOnPlinth(base: CFrame)
	local coat = Color3.fromRGB(170, 126, 80)
	local pale = Color3.fromRGB(214, 190, 156)
	local dark = Color3.fromRGB(42, 30, 22)
	solid(base, "Pedestal", Vector3.new(9, 1.5, 3.4), CFrame.new(0, 0.75, 0), WOOD_COLOR)
	solid(
		base,
		"PlacaPedestal",
		Vector3.new(1.6, 0.5, 0.1),
		CFrame.new(0, 0.75, -1.72),
		GOLD_COLOR,
		Enum.Material.Metal
	)
	local top = base * CFrame.new(0, 1.5, 0)
	trophyLight((top * CFrame.new(0, 4, -6)).Position)
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
	end
	stuffed(
		top,
		"CuelloPuma",
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
		dark,
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
			Color3.fromRGB(190, 150, 50),
			nil,
			Enum.Material.SmoothPlastic
		)
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
end

local function placeTrophies(id: string)
	local center = cellCenter(id)
	local function onWall(x: number, z: number, inward: Vector3): CFrame
		local point = center + Vector3.new(x, 11, z)
		return CFrame.lookAt(point, point + inward)
	end
	if id == "room1" then
		mooseHead(onWall(HALF - 0.5, 13, -Vector3.xAxis))
	elseif id == "room2" then
		rhinoHead(onWall(-HALF + 0.5, 13, Vector3.xAxis))
	elseif id == "room11" then
		local spot = center + Vector3.new(-11, 0, -HALF + 2.4)
		pumaOnPlinth(CFrame.lookAt(spot, spot + Vector3.zAxis))
	end
end

local function decorateRoom(id: string, random: Random)
	placeTrophies(id)
	local center = cellCenter(id)
	local inCellar = PLAN[id].y == CELLAR_Y
	if not inCellar then
		local rugCenter = if STAIR_ROOMS[id] then center + Vector3.new(8, 0, 0) else center
		local colors = {
			Color3.fromRGB(60, 80, 150),
			Color3.fromRGB(80, 120, 80),
			Color3.fromRGB(150, 110, 60),
		}
		rug(rugCenter, 20, 26, colors[random:NextInteger(1, #colors)])
	end
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
	if not inCellar then
		local y = center.Y + 9
		local kinds = { 1, 2, 3 }
		local placements = {
			{ Vector3.new(20, 0, -HALF + 0.7), Vector3.zAxis },
			{ Vector3.new(-20, 0, HALF - 0.7), -Vector3.zAxis },
			{ Vector3.new(HALF - 0.7, 0, 20), -Vector3.xAxis },
			{ Vector3.new(-HALF + 0.7, 0, -22), Vector3.xAxis },
		}
		for i, placement in placements do
			painting(
				Vector3.new(center.X, y, center.Z) + placement[1],
				placement[2],
				kinds[(i + random:NextInteger(0, 2)) % 3 + 1]
			)
		end
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
		-- Dos pilastras por pared, cerca de las esquinas.
		for _, sign in { -1, 1 } do
			decor({
				Name = "Pilastra",
				Size = if side.along.X ~= 0
					then Vector3.new(2, CEILING, 0.7)
					else Vector3.new(0.7, CEILING, 2),
				Position = wallPoint + side.along * sign * 25 + Vector3.new(0, CEILING / 2, 0),
				Color = if inCellar
					then Color3.fromRGB(120, 114, 104)
					else Color3.fromRGB(190, 190, 182),
				Material = Enum.Material.Concrete,
			})
		end
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
	}
end

local function buildLink(a: string, b: string)
	local ca, cb = cellCenter(a), cellCenter(b)
	local dir = (cb - ca).Unit
	local middle = (ca + cb) / 2
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local length = PITCH - ROOM_SIZE
	local floorSize = if math.abs(dir.X) > 0
		then Vector3.new(length, 1, CORRIDOR_WIDTH + 2)
		else Vector3.new(CORRIDOR_WIDTH + 2, 1, length)
	part({
		Name = "PisoPasillo",
		Size = floorSize,
		Position = middle - Vector3.new(0, 0.5, 0),
		Color = FLOOR_COLOR,
		Material = Enum.Material.WoodPlanks,
	})
	part({
		Name = "TechoPasillo",
		Size = floorSize,
		Position = middle + Vector3.new(0, CORRIDOR_HEIGHT + 0.5, 0),
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

	if LOCKED_LINKS[b] then
		refs.doors[b] = buildDoor(
			b,
			middle,
			across,
			"Abrir",
			DOOR_WIDTH,
			DOOR_HEIGHT,
			CORRIDOR_WIDTH,
			CORRIDOR_HEIGHT
		)
	end
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
	PhysicsService:CollisionGroupSetCollidable("KillerBarrier", "Default", false)
	-- El modo desarrollador atraviesa puertas cerradas y barreras.
	PhysicsService:RegisterCollisionGroup("DevPlayer")
	PhysicsService:CollisionGroupSetCollidable("DevPlayer", "LockedDoor", false)
	PhysicsService:CollisionGroupSetCollidable("DevPlayer", "KillerBarrier", false)
end

local function buildExterior()
	-- Terreno en cuatro franjas: no tapa el agujero de la escalera del sótano.
	local x0, x1, z0, z1 = -HALF - 2, 2 * PITCH + HALF + 2, -HALF - 2, PITCH + HALF + 2
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
	ground(-far, far, -far, hallZ0)
	ground(-far, far, z1, far)
	ground(-far, hallX0, hallZ0, z1)
	ground(x1, far, hallZ0, z1)
	ground(GrandHall.X1 + 2, x1, hallZ0, z0)
	ground(hallX0, x0, GrandHall.Z1 + 2, z1)

	-- Bosque: se ven solo árboles hasta perderse en la niebla.
	local random = Random.new(7)
	local midX, midZ = (x0 + x1) / 2, (z0 + z1) / 2
	local trunkColor = Color3.fromRGB(62, 46, 32)
	local leafColor = Color3.fromRGB(34, 70, 40)
	local planted = 0
	while planted < 170 do
		local angle = random:NextNumber(0, 2 * math.pi)
		local radius = random:NextNumber(70, 300)
		local x, z = midX + math.cos(angle) * radius, midZ + math.sin(angle) * radius
		if x < hallX0 - 14 or x > x1 + 14 or z < hallZ0 - 14 or z > z1 + 14 then
			planted += 1
			local height = random:NextNumber(38, 70)
			decor({
				Name = "Tronco",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, 2.6, 2.6),
				CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = trunkColor,
				Material = Enum.Material.Wood,
			})
			decor({
				Name = "Copa",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * random:NextNumber(20, 30),
				Position = Vector3.new(x, height, z),
				Color = leafColor,
				Material = Enum.Material.Grass,
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
			then Vector3.new(window.width + 26, 1, 10)
			else Vector3.new(10, 1, window.width + 26),
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
local function buildAltar(hall: Vector3)
	-- En el centro del hall, entre los dos tramos de la escalera, mirando a la entrada.
	local midX = GrandHall.CenterX
	local base = CFrame.lookAt(hall + Vector3.new(midX, 0, -18), hall + Vector3.new(midX, 0, -60))
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
	local side = base * CFrame.new(10, 0, 0)
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
	prompt.Parent = decor({
		Name = "PuntoEstatua",
		Size = Vector3.one,
		Position = (base * CFrame.new(0, 5.5, -3)).Position,
		Transparency = 1,
	})
	refs.altar = {
		prompt = prompt,
		drawer = drawer,
		closedCFrame = drawer.CFrame,
		openCFrame = drawer.CFrame * CFrame.new(0, 0, -2.6),
		position = cabinet.Position,
		keySpot = (closedDrawer * CFrame.new(0, 1, -1)).Position,
	}
end

function Mansion.setDrawerOpen(open: boolean)
	local altar = refs.altar
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
		ladderCFrame = CFrame.identity,
		ladderSize = Vector3.one,
		flashlightSpot = Vector3.zero,
		altar = nil :: any,
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
			Color = Color3.fromRGB(90, 110, 140),
			-- El material Glass oculta las partículas que hay detrás: la lluvia no se vería.
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.88,
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
		-- Las ventanitas del altillo dan sobre los techos: su lluvia caería dentro de los pasillos.
		if window.width > 20 then
			rainOutside(window)
		end
	end

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

	-- Puerta principal: es la salida. Afuera, la zona que da por terminada la partida.
	local hall = cellCenter("hall")
	refs.doors.exit = buildDoor(
		"exit",
		Vector3.new(GrandHall.CenterX, 0, GrandHall.Z0 - 0.5),
		Vector3.xAxis,
		"Abrir salida",
		14,
		15,
		14,
		15
	)
	refs.exitZone = decor({
		Name = "ZonaSalida",
		Size = Vector3.new(40, 14, 8),
		Position = Vector3.new(GrandHall.CenterX, 7, GrandHall.Z0 - 10),
		Transparency = 1,
	})
	refs.exitZone.CanTouch = true

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
			Vector3.new(GrandHall.CenterX - 9 + (i - 1) * 6, 0.1, GrandHall.Z0 + 12)
		spawnPoint.Parent = world
	end

	refs.taserPedestal = part({
		Name = "PedestalTaser",
		Size = Vector3.new(3, 3.6, 3),
		Position = Vector3.new(GrandHall.CenterX + 12, 1.8, GrandHall.Z0 + 22),
		Color = WOOD_COLOR,
		Material = Enum.Material.Marble,
	})

	buildAltar(hall)
	buildExterior()
	world.Parent = workspace
	return refs
end

-- Pieza que contiene la posición; nil en pasillos.
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
-- Conexiones cerradas con llave: pieza vecina -> puerta que hay que abrir.
local LOCKED_BY: { [string]: string } = {
	["room1|room2"] = "room2",
	["room2|room3"] = "room3",
	["room4|room5"] = "room5",
	["hall|room7"] = "room7",
	["room8|room9"] = "room9",
	["room10|room11"] = "room11",
}
local hatchOpen = false

function Mansion.setHatchOpen(open: boolean)
	hatchOpen = open
end

-- Si el asesino puede cruzar de `a` a `b`: la puerta abierta o la escalera puesta.
function Mansion.isLinkOpen(a: string, b: string): boolean
	if Mansion.isHatch(a, b) then
		return hatchOpen
	end
	local doorKey = LOCKED_BY[`{a}|{b}`] or LOCKED_BY[`{b}|{a}`]
	return not doorKey or refs.doors[doorKey].unlocked
end

function Mansion.isHatch(a: string, b: string): boolean
	return (a == "room12" and b == "attic") or (a == "attic" and b == "room12")
end

local SWING = TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

function Mansion.swingDoor(door: Door, open: boolean)
	if door.swung == open then
		return
	end
	door.swung = open
	for _, leaf in door.leaves do
		TweenService:Create(leaf.part, SWING, { CFrame = if open then leaf.open else leaf.closed })
			:Play()
	end
end

function Mansion.setDoorUnlocked(door: Door, unlocked: boolean)
	door.unlocked = unlocked
	door.blocker.CanCollide = not unlocked
	door.prompt.Enabled = not unlocked
	Mansion.swingDoor(door, unlocked)
	if door.twin and door.twin.unlocked ~= unlocked then
		Mansion.setDoorUnlocked(door.twin, unlocked)
	end
end

return Mansion
