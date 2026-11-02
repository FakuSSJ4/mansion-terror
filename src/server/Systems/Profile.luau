--!strict
-- Lo que cada jugador conserva entre partidas: gemas y ventajas compradas. Se guarda en un
-- DataStore; si no hay acceso (Studio sin permiso de API), se juega con lo que haya en memoria.
-- Los valores van también en atributos del jugador, que replican solos al cliente.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Profile = {}

type Data = { gems: number, owned: { [string]: boolean }, normalWins: number }

local STORE_NAME = "MansionTerrorProfile_v1"
local SAVE_RETRIES = 3

local store: DataStore? = nil
local profiles: { [Player]: Data } = {}
local dirty: { [Player]: boolean } = {}

local function newData(): Data
	return { gems = 0, owned = {}, normalWins = 0 }
end

local function key(player: Player): string
	return `Player_{player.UserId}`
end

-- Aplica a los atributos lo que el jugador tiene: gemas y los efectos de sus ventajas.
local function publish(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Gems", data.gems)
	player:SetAttribute("NormalWins", data.normalWins)
	local reduction = 0
	local staminaMult = 1
	for id, item in Config.Shop do
		local owned = data.owned[id] == true
		player:SetAttribute(`Owns_{id}`, owned)
		if owned then
			reduction = math.max(reduction, item.damageReduction or 0)
			staminaMult = math.max(staminaMult, item.staminaMult or 1)
		end
	end
	player:SetAttribute("DamageReduction", reduction)
	player:SetAttribute("StaminaMult", staminaMult)
end

local function load(player: Player): Data
	local data = newData()
	local current = store
	if not current then
		return data
	end
	for attempt = 1, SAVE_RETRIES do
		local ok, result = pcall(function()
			return current:GetAsync(key(player))
		end)
		if ok then
			if type(result) == "table" then
				local saved = result :: any
				data.gems = math.max(0, math.floor(tonumber(saved.gems) or 0))
				for id, value in saved.owned or {} do
					if Config.Shop[id] and value == true then
						data.owned[id] = true
					end
				end
			end
			return data
		end
		task.wait(attempt)
	end
	warn(`[Perfil] no se pudo cargar a {player.Name}: juega con el perfil vacío y no se guarda`)
	store = nil
	return data
end

local function save(player: Player)
	local data = profiles[player]
	local current = store
	if not data or not current or not dirty[player] then
		return
	end
	dirty[player] = nil
	for attempt = 1, SAVE_RETRIES do
		local ok = pcall(function()
			current:UpdateAsync(key(player), function()
				return { gems = data.gems, owned = data.owned, normalWins = data.normalWins }
			end)
		end)
		if ok then
			return
		end
		task.wait(attempt)
	end
	dirty[player] = true
	warn(`[Perfil] no se pudo guardar a {player.Name}`)
end

function Profile.gems(player: Player): number
	local data = profiles[player]
	return if data then data.gems else 0
end

-- Partidas ganadas en dificultad Normal; con Config.NightmareUnlockWins se desbloquea Pesadilla.
function Profile.addNormalWin(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	data.normalWins += 1
	dirty[player] = true
	publish(player)
	task.spawn(save, player)
end

function Profile.nightmareUnlocked(player: Player): boolean
	local data = profiles[player]
	return data ~= nil and data.normalWins >= Config.NightmareUnlockWins
end

function Profile.addGems(player: Player, amount: number)
	local data = profiles[player]
	if not data or amount <= 0 then
		return
	end
	data.gems += math.floor(amount)
	dirty[player] = true
	publish(player)
end

-- Compra una ventaja. Devuelve nil si salió bien o el motivo si no.
function Profile.buy(player: Player, id: string): string?
	local data = profiles[player]
	local item = Config.Shop[id]
	if not data or not item then
		return "Eso no se vende"
	end
	if data.owned[id] then
		return "Ya la tenés"
	end
	if data.gems < item.price then
		return `Te faltan {item.price - data.gems} gemas`
	end
	data.gems -= item.price
	data.owned[id] = true
	if RunService:IsStudio() then
		print(`[Perfil] {player.Name} compró {id}: quedan {data.gems} gemas`)
	end
	dirty[player] = true
	publish(player)
	task.spawn(save, player)
	return nil
end

function Profile.start()
	if RunService:IsStudio() or game.PlaceId ~= 0 then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		end
	end

	local function onPlayer(player: Player)
		profiles[player] = newData()
		publish(player)
		task.spawn(function()
			local data = load(player)
			if player.Parent then
				profiles[player] = data
				publish(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		dirty[player] = nil
	end)
	game:BindToClose(function()
		for player in profiles do
			save(player)
		end
	end)
	-- Guardado de rutina por si el servidor se cae.
	task.spawn(function()
		while true do
			task.wait(60)
			for player in dirty do
				task.spawn(save, player)
			end
		end
	end)

	Remotes.get("ShopBuy").OnServerEvent:Connect(function(player, id)
		if typeof(id) ~= "string" then
			return
		end
		local problem = Profile.buy(player, id)
		Remotes.get("Notify"):FireClient(player, problem or `Compraste: {Config.Shop[id].name}`)
	end)
end

return Profile
