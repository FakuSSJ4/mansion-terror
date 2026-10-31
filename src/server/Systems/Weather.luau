--!strict
-- Noche con niebla y un rayo cada Config.LightningInterval segundos.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Weather = {}

function Weather.strike()
	Remotes.get("Lightning"):FireAllClients()
end

function Weather.start()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(5, 5, 8)
	Lighting.OutdoorAmbient = Color3.fromRGB(14, 16, 24)
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(8, 10, 16)
	Lighting.FogStart = 40
	Lighting.FogEnd = 240

	task.spawn(function()
		while true do
			task.wait(Config.LightningInterval)
			Weather.strike()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.CrowInterval)
			Remotes.get("Crow"):FireAllClients()
		end
	end)
end

return Weather
