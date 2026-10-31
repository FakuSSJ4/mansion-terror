--!strict
-- Progreso del equipo: llaves, libros y puertas. Sin APIs de Roblox.

export type State = {
	keys: { [number]: boolean },
	books: { [string]: boolean },
	keyCount: number,
	bookCount: number,
	bookGoal: number,
}

local Progress = {}

function Progress.new(bookGoal: number): State
	return { keys = {}, books = {}, keyCount = 0, bookCount = 0, bookGoal = bookGoal }
end

function Progress.addKey(s: State, n: number): boolean
	if s.keys[n] then
		return false
	end
	s.keys[n] = true
	s.keyCount += 1
	return true
end

function Progress.addBook(s: State, id: string): boolean
	if s.books[id] then
		return false
	end
	s.books[id] = true
	s.bookCount += 1
	return true
end

-- Si el equipo tiene la llave de esa puerta; las que no figuran en DoorKeys no llevan llave.
function Progress.isDoorOpen(s: State, door: string, cfg: any): boolean
	local key = cfg.DoorKeys[door]
	return key == nil or s.keys[key] == true
end

function Progress.isExitOpen(s: State): boolean
	return s.bookCount >= s.bookGoal
end

return Progress
