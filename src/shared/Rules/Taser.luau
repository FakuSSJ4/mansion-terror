--!strict
-- Reglas del aturdimiento. Sin APIs de Roblox.

type Stunnable = { stunUntil: number, immuneUntil: number }

local Taser = {}

function Taser.canStun(killer: Stunnable, now: number): boolean
	return now >= killer.immuneUntil
end

function Taser.applyStun(killer: Stunnable, now: number, cfg: any)
	killer.stunUntil = now + cfg.TaserStunSeconds
	killer.immuneUntil = killer.stunUntil + cfg.TaserImmunitySeconds
end

return Taser
