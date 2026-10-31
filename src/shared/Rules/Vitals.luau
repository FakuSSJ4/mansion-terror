--!strict
-- Reglas de vida. Sin APIs de Roblox.

local Vitals = {}

function Vitals.damage(hp: number, amount: number): number
	return math.max(hp - amount, 0)
end

function Vitals.heal(hp: number, amount: number, maxHp: number): number
	return math.min(hp + amount, maxHp)
end

function Vitals.canTakePill(hp: number, maxHp: number): boolean
	return hp < maxHp
end

return Vitals
