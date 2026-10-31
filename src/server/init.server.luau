--!strict
local Systems = script:WaitForChild("Systems")

local DebugTools = require(Systems:WaitForChild("DebugTools"))
local Killer = require(Systems:WaitForChild("Killer"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local TaserSystem = require(Systems:WaitForChild("TaserSystem"))
local Vitality = require(Systems:WaitForChild("Vitality"))
local Weather = require(Systems:WaitForChild("Weather"))

local refs = Mansion.build()
Weather.start()
Vitality.start()
Round.start(refs)
Killer.start(refs)
TaserSystem.start()
DebugTools.start(refs)
