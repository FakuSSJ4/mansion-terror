--!strict
-- Genera la mansión por código a partir de un plano en grilla.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local ROOM_SIZE = 40
local ROOM_HEIGHT = 16
local PITCH = 60
local WALL = 1
local CORRIDOR_WIDTH = 10
local DOOR_WIDTH = 8
local DOOR_HEIGHT = 10
local REFUGE_WIDTH = 24
local REFUGE_DEPTH = 18

local WALL_COLOR = Color3.fromRGB(58, 44, 38)
local FLOOR_COLOR = Color3.fromRGB(46, 31, 23)
local WOOD_COLOR = Color3.fromRGB(52, 33, 22)
local CANDLE_LIGHT = Color3.fromRGB(255, 170, 90)
local REFUGE_LIGHT = Color3.fromRGB(120, 170, 255)

local CELLS: { [string]: { number } } = {
	hall = { 0, 0 },
	room1 = { 1, 0 },
	room2 = { 2, 0 },
	room3 = { 3, 0 },
	room4 = { 3, 1 },
	room5 = { 2, 1 },
	room6 = { 1, 1 },
	room7 = { 0, 1 },
	room8 = { 0, 2 },
	room9 = { 1, 2 },
	room10 = { 2, 2 },
	room11 = { 3, 2 },
	room12 = { 3, 3 },
	exit = { 2, 3 },
}

local LINKS = {
	{ "hall", "room1" },
	{ "room1", "room2" },
	{ "room2", "room3" },
	{ "room3", "room4" },
	{ "room4", "room5" },
	{ "room5", "room6" },
	{ "room6", "room7" },
	{ "room7", "room8" },
	{ "room8", "room9" },
	{ "room9", "room10" },
	{ "room10", "room11" },
	{ "room11", "room12" },
	{ "room12", "exit" },
}

local REFUGES = {
	refuge1 = { room = "room2", dir = Vector3.new(0, 0, -1) },
	refuge2 = { room = "room5", dir = Vector3.new(0, 0, 1) },
	refuge3 = { room = "room9", dir = Vector3.new(0, 0, 1) },
}

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
	doorways: { [string]: Vector3 },
	hidingSpots: { [string]: { Vector3 } },
	refugeDoors: { [string]: Vector3 },
	taserPedestal: BasePart,
	exitZone: BasePart,
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

local function cellCenter(id: string): Vector3
	local cell = CELLS[id]
	return Vector3.new(cell[1] * PITCH, 0, cell[2] * PITCH)
end

local function linkKey(a: string, b: string): string
	return if a < b then `{a}|{b}` else `{b}|{a}`
end

-- Pared de `length` centrada en `center` a lo largo de `along`, con un hueco central opcional.
local function wall(
	center: Vector3,
	along: Vector3,
	length: number,
	height: number,
	hole: { width: number, bottom: number, top: number }?,
	color: Color3?
)
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
			Color = color or WALL_COLOR,
			Material = Enum.Material.Brick,
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

local function candle(position: Vector3, lightColor: Color3)
	part({
		Name = "Vela",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.1, 0.35, 0.35),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(225, 215, 190),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	local flame = part({
		Name = "Llama",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.3, 0.45, 0.3),
		Position = position + Vector3.new(0, 0.75, 0),
		Color = lightColor,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	})
	flame:AddTag("CandleFlame")
	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Range = 22
	light.Brightness = 1.1
	light.Shadows = true
	light.Parent = flame
end

-- Muebles en las esquinas; cada uno devuelve sus escondites.
local FURNITURE: { (CFrame) -> { Vector3 } } = {
	function(base) -- Ropero, con espacio detrás
		part({
			Name = "Ropero",
			Size = Vector3.new(7, 11, 3.5),
			CFrame = base * CFrame.new(0, 5.5, 0),
			Color = WOOD_COLOR,
			Material = Enum.Material.WoodPlanks,
		})
		return {
			(base * CFrame.new(0, 0.3, 3.2)).Position,
			(base * CFrame.new(-4.4, 0.3, 0)).Position,
		}
	end,
	function(base) -- Mesa con mantel: el escondite queda abajo
		part({
			Name = "Mesa",
			Size = Vector3.new(9, 0.6, 5),
			CFrame = base * CFrame.new(0, 3.3, 0),
			Color = WOOD_COLOR,
			Material = Enum.Material.Wood,
		})
		for _, x in { -4, 4 } do
			for _, z in { -2, 2 } do
				part({
					Name = "Pata",
					Size = Vector3.new(0.5, 3, 0.5),
					CFrame = base * CFrame.new(x, 1.5, z),
					Color = WOOD_COLOR,
				})
			end
		end
		return { (base * CFrame.new(-1, 0.3, 0)).Position, (base * CFrame.new(2, 3.85, 1)).Position }
	end,
	function(base) -- Biblioteca alta con un estante arriba
		part({
			Name = "Biblioteca",
			Size = Vector3.new(10, 9, 2),
			CFrame = base * CFrame.new(0, 4.5, 0),
			Color = WOOD_COLOR,
			Material = Enum.Material.WoodPlanks,
		})
		return {
			(base * CFrame.new(3, 9.3, 0)).Position,
			(base * CFrame.new(-5.8, 0.3, 0.5)).Position,
		}
	end,
	function(base) -- Cama: el escondite queda debajo o entre las sábanas
		part({
			Name = "Cama",
			Size = Vector3.new(6, 1, 10),
			CFrame = base * CFrame.new(0, 2.2, 0),
			Color = Color3.fromRGB(70, 40, 42),
			Material = Enum.Material.Fabric,
		})
		for _, x in { -2.7, 2.7 } do
			for _, z in { -4.7, 4.7 } do
				part({
					Name = "Pata",
					Size = Vector3.new(0.5, 1.7, 0.5),
					CFrame = base * CFrame.new(x, 0.85, z),
					Color = WOOD_COLOR,
				})
			end
		end
		return {
			(base * CFrame.new(0, 0.3, 1)).Position,
			(base * CFrame.new(1.5, 2.95, -3)).Position,
		}
	end,
	function(base) -- Baúl y rincón oscuro
		part({
			Name = "Baul",
			Size = Vector3.new(5, 3, 3),
			CFrame = base * CFrame.new(0, 1.5, 0),
			Color = Color3.fromRGB(44, 30, 20),
			Material = Enum.Material.Wood,
		})
		return {
			(base * CFrame.new(0, 3.3, 0)).Position,
			(base * CFrame.new(3.4, 0.3, 2.4)).Position,
		}
	end,
}

local function buildRoom(
	id: string,
	random: Random,
	openings: { [string]: { width: number, bottom: number, top: number } }
)
	local center = cellCenter(id)
	local half = ROOM_SIZE / 2
	part({
		Name = `Piso_{id}`,
		Size = Vector3.new(ROOM_SIZE, 1, ROOM_SIZE),
		Position = center - Vector3.new(0, 0.5, 0),
		Color = FLOOR_COLOR,
		Material = Enum.Material.WoodPlanks,
	})
	part({
		Name = "Techo",
		Size = Vector3.new(ROOM_SIZE, 1, ROOM_SIZE),
		Position = center + Vector3.new(0, ROOM_HEIGHT + 0.5, 0),
		Color = Color3.fromRGB(26, 20, 18),
		Material = Enum.Material.Wood,
	})
	wall(center + Vector3.new(half, 0, 0), Vector3.zAxis, ROOM_SIZE, ROOM_HEIGHT, openings.E)
	wall(center - Vector3.new(half, 0, 0), Vector3.zAxis, ROOM_SIZE, ROOM_HEIGHT, openings.W)
	wall(center + Vector3.new(0, 0, half), Vector3.xAxis, ROOM_SIZE, ROOM_HEIGHT, openings.S)
	wall(center - Vector3.new(0, 0, half), Vector3.xAxis, ROOM_SIZE, ROOM_HEIGHT, openings.N)

	for _, offset in
		{
			Vector3.new(-9, 0, -half + 1),
			Vector3.new(9, 0, half - 1),
			Vector3.new(-half + 1, 0, 9),
			Vector3.new(half - 1, 0, -9),
		}
	do
		candle(center + offset + Vector3.new(0, 7, 0), CANDLE_LIGHT)
	end

	if id == "hall" or id == "exit" then
		return
	end

	-- Cuatro esquinas con muebles al azar, mirando hacia el centro de la pieza.
	local spots = {}
	local kinds = table.clone(FURNITURE)
	for _, corner in
		{
			Vector3.new(1, 0, 1),
			Vector3.new(-1, 0, 1),
			Vector3.new(1, 0, -1),
			Vector3.new(-1, 0, -1),
		}
	do
		local position = center + corner * 13
		local base = CFrame.lookAt(position, center)
			* CFrame.Angles(0, math.rad(random:NextInteger(-12, 12)), 0)
		local kind = table.remove(kinds, random:NextInteger(1, #kinds)) :: (CFrame) -> { Vector3 }
		for _, spot in kind(base) do
			table.insert(spots, spot)
		end
	end
	refs.hidingSpots[id] = spots
end

local function buildDoor(key: string, position: Vector3, along: Vector3, actionText: string): Door
	local size = if math.abs(along.X) > 0
		then Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, 0.6)
		else Vector3.new(0.6, DOOR_HEIGHT, DOOR_WIDTH)
	local closed = CFrame.new(position + Vector3.new(0, DOOR_HEIGHT / 2, 0))
	local hingeOffset = along * (DOOR_WIDTH / 2)
	local open = CFrame.new(position - hingeOffset + Vector3.new(0, DOOR_HEIGHT / 2, 0))
		* CFrame.Angles(0, math.rad(90), 0)
		* CFrame.new(hingeOffset)
	local visual = part({
		Name = `Puerta_{key}`,
		Size = size,
		CFrame = closed,
		Color = Color3.fromRGB(38, 22, 14),
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	})
	local blocker = part({
		Name = "BloqueoPuerta",
		-- Sella todo el pasillo, que es más ancho y alto que la hoja de la puerta.
		Size = if math.abs(along.X) > 0
			then Vector3.new(CORRIDOR_WIDTH, DOOR_HEIGHT + 2, 0.6)
			else Vector3.new(0.6, DOOR_HEIGHT + 2, CORRIDOR_WIDTH),
		CFrame = CFrame.new(position + Vector3.new(0, (DOOR_HEIGHT + 2) / 2, 0)),
		Transparency = 1,
		CanQuery = false,
		CollisionGroup = "LockedDoor",
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = "Puerta"
	prompt.MaxActivationDistance = Config.InteractRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = visual
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

local function buildLink(a: string, b: string, door: Door?): Door?
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
		Position = middle + Vector3.new(0, DOOR_HEIGHT + 2.5, 0),
		Color = Color3.fromRGB(26, 20, 18),
	})
	for _, side in { -1, 1 } do
		wall(middle + across * side * (CORRIDOR_WIDTH / 2 + 0.5), dir, length, DOOR_HEIGHT + 2)
	end
	candle(middle + across * (CORRIDOR_WIDTH / 2 - 0.5) + Vector3.new(0, 6, 0), CANDLE_LIGHT)
	refs.doorways[linkKey(a, b)] = middle
	return door
end

local function buildRefuge(id: string, room: string, dir: Vector3)
	local mouth = cellCenter(room) + dir * (ROOM_SIZE / 2)
	local center = mouth + dir * (REFUGE_DEPTH / 2)
	local across = Vector3.new(-dir.Z, 0, dir.X)
	local size = Vector3.new(REFUGE_WIDTH, 1, REFUGE_DEPTH)
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
		Position = center + Vector3.new(0, DOOR_HEIGHT + 2.5, 0),
		Color = Color3.fromRGB(20, 22, 30),
	})
	wall(mouth + dir * REFUGE_DEPTH, across, REFUGE_WIDTH, DOOR_HEIGHT + 2)
	for _, side in { -1, 1 } do
		wall(center + across * side * (REFUGE_WIDTH / 2), dir, REFUGE_DEPTH, DOOR_HEIGHT + 2)
	end
	candle(center + across * 10 + Vector3.new(0, 6, 0), REFUGE_LIGHT)
	candle(center - across * 10 + Vector3.new(0, 6, 0), REFUGE_LIGHT)

	-- Barrera que solo frena al asesino.
	part({
		Name = "BarreraAsesino",
		Size = Vector3.new(DOOR_WIDTH + 2, DOOR_HEIGHT + 2, 2),
		CFrame = CFrame.lookAt(
			mouth + Vector3.new(0, (DOOR_HEIGHT + 2) / 2, 0),
			mouth + dir + Vector3.new(0, (DOOR_HEIGHT + 2) / 2, 0)
		),
		Transparency = 1,
		CanQuery = false,
		CollisionGroup = "KillerBarrier",
	})
	refs.rooms[id] = {
		center = center,
		size = Vector3.new(
			math.abs(dir.X) * REFUGE_DEPTH + math.abs(across.X) * REFUGE_WIDTH,
			ROOM_HEIGHT,
			math.abs(dir.Z) * REFUGE_DEPTH + math.abs(across.Z) * REFUGE_WIDTH
		),
	}
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
	part({
		Name = "Terreno",
		Size = Vector3.new(800, 2, 800),
		Position = Vector3.new(90, -3, 90),
		Color = Color3.fromRGB(24, 32, 22),
		Material = Enum.Material.Grass,
	})
	-- Franjas de lluvia alrededor del edificio, visibles por las ventanas.
	local margin = 45
	for _, strip in
		{
			{ Vector3.new(90, 70, -20 - margin), Vector3.new(320, 1, 70) },
			{ Vector3.new(90, 70, 200 + margin), Vector3.new(320, 1, 70) },
			{ Vector3.new(-20 - margin, 70, 90), Vector3.new(70, 1, 220) },
			{ Vector3.new(200 + margin, 70, 90), Vector3.new(70, 1, 220) },
		}
	do
		local cloud = part({
			Name = "Lluvia",
			Size = strip[2],
			Position = strip[1],
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local rain = Instance.new("ParticleEmitter")
		rain.EmissionDirection = Enum.NormalId.Bottom
		rain.Speed = NumberRange.new(90, 110)
		rain.Lifetime = NumberRange.new(0.75)
		rain.Rate = 350
		rain.Size = NumberSequence.new(0.18)
		rain.Squash = NumberSequence.new(4)
		rain.Color = ColorSequence.new(Color3.fromRGB(170, 190, 220))
		rain.Transparency = NumberSequence.new(0.45)
		rain.LightInfluence = 0
		rain.Parent = cloud
	end
end

function Mansion.build(): MansionRefs
	setupCollisionGroups()
	world = Instance.new("Model")
	world.Name = "Mansion"
	refs = {
		rooms = {},
		doors = {},
		doorways = {},
		hidingSpots = {},
		refugeDoors = {},
		taserPedestal = nil :: any,
		exitZone = nil :: any,
	}

	local openings: { [string]: { [string]: { width: number, bottom: number, top: number } } } = {}
	for id in CELLS do
		openings[id] = {}
	end
	local doorHole = { width = DOOR_WIDTH + 2, bottom = 0, top = DOOR_HEIGHT + 2 }
	for _, link in LINKS do
		local dir = (cellCenter(link[2]) - cellCenter(link[1])).Unit
		openings[link[1]][sideOf(dir)] = doorHole
		openings[link[2]][sideOf(-dir)] = doorHole
	end
	for _, refuge in REFUGES do
		openings[refuge.room][sideOf(refuge.dir)] = doorHole
	end
	-- Ventanas en las paredes exteriores que quedan libres.
	local windowHole = { width = 12, bottom = 5, top = 12 }
	local occupied: { [string]: boolean } = {}
	for _, cell in CELLS do
		occupied[`{cell[1]},{cell[2]}`] = true
	end
	local windows = {}
	for id, cell in CELLS do
		for side, delta in { E = { 1, 0 }, W = { -1, 0 }, S = { 0, 1 }, N = { 0, -1 } } do
			if
				not openings[id][side] and not occupied[`{cell[1] + delta[1]},{cell[2] + delta[2]}`]
			then
				openings[id][side] = windowHole
				table.insert(windows, {
					position = cellCenter(id)
						+ Vector3.new(delta[1], 0, delta[2]) * (ROOM_SIZE / 2)
						+ Vector3.new(0, 8.5, 0),
					horizontal = delta[2] ~= 0,
				})
			end
		end
	end

	local random = Random.new()
	for id in CELLS do
		refs.rooms[id] = {
			center = cellCenter(id),
			size = Vector3.new(ROOM_SIZE, ROOM_HEIGHT, ROOM_SIZE),
		}
		buildRoom(id, random, openings[id])
	end

	for _, window in windows do
		part({
			Name = "Ventana",
			Size = if window.horizontal then Vector3.new(12, 7, 0.3) else Vector3.new(0.3, 7, 12),
			Position = window.position,
			Color = Color3.fromRGB(90, 110, 140),
			Material = Enum.Material.Glass,
			Transparency = 0.6,
		})
	end

	for i, link in LINKS do
		buildLink(link[1], link[2])
		-- La primera puerta no lleva llave; las piezas 8 a 12 quedan sin puerta.
		local dir = (cellCenter(link[2]) - cellCenter(link[1])).Unit
		local across = Vector3.new(-dir.Z, 0, dir.X)
		local middle = (cellCenter(link[1]) + cellCenter(link[2])) / 2
		if link[2] == "exit" then
			refs.doors.exit = buildDoor("exit", middle, across, "Abrir salida")
		elseif i >= 2 and i <= 7 then
			refs.doors[link[2]] = buildDoor(link[2], middle, across, "Abrir")
		end
	end

	for id, refuge in REFUGES do
		buildRefuge(id, refuge.room, refuge.dir)
	end

	-- Puerta principal clausurada del hall y aparición en la entrada.
	part({
		Name = "PuertaPrincipal",
		Size = Vector3.new(10, 13, 1.2),
		Position = cellCenter("hall") + Vector3.new(0, 6.5, -ROOM_SIZE / 2 + 1.2),
		Color = Color3.fromRGB(30, 18, 12),
		Material = Enum.Material.WoodPlanks,
	})
	for i = 1, 4 do
		local spawnPoint = Instance.new("SpawnLocation")
		spawnPoint.Anchored = true
		spawnPoint.Neutral = true
		spawnPoint.Duration = 0
		spawnPoint.Enabled = true
		spawnPoint.Transparency = 1
		spawnPoint.CanCollide = false
		spawnPoint.Size = Vector3.new(4, 0.2, 4)
		spawnPoint.Position = cellCenter("hall") + Vector3.new((i - 2.5) * 5, 0.1, -12)
		spawnPoint.Parent = world
	end

	refs.taserPedestal = part({
		Name = "PedestalTaser",
		Size = Vector3.new(3, 3.6, 3),
		Position = cellCenter("hall") + Vector3.new(0, 1.8, 2),
		Color = WOOD_COLOR,
		Material = Enum.Material.Marble,
	})

	refs.exitZone = part({
		Name = "ZonaSalida",
		Size = Vector3.new(30, 12, 30),
		Position = cellCenter("exit") + Vector3.new(0, 6, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})

	buildExterior()
	world.Parent = workspace
	return refs
end

-- Pieza que contiene la posición; nil en pasillos.
function Mansion.roomAt(position: Vector3): string?
	for id, room in refs.rooms do
		local delta = position - room.center
		if math.abs(delta.X) <= room.size.X / 2 and math.abs(delta.Z) <= room.size.Z / 2 then
			return id
		end
	end
	return nil
end

function Mansion.doorway(a: string, b: string): Vector3?
	return refs.doorways[linkKey(a, b)]
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
