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
local WAYPOINT_REACHED = 5

local Killer = {}

local graph = MapGraph.default()
local refs: Mansion.MansionRefs
local rig: KillerModel.Rig?
local brain = KillerBrain.new()
local active = false
local currentRoom = Config.KillerStartRoom
local patrolRoom: string? = nil
local passing: { from: string, to: string, points: { Vector3 }, index: number }? = nil
local needsCenter = false
local releaseAt: number? = nil
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

-- Solo le importan los jugadores a los que puede llegar por puertas abiertas.
local function canReach(player: Player): boolean
	local room = Vitality.getRoom(player)
	return room ~= nil
		and not MapGraph.isRefuge(graph, room)
		and MapGraph.distance(graph, currentRoom, room, Mansion.isLinkOpen) < math.huge
end

-- Sentidos: lo ve de frente con línea de vista, o escucha a quien corre cerca.
local function senseTarget(position: Vector3, forward: Vector3): Player?
	local current = rig :: KillerModel.Rig
	local best: Player? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local root = Vitality.rootOf(player)
		if root and canReach(player) and not player:GetAttribute("InTutorial") then
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
		local playing = not player:GetAttribute("InTutorial")
		if playing and Vitality.rootOf(player) and room and not MapGraph.isRefuge(graph, room) then
			local distance = MapGraph.distance(graph, currentRoom, room, Mansion.isLinkOpen)
			if distance < math.huge and (not bestDistance or distance < bestDistance) then
				best, bestDistance = player, distance
			end
		end
	end
	return best, bestDistance
end

-- Próximo punto para llegar a `dest`, avanzando de a una pieza por el grafo.
local function waypointTo(dest: string, finalPoint: Vector3, position: Vector3): Vector3
	if passing then
		local point = passing.points[passing.index]
		local flat = Vector3.new(point.X - position.X, 0, point.Z - position.Z)
		if flat.Magnitude > WAYPOINT_REACHED then
			return point
		end
		passing.index += 1
		if passing.index <= #passing.points then
			return passing.points[passing.index]
		end
		-- Fin del recorrido; la trampilla del altillo se cruza apareciendo del otro lado.
		if Mansion.isHatch(passing.from, passing.to) and rig then
			rig.root.CFrame = CFrame.new(refs.rooms[passing.to].center + Vector3.new(0, 4, 0))
			currentRoom = passing.to
		end
		passing = nil
		needsCenter = true
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
	local path = MapGraph.path(graph, currentRoom, dest, Mansion.isLinkOpen)
	if #path < 2 or MapGraph.isRefuge(graph, path[2]) then
		return refs.rooms[currentRoom].center
	end
	local points = Mansion.route(currentRoom, path[2]) :: { Vector3 }
	passing = { from = currentRoom, to = path[2], points = points, index = 1 }
	return points[1]
end

local function patrolDestination(position: Vector3): Vector3
	if not patrolRoom or patrolRoom == currentRoom then
		-- Patrulla lo que ya está abierto; el hall solo cuenta si no hay otra pieza adonde ir.
		local options = {}
		for _, room in MapGraph.reachable(graph, currentRoom, Mansion.isLinkOpen) do
			local eligible = room ~= currentRoom
				and room ~= "hall"
				and room ~= "attic"
				and not MapGraph.isRefuge(graph, room)
			if eligible then
				table.insert(options, room)
			end
		end
		if #options == 0 then
			table.insert(options, if currentRoom == "hall" then Config.KillerStartRoom else "hall")
		end
		patrolRoom = options[math.random(1, #options)]
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
		return waypointTo(room, root.Position, position)
	elseif state == "Search" then
		local target = nearestPlayer()
		local room = target and Vitality.getRoom(target)
		local root = target and Vitality.rootOf(target)
		if not room or not root then
			return patrolDestination(position)
		end
		return waypointTo(room, root.Position, position)
	end
	return patrolDestination(position)
end

local function speedFor(state: KillerBrain.State): number
	if state == "Chase" then
		return Config.KillerChaseSpeed
	elseif state == "Search" then
		return Config.KillerSearchSpeed
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
			and canReach(player)
			and (root.Position - position).Magnitude <= Config.KillerHitRange
		then
			lastHit = now
			swingUntil = now + 0.4
			Vitality.damage(player, Config.KillerDamage)
			return
		end
	end
end

-- Si quedó trabado, reaparece en una puerta vecina donde no haya jugadores.
local function checkStuck(current: KillerModel.Rig, position: Vector3)
	if brain.state == "Stunned" or (position - stuckAnchor).Magnitude > 1.5 then
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
		local route = if Mansion.isLinkOpen(currentRoom, nextRoom)
			then Mansion.route(currentRoom, nextRoom)
			else nil
		local doorway = route and route[1]
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
	-- La gracia corre desde que alguien empieza a jugar: mientras tanto se queda quieto.
	if not releaseAt then
		for _, player in Players:GetPlayers() do
			if not player:GetAttribute("InTutorial") then
				releaseAt = now + Config.KillerGraceSeconds
				break
			end
		end
	end
	if not releaseAt or now < releaseAt then
		return
	end
	brain.clock = now
	local position = current.root.Position
	currentRoom = Mansion.roomAt(position) or currentRoom

	local _, minDistance = nearestPlayer()
	local visible = senseTarget(position, current.root.CFrame.LookVector)
	-- Si el objetivo se metió en un refugio, lo abandona y sigue de largo.
	local chased = playerById(brain.target)
	if chased and inRefuge(chased) then
		KillerBrain.dropTarget(brain, chased.Name)
		patrolRoom = nil
	end
	KillerBrain.step(brain, {
		now = now,
		dt = TICK,
		visibleTarget = visible and visible.Name,
		minRoomDistance = minDistance,
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
	releaseAt = nil
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
	local function freeze()
		active = false
		if rig then
			rig.humanoid.WalkSpeed = 0
		end
	end
	Round.Won:Connect(freeze)
	Round.Lost:Connect(freeze)

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
