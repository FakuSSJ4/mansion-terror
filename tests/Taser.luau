--!strict
local Config = require("../src/shared/Config")
local KillerBrain = require("../src/shared/Rules/KillerBrain")
local Taser = require("../src/shared/Rules/Taser")

return {
	carriesOnlyOneTaser = function()
		assert(Taser.canPickUp(0))
		assert(not Taser.canPickUp(1))
	end,
	eachTaserHasOneShot = function()
		assert(Config.TaserStartCharges == 1)
	end,
	stunLastsTenSecondsThenFiveImmune = function()
		local k = KillerBrain.new()
		assert(Taser.canStun(k, 0))
		Taser.applyStun(k, 0, Config)
		assert(not Taser.canStun(k, 9))
		assert(not Taser.canStun(k, 14))
		assert(Taser.canStun(k, 15.1))
	end,
}
