--!strict
local Config = require("../src/shared/Config")
local KillerBrain = require("../src/shared/Rules/KillerBrain")
local Taser = require("../src/shared/Rules/Taser")

-- Avanza `seconds` pasos de 1 s con la misma entrada.
local function run(b: KillerBrain.Brain, seconds: number, input: { [string]: any })
	for _ = 1, seconds do
		b.clock += 1
		KillerBrain.step(b, {
			now = b.clock,
			dt = 1,
			visibleTarget = input.visibleTarget,
			minRoomDistance = input.minRoomDistance,
			refugeCamper = input.refugeCamper,
		}, Config)
	end
end

return {
	seeingPlayerStartsChase = function()
		local b = KillerBrain.new()
		run(b, 1, { visibleTarget = "ana", minRoomDistance = 0 })
		assert(b.state == "Chase" and b.target == "ana")
	end,
	losesTargetAfterEightSeconds = function()
		local b = KillerBrain.new()
		run(b, 1, { visibleTarget = "ana", minRoomDistance = 0 })
		run(b, 7, { minRoomDistance = 0 })
		assert(b.state == "Chase" and b.target == "ana")
		run(b, 1, { minRoomDistance = 0 })
		assert(b.state == "Patrol" and b.target == nil)
	end,
	searchesAfterTwoMinutesFar = function()
		local b = KillerBrain.new()
		run(b, 119, { minRoomDistance = 4 })
		assert(b.state == "Patrol")
		run(b, 1, { minRoomDistance = 4 })
		assert(b.state == "Search")
	end,
	closeDistanceResetsSearchTimer = function()
		local b = KillerBrain.new()
		run(b, 100, { minRoomDistance = 4 })
		run(b, 1, { minRoomDistance = 3 })
		run(b, 100, { minRoomDistance = 4 })
		assert(b.state == "Patrol")
	end,
	searchKeepsGoingUntilSameRoom = function()
		local b = KillerBrain.new()
		run(b, 120, { minRoomDistance = 9 })
		run(b, 1, { minRoomDistance = 2 })
		assert(b.state == "Search")
		run(b, 1, { minRoomDistance = 0 })
		assert(b.state == "Patrol")
	end,
	searchEndsWhenAllInRefuges = function()
		local b = KillerBrain.new()
		run(b, 120, { minRoomDistance = 9 })
		run(b, 1, {})
		assert(b.state == "Patrol")
	end,
	allInRefugesKeepsPatrolling = function()
		local b = KillerBrain.new()
		run(b, 200, {})
		assert(b.state == "Patrol")
	end,
	neverCampsARefuge = function()
		local b = KillerBrain.new()
		run(b, 200, { refugeCamper = "ana" })
		assert(b.state == "Patrol" and b.target == nil)
	end,
	stunnedIgnoresTargetsUntilItEnds = function()
		local b = KillerBrain.new()
		run(b, 1, { visibleTarget = "ana", minRoomDistance = 0 })
		Taser.applyStun(b, b.clock, Config)
		run(b, 9, { visibleTarget = "ana", minRoomDistance = 0 })
		assert(b.state == "Stunned" and b.target == nil)
		run(b, 1, { visibleTarget = "ana", minRoomDistance = 0 })
		assert(b.state == "Chase")
	end,
	targetGoneDropsItImmediately = function()
		local b = KillerBrain.new()
		run(b, 1, { visibleTarget = "ana", minRoomDistance = 0 })
		KillerBrain.dropTarget(b, "ana")
		assert(b.state == "Patrol" and b.target == nil)
	end,
	droppingOtherPlayerKeepsChase = function()
		local b = KillerBrain.new()
		run(b, 1, { visibleTarget = "ana", minRoomDistance = 0 })
		KillerBrain.dropTarget(b, "beto")
		assert(b.state == "Chase" and b.target == "ana")
	end,
}
