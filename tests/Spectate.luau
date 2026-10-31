--!strict
local Spectate = require("../src/shared/Rules/Spectate")

return {
	picksFirstWhenNoCurrent = function()
		assert(Spectate.nextTarget({ "ana", "beto" }, nil) == "ana")
	end,
	cyclesAndWraps = function()
		assert(Spectate.nextTarget({ "ana", "beto" }, "ana") == "beto")
		assert(Spectate.nextTarget({ "ana", "beto" }, "beto") == "ana")
	end,
	currentGoneFallsBackToFirst = function()
		assert(Spectate.nextTarget({ "ana" }, "beto") == "ana")
	end,
	nobodyAliveIsNil = function()
		assert(Spectate.nextTarget({}, "ana") == nil)
	end,
}
