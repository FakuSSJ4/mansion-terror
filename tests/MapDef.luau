--!strict
local Config = require("../src/shared/Config")
local MapDef = require("../src/shared/Rules/MapDef")
local MapGraph = require("../src/shared/Rules/MapGraph")
local Placement = require("../src/shared/Rules/Placement")

local function rollerFor(seed: number): (number) -> number
	-- Generador congruencial simple: lune no trae `Random` de Roblox.
	local state = seed * 104729 + 7
	return function(n)
		state = (state * 1103515245 + 12345) % 2147483648
		return math.floor(state / 65536) % n + 1
	end
end

local function always(_: string): boolean
	return true
end

-- Lo que había escrito a mano antes de pasar el mapa a datos: el mapa de antes no debe cambiar.
local OLD_NEEDS: { [string]: { string } } = {
	hall = {},
	room1 = {},
	gameRoom = {},
	room2 = { "room2" },
	room3 = { "room2", "room3" },
	room4 = { "room2", "room3" },
	room5 = { "room2", "room3", "room5" },
	room6 = { "room2", "room3", "room5" },
	room7 = { "room7" },
	bar = { "room7" },
	room8 = { "room7" },
	room9 = { "room7", "room9" },
	room10 = { "room7", "room9" },
	room11 = { "room7", "room9", "room11" },
	room12 = { "room7", "room9", "room11" },
	attic = { "room7", "room9", "room11" },
}

local function sorted(list: { string }): string
	local copy = table.clone(list)
	table.sort(copy)
	return table.concat(copy, ",")
end

local function layoutFor(seed: number): MapDef.Layout
	return MapDef.rollLayout(rollerFor(seed))
end

local function countKeys(map: { [string]: any }): number
	local count = 0
	for _ in map do
		count += 1
	end
	return count
end

return {
	defaultLayoutKeepsTheOldMap = function()
		local needs = MapDef.needs()
		for room, doors in OLD_NEEDS do
			assert(needs[room], `falta {room}`)
			assert(sorted(needs[room]) == sorted(doors), `{room} necesita otras puertas`)
		end
		for room in needs do
			assert(OLD_NEEDS[room], `sobra {room}`)
		end
	end,
	everyRoomIsReachableFromTheHub = function()
		local g = MapGraph.fromDef(MapDef, MapDef.DefaultLayout.sealed)
		for room in MapDef.needs() do
			assert(
				MapGraph.distance(g, MapDef.Hub, room) < math.huge,
				`{room} no se alcanza desde la entrada`
			)
		end
	end,
	everyLockHasAKeyColor = function()
		for _, edge in MapDef.Edges do
			if edge.lock then
				assert(Config.DoorKeys[edge.lock], `la puerta {edge.lock} no tiene llave`)
			end
		end
		for _, label in MapDef.LockLabels do
			assert(Config.DoorKeys[label], `la puerta {label} no tiene llave`)
		end
	end,
	rolledLayoutSealsOneCorridorPerCycleAndUsesAllLabels = function()
		for seed = 1, 200 do
			local layout = layoutFor(seed)
			assert(
				countKeys(layout.sealed) == #MapDef.Cycles,
				`semilla {seed}: tapiados de más o de menos`
			)
			for key in layout.sealed do
				local inCycle = false
				for _, cycle in MapDef.Cycles do
					inCycle = inCycle or table.find(cycle, key) ~= nil
				end
				assert(inCycle, `{key} no está en un ciclo`)
			end
			local labels: { [string]: boolean } = {}
			for spot, label in layout.locks do
				assert(table.find(MapDef.LockCandidates, spot), `{spot} no es candidato`)
				assert(not layout.sealed[spot], `{spot} está tapiado y lleva puerta`)
				assert(not labels[label], `{label} repetida`)
				labels[label] = true
			end
			for _, label in MapDef.LockLabels do
				assert(labels[label], `falta {label}`)
			end
		end
	end,
	rolledLayoutsLeaveATreeWhereEverythingIsReachable = function()
		for seed = 1, 200 do
			local layout = layoutFor(seed)
			local g = MapGraph.fromDef(MapDef, layout.sealed)
			local needs = MapDef.needs(layout)
			local rooms = 0
			local edges = 0
			for room in needs do
				rooms += 1
				assert(
					MapGraph.distance(g, MapDef.Hub, room) < math.huge,
					`semilla {seed}: {room} quedó aislada`
				)
			end
			for _, edge in MapDef.Edges do
				if not MapDef.isSealed(edge.a, edge.b, layout) then
					edges += 1
				end
			end
			assert(edges == rooms - 1, `semilla {seed}: quedaron ciclos (o piezas sueltas)`)
		end
	end,
	rolledLayoutsVaryBetweenGames = function()
		local seen: { [string]: boolean } = {}
		for seed = 1, 200 do
			local layout = layoutFor(seed)
			local parts = {}
			for spot in layout.sealed do
				table.insert(parts, `sello {spot}`)
			end
			for spot, label in layout.locks do
				table.insert(parts, `{spot}={label}`)
			end
			table.sort(parts)
			seen[table.concat(parts, ";")] = true
		end
		assert(countKeys(seen) > 100, `solo {countKeys(seen)} distribuciones`)
	end,
	everyKindOfSealedPairShowsUp = function()
		local found: { [string]: boolean } = {}
		for seed = 1, 300 do
			for spot in layoutFor(seed).sealed do
				found[spot] = true
			end
		end
		for _, cycle in MapDef.Cycles do
			for _, spot in cycle do
				assert(found[spot], `{spot} nunca se tapia`)
			end
		end
	end,
	mostRolledLayoutsLetTheKeysBePlaced = function()
		-- Como hace el juego: si un reparto de llaves se traba, prueba otro con la misma distribución.
		local failures = 0
		for seed = 1, 200 do
			local layout = layoutFor(seed)
			local needs = MapDef.needs(layout)
			local placed = false
			for attempt = 1, 30 do
				local rooms = Placement.keyRooms(
					needs,
					Config.DoorKeys,
					Config.KeyCount,
					rollerFor(seed * 31 + attempt),
					always
				)
				if rooms then
					placed = true
					break
				end
			end
			if not placed then
				failures += 1
			end
		end
		-- El juego descarta las que no tienen solución y sortea otra: tienen que ser pocas.
		assert(failures < 60, `{failures} de 200 distribuciones no tienen reparto de llaves`)
	end,
	refugesHangFromExistingRooms = function()
		local needs = MapDef.needs()
		for refuge, room in MapDef.Refuges do
			assert(needs[room], `{refuge} cuelga de {room}, que no existe`)
		end
	end,
	lockSealAndHatchLookupsWorkBothWays = function()
		local layout = MapDef.DefaultLayout
		assert(MapDef.lockOf("room1", "room2", layout) == "room2")
		assert(MapDef.lockOf("room2", "room1", layout) == "room2")
		assert(MapDef.lockOf("hall", "room1", layout) == nil)
		assert(MapDef.isSealed("room4", "room1", layout))
		assert(not MapDef.isSealed("room1", "room2", layout))
		assert(MapDef.isHatch("room12", "attic") and MapDef.isHatch("attic", "room12"))
		assert(not MapDef.isHatch("room11", "room12"))
	end,
	corridorsExcludeStairsAndHatch = function()
		local corridors = MapDef.corridors()
		assert(#corridors == 14)
		for _, pair in corridors do
			assert(not (pair[1] == "hall" and pair[2] == "room7"))
			assert(not (pair[1] == "room12" and pair[2] == "attic"))
		end
	end,
}
