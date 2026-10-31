--!strict
local Systems = script:WaitForChild("Systems")

local DebugTools = require(Systems:WaitForChild("DebugTools"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))
local Weather = require(Systems:WaitForChild("Weather"))

local refs = Mansion.build()
Weather.start()
Vitality.start()
Round.start(refs)
DebugTools.start(refs)
