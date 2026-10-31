--!strict
-- Cantidad de objetos escondidos según la dificultad. Sin APIs de Roblox.

local Loot = {}

function Loot.isValid(difficulty: any): boolean
	return difficulty == "normal" or difficulty == "hard"
end

export type Counts = { pills: number, batteries: number, tasers: number }

function Loot.counts(difficulty: string, cfg: any): Counts
	local scale = if difficulty == "hard" then 0.5 else 1
	return {
		pills = math.floor(cfg.PillCount * scale),
		batteries = math.floor(cfg.BatteryCount * scale),
		tasers = math.floor(cfg.TaserSpareCount * scale),
	}
end

return Loot
