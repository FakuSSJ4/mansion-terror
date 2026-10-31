--!strict
-- Patio delantero, frente a la puerta principal: fuente con ángel, faroles, canteros y portón.
-- Se ve por los ventanales del hall y se cruza al escapar: la salida es el portón del fondo.

local Courtyard = {}

Courtyard.CenterX = -32
Courtyard.X0 = -78
Courtyard.X1 = 14
Courtyard.Z0 = -71
Courtyard.Z1 = -138
Courtyard.GateHalf = 8

local STONE = Color3.fromRGB(72, 68, 62)
local MARBLE = Color3.fromRGB(176, 174, 166)
local BRICK = Color3.fromRGB(78, 62, 52)
local IRON = Color3.fromRGB(18, 18, 20)
local LEAF = Color3.fromRGB(34, 66, 32)
local LAMP = Color3.fromRGB(255, 226, 170)

function Courtyard.build(ctx: any)
	local midX = Courtyard.CenterX
	local x0, x1, z0, z1 = Courtyard.X0, Courtyard.X1, Courtyard.Z0, Courtyard.Z1
	local midZ = (z0 + z1) / 2
	local width, depth = x1 - x0, z0 - z1
	local random = Random.new(11)
	local cylinderUp = CFrame.Angles(0, 0, math.rad(90))

	local function block(
		name: string,
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material
	): Part
		return ctx.part({
			Name = name,
			Size = size,
			CFrame = cframe,
			Color = color,
			Material = material,
		})
	end
	local function deco(
		name: string,
		size: Vector3,
		cframe: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	): Part
		return ctx.decor({
			Name = name,
			Size = size,
			CFrame = cframe,
			Color = color,
			Material = material,
			Shape = shape or Enum.PartType.Block,
		})
	end
	local function disc(
		name: string,
		position: Vector3,
		diameter: number,
		height: number,
		color: Color3,
		material: Enum.Material
	)
		ctx.part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, diameter, diameter),
			CFrame = CFrame.new(position) * cylinderUp,
			Color = color,
			Material = material,
		})
	end
	local function glow(parent: BasePart, range: number, brightness: number)
		local light = Instance.new("PointLight")
		light.Color = LAMP
		light.Range = range
		light.Brightness = brightness
		-- Con sombras: la luz de afuera no atraviesa las paredes del hall.
		light.Shadows = true
		light.Parent = parent
	end

	-- Piso de piedra, con un camino de lajas irregulares y canteros a los costados.
	block(
		"PisoPatio",
		Vector3.new(width + 4, 2.2, depth + 4),
		CFrame.new(midX, -0.9, midZ - 2),
		Color3.fromRGB(52, 50, 46),
		Enum.Material.Slate
	)
	for z = z0 - 3, z1 + 3, -6 do
		for _, offset in { -6, 0, 6 } do
			local shade = random:NextInteger(58, 84)
			deco(
				"Laja",
				Vector3.new(5.7, 0.06, 5.7),
				CFrame.new(midX + offset, 0.22, z)
					* CFrame.Angles(0, math.rad(random:NextNumber(-3, 3)), 0),
				Color3.fromRGB(shade, shade - 3, shade - 8),
				Enum.Material.Cobblestone
			)
		end
	end
	for _, side in { -1, 1 } do
		local bedX = midX + side * (width / 2 - 9)
		deco(
			"Cantero",
			Vector3.new(16, 0.3, depth - 8),
			CFrame.new(bedX, 0.3, midZ),
			Color3.fromRGB(30, 46, 26),
			Enum.Material.Grass
		)
		-- Ligustrina pegada al muro.
		block(
			"Ligustrina",
			Vector3.new(3, 7, depth - 8),
			CFrame.new(midX + side * (width / 2 - 2.5), 3.6, midZ),
			LEAF,
			Enum.Material.Grass
		)
		-- Muro lateral con remate.
		block(
			"MuroPatio",
			Vector3.new(2, 15, depth),
			CFrame.new(midX + side * (width / 2 + 1), 7.5, midZ),
			BRICK,
			Enum.Material.Brick
		)
		deco(
			"RemateMuro",
			Vector3.new(3, 0.8, depth),
			CFrame.new(midX + side * (width / 2 + 1), 15.4, midZ),
			STONE,
			Enum.Material.Concrete
		)
		for _ = 1, 15 do
			local size = random:NextNumber(3.5, 7.5)
			deco(
				"Arbusto",
				Vector3.one * size,
				CFrame.new(
					bedX + random:NextNumber(-7, 6),
					size * 0.38,
					random:NextNumber(z1 + 8, z0 - 6)
				),
				Color3.fromRGB(30, random:NextInteger(58, 84), 32),
				Enum.Material.Grass,
				Enum.PartType.Ball
			)
		end
	end

	-- Muro del fondo y portón abierto, con pilares, faroles y hojas de hierro.
	local gateHalf = Courtyard.GateHalf
	for _, side in { -1, 1 } do
		local length = width / 2 + 2 - gateHalf
		local centerX = midX + side * (gateHalf + length / 2)
		block(
			"MuroPatio",
			Vector3.new(length, 15, 2),
			CFrame.new(centerX, 7.5, z1 - 1),
			BRICK,
			Enum.Material.Brick
		)
		deco(
			"RemateMuro",
			Vector3.new(length, 0.8, 3),
			CFrame.new(centerX, 15.4, z1 - 1),
			STONE,
			Enum.Material.Concrete
		)
		local pillarX = midX + side * (gateHalf + 1.5)
		block(
			"PilarPorton",
			Vector3.new(3.4, 19, 3.4),
			CFrame.new(pillarX, 9.5, z1 - 1),
			STONE,
			Enum.Material.Concrete
		)
		deco(
			"BolaPilar",
			Vector3.one * 2.8,
			CFrame.new(pillarX, 20.2, z1 - 1),
			MARBLE,
			Enum.Material.Marble,
			Enum.PartType.Ball
		)
		-- Hoja abierta hacia adentro, contra el cantero.
		local hinge = CFrame.new(midX + side * gateHalf, 0, z1 + 0.5)
		for i = 0, 7 do
			deco(
				"BarrotePorton",
				Vector3.new(0.22, 13, 0.22),
				hinge * CFrame.new(0, 6.5, i * 1),
				IRON,
				Enum.Material.Metal
			)
		end
		for _, y in { 1, 7, 12.6 } do
			deco(
				"TravesanoPorton",
				Vector3.new(0.2, 0.3, 7.6),
				hinge * CFrame.new(0, y, 3.5),
				IRON,
				Enum.Material.Metal
			)
		end
	end

	-- Fuente: base, borde, agua y pedestal escalonado.
	local fountain = Vector3.new(midX, 0, midZ - 1)
	disc("BaseFuente", fountain + Vector3.new(0, 0.6, 0), 34, 1.2, STONE, Enum.Material.Concrete)
	disc("BordeFuente", fountain + Vector3.new(0, 2, 0), 28, 2.4, MARBLE, Enum.Material.Concrete)
	deco(
		"AguaFuente",
		Vector3.new(0.2, 25.5, 25.5),
		CFrame.new(fountain + Vector3.new(0, 3.25, 0)) * cylinderUp,
		Color3.fromRGB(26, 44, 54),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	block(
		"PedestalBajo",
		Vector3.new(11, 3, 11),
		CFrame.new(fountain + Vector3.new(0, 4.5, 0)),
		STONE,
		Enum.Material.Concrete
	)
	block(
		"PedestalAlto",
		Vector3.new(7, 6, 7),
		CFrame.new(fountain + Vector3.new(0, 9, 0)),
		MARBLE,
		Enum.Material.Concrete
	)
	block(
		"CapitelPedestal",
		Vector3.new(9, 1, 9),
		CFrame.new(fountain + Vector3.new(0, 12.5, 0)),
		STONE,
		Enum.Material.Concrete
	)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		deco(
			"UrnaFuente",
			Vector3.new(2.2, 2.4, 2.2),
			CFrame.new(fountain + Vector3.new(corner[1] * 4.6, 7.2, corner[2] * 4.6)),
			MARBLE,
			Enum.Material.Marble,
			Enum.PartType.Ball
		)
	end

	-- Ángel de túnica sobre el pedestal, mirando a la puerta de la casa, con las alas abiertas.
	local angel = CFrame.lookAt(fountain + Vector3.new(0, 13, 0), fountain + Vector3.new(0, 13, 1))
	local function stone(name: string, size: Vector3, offset: CFrame, shape: Enum.PartType?)
		deco(name, size, angel * offset, MARBLE, Enum.Material.Marble, shape)
	end
	-- Túnica que se angosta hacia los hombros.
	for i, section in { { 6.4, 0 }, { 5.4, 3 }, { 4.5, 6 }, { 3.8, 9 } } do
		stone(
			`Tunica{i}`,
			Vector3.new(3.2, section[1], section[1]),
			CFrame.new(0, section[2] + 1.6, 0) * cylinderUp,
			Enum.PartType.Cylinder
		)
	end
	stone("Hombros", Vector3.new(5, 2, 2.8), CFrame.new(0, 12.6, 0))
	stone("Cuello", Vector3.new(1, 1, 1), CFrame.new(0, 14, 0))
	stone("CabezaAngel", Vector3.one * 2.5, CFrame.new(0, 15.6, -0.1), Enum.PartType.Ball)
	stone("Velo", Vector3.new(2.9, 3.4, 1.4), CFrame.new(0, 14.9, 0.8))
	stone(
		"Aureola",
		Vector3.new(0.3, 4.4, 4.4),
		CFrame.new(0, 17.6, 0.3) * cylinderUp,
		Enum.PartType.Cylinder
	)
	-- Brazos juntos adelante, en oración.
	for _, side in { -1, 1 } do
		stone(
			"BrazoAngel",
			Vector3.new(0.9, 3.6, 0.9),
			CFrame.new(side * 1.2, 11, -1.9) * CFrame.Angles(math.rad(50), 0, math.rad(side * 28))
		)
		-- Ala: plumas cada vez más largas y abiertas hacia afuera.
		for i = 1, 6 do
			stone(
				"Pluma",
				Vector3.new(1.5, 7 + i * 1.5, 0.5),
				CFrame.new(side * (1.6 + i * 1.35), 12 + i * 0.75, 1.3)
					* CFrame.Angles(0, 0, math.rad(side * -(i * 7)))
			)
		end
	end
	-- Luz baja que le da a la estatua desde el agua.
	local uplight = deco(
		"LuzEstatua",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(fountain + Vector3.new(0, 9, -9)),
		LAMP,
		Enum.Material.SmoothPlastic
	)
	uplight.Transparency = 1
	glow(uplight, 30, 1.5)

	-- Cuatro faroles de hierro alrededor de la fuente.
	for _, lamp in { { -24, -86 }, { 24, -86 }, { -24, -122 }, { 24, -122 } } do
		local x = midX + lamp[1]
		block(
			"BaseFarol",
			Vector3.new(2, 1.6, 2),
			CFrame.new(x, 1, lamp[2]),
			IRON,
			Enum.Material.Metal
		)
		block(
			"PosteFarol",
			Vector3.new(0.7, 13, 0.7),
			CFrame.new(x, 7, lamp[2]),
			IRON,
			Enum.Material.Metal
		)
		deco(
			"TechoFarol",
			Vector3.new(2.4, 0.4, 2.4),
			CFrame.new(x, 15.9, lamp[2]),
			IRON,
			Enum.Material.Metal
		)
		glow(
			deco(
				"LuzFarol",
				Vector3.one * 2,
				CFrame.new(x, 14.6, lamp[2]),
				LAMP,
				Enum.Material.Neon,
				Enum.PartType.Ball
			),
			28,
			1.2
		)
	end

	-- Portal de la casa: columnas, dintel, faroles y dos figuras sobre pedestal.
	for _, side in { -1, 1 } do
		local x = midX + side * 10.5
		ctx.part({
			Name = "ColumnaPortal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(20, 3, 3),
			CFrame = CFrame.new(x, 10, z0 - 5) * cylinderUp,
			Color = MARBLE,
			Material = Enum.Material.Concrete,
		})
		glow(
			deco(
				"FarolPortal",
				Vector3.new(1.2, 1.8, 1.2),
				CFrame.new(midX + side * 8, 11, z0 - 0.8),
				LAMP,
				Enum.Material.Neon
			),
			20,
			1
		)
		local statueX = midX + side * 24
		block(
			"PedestalFigura",
			Vector3.new(5, 5, 5),
			CFrame.new(statueX, 2.5, z0 - 6),
			STONE,
			Enum.Material.Concrete
		)
		deco(
			"CuerpoFigura",
			Vector3.new(2.6, 5, 2.2),
			CFrame.new(statueX, 7.5, z0 - 6),
			Color3.fromRGB(96, 96, 98),
			Enum.Material.Metal
		)
		deco(
			"CabezaFigura",
			Vector3.one * 1.6,
			CFrame.new(statueX, 10.8, z0 - 6),
			Color3.fromRGB(96, 96, 98),
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		-- Macetones con plantas a los costados del camino.
		for _, z in { z0 - 20, z1 + 14 } do
			local potX = midX + side * 12
			block(
				"Maceton",
				Vector3.new(3.4, 3, 3.4),
				CFrame.new(potX, 1.7, z),
				Color3.fromRGB(66, 42, 32),
				Enum.Material.Concrete
			)
			deco(
				"PlantaMaceton",
				Vector3.one * 5,
				CFrame.new(potX, 5, z),
				LEAF,
				Enum.Material.Grass,
				Enum.PartType.Ball
			)
		end
	end
	block(
		"DintelPortal",
		Vector3.new(26, 2.4, 9),
		CFrame.new(midX, 21.2, z0 - 4.5),
		STONE,
		Enum.Material.Concrete
	)

	-- Hojas secas y escombros, como un patio abandonado.
	for _ = 1, 40 do
		local size = random:NextNumber(0.5, 1.2)
		deco(
			"HojaSeca",
			Vector3.new(size, 0.04, size * 0.7),
			CFrame.new(midX + random:NextNumber(-18, 22), 0.3, random:NextNumber(z1 + 3, z0 - 30))
				* CFrame.Angles(0, random:NextNumber(0, 6), 0),
			Color3.fromRGB(random:NextInteger(90, 130), random:NextInteger(60, 85), 30),
			Enum.Material.Grass
		)
	end
	for _ = 1, 7 do
		deco(
			"Escombro",
			Vector3.new(random:NextNumber(1, 2.6), 0.5, random:NextNumber(1, 2)),
			CFrame.new(midX + random:NextNumber(10, 21), 0.45, random:NextNumber(z1 + 5, z1 + 18))
				* CFrame.Angles(random:NextNumber(-0.25, 0.25), random:NextNumber(0, 6), 0),
			STONE,
			Enum.Material.Slate
		)
	end

	ctx.rainOutside({
		position = Vector3.new(midX, 16, midZ + 7),
		width = width - 26,
		height = 32,
		depth = depth,
		horizontal = true,
		outward = Vector3.new(0, 0, -1),
	})
end

return Courtyard
