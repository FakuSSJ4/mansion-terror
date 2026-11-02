--!strict
-- Noche con niebla. Los rayos caen a horas al azar dentro de la ventana que se sortea al empezar cada
-- partida (Config.Storm) y nunca en el primer minuto.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Storm = require(Shared:WaitForChild("Rules"):WaitForChild("Storm"))

local Weather = {}

local random = Random.new()
local stormId = 0

function Weather.strike()
	Remotes.get("Lightning"):FireAllClients()
end

-- Arranca el calendario de rayos de una partida; devuelve los minutos de la ventana elegida.
function Weather.beginMatch(minutes: number?): number
	stormId += 1
	local id = stormId
	local window = minutes or Storm.pickWindow(Config.Storm, random)
	local times = Storm.schedule(window, Config.Storm, random)
	print(`[Clima] Ventana de {window} min, rayos en segundos: {table.concat(times, ", ")}`)
	task.spawn(function()
		local startedAt = os.clock()
		for _, at in times do
			task.wait(math.max(0, at - (os.clock() - startedAt)))
			if id ~= stormId then
				return
			end
			Weather.strike()
		end
	end)
	return window
end

-- Cancela los rayos que faltaban (la partida terminó).
function Weather.endMatch()
	stormId += 1
end

function Weather.start()
	Lighting.ClockTime = 0
	-- La luna ilumina el bosque; adentro, el techo la tapa gracias a las sombras globales.
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(64, 62, 76)
	Lighting.OutdoorAmbient = Color3.fromRGB(78, 86, 112)
	Lighting.ExposureCompensation = 0.5
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(70, 82, 104)
	-- Empieza después del largo del hall: la niebla es para el bosque, no para el interior.
	Lighting.FogStart = 100
	Lighting.FogEnd = 240

	task.spawn(function()
		while true do
			task.wait(Config.CrowInterval)
			Remotes.get("Crow"):FireAllClients()
		end
	end)
end

return Weather
