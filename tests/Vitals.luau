--!strict
local Config = require("../src/shared/Config")
local Vitals = require("../src/shared/Rules/Vitals")

local function hitsToKill(damage: number): number
	local hp, hits = Config.MaxHealth, 0
	while hp > 0 do
		hp = Vitals.damage(hp, damage)
		hits += 1
	end
	return hits
end

return {
	mainKillerNeedsThreeHits = function()
		assert(hitsToKill(Config.Killers.main.damage) == 3)
	end,
	secondKillerNeedsTwoHits = function()
		assert(hitsToKill(Config.Killers.gentleman.damage) == 2)
	end,
	secondKillerWalksSlower = function()
		local main, second = Config.Killers.main, Config.Killers.gentleman
		assert(second.patrolSpeed < main.patrolSpeed)
		assert(second.chaseSpeed < main.chaseSpeed)
	end,
	secondKillerStaysOnUpperFloor = function()
		local rooms = Config.Killers.gentleman.rooms
		assert(rooms.room7 and rooms.room12)
		assert(not rooms.attic and not rooms.hall)
	end,
	butcherNeedsFiveHits = function()
		local damage = Config.Killers.butcher.damage
		assert(damage * 5 >= Config.MaxHealth and damage * 4 < Config.MaxHealth)
	end,
	butcherIsFasterThanMain = function()
		local butcher, main = Config.Killers.butcher, Config.Killers.main
		assert(butcher.patrolSpeed > main.patrolSpeed)
		assert(butcher.chaseSpeed > main.chaseSpeed)
		assert(butcher.searchSpeed > main.searchSpeed)
	end,
	butcherClimbsOnlyOneFloor = function()
		local rooms = Config.Killers.butcher.rooms
		assert(Config.Killers.butcher.startRoom == "room6")
		assert(rooms.room5 and rooms.room6 and rooms.room4 and rooms.hall)
		assert(not rooms.room7 and not rooms.attic)
	end,
	damageSubtractsDownToZero = function()
		assert(Vitals.damage(100, 50) == 50)
		assert(Vitals.damage(50, 50) == 0)
		assert(Vitals.damage(20, 50) == 0)
	end,
	healCapsAtMax = function()
		assert(Vitals.heal(80, Config.PillHeal, Config.MaxHealth) == 100)
		assert(Vitals.heal(10, Config.PillHeal, Config.MaxHealth) == 60)
	end,
	fullHealthCannotTakePill = function()
		assert(not Vitals.canTakePill(100, Config.MaxHealth))
		assert(Vitals.canTakePill(99, Config.MaxHealth))
	end,
}
