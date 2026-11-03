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
	-- Texto dibujado sobre una cara (la pieza queda invisible): dos renglones en vertical.
	label: { face: Enum.NormalId, lines: { string } }?,
}

local function piece(
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	extra: {
		shape: Enum.PartType?,
		reflectance: number?,
		transparency: number?,
		label: { face: Enum.NormalId, lines: { string } }?,
	}?
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
		label = if extra then extra.label else nil,
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
	local label = spec.label
	if label then
		-- Lienzo de 72 x 116 px: los renglones van de abajo hacia arriba, uno al lado del otro.
		local gui = Instance.new("SurfaceGui")
		gui.Face = label.face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(72, 116)
		gui.LightInfluence = 1
		gui.Parent = part
		local flip = label.face == Enum.NormalId.Left
		for index, line in label.lines do
			local text = Instance.new("TextLabel")
			text.AnchorPoint = Vector2.new(0.5, 0.5)
			text.Position = UDim2.fromOffset(if index == 1 then 26 else 51, 58)
			text.Size = UDim2.fromOffset(112, 28)
			text.Rotation = if flip then 90 else -90
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamBlack
			text.TextSize = if index == 1 then 24 else 16
			text.TextColor3 = Color3.new(1, 1, 1)
			text.Text = line
			text.Parent = gui
		end
	end
end

local WHITE = Color3.fromRGB(252, 252, 252)
local RED = Color3.fromRGB(200, 34, 40)

-- Botiquín rojo con cruz blanca, cierres plateados y asa. Mira a -Z; la tapa va hacia arriba.
function ItemModels.medkit(): { Piece }
	local pieces = {
		piece(
			"Caja",
			Vector3.new(1, 0.62, 0.54),
			CFrame.new(),
			RED,
			Enum.Material.SmoothPlastic,
			{ reflectance = 0.06 }
		),
		piece(
			"Tapa",
			Vector3.new(1.04, 0.09, 0.58),
			CFrame.new(0, 0.155, 0),
			Color3.fromRGB(165, 22, 28),
			Enum.Material.SmoothPlastic
		),
		piece(
			"CruzVertical",
			Vector3.new(0.14, 0.38, 0.03),
			CFrame.new(0, 0, -0.285),
			WHITE,
			Enum.Material.SmoothPlastic
		),
		piece(
			"CruzHorizontal",
			Vector3.new(0.38, 0.14, 0.03),
			CFrame.new(0, 0, -0.285),
			WHITE,
			Enum.Material.SmoothPlastic
		),
		piece(
			"CruzArribaA",
			Vector3.new(0.14, 0.03, 0.38),
			CFrame.new(0, 0.215, 0),
			WHITE,
			Enum.Material.SmoothPlastic
		),
		piece(
			"CruzArribaB",
			Vector3.new(0.38, 0.03, 0.14),
			CFrame.new(0, 0.215, 0),
			WHITE,
			Enum.Material.SmoothPlastic
		),
		piece(
			"Asa",
			Vector3.new(0.46, 0.05, 0.09),
			CFrame.new(0, 0.25, 0.19),
			RUBBER,
			Enum.Material.SmoothPlastic
		),
	}
	for _, x in { -0.34, 0.34 } do
		table.insert(
			pieces,
			piece(
				"Cierre",
				Vector3.new(0.1, 0.1, 0.04),
				CFrame.new(x, 0.13, -0.29),
				STEEL,
				Enum.Material.Metal
			)
		)
	end
	return pieces
end

-- Vendas, todo blanco: un rollo con la punta suelta y un parche con gasa al lado. Acostado.
function ItemModels.bandage(): { Piece }
	local paper = Color3.fromRGB(246, 246, 246)
	return {
		piece(
			"Rollo",
			Vector3.new(0.5, 0.7, 0.7),
			CFrame.new(0, 0, 0),
			WHITE,
			Enum.Material.SmoothPlastic,
			CYLINDER
		),
		piece(
			"Centro",
			Vector3.new(0.52, 0.24, 0.24),
			CFrame.new(0, 0, 0),
			Color3.fromRGB(214, 214, 218),
			Enum.Material.SmoothPlastic,
			CYLINDER
		),
		piece(
			"PuntaSuelta",
			Vector3.new(0.5, 0.04, 0.8),
			CFrame.new(0, -0.35, -0.42),
			WHITE,
			Enum.Material.SmoothPlastic
		),
		piece(
			"Parche",
			Vector3.new(0.5, 0.06, 0.5),
			CFrame.new(0.7, -0.32, 0.05),
			paper,
			Enum.Material.SmoothPlastic
		),
		piece(
			"Gasa",
			Vector3.new(0.3, 0.08, 0.3),
			CFrame.new(0.7, -0.29, 0.05),
			WHITE,
			Enum.Material.SmoothPlastic
		),
		piece(
			"Cinta",
			Vector3.new(0.5, 0.05, 0.1),
			CFrame.new(0.7, -0.3, 0.05),
			paper,
			Enum.Material.SmoothPlastic
		),
	}
end

-- Pila alcalina grande (tipo Rayovac): cuerpo azul con "RAYOVAC ALCALINA", banda roja con filete
-- blanco, parte de arriba plateada con el polo. Parada; los cilindros giran para quedar a lo largo de Y.
function ItemModels.battery(): { Piece }
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local blue = Color3.fromRGB(26, 62, 150)
	local silver = Color3.fromRGB(204, 207, 214)
	local pieces = {
		piece(
			"Cuerpo",
			Vector3.new(0.62, 0.6, 0.6),
			CFrame.new(0, -0.19, 0) * upright,
			blue,
			Enum.Material.SmoothPlastic,
			{ shape = Enum.PartType.Cylinder, reflectance = 0.1 }
		),
		piece(
			"Plata",
			Vector3.new(0.36, 0.6, 0.6),
			CFrame.new(0, 0.3, 0) * upright,
			silver,
			Enum.Material.Metal,
			{ shape = Enum.PartType.Cylinder, reflectance = 0.35 }
		),
		piece(
			"Banda",
			Vector3.new(0.07, 0.606, 0.606),
			CFrame.new(0, 0.12, 0) * upright,
			Color3.fromRGB(208, 30, 54),
			Enum.Material.SmoothPlastic,
			CYLINDER
		),
		piece(
			"Filete",
			Vector3.new(0.018, 0.608, 0.608),
			CFrame.new(0, 0.073, 0) * upright,
			WHITE,
			Enum.Material.SmoothPlastic,
			CYLINDER
		),
		piece(
			"Polo",
			Vector3.new(0.07, 0.22, 0.22),
			CFrame.new(0, 0.515, 0) * upright,
			Color3.fromRGB(190, 192, 198),
			Enum.Material.Metal,
			{ shape = Enum.PartType.Cylinder, reflectance = 0.3 }
		),
		piece(
			"Base",
			Vector3.new(0.03, 0.58, 0.58),
			CFrame.new(0, -0.485, 0) * upright,
			Color3.fromRGB(14, 30, 70),
			Enum.Material.SmoothPlastic,
			CYLINDER
		),
	}
	-- El texto, a los dos lados del cuerpo.
	for _, side in
		{ { x = 0.305, face = Enum.NormalId.Right }, { x = -0.305, face = Enum.NormalId.Left } }
	do
		table.insert(
			pieces,
			piece(
				"Etiqueta",
				Vector3.new(0.02, 0.58, 0.36),
				CFrame.new(side.x, -0.19, 0),
				WHITE,
				Enum.Material.SmoothPlastic,
				{
					transparency = 1,
					label = { face = side.face, lines = { "RAYOVAC", "ALCALINA" } },
				}
			)
		)
	end
	return pieces
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
