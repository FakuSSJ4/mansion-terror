--!strict
local Config = require("../src/shared/Config")
local Lighting = require("../src/shared/Rules/LightFade")

return {
	sixColoredKeys = function()
		assert(#Config.KeyColors == 6 and Config.KeyCount == 6)
		assert(#Config.KeyRooms == 6)
	end,
	fourScrolls = function()
		assert(Config.BookCount == 4)
	end,
	lightsFadeWithDistance = function()
		assert(Lighting.factor(10, Config) == 1)
		assert(Lighting.factor(Config.LightFadeEnd + 1, Config) == 0)
		local middle = Lighting.factor((Config.LightFadeStart + Config.LightFadeEnd) / 2, Config)
		assert(middle > 0.4 and middle < 0.6)
	end,
}
