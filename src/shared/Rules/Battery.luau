--!strict
-- Batería de la linterna, de 0 a 1. Sin APIs de Roblox.

local Battery = {}

function Battery.drain(level: number, seconds: number, cfg: any): number
	return math.max(level - seconds / cfg.FlashlightSeconds, 0)
end

function Battery.recharge(level: number, cfg: any): number
	return math.min(level + cfg.BatteryRechargeSeconds / cfg.FlashlightSeconds, 1)
end

function Battery.canRecharge(level: number): boolean
	return level < 1
end

return Battery
