--!strict
-- Grafo de piezas de la mansión. Sin APIs de Roblox.

export type Graph = {
	neighbors: { [string]: { string } },
	refuges: { [string]: boolean },
}

local MapGraph = {}

local function connect(g: Graph, a: string, b: string)
	g.neighbors[a] = g.neighbors[a] or {}
	g.neighbors[b] = g.neighbors[b] or {}
	table.insert(g.neighbors[a], b)
	table.insert(g.neighbors[b], a)
end

function MapGraph.default(): Graph
	local g: Graph = { neighbors = {}, refuges = {} }
	-- Planta baja (1 a 4), sótano (5 y 6) y primer piso (7 a 12), con el altillo arriba.
	connect(g, "hall", "room1")
	for i = 1, 5 do
		connect(g, `room{i}`, `room{i + 1}`)
	end
	connect(g, "hall", "room7")
	for i = 7, 11 do
		connect(g, `room{i}`, `room{i + 1}`)
	end
	connect(g, "room12", "attic")
	-- Ala oeste, a la derecha de la entrada: sala de juegos abajo y bar arriba.
	connect(g, "hall", "gameRoom")
	connect(g, "room7", "bar")
	for refuge, room in { refuge1 = "room1", refuge2 = "room6", refuge3 = "room8" } do
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
