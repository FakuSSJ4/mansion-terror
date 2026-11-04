--!strict
-- Arma al asesino con piezas: 1,80 m, hacha en la izquierda, sin brazo derecho,
-- pelo largo, media cara con piel y media en carne viva, y un solo ojo.
-- Con el modelo mirando a -Z, su derecha es +X.

local SKIN = Color3.fromRGB(176, 145, 120)
local FLESH = Color3.fromRGB(122, 24, 28)
local BLOOD = Color3.fromRGB(70, 10, 12)
local CLOTH = Color3.fromRGB(38, 36, 34)
local HAIR = Color3.fromRGB(16, 13, 12)

local LEG_LENGTH = 2.7
local TORSO_HEIGHT = 2.4
local HEAD_HEIGHT = 1.3

local KillerModel = {}

export type Rig = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	leftHip: Motor6D,
	rightHip: Motor6D,
	shoulder: Motor6D,
	-- Articulaciones extra (solo el del smoking): cuello, cintura y hombro izquierdo, para una caminata
	-- más expresiva; y cuánto se escaló el modelo.
	head: Motor6D?,
	spine: Motor6D?,
	leftShoulder: Motor6D?,
	scale: number?,
	-- Parte que lleva el resplandor de la cara.
	glowPart: BasePart,
	glowColor: Color3,
}

local function piece(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	-- Que los rayos (línea de vista) no se choquen con su propio cuerpo.
	p.CanQuery = false
	p.Massless = true
	p.CollisionGroup = "Killer"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function joint(parent: BasePart, child: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Part0 = parent
	motor.Part1 = child
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = parent
	return motor
end

local function attach(
	model: Model,
	parent: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = piece(model, name, size, color, material)
	joint(parent, p, offset, CFrame.identity)
	return p
end

-- Cilindro vertical (los de Roblox van acostados a lo largo de X): `size` es (alto, diámetro, diámetro).
local function cylinder(
	model: Model,
	parent: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = attach(
		model,
		parent,
		name,
		size,
		offset * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Detalles dibujados sobre una cara: así el rostro y la ropa ganan detalle sin sumar partes.
-- `alone` apaga la influencia de la luz (para lo que brilla, como las pupilas).
local function paint(
	part: BasePart,
	face: Enum.NormalId,
	density: number?,
	alone: boolean?
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = density or 100
	gui.LightInfluence = if alone then 0 else 0.75
	gui.Parent = part
	return gui
end

-- Rectángulo (o elipse) en coordenadas de la cara: centro x, y y tamaño, de 0 a 1.
local function mark(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	h: number,
	color: Color3,
	extra: { rotation: number?, alpha: number?, round: boolean? }?
): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = if extra and extra.alpha then extra.alpha else 0
	frame.Rotation = if extra and extra.rotation then extra.rotation else 0
	frame.BorderSizePixel = 0
	if extra and extra.round then
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = frame
	end
	frame.Parent = parent
	return frame
end

-- Degradé de arriba hacia abajo: de `from` a `to` de transparencia (sangre que chorrea).
local function fade(frame: Frame, from: number, to: number)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new(from, to)
	gradient.Parent = frame
end

-- Gotas que caen despacio de una pieza (filo del hacha, machete).
local function drip(part: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 2.5
	emitter.Lifetime = NumberRange.new(0.8, 1.1)
	emitter.Speed = NumberRange.new(0, 0.2)
	emitter.Acceleration = Vector3.new(0, -16, 0)
	emitter.Size = NumberSequence.new(0.12)
	emitter.Color = ColorSequence.new(Color3.fromRGB(110, 8, 10))
	emitter.LightInfluence = 1
	emitter.Parent = part
end

-- Desgaste: cada pieza grande sale con un tono algo distinto y con manchas de mugre y de sangre seca
-- pegadas a su frente y su espalda, para que no se vea de plástico liso.
local function weather(model: Model)
	local random = Random.new()
	local targets: { Part } = {}
	for _, item in model:GetChildren() do
		if
			item:IsA("Part")
			and item.Name ~= "HumanoidRootPart"
			and item.Transparency == 0
			and math.min(item.Size.X, item.Size.Y, item.Size.Z) >= 0.4
		then
			table.insert(targets, item)
		end
	end
	for _, target in targets do
		local shade = random:NextNumber(0.8, 1)
		target.Color =
			Color3.new(target.Color.R * shade, target.Color.G * shade, target.Color.B * shade)
		if target.Material == Enum.Material.SmoothPlastic then
			target.Material = Enum.Material.Fabric
		end
		for _ = 1, 3 do
			local blood = random:NextNumber() < 0.4
			local width = random:NextNumber(0.2, 0.55) * math.min(target.Size.X, 1.6)
			local height = random:NextNumber(0.2, 0.55) * math.min(target.Size.Y, 1.6)
			local side = if random:NextNumber() < 0.5 then -1 else 1
			local stain = attach(
				model,
				target,
				if blood then "SangreSeca" else "Mugre",
				Vector3.new(width, height, 0.05),
				CFrame.new(
					random:NextNumber(-0.35, 0.35) * target.Size.X,
					random:NextNumber(-0.35, 0.35) * target.Size.Y,
					side * (target.Size.Z / 2 + 0.02)
				),
				if blood then Color3.fromRGB(78, 12, 12) else Color3.fromRGB(42, 34, 27),
				Enum.Material.Slate
			)
			stain.Transparency = 0.12
		end
	end
end
function KillerModel.build(): Rig
	local model = Instance.new("Model")
	model.Name = "Asesino"
	model:AddTag("Killer")

	local root = piece(model, "HumanoidRootPart", Vector3.new(2, TORSO_HEIGHT, 1), CLOTH)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	model.PrimaryPart = root

	local torso = attach(
		model,
		root,
		"Torso",
		Vector3.new(2, TORSO_HEIGHT, 1),
		CFrame.identity,
		CLOTH,
		Enum.Material.Fabric
	)
	attach(
		model,
		torso,
		"Sangre",
		Vector3.new(1.1, 1.2, 0.1),
		CFrame.new(0.3, 0.2, -0.5),
		BLOOD,
		Enum.Material.Slate
	)

	-- Muñón del brazo derecho.
	attach(
		model,
		torso,
		"Munon",
		Vector3.new(0.9, 0.7, 0.9),
		CFrame.new(1.4, TORSO_HEIGHT / 2 - 0.35, 0),
		CLOTH,
		Enum.Material.Fabric
	)
	attach(
		model,
		torso,
		"HeridaMunon",
		Vector3.new(0.75, 0.15, 0.75),
		CFrame.new(1.4, TORSO_HEIGHT / 2 - 0.75, 0),
		FLESH,
		Enum.Material.Slate
	)

	-- Brazo izquierdo con hacha, articulado para el golpe.
	local arm =
		piece(model, "BrazoIzquierdo", Vector3.new(0.9, 2.3, 0.9), SKIN, Enum.Material.Fabric)
	local shoulder =
		joint(torso, arm, CFrame.new(-1.45, TORSO_HEIGHT / 2 - 0.2, 0), CFrame.new(0, 0.95, 0))
	local axeYellow = Color3.fromRGB(225, 185, 30)
	local axeSteel = Color3.fromRGB(190, 190, 195)
	local axeHand = CFrame.new(0, -1.15, 0)
	local function axe(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material
	)
		attach(model, arm, name, size, axeHand * offset, color, material)
	end
	-- Mango negro con la empuñadura amarilla.
	axe(
		"MangoHacha",
		Vector3.new(0.3, 0.32, 4.6),
		CFrame.new(0, 0, -1.8),
		Color3.fromRGB(14, 14, 16),
		Enum.Material.Wood
	)
	axe(
		"Empunadura",
		Vector3.new(0.38, 0.4, 1.3),
		CFrame.new(0, 0, 0.4),
		axeYellow,
		Enum.Material.SmoothPlastic
	)
	-- Cabeza amarilla, con el filo y el pico de acero.
	axe(
		"CabezaHacha",
		Vector3.new(0.42, 1.5, 1.3),
		CFrame.new(0, 0.1, -4.1),
		axeYellow,
		Enum.Material.SmoothPlastic
	)
	axe(
		"FiloHacha",
		Vector3.new(0.14, 0.75, 1.9),
		CFrame.new(0, -1, -4.1),
		axeSteel,
		Enum.Material.Metal
	)
	axe(
		"PicoHacha",
		Vector3.new(0.14, 0.75, 0.5),
		CFrame.new(0, 1.2, -4.1),
		axeSteel,
		Enum.Material.Metal
	)
	axe(
		"SangreHacha",
		Vector3.new(0.16, 0.35, 1),
		CFrame.new(0, -1.1, -4.3),
		BLOOD,
		Enum.Material.Slate
	)

	-- Piernas.
	local hipOffset = -TORSO_HEIGHT / 2
	local leftLeg = piece(
		model,
		"PiernaIzquierda",
		Vector3.new(0.95, LEG_LENGTH, 0.95),
		CLOTH,
		Enum.Material.Fabric
	)
	local rightLeg = piece(
		model,
		"PiernaDerecha",
		Vector3.new(0.95, LEG_LENGTH, 0.95),
		CLOTH,
		Enum.Material.Fabric
	)
	local c1 = CFrame.new(0, LEG_LENGTH / 2, 0)
	local leftHip = joint(root, leftLeg, CFrame.new(-0.5, hipOffset, 0), c1)
	local rightHip = joint(root, rightLeg, CFrame.new(0.5, hipOffset, 0), c1)

	-- Cabeza partida al medio.
	local headY = TORSO_HEIGHT / 2 + HEAD_HEIGHT / 2
	local skinSide = attach(
		model,
		torso,
		"CaraPiel",
		Vector3.new(0.65, HEAD_HEIGHT, 1.1),
		CFrame.new(-0.325, headY, 0),
		SKIN
	)
	local fleshSide = attach(
		model,
		torso,
		"CaraCarne",
		Vector3.new(0.65, HEAD_HEIGHT, 1.1),
		CFrame.new(0.325, headY, 0),
		FLESH,
		Enum.Material.Slate
	)
	attach(
		model,
		torso,
		"Corte",
		Vector3.new(0.08, HEAD_HEIGHT + 0.04, 1.14),
		CFrame.new(0, headY, 0),
		BLOOD,
		Enum.Material.Slate
	)

	-- El único ojo está del lado de la piel; del otro queda la cuenca vacía.
	attach(
		model,
		skinSide,
		"Ojo",
		Vector3.new(0.3, 0.2, 0.05),
		CFrame.new(0, 0.15, -0.56),
		Color3.fromRGB(225, 215, 200)
	)
	attach(
		model,
		skinSide,
		"Pupila",
		Vector3.new(0.1, 0.13, 0.05),
		CFrame.new(0.03, 0.15, -0.59),
		Color3.new(0, 0, 0)
	)
	attach(
		model,
		fleshSide,
		"Cuenca",
		Vector3.new(0.34, 0.3, 0.05),
		CFrame.new(0, 0.15, -0.56),
		Color3.new(0.02, 0, 0)
	)
	attach(
		model,
		fleshSide,
		"Dientes",
		Vector3.new(0.5, 0.14, 0.05),
		CFrame.new(-0.02, -0.33, -0.56),
		Color3.fromRGB(210, 200, 170)
	)
	attach(
		model,
		skinSide,
		"Boca",
		Vector3.new(0.45, 0.07, 0.05),
		CFrame.new(0.05, -0.33, -0.56),
		Color3.fromRGB(50, 20, 20)
	)

	-- Pelo largo hasta la espalda.
	attach(
		model,
		torso,
		"PeloArriba",
		Vector3.new(1.4, 0.25, 1.25),
		CFrame.new(0, headY + HEAD_HEIGHT / 2 + 0.1, 0),
		HAIR,
		Enum.Material.Fabric
	)
	attach(
		model,
		torso,
		"PeloAtras",
		Vector3.new(1.4, 2.5, 0.25),
		CFrame.new(0, headY - 0.6, 0.65),
		HAIR,
		Enum.Material.Fabric
	)
	attach(
		model,
		torso,
		"PeloIzquierda",
		Vector3.new(0.18, 2, 0.8),
		CFrame.new(-0.72, headY - 0.45, 0.15),
		HAIR,
		Enum.Material.Fabric
	)
	attach(
		model,
		torso,
		"PeloDerecha",
		Vector3.new(0.18, 1.6, 0.7),
		CFrame.new(0.72, headY - 0.3, 0.2),
		HAIR,
		Enum.Material.Fabric
	)

	-- Más detalle y más feo: cinturón, botas, manos, vendaje del muñón, y todo lo demás dibujado.
	local leather = Color3.fromRGB(30, 22, 18)
	attach(
		model,
		torso,
		"Cinturon",
		Vector3.new(2.06, 0.24, 1.06),
		CFrame.new(0, -0.85, 0),
		leather,
		Enum.Material.Leather
	)
	attach(
		model,
		torso,
		"Hebilla",
		Vector3.new(0.42, 0.3, 0.06),
		CFrame.new(0, -0.85, -0.55),
		Color3.fromRGB(150, 138, 96),
		Enum.Material.Metal
	)
	for _, leg in { leftLeg, rightLeg } do
		attach(
			model,
			leg,
			"Bota",
			Vector3.new(1.05, 0.8, 1.45),
			CFrame.new(0, -LEG_LENGTH / 2 + 0.4, -0.22),
			Color3.fromRGB(24, 18, 14),
			Enum.Material.Leather
		)
	end
	attach(
		model,
		arm,
		"ManoIzquierda",
		Vector3.new(0.82, 0.5, 0.82),
		CFrame.new(0, -1.12, 0),
		Color3.fromRGB(128, 104, 90),
		Enum.Material.Slate
	)
	attach(
		model,
		torso,
		"Venda",
		Vector3.new(0.98, 0.55, 0.98),
		CFrame.new(1.4, TORSO_HEIGHT / 2 - 0.5, 0),
		Color3.fromRGB(176, 166, 146),
		Enum.Material.Fabric
	)

	-- Pecho: la camisa rota deja ver la carne y las costillas, la sangre chorrea y una correa lo cruza.
	local chest = paint(torso, Enum.NormalId.Front, 80)
	for _, tear in
		{
			{ 0.36, 0.42, 0.42, 0.5, -8 },
			{ 0.62, 0.55, 0.36, 0.42, 10 },
			{ 0.5, 0.7, 0.5, 0.3, 4 },
		}
	do
		mark(chest, tear[1], tear[2], tear[3], tear[4], FLESH, { rotation = tear[5] })
	end
	for i = 0, 5 do
		mark(chest, 0.5, 0.3 + i * 0.075, 0.5, 0.012, BLOOD, { alpha = 0.2 })
	end
	mark(chest, 0.5, 0.5, 0.12, 1.5, leather, { rotation = -38 })
	local gore = mark(chest, 0.5, 0.8, 1, 0.4, BLOOD)
	fade(gore, 1, 0.1)
	for i = 0, 3 do
		mark(chest, 0.82, 0.22 + i * 0.05, 0.1, 0.012, Color3.fromRGB(14, 10, 10))
	end

	-- Cara: ojera, cicatriz, venas y sangre que baja del ojo (lado de la piel); fibras y sangre en la boca
	-- (lado de la carne viva).
	local skinFace = paint(skinSide, Enum.NormalId.Front, 140)
	mark(skinFace, 0.5, 0.4, 0.95, 0.2, Color3.fromRGB(34, 18, 18), { alpha = 0.45, round = true })
	mark(skinFace, 0.5, 0.18, 0.9, 0.012, BLOOD, { rotation = 18 })
	for _, vein in
		{
			{ 0.25, 0.55, 0.012, 0.22, -12 },
			{ 0.7, 0.6, 0.012, 0.18, 14 },
			{ 0.4, 0.14, 0.012, 0.16, 30 },
		}
	do
		mark(
			skinFace,
			vein[1],
			vein[2],
			vein[3],
			vein[4],
			Color3.fromRGB(120, 36, 40),
			{ rotation = vein[5], alpha = 0.25 }
		)
	end
	local streak = mark(skinFace, 0.58, 0.64, 0.06, 0.42, BLOOD)
	fade(streak, 0, 0.8)
	local fleshFace = paint(fleshSide, Enum.NormalId.Front, 140)
	for i = 0, 5 do
		mark(
			fleshFace,
			0.15 + i * 0.14,
			0.45,
			0.012,
			0.8,
			Color3.fromRGB(70, 10, 14),
			{ alpha = 0.3 }
		)
	end
	mark(fleshFace, 0.5, 0.78, 0.8, 0.05, Color3.fromRGB(214, 202, 170), { alpha = 0.1 })
	for i = 0, 3 do
		mark(fleshFace, 0.2 + i * 0.2, 0.78, 0.015, 0.06, Color3.fromRGB(60, 40, 36))
	end
	local mouthBlood = mark(fleshFace, 0.4, 0.9, 0.12, 0.3, BLOOD)
	fade(mouthBlood, 0.1, 1)
	-- El ojo único brilla en rojo en la oscuridad.
	local pupil = model:FindFirstChild("Pupila")
	if pupil and pupil:IsA("BasePart") then
		pupil.Material = Enum.Material.Neon
		pupil.Color = Color3.fromRGB(230, 40, 30)
	end
	local blade = model:FindFirstChild("FiloHacha")
	if blade and blade:IsA("BasePart") then
		drip(blade)
	end

	-- Con HipHeight igual al largo de pierna, la altura total da unos 6,4 studs (1,80 m).
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = LEG_LENGTH
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	weather(model)
	return {
		model = model,
		root = root,
		humanoid = humanoid,
		leftHip = leftHip,
		rightHip = rightHip,
		shoulder = shoulder,
		glowPart = model:FindFirstChild("Corte") :: BasePart,
		glowColor = Color3.fromRGB(255, 140, 110),
	}
end

-- El segundo asesino: smoking negro, camisa blanca, moño y bastón estoque en la mano derecha.
function KillerModel.buildGentleman(): Rig
	local jacket = Color3.fromRGB(16, 16, 20)
	local shirt = Color3.fromRGB(215, 212, 205)
	local pale = Color3.fromRGB(205, 190, 175)
	local fabric = Enum.Material.Fabric

	local model = Instance.new("Model")
	model.Name = "AsesinoSmoking"
	model:AddTag("Killer")

	local root = piece(model, "HumanoidRootPart", Vector3.new(2, TORSO_HEIGHT, 1), jacket)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	model.PrimaryPart = root

	-- Torso, brazo izquierdo y cabeza articulados (la cintura, el hombro y el cuello) para poder moverlos
	-- al caminar.
	local torso = piece(model, "Saco", Vector3.new(2, TORSO_HEIGHT, 1), jacket, fabric)
	local spine = joint(root, torso, CFrame.identity, CFrame.identity)
	-- Pechera en V: camisa, moño y solapas.
	attach(
		model,
		torso,
		"Camisa",
		Vector3.new(0.7, 1.3, 0.05),
		CFrame.new(0, 0.5, -0.52),
		shirt,
		fabric
	)
	attach(
		model,
		torso,
		"Mono",
		Vector3.new(0.7, 0.25, 0.1),
		CFrame.new(0, 1.02, -0.56),
		Color3.new(0, 0, 0),
		fabric
	)
	for _, side in { -1, 1 } do
		attach(
			model,
			torso,
			"Solapa",
			Vector3.new(0.3, 1.5, 0.06),
			CFrame.new(side * 0.42, 0.42, -0.53) * CFrame.Angles(0, 0, math.rad(side * -14)),
			Color3.fromRGB(34, 34, 40),
			Enum.Material.SmoothPlastic
		)
	end

	-- Brazo izquierdo fijo y derecho articulado con el arma; los dos con puño de camisa.
	local leftArm = piece(model, "BrazoIzquierdo", Vector3.new(0.85, 2.3, 0.9), jacket, fabric)
	local leftShoulder =
		joint(torso, leftArm, CFrame.new(-1.43, TORSO_HEIGHT / 2 - 0.2, 0), CFrame.new(0, 0.95, 0))
	local rightArm = piece(model, "BrazoDerecho", Vector3.new(0.85, 2.3, 0.9), jacket, fabric)
	local shoulder =
		joint(torso, rightArm, CFrame.new(1.43, TORSO_HEIGHT / 2 - 0.2, 0), CFrame.new(0, 0.95, 0))
	for _, arm in { leftArm, rightArm } do
		attach(
			model,
			arm,
			"Puno",
			Vector3.new(0.88, 0.25, 0.92),
			CFrame.new(0, -1, 0),
			shirt,
			fabric
		)
		attach(model, arm, "Mano", Vector3.new(0.7, 0.4, 0.7), CFrame.new(0, -1.3, 0), pale)
	end

	-- Bastón estoque: mango de madera rojiza, virolas doradas y hoja fina de acero.
	local gold = Color3.fromRGB(190, 150, 60)
	local hand = CFrame.new(0, -1.3, 0)
	local function sword(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material
	)
		attach(model, rightArm, name, size, hand * offset, color, material)
	end
	sword("Pomo", Vector3.new(0.42, 0.42, 0.5), CFrame.new(0, 0, 1), gold, Enum.Material.Metal)
	sword(
		"MangoBaston",
		Vector3.new(0.3, 0.3, 1.5),
		CFrame.new(0, 0, 0.1),
		Color3.fromRGB(150, 72, 30),
		Enum.Material.SmoothPlastic
	)
	sword("Virola", Vector3.new(0.36, 0.36, 0.2), CFrame.new(0, 0, -0.7), gold, Enum.Material.Metal)
	sword(
		"Estoque",
		Vector3.new(0.09, 0.14, 5),
		CFrame.new(0, 0, -3.25),
		Color3.fromRGB(175, 178, 185),
		Enum.Material.Metal
	)

	local hipOffset = -TORSO_HEIGHT / 2
	local leftLeg =
		piece(model, "PiernaIzquierda", Vector3.new(0.95, LEG_LENGTH, 0.95), jacket, fabric)
	local rightLeg =
		piece(model, "PiernaDerecha", Vector3.new(0.95, LEG_LENGTH, 0.95), jacket, fabric)
	local c1 = CFrame.new(0, LEG_LENGTH / 2, 0)
	local leftHip = joint(root, leftLeg, CFrame.new(-0.5, hipOffset, 0), c1)
	local rightHip = joint(root, rightLeg, CFrame.new(0.5, hipOffset, 0), c1)

	-- Cabeza pálida, pelo engominado y ojos hundidos.
	local headY = TORSO_HEIGHT / 2 + HEAD_HEIGHT / 2
	local head = piece(model, "Cabeza", Vector3.new(1.25, HEAD_HEIGHT, 1.1), pale)
	local neck = joint(
		torso,
		head,
		CFrame.new(0, headY - HEAD_HEIGHT / 2, 0),
		CFrame.new(0, -HEAD_HEIGHT / 2, 0)
	)
	attach(
		model,
		head,
		"Pelo",
		Vector3.new(1.32, 0.3, 1.16),
		CFrame.new(0, HEAD_HEIGHT / 2 - 0.05, 0.02),
		Color3.fromRGB(12, 10, 10),
		Enum.Material.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		attach(
			model,
			head,
			"Ojo",
			Vector3.new(0.24, 0.16, 0.05),
			CFrame.new(side * 0.3, 0.1, -0.56),
			Color3.new(0.03, 0, 0)
		)
	end
	attach(
		model,
		head,
		"Boca",
		Vector3.new(0.5, 0.06, 0.05),
		CFrame.new(0, -0.32, -0.56),
		Color3.fromRGB(70, 20, 22)
	)

	-- Sombrero de copa, guantes blancos, zapatos de charol y la cara descompuesta.
	local felt = Color3.fromRGB(12, 11, 13)
	cylinder(
		model,
		head,
		"Copa",
		Vector3.new(1.15, 1.2, 1.2),
		CFrame.new(0, HEAD_HEIGHT / 2 + 0.55, 0.02),
		felt,
		Enum.Material.Fabric
	)
	cylinder(
		model,
		head,
		"Ala",
		Vector3.new(0.1, 2, 2),
		CFrame.new(0, HEAD_HEIGHT / 2 - 0.02, 0.02),
		felt,
		Enum.Material.Fabric
	)
	cylinder(
		model,
		head,
		"CintaSombrero",
		Vector3.new(0.24, 1.24, 1.24),
		CFrame.new(0, HEAD_HEIGHT / 2 + 0.16, 0.02),
		Color3.fromRGB(96, 12, 18),
		Enum.Material.Fabric
	)
	for _, leg in { leftLeg, rightLeg } do
		local shoe = attach(
			model,
			leg,
			"Zapato",
			Vector3.new(1, 0.55, 1.4),
			CFrame.new(0, -LEG_LENGTH / 2 + 0.28, -0.22),
			Color3.fromRGB(8, 8, 10),
			Enum.Material.Plastic
		)
		shoe.Reflectance = 0.18
	end
	for _, arm in { leftArm, rightArm } do
		for _, item in arm:GetChildren() do
			if item:IsA("Motor6D") and item.Part1 and item.Part1.Name == "Mano" then
				item.Part1.Color = Color3.fromRGB(232, 230, 224)
			end
		end
	end
	-- Cara: mejillas hundidas, cuencas negras con un punto rojo, y una sonrisa cosida de oreja a oreja.
	local face = paint(head, Enum.NormalId.Front, 120)
	for _, x in { 0.2, 0.8 } do
		mark(face, x, 0.66, 0.24, 0.22, Color3.fromRGB(60, 40, 42), { alpha = 0.55, round = true })
		mark(face, x, 0.42, 0.3, 0.2, Color3.new(0, 0, 0), { alpha = 0.2, round = true })
	end
	mark(face, 0.5, 0.86, 0.66, 0.012, Color3.fromRGB(20, 8, 10))
	for i = 0, 12 do
		mark(face, 0.2 + i * 0.05, 0.86, 0.007, 0.07, Color3.fromRGB(20, 8, 10))
	end
	mark(face, 0.17, 0.83, 0.012, 0.07, Color3.fromRGB(20, 8, 10), { rotation = -25 })
	mark(face, 0.83, 0.83, 0.012, 0.07, Color3.fromRGB(20, 8, 10), { rotation = 25 })
	local glow = paint(head, Enum.NormalId.Front, 120, true)
	for _, x in { 0.26, 0.74 } do
		mark(glow, x, 0.42, 0.045, 0.04, Color3.fromRGB(255, 40, 30), { round = true })
	end
	-- Chaleco: botones dorados y la cadena del reloj.
	local vest = model:FindFirstChild("Camisa")
	if vest and vest:IsA("BasePart") then
		local vestFace = paint(vest, Enum.NormalId.Front, 160)
		for i = 0, 2 do
			mark(vestFace, 0.5, 0.22 + i * 0.24, 0.12, 0.06, gold, { round = true })
		end
		mark(vestFace, 0.38, 0.5, 0.01, 0.4, gold, { rotation = 55 })
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = LEG_LENGTH
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	weather(model)
	-- Más alto y más ancho que los otros: el doble de presencia, y el pasillo se le queda justo.
	local scale = 1.35
	model:ScaleTo(scale)
	humanoid.HipHeight = LEG_LENGTH * scale
	return {
		model = model,
		root = root,
		humanoid = humanoid,
		leftHip = leftHip,
		rightHip = rightHip,
		shoulder = shoulder,
		head = neck,
		spine = spine,
		leftShoulder = leftShoulder,
		scale = scale,
		glowPart = head,
		glowColor = Color3.fromRGB(190, 195, 210),
	}
end

-- El tercer asesino: bajito, máscara de chancho, delantal de carnicero con sangre y machete.
function KillerModel.buildButcher(): Rig
	local legLength, torsoHeight, headHeight = 2, 2, 1.2
	local shirt = Color3.fromRGB(150, 146, 136)
	local apron = Color3.fromRGB(205, 200, 186)
	local pants = Color3.fromRGB(46, 44, 42)
	local pig = Color3.fromRGB(226, 158, 158)
	local pigDark = Color3.fromRGB(150, 84, 90)
	local steel = Color3.fromRGB(165, 168, 172)
	local fabric = Enum.Material.Fabric

	local model = Instance.new("Model")
	model.Name = "AsesinoCarnicero"
	model:AddTag("Killer")

	local root = piece(model, "HumanoidRootPart", Vector3.new(2, torsoHeight, 1), shirt)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	model.PrimaryPart = root

	local torso = attach(
		model,
		root,
		"Camisa",
		Vector3.new(2, torsoHeight, 1.1),
		CFrame.identity,
		shirt,
		fabric
	)
	-- Delantal largo con pechera, tiras y manchas de sangre.
	local bib = attach(
		model,
		torso,
		"Delantal",
		Vector3.new(1.7, 2.9, 0.08),
		CFrame.new(0, -0.4, -0.6),
		apron,
		fabric
	)
	for _, stain in { { -0.35, 0.5, 0.8, 0.7 }, { 0.4, -0.3, 0.6, 1 }, { -0.2, -1, 0.9, 0.5 } } do
		attach(
			model,
			bib,
			"Mancha",
			Vector3.new(stain[3], stain[4], 0.03),
			CFrame.new(stain[1], stain[2], -0.05),
			BLOOD
		)
	end
	for _, side in { -1, 1 } do
		attach(
			model,
			torso,
			"Tira",
			Vector3.new(0.18, 0.9, 1.14),
			CFrame.new(side * 0.6, 0.65, 0),
			apron,
			fabric
		)
	end

	local leftArm = attach(
		model,
		torso,
		"BrazoIzquierdo",
		Vector3.new(0.75, 1.9, 0.8),
		CFrame.new(-1.38, 0.05, 0),
		shirt,
		fabric
	)
	local rightArm = piece(model, "BrazoDerecho", Vector3.new(0.75, 1.9, 0.8), shirt, fabric)
	local shoulder =
		joint(torso, rightArm, CFrame.new(1.38, torsoHeight / 2 - 0.15, 0), CFrame.new(0, 0.8, 0))
	for _, arm in { leftArm, rightArm } do
		attach(model, arm, "Guante", Vector3.new(0.72, 0.45, 0.72), CFrame.new(0, -1.1, 0), pigDark)
	end

	-- Machete: mango negro y hoja ancha de acero, con la punta manchada.
	local hand = CFrame.new(0, -1.1, 0)
	attach(
		model,
		rightArm,
		"MangoMachete",
		Vector3.new(0.28, 0.28, 1.2),
		hand * CFrame.new(0, 0, -0.3),
		Color3.fromRGB(16, 15, 14)
	)
	attach(
		model,
		rightArm,
		"Machete",
		Vector3.new(0.1, 0.75, 3.2),
		hand * CFrame.new(0, -0.15, -2.5),
		steel,
		Enum.Material.Metal
	)
	attach(
		model,
		rightArm,
		"SangreMachete",
		Vector3.new(0.12, 0.6, 1),
		hand * CFrame.new(0, -0.2, -3.5),
		BLOOD
	)

	local hipOffset = -torsoHeight / 2
	local leftLeg = piece(model, "PiernaIzquierda", Vector3.new(0.9, legLength, 0.9), pants, fabric)
	local rightLeg = piece(model, "PiernaDerecha", Vector3.new(0.9, legLength, 0.9), pants, fabric)
	local c1 = CFrame.new(0, legLength / 2, 0)
	local leftHip = joint(root, leftLeg, CFrame.new(-0.5, hipOffset, 0), c1)
	local rightHip = joint(root, rightLeg, CFrame.new(0.5, hipOffset, 0), c1)

	-- Máscara de chancho: cabeza rosada, trompa con fosas, orejas y ojos hundidos.
	local head = attach(
		model,
		torso,
		"Mascara",
		Vector3.new(1.4, headHeight, 1.25),
		CFrame.new(0, torsoHeight / 2 + headHeight / 2, 0),
		pig,
		fabric
	)
	local snout = attach(
		model,
		head,
		"Trompa",
		Vector3.new(0.75, 0.55, 0.4),
		CFrame.new(0, -0.15, -0.8),
		Color3.fromRGB(240, 175, 175),
		fabric
	)
	for _, side in { -1, 1 } do
		attach(
			model,
			snout,
			"Fosa",
			Vector3.new(0.14, 0.2, 0.04),
			CFrame.new(side * 0.17, 0, -0.21),
			pigDark
		)
		attach(
			model,
			head,
			"Ojo",
			Vector3.new(0.22, 0.2, 0.05),
			CFrame.new(side * 0.33, 0.25, -0.64),
			Color3.new(0.02, 0, 0)
		)
		attach(
			model,
			head,
			"Oreja",
			Vector3.new(0.45, 0.45, 0.15),
			CFrame.new(side * 0.62, 0.72, 0) * CFrame.Angles(0, 0, math.rad(side * -30)),
			pigDark,
			fabric
		)
		-- Colmillos amarillentos que salen de la boca.
		attach(
			model,
			head,
			"Colmillo",
			Vector3.new(0.12, 0.42, 0.12),
			CFrame.new(side * 0.34, -0.5, -0.66)
				* CFrame.Angles(math.rad(-12), 0, math.rad(side * 8)),
			Color3.fromRGB(226, 214, 176)
		)
	end

	-- Boca abierta bajo la trompa, botas de goma, y el machete con la hoja astillada y chorreando.
	local mouth = attach(
		model,
		head,
		"Boca",
		Vector3.new(0.72, 0.2, 0.1),
		CFrame.new(0, -0.5, -0.64),
		Color3.fromRGB(26, 6, 8)
	)
	local teeth = paint(mouth, Enum.NormalId.Front, 200)
	for i = 0, 5 do
		mark(teeth, 0.1 + i * 0.16, 0.2, 0.09, 0.4, Color3.fromRGB(214, 202, 170))
		mark(teeth, 0.18 + i * 0.13, 0.8, 0.07, 0.35, Color3.fromRGB(200, 188, 156))
	end
	for _, leg in { leftLeg, rightLeg } do
		attach(
			model,
			leg,
			"Bota",
			Vector3.new(0.98, 1, 1.25),
			CFrame.new(0, -legLength / 2 + 0.5, -0.18),
			Color3.fromRGB(20, 22, 20),
			Enum.Material.Plastic
		)
	end
	local machete = model:FindFirstChild("Machete")
	if machete and machete:IsA("BasePart") then
		drip(machete)
	end

	-- Máscara: poros, costuras, grietas, una correa de cuero con hebilla, ojos hundidos con un brillo rojo
	-- y sangre que chorrea de la boca.
	local mask = paint(head, Enum.NormalId.Front, 110)
	local pores = Random.new(7)
	for _ = 1, 40 do
		mark(
			mask,
			pores:NextNumber(0.08, 0.92),
			pores:NextNumber(0.06, 0.94),
			0.022,
			0.026,
			pigDark,
			{ alpha = 0.5, round = true }
		)
	end
	for _, eyeX in { 0.264, 0.736 } do
		mark(mask, eyeX, 0.3, 0.3, 0.3, Color3.new(0, 0, 0), { alpha = 0.3, round = true })
	end
	mark(mask, 0.5, 0.12, 1, 0.09, Color3.fromRGB(18, 14, 12))
	mark(mask, 0.88, 0.12, 0.1, 0.12, Color3.fromRGB(160, 140, 90))
	for i = 0, 5 do
		mark(mask, 0.5, 0.2 + i * 0.05, 0.012, 0.03, Color3.fromRGB(30, 14, 16))
	end
	mark(mask, 0.3, 0.45, 0.01, 0.2, Color3.fromRGB(80, 40, 44), { rotation = 28 })
	mark(mask, 0.72, 0.5, 0.01, 0.16, Color3.fromRGB(80, 40, 44), { rotation = -22 })
	for _, x in { 0.38, 0.5, 0.62 } do
		local dribble = mark(mask, x, 0.86, 0.045, 0.3, BLOOD)
		fade(dribble, 0.1, 1)
	end
	local glint = paint(head, Enum.NormalId.Front, 110, true)
	for _, eyeX in { 0.264, 0.736 } do
		mark(glint, eyeX, 0.3, 0.05, 0.05, Color3.fromRGB(255, 40, 30), { round = true })
	end
	-- Delantal: sangre que sube desde abajo, manchas viejas y huellas de manos.
	local apronFace = paint(bib, Enum.NormalId.Front, 70)
	local dirt = mark(apronFace, 0.5, 0.15, 1, 0.3, Color3.fromRGB(70, 56, 40))
	fade(dirt, 0.4, 1)
	local gore = mark(apronFace, 0.5, 0.75, 1, 0.5, BLOOD)
	fade(gore, 1, 0.05)
	for _, handprint in { { 0.3, 0.55, 20 }, { 0.65, 0.65, -15 }, { 0.5, 0.4, 5 } } do
		mark(
			apronFace,
			handprint[1],
			handprint[2],
			0.16,
			0.12,
			BLOOD,
			{ rotation = handprint[3], alpha = 0.15 }
		)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = legLength
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model

	weather(model)
	return {
		model = model,
		root = root,
		humanoid = humanoid,
		leftHip = leftHip,
		rightHip = rightHip,
		shoulder = shoulder,
		glowPart = head,
		glowColor = Color3.fromRGB(190, 195, 210),
	}
end

return KillerModel
