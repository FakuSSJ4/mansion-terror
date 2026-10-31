--!strict
local Routes = require("../src/shared/Rules/Routes")

return {
	forwardEndsAtTheDestinationCenter = function()
		local forward = Routes.both({ "mitad" }, "centroA", "centroB")
		assert(#forward == 2 and forward[1] == "mitad" and forward[2] == "centroB")
	end,
	backwardEndsAtTheOriginCenter = function()
		local _, backward = Routes.both({ "mitad" }, "centroA", "centroB")
		assert(#backward == 2 and backward[1] == "mitad" and backward[2] == "centroA")
	end,
	backwardReversesAllPoints = function()
		local _, backward = Routes.both({ "abajo", "arriba" }, "centroA", "centroB")
		assert(backward[1] == "arriba" and backward[2] == "abajo" and backward[3] == "centroA")
	end,
}
