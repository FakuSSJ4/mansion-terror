--!strict
-- Cuándo caen los rayos de una partida: dentro de una ventana de unos minutos, a horas al azar,
-- y nunca durante el primer minuto.

local Storm = {}

export type RandomLike = {
	NextNumber: (any, number, number) -> number,
	NextInteger: (any, number, number) -> number,
}

export type Settings = {
	WindowsMinutes: { number },
	QuietSeconds: number,
	StrikesPerWindowMinute: number,
	MinStrikes: number,
}

-- Segundos (desde que empieza la partida) en que cae cada rayo, de menor a mayor.
function Storm.schedule(minutes: number, settings: Settings, random: RandomLike): { number }
	local from = settings.QuietSeconds
	local to = math.max(from, minutes * 60)
	local count =
		math.max(settings.MinStrikes, math.round(minutes * settings.StrikesPerWindowMinute))
	local times = {}
	for index = 1, count do
		times[index] = random:NextNumber(from, to)
	end
	table.sort(times)
	return times
end

function Storm.pickWindow(settings: Settings, random: RandomLike): number
	return settings.WindowsMinutes[random:NextInteger(1, #settings.WindowsMinutes)]
end

return Storm
