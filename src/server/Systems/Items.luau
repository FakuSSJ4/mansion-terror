--!strict
-- Reparte llaves, libros, píldoras, tasers, pilas, linterna y escalera en escondites al azar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Config = require(Shared:WaitForChild("Config"))
local ItemModels = require(Shared:WaitForChild("ItemModels"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Battery = require(Rules:WaitForChild("Battery"))
local ItemClaim = require(Rules:WaitForChild("ItemClaim"))
local Taser = require(Rules:WaitForChild("Taser"))

local Loot = require(Rules:WaitForChild("Loot"))
local Placement = require(Rules:WaitForChild("Placement"))
local Profile = require(script.Parent:WaitForChild("Profile"))
local Mansion = require(script.Parent:WaitForChild("Mansion"))
local Vitality = require(script.Parent:WaitForChild("Vitality"))

local PICKUP_DISTANCE = 7

local Items = {}

type Handlers = {
	onKey: (player: Player, n: number) -> (),
	onBook: (player: Player, id: string) -> (),
	onCode: (player: Player, n: number) -> (),
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
	note = look(
		"Nota",
		Vector3.new(1.2, 0.08, 1.5),
		Color3.fromRGB(226, 214, 184),
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
	gem = look(
		"Gema",
		Vector3.new(0.7, 0.7, 0.7),
		Color3.fromRGB(90, 220, 255),
		Enum.Material.Neon
	),
	goldKey = look(
		"Llave dorada del lobo",
		Vector3.new(1.3, 0.3, 0.6),
		Color3.fromRGB(table.unpack(Config.GoldKeyRgb)),
		Enum.Material.Neon
	),
}

-- Llave de hierro con anillo de ocho gajos, collares, adorno y dientes, en el color de su puerta.
-- `item` es el vástago (un cilindro a lo largo de X); el resto cuelga de él.
local function decorateKey(item: Part, color: Color3, gold: boolean)
	local scale = if gold then 1.25 else 1
	local light = color:Lerp(Color3.new(1, 1, 1), 0.3)
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	item.Shape = Enum.PartType.Cylinder
	item.Size = Vector3.new(1.0, 0.13, 0.13) * scale
	item.Material = Enum.Material.Metal
	item.Reflectance = 0.2
	item.Color = color
	-- Cada llave queda tirada con su propio ángulo.
	local base = CFrame.new(item.Position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	item.CFrame = base

	local function add(
		size: Vector3,
		offset: CFrame,
		tint: Color3,
		shape: Enum.PartType?,
		material: Enum.Material?
	)
		local piece = Instance.new("Part")
		piece.Name = "PiezaLlave"
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Shape = shape or Enum.PartType.Block
		piece.Size = size * scale
		piece.Color = tint
		piece.Material = material or Enum.Material.Metal
		piece.Reflectance = 0.2
		piece.CFrame = base * CFrame.new(offset.Position * scale) * offset.Rotation
		piece.Parent = item
	end

	-- Anillo: doce tramos en círculo en el extremo del mango, con un aro interior más oscuro.
	local radius = 0.26
	local ringX = -0.5 - radius + 0.04
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		add(
			Vector3.new(0.09, 0.12, 0.16),
			CFrame.new(ringX, 0, 0) * CFrame.Angles(0, -angle, 0) * CFrame.new(radius, 0, 0),
			light
		)
	end
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		add(
			Vector3.new(0.04, 0.09, 0.1),
			CFrame.new(ringX, 0, 0) * CFrame.Angles(0, -angle, 0) * CFrame.new(radius - 0.075, 0, 0),
			dark
		)
	end
	-- Collares y adorno a lo largo del mango.
	for _, x in { -0.42, -0.31 } do
		add(Vector3.new(0.07, 0.2, 0.2), CFrame.new(x, 0, 0), light, Enum.PartType.Cylinder)
	end
	add(Vector3.new(0.18, 0.17, 0.17), CFrame.new(-0.12, 0, 0), light, Enum.PartType.Cylinder)
	add(Vector3.new(0.06, 0.15, 0.15), CFrame.new(0.06, 0, 0), dark, Enum.PartType.Cylinder)
	-- Paleta con tres dientes de distinto largo y la punta redondeada.
	add(Vector3.new(0.3, 0.09, 0.07), CFrame.new(0.34, 0, 0.04), color)
	for tooth, spec in { { 0.26, 0.24 }, { 0.38, 0.14 }, { 0.5, 0.26 } } do
		add(Vector3.new(0.09, 0.09, spec[2]), CFrame.new(spec[1], 0, 0.04 + spec[2] / 2), dark)
		if tooth == 3 then
			add(
				Vector3.new(0.1, 0.1, 0.1),
				CFrame.new(spec[1] + 0.02, 0, 0),
				dark,
				Enum.PartType.Ball
			)
		end
	end

	if gold then
		local glow = Instance.new("PointLight")
		glow.Color = color
		glow.Range = 7
		glow.Brightness = 0.8
		glow.Shadows = false
		glow.Parent = item
	end
end

-- La escalera de mano no queda tirada: se apoya parada contra la pared más cercana (o inclinada si no
-- hay ninguna a mano). `item` pasa a ser el contorno invisible donde se la agarra.
local function leanLadder(item: Part, position: Vector3)
	local height = 6
	local lean = math.rad(16)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder :: Instance }
	local origin = position + Vector3.new(0, 3, 0)
	local nearest = 14
	local wallPoint: Vector3? = nil
	local wallNormal = Vector3.zAxis
	for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local hit = workspace:Raycast(origin, direction * 14, params)
		if hit and hit.Distance < nearest then
			nearest = hit.Distance
			wallPoint = hit.Position
			wallNormal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
		end
	end
	local base = position
	if wallPoint then
		base = Vector3.new(wallPoint.X, position.Y, wallPoint.Z)
			+ wallNormal * (math.sin(lean) * height + 0.3)
	else
		wallNormal = Vector3.xAxis
	end
	-- El frente mira hacia la pared: su -Z, y arriba se inclina hacia ahí.
	local frame = CFrame.lookAt(base, base - wallNormal)
	local ladder = frame
		* CFrame.new(0, height / 2 * math.cos(lean), -height / 2 * math.sin(lean))
		* CFrame.Angles(-lean, 0, 0)
	item.Transparency = 1
	item.Size = Vector3.new(2.4, height, 1.2)
	item.CFrame = ladder
	local function wood(size: Vector3, offset: CFrame)
		local piece = Instance.new("Part")
		piece.Name = "PiezaEscalera"
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.Size = size
		piece.Color = Color3.fromRGB(112, 78, 46)
		piece.Material = Enum.Material.WoodPlanks
		piece.CFrame = ladder * offset
		piece.Parent = item
	end
	for _, x in { -0.9, 0.9 } do
		wood(Vector3.new(0.3, height, 0.3), CFrame.new(x, 0, 0))
	end
	for y = -height / 2 + 0.7, height / 2 - 0.4, 0.95 do
		wood(Vector3.new(1.8, 0.2, 0.25), CFrame.new(0, y, 0))
	end
end
local function spawnItem(
	id: string,
	kind: string,
	position: Vector3,
	onPicked: (Player) -> boolean,
	keyColor: { name: string, rgb: { number } }?,
	label: string?
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
	if kind == "key" or kind == "goldKey" then
		decorateKey(item, item.Color, kind == "goldKey")
	elseif kind == "ladder" then
		leanLadder(item, position)
	elseif kind == "gem" then
		-- Un cubo girado sobre la punta, con brillo propio, para que se vea como una gema.
		item.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(45), math.rad(45), 0)
		item.Reflectance = 0.3
		local glow = Instance.new("PointLight")
		glow.Color = item.Color
		glow.Range = 7
		glow.Brightness = 0.7
		glow.Shadows = false
		glow.Parent = item
	elseif kind == "taser" or kind == "flashlight" then
		-- Un resplandor suave, para que se encuentren en la oscuridad.
		local beacon = Instance.new("PointLight")
		beacon.Color = Color3.fromRGB(255, 236, 190)
		beacon.Range = 10
		beacon.Brightness = 0.9
		beacon.Shadows = false
		beacon.Parent = item
		item.CFrame = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
		ItemModels.apply(
			item,
			if kind == "taser" then ItemModels.taser() else ItemModels.flashlight()
		)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Agarrar"
	prompt.ObjectText = if label
		then label
		elseif keyColor then `Llave {keyColor.name}`
		else itemLook.name
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
		notify(player, "Encontraste la linterna. Tecla 2 para sacarla, clic derecho para prenderla")
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
		notify(player, "Agarraste un taser. Tecla 1 para sacarlo, clic para disparar")
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
		notify(player, "Llave dorada del lobo: abrí la puerta del túnel")
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

	local function roll(n: number): number
		return random:NextInteger(1, n)
	end
	local function hasSpot(room: string): boolean
		return free[room] ~= nil and #free[room] > 0
	end

	-- Cada llave en una pieza a la que ya se llega con las anteriores; incluye las salas del
	-- ala oeste y los huecos de las librerías del hall.
	-- Con las puertas sorteadas de esta partida; si un reparto se traba, prueba otro.
	local needs = Mansion.currentNeeds()
	local keyRooms: { string }? = nil
	for _ = 1, 60 do
		keyRooms = Placement.keyRooms(needs, Config.DoorKeys, Config.KeyCount, roll, hasSpot)
		if keyRooms then
			break
		end
	end
	assert(keyRooms, "no se pudieron repartir las llaves")
	for n = 1, Config.KeyCount do
		spawnItem(`key{n}`, "key", takeSpot(free[keyRooms[n]], random), function(player)
			handlers.onKey(player, n)
			return true
		end, Config.KeyColors[n])
	end

	-- Un pergamino en cada habitación con código, sobre su pedestal.
	for n = 1, Config.BookCount do
		local id = `book{n}`
		spawnItem(id, "scroll", refs.vaults[n].scrollSpot, function(player)
			handlers.onBook(player, id)
			return true
		end)
	end
	local function randomSpot(rooms: { string }): Vector3
		-- A veces cae en un hueco de las librerías del hall.
		local shelves = free.hall
		if shelves and #shelves > 0 and random:NextNumber() < 0.3 then
			return takeSpot(shelves, random)
		end
		while true do
			local spots = free[rooms[random:NextInteger(1, #rooms)]]
			if #spots > 0 then
				return takeSpot(spots, random)
			end
		end
	end
	local allRooms = {
		"room1",
		"room2",
		"room3",
		"room4",
		"room5",
		"room6",
		"room7",
		"room8",
		"room9",
		"room10",
		"room11",
		"room12",
		"gameRoom",
		"bar",
	}

	-- La nota con el código de cada habitación, escondida en cualquier pieza (las llaves no dependen
	-- de las habitaciones, así que siempre se llega a todas).
	for n = 1, Config.BookCount do
		spawnItem(`code{n}`, "note", randomSpot(allRooms), function(player)
			handlers.onCode(player, n)
			return true
		end, nil, `Nota: código de la Caja fuerte {n}`)
	end
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

	-- Gemas escondidas: de una a cinco por partida, para gastar en la tienda del lobby.
	for n = 1, random:NextInteger(Config.GemsMin, Config.GemsMax) do
		spawnItem(`gem{n}`, "gem", randomSpot(allRooms), function(player)
			Profile.addGems(player, 1)
			notify(player, `+1 gema (tenés {Profile.gems(player)})`)
			return true
		end)
	end

	spawnFlashlight(refs.flashlightSpot, 1)
	-- La escalera de mano siempre está en el sótano.
	spawnLadder(randomSpot({ "room5", "room6" }))
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
	taser.Position = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2 + 0.3, 0)
	taser.Parent = pedestal
	ItemModels.apply(taser, ItemModels.taser())
	local beacon = Instance.new("PointLight")
	beacon.Color = Color3.fromRGB(255, 236, 190)
	beacon.Range = 12
	beacon.Brightness = 1
	beacon.Shadows = false
	beacon.Parent = taser

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
		notify(player, "Agarraste un taser. Tecla 1 para sacarlo, clic para disparar")
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
