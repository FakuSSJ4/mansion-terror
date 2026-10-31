--!strict
-- Genera la mansión por código: planta baja, sótano, primer piso y altillo sobre una grilla.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Routes = require(Shared:WaitForChild("Rules"):WaitForChild("Routes"))

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

local CELLAR_Y = -LEVEL_HEIGHT
local GROUND_Y = 0
local UPPER_Y = LEVEL_HEIGHT
local ATTIC_Y = 2 * LEVEL_HEIGHT

-- La escalera ocupa este rectángulo del lado oeste de la pieza, subiendo hacia +Z.
local STAIR = { x0 = -HALF, x1 = -12, z0 = -18, z1 = 22 }
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

local LOCKED_LINKS = { room2 = true, room3 = true, room4 = true, room6 = true }

local REFUGES = {
	refuge1 = { room = "room1", dir = Vector3.new(0, 0, 1) },
	refuge2 = { room = "room6", dir = Vector3.new(0, 0, -1) },
	refuge3 = { room = "room8", dir = Vector3.new(0, 0, 1) },
}

local FLOOR_HOLES: { [string]: Hole } = { room7 = STAIR, room4 = STAIR, attic = HATCH }
local CEILING_HOLES: { [string]: Hole } = { hall = STAIR, room5 = STAIR, room12 = HATCH }
local STAIR_ROOMS = { hall = true, room4 = true, room5 = true, room7 = true }
local CHANDELIER_ROOMS =
	{ hall = true, room1 = true, room2 = true, room7 = true, room8 = true, room10 = true }

export type Door = {
	visual: BasePart,
	blocker: BasePart,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	unlocked: boolean,
	swung: boolean,
	prompt: ProximityPrompt,
}

export type MansionRefs = {
	rooms: { [string]: { center: Vector3, size: Vector3 } },
	doors: { [string]: Door },
	routes: { [string]: { Vector3 } },
	hidingSpots: { [string]: { Vector3 } },
	refugeDoors: { [string]: Vector3 },
	taserPedestal: BasePart,
	exitZone: BasePart,
	hatchPoint: BasePart,
	ladderCFrame: CFrame,
	ladderSize: Vector3,
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

local function chandelier(center: Vector3)
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
	local light = Instance.new("PointLight")
	light.Color = CANDLE_LIGHT
	light.Range = 34
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
		solid(
			base,
			"Piano",
			Vector3.new(9, 4, 5),
			CFrame.new(0, 3, 0),
			Color3.fromRGB(14, 12, 12),
			Enum.Material.SmoothPlastic
		)
		solid(
			base,
			"Teclas",
			Vector3.new(8, 0.3, 1),
			CFrame.new(0, 3.5, -3),
			Color3.fromRGB(225, 222, 210),
			Enum.Material.SmoothPlastic
		)
		return { (base * CFrame.new(-2, 5.3, 0)).Position, (base * CFrame.new(1, 0.3, 0)).Position }
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

local function decorateRoom(id: string, random: Random)
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
	wall(center + Vector3.new(HALF, 0, 0), Vector3.zAxis, ROOM_SIZE, LEVEL_HEIGHT, openings.E)
	wall(center - Vector3.new(HALF, 0, 0), Vector3.zAxis, ROOM_SIZE, LEVEL_HEIGHT, openings.W)
	wall(center + Vector3.new(0, 0, HALF), Vector3.xAxis, ROOM_SIZE, LEVEL_HEIGHT, openings.S)
	wall(center - Vector3.new(0, 0, HALF), Vector3.xAxis, ROOM_SIZE, LEVEL_HEIGHT, openings.N)

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
end

-- Ícono de llave pintado en una cara de la puerta, del color de la llave que la abre.
local function keyIcon(door: BasePart, face: Enum.NormalId, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.5
	gui.Parent = door
	local function piece(x: number, y: number, w: number, h: number, round: boolean)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.new(0.5, x, 0.5, y)
		frame.Size = UDim2.fromOffset(w, h)
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Parent = gui
		-- El contorno claro hace que también se distinga la llave negra.
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(225, 215, 195)
		stroke.Thickness = 2
		stroke.Parent = frame
		if round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = frame
		end
	end
	piece(0, 20, 16, 80, false)
	piece(18, 42, 22, 12, false)
	piece(18, 18, 22, 12, false)
	piece(0, -38, 60, 60, true)
end

local function buildDoor(
	key: string,
	position: Vector3,
	along: Vector3,
	actionText: string,
	width: number,
	height: number,
	blockerWidth: number,
	blockerHeight: number
): Door
	local function sized(w: number, h: number): Vector3
		return if math.abs(along.X) > 0 then Vector3.new(w, h, 0.6) else Vector3.new(0.6, h, w)
	end
	local closed = CFrame.new(position + Vector3.new(0, height / 2, 0))
	local hingeOffset = along * (width / 2)
	local open = CFrame.new(position - hingeOffset + Vector3.new(0, height / 2, 0))
		* CFrame.Angles(0, math.rad(90), 0)
		* CFrame.new(hingeOffset)
	local keyIndex = tonumber(string.match(key, "%d+"))
	local keyColor = if keyIndex then Config.KeyColors[keyIndex - 1] else nil
	local emblem =
		Color3.fromRGB(table.unpack(if keyColor then keyColor.rgb else Config.GoldKeyRgb))
	local visual = part({
		Name = `Puerta_{key}`,
		Size = sized(width, height),
		CFrame = closed,
		Color = Color3.fromRGB(38, 22, 14):Lerp(emblem, 0.2),
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	})
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
	-- En el bloqueo, que no se mueve: la hoja se abre sola cuando pasa el asesino.
	prompt.Parent = blocker
	local faces = if math.abs(along.X) > 0
		then { Enum.NormalId.Front, Enum.NormalId.Back }
		else { Enum.NormalId.Left, Enum.NormalId.Right }
	for _, face in faces do
		keyIcon(visual, face, emblem)
	end
	return {
		visual = visual,
		blocker = blocker,
		closedCFrame = closed,
		openCFrame = open,
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
		-- Lateral macizo que acompaña los escalones y termina al nivel del piso de arriba.
		local sideHeight = math.min(i + 4, LEVEL_HEIGHT)
		part({
			Name = "LateralEscalera",
			Size = Vector3.new(1, sideHeight, run),
			Position = base + Vector3.new(STAIR.x1 + 0.5, sideHeight / 2, z),
			Color = WOOD_COLOR,
			Material = Enum.Material.Wood,
		})
	end

	-- Baranda recta alrededor del hueco; una pared invisible impide saltarla.
	local stairLength = STAIR.z1 - STAIR.z0
	local sideRail = Vector3.new(STAIR.x1 + 0.5, LEVEL_HEIGHT, (STAIR.z0 + STAIR.z1) / 2)
	local endRail = Vector3.new(xCenter + 0.5, LEVEL_HEIGHT, STAIR.z0 - 0.5)
	for _, rail in
		{
			{ sideRail, Vector3.new(0.6, 0.5, stairLength + 1) },
			{ endRail, Vector3.new(width + 1, 0.5, 0.6) },
		}
	do
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
	for offset = 0, stairLength, 8 do
		part({
			Name = "Baluastre",
			Size = Vector3.new(0.5, 3.5, 0.5),
			Position = base + Vector3.new(STAIR.x1 + 0.5, LEVEL_HEIGHT + 1.75, STAIR.z0 + offset),
			Color = WOOD_COLOR,
			Material = Enum.Material.Wood,
		})
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
		CORRIDOR_HEIGHT
	)

	local up = LEVEL_HEIGHT
	addRoute(lower, upper, {
		base + Vector3.new(-6, 0, STAIR.z0 - 6),
		base + Vector3.new(xCenter, 0, STAIR.z0 - 6),
		base + Vector3.new(xCenter, up, STAIR.z1 + 3),
		base + Vector3.new(-6, up, STAIR.z1 + 3),
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
	PhysicsService:CollisionGroupSetCollidable("LockedDoor", "Killer", false)
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
	ground(-far, far, -far, z0)
	ground(-far, far, z1, far)
	ground(-far, x0, z0, z1)
	ground(x1, far, z0, z1)

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
		if x < x0 - 14 or x > x1 + 14 or z < z0 - 14 or z > z1 + 14 then
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
	local cloud = decor({
		Name = "Lluvia",
		Size = if window.horizontal
			then Vector3.new(window.width + 16, 1, 22)
			else Vector3.new(22, 1, window.width + 16),
		Position = window.position + window.outward * 14 + Vector3.new(0, 24, 0),
		Transparency = 1,
	})
	local rain = Instance.new("ParticleEmitter")
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Speed = NumberRange.new(95, 115)
	rain.Lifetime = NumberRange.new(0.45)
	rain.Rate = 500
	rain.Size = NumberSequence.new(0.2)
	rain.Squash = NumberSequence.new(5)
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 205, 230))
	rain.Transparency = NumberSequence.new(0.35)
	rain.LightInfluence = 0
	rain.Parent = cloud
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
	openings.hall.N = { width = 14, bottom = 0, top = 15 }

	local occupied: { [string]: boolean } = { [`0,1,{GROUND_Y}`] = true }
	for _, plan in PLAN do
		occupied[`{plan.col},{plan.row},{plan.y}`] = true
	end
	local windows = {}
	for id, plan in PLAN do
		if plan.y ~= CELLAR_Y then
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
	local base = CFrame.lookAt(hall + Vector3.new(10, 0, 24), hall + Vector3.new(10, 0, 0))
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
		altar = nil :: any,
	}

	local openings, windows = planOpenings()
	local random = Random.new()
	for id in PLAN do
		refs.rooms[id] = {
			center = cellCenter(id),
			size = Vector3.new(ROOM_SIZE, LEVEL_HEIGHT, ROOM_SIZE),
		}
		buildRoom(id, random, openings[id])
	end

	for _, window in windows do
		part({
			Name = "Ventanal",
			Size = if window.horizontal
				then Vector3.new(window.width, window.height, 0.3)
				else Vector3.new(0.3, window.height, window.width),
			Position = window.position,
			Color = Color3.fromRGB(90, 110, 140),
			Material = Enum.Material.Glass,
			Transparency = 0.7,
		})
		-- Las ventanitas del altillo dan sobre los techos: su lluvia caería dentro de los pasillos.
		if window.width > 20 then
			rainOutside(window)
		end
	end

	for _, link in LINKS do
		buildLink(link[1], link[2])
	end
	buildStairs("room5", "room4", "room5", true)
	buildStairs("hall", "room7", "room7", false)

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
		hall + Vector3.new(0, 0, -HALF),
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
		Position = hall + Vector3.new(0, 7, -HALF - 10),
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
		spawnPoint.Position = hall + Vector3.new(4 + (i - 1) * 5, 0.1, -14)
		spawnPoint.Parent = world
	end

	refs.taserPedestal = part({
		Name = "PedestalTaser",
		Size = Vector3.new(3, 3.6, 3),
		Position = hall + Vector3.new(21, 1.8, -8),
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
		local delta = position - room.center
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
function Mansion.isHatch(a: string, b: string): boolean
	return (a == "room12" and b == "attic") or (a == "attic" and b == "room12")
end

local SWING = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Mansion.swingDoor(door: Door, open: boolean)
	if door.swung == open then
		return
	end
	door.swung = open
	TweenService
		:Create(
			door.visual,
			SWING,
			{ CFrame = if open then door.openCFrame else door.closedCFrame }
		)
		:Play()
end

function Mansion.setDoorUnlocked(door: Door, unlocked: boolean)
	door.unlocked = unlocked
	door.blocker.CanCollide = not unlocked
	door.prompt.Enabled = not unlocked
	Mansion.swingDoor(door, unlocked)
end

return Mansion
