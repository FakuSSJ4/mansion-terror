--!strict
-- Revisión de QA: qué cosas colgadas de la pared (cuadros, cajas fuertes con su cartel, ventanales)
-- se atraviesan con muebles u otras cosas. Las piezas decorativas no responden a consultas del
-- mundo, así que acá se comparan las cajas de cada pieza a mano.

local WallCheck = {}

-- Lo que cuelga de la pared. La caja fuerte se revisa por sus chapas.
local HUNG = {
	MarcoCuadro = true,
	CartelCajaFuerte = true,
	CajaFuerte = true,
	Ventanal = true,
}

-- Estructura o detalle pegado a la pared o al piso a propósito: que se toque no es un choque.
local IGNORED = {
	Pared = true,
	Placa = true,
	Tapiz = true,
	Moldura = true,
	Viga = true,
	Pintura = true,
	Alfombra = true,
	Parteluz = true,
	MarcoVentana = true,
	Alfeizar = true,
	Postigo = true,
	Enredadera = true,
	Zocalo = true,
	-- Piezas de la misma caja fuerte.
	BisagraCajaFuerte = true,
	PuertaCajaFuerte = true,
}

type Box = { part: BasePart, min: Vector3, max: Vector3 }

local function boxOf(part: BasePart): Box
	-- Caja alineada a los ejes que envuelve a la pieza (las paredes están a 0 o 90 grados).
	local cf = part.CFrame
	local size = part.Size
	local right, up, back = cf.RightVector, cf.UpVector, cf.LookVector
	local half = Vector3.new(
		(math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(back.X) * size.Z) / 2,
		(math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(back.Y) * size.Z) / 2,
		(math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(back.Z) * size.Z) / 2
	)
	return { part = part, min = cf.Position - half, max = cf.Position + half }
end

local function overlap(a: Box, b: Box): boolean
	-- Un margen chico: apoyarse una pieza contra otra no cuenta.
	local gap = 0.08
	return a.min.X < b.max.X - gap
		and a.max.X > b.min.X + gap
		and a.min.Y < b.max.Y - gap
		and a.max.Y > b.min.Y + gap
		and a.min.Z < b.max.Z - gap
		and a.max.Z > b.min.Z + gap
end

local function roomOf(position: Vector3, rooms: { [string]: { center: Vector3 } }): string
	local best, bestDistance = "?", math.huge
	for id, room in rooms do
		local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(
			room.center.X,
			0,
			room.center.Z
		)).Magnitude + math.abs(position.Y - room.center.Y) * 3
		if distance < bestDistance then
			best, bestDistance = id, distance
		end
	end
	return best
end

-- Devuelve una línea por cada par que se pisa, ordenadas por pieza.
function WallCheck.scan(root: Instance, rooms: { [string]: { center: Vector3 } }): { string }
	local hung: { Box } = {}
	local others: { Box } = {}
	for _, instance in root:GetDescendants() do
		if instance:IsA("BasePart") and instance.Transparency < 1 then
			if HUNG[instance.Name] then
				table.insert(hung, boxOf(instance))
			elseif not IGNORED[instance.Name] then
				table.insert(others, boxOf(instance))
			end
		end
	end
	local lines = {}
	local seen: { [string]: boolean } = {}
	for _, a in hung do
		for _, b in others do
			if a.part ~= b.part and overlap(a, b) then
				local room = roomOf(a.part.Position, rooms)
				local key =
					`{room}|{a.part.Name}|{b.part.Name}|{math.floor(a.part.Position.X / 6)}|{math.floor(
						a.part.Position.Z / 6
					)}`
				if not seen[key] then
					seen[key] = true
					local at = b.part.Position
					table.insert(
						lines,
						`{room}: {a.part.Name} x {b.part.Name} ({b.part.Parent and b.part.Parent.Name or "?"}) en ({math.floor(
							at.X
						)}, {math.floor(at.Y)}, {math.floor(at.Z)})`
					)
				end
			end
		end
	end
	-- Los cuadros entre sí y contra ventanales también cuentan.
	for i = 1, #hung do
		for j = i + 1, #hung do
			local a, b = hung[i], hung[j]
			local paintingA = a.part.Name == "MarcoCuadro"
			local paintingB = b.part.Name == "MarcoCuadro"
			-- Cuadro contra caja o contra otro cuadro; las chapas de una misma caja no cuentan.
			if paintingA or paintingB then
				if overlap(a, b) then
					local room = roomOf(a.part.Position, rooms)
					table.insert(lines, `{room}: {a.part.Name} x {b.part.Name} entre sí`)
				end
			end
		end
	end
	table.sort(lines)
	return lines
end

return WallCheck
