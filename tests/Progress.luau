--!strict
local Config = require("../src/shared/Config")
local Progress = require("../src/shared/Rules/Progress")

return {
	doorWithoutKeyIsOpen = function()
		local s = Progress.new(8)
		assert(Progress.isDoorOpen(s, "room1", Config))
		assert(not Progress.isDoorOpen(s, "room7", Config))
	end,
	eachKeyOpensItsDoor = function()
		local s = Progress.new(8)
		Progress.addKey(s, Config.DoorKeys.room7)
		assert(Progress.isDoorOpen(s, "room7", Config))
		assert(Progress.isDoorOpen(s, "room7b", Config))
		assert(not Progress.isDoorOpen(s, "room2", Config))
	end,
	blackKeyOpensTheCellarLast = function()
		assert(Config.KeyColors[Config.DoorKeys.room5].name == "negra")
		assert(Config.DoorKeys.room5 == Config.KeyCount)
	end,
	duplicatesCountOnce = function()
		local s = Progress.new(8)
		assert(Progress.addKey(s, 1))
		assert(not Progress.addKey(s, 1))
		assert(Progress.addBook(s, "a"))
		assert(not Progress.addBook(s, "a"))
		assert(s.keyCount == 1 and s.bookCount == 1)
	end,
	exitNeedsAllBooks = function()
		local s = Progress.new(8)
		for i = 1, 7 do
			Progress.addBook(s, `b{i}`)
		end
		assert(not Progress.isExitOpen(s))
		Progress.addBook(s, "b8")
		assert(Progress.isExitOpen(s))
	end,
}
