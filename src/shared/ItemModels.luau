--!strict
-- Taser y linterna armados con piezas. Se usan igual en el suelo, en el pedestal, en la mano
-- en primera persona y en los íconos de la barra de objetos.
-- El largo va por el eje Z y el frente (boca del taser, lente de la linterna) mira a -Z.

local ItemModels = {}

export type Piece = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?,
	reflectance: number?,
	transparency: number?,
}

local function piece(
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	extra: { shape: Enum.PartType?, reflectance: number?, transparency: number? }?
): Piece
	return {
		name = name,
		size = size,
		offset = offset,
		color = color,
		material = material,
		shape = if extra then extra.shape else nil,
		reflectance = if extra then extra.reflectance else nil,
		transparency = if extra then extra.transparency else nil,
	}
end

-- Los cilindros de Roblox van por X; este giro los acuesta a lo largo de Z.
local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)
local CYLINDER = { shape = Enum.PartType.Cylinder }

local YELLOW = Color3.fromRGB(238, 190, 28)
local BLACK = Color3.fromRGB(26, 26, 28)
local RUBBER = Color3.fromRGB(38, 38, 42)
local STEEL = Color3.fromRGB(150, 152, 158)
local ARC = Color3.fromRGB(150, 210, 255)

-- Pistola eléctrica: carcasa amarilla, empuñadura de goma, cartucho negro y dos electrodos.
function ItemModels.taser(): { Piece }
	local pieces = {
		piece(
			"Carcasa",
			Vector3.new(0.26, 0.34, 0.86),
			CFrame.new(),
			YELLOW,
			Enum.Material.SmoothPlastic,
			{ reflectance = 0.08 }
		),
		piece(
			"Empunadura",
			Vector3.new(0.25, 0.58, 0.28),
			CFrame.new(0, -0.42, 0.24) * CFrame.Angles(math.rad(-14), 0, 0),
			RUBBER,
			Enum.Material.Plastic
		),
		piece(
			"Cartucho",
			Vector3.new(0.22, 0.24, 0.26),
			CFrame.new(0, 0.02, -0.5),
			BLACK,
			Enum.Material.SmoothPlastic
		),
		piece(
			"GuardaGatillo",
			Vector3.new(0.05, 0.05, 0.3),
			CFrame.new(0, -0.22, -0.02),
			BLACK,
			Enum.Material.SmoothPlastic
		),
		piece(
			"Gatillo",
			Vector3.new(0.06, 0.16, 0.06),
			CFrame.new(0, -0.14, 0.04) * CFrame.Angles(math.rad(12), 0, 0),
			STEEL,
			Enum.Material.Metal
		),
		piece(
			"MiraLaser",
			Vector3.new(0.07, 0.07, 0.16),
			CFrame.new(0, 0.2, -0.3),
			BLACK,
			Enum.Material.SmoothPlastic
		),
		piece(
			"PuntoLaser",
			Vector3.new(0.05, 0.05, 0.05),
			CFrame.new(0, 0.2, -0.39),
			Color3.fromRGB(255, 40, 40),
			Enum.Material.Neon,
			{ shape = Enum.PartType.Ball }
		),
		piece(
			"Bateria",
			Vector3.new(0.27, 0.05, 0.3),
			CFrame.new(0, 0.12, 0.2),
			Color3.fromRGB(60, 220, 110),
			Enum.Material.Neon
		),
	}
	-- Franjas de agarre en la empuñadura.
	for i = 0, 3 do
		table.insert(
			pieces,
			piece(
				"Surco",
				Vector3.new(0.27, 0.035, 0.22),
				CFrame.new(0, -0.3 - i * 0.1, 0.22 + i * 0.025) * CFrame.Angles(math.rad(-14), 0, 0),
				BLACK,
				Enum.Material.SmoothPlastic
			)
		)
	end
	-- Los dos electrodos de la boca y sus puntas que chispean.
	for _, side in { -1, 1 } do
		table.insert(
			pieces,
			piece(
				"Electrodo",
				Vector3.new(0.14, 0.035, 0.035),
				CFrame.new(side * 0.075, 0.06, -0.66) * ALONG_Z,
				STEEL,
				Enum.Material.Metal,
				CYLINDER
			)
		)
		table.insert(
			pieces,
			piece(
				"PuntaElectrodo",
				Vector3.new(0.05, 0.05, 0.05),
				CFrame.new(side * 0.075, 0.06, -0.74),
				ARC,
				Enum.Material.Neon,
				{ shape = Enum.PartType.Ball }
			)
		)
	end
	return pieces
end

-- Linterna de metal: cuerpo oscuro con aros de agarre, cabezal plateado, lente y botón rojo.
function ItemModels.flashlight(): { Piece }
	local body = Color3.fromRGB(46, 48, 54)
	local pieces = {
		piece(
			"Cuerpo",
			Vector3.new(0.78, 0.24, 0.24),
			ALONG_Z,
			body,
			Enum.Material.Metal,
			{ shape = Enum.PartType.Cylinder, reflectance = 0.2 }
		),
		piece(
			"Cabezal",
			Vector3.new(0.34, 0.38, 0.38),
			CFrame.new(0, 0, -0.5) * ALONG_Z,
			Color3.fromRGB(176, 178, 184),
			Enum.Material.Metal,
			{ shape = Enum.PartType.Cylinder, reflectance = 0.35 }
		),
		piece(
			"Aro",
			Vector3.new(0.05, 0.42, 0.42),
			CFrame.new(0, 0, -0.69) * ALONG_Z,
			Color3.fromRGB(30, 30, 34),
			Enum.Material.Metal,
			CYLINDER
		),
		piece(
			"Lente",
			Vector3.new(0.03, 0.34, 0.34),
			CFrame.new(0, 0, -0.705) * ALONG_Z,
			Color3.fromRGB(255, 238, 200),
			Enum.Material.Glass,
			{ shape = Enum.PartType.Cylinder, reflectance = 0.3, transparency = 0.25 }
		),
		piece(
			"Tapa",
			Vector3.new(0.09, 0.27, 0.27),
			CFrame.new(0, 0, 0.42) * ALONG_Z,
			Color3.fromRGB(30, 30, 34),
			Enum.Material.Metal,
			CYLINDER
		),
		piece(
			"Boton",
			Vector3.new(0.1, 0.06, 0.12),
			CFrame.new(0, 0.14, 0.14),
			Color3.fromRGB(180, 38, 38),
			Enum.Material.SmoothPlastic
		),
		piece(
			"Correa",
			Vector3.new(0.04, 0.04, 0.16),
			CFrame.new(0, -0.14, 0.42),
			RUBBER,
			Enum.Material.Fabric
		),
	}
	-- Aros de agarre a lo largo del cuerpo.
	for i = 0, 4 do
		table.insert(
			pieces,
			piece(
				"AroAgarre",
				Vector3.new(0.035, 0.265, 0.265),
				CFrame.new(0, 0, -0.18 + i * 0.1) * ALONG_Z,
				Color3.fromRGB(22, 22, 26),
				Enum.Material.Metal,
				CYLINDER
			)
		)
	end
	return pieces
end

local function setup(part: Part, spec: Piece)
	part.Name = spec.name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = spec.shape or Enum.PartType.Block
	part.Size = spec.size
	part.Color = spec.color
	part.Material = spec.material
	part.Reflectance = spec.reflectance or 0
	part.Transparency = spec.transparency or 0
end

-- Convierte `item` en la pieza principal y le cuelga el resto; queda donde estaba.
function ItemModels.apply(item: Part, pieces: { Piece })
	local origin = item.CFrame
	local name = item.Name
	setup(item, pieces[1])
	item.Name = name
	item.CFrame = origin * pieces[1].offset
	for i = 2, #pieces do
		local part = Instance.new("Part")
		setup(part, pieces[i])
		part.CFrame = origin * pieces[i].offset
		part.Parent = item
	end
end

-- Modelo suelto, con la primera pieza como PrimaryPart. Para la mano y los íconos.
function ItemModels.model(pieces: { Piece }): Model
	local model = Instance.new("Model")
	for i, spec in pieces do
		local part = Instance.new("Part")
		setup(part, spec)
		part.CFrame = spec.offset
		part.Parent = model
		if i == 1 then
			model.PrimaryPart = part
		end
	end
	return model
end

return ItemModels
