--!strict
-- A quién mira el espectador: el siguiente de la lista de vivos. Sin APIs de Roblox.

local Spectate = {}

function Spectate.nextTarget<T>(alive: { T }, current: T?): T?
	if #alive == 0 then
		return nil
	end
	local index = if current then table.find(alive, current) else nil
	return alive[if index then index % #alive + 1 else 1]
end

return Spectate
