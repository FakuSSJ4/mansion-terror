--!strict
-- La película que mira el asesino del living: una escena 3D (con los mismos carniceros del juego) filmada
-- por una cámara y mostrada en un ViewportFrame, en blanco y negro:
--  0 a 6 s     primer plano de un chancho que agarra la cámara con las dos manos, la mira fijo y la
--              acomoda hasta dejarla firme apuntando al sótano.
--  6 a 25 s    el sótano: entra un chancho arrastrando a una persona y la sienta en una silla; la tortura
--              queda sugerida con la sombra enorme de un chancho con un cuchillón en la pared, la
--              lámpara que se apaga y cortes a negro. Después traen a otra.
--  25 a 31 s   el chancho vuelve, se acerca a la cámara, la mira y la tapa con la mano.
-- Nada de sangre ni heridas: todo es siluetas, sombras y lo que no se ve.
-- El grano, las rayas y el parpadeo los pone `Projector` encima.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillerModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KillerModel"))

local Footage = {}

local LOOP = 34
-- Dónde está cada escenario dentro del mundo del ViewportFrame.
local CLOSE = Vector3.new(200, 0, 0)
local CHAIR_X = 2
local TABLE_X = -9
local LANE_Z = -6.5
local PIG_ROOT_Y = 3

local function grey(value: number): Color3
	return Color3.fromRGB(value, value, value)
end

local function ramp(t: number, from: number, to: number): number
	return math.clamp((t - from) / (to - from), 0, 1)
end

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

local function mix(a: number, b: number, x: number): number
	return a + (b - a) * x
end

-- Todo en blanco y negro: cada pieza pasa a su gris de luminancia.
local function desaturate(root: Instance)
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			local c = item.Color
			local l = 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
			item.Color = Color3.new(l, l, l)
		elseif item:IsA("ParticleEmitter") then
			item:Destroy()
		end
	end
end

local function block(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	shade: number,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = grey(shade)
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ============================================================================================
-- Los chanchos: el mismo carnicero del juego, articulado a mano
-- ============================================================================================

type Pig = {
	model: Model,
	root: BasePart,
	hipL: Motor6D,
	hipR: Motor6D,
	hipLBase: CFrame,
	hipRBase: CFrame,
	armL: Motor6D?,
	armLBase: CFrame,
	armR: Motor6D,
	armRBase: CFrame,
	head: Motor6D?,
	headBase: CFrame,
	snout: BasePart?,
	snoutSize: Vector3,
}

local function motorOf(model: Model, partName: string): Motor6D?
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and item.Part1 and item.Part1.Name == partName then
			return item
		end
	end
	return nil
end

-- `scale` agranda al chancho (la sombra de la pared); `dark` lo deja negro y algo transparente.
local function buildPig(parent: Instance, scale: number, dark: boolean, hideMachete: boolean): Pig
	local rig = KillerModel.buildButcher()
	local model = rig.model
	rig.humanoid:Destroy()
	rig.root.Anchored = true
	desaturate(model)
	-- Un brillo en cada ojo: la máscara de verdad lo dibuja con un SurfaceGui, que acá no se ve.
	if not dark then
		for _, item in model:GetChildren() do
			if item.Name == "Ojo" and item:IsA("BasePart") then
				local glint = Instance.new("Part")
				glint.Name = "BrilloOjo"
				glint.Size = Vector3.new(0.12, 0.1, 0.05)
				glint.Material = Enum.Material.Neon
				glint.Color = grey(235)
				glint.CanCollide = false
				glint.CanQuery = false
				glint.Massless = true
				glint.Parent = model
				local weld = Instance.new("Weld")
				weld.Part0 = item
				weld.Part1 = glint
				weld.C0 = CFrame.new(0, 0, -0.06)
				weld.Parent = glint
			end
		end
	end
	if hideMachete then
		for _, name in { "Machete", "MangoMachete", "SangreMachete" } do
			local item = model:FindFirstChild(name)
			if item and item:IsA("BasePart") then
				item.Transparency = 1
			end
		end
	end
	if dark then
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
				item.Color = Color3.new(0, 0, 0)
				item.Material = Enum.Material.SmoothPlastic
				item.Transparency = 0.4
			end
		end
	end
	model.Parent = parent
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	local armL = motorOf(model, "BrazoIzquierdo")
	local head = motorOf(model, "Mascara")
	local snout = model:FindFirstChild("Trompa")
	return {
		model = model,
		root = rig.root,
		hipL = rig.leftHip,
		hipR = rig.rightHip,
		hipLBase = rig.leftHip.C0,
		hipRBase = rig.rightHip.C0,
		armL = armL,
		armLBase = if armL then armL.C0 else CFrame.identity,
		armR = rig.shoulder,
		armRBase = rig.shoulder.C0,
		head = head,
		headBase = if head then head.C0 else CFrame.identity,
		snout = if snout and snout:IsA("BasePart") then snout else nil,
		snoutSize = if snout and snout:IsA("BasePart") then snout.Size else Vector3.one,
	}
end

type PigPose = {
	-- Posición y hacia dónde mira (en radianes, 0 = mira a -Z).
	x: number,
	y: number,
	z: number,
	yaw: number,
	stride: number,
	phase: number,
	-- Brazo izquierdo: hacia adelante (+) o atrás (-) y hacia afuera.
	leftPitch: number,
	leftSpread: number,
	-- Brazo derecho (el del machete): pitch y apertura.
	rightPitch: number,
	rightSpread: number,
	headYaw: number,
	headPitch: number,
	scale: number?,
}

local function poseOf(x: number, z: number, yaw: number): PigPose
	return {
		x = x,
		y = PIG_ROOT_Y,
		z = z,
		yaw = yaw,
		stride = 0,
		phase = 0,
		leftPitch = 0,
		leftSpread = 0,
		rightPitch = 0,
		rightSpread = 0,
		headYaw = 0,
		headPitch = 0,
		scale = nil,
	}
end

local function posePig(pig: Pig, pose: PigPose)
	local k = pose.scale or 1
	pig.model:PivotTo(CFrame.new(pose.x, pose.y * k, pose.z) * CFrame.Angles(0, pose.yaw, 0))
	local swing = math.sin(pose.phase) * pose.stride
	pig.hipL.C0 = pig.hipLBase * CFrame.Angles(swing, 0, 0)
	pig.hipR.C0 = pig.hipRBase * CFrame.Angles(-swing, 0, 0)
	if pig.armL then
		-- El brazo cuelga: se gira desde el hombro (arriba del brazo), no desde el medio.
		local pivot = CFrame.new(0, 0.95 * k, 0)
		pig.armL.C0 = pig.armLBase
			* pivot
			* CFrame.Angles(pose.leftPitch, 0, -pose.leftSpread)
			* pivot:Inverse()
	end
	pig.armR.C0 = pig.armRBase * CFrame.Angles(pose.rightPitch, 0, pose.rightSpread)
	if pig.head then
		pig.head.C0 = pig.headBase * CFrame.Angles(pose.headPitch, pose.headYaw, 0)
	end
end

-- ============================================================================================
-- Las personas secuestradas: muñecos con capucha, que se arrastran y se sientan
-- ============================================================================================

type Person = { model: Model, parts: { [string]: Part } }

local PERSON_SIZES: { [string]: Vector3 } = {
	Torso = Vector3.new(1.8, 2.2, 0.9),
	Head = Vector3.new(1.1, 1.2, 1.1),
	ArmL = Vector3.new(0.7, 1.9, 0.7),
	ArmR = Vector3.new(0.7, 1.9, 0.7),
	ThighL = Vector3.new(0.85, 1.3, 0.85),
	ThighR = Vector3.new(0.85, 1.3, 0.85),
	ShinL = Vector3.new(0.85, 1.65, 0.85),
	ShinR = Vector3.new(0.85, 1.65, 0.85),
	Cuerda = Vector3.new(1.95, 0.25, 1.05),
	Cuello = Vector3.new(1.0, 0.2, 1.2),
}

local PERSON_SHADE: { [string]: number } = {
	Torso = 78,
	Head = 150,
	ArmL = 72,
	ArmR = 72,
	ThighL = 52,
	ThighR = 52,
	ShinL = 52,
	ShinR = 52,
	Cuerda = 120,
	Cuello = 40,
}

local function buildPerson(parent: Instance): Person
	local model = Instance.new("Model")
	model.Name = "Persona"
	local parts: { [string]: Part } = {}
	for name, size in PERSON_SIZES do
		parts[name] = block(
			model,
			size,
			CFrame.identity,
			PERSON_SHADE[name],
			if name == "Head" then Enum.Material.Fabric else Enum.Material.SmoothPlastic
		)
		parts[name].Name = name
	end
	model.Parent = parent
	return { model = model, parts = parts }
end

-- Posturas (con el origen en la cadera y el frente hacia -Z).
local function standPose(): { [string]: CFrame }
	return {
		Torso = CFrame.new(0, 1.2, 0),
		Head = CFrame.new(0, 2.9, 0),
		ArmL = CFrame.new(-1.25, 1.2, 0),
		ArmR = CFrame.new(1.25, 1.2, 0),
		ThighL = CFrame.new(-0.5, -0.65, 0),
		ThighR = CFrame.new(0.5, -0.65, 0),
		ShinL = CFrame.new(-0.5, -2.125, 0),
		ShinR = CFrame.new(0.5, -2.125, 0),
	}
end

local function sitPose(): { [string]: CFrame }
	local lean = CFrame.Angles(-0.2, 0, 0)
	return {
		Torso = CFrame.new(0, 0, 0.05) * lean * CFrame.new(0, 1.2, 0),
		Head = CFrame.new(0, 0, 0.05)
			* lean
			* CFrame.new(0, 2.85, -0.15)
			* CFrame.Angles(-0.45, 0, 0),
		ArmL = CFrame.new(-0.7, 0.9, 0.85),
		ArmR = CFrame.new(0.7, 0.9, 0.85),
		ThighL = CFrame.new(-0.5, 0, -0.65) * CFrame.Angles(math.pi / 2, 0, 0),
		ThighR = CFrame.new(0.5, 0, -0.65) * CFrame.Angles(math.pi / 2, 0, 0),
		ShinL = CFrame.new(-0.5, -0.82, -1.3),
		ShinR = CFrame.new(0.5, -0.82, -1.3),
	}
end

local function dragPose(): { [string]: CFrame }
	local lying = CFrame.Angles(-math.pi / 2, 0, 0)
	local out = {}
	for name, rel in standPose() do
		out[name] = lying * rel
	end
	-- Los brazos quedan estirados hacia quien lo arrastra.
	out.ArmL = lying * CFrame.new(-0.9, 1.2, 0)
	out.ArmR = lying * CFrame.new(0.9, 1.2, 0)
	return out
end

local SIT, DRAG = sitPose(), dragPose()

-- Mezcla de dos posturas y colocación en el mundo.
local function posePerson(
	person: Person,
	base: CFrame,
	from: { [string]: CFrame },
	to: { [string]: CFrame },
	amount: number
)
	local rel: { [string]: CFrame } = {}
	for name, cf in from do
		rel[name] = cf:Lerp(to[name], amount)
		person.parts[name].CFrame = base * rel[name]
	end
	person.parts.Cuerda.CFrame = base * rel.Torso * CFrame.new(0, 0.1, 0)
	person.parts.Cuello.CFrame = base * rel.Head * CFrame.new(0, -0.65, 0)
end

-- ============================================================================================
-- Los decorados
-- ============================================================================================

type Basement = {
	doorLight: Part,
	bulb: Part,
	glow: Part,
	cord: Part,
	chains: { Part },
	chair: Model,
}

local function buildBasement(parent: Instance): Basement
	local folder = Instance.new("Folder")
	folder.Name = "Sotano"
	folder.Parent = parent
	block(folder, Vector3.new(80, 1, 50), CFrame.new(0, -0.5, -10), 62, Enum.Material.Concrete)
	block(folder, Vector3.new(80, 18, 1), CFrame.new(0, 8, -10.5), 88, Enum.Material.Brick)
	block(folder, Vector3.new(80, 1, 50), CFrame.new(0, 17, -10), 30, Enum.Material.Concrete)
	-- Caños en la pared del fondo.
	local pipe =
		block(folder, Vector3.new(80, 0.9, 0.9), CFrame.new(0, 12.6, -9.8), 50, Enum.Material.Metal)
	pipe.Shape = Enum.PartType.Cylinder
	pipe.CFrame = CFrame.new(0, 12.6, -9.8)
	pipe.Size = Vector3.new(80, 0.9, 0.9)

	-- La puerta del fondo, a la derecha: marco y luz que entra cuando se abre.
	local doorX = 11
	block(
		folder,
		Vector3.new(0.7, 9, 0.7),
		CFrame.new(doorX - 2.3, 4.5, -9.8),
		30,
		Enum.Material.Wood
	)
	block(
		folder,
		Vector3.new(0.7, 9, 0.7),
		CFrame.new(doorX + 2.3, 4.5, -9.8),
		30,
		Enum.Material.Wood
	)
	block(folder, Vector3.new(5.3, 0.7, 0.7), CFrame.new(doorX, 9, -9.8), 30, Enum.Material.Wood)
	local doorLight = block(
		folder,
		Vector3.new(4, 8.6, 0.2),
		CFrame.new(doorX, 4.3, -9.95),
		235,
		Enum.Material.Neon
	)

	-- La mesa con las herramientas, a la izquierda.
	block(folder, Vector3.new(7, 0.5, 3.2), CFrame.new(TABLE_X, 3.2, -8), 70, Enum.Material.Wood)
	for _, dx in { -3.2, 3.2 } do
		for _, dz in { -1.3, 1.3 } do
			block(
				folder,
				Vector3.new(0.5, 3.2, 0.5),
				CFrame.new(TABLE_X + dx, 1.6, -8 + dz),
				55,
				Enum.Material.Wood
			)
		end
	end
	block(
		folder,
		Vector3.new(0.35, 0.12, 2.6),
		CFrame.new(TABLE_X - 2, 3.5, -8),
		190,
		Enum.Material.Metal
	)
	block(
		folder,
		Vector3.new(0.9, 0.12, 2),
		CFrame.new(TABLE_X + 0.2, 3.5, -8.2),
		175,
		Enum.Material.Metal
	)
	block(
		folder,
		Vector3.new(2.6, 0.5, 0.9),
		CFrame.new(TABLE_X + 2.4, 3.7, -7.6),
		110,
		Enum.Material.Metal
	)
	-- Ganchos con cadenas que cuelgan del techo.
	local chains: { Part } = {}
	for _, x in { -13, -6, 9 } do
		local chain =
			block(folder, Vector3.new(0.3, 7, 0.3), CFrame.new(x, 13, -8), 85, Enum.Material.Metal)
		table.insert(chains, chain)
		block(folder, Vector3.new(0.9, 0.9, 0.3), CFrame.new(x, 9.2, -8), 95, Enum.Material.Metal)
	end
	-- La silla de madera.
	local chair = Instance.new("Model")
	chair.Name = "Silla"
	chair.Parent = folder
	block(chair, Vector3.new(2.8, 0.3, 2.8), CFrame.new(CHAIR_X, 1.55, -6), 66, Enum.Material.Wood)
	block(chair, Vector3.new(2.8, 3.6, 0.3), CFrame.new(CHAIR_X, 3.4, -7.4), 62, Enum.Material.Wood)
	for _, dx in { -1.2, 1.2 } do
		for _, dz in { -1.2, 1.2 } do
			block(
				chair,
				Vector3.new(0.35, 1.5, 0.35),
				CFrame.new(CHAIR_X + dx, 0.75, -6 + dz),
				52,
				Enum.Material.Wood
			)
		end
	end
	-- La lámpara que se balancea.
	local cord = block(folder, Vector3.new(0.08, 5, 0.08), CFrame.new(4, 14.5, -5), 20)
	local bulb =
		block(folder, Vector3.new(1, 1, 1), CFrame.new(4, 11.8, -5), 255, Enum.Material.Neon)
	bulb.Shape = Enum.PartType.Ball
	local glow =
		block(folder, Vector3.new(3.4, 3.4, 3.4), CFrame.new(4, 11.8, -5), 255, Enum.Material.Neon)
	glow.Shape = Enum.PartType.Ball
	glow.Transparency = 0.9
	return {
		doorLight = doorLight,
		bulb = bulb,
		glow = glow,
		cord = cord,
		chains = chains,
		chair = chair,
	}
end

local function buildCloseUp(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "PrimerPlano"
	folder.Parent = parent
	block(
		folder,
		Vector3.new(60, 1, 60),
		CFrame.new(CLOSE + Vector3.new(0, -0.5, 0)),
		55,
		Enum.Material.Concrete
	)
	block(
		folder,
		Vector3.new(60, 22, 1),
		CFrame.new(CLOSE + Vector3.new(0, 10, -8)),
		80,
		Enum.Material.Brick
	)
	block(
		folder,
		Vector3.new(1, 22, 40),
		CFrame.new(CLOSE + Vector3.new(-9, 10, 0)),
		70,
		Enum.Material.Brick
	)
end

-- ============================================================================================
-- La cámara
-- ============================================================================================

-- La cámara sostenida por el chancho tiembla y se inclina; sobre el trípode casi no se mueve.
local function cameraShake(s: number): (number, number, number, number, number)
	local held = math.max(
		ease(ramp(s, 0, 0.45)) * (1 - ease(ramp(s, 5.2, 6.2))),
		ease(ramp(s, 27.4, 28.2)) * (1 - ease(ramp(s, 31, 31.3)))
	)
	local adjust = ramp(s, 1.2, 2) * (1 - ramp(s, 4.2, 5.4))
		+ ramp(s, 28.2, 29) * (1 - ramp(s, 30.2, 30.8))
	local roll = held * math.sin(s * 7) * 0.9 + adjust * math.sin(s * 2.6) * 9
	roll += (1 - held) * math.sin(s * 1.3) * 0.15
	local dx = held * math.sin(s * 5.3) * 0.05 + adjust * math.sin(s * 1.9) * 0.5
	local dy = held * math.cos(s * 6.1) * 0.05 + adjust * math.cos(s * 2.3) * 0.25
	return math.rad(roll), dx, dy, held, adjust
end

-- ============================================================================================
-- La película entera
-- ============================================================================================

-- Qué tan negra está la pantalla en este momento: cortes bruscos mientras pasa lo peor y el negro
-- completo cuando la cámara se apaga.
local function blackout(s: number): number
	for _, cut in { 14.4, 16, 17.6, 19.2 } do
		if s >= cut and s < cut + 0.09 then
			return 1
		end
	end
	if (s >= 20 and s < 20.8) or (s >= 24.6 and s < 25.3) or s >= 31.2 then
		return 1
	end
	return 0
end

-- Dibuja la película dentro de `image` y devuelve la función que la avanza a `t` segundos.
function Footage.build(image: Frame): (number) -> ()
	image.BackgroundColor3 = grey(0)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundColor3 = grey(0)
	viewport.BorderSizePixel = 0
	viewport.Ambient = grey(40)
	viewport.LightColor = grey(190)
	viewport.LightDirection = Vector3.new(0.3, -1, -0.4)
	viewport.Parent = image
	local camera = Instance.new("Camera")
	camera.FieldOfView = 55
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local basement = buildBasement(world)
	buildCloseUp(world)
	local closePig = buildPig(world, 1, false, true)
	local closeModel = closePig.model
	local pigA = buildPig(world, 1, false, false)
	local pigB = buildPig(world, 1, false, false)
	local shadowPig = buildPig(world, 2.6, true, false)
	local victim1 = buildPerson(world)
	local victim2 = buildPerson(world)
	-- La mano que tapa el lente al final.
	local cover = block(world, Vector3.one, CFrame.identity, 60, Enum.Material.Fabric)
	cover.Transparency = 1

	-- Viñeta en los costados.
	for _, side in { -1, 1 } do
		local edge = Instance.new("Frame")
		edge.AnchorPoint = Vector2.new(0.5, 0.5)
		edge.Size = UDim2.fromScale(0.12, 1)
		edge.Position = UDim2.fromScale(if side < 0 then 0.06 else 0.94, 0.5)
		edge.BackgroundColor3 = grey(0)
		edge.BorderSizePixel = 0
		edge.ZIndex = 2
		edge.Parent = image
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if side < 0 then 0.1 else 1),
			NumberSequenceKeypoint.new(1, if side < 0 then 1 else 0.1),
		})
		g.Parent = edge
	end
	-- Rótulo de la cámara y su luz roja.
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0)
	label.Position = UDim2.fromScale(0.02, 0.04)
	label.Size = UDim2.fromScale(0.3, 0.09)
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = grey(240)
	label.ZIndex = 3
	label.Parent = image
	-- Apagón y parpadeo de la luz del proyector.
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = grey(0)
	black.BorderSizePixel = 0
	black.ZIndex = 4
	black.Parent = image
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = grey(0)
	dim.BorderSizePixel = 0
	dim.ZIndex = 4
	dim.Parent = image
	local random = Random.new()

	-- --------------------------------------------------------------------------------------
	-- Primer plano: el chancho frente a la cámara
	-- --------------------------------------------------------------------------------------
	local function closeUp(s: number)
		local roll, dx, dy, held, adjust = cameraShake(s)
		local phaseTwo = s >= 25
		-- Dónde está el chancho y a qué distancia la cámara.
		local pigZ, pigX, distance = 0, 0, 3.6
		local walking = false
		if not phaseTwo then
			if s < 3 then
				distance = 4.3 + 0.2 * math.sin(s * 1.3)
			elseif s < 3.9 then
				distance = mix(4.3, 3.1, ease(ramp(s, 3, 3.9)))
			elseif s < 4.6 then
				distance = 3.1
			else
				-- Termina de acomodar la cámara y se aparta caminando hacia atrás.
				local back = ease(ramp(s, 4.6, 6.3))
				distance = mix(3.1, 4.4, back)
				pigZ = -back * 4.5
				pigX = -back * 2.2
				walking = back > 0 and back < 1
			end
		else
			local near = ease(ramp(s, 25, 27.4))
			distance = 3.6
			pigZ = mix(-6, 0, near)
			walking = near > 0 and near < 1
			pigX = 0
		end
		local pose = poseOf(CLOSE.X + pigX, CLOSE.Z + pigZ, math.pi)
		if walking then
			pose.stride = 0.5
			pose.phase = s * 7
		end
		pose.y = PIG_ROOT_Y + if walking then math.abs(math.sin(s * 7)) * 0.1 else 0
		-- Manos hacia la cámara, con los brazos abiertos, y se mueven al acomodarla.
		local lift = if phaseTwo then math.max(held, 0.0) else held
		local sway = math.sin(s * 2.6) * 0.18 * adjust
		pose.leftPitch = 0.8 * lift + sway
		pose.leftSpread = 1.0 * lift
		pose.rightPitch = 0.8 * lift - sway
		pose.rightSpread = -1.0 * lift
		-- La cabeza lo mira todo, con un leve cabeceo.
		pose.headYaw = math.sin(s * 0.9) * 0.08
		pose.headPitch = -0.12 * ramp(s, 3, 3.9) * (1 - ramp(s, 4.4, 4.8))
			+ math.sin(s * 1.7) * 0.03
		posePig(closePig, pose)
		if closePig.snout then
			closePig.snout.Size = closePig.snoutSize * (1 + 0.05 * math.sin(s * 5))
		end

		local head = Vector3.new(CLOSE.X + pigX, 4.6, CLOSE.Z + pigZ)
		local eye = head + Vector3.new(dx, dy + 0.1, distance)
		camera.FieldOfView = 55
		camera.CFrame = CFrame.lookAt(eye, head + Vector3.new(dx * 0.5, dy * 0.5, 0))
			* CFrame.Angles(0, 0, roll)
		viewport.Ambient = grey(35)
		viewport.LightColor = grey(215)
		viewport.LightDirection = Vector3.new(-0.25, -0.35, -1)
	end

	-- --------------------------------------------------------------------------------------
	-- El sótano
	-- --------------------------------------------------------------------------------------
	local function cellar(s: number)
		local roll = cameraShake(s)
		-- Cámara fija en trípode, apenas mueve.
		camera.FieldOfView = 55
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 5, 6.5), Vector3.new(1, 4.2, -7))
			* CFrame.Angles(0, 0, roll)

		-- Lámpara que se balancea y titila.
		local sway = math.sin(s * 1.1) * 0.9
		local flicker = 0.9 + 0.1 * math.sin(s * 37) * math.sin(s * 11)
		basement.bulb.Position = Vector3.new(4 + sway, 11.8, -5)
		basement.glow.Position = Vector3.new(4 + sway, 11.8, -5)
		basement.glow.Transparency = 0.9 + (1 - flicker) * 0.5
		basement.cord.CFrame = CFrame.new(4 + sway / 2, 14.3, -5)
			* CFrame.Angles(0, 0, sway * -0.18)
		for index, chain in basement.chains do
			local home = ({ -13, -6, 9 })[index]
			chain.CFrame = CFrame.new(home + math.sin(s * 0.8 + index) * 0.15, 13, -8)
		end
		viewport.Ambient = grey(78 * flicker)
		viewport.LightColor = grey(235 * flicker)
		viewport.LightDirection = Vector3.new(0.35 - sway * 0.12, -1, -0.5)

		-- La puerta: se abre dos veces, para entrar con cada persona.
		local open = ease(ramp(s, 6.2, 7)) * (1 - ease(ramp(s, 12.2, 13)))
			+ ease(ramp(s, 21, 21.8)) * (1 - ease(ramp(s, 24, 24.6)))
		basement.doorLight.Size = Vector3.new(4 * open + 0.01, 8.6, 0.2)
		basement.doorLight.Transparency = 1 - math.min(open * 1.5, 1)

		-- Primer chancho: entra arrastrando a la primera persona.
		local ax = 17
		local walkingA = false
		local leftDrag = 0
		if s >= 7 and s < 11 then
			ax = mix(17, CHAIR_X + 4.4, ease(ramp(s, 7, 11)))
			walkingA = true
			leftDrag = -1.15
		elseif s >= 11 and s < 20.4 then
			ax = CHAIR_X + 4.4
			leftDrag = if s < 12.2
				then mix(-1.15, 0.3, ease(ramp(s, 11, 12.2)))
				else 0.3 * (1 - ramp(s, 12.2, 13))
		elseif s >= 21.4 and s < 24.6 then
			ax = mix(17, CHAIR_X + 4, ease(ramp(s, 21.4, 24.4)))
			walkingA = s < 24.4
			leftDrag = -1.15
		elseif s >= 24.4 and s < 25.3 then
			ax = CHAIR_X + 4
			leftDrag = -1.15
		end
		local poseA = poseOf(ax, LANE_Z, math.pi / 2)
		if walkingA then
			poseA.stride = 0.55
			poseA.phase = s * 7
			poseA.y = PIG_ROOT_Y + math.abs(math.sin(s * 7)) * 0.1
		end
		poseA.leftPitch = leftDrag
		poseA.leftSpread = 0.15
		poseA.headPitch = if s >= 12.2 and s < 20.4 then 0.1 * math.sin(s * 1.5) else 0
		posePig(pigA, poseA)

		-- Segundo chancho: espera junto a la mesa y después se acerca a la silla y descarga el cuchillón.
		local move = ease(ramp(s, 12.2, 13.5))
		local bx = mix(-6 + 0.4 * math.sin(s * 0.8), CHAIR_X - 3.8, move)
		local poseB = poseOf(bx, LANE_Z, mix(math.pi, math.pi * 1.5, move))
		local hit = ramp(s, 13.5, 14) * (1 - ramp(s, 19.6, 20))
		poseB.rightPitch = hit * (1.4 + 1.1 * math.sin(s * 2.2))
		poseB.headPitch = 0.15 * hit
		if move > 0 and move < 1 then
			poseB.stride = 0.5
			poseB.phase = s * 7
		end
		posePig(pigB, poseB)

		-- Primera persona: arrastrada, sentada en la silla y, al final, caída hacia adelante.
		local v1 = victim1
		if s < 7 or s >= 25.3 then
			v1.model.Parent = nil
		else
			v1.model.Parent = world
			if s < 11 then
				local base = CFrame.new(ax + 6.4, 0.6, LANE_Z) * CFrame.Angles(0, math.pi / 2, 0)
				posePerson(v1, base, DRAG, DRAG, 0)
			elseif s < 12.2 then
				local lift = ease(ramp(s, 11, 12.2))
				local start = Vector3.new(ax + 6.4, 0.6, LANE_Z)
				local finish = Vector3.new(CHAIR_X, 2.05, -6.05)
				local pos = start:Lerp(finish, lift)
				local base = CFrame.new(pos) * CFrame.Angles(0, mix(math.pi / 2, math.pi, lift), 0)
				posePerson(v1, base, DRAG, SIT, lift)
			else
				local struggle = ramp(s, 13, 15.5) * (1 - ramp(s, 17.5, 20))
				local shake = Vector3.new(math.sin(s * 23) * 0.1 * struggle, 0, 0)
				local twist = math.sin(s * 19) * 0.12 * struggle
				local slump = if s >= 20.4 then 0.25 else 0
				local base = CFrame.new(Vector3.new(CHAIR_X, 2.05, -6.05) + shake)
					* CFrame.Angles(slump, math.pi + twist, 0)
				posePerson(v1, base, SIT, SIT, 0)
			end
		end

		-- Segunda persona: la traen a rastras.
		local v2 = victim2
		if s >= 21.4 and s < 25.3 then
			v2.model.Parent = world
			local base = CFrame.new(ax + 6.4, 0.6 + math.sin(s * 17) * 0.03, LANE_Z)
				* CFrame.Angles(0, math.pi / 2, 0)
			posePerson(v2, base, DRAG, DRAG, 0)
		else
			v2.model.Parent = nil
		end

		-- La sombra enorme en la pared, con el cuchillón que sube y baja.
		local shade = ramp(s, 13.2, 14) * (1 - ramp(s, 20, 20.4))
		if shade > 0.01 then
			shadowPig.model.Parent = world
			local poseS = poseOf(CHAIR_X - 3 + math.sin(s * 0.9) * 0.8, -9.2, math.pi * 1.5)
			poseS.scale = 2.6
			poseS.rightPitch = 1.4 + 1.1 * math.sin(s * 2)
			posePig(shadowPig, poseS)
			-- Se funde con la pared al principio y al final.
			for _, item in shadowPig.model:GetDescendants() do
				if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
					item.Transparency = 1 - 0.6 * shade
				end
			end
		else
			shadowPig.model.Parent = nil
		end
	end

	return function(t: number)
		local s = t % LOOP
		local inCloseUp = s < 6.3 or (s >= 25 and s < 31.3)
		closeModel.Parent = if inCloseUp then world else nil
		if inCloseUp then
			closeUp(s)
		else
			cellar(s)
		end
		-- La mano que tapa el lente al final.
		local covering = ease(ramp(s, 30.4, 31.2))
		cover.Transparency = if covering > 0.01 then 0 else 1
		if covering > 0.01 then
			local size = mix(0.5, 14, covering)
			cover.Size = Vector3.new(size, size * 0.8, 0.4)
			cover.CFrame = camera.CFrame
				* CFrame.new(0.4 * (1 - covering), -0.3 * (1 - covering), -1.3)
		end
		local out = blackout(s)
		black.BackgroundTransparency = 1 - out
		dim.BackgroundTransparency = 0.86
			+ random:NextNumber() * 0.1
			+ (if s % 3.2 < 0.12 then -0.25 else 0)
		local seconds = math.floor(s)
		label.Text = `{if s % 1 < 0.6 then "●" else " "} REC  SOTANO 02  00:{string.format(
			"%02d",
			seconds
		)}`
		label.Visible = out < 1
	end
end

return Footage
