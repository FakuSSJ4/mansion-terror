--!strict
local MapGraph = require("../src/shared/Rules/MapGraph")

local g = MapGraph.default()

return {
	distanceAlongRooms = function()
		assert(MapGraph.distance(g, "hall", "room4") == 4)
		assert(MapGraph.distance(g, "room12", "exit") == 1)
		assert(MapGraph.distance(g, "room7", "room7") == 0)
	end,
	refugesHangFromTheirRooms = function()
		assert(MapGraph.distance(g, "room2", "refuge1") == 1)
		assert(MapGraph.distance(g, "room5", "refuge2") == 1)
		assert(MapGraph.distance(g, "room9", "refuge3") == 1)
	end,
	identifiesRefuges = function()
		assert(MapGraph.isRefuge(g, "refuge2"))
		assert(not MapGraph.isRefuge(g, "room5"))
	end,
	killerPathAvoidsRefuges = function()
		assert(MapGraph.isRefuge(g, "refuge1"))
		local path = MapGraph.path(g, "room1", "room3")
		assert(#path == 3 and path[2] == "room2")
	end,
	unknownRoomIsInfinitelyFar = function()
		assert(MapGraph.distance(g, "hall", "nada") == math.huge)
	end,
}
