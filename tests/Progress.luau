--!strict
local Config = require("../src/shared/Config")
local Progress = require("../src/shared/Rules/Progress")

local UPPER =
	{ room7 = true, room8 = true, room9 = true, room10 = true, room11 = true, room12 = true }

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
	keysAlternateBetweenFloors = function()
		for n = 2, #Config.KeyRooms do
			local before = UPPER[Config.KeyRooms[n - 1]] == true
			local now = UPPER[Config.KeyRooms[n]] == true
			assert(before ~= now, `las llaves {n - 1} y {n} están en el mismo piso`)
		end
	end,
	blackKeyOpensTheCellarLast = function()
		assert(Config.KeyColors[Config.DoorKeys.room5].name == "negra")
		assert(Config.DoorKeys.room5 == #Config.KeyRooms)
	end,
	everyKeyIsReachableInOrder = function()
		-- Pieza donde está cada llave -> puerta que hay que haber abierto antes para llegar.
		local needs = {
			room1 = {},
			room8 = { "room7" },
			room2 = { "room2" },
			room10 = { "room7", "room9" },
			room3 = { "room2", "room3" },
			room12 = { "room7", "room9", "room11" },
		}
		local opened: { [string]: boolean } = {}
		for n, room in Config.KeyRooms do
			for _, door in needs[room] do
				assert(opened[door], `la llave {n} queda detrás de {door}`)
			end
			for door, key in Config.DoorKeys do
				if key == n then
					opened[door] = true
				end
			end
		end
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
