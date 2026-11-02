--!strict
local Config = require("../src/shared/Config")
local MapDef = require("../src/shared/Rules/MapDef")
local Placement = require("../src/shared/Rules/Placement")

local Needs = MapDef.needs()

local function always(_: string): boolean
	return true
end

local function rollerFor(seed: number): (number) -> number
	-- Generador congruencial simple: lune no trae `Random` de Roblox.
	local state = seed * 7919 + 13
	return function(n)
		state = (state * 1103515245 + 12345) % 2147483648
		return math.floor(state / 65536) % n + 1
	end
end

return {
	everyKeyIsReachableWithThePreviousOnes = function()
		for seed = 1, 300 do
			local rooms =
				Placement.keyRooms(Needs, Config.DoorKeys, Config.KeyCount, rollerFor(seed), always)
			assert(rooms and #rooms == Config.KeyCount, `semilla {seed} no repartió las llaves`)
			local opened: { [string]: boolean } = {}
			for n, room in rooms do
				for _, door in Needs[room] do
					assert(opened[door], `semilla {seed}: la llave {n} queda detrás de {door}`)
				end
				for door, key in Config.DoorKeys do
					if key == n then
						opened[door] = true
					end
				end
			end
		end
	end,
	keysGoInDifferentRooms = function()
		for seed = 1, 100 do
			local rooms =
				Placement.keyRooms(Needs, Config.DoorKeys, Config.KeyCount, rollerFor(seed), always)
			local seen: { [string]: boolean } = {}
			for _, room in rooms :: { string } do
				assert(not seen[room], `semilla {seed} repite {room}`)
				seen[room] = true
			end
		end
	end,
	keysVaryBetweenGames = function()
		local layouts: { [string]: boolean } = {}
		for seed = 1, 50 do
			local rooms =
				Placement.keyRooms(Needs, Config.DoorKeys, Config.KeyCount, rollerFor(seed), always)
			layouts[table.concat(rooms :: { string }, ",")] = true
		end
		assert(next(layouts) ~= nil)
		local count = 0
		for _ in layouts do
			count += 1
		end
		assert(count > 10)
	end,
	keysCanLandInTheNewRoomsAndTheHallShelves = function()
		local found: { [string]: boolean } = {}
		for seed = 1, 300 do
			for _, room in
				Placement.keyRooms(Needs, Config.DoorKeys, Config.KeyCount, rollerFor(seed), always) :: { string }
			do
				found[room] = true
			end
		end
		assert(found.gameRoom and found.bar and found.hall)
	end,
	keysNeverGoInCellarOrAttic = function()
		for seed = 1, 100 do
			for _, room in
				Placement.keyRooms(Needs, Config.DoorKeys, Config.KeyCount, rollerFor(seed), always) :: { string }
			do
				assert(room ~= "room5" and room ~= "room6" and room ~= "attic")
			end
		end
	end,
	roomsWithoutSpotsAreSkipped = function()
		local function noBar(room: string): boolean
			return room ~= "bar"
		end
		for seed = 1, 100 do
			for _, room in
				Placement.keyRooms(Needs, Config.DoorKeys, Config.KeyCount, rollerFor(seed), noBar) :: { string }
			do
				assert(room ~= "bar")
			end
		end
	end,
	scrollsGoInDifferentRoomsAndCanUseNewOnes = function()
		local found: { [string]: boolean } = {}
		for seed = 1, 300 do
			local rooms = Placement.scrollRooms(Config.BookCount, rollerFor(seed), always)
			assert(rooms and #rooms == Config.BookCount)
			local seen: { [string]: boolean } = {}
			for _, room in rooms do
				assert(not seen[room])
				seen[room] = true
				found[room] = true
			end
		end
		assert(found.gameRoom and found.bar and found.hall)
	end,
	theAtticAlwaysHasExactlyOneScroll = function()
		for seed = 1, 200 do
			local rooms = Placement.scrollRooms(Config.BookCount, rollerFor(seed), always)
			local inAttic = 0
			for _, room in rooms :: { string } do
				if room == "attic" then
					inAttic += 1
				end
			end
			assert(inAttic == 1, `semilla {seed}: {inAttic} pergaminos en el altillo`)
		end
	end,
	scrollsFailWhenThereAreNotEnoughRooms = function()
		local function onlyHall(room: string): boolean
			return room == "hall"
		end
		assert(Placement.scrollRooms(Config.BookCount, rollerFor(1), onlyHall) == nil)
	end,
}
