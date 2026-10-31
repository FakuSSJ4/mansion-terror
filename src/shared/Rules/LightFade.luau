--!strict
-- Cuánto brilla una vela según lo lejos que esté: lo distante se pierde en la oscuridad.

local LightFade = {}

function LightFade.factor(distance: number, cfg: any): number
	local t = (cfg.LightFadeEnd - distance) / (cfg.LightFadeEnd - cfg.LightFadeStart)
	return math.clamp(t, 0, 1)
end

return LightFade
