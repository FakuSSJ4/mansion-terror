--!strict
local Config = require("../src/shared/Config")
local Loot = require("../src/shared/Rules/Loot")

return {
	normalKeepsFullLoot = function()
		local c = Loot.counts("normal", Config)
		assert(c.pills == Config.PillCount)
		assert(c.batteries == Config.BatteryCount)
		assert(c.tasers == Config.TaserSpareCount)
	end,
	hardHalvesEverything = function()
		local c = Loot.counts("hard", Config)
		assert(c.pills == 4 and c.batteries == 3 and c.tasers == 2)
	end,
	onlyKnownDifficulties = function()
		assert(Loot.isValid("normal") and Loot.isValid("hard"))
		assert(not Loot.isValid("facil") and not Loot.isValid(3))
	end,
}
