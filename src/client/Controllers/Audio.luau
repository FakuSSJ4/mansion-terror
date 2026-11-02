--!strict
-- Sonido del juego que depende de lo que pasa con el jugador: música del lobby, zumbido de fondo de
-- la mansión, latido que sube cuando hay un asesino cerca y avisos de golpe, objeto, linterna y compra.
-- La lluvia, los truenos y los cuervos viven en Ambience; el portazo de la fuga, en Escape.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local Audio = {}

local function loop(id: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0
	sound:SetAttribute("TargetVolume", volume)
	sound.Parent = SoundService
	return sound
end

-- Sube o baja el volumen de un sonido en bucle; arranca solo cuando hace falta y se pausa en silencio.
local function fade(sound: Sound, on: boolean, seconds: number)
	local target = if on then sound:GetAttribute("TargetVolume") :: number else 0
	if on and not sound.IsPlaying then
		sound:Play()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = target })
	tween:Play()
	if not on then
		tween.Completed:Once(function()
			if sound.Volume <= 0.001 then
				sound:Pause()
			end
		end)
	end
end

local function once(id: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

function Audio.start()
	local player = Players.LocalPlayer
	local music = loop(Sounds.LobbyMusic, 0.4)
	local drone = loop(Sounds.Drone, 0.35)
	local heartbeat = loop(Sounds.Heartbeat, 0.9)

	local function refreshScene()
		local inLobby = player:GetAttribute("InLobby") == true
		fade(music, inLobby, 1.2)
		fade(drone, not inLobby, 2)
		if inLobby then
			fade(heartbeat, false, 0.4)
		end
	end
	player:GetAttributeChangedSignal("InLobby"):Connect(refreshScene)
	refreshScene()

	-- Latido: más fuerte y más rápido cuanto más cerca está un asesino.
	player:GetAttributeChangedSignal("Danger"):Connect(function()
		local danger = (player:GetAttribute("Danger") :: number?) or 0
		if danger <= 0 then
			fade(heartbeat, false, 0.8)
			return
		end
		if not heartbeat.IsPlaying then
			heartbeat:Play()
		end
		heartbeat.PlaybackSpeed = 0.9 + danger * 0.8
		TweenService
			:Create(
				heartbeat,
				TweenInfo.new(0.25),
				{ Volume = math.clamp(0.2 + danger * 0.8, 0, 1) }
			)
			:Play()
	end)

	Remotes.get("Hit").OnClientEvent:Connect(function()
		once(Sounds.Hit, 0.9)
	end)

	-- Fin de partida: un acorde de alivio al escapar y otro muy distinto al caer.
	workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		if player:GetAttribute("InLobby") == true then
			return
		end
		local phase = workspace:GetAttribute("Phase")
		if phase == "Won" then
			once(Sounds.Win, 0.9)
		elseif phase == "Dead" then
			once(Sounds.GameOver, 0.8)
		end
	end)

	-- Un objeto nuevo: llave, pergamino, gema, linterna o taser.
	local function onGain()
		if player:GetAttribute("InLobby") ~= true then
			once(Sounds.Pickup, 0.6)
		end
	end
	player:GetAttributeChangedSignal("Gems"):Connect(onGain)
	player:GetAttributeChangedSignal("HasFlashlight"):Connect(function()
		if player:GetAttribute("HasFlashlight") == true then
			onGain()
		end
	end)
	player:GetAttributeChangedSignal("TaserCharges"):Connect(function()
		if ((player:GetAttribute("TaserCharges") :: number?) or 0) > 0 then
			onGain()
		end
	end)
	workspace:GetAttributeChangedSignal("Keys"):Connect(onGain)
	workspace:GetAttributeChangedSignal("Books"):Connect(onGain)
	player:GetAttributeChangedSignal("FlashlightOn"):Connect(function()
		once(Sounds.FlashlightClick, 0.5)
	end)

	-- Compra en la tienda: suena cuando una ventaja pasa a ser tuya.
	for id in Config.Shop do
		player:GetAttributeChangedSignal(`Owns_{id}`):Connect(function()
			if
				player:GetAttribute(`Owns_{id}`) == true
				and player:GetAttribute("InLobby") == true
			then
				once(Sounds.Buy, 0.8)
			end
		end)
	end
end

return Audio
