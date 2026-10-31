--!strict
-- Reparte llaves, libros, píldoras, tasers, pilas, linterna y escalera en escondites al azar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Battery = require(Rules:WaitForChild("Battery"))
local ItemClaim = require(Rules:WaitForChild("ItemClaim"))
local Taser = require(Rules:WaitForChild("Taser"))

local Loot = require(Rules:WaitForChild("Loot"))
local Mansion = require(script.Parent:WaitForChild("Mansion"))
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
local dropCount = 0
local mansion: any
local hatchPrompt: ProximityPrompt?

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

local function look(name: string, size: Vector3, color: Color3, material: Enum.Material)
	return { name = name, size = size, color = color, material = material }
end

local LOOKS = {
	key = look(
		"Llave",
		Vector3.new(0.9, 0.25, 0.4),
		Color3.fromRGB(190, 150, 60),
		Enum.Material.Metal
	),
	book = look(
		"Libro",
		Vector3.new(1.1, 0.35, 1.5),
		Color3.fromRGB(90, 30, 30),
		Enum.Material.Fabric
	),
	scroll = look(
		"Pergamino",
		Vector3.new(1.5, 0.4, 0.4),
		Color3.fromRGB(200, 180, 130),
		Enum.Material.Fabric
	),
	pill = look(
		"Píldoras",
		Vector3.new(0.8, 0.5, 0.5),
		Color3.fromRGB(215, 215, 225),
		Enum.Material.SmoothPlastic
	),
	taser = look(
		"Taser",
		Vector3.new(1.3, 0.5, 0.5),
		Color3.fromRGB(230, 190, 40),
		Enum.Material.Metal
	),
	battery = look(
		"Pila",
		Vector3.new(0.5, 0.8, 0.5),
		Color3.fromRGB(70, 130, 80),
		Enum.Material.Metal
	),
	flashlight = look(
		"Linterna",
		Vector3.new(1.5, 0.5, 0.5),
		Color3.fromRGB(60, 60, 66),
		Enum.Material.Metal
	),
	ladder = look(
		"Escalera",
		Vector3.new(0.5, 0.4, 6),
		Color3.fromRGB(110, 80, 50),
		Enum.Material.Wood
	),
	goldKey = look(
		"Llave dorada del lobo",
		Vector3.new(1.3, 0.3, 0.6),
		Color3.fromRGB(table.unpack(Config.GoldKeyRgb)),
		Enum.Material.Neon
	),
}

local function spawnItem(
	id: string,
	kind: string,
	position: Vector3,
	onPicked: (Player) -> boolean,
	keyColor: { name: string, rgb: { number } }?
)
	local itemLook = LOOKS[kind]
	local item = Instance.new("Part")
	item.Name = id
	item.Anchored = true
	item.CanCollide = false
	item.CanQuery = false
	item.Size = itemLook.size
	item.Color = if keyColor then Color3.fromRGB(table.unpack(keyColor.rgb)) else itemLook.color
	item.Material = itemLook.material
	item.Position = position
	item.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Agarrar"
	prompt.ObjectText = if keyColor then `Llave {keyColor.name}` else itemLook.name
	prompt.MaxActivationDistance = PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = item
	prompt.Triggered:Connect(function(player)
		if claims[id] or not canUse(player, position) or not onPicked(player) then
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

-- La linterna y la escalera son únicas: se llevan encima y se caen si el dueño muere o se va.
local function spawnFlashlight(position: Vector3, level: number)
	dropCount += 1
	spawnItem(`flashlight{dropCount}`, "flashlight", position, function(player)
		player:SetAttribute("HasFlashlight", true)
		player:SetAttribute("Battery", level)
		notify(player, "Encontraste la linterna. F para prenderla")
		return true
	end)
end

local function spawnTaser(position: Vector3)
	dropCount += 1
	spawnItem(`taser{dropCount}`, "taser", position, function(player)
		if not Taser.canPickUp((player:GetAttribute("TaserCharges") :: number?) or 0) then
			notify(player, "Ya llevás un taser")
			return false
		end
		player:SetAttribute("TaserCharges", Config.TaserStartCharges)
		notify(player, "Agarraste un taser. Clic para disparar")
		return true
	end)
end

local function spawnLadder(position: Vector3)
	dropCount += 1
	spawnItem(`ladder{dropCount}`, "ladder", position, function(player)
		player:SetAttribute("HasLadder", true)
		notify(player, "Llevás la escalera: buscá la trampilla del techo")
		return true
	end)
end

function Items.spawnGoldKey(position: Vector3)
	dropCount += 1
	spawnItem(`goldkey{dropCount}`, "goldKey", position, function(player)
		player:SetAttribute("HasGoldKey", true)
		notify(player, "Llave dorada del lobo: abrí la puerta principal")
		return true
	end)
end

local function dropCarried(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local position = if root then root.Position - Vector3.new(0, 2.6, 0) else Vector3.zero
	if player:GetAttribute("HasFlashlight") then
		spawnFlashlight(position, (player:GetAttribute("Battery") :: number?) or 0)
		player:SetAttribute("HasFlashlight", false)
		player:SetAttribute("FlashlightOn", false)
	end
	if player:GetAttribute("HasLadder") then
		spawnLadder(position + Vector3.new(1.5, 0, 0))
		player:SetAttribute("HasLadder", false)
	end
	if player:GetAttribute("HasGoldKey") then
		Items.spawnGoldKey(position + Vector3.new(-1.5, 0, 0))
		player:SetAttribute("HasGoldKey", false)
	end
	if ((player:GetAttribute("TaserCharges") :: number?) or 0) > 0 then
		spawnTaser(position + Vector3.new(0, 0, 1.5))
		player:SetAttribute("TaserCharges", 0)
	end
end

local function placeLadder()
	local ladder = Instance.new("TrussPart")
	ladder.Name = "EscaleraPuesta"
	ladder.Anchored = true
	ladder.Size = mansion.ladderSize
	ladder.CFrame = mansion.ladderCFrame
	-- El truss invisible da el trepado; lo que se ve son largueros y peldaños de madera.
	ladder.Transparency = 1
	ladder.Parent = folder
	local function wood(name: string, size: Vector3, offset: CFrame)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Size = size
		part.CFrame = mansion.ladderCFrame * offset
		part.Color = Color3.fromRGB(122, 84, 48)
		part.Material = Enum.Material.WoodPlanks
		part.Parent = ladder
	end
	local height = mansion.ladderSize.Y
	for _, x in { -1.5, 1.5 } do
		wood("Larguero", Vector3.new(0.45, height, 0.45), CFrame.new(x, 0, -0.9))
	end
	for y = -height / 2 + 1, height / 2 - 0.5, 1.5 do
		wood("Peldano", Vector3.new(3.2, 0.28, 0.32), CFrame.new(0, y, -0.9))
	end
	Mansion.setHatchOpen(true)
	if hatchPrompt then
		hatchPrompt.Enabled = false
	end
end

function Items.spawnAll(refs: any, handlers: Handlers, counts: Loot.Counts)
	Items.clear()
	Mansion.setHatchOpen(false)
	local holder = Instance.new("Folder")
	holder.Name = "Objetos"
	holder.Parent = workspace
	folder = holder
	claims = ItemClaim.new()
	if hatchPrompt then
		hatchPrompt.Enabled = true
	end

	local random = Random.new()
	local free: { [string]: { Vector3 } } = {}
	for room, spots in refs.hidingSpots do
		free[room] = table.clone(spots)
	end

	for n = 1, Config.KeyCount do
		spawnItem(`key{n}`, "key", takeSpot(free[Config.KeyRooms[n]], random), function(player)
			handlers.onKey(player, n)
			return true
		end, Config.KeyColors[n])
	end

	-- Un pergamino en el sótano, uno en el altillo, uno en planta baja y uno en el primer piso.
	local function pick(rooms: { string }): string
		return rooms[random:NextInteger(1, #rooms)]
	end
	local scrollRooms = {
		pick({ "room5", "room6" }),
		"attic",
		pick({ "room2", "room3" }),
		pick({ "room9", "room10", "room11", "room12" }),
	}
	for n = 1, Config.BookCount do
		local id = `book{n}`
		spawnItem(id, "scroll", takeSpot(free[scrollRooms[n]], random), function(player)
			handlers.onBook(player, id)
			return true
		end)
	end

	local function randomSpot(rooms: { number }): Vector3
		-- A veces cae en un hueco de las librerías del hall.
		local shelves = free.hall
		if shelves and #shelves > 0 and random:NextNumber() < 0.3 then
			return takeSpot(shelves, random)
		end
		while true do
			local spots = free[`room{rooms[random:NextInteger(1, #rooms)]}`]
			if #spots > 0 then
				return takeSpot(spots, random)
			end
		end
	end
	local allRooms = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

	for n = 1, counts.pills do
		spawnItem(`pill{n}`, "pill", randomSpot(allRooms), function(player)
			if not Vitality.heal(player, Config.PillHeal) then
				notify(player, "Tenés la vida llena")
				return false
			end
			notify(player, "Te curaste")
			return true
		end)
	end

	for _ = 1, counts.tasers do
		spawnTaser(randomSpot(allRooms))
	end

	for n = 1, counts.batteries do
		spawnItem(`battery{n}`, "battery", randomSpot(allRooms), function(player)
			local level = (player:GetAttribute("Battery") :: number?) or 0
			if not player:GetAttribute("HasFlashlight") then
				notify(player, "Te falta la linterna")
				return false
			end
			if not Battery.canRecharge(level) then
				notify(player, "La batería está llena")
				return false
			end
			player:SetAttribute("Battery", Battery.recharge(level, Config))
			notify(player, "Recargaste la linterna")
			return true
		end)
	end

	spawnFlashlight(refs.flashlightSpot, 1)
	-- La escalera de mano siempre está en el sótano.
	spawnLadder(randomSpot({ 5, 6 }))
end

function Items.clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
end

function Items.debugGive(player: Player)
	player:SetAttribute("HasFlashlight", true)
	player:SetAttribute("Battery", 1)
	player:SetAttribute("HasLadder", true)
	player:SetAttribute("HasGoldKey", true)
end

-- En el hall cada jugador agarra un taser por partida.
local function setupTaserPedestal(pedestal: BasePart)
	local taser = Instance.new("Part")
	taser.Name = "Taser"
	taser.Anchored = true
	taser.CanCollide = false
	taser.Size = LOOKS.taser.size
	taser.Color = LOOKS.taser.color
	taser.Material = LOOKS.taser.material
	taser.Position = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2 + 0.3, 0)
	taser.Parent = pedestal

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Agarrar"
	prompt.ObjectText = "Taser"
	prompt.MaxActivationDistance = PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = taser
	prompt.Triggered:Connect(function(player)
		if not canUse(player, taser.Position) then
			return
		end
		if player:GetAttribute("TaserTaken") then
			notify(player, "Ya agarraste el taser de acá")
			return
		end
		if not Taser.canPickUp((player:GetAttribute("TaserCharges") :: number?) or 0) then
			notify(player, "Ya llevás un taser")
			return
		end
		player:SetAttribute("TaserTaken", true)
		player:SetAttribute("TaserCharges", Config.TaserStartCharges)
		notify(player, "Agarraste un taser. Clic para disparar")
	end)
end

local function setupHatch(point: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Poner escalera"
	prompt.ObjectText = "Trampilla"
	prompt.MaxActivationDistance = Config.InteractRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	hatchPrompt = prompt
	prompt.Triggered:Connect(function(player)
		if not Vitality.canReach(player, point.Position) then
			return
		end
		if not player:GetAttribute("HasLadder") then
			notify(player, "Hace falta una escalera para subir")
			return
		end
		player:SetAttribute("HasLadder", false)
		placeLadder()
		Remotes.get("Notify"):FireAllClients(`{player.DisplayName} puso la escalera del altillo`)
	end)
end

function Items.start(refs: any)
	mansion = refs
	setupTaserPedestal(refs.taserPedestal)
	setupHatch(refs.hatchPoint)
	Vitality.Died:Connect(dropCarried)
	Players.PlayerRemoving:Connect(function(player)
		dropCarried(player)
		lastUse[player] = nil
	end)
end

return Items
