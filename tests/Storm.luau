--!strict
local Config = require("../src/shared/Config")
local Storm = require("../src/shared/Rules/Storm")

-- Lune no trae Random: un sorteo equivalente con math.random.
local function newRandom(seed: number): any
	math.randomseed(seed)
	return {
		NextNumber = function(_, from: number, to: number)
			return from + math.random() * (to - from)
		end,
		NextInteger = function(_, from: number, to: number)
			return math.random(from, to)
		end,
	}
end

return {
	noStrikeInFirstMinute = function()
		local random = newRandom(7)
		for _ = 1, 200 do
			local minutes = Storm.pickWindow(Config.Storm, random)
			for _, at in Storm.schedule(minutes, Config.Storm, random) do
				assert(at >= Config.Storm.QuietSeconds)
			end
		end
	end,
	strikesStayInsideWindow = function()
		local random = newRandom(3)
		for _, minutes in Config.Storm.WindowsMinutes do
			local times = Storm.schedule(minutes, Config.Storm, random)
			assert(#times >= Config.Storm.MinStrikes)
			assert(times[#times] <= minutes * 60)
		end
	end,
	windowIsOneOfTheOptions = function()
		local random = newRandom(1)
		for _ = 1, 50 do
			local minutes = Storm.pickWindow(Config.Storm, random)
			assert(table.find(Config.Storm.WindowsMinutes, minutes) ~= nil)
		end
	end,
}
