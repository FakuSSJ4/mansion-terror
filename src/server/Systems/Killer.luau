--!strict
-- Conecta KillerBrain con el mundo: sentidos, movimiento por el grafo de piezas y golpes.
-- Cada asesino es una instancia con sus datos de Config.Killers y su propio modelo.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Config = require(Shared:WaitForChild("Config"))
local KillerBrain = require(Rules:WaitForChild("KillerBrain"))
local MapDef = require(Rules:WaitForChild("MapDef"))
local MapGraph = require(Rules:WaitForChild("MapGraph"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Taser = require(Rules:WaitForChild("Taser"))

local Systems = script.Parent
local KillerModel = require(Systems:WaitForChild("KillerModel"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))

local TICK = 0.2
-- A esta distancia o menos del asesino empieza a sonar el aviso de peligro.
local DANGER_RANGE = 36
-- Diferencia de altura máxima para considerar que dos están en el mismo piso.
local SAME_FLOOR = 10
local WAYPOINT_REACHED = 5

local Killer = {}

local graph = MapGraph.fromDef(MapDef)
local refs: Mansion.MansionRefs

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

-- Un lugar libre cerca de `center` (a nivel del piso) donde cabe un asesino parado: sin muebles,
-- cuerpos colgados ni paredes encima y con piso debajo. Así nunca aparece atrapado.
function Killer.safeSpot(center: Vector3): Vector3
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, tagged in CollectionService:GetTagged("Killer") do
		table.insert(ignore, tagged)
	end
	params.FilterDescendantsInstances = ignore
	local floorParams = RaycastParams.new()
	floorParams.FilterDescendantsInstances = ignore
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	for radius = 0, 36, 4 do
		local steps = if radius == 0 then 1 else 10
		for step = 0, steps - 1 do
			local angle = step / steps * math.pi * 2
			local at = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local blocked = false
			for _, part in
				workspace:GetPartBoundsInBox(
					CFrame.new(at + Vector3.new(0, 4.6, 0)),
					Vector3.new(5, 7, 5),
					params
				)
			do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				local floor =
					workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), floorParams)
				if floor then
					return Vector3.new(at.X, floor.Position.Y + 4, at.Z)
				end
			end
		end
	end
	return center + Vector3.new(0, 5, 0)
end

local function create(name: string, spec: any, buildModel: () -> KillerModel.Rig): any
	local self: any = { name = name }

	local rig: KillerModel.Rig? = nil
	local brain = KillerBrain.new()
	local active = false
	local currentRoom: string = spec.startRoom
	local patrolRoom: string? = nil
	local passing: { from: string, to: string, points: { Vector3 }, index: number }? = nil
	local needsCenter = false
	local releaseAt: number? = nil
	local baseC0: { [Motor6D]: CFrame } = {}
	local lastAnimate = 0
	local lastHit = 0
	local lastGrowl = 0
	local lastState = "Patrol"
	local stuckAnchor = Vector3.zero
	local stuckFor = 0
	local sparks: ParticleEmitter? = nil
	local swingUntil = 0
	-- En una escena guionada (la fuga) lo mueve la escena, no el cerebro ni animate.
	local scripted = false
	-- Dónde y en qué pieza vio por última vez a su objetivo: si lo pierde de vista (se agachó
	-- detrás de un mueble, salió del cono), va hasta ahí y se rinde en vez de seguirlo a ciegas.
	-- Primer encuentro (Systems/Cinema): sentado en el sillón, con el vaso en la mano y el hacha
	-- escondida. Se guarda qué se ocultó para devolverlo al levantarse.
	local heldGlass: Model? = nil
	local glassMotor: Motor6D? = nil
	local hiddenParts: { [BasePart]: number } = {}
	local sceneConnection: RBXScriptConnection? = nil
	local finishEncounter: (() -> ())? = nil
	local seeingTarget = false
	local lastSeenPosition: Vector3? = nil
	local lastSeenRoom: string? = nil

	-- Puertas abiertas y, si tiene zona propia, solo dentro de ella.
	local function isOpen(a: string, b: string): boolean
		if spec.rooms and not (spec.rooms[a] and spec.rooms[b]) then
			return false
		end
		return Mansion.isLinkOpen(a, b)
	end

	-- Solo le importan los jugadores a los que puede llegar; al modo desarrollador lo ignora.
	local function canReach(player: Player): boolean
		local room = Vitality.getRoom(player)
		return room ~= nil
			and not player:GetAttribute("GodMode")
			and not MapGraph.isRefuge(graph, room)
			and MapGraph.distance(graph, currentRoom, room, isOpen) < math.huge
	end

	-- Sentidos: lo ve si está dentro de su cono de visión y alguna parte del cuerpo tiene línea de
	-- vista (la cabeza asoma sobre los muebles bajos, pero agachado se esconde detrás), escucha a
	-- quien corre cerca y siente a quien tiene pegado, incluso fuera del cono.
	local function senseTarget(position: Vector3, forward: Vector3): Player?
		local current = rig :: KillerModel.Rig
		local best: Player? = nil
		local bestDistance = math.huge
		local cosHalfFov = math.cos(math.rad(Config.KillerFov / 2))
		for _, player in Players:GetPlayers() do
			local root = Vitality.rootOf(player)
			if root and canReach(player) and Vitality.isPlaying(player) then
				local crouching = player:GetAttribute("Crouching") == true
				local offset = root.Position - position
				local distance = offset.Magnitude
				local ignore = { current.model, player.Character :: Model }
				-- Dos puntos del cuerpo: la cintura y la cabeza (más baja si está agachado).
				local head = root.Position + Vector3.new(0, if crouching then 1.2 else 2.3, 0)
				local function visible(): boolean
					return hasLineOfSight(position, root.Position, ignore)
						or hasLineOfSight(position, head, ignore)
				end
				local inCone = distance > 0 and forward:Dot(offset.Unit) >= cosHalfFov
				local seen = distance <= Config.KillerSightRange and inCone and visible()
				-- El oído: correr se oye de lejos y a través de las paredes, caminar apenas de cerca y agachado
				-- o quieto no hace ruido.
				local velocity = root.AssemblyLinearVelocity
				local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1
				local hearRange = if crouching or not moving
					then 0
					elseif player:GetAttribute("Running") == true then Config.KillerHearRange
					else Config.KillerHearWalkRange
				local heard = distance <= hearRange
				local senseRange = if crouching
					then Config.KillerSenseRange * 0.4
					else Config.KillerSenseRange
				local sensed = distance <= senseRange
					and hasLineOfSight(position, root.Position, ignore)
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
			local playing = Vitality.isPlaying(player)
			if
				playing
				and not player:GetAttribute("GodMode")
				and Vitality.rootOf(player)
				and room
				and not MapGraph.isRefuge(graph, room)
			then
				local distance = MapGraph.distance(graph, currentRoom, room, isOpen)
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
		local path = MapGraph.path(graph, currentRoom, dest, isOpen)
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
			for _, room in MapGraph.reachable(graph, currentRoom, isOpen) do
				local eligible = room ~= currentRoom
					and room ~= "hall"
					and room ~= "attic"
					and not MapGraph.isRefuge(graph, room)
				if eligible then
					table.insert(options, room)
				end
			end
			if #options == 0 then
				local fallback = if spec.rooms
					then currentRoom
					elseif currentRoom == "hall" then spec.startRoom
					else "hall"
				table.insert(options, fallback)
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
			if seeingTarget then
				return waypointTo(room, root.Position, position)
			end
			-- Sin verlo: va a donde lo vio por última vez. Si llega y no hay nadie, se rinde.
			local spot, spotRoom = lastSeenPosition, lastSeenRoom
			if not spot or not spotRoom then
				return patrolDestination(position)
			end
			local flat = Vector3.new(spot.X - position.X, 0, spot.Z - position.Z)
			if flat.Magnitude < 4 then
				brain.lostFor = Config.KillerLoseTargetSeconds
				return patrolDestination(position)
			end
			return waypointTo(spotRoom, spot, position)
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

	-- La dificultad de la partida escala la velocidad y el daño de todos los asesinos.
	local function difficulty(): any
		return Config.Difficulties[workspace:GetAttribute("Difficulty")]
			or Config.Difficulties.normal
	end

	local function speedFor(state: KillerBrain.State): number
		local scale = difficulty().speed
		if state == "Chase" then
			return spec.chaseSpeed * scale
		elseif state == "Search" then
			return spec.searchSpeed * scale
		elseif state == "Stunned" then
			return 0
		end
		return spec.patrolSpeed * scale
	end

	-- Ruge (o gruñe, el carnicero) con su propia voz en el espacio.
	local function roar(current: KillerModel.Rig)
		lastGrowl = os.clock()
		local growl = Instance.new("Sound")
		growl.SoundId = if string.find(name, "carnicero") then Sounds.PigGrunt else Sounds.Growl
		growl.Volume = 1.6
		growl.RollOffMinDistance = 15
		growl.RollOffMaxDistance = 110
		growl.Parent = current.root
		growl.Ended:Once(function()
			growl:Destroy()
		end)
		growl:Play()
	end

	local function tryHit(position: Vector3, now: number)
		if brain.state == "Stunned" or now - lastHit < Config.KillerHitCooldown then
			return
		end
		for _, player in Players:GetPlayers() do
			local root = Vitality.rootOf(player)
			-- No pega a través de un mueble: tiene que haber línea de vista a la cintura o la cabeza.
			local character = player.Character
			-- El rayo sale del medio del cuerpo: su propio brazo, el hacha o el machete (y los otros
			-- asesinos) no cuentan como un obstáculo; si no, no pega aunque te tenga pegado.
			local ignore: { Instance } = { character :: Instance }
			for _, killerModel in CollectionService:GetTagged("Killer") do
				table.insert(ignore, killerModel)
			end
			if
				root
				and character
				and canReach(player)
				and Vitality.isPlaying(player)
				and (root.Position - position).Magnitude <= Config.KillerHitRange
				and (
					hasLineOfSight(position, root.Position, ignore)
					or hasLineOfSight(position, root.Position + Vector3.new(0, 1.2, 0), ignore)
				)
			then
				lastHit = now
				swingUntil = now + 0.4
				KillerBrain.registerHit(brain, now, Config)
				Vitality.damage(player, spec.damage * difficulty().damage, position)
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
			local route = if isOpen(currentRoom, nextRoom)
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
				if Vitality.isPlaying(player) then
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
		seeingTarget = visible ~= nil
		local visibleRoot = visible and Vitality.rootOf(visible)
		if visible and visibleRoot then
			lastSeenPosition = visibleRoot.Position
			lastSeenRoom = Vitality.getRoom(visible)
		end
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

		-- Al empezar una persecución ruge (o gruñe, el carnicero), con su propia voz en el espacio.
		if brain.state == "Chase" and lastState ~= "Chase" and now - lastGrowl > 10 then
			roar(current)
		end
		lastState = brain.state

		if sparks then
			sparks.Enabled = brain.state == "Stunned"
		end
		if not KillerBrain.canAct(brain, now) then
			current.humanoid.WalkSpeed = 0
			current.humanoid:MoveTo(position)
			return
		end
		current.humanoid.WalkSpeed = speedFor(brain.state)
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
		if scripted or now - lastAnimate < 0.05 then
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

	local function spawnModel()
		local built = buildModel()
		built.model:PivotTo(CFrame.new(Killer.safeSpot(refs.rooms[spec.startRoom].center)))
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
		glow.Color = built.glowColor
		glow.Range = Config.KillerGlowRange
		glow.Brightness = 0.45
		glow.Shadows = false
		glow.Parent = built.glowPart

		-- El cono de visión se ve: una luz tenue que sale de su frente. Donde hay sombra detrás de un
		-- mueble, no ve.
		local cone = Instance.new("SpotLight")
		cone.Name = "ConoDeVision"
		cone.Color = Color3.fromRGB(255, 120, 100)
		cone.Face = Enum.NormalId.Front
		cone.Angle = Config.KillerFov
		cone.Range = 44
		cone.Brightness = 0.9
		cone.Shadows = true
		cone.Parent = built.root

		baseC0 = {
			[built.leftHip] = built.leftHip.C0,
			[built.rightHip] = built.rightHip.C0,
			[built.shoulder] = built.shoulder.C0,
		}
		rig = built
	end

	function self.restart()
		if rig then
			rig.model:Destroy()
		end
		if sceneConnection then
			sceneConnection:Disconnect()
			sceneConnection = nil
		end
		heldGlass = nil
		glassMotor = nil
		hiddenParts = {}
		finishEncounter = nil
		brain = KillerBrain.new()
		currentRoom = spec.startRoom
		patrolRoom = nil
		passing = nil
		needsCenter = false
		releaseAt = nil
		lastHit = 0
		stuckFor = 0
		active = true
		scripted = false
		seeingTarget = false
		lastSeenPosition = nil
		lastSeenRoom = nil
		spawnModel()
		stuckAnchor = (rig :: KillerModel.Rig).root.Position
	end

	function self.freeze()
		active = false
		if rig then
			rig.humanoid.WalkSpeed = 0
		end
	end

	-- Fuga del jugador: aparece en `from`, espera `delay`, corre hasta `to` y golpea la puerta
	-- cerrada con el hacha cada `strikeEvery` s. `onStrike` avisa cada golpe a la escena.
	function self.escapeScene(
		from: Vector3,
		to: Vector3,
		delay: number,
		speed: number,
		strikeEvery: number,
		onStrike: () -> (),
		floorY: number?
	)
		local current = rig
		if not current then
			return
		end
		active = false
		scripted = true
		passing = nil
		current.humanoid.WalkSpeed = 0
		local direction = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Unit
		-- Con HipHeight = largo de pierna, la raíz queda a pierna + media altura del torso.
		local rootY = (floorY or 0) + 0.1 + current.humanoid.HipHeight + current.root.Size.Y / 2
		local function place(position: Vector3, lean: number, bob: number)
			local at = Vector3.new(position.X, rootY + bob, position.Z)
			current.root.CFrame = CFrame.lookAt(at, at + direction) * CFrame.Angles(lean, 0, 0)
		end
		current.root.Anchored = true
		place(from, 0, 0)
		current.leftHip.C0 = baseC0[current.leftHip]
		current.rightHip.C0 = baseC0[current.rightHip]
		-- Brazo del hacha en alto desde que se queda quieto.
		current.shoulder.C0 = baseC0[current.shoulder] * CFrame.Angles(0.3, 0, 0)

		local distance = (Vector3.new(to.X, 0, to.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
		local startedAt = os.clock()
		local lastStrike = -1
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			if not current.model.Parent or not scripted then
				connection:Disconnect()
				return
			end
			local t = os.clock() - startedAt - delay
			if t < 0 then
				return
			end
			local travelled = t * speed
			if travelled < distance then
				-- Carrera: cuerpo inclinado, paso largo y el hacha al frente.
				local stride = math.sin(t * 15) * 0.9
				current.leftHip.C0 = baseC0[current.leftHip] * CFrame.Angles(stride, 0, 0)
				current.rightHip.C0 = baseC0[current.rightHip] * CFrame.Angles(-stride, 0, 0)
				current.shoulder.C0 = baseC0[current.shoulder]
					* CFrame.Angles(1.3 + math.sin(t * 15) * 0.25, 0, 0)
				local at = from + direction * travelled
				place(at, -0.22, math.abs(math.sin(t * 15)) * 0.35)
				return
			end
			-- Contra la puerta: patas quietas y hachazos ritmados.
			current.leftHip.C0 = baseC0[current.leftHip]
			current.rightHip.C0 = baseC0[current.rightHip]
			local sinceArrival = t - distance / speed
			local strike = math.floor(sinceArrival / strikeEvery)
			local phase = (sinceArrival % strikeEvery) / strikeEvery
			-- Sube lento (0 a 0.6) y cae rápido (0.6 a 1).
			local raise = if phase < 0.6 then phase / 0.6 else 1 - (phase - 0.6) / 0.4
			current.shoulder.C0 = baseC0[current.shoulder] * CFrame.Angles(0.4 + raise * 2.3, 0, 0)
			local lunge = if phase > 0.6 then 0.5 * (phase - 0.6) / 0.4 else 0
			place(to, -0.1 - lunge * 0.3, 0)
			current.root.CFrame = current.root.CFrame * CFrame.new(0, 0, -lunge)
			if phase > 0.6 and strike > lastStrike then
				lastStrike = strike
				onStrike()
			end
		end)
	end

	local SIT_LEGS = math.rad(72)

	local function ease(alpha: number): number
		local a = math.clamp(alpha, 0, 1)
		return a * a * (3 - 2 * a)
	end

	-- Brazo del vaso: `raise` 0 lo deja apoyado sobre el muslo y 1 lo lleva a la boca; `tilt` inclina
	-- el vaso hacia la cara. El vaso se contrarrota para quedar derecho mientras sube el brazo.
	local function holdGlass(current: KillerModel.Rig, raise: number, tilt: number)
		local turn = CFrame.Angles(0.9 + raise * 1.4, 0, 0.15 + raise * 0.45)
		current.shoulder.C0 = baseC0[current.shoulder] * turn
		if glassMotor then
			-- Un poco más allá de la punta del brazo: si no, queda metido adentro y no se ve.
			glassMotor.C0 = CFrame.new(0, -1.6, -0.2) * turn:Inverse() * CFrame.Angles(tilt, 0, 0)
		end
	end

	-- Primer encuentro: sentado en el sillón mirando la película, con el whisky en la mano. Su
	-- hacha queda oculta (la que se ve es la apoyada contra el sillón) hasta que se levanta.
	function self.sit(seat: CFrame, glassTemplate: Model)
		local current = rig
		if not current then
			return
		end
		active = false
		scripted = true
		passing = nil
		current.humanoid.WalkSpeed = 0
		current.root.Anchored = true
		current.root.CFrame = seat * CFrame.new(0, 0.5 + current.root.Size.Y / 2, 0)
		for _, hip in { current.leftHip, current.rightHip } do
			hip.C0 = baseC0[hip] * CFrame.Angles(SIT_LEGS, 0, 0)
		end
		hiddenParts = {}
		for _, item in current.model:GetChildren() do
			if
				item:IsA("BasePart")
				and (string.find(item.Name, "Hacha") ~= nil or item.Name == "Empunadura")
			then
				hiddenParts[item] = item.Transparency
				-- Con sus manchas, que cuelgan de la pieza.
				for _, joint in item:GetChildren() do
					if joint:IsA("Motor6D") and joint.Part1 then
						hiddenParts[joint.Part1] = joint.Part1.Transparency
					end
				end
			end
		end
		for item in hiddenParts do
			item.Transparency = 1
		end

		local held = glassTemplate:Clone()
		-- Más grande que el de la mesa: en su mano tiene que verse desde la cámara.
		held:ScaleTo(1.1)
		local centre = held.PrimaryPart :: BasePart
		for _, item in held:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = false
				item.Massless = true
				item.CanCollide = false
				item.CanTouch = false
				if item ~= centre then
					-- Weld con el desfase escrito a mano: un WeldConstraint armado fuera del mundo
					-- no sigue al centro y las piezas se quedan atrás.
					local weld = Instance.new("Weld")
					weld.Part0 = centre
					weld.Part1 = item
					weld.C0 = centre.CFrame:ToObjectSpace(item.CFrame)
					weld.Parent = item
				end
			end
		end
		local hand = current.shoulder.Part1 :: BasePart
		local motor = Instance.new("Motor6D")
		motor.Part0 = hand
		motor.Part1 = centre
		motor.Parent = hand
		held.Parent = current.model
		heldGlass = held
		glassMotor = motor
		holdGlass(current, 0, 0)
	end

	-- La escena: respira mirando la película, toma un trago largo, gira hacia `watcher`, deja el vaso,
	-- se para en `stand`, levanta el hacha y ruge. Al terminar sale a cazar (con un segundo de
	-- ventaja para los jugadores). `onGlassDown` avisa cuando el vaso pasa a la mesa.
	function self.encounter(
		watcher: Vector3,
		stand: Vector3,
		floorY: number,
		onGlassDown: () -> (),
		onDone: () -> ()
	)
		local current = rig
		if not current or not scripted or not heldGlass then
			onDone()
			return
		end
		local timing = Config.Cinema
		local seated = current.root.CFrame
		local flat = Vector3.new(watcher.X - seated.Position.X, 0, watcher.Z - seated.Position.Z)
		local yaw = 0
		if flat.Magnitude > 0.1 then
			local look = seated.LookVector
			yaw = math.clamp(math.atan2(look:Cross(flat.Unit).Y, look:Dot(flat.Unit)), -0.7, 0.7)
		end
		local standY = floorY + 0.1 + current.humanoid.HipHeight + current.root.Size.Y / 2
		local standAt = Vector3.new(stand.X, standY, stand.Z)
		local facing = Vector3.new(watcher.X, standY, watcher.Z)
		local standing = if (facing - standAt).Magnitude > 0.1
			then CFrame.lookAt(standAt, facing)
			else CFrame.new(standAt) * seated.Rotation

		local glassDown = false
		local roared = false
		local function putDown()
			if glassDown then
				return
			end
			glassDown = true
			if heldGlass then
				heldGlass:Destroy()
			end
			heldGlass = nil
			glassMotor = nil
			for item, transparency in hiddenParts do
				item.Transparency = transparency
			end
			hiddenParts = {}
			onGlassDown()
		end
		local function finish()
			if finishEncounter == nil then
				return
			end
			finishEncounter = nil
			if sceneConnection then
				sceneConnection:Disconnect()
				sceneConnection = nil
			end
			putDown()
			current.leftHip.C0 = baseC0[current.leftHip]
			current.rightHip.C0 = baseC0[current.rightHip]
			current.shoulder.C0 = baseC0[current.shoulder]
			current.root.CFrame = standing
			current.root.Anchored = false
			-- Si no, el Humanoide queda "sentado" en el piso, sin altura de cadera: no camina y se hunde.
			current.humanoid.Sit = false
			current.humanoid.PlatformStand = false
			current.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			scripted = false
			active = true
			releaseAt = os.clock() + 1
			onDone()
		end
		finishEncounter = finish

		local startedAt = os.clock()
		sceneConnection = RunService.Heartbeat:Connect(function()
			if not current.model.Parent then
				finish()
				return
			end
			local t = os.clock() - startedAt
			if t >= timing.seconds then
				finish()
				return
			end
			if t < timing.standAt then
				-- Un trago largo: sube el vaso, lo inclina, lo sostiene y lo baja.
				local drink = t - timing.drinkAt
				local raise = if drink < 0
					then 0
					elseif drink < 1.2 then ease(drink / 1.2)
					elseif drink < 2 then 1
					else 1 - ease((drink - 2) / 0.8)
				holdGlass(current, raise, raise * raise * 0.9)
				local turn = yaw * ease((t - timing.turnAt) / 0.9)
				current.root.CFrame = seated
					* CFrame.Angles(0, turn, 0)
					* CFrame.new(0, math.sin(t * 1.6) * 0.03, 0)
				return
			end
			putDown()
			local u = ease((t - timing.standAt) / (timing.roarAt - timing.standAt))
			current.root.CFrame = (seated * CFrame.Angles(0, yaw, 0)):Lerp(standing, u)
			for _, hip in { current.leftHip, current.rightHip } do
				hip.C0 = baseC0[hip] * CFrame.Angles(SIT_LEGS * (1 - u), 0, 0)
			end
			-- El hacha sube y queda en alto para el rugido.
			local lift = ease((t - timing.roarAt + 0.5) / 0.6)
			current.shoulder.C0 = baseC0[current.shoulder] * CFrame.Angles(0.3 + lift * 2, 0, 0)
			if t >= timing.roarAt and not roared then
				roared = true
				roar(current)
			end
		end)
	end

	-- Corta la escena: queda parado y sale a cazar enseguida.
	function self.skipEncounter()
		if finishEncounter then
			finishEncounter()
		end
	end

	-- Solo para QA: a quién ve ahora, con los mismos sentidos que usa de verdad.
	function self.debugSense(): Player?
		local current = rig
		if not current then
			return nil
		end
		return senseTarget(current.root.Position, current.root.CFrame.LookVector)
	end

	function self.debugPlace(position: Vector3, lookAt: Vector3)
		if rig then
			passing = nil
			rig.root.CFrame = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
		end
	end

	function self.dropTarget(player: Player)
		KillerBrain.dropTarget(brain, player.Name)
	end

	function self.update(now: number)
		if rig then
			animate(rig, now)
		end
	end
	self.tick = tick

	function self.getPosition(): Vector3?
		return if rig then rig.root.Position else nil
	end

	function self.isVisibleFrom(player: Player, range: number): boolean
		local root = Vitality.rootOf(player)
		local current = rig
		if not root or not current then
			return false
		end
		if (root.Position - current.root.Position).Magnitude > range then
			return false
		end
		return hasLineOfSight(
			root.Position,
			current.root.Position,
			{ current.model, player.Character :: Model }
		)
	end

	function self.stun(now: number): boolean
		if not active or not Taser.canStun(brain, now) then
			return false
		end
		Taser.applyStun(brain, now, Config)
		return true
	end

	function self.debugStatus(): string
		local position = self.getPosition()
		local anchored = if rig then rig.root.Anchored else false
		local glass = if heldGlass then "en la mano" else "sin vaso"
		return `{name}: estado={brain.state} objetivo={brain.target} pieza={currentRoom} pos={position} lejos={brain.farFor} anclado={anchored} escena={scripted} activo={active} vaso={glass}`
	end

	function self.debugTeleport(position: Vector3)
		if rig then
			passing = nil
			rig.root.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
		end
	end

	return self
end

local killers: { any } = {}

-- El asesino más cercano que el jugador tiene a tiro.
function Killer.inRange(player: Player, range: number): any?
	local root = Vitality.rootOf(player)
	if not root then
		return nil
	end
	local best: any = nil
	local bestDistance = math.huge
	for _, killer in killers do
		local position = killer.getPosition()
		if position and killer.isVisibleFrom(player, range) then
			local distance = (position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = killer, distance
			end
		end
	end
	return best
end

-- Solo para los atajos de QA.
function Killer.debugStatus(): string
	local lines = {}
	for _, killer in killers do
		table.insert(lines, killer.debugStatus())
	end
	return table.concat(lines, " | ")
end

-- Escena de la fuga con el asesino principal.
function Killer.playEscape(
	from: Vector3,
	to: Vector3,
	delay: number,
	speed: number,
	strikeEvery: number,
	onStrike: () -> (),
	floorY: number?
)
	killers[1].escapeScene(from, to, delay, speed, strikeEvery, onStrike, floorY)
end

-- Primer encuentro con el asesino principal (ver Systems/Cinema).
function Killer.sitMain(seat: CFrame, glassTemplate: Model)
	killers[1].sit(seat, glassTemplate)
end

function Killer.encounterMain(
	watcher: Vector3,
	stand: Vector3,
	floorY: number,
	onGlassDown: () -> (),
	onDone: () -> ()
)
	killers[1].encounter(watcher, stand, floorY, onGlassDown, onDone)
end

function Killer.skipEncounter()
	killers[1].skipEncounter()
end

function Killer.debugSense(index: number): Player?
	return killers[index].debugSense()
end

function Killer.debugPlace(index: number, position: Vector3, lookAt: Vector3)
	killers[index].debugPlace(position, lookAt)
end

function Killer.debugTeleport(index: number, position: Vector3)
	killers[index].debugTeleport(position)
end

function Killer.start(mansionRefs: Mansion.MansionRefs)
	refs = mansionRefs
	killers = {
		create("asesino", Config.Killers.main, KillerModel.build),
		create("smoking", Config.Killers.gentleman, KillerModel.buildGentleman),
		create("carnicero", Config.Killers.butcher, KillerModel.buildButcher),
		create("carnicero2", Config.Killers.butcher2, KillerModel.buildButcher),
	}

	local function forEach(action: (any) -> ())
		for _, killer in killers do
			action(killer)
		end
	end
	forEach(function(killer)
		killer.restart()
	end)

	Round.Reset:Connect(function()
		forEach(function(killer)
			killer.restart()
		end)
	end)
	local function freezeAll()
		forEach(function(killer)
			killer.freeze()
		end)
	end
	Round.Escaping:Connect(freezeAll)
	Round.Won:Connect(freezeAll)
	Round.Lost:Connect(freezeAll)

	local function forget(player: Player)
		forEach(function(killer)
			killer.dropTarget(player)
		end)
	end
	Vitality.Died:Connect(forget)
	Players.PlayerRemoving:Connect(forget)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		forEach(function(killer)
			killer.update(now)
		end)
		elapsed += dt
		if elapsed >= TICK then
			elapsed = 0
			forEach(function(killer)
				killer.tick(now)
			end)
			-- Aviso de peligro para el cliente: 0 lejos, 1 pegado al asesino más cercano.
			for _, player in Players:GetPlayers() do
				local root = Vitality.rootOf(player)
				local danger = 0
				if root and Vitality.isPlaying(player) then
					local nearest = math.huge
					for _, killer in killers do
						local position = killer.getPosition()
						-- Solo cuenta el que está en tu piso: uno arriba o abajo confunde (los pisos
						-- están a 20 studs).
						if position and math.abs(position.Y - root.Position.Y) < SAME_FLOOR then
							nearest = math.min(nearest, (position - root.Position).Magnitude)
						end
					end
					danger = math.clamp(1 - nearest / DANGER_RANGE, 0, 1)
				end
				danger = math.floor(danger * 10) / 10
				if player:GetAttribute("Danger") ~= danger then
					player:SetAttribute("Danger", danger)
				end
			end
		end
	end)
end

return Killer
