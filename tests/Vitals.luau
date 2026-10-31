--!strict
local Config = require("../src/shared/Config")
local Vitals = require("../src/shared/Rules/Vitals")

return {
	damageSubtractsDownToZero = function()
		assert(Vitals.damage(100, Config.KillerDamage) == 50)
		assert(Vitals.damage(50, Config.KillerDamage) == 0)
		assert(Vitals.damage(20, Config.KillerDamage) == 0)
	end,
	healCapsAtMax = function()
		assert(Vitals.heal(80, Config.PillHeal, Config.MaxHealth) == 100)
		assert(Vitals.heal(10, Config.PillHeal, Config.MaxHealth) == 60)
	end,
	fullHealthCannotTakePill = function()
		assert(not Vitals.canTakePill(100, Config.MaxHealth))
		assert(Vitals.canTakePill(99, Config.MaxHealth))
	end,
}
