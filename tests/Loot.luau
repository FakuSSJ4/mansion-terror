--!strict
local Config = require("../src/shared/Config")
local Loot = require("../src/shared/Rules/Loot")

return {
	normalKeepsFullLoot = function()
		local c = Loot.counts("normal", Config)
		assert(c.bandages + c.medkits == Config.CureCount)
		assert(c.batteries == Config.BatteryCount)
		assert(c.tasers == Config.TaserSpareCount)
	end,
	nightmareHalvesEverything = function()
		local c = Loot.counts("nightmare", Config)
		assert(c.bandages == 2 and c.medkits == 2 and c.batteries == 3 and c.tasers == 2)
	end,
	curesSplitHalfAndHalf = function()
		local c = Loot.counts("normal", Config)
		assert(c.bandages == c.medkits)
		local odd = Loot.counts("easy", { CureCount = 5, BatteryCount = 0, TaserSpareCount = 0 })
		assert(odd.bandages == 3 and odd.medkits == 4)
	end,
	medkitHealsMoreThanBandage = function()
		assert(Config.MedkitHeal > Config.BandageHeal)
	end,
	onlyKnownDifficulties = function()
		assert(
			Loot.isValid("normal")
				and Loot.isValid("nightmare")
				and Loot.isValid("easy")
				and not Loot.isValid("hard")
		)
		assert(not Loot.isValid("facil") and not Loot.isValid(3))
	end,
}
