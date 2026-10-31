--!strict
local Config = require("../src/shared/Config")
local Battery = require("../src/shared/Rules/Battery")

return {
	drainsEmptyInTwoMinutes = function()
		local level = Battery.drain(1, 60, Config)
		assert(math.abs(level - 0.5) < 0.001)
		assert(Battery.drain(level, 60, Config) == 0)
		assert(Battery.drain(0, 10, Config) == 0)
	end,
	eachPillRechargesOneMinuteCapped = function()
		assert(math.abs(Battery.recharge(0, Config) - 0.5) < 0.001)
		assert(Battery.recharge(0.8, Config) == 1)
	end,
	fullBatteryTakesNoPill = function()
		assert(not Battery.canRecharge(1))
		assert(Battery.canRecharge(0.99))
	end,
}
