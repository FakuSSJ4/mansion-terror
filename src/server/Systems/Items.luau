--!strict
-- Reparte llaves, libros, píldoras y recargas en escondites al azar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ItemClaim = require(Shared:WaitForChild("Rules"):WaitForChild("ItemClaim"))

local Vitality = require(script.Parent:WaitForChild("Vitality"))

local PICKUP_DISTANCE = 7

local Items = {}

type Handlers = {
	onKey: (player: Player, n: number) -> (),
	onBook: (player: Player, id: string) -> (),
}

local folder: Folder?
local claims = ItemClaim.new()
local lastUse: { [Player]: number } = {}

local function notify(player: Player, text: string)
	Remotes.get("Notify"):FireClient(player, text)
end

local function canUse(player: Player, position: Vector3): boolean
	local now = os.clock()
	if now - (lastUse[player] or 0) < Config.InteractCooldown then
		return false
	end
	lastUse[player] = now
	return Vitality.canReach(player, position)
end

local LOOKS = {
	key = {
		name = "Llave",
		size = Vector3.new(0.9, 0.25, 0.4),
		color = Color3.fromRGB(190, 150, 60),
		material = Enum.Material.Metal,
	},
	book = {
		name = "Libro",
		size = Vector3.new(1.1, 0.35, 1.5),
		color = Color3.fromRGB(90, 30, 30),
		material = Enum.Material.Fabric,
	},
	scroll = {
		name = "Pergamino",
		size = Vector3.new(1.5, 0.4, 0.4),
		color = Color3.fromRGB(200, 180, 130),
		material = Enum.Material.Fabric,
	},
	pill = {
		name = "Píldoras",
		size = Vector3.new(0.8, 0.5, 0.5),
		color = Color3.fromRGB(215, 215, 225),
		material = Enum.Material.SmoothPlastic,
	},
	recharge = {
		name = "Carga de taser",
		size = Vector3.new(0.8, 0.5, 0.6),
		color = Color3.fromRGB(60, 90, 140),
		material = Enum.Material.Metal,
	},
}

local function spawnItem(id: string, kind: string, position: Vector3, onPicked: (Player) -> boolean)
	local look = LOOKS[kind]
	local item = Instance.new("Part")
	item.Name = id
	item.Anchored = true
	item.CanCollide = false
	item.Size = look.size
	item.Color = look.color
	item.Material = look.material
	item.Position = position
	item.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Agarrar"
	prompt.ObjectText = look.name
	prompt.MaxActivationDistance = PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = item
	prompt.Triggered:Connect(function(player)
		if not canUse(player, position) or not onPicked(player) then
			return
		end
		if ItemClaim.tryClaim(claims, id, player.UserId) then
			item:Destroy()
		end
	end)
end

local function takeSpot(spots: { Vector3 }, random: Random): Vector3
	return table.remove(spots, random:NextInteger(1, #spots)) :: Vector3
end

function Items.spawnAll(refs: any, handlers: Handlers)
	Items.clear()
	local holder = Instance.new("Folder")
	holder.Name = "Objetos"
	holder.Parent = workspace
	folder = holder
	claims = ItemClaim.new()

	local random = Random.new()
	local free: { [string]: { Vector3 } } = {}
	for room, spots in refs.hidingSpots do
		free[room] = table.clone(spots)
	end

	-- Si otro jugador ya lo agarró, no vuelve a contar.
	local function once(id: string, fn: (Player) -> ()): (Player) -> boolean
		return function(player)
			if claims[id] then
				return false
			end
			fn(player)
			return true
		end
	end

	for n = 1, Config.KeyCount do
		local id = `key{n}`
		spawnItem(
			id,
			"key",
			takeSpot(free[`room{n}`], random),
			once(id, function(player)
				handlers.onKey(player, n)
			end)
		)
	end

	-- Una ronda por las piezas del ala final hasta repartir todos los libros.
	local bookRooms = { "room7", "room8", "room9", "room10", "room11", "room12" }
	for n = 1, Config.BookCount do
		local id = `book{n}`
		local room = bookRooms[(n - 1) % #bookRooms + 1]
		spawnItem(
			id,
			if n % 2 == 0 then "scroll" else "book",
			takeSpot(free[room], random),
			once(id, function(player)
				handlers.onBook(player, id)
			end)
		)
	end

	local function randomSpot(): Vector3
		while true do
			local spots = free[`room{random:NextInteger(1, 12)}`]
			if #spots > 0 then
				return takeSpot(spots, random)
			end
		end
	end

	for n = 1, Config.PillCount do
		local id = `pill{n}`
		spawnItem(id, "pill", randomSpot(), function(player)
			if claims[id] then
				return false
			end
			if not Vitality.heal(player, Config.PillHeal) then
				notify(player, "Tenés la vida llena")
				return false
			end
			notify(player, "Te curaste")
			return true
		end)
	end

	for n = 1, Config.TaserRechargeCount do
		local id = `recharge{n}`
		spawnItem(
			id,
			"recharge",
			randomSpot(),
			once(id, function(player)
				Vitality.addCharges(player, 1)
				notify(player, "+1 carga de taser")
			end)
		)
	end
end

function Items.clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
end

-- El taser del hall queda siempre; cada jugador lo agarra una vez por partida.
function Items.setupTaserPedestal(pedestal: BasePart)
	local taser = Instance.new("Part")
	taser.Name = "Taser"
	taser.Anchored = true
	taser.CanCollide = false
	taser.Size = Vector3.new(1.4, 0.5, 0.5)
	taser.Color = Color3.fromRGB(230, 190, 40)
	taser.Material = Enum.Material.Metal
	taser.Position = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2 + 0.3, 0)
	taser.Parent = pedestal

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Agarrar"
	prompt.ObjectText = "Taser"
	prompt.MaxActivationDistance = PICKUP_DISTANCE
	prompt.Parent = taser
	prompt.Triggered:Connect(function(player)
		if not canUse(player, taser.Position) then
			return
		end
		if player:GetAttribute("TaserTaken") then
			notify(player, "Ya agarraste el taser")
			return
		end
		player:SetAttribute("TaserTaken", true)
		Vitality.addCharges(player, Config.TaserStartCharges)
		notify(player, `Taser con {Config.TaserStartCharges} cargas. Clic para disparar`)
	end)
end

return Items
