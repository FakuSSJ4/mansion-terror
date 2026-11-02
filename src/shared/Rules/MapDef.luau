--!strict
-- El mapa de la mansión como datos: pasillos, escaleras, trampilla, puertas con llave y refugios.
-- Es la única fuente: el grafo de los asesinos, el reparto de llaves y la construcción del
-- edificio leen de acá. Sin APIs de Roblox.
--
-- Todos los pasillos se construyen una vez. En cada partida se sortea una distribución (Layout):
-- qué pasillos se tapian con tablones (así el mapa vuelve a ser un árbol, con otro recorrido) y
-- en cuáles va cada una de las cuatro puertas con llave.

export type Edge = {
	a: string,
	b: string,
	-- "corridor" (pasillo), "stairs" o "hatch".
	kind: string,
	-- Puerta fija que bloquea el paso (las escaleras). Las de los pasillos se sortean: ver Locks.
	lock: string?,
}

-- Puertas con llave de los pasillos: clave "a|b" del pasillo -> nombre de la puerta.
export type Locks = { [string]: string }

-- Distribución de una partida: pasillos tapiados (clave "a|b") y puertas con llave.
export type Layout = { sealed: { [string]: boolean }, locks: Locks }

local MapDef = {}

-- Pieza desde la que se cuenta todo: acá aparecen los jugadores.
MapDef.Hub = "hall"

-- El orden importa: es el orden en que se construyen los pasillos y se arman los vecinos del grafo.
-- Planta baja (1 a 4), sótano (5 y 6), primer piso (7 a 12), altillo, el ala oeste y, al final, los
-- dos pasillos que cierran un ciclo en cada piso (1-4 y 8-11).
MapDef.Edges = {
	{ a = "hall", b = "room1", kind = "corridor" },
	{ a = "room1", b = "room2", kind = "corridor" },
	{ a = "room2", b = "room3", kind = "corridor" },
	{ a = "room3", b = "room4", kind = "corridor" },
	{ a = "room4", b = "room5", kind = "stairs", lock = "room5" },
	{ a = "room5", b = "room6", kind = "corridor" },
	{ a = "hall", b = "room7", kind = "stairs", lock = "room7" },
	{ a = "room7", b = "room8", kind = "corridor" },
	{ a = "room8", b = "room9", kind = "corridor" },
	{ a = "room9", b = "room10", kind = "corridor" },
	{ a = "room10", b = "room11", kind = "corridor" },
	{ a = "room11", b = "room12", kind = "corridor" },
	{ a = "room12", b = "attic", kind = "hatch" },
	{ a = "hall", b = "gameRoom", kind = "corridor" },
	{ a = "room7", b = "bar", kind = "corridor" },
	{ a = "room1", b = "room4", kind = "corridor" },
	{ a = "room8", b = "room11", kind = "corridor" },
} :: { Edge }

-- Cada refugio cuelga de una pieza.
-- Ya no hay zonas seguras: no queda ninguna pieza donde el asesino no pueda entrar.
MapDef.Refuges = {} :: { [string]: string }

-- En cada piso hay un ciclo de cuatro pasillos; en cada partida se tapia uno de ellos.
MapDef.Cycles = {
	{ "room1|room2", "room2|room3", "room3|room4", "room1|room4" },
	{ "room8|room9", "room9|room10", "room10|room11", "room8|room11" },
}

-- Las cuatro puertas con llave de los pasillos (cada una lleva el color de su llave).
MapDef.LockLabels = { "room2", "room3", "room9", "room11" }

-- Pasillos donde puede ir una de esas puertas. Quedan afuera los de la entrada (hall-room1,
-- hall-gameRoom), para que siempre haya algo que recorrer antes de la primera llave.
MapDef.LockCandidates = {
	"room1|room2",
	"room2|room3",
	"room3|room4",
	"room1|room4",
	"room8|room9",
	"room9|room10",
	"room10|room11",
	"room8|room11",
	"room11|room12",
}

-- La distribución de antes de sortear: la cadena de siempre, con los dos pasillos nuevos tapiados.
MapDef.DefaultLayout = {
	sealed = { ["room1|room4"] = true, ["room8|room11"] = true },
	locks = {
		["room1|room2"] = "room2",
		["room2|room3"] = "room3",
		["room8|room9"] = "room9",
		["room10|room11"] = "room11",
	},
} :: Layout

local function sameEdge(edge: Edge, a: string, b: string): boolean
	return (edge.a == a and edge.b == b) or (edge.a == b and edge.b == a)
end

local function edgeBetween(a: string, b: string): Edge?
	for _, edge in MapDef.Edges do
		if sameEdge(edge, a, b) then
			return edge
		end
	end
	return nil
end

local function inTable(map: { [string]: any }, a: string, b: string): any
	return map[`{a}|{b}`] or map[`{b}|{a}`]
end

-- Pares {a, b} de los pasillos que se construyen como corredor, en orden.
function MapDef.corridors(): { { string } }
	local list = {}
	for _, edge in MapDef.Edges do
		if edge.kind == "corridor" then
			table.insert(list, { edge.a, edge.b })
		end
	end
	return list
end

-- Sortea una distribución. `roll(n)` devuelve un entero de 1 a n.
function MapDef.rollLayout(roll: (n: number) -> number): Layout
	local sealed: { [string]: boolean } = {}
	for _, cycle in MapDef.Cycles do
		sealed[cycle[roll(#cycle)]] = true
	end
	local spots = {}
	for _, key in MapDef.LockCandidates do
		if not sealed[key] then
			table.insert(spots, key)
		end
	end
	local labels = table.clone(MapDef.LockLabels)
	local locks: Locks = {}
	while #labels > 0 do
		local spot = table.remove(spots, roll(#spots)) :: string
		local label = table.remove(labels, roll(#labels)) :: string
		locks[spot] = label
	end
	return { sealed = sealed, locks = locks }
end

-- Si el pasillo entre dos piezas está tapiado en esta distribución.
function MapDef.isSealed(a: string, b: string, layout: Layout?): boolean
	local current = layout or MapDef.DefaultLayout
	return inTable(current.sealed, a, b) == true
end

-- Puerta que bloquea el paso entre dos piezas vecinas, o nil si está libre.
function MapDef.lockOf(a: string, b: string, layout: Layout?): string?
	local edge = edgeBetween(a, b)
	if edge and edge.lock then
		return edge.lock
	end
	local current = layout or MapDef.DefaultLayout
	return inTable(current.locks, a, b)
end

-- Si el paso entre dos piezas es la trampilla del altillo.
function MapDef.isHatch(a: string, b: string): boolean
	local edge = edgeBetween(a, b)
	return edge ~= nil and edge.kind == "hatch"
end

-- Puertas con llave que hay que haber abierto para llegar a cada pieza desde la entrada, sin pasar
-- por pasillos tapiados. Con los ciclos cortados el mapa es un árbol: hay un solo camino a cada pieza.
function MapDef.needs(layout: Layout?): { [string]: { string } }
	local neighbors: { [string]: { Edge } } = {}
	for _, edge in MapDef.Edges do
		if not MapDef.isSealed(edge.a, edge.b, layout) then
			neighbors[edge.a] = neighbors[edge.a] or {}
			neighbors[edge.b] = neighbors[edge.b] or {}
			table.insert(neighbors[edge.a], edge)
			table.insert(neighbors[edge.b], edge)
		end
	end
	local result: { [string]: { string } } = { [MapDef.Hub] = {} }
	local queue = { MapDef.Hub }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, edge in neighbors[current] or {} do
			local other = if edge.a == current then edge.b else edge.a
			if not result[other] then
				local doors = table.clone(result[current])
				local lock = MapDef.lockOf(current, other, layout)
				if lock then
					table.insert(doors, lock)
				end
				result[other] = doors
				table.insert(queue, other)
			end
		end
	end
	return result
end

return MapDef
