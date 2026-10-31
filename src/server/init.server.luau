--!strict
local Systems = script:WaitForChild("Systems")

local Mansion = require(Systems:WaitForChild("Mansion"))
local Weather = require(Systems:WaitForChild("Weather"))

Mansion.build()
Weather.start()
