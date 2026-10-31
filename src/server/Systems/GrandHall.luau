--!strict
-- El hall principal: doble altura, escalera imperial, galería con baranda y columnas.
-- `ctx` trae las piezas de construcción de Mansion. Los detalles van con pocas partes.

local GrandHall = {}

-- Rectángulo del hall, en coordenadas del mundo.
GrandHall.X0 = -92
GrandHall.X1 = 28
GrandHall.Z0 = -70
GrandHall.Z1 = 28
GrandHall.CenterX = -32
-- Frente de la galería (primer piso) y tramos de la escalera.
GrandHall.GalleryZ = -8
GrandHall.FlightZ0 = -50
GrandHall.FlightWest = { x0 = -82, x1 = -66 }
GrandHall.FlightEast = { x0 = 2, x1 = 18 }

local TOP = 40
local FLOOR = 20
local WINDOW_BOTTOM = 4
local WINDOW_TOP = 34

function GrandHall.build(ctx: any)
	local X0, X1, Z0, Z1 = GrandHall.X0, GrandHall.X1, GrandHall.Z0, GrandHall.Z1
	local midX = GrandHall.CenterX
	local galleryZ = GrandHall.GalleryZ
	local wallColor, floorColor, ceilingColor = ctx.WALL_COLOR, ctx.FLOOR_COLOR, ctx.CEILING_COLOR
	local wood, gold = ctx.WOOD_COLOR, ctx.GOLD_COLOR
	local columnColor = Color3.fromRGB(190, 190, 182)

	local function box(
		x0: number,
		y0: number,
		z0: number,
		x1: number,
		y1: number,
		z1: number,
		color: Color3,
		material: Enum.Material,
		name: string
	): Part
		return ctx.part({
			Name = name,
			Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0),
			Position = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
			Color = color,
			Material = material,
		})
	end
	local function wallBox(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number)
		box(x0, y0, z0, x1, y1, z1, wallColor, Enum.Material.Concrete, "Pared")
	end

	-- Pisos y techos.
	box(X0 - 1, -1, Z0 - 1, X1 + 1, 0, Z1 + 1, floorColor, Enum.Material.WoodPlanks, "PisoHall")
	box(X0 - 1, TOP, Z0 - 1, X1 + 1, TOP + 1, Z1 + 1, ceilingColor, Enum.Material.Wood, "TechoHall")
	box(
		X0,
		FLOOR - 2,
		galleryZ,
		X1,
		FLOOR - 1,
		Z1,
		ceilingColor,
		Enum.Material.Wood,
		"TechoBajoGaleria"
	)
	box(X0, FLOOR - 1, galleryZ, X1, FLOOR, Z1, floorColor, Enum.Material.WoodPlanks, "PisoGaleria")

	-- Ventanal alto con parteluz y remate redondo, que simula un arco con dos discos.
	local function tallWindow(center: Vector3, outward: Vector3, width: number)
		local horizontal = outward.Z ~= 0
		local height = WINDOW_TOP - WINDOW_BOTTOM
		local middle = center + Vector3.new(0, (WINDOW_BOTTOM + WINDOW_TOP) / 2, 0)
		ctx.part({
			Name = "Ventanal",
			Size = if horizontal
				then Vector3.new(width, height, 0.3)
				else Vector3.new(0.3, height, width),
			Position = middle,
			Color = Color3.fromRGB(90, 110, 140),
			-- El material Glass oculta las partículas que hay detrás: la lluvia no se vería.
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.88,
		})
		local along = if horizontal then Vector3.xAxis else Vector3.zAxis
		for _, offset in { -width / 6, width / 6 } do
			ctx.decor({
				Name = "Parteluz",
				Size = if horizontal
					then Vector3.new(0.5, height, 0.5)
					else Vector3.new(0.5, height, 0.5),
				Position = middle + along * offset,
				Color = wood,
				Material = Enum.Material.Wood,
			})
		end
		local head = center + Vector3.new(0, WINDOW_TOP, 0) - outward * 0.7
		local turn = if horizontal then CFrame.Angles(0, math.rad(90), 0) else CFrame.identity
		ctx.decor({
			Name = "MarcoArco",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, width + 2, width + 2),
			CFrame = CFrame.new(head) * turn,
			Color = wood,
			Material = Enum.Material.Wood,
		})
		ctx.decor({
			Name = "VidrioArco",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, width, width),
			CFrame = CFrame.new(head - outward * 0.1) * turn,
			Color = Color3.fromRGB(38, 48, 68),
			Material = Enum.Material.Glass,
		})
		ctx.rainOutside({
			position = middle,
			width = width,
			height = height,
			horizontal = horizontal,
			outward = outward,
		})
	end

	-- Pared norte: puerta principal y dos ventanales.
	local doorHalf, doorTop = 7, 15
	local north = { z0 = Z0 - 1, z1 = Z0 }
	local windowHalf = 10
	local leftWindow, rightWindow = midX - 34, midX + 34
	wallBox(X0 - 1, 0, north.z0, leftWindow - windowHalf, TOP, north.z1)
	wallBox(leftWindow + windowHalf, 0, north.z0, midX - doorHalf, TOP, north.z1)
	wallBox(midX + doorHalf, 0, north.z0, rightWindow - windowHalf, TOP, north.z1)
	wallBox(rightWindow + windowHalf, 0, north.z0, X1 + 1, TOP, north.z1)
	wallBox(midX - doorHalf, doorTop, north.z0, midX + doorHalf, TOP, north.z1)
	for _, x in { leftWindow, rightWindow } do
		wallBox(x - windowHalf, 0, north.z0, x + windowHalf, WINDOW_BOTTOM, north.z1)
		wallBox(x - windowHalf, WINDOW_TOP, north.z0, x + windowHalf, TOP, north.z1)
		tallWindow(Vector3.new(x, 0, Z0 - 0.5), Vector3.new(0, 0, -1), 2 * windowHalf)
	end

	-- Pared sur, maciza.
	wallBox(X0 - 1, 0, Z1, X1 + 1, TOP, Z1 + 1)

	-- Pared oeste con un ventanal.
	local sideWindow = -38
	wallBox(X0 - 1, 0, Z0, X0, TOP, sideWindow - windowHalf)
	wallBox(X0 - 1, 0, sideWindow + windowHalf, X0, TOP, Z1)
	wallBox(X0 - 1, 0, sideWindow - windowHalf, X0, WINDOW_BOTTOM, sideWindow + windowHalf)
	wallBox(X0 - 1, WINDOW_TOP, sideWindow - windowHalf, X0, TOP, sideWindow + windowHalf)
	tallWindow(Vector3.new(X0 - 0.5, 0, sideWindow), Vector3.new(-1, 0, 0), 2 * windowHalf)

	-- Pared este: ventanal y los dos pasillos, en planta baja y en la galería.
	local hole = 6
	local holeHeight = ctx.CORRIDOR_HEIGHT
	wallBox(X1, 0, Z0, X1 + 1, TOP, sideWindow - windowHalf)
	wallBox(X1, 0, sideWindow + windowHalf, X1 + 1, TOP, -hole)
	wallBox(X1, 0, hole, X1 + 1, TOP, Z1)
	wallBox(X1, 0, sideWindow - windowHalf, X1 + 1, WINDOW_BOTTOM, sideWindow + windowHalf)
	wallBox(X1, WINDOW_TOP, sideWindow - windowHalf, X1 + 1, TOP, sideWindow + windowHalf)
	wallBox(X1, holeHeight, -hole, X1 + 1, FLOOR, hole)
	wallBox(X1, FLOOR + holeHeight, -hole, X1 + 1, TOP, hole)
	tallWindow(Vector3.new(X1 + 0.5, 0, sideWindow), Vector3.new(1, 0, 0), 2 * windowHalf)

	-- Molduras: una franja oscura a media altura y zócalo, sin agregar geometría compleja.
	for _, band in { { 0, 1.6 }, { FLOOR - 2, FLOOR }, { TOP - 2, TOP } } do
		local color = if band[1] == 0 then wood else gold
		ctx.decor({
			Name = "Moldura",
			Size = Vector3.new(X1 - X0, band[2] - band[1], 0.4),
			Position = Vector3.new(midX, (band[1] + band[2]) / 2, Z1 - 0.2),
			Color = color,
			Material = Enum.Material.Wood,
		})
	end

	-- Columnas con base y capitel.
	local function column(x: number, z: number, bottom: number, top: number, radius: number)
		local height = top - bottom
		ctx.part({
			Name = "Columna",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, radius * 2, radius * 2),
			CFrame = CFrame.new(x, bottom + height / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = columnColor,
			Material = Enum.Material.Marble,
		})
		local slab = Vector3.new(radius * 2 + 1.6, 1.2, radius * 2 + 1.6)
		for _, y in { bottom + 0.6, top - 0.6 } do
			ctx.part({
				Name = "BaseColumna",
				Size = slab,
				Position = Vector3.new(x, y, z),
				Color = columnColor,
				Material = Enum.Material.Marble,
			})
		end
	end
	for _, x in { midX - 24, midX - 8, midX + 8, midX + 24 } do
		column(x, galleryZ, 0, FLOOR - 2, 2.2)
		column(x, galleryZ - 1, FLOOR, TOP, 1.8)
	end
	column(midX - 18, Z0 + 8, 0, TOP, 3)
	column(midX + 18, Z0 + 8, 0, TOP, 3)

	-- Tramos de la escalera imperial, que suben hacia la galería.
	local steps = FLOOR
	local flightZ0 = GrandHall.FlightZ0
	local run = (galleryZ - flightZ0) / steps
	local stepColor = Color3.fromRGB(70, 44, 28)
	local function flight(range: { x0: number, x1: number }, doorKey: string): any
		local width = range.x1 - range.x0
		local cx = (range.x0 + range.x1) / 2
		for i = 1, steps do
			box(
				range.x0,
				0,
				flightZ0 + run * (i - 1),
				range.x1,
				i,
				flightZ0 + run * i,
				stepColor,
				Enum.Material.Wood,
				"Escalon"
			)
		end
		-- Lateral en cuña y pasamanos inclinado, de una sola pieza cada uno.
		local length = math.sqrt((galleryZ - flightZ0) ^ 2 + steps ^ 2)
		for _, x in { range.x0 - 0.5, range.x1 + 0.5 } do
			local wedge = Instance.new("WedgePart")
			wedge.Anchored = true
			wedge.Name = "LateralEscalera"
			wedge.Size = Vector3.new(1, steps, galleryZ - flightZ0)
			wedge.CFrame = CFrame.new(x, steps / 2, (flightZ0 + galleryZ) / 2)
				* CFrame.Angles(0, math.rad(180), 0)
			wedge.Color = wood
			wedge.Material = Enum.Material.Wood
			wedge.Parent = ctx.world
			local low = Vector3.new(x, 3.6, flightZ0)
			local high = Vector3.new(x, steps + 3.6, galleryZ)
			ctx.decor({
				Name = "Pasamanos",
				Size = Vector3.new(0.6, 0.5, length),
				CFrame = CFrame.lookAt((low + high) / 2, high),
				Color = gold,
				Material = Enum.Material.Wood,
			})
			for t = 0, 1, 0.25 do
				local point = low:Lerp(high, t)
				ctx.decor({
					Name = "Balaustre",
					Size = Vector3.new(0.4, 3.6, 0.4),
					Position = point - Vector3.new(0, 1.8, 0),
					Color = wood,
					Material = Enum.Material.Wood,
				})
			end
			-- Impide saltar al tramo por el costado y esquivar la reja.
			ctx.part({
				Name = "ParedInvisible",
				Size = Vector3.new(1, TOP, galleryZ - flightZ0),
				Position = Vector3.new(x, TOP / 2, (flightZ0 + galleryZ) / 2),
				Transparency = 1,
				CanQuery = false,
			})
			-- Pilar del arranque, como remate del pasamanos.
			ctx.part({
				Name = "PilarEscalera",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(4.4, 1.6, 1.6),
				CFrame = CFrame.new(x, 2.2, flightZ0 - 0.3) * CFrame.Angles(0, 0, math.rad(90)),
				Color = columnColor,
				Material = Enum.Material.Marble,
			})
		end
		return ctx.buildDoor(
			doorKey,
			Vector3.new(cx, 0, flightZ0 - 1),
			Vector3.xAxis,
			"Abrir",
			width,
			ctx.DOOR_HEIGHT,
			width,
			ctx.CORRIDOR_HEIGHT,
			"gate"
		)
	end
	local westGate = flight(GrandHall.FlightWest, "room7b")
	local eastGate = flight(GrandHall.FlightEast, "room7")
	eastGate.twin = westGate
	westGate.twin = eastGate
	ctx.refs.doors.room7 = eastGate
	ctx.refs.doors.room7b = westGate

	-- Baranda de la galería, cortada donde llegan los tramos.
	local spans = {
		{ X0, GrandHall.FlightWest.x0 - 1 },
		{ GrandHall.FlightWest.x1 + 1, GrandHall.FlightEast.x0 - 1 },
		{ GrandHall.FlightEast.x1 + 1, X1 },
	}
	for _, span in spans do
		local length = span[2] - span[1]
		local cx = (span[1] + span[2]) / 2
		ctx.decor({
			Name = "Baranda",
			Size = Vector3.new(length, 0.5, 0.7),
			Position = Vector3.new(cx, FLOOR + 3.6, galleryZ + 0.2),
			Color = gold,
			Material = Enum.Material.Wood,
		})
		ctx.part({
			Name = "ParedInvisible",
			Size = Vector3.new(length, 5, 0.7),
			Position = Vector3.new(cx, FLOOR + 2.5, galleryZ + 0.2),
			Transparency = 1,
			CanQuery = false,
		})
		for x = span[1] + 1, span[2] - 0.5, 3 do
			ctx.decor({
				Name = "Balaustre",
				Size = Vector3.new(0.45, 3.4, 0.45),
				Position = Vector3.new(x, FLOOR + 1.7, galleryZ + 0.2),
				Color = wood,
				Material = Enum.Material.Wood,
			})
		end
	end

	-- Alfombra central y medallón en el piso.
	ctx.rug(Vector3.new(midX, 0, -44), 12, 42, Color3.fromRGB(60, 80, 150))
	ctx.decor({
		Name = "Medallon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 24, 24),
		CFrame = CFrame.new(midX, 0.12, -44) * CFrame.Angles(0, 0, math.rad(90)),
		Color = gold,
		Material = Enum.Material.Metal,
	})
	ctx.decor({
		Name = "Medallon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.14, 21, 21),
		CFrame = CFrame.new(midX, 0.14, -44) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 80, 150),
		Material = Enum.Material.Fabric,
	})

	-- Nichos con estatua a los lados, con muy pocas piezas.
	local stone = Color3.fromRGB(150, 150, 146)
	local function niche(x: number, z: number, inward: number)
		ctx.decor({
			Name = "Nicho",
			Size = Vector3.new(0.3, 15, 8),
			Position = Vector3.new(x, 8, z),
			Color = Color3.fromRGB(70, 68, 66),
			Material = Enum.Material.Concrete,
		})
		local sx = x + inward * 2
		ctx.part({
			Name = "Peana",
			Size = Vector3.new(3.4, 2.4, 3.4),
			Position = Vector3.new(sx, 1.2, z),
			Color = stone,
			Material = Enum.Material.Marble,
		})
		for _, piece in
			{
				{ Vector3.new(2, 4, 1.4), 4.4 },
				{ Vector3.new(2.2, 3.6, 1.4), 8.2 },
			}
		do
			ctx.part({
				Name = "Estatua",
				Size = piece[1],
				Position = Vector3.new(sx, piece[2], z),
				Color = stone,
				Material = Enum.Material.Marble,
			})
		end
		ctx.part({
			Name = "Estatua",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.5, 1.5, 1.5),
			Position = Vector3.new(sx, 10.8, z),
			Color = stone,
			Material = Enum.Material.Marble,
		})
	end
	niche(X0 + 0.2, -16, 1)
	niche(X1 - 0.2, -16, -1)

	-- Seis librerías contra la pared del fondo, bajo la galería. Los libros van dibujados
	-- sobre el panel trasero; los huecos de las tres repisas de abajo guardan loot.
	local caseWidth, caseHeight, caseDepth = 13, 16, 2.6
	local shelves = 5
	local spines = {
		Color3.fromRGB(170, 45, 40),
		Color3.fromRGB(55, 90, 150),
		Color3.fromRGB(65, 120, 70),
		Color3.fromRGB(195, 150, 65),
		Color3.fromRGB(125, 80, 50),
		Color3.fromRGB(205, 195, 160),
		Color3.fromRGB(60, 55, 60),
	}
	local random = Random.new()
	local lootSpots = {}
	local pixelsPerStud = 24
	local rowPixels = caseHeight * pixelsPerStud / shelves
	for caseIndex = 1, 6 do
		local cx = midX + (caseIndex - 3.5) * (caseWidth + 0.4)
		local front = Z1 - caseDepth
		local back = ctx.part({
			Name = "FondoLibreria",
			Size = Vector3.new(caseWidth, caseHeight, 0.4),
			Position = Vector3.new(cx, caseHeight / 2, Z1 - 0.3),
			Color = Color3.fromRGB(30, 18, 12),
			Material = Enum.Material.Wood,
		})
		for _, x in { cx - caseWidth / 2, cx + caseWidth / 2 } do
			box(
				x - 0.25,
				0,
				front,
				x + 0.25,
				caseHeight,
				Z1,
				wood,
				Enum.Material.Wood,
				"LateralLibreria"
			)
		end
		for row = 0, shelves do
			local y = row * caseHeight / shelves
			box(
				cx - caseWidth / 2,
				y - 0.15,
				front,
				cx + caseWidth / 2,
				y + 0.15,
				Z1,
				wood,
				Enum.Material.Wood,
				"Repisa"
			)
		end

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixelsPerStud
		gui.LightInfluence = 0.8
		gui.Parent = back
		for row = 1, shelves do
			-- De arriba a abajo en la pantalla; `row` 1 es la repisa superior.
			local shelfTop = (row - 1) * rowPixels
			local x = 8
			local widthPixels = caseWidth * pixelsPerStud - 8
			while x < widthPixels do
				if random:NextNumber() < 0.09 then
					-- Hueco en la repisa.
					local gap = random:NextInteger(50, 80)
					local gapCenter = math.min(x + gap / 2, widthPixels)
					if row > shelves - 3 then
						local worldX = cx + caseWidth / 2 - gapCenter / pixelsPerStud
						local shelfY = (shelves - row) * caseHeight / shelves
						table.insert(lootSpots, Vector3.new(worldX, shelfY + 0.5, Z1 - 1.3))
					end
					x += gap
				else
					local bookWidth = random:NextInteger(7, 13)
					local bookHeight = rowPixels * random:NextNumber(0.62, 0.9)
					local book = Instance.new("Frame")
					book.BorderSizePixel = 0
					book.BackgroundColor3 = spines[random:NextInteger(1, #spines)]
					book.Size = UDim2.fromOffset(bookWidth, bookHeight)
					book.Position = UDim2.fromOffset(x, shelfTop + rowPixels - bookHeight - 4)
					book.Parent = gui
					x += bookWidth + 1
				end
			end
		end
	end
	ctx.refs.hidingSpots.hall = lootSpots

	-- Sillones de cada lado de la entrada.
	local center = Vector3.new(midX, 0, -40)
	ctx.FURNITURE.sofa(CFrame.lookAt(Vector3.new(X0 + 8, 0, Z0 + 10), center))
	ctx.FURNITURE.sofa(CFrame.lookAt(Vector3.new(X1 - 8, 0, Z0 + 10), center))

	-- Velas y gran candelabro.
	for _, position in
		{
			Vector3.new(X0 + 1, 10, -58),
			Vector3.new(X1 - 1, 10, -58),
			Vector3.new(X0 + 1, 10, 12),
			Vector3.new(X1 - 1, 10, 12),
			Vector3.new(midX - 21, 15, galleryZ + 3),
			Vector3.new(midX + 21, 15, galleryZ + 3),
			Vector3.new(midX, 15, galleryZ + 3),
			Vector3.new(midX - 30, FLOOR + 8, Z1 - 1),
			Vector3.new(midX + 30, FLOOR + 8, Z1 - 1),
		}
	do
		ctx.candle(position, ctx.CANDLE_LIGHT)
	end
	ctx.chandelier(Vector3.new(midX, FLOOR, -38), true)
	-- Bajo la galería no llega el candelabro central: dos más alumbran las librerías.
	ctx.chandelier(Vector3.new(midX - 22, 0, 14), true)
	ctx.chandelier(Vector3.new(midX + 22, 0, 14), true)

	-- La galería es el primer ambiente del primer piso.
	local spots = {}
	local look = Vector3.new(midX, FLOOR, -20)
	for i, kind in { "chest", "bookcase", "wardrobe", "nightstand" } do
		local x = midX + (i - 2.5) * 26
		local base = CFrame.lookAt(Vector3.new(x, FLOOR, Z1 - 7), look)
		for _, spot in ctx.FURNITURE[kind](base) do
			table.insert(spots, spot)
		end
	end
	ctx.refs.hidingSpots.room7 = spots
	ctx.painting(Vector3.new(midX, FLOOR + 10, Z1 - 0.7), -Vector3.zAxis, 3)
	ctx.painting(Vector3.new(midX - 20, FLOOR + 10, Z1 - 0.7), -Vector3.zAxis, 1)
	ctx.painting(Vector3.new(midX + 20, FLOOR + 10, Z1 - 0.7), -Vector3.zAxis, 2)
end

return GrandHall
