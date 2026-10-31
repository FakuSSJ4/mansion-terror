--!strict
-- Garantiza que cada objeto lo agarre un solo jugador. Sin APIs de Roblox.

export type Claims = { [string]: number }

local ItemClaim = {}

function ItemClaim.new(): Claims
	return {}
end

function ItemClaim.tryClaim(claims: Claims, itemId: string, playerId: number): boolean
	if claims[itemId] then
		return false
	end
	claims[itemId] = playerId
	return true
end

return ItemClaim
