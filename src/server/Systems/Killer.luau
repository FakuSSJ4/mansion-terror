--!strict
-- Conecta KillerBrain con el mundo: sentidos, movimiento por el grafo de piezas y golpes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Config = require(Shared:WaitForChild("Config"))
local KillerBrain = require(Rules:WaitForChild("KillerBrain"))
local MapGraph = require(Rules:WaitForChild("MapGraph"))
local Taser = require(Rules:WaitForChild("Taser"))

local Systems = script.Parent
local KillerModel = require(Systems:WaitForChild("KillerModel"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local TICK = 0.2
local DOOR_SWING_DISTANCE = 12
local WAYPOINT_REACHED = 5

local Killer = {}

local graph = MapGraph.default()
local refs: Mansion.MansionRefs
local rig: KillerModel.Rig?
local brain = KillerBrain.new()
local active = false
local currentRoom = Config.KillerStartRoom
local patrolRoom: string? = nil
local passing: { from: string, to: string, through: boolean }? = nil
local needsCenter = false
local baseC0: { [Motor6D]: CFrame } = {}
local lastAnimate = 0
local lastHit = 0
local stuckAnchor = Vector3.zero
local stuckFor = 0
local sparks: ParticleEmitter? = nil
local swingUntil = 0

local function playerById(id: string?): Player?
	return if id then Players:FindFirstChild(id) :: Player? else nil
end

local function inRefuge(player: Player): boolean
	local room = Vitality.getRoom(player)
	return room ~= nil and MapGraph.isRefuge(graph, room)
end

local function hasLineOfSight(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	-- Con este grupo el rayo ignora la barrera invisible de los refugios.
	params.CollisionGroup = "Default"
	return workspace:Raycast(from, to - from, params) == nil
end

function Killer.getPosition(): Vector3?
	return if rig then rig.root.Position else nil
end

function Killer.isVisibleFrom(player: Player, range: number): boolean
	local root = Vitality.rootOf(player)
	local current = rig
	if not root or not current or (root.Position - current.root.Position).Magnitude > range then
		return false
	end
	return hasLineOfSight(
		root.Position,
		current.root.Position,
		{ current.model, player.Character :: Model }
	)
end

-- Sentidos: lo ve de frente con línea de vista, o escucha a quien corre cerca.
local function senseTarget(position: Vector3, forward: Vector3): Player?
	local current = rig :: KillerModel.Rig
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local root = Vitality.rootOf(player)
		if root and not inRefuge(player) then
			local offset = root.Position - position
			local distance = offset.Magnitude
			local inFront = distance > 0 and forward:Dot(offset.Unit) > 0
			local seen = distance <= Config.KillerSightRange
				and inFront
				and hasLineOfSight(
					position,
					root.Position,
					{ current.model, player.Character :: Model }
				)
			local heard = distance <= Config.KillerHearRange
				and player:GetAttribute("Running") == true
			local sensed = distance <= Config.KillerSenseRange
				and hasLineOfSight(
					position,
					root.Position,
					{ current.model, player.Character :: Model }
				)
			if (seen or heard or sensed) and distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

local function nearestPlayer(): (Player?, number?)
	local best: Player? = nil
	local bestDistance: number? = nil
	for _, player in Players:GetPlayers() do
		local room = Vitality.getRoom(player)
		if Vitality.rootOf(player) and room and not MapGraph.isRefuge(graph, room) then
			local distance = MapGraph.distance(graph, currentRoom, room)
			if not bestDistance or distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

local function refugeCamper(): Player?
	for _, player in Players:GetPlayers() do
		if Vitality.rootOf(player) and inRefuge(player) then
			return player
		end
	end
	return nil
end

-- Próximo punto para llegar a `dest`, avanzando de a una pieza por el grafo.
local function waypointTo(dest: string, finalPoint: Vector3, position: Vector3): Vector3
	if passing then
		if currentRoom == passing.to then
			passing = nil
			needsCenter = true
		else
			local doorway = Mansion.doorway(passing.from, passing.to) :: Vector3
			local flat = Vector3.new(doorway.X - position.X, 0, doorway.Z - position.Z)
			if
				flat.Magnitude > WAYPOINT_REACHED
				and currentRoom == passing.from
				and not passing.through
			then
				return doorway
			end
			passing.through = true
			return refs.rooms[passing.to].center
		end
	end
	if currentRoom == dest then
		needsCenter = false
		return finalPoint
	end
	-- Pasa por el centro de la pieza para no cortar en diagonal por los muebles.
	if needsCenter then
		local center = refs.rooms[currentRoom].center
		local toCenter = Vector3.new(center.X - position.X, 0, center.Z - position.Z)
		if toCenter.Magnitude > WAYPOINT_REACHED then
			return center
		end
		needsCenter = false
	end
	local path = MapGraph.path(graph, currentRoom, dest)
	if #path < 2 or MapGraph.isRefuge(graph, path[2]) then
		return refs.rooms[currentRoom].center
	end
	passing = { from = currentRoom, to = path[2], through = false }
	return Mansion.doorway(currentRoom, path[2]) :: Vector3
end

local function patrolDestination(position: Vector3): Vector3
	if not patrolRoom or patrolRoom == currentRoom then
		local n = math.random(1, 12)
		patrolRoom = `room{n}`
	end
	local dest = patrolRoom :: string
	return waypointTo(dest, refs.rooms[dest].center, position)
end

local function destination(position: Vector3): Vector3?
	local state = brain.state
	if state == "Stunned" then
		return nil
	elseif state == "Chase" then
		local target = playerById(brain.target)
		local root = target and Vitality.rootOf(target)
		local room = target and Vitality.getRoom(target)
		if not target or not root or not room then
			return patrolDestination(position)
		end
		if MapGraph.isRefuge(graph, room) then
			local neighbor = MapGraph.path(graph, room, currentRoom)[2]
			return waypointTo(neighbor or currentRoom, refs.refugeDoors[room], position)
		end
		return waypointTo(room, root.Position, position)
	elseif state == "Search" then
		local target = nearestPlayer()
		local room = target and Vitality.getRoom(target)
		local root = target and Vitality.rootOf(target)
		if not room or not root then
			return patrolDestination(position)
		end
		return waypointTo(room, root.Position, position)
	elseif state == "Stalk" then
		local target = playerById(brain.target)
		local room = target and Vitality.getRoom(target)
		if not room or not MapGraph.isRefuge(graph, room) then
			return patrolDestination(position)
		end
		local neighbor = MapGraph.path(graph, room, currentRoom)[2]
		return waypointTo(neighbor or currentRoom, refs.refugeDoors[room], position)
	end
	return patrolDestination(position)
end

local function speedFor(state: KillerBrain.State): number
	if state == "Chase" then
		return Config.KillerChaseSpeed
	elseif state == "Search" then
		return Config.KillerSearchSpeed
	elseif state == "Stalk" then
		return Config.KillerStalkSpeed
	elseif state == "Stunned" then
		return 0
	end
	return Config.KillerPatrolSpeed
end

local function tryHit(position: Vector3, now: number)
	if brain.state == "Stunned" or now - lastHit < Config.KillerHitCooldown then
		return
	end
	for _, player in Players:GetPlayers() do
		local root = Vitality.rootOf(player)
		if
			root
			and not inRefuge(player)
			and (root.Position - position).Magnitude <= Config.KillerHitRange
		then
			lastHit = now
			swingUntil = now + 0.4
			Vitality.damage(player, Config.KillerDamage)
			return
		end
	end
end

local function updateDoors(position: Vector3)
	for _, door in refs.doors do
		if not door.unlocked then
			local near = (door.closedCFrame.Position - position).Magnitude <= DOOR_SWING_DISTANCE
			Mansion.swingDoor(door, near)
		end
	end
end

-- Si quedó trabado, reaparece en una puerta vecina donde no haya jugadores.
local function checkStuck(current: KillerModel.Rig, position: Vector3)
	local holding = brain.state == "Stunned" or brain.state == "Stalk"
	if holding or (position - stuckAnchor).Magnitude > 1.5 then
		stuckAnchor = position
		stuckFor = 0
		return
	end
	stuckFor += TICK
	if stuckFor < Config.KillerStuckSeconds then
		return
	end
	stuckFor = 0
	passing = nil
	for _, nextRoom in graph.neighbors[currentRoom] do
		local doorway = Mansion.doorway(currentRoom, nextRoom)
		if doorway then
			local watched = false
			for _, player in Players:GetPlayers() do
				local room = Vitality.getRoom(player)
				watched = watched or room == currentRoom or room == nextRoom
			end
			if not watched then
				current.root.CFrame = CFrame.new(doorway + Vector3.new(0, 4, 0))
				return
			end
		end
	end
end

local function tick(now: number)
	local current = rig
	if not current or not active then
		return
	end
	brain.clock = now
	local position = current.root.Position
	currentRoom = Mansion.roomAt(position) or currentRoom

	local _, minDistance = nearestPlayer()
	local visible = senseTarget(position, current.root.CFrame.LookVector)
	local camper = refugeCamper()
	KillerBrain.step(brain, {
		now = now,
		dt = TICK,
		visibleTarget = visible and visible.Name,
		minRoomDistance = minDistance,
		refugeCamper = camper and camper.Name,
	}, Config)

	current.humanoid.WalkSpeed = speedFor(brain.state)
	if sparks then
		sparks.Enabled = brain.state == "Stunned"
	end
	local point = destination(position)
	local seenRoot = visible and Vitality.rootOf(visible)
	if seenRoot and brain.state == "Chase" then
		passing = nil
		current.humanoid:MoveTo(seenRoot.Position)
	elseif point then
		current.humanoid:MoveTo(point)
	else
		current.humanoid:MoveTo(position)
	end

	tryHit(position, now)
	updateDoors(position)
	checkStuck(current, position)
end

local function animate(current: KillerModel.Rig, now: number)
	-- Se anima con C0 porque Transform no replica a los clientes.
	if now - lastAnimate < 0.05 then
		return
	end
	lastAnimate = now
	local speed = current.root.AssemblyLinearVelocity.Magnitude
	local stride = if speed > 1 then math.sin(now * (4 + speed * 0.5)) * 0.65 else 0
	local swing = if now < swingUntil then 2.2 else 0.25 + stride * 0.2
	current.leftHip.C0 = baseC0[current.leftHip] * CFrame.Angles(stride, 0, 0)
	current.rightHip.C0 = baseC0[current.rightHip] * CFrame.Angles(-stride, 0, 0)
	current.shoulder.C0 = baseC0[current.shoulder] * CFrame.Angles(swing, 0, 0)
end

local function spawnKiller()
	local built = KillerModel.build()
	built.model:PivotTo(
		CFrame.new(refs.rooms[Config.KillerStartRoom].center + Vector3.new(0, 5, 0))
	)
	built.model.Parent = workspace
	built.root:SetNetworkOwner(nil)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 60
	emitter.Lifetime = NumberRange.new(0.15, 0.35)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.2)
	emitter.Color = ColorSequence.new(Color3.fromRGB(160, 210, 255))
	emitter.LightInfluence = 0
	emitter.Enabled = false
	emitter.Parent = built.root
	sparks = emitter

	-- Resplandor tenue para que se le distinga la cara en la oscuridad.
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 140, 110)
	glow.Range = Config.KillerGlowRange
	glow.Brightness = 0.45
	glow.Shadows = false
	glow.Parent = built.model:FindFirstChild("Corte") :: BasePart

	baseC0 = {
		[built.leftHip] = built.leftHip.C0,
		[built.rightHip] = built.rightHip.C0,
		[built.shoulder] = built.shoulder.C0,
	}
	rig = built
end

local function restart()
	if rig then
		rig.model:Destroy()
	end
	brain = KillerBrain.new()
	currentRoom = Config.KillerStartRoom
	patrolRoom = nil
	passing = nil
	needsCenter = false
	lastHit = 0
	stuckFor = 0
	active = true
	spawnKiller()
	stuckAnchor = (rig :: KillerModel.Rig).root.Position
end

-- Solo para los atajos de QA.
function Killer.debugStatus(): string
	local position = Killer.getPosition()
	return `estado={brain.state} objetivo={brain.target} pieza={currentRoom} pos={position} lejos={brain.farFor}`
end

function Killer.debugTeleport(position: Vector3)
	if rig then
		passing = nil
		rig.root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	end
end

function Killer.stun(now: number): boolean
	if not active or not Taser.canStun(brain, now) then
		return false
	end
	Taser.applyStun(brain, now, Config)
	return true
end

function Killer.start(mansionRefs: Mansion.MansionRefs)
	refs = mansionRefs
	restart()

	Round.Reset:Connect(restart)
	Round.Won:Connect(function()
		active = false
		if rig then
			rig.humanoid.WalkSpeed = 0
		end
	end)

	Vitality.Died:Connect(function(player: Player)
		KillerBrain.dropTarget(brain, player.Name)
	end)
	Players.PlayerRemoving:Connect(function(player)
		KillerBrain.dropTarget(brain, player.Name)
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		if rig then
			animate(rig, now)
		end
		elapsed += dt
		if elapsed >= TICK then
			elapsed = 0
			tick(now)
		end
	end)
end

return Killer
