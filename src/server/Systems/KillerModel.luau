--!strict
-- Arma al asesino con piezas: 1,80 m, machete en la izquierda, sin brazo derecho,
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

function KillerModel.build(): Rig
	local model = Instance.new("Model")
	model.Name = "Asesino"

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

	-- Brazo izquierdo con machete, articulado para el golpe.
	local arm =
		piece(model, "BrazoIzquierdo", Vector3.new(0.9, 2.3, 0.9), SKIN, Enum.Material.Fabric)
	local shoulder =
		joint(torso, arm, CFrame.new(-1.45, TORSO_HEIGHT / 2 - 0.2, 0), CFrame.new(0, 0.95, 0))
	attach(
		model,
		arm,
		"Mango",
		Vector3.new(0.25, 0.25, 0.9),
		CFrame.new(0, -1.15, -0.3),
		Color3.fromRGB(30, 20, 14)
	)
	attach(
		model,
		arm,
		"Machete",
		Vector3.new(0.1, 0.55, 3),
		CFrame.new(0, -1.15, -2.2),
		Color3.fromRGB(120, 120, 118),
		Enum.Material.Metal
	)
	attach(
		model,
		arm,
		"SangreMachete",
		Vector3.new(0.12, 0.3, 1.1),
		CFrame.new(0, -1.05, -3.05),
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

	return {
		model = model,
		root = root,
		humanoid = humanoid,
		leftHip = leftHip,
		rightHip = rightHip,
		shoulder = shoulder,
	}
end

return KillerModel
