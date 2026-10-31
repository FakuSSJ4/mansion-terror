--!strict
local Config = require("../src/shared/Config")
local KillerBrain = require("../src/shared/Rules/KillerBrain")
local Taser = require("../src/shared/Rules/Taser")

return {
	stunLastsTenSecondsThenFiveImmune = function()
		local k = KillerBrain.new()
		assert(Taser.canStun(k, 0))
		Taser.applyStun(k, 0, Config)
		assert(not Taser.canStun(k, 9))
		assert(not Taser.canStun(k, 14))
		assert(Taser.canStun(k, 15.1))
	end,
}
