--!strict
-- Cantidad de objetos escondidos según la dificultad. Sin APIs de Roblox.

local Loot = {}

function Loot.isValid(difficulty: any): boolean
	return difficulty == "easy" or difficulty == "normal" or difficulty == "nightmare"
end

export type Counts = { bandages: number, medkits: number, batteries: number, tasers: number }

function Loot.counts(difficulty: string, cfg: any): Counts
	local scale = if difficulty == "nightmare" then 0.5 elseif difficulty == "easy" then 1.5 else 1
	-- Mitad y mitad entre las dos curas; si el total es impar sobra un botiquín.
	local cures = math.floor(cfg.CureCount * scale)
	local bandages = math.floor(cures / 2)
	return {
		bandages = bandages,
		medkits = cures - bandages,
		batteries = math.floor(cfg.BatteryCount * scale),
		tasers = math.floor(cfg.TaserSpareCount * scale),
	}
end

return Loot
