--!strict
-- Dónde se esconden las llaves y los pergaminos en cada partida. Sin APIs de Roblox.
-- Las llaves se reparten en orden y solo en piezas a las que ya se llega con las anteriores,
-- así que la partida siempre se puede ganar.

local Placement = {}

-- El sótano y el altillo no guardan llaves: el sótano se abre con la última y al altillo
-- se sube con la escalera, que está en el sótano.
Placement.KeyPool = {
	"hall",
	"room1",
	"room2",
	"room3",
	"room4",
	"room7",
	"room8",
	"room9",
	"room10",
	"room11",
	"room12",
	"gameRoom",
	"bar",
}

Placement.ScrollPool = {
	"hall",
	"room1",
	"room2",
	"room3",
	"room4",
	"room5",
	"room6",
	"room7",
	"room8",
	"room9",
	"room10",
	"room11",
	"room12",
	"attic",
	"gameRoom",
	"bar",
}

-- `roll(n)` devuelve un entero de 1 a n; `hasSpot` dice si a la pieza le queda un escondite.
export type Roll = (n: number) -> number

-- Una pieza por llave, o nil si no hubo forma de repartirlas todas.
function Placement.keyRooms(
	needs: { [string]: { string } },
	doorKeys: { [string]: number },
	keyCount: number,
	roll: Roll,
	hasSpot: (room: string) -> boolean
): { string }?
	local opened: { [string]: boolean } = {}
	local used: { [string]: boolean } = {}
	local rooms = {}
	for n = 1, keyCount do
		local eligible = {}
		for _, room in Placement.KeyPool do
			local reachable = not used[room] and hasSpot(room)
			for _, door in needs[room] do
				reachable = reachable and opened[door] == true
			end
			if reachable then
				table.insert(eligible, room)
			end
		end
		if #eligible == 0 then
			return nil
		end
		local room = eligible[roll(#eligible)]
		used[room] = true
		table.insert(rooms, room)
		for door, key in doorKeys do
			if key == n then
				opened[door] = true
			end
		end
	end
	return rooms
end

-- `count` piezas distintas para los pergaminos: el altillo siempre lleva uno (y solo uno) y los
-- demás van al azar en otras piezas.
function Placement.scrollRooms(
	count: number,
	roll: Roll,
	hasSpot: (room: string) -> boolean
): { string }?
	if not hasSpot("attic") then
		return nil
	end
	local pool = {}
	for _, room in Placement.ScrollPool do
		if room ~= "attic" and hasSpot(room) then
			table.insert(pool, room)
		end
	end
	if #pool < count - 1 then
		return nil
	end
	local rooms = { "attic" }
	for _ = 2, count do
		table.insert(rooms, table.remove(pool, roll(#pool)) :: string)
	end
	return rooms
end

return Placement
