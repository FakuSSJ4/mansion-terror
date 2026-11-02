--!strict
-- Grafo de piezas de la mansión. Sin APIs de Roblox.

export type Graph = {
	neighbors: { [string]: { string } },
	refuges: { [string]: boolean },
}

-- Lo que hace falta de MapDef para armar el grafo.
export type Def = {
	Edges: { { a: string, b: string } },
	Refuges: { [string]: string },
}

local MapGraph = {}

local function connect(g: Graph, a: string, b: string)
	g.neighbors[a] = g.neighbors[a] or {}
	g.neighbors[b] = g.neighbors[b] or {}
	table.insert(g.neighbors[a], b)
	table.insert(g.neighbors[b], a)
end

-- El grafo sale de un MapDef: pasillos, escaleras y trampilla, más los refugios.
-- sealed (opcional): pasillos tapiados (clave |b) que no entran al grafo.
function MapGraph.fromDef(def: Def, sealed: { [string]: boolean }?): Graph
	local g: Graph = { neighbors = {}, refuges = {} }
	for _, edge in def.Edges do
		local skipped = sealed and (sealed[`{edge.a}|{edge.b}`] or sealed[`{edge.b}|{edge.a}`])
		if not skipped then
			connect(g, edge.a, edge.b)
		end
	end
	for refuge, room in def.Refuges do
		connect(g, room, refuge)
		g.refuges[refuge] = true
	end
	return g
end

function MapGraph.isRefuge(g: Graph, id: string): boolean
	return g.refuges[id] == true
end

export type LinkOpen = (a: string, b: string) -> boolean

-- Piezas a las que se puede llegar desde `from` cruzando solo conexiones abiertas.
function MapGraph.reachable(g: Graph, from: string, isOpen: LinkOpen): { string }
	local seen = { [from] = true }
	local rooms = { from }
	local head = 1
	while head <= #rooms do
		local current = rooms[head]
		head += 1
		for _, nextId in g.neighbors[current] or {} do
			if not seen[nextId] and isOpen(current, nextId) then
				seen[nextId] = true
				table.insert(rooms, nextId)
			end
		end
	end
	return rooms
end

-- Camino más corto de `from` a `to`, ambos incluidos; vacío si no hay.
function MapGraph.path(g: Graph, from: string, to: string, isOpen: LinkOpen?): { string }
	if not g.neighbors[from] or not g.neighbors[to] then
		return {}
	end
	local cameFrom: { [string]: string } = { [from] = from }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		if current == to then
			local path = { to }
			while path[1] ~= from do
				table.insert(path, 1, cameFrom[path[1]])
			end
			return path
		end
		for _, nextId in g.neighbors[current] do
			if not cameFrom[nextId] and (not isOpen or isOpen(current, nextId)) then
				cameFrom[nextId] = current
				table.insert(queue, nextId)
			end
		end
	end
	return {}
end

function MapGraph.distance(g: Graph, from: string, to: string, isOpen: LinkOpen?): number
	local path = MapGraph.path(g, from, to, isOpen)
	return if #path == 0 then math.huge else #path - 1
end

return MapGraph
