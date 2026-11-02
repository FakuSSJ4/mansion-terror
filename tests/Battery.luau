--!strict
local Config = require("../src/shared/Config")
local Battery = require("../src/shared/Rules/Battery")

return {
	drainsEmptyInFlashlightSeconds = function()
		local half = Config.FlashlightSeconds / 2
		local level = Battery.drain(1, half, Config)
		assert(math.abs(level - 0.5) < 0.001)
		assert(Battery.drain(level, half, Config) == 0)
		assert(Battery.drain(0, 10, Config) == 0)
	end,
	eachBatteryRechargesItsSecondsCapped = function()
		local expected = Config.BatteryRechargeSeconds / Config.FlashlightSeconds
		assert(math.abs(Battery.recharge(0, Config) - expected) < 0.001)
		assert(Battery.recharge(0.95, Config) == 1)
	end,
	fullBatteryTakesNoPill = function()
		assert(not Battery.canRecharge(1))
		assert(Battery.canRecharge(0.99))
	end,
}
