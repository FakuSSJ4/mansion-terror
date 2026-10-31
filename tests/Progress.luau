--!strict
local Progress = require("../src/shared/Rules/Progress")

return {
	firstDoorNeedsNoKey = function()
		local s = Progress.new(8)
		assert(Progress.isDoorOpen(s, 1))
		assert(not Progress.isDoorOpen(s, 2))
	end,
	keyNOpensDoorToNextRoom = function()
		local s = Progress.new(8)
		assert(Progress.addKey(s, 1))
		assert(Progress.isDoorOpen(s, 2))
		assert(not Progress.isDoorOpen(s, 3))
		assert(Progress.addKey(s, 6))
		assert(Progress.isDoorOpen(s, 7))
	end,
	duplicatesCountOnce = function()
		local s = Progress.new(8)
		assert(Progress.addKey(s, 1))
		assert(not Progress.addKey(s, 1))
		assert(Progress.addBook(s, "a"))
		assert(not Progress.addBook(s, "a"))
		assert(s.keyCount == 1 and s.bookCount == 1)
	end,
	exitNeedsEightBooks = function()
		local s = Progress.new(8)
		for i = 1, 7 do
			Progress.addBook(s, `b{i}`)
		end
		assert(not Progress.isExitOpen(s))
		Progress.addBook(s, "b8")
		assert(Progress.isExitOpen(s))
	end,
}
