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
	connect(g, "hall", "room1")
	for i = 1, 11 do
		connect(g, `room{i}`, `room{i + 1}`)
	end
	connect(g, "room12", "exit")
	for refuge, room in { refuge1 = "room2", refuge2 = "room5", refuge3 = "room9" } do
		connect(g, room, refuge)
		g.refuges[refuge] = true
	end
	return g
end

function MapGraph.isRefuge(g: Graph, id: string): boolean
	return g.refuges[id] == true
end

-- Camino más corto de `from` a `to`, ambos incluidos; vacío si no hay.
function MapGraph.path(g: Graph, from: string, to: string): { string }
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
			if not cameFrom[nextId] then
				cameFrom[nextId] = current
				table.insert(queue, nextId)
			end
		end
	end
	return {}
end

function MapGraph.distance(g: Graph, from: string, to: string): number
	local path = MapGraph.path(g, from, to)
	return if #path == 0 then math.huge else #path - 1
end

return MapGraph
