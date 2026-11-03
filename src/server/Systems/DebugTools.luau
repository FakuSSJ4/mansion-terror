--!strict
-- Atajos de QA. Solo existen en Studio.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Systems = script.Parent
local Cinema = require(Systems:WaitForChild("Cinema"))
local Items = require(Systems:WaitForChild("Items"))
local LobbyMap = require(Systems:WaitForChild("LobbyMap"))
local MapDef =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("MapDef"))
local Profile = require(Systems:WaitForChild("Profile"))
local Killer = require(Systems:WaitForChild("Killer"))
local Mansion = require(Systems:WaitForChild("Mansion"))
local Round = require(Systems:WaitForChild("Round"))
local Vitality = require(Systems:WaitForChild("Vitality"))
local Weather = require(Systems:WaitForChild("Weather"))

-- Paradas de la tecla T: alce, rinoceronte, puma, teclado y umbral del primer piso.
local TOUR_STOPS: { [any]: Vector3 } = {
	tour1 = Vector3.new(94, 10, 25),
	tour2 = Vector3.new(146, 10, 25),
	tour3 = Vector3.new(68, 24, 80),
	tour4 = Vector3.new(173.5, 8, 93.5),
	tour5 = Vector3.new(16, 26, 0),
	tour6 = Vector3.new(88, 27, 8),
	tour7 = Vector3.new(200, -13, 80),
	tour8 = Vector3.new(222, -14, 87),
	tour9 = Vector3.new(-136, 9, -8),
	tour10 = Vector3.new(-136, 29, 8),
	tour11 = Vector3.new(-70, 8, 0),
	tour12 = Vector3.new(-32, 8, -80),
	tour13 = Vector3.new(-32, 8, -130),
	tour14 = Vector3.new(-32, 5, -65),
}

local DebugTools = {}

local function runSoundCheck()
	task.spawn(function()
		local candidates = {
			DoorCreak = { 9120839010, 9120839174 },
			MetalDoor = { 9116604303 },
			Drawer = { 9113657277, 9114061142 },
			Growl = { 9113980319, 2184044761 },
			PigGrunt = { 9117344600, 9117352464 },
			Fountain = { 136569006780446, 92671411084211 },
			Wind = { 9113286969, 9113286782 },
			Drip = { 9120607899, 9112852458 },
			GameOver = { 9040342348, 9040342360 },
			Win = { 138132318456925, 9038470580 },
			Breathing = { 9113586144 },
		}
		for name, ids in candidates do
			for _, id in ids do
				local sound = Instance.new("Sound")
				sound.SoundId = `rbxassetid://{id}`
				sound.Parent = workspace
				pcall(function()
					ContentProvider:PreloadAsync({ sound })
				end)
				print(
					`[Audio] {name} {id}: cargó={sound.IsLoaded} duración={math.floor(
						sound.TimeLength * 10
					) / 10}`
				)
				sound:Destroy()
			end
		end
		print("[Audio] fin")
	end)
end

local sealView = 0
local cureView = 0
local lobbyView = 0

function DebugTools.start(refs: Mansion.MansionRefs)
	if not RunService:IsStudio() then
		return
	end
	-- Telemetría solo para QA: cada 3 segundos, qué hace cada jugador en partida y dónde están los
	-- asesinos, para evaluar el ritmo de una partida.
	task.spawn(function()
		local startedAt = os.clock()
		while true do
			task.wait(3)
			for _, player in Players:GetPlayers() do
				local root = Vitality.rootOf(player)
				if root and not player:GetAttribute("InLobby") then
					local humanoid = player.Character
						and player.Character:FindFirstChildOfClass("Humanoid")
					print(
						`[Telemetría] t={math.floor(os.clock() - startedAt)} sala={Vitality.getRoom(
							player
						)} pos=({math.floor(root.Position.X)},{math.floor(root.Position.Z)}) vida={humanoid and math.floor(
							humanoid.Health
						)} llaves={workspace:GetAttribute("Keys")} pergaminos={workspace:GetAttribute(
							"Books"
						)} agachado={player:GetAttribute("Crouching")} peligro={player:GetAttribute(
							"Danger"
						)} | {Killer.debugStatus()}`
					)
				end
			end
		end
	end)

	Remotes.get("Debug").OnServerEvent:Connect(function(player, command)
		if command == "devmode" then
			local on = not player:GetAttribute("GodMode")
			player:SetAttribute("GodMode", on)
			Vitality.applyDevCollision(player)
			if on then
				for n = 1, Config.KeyCount do
					Round.addKey(player, n)
				end
				for n = 1, Config.BookCount do
					Round.addBook(player, `book{n}`)
				end
			end
			Remotes.get("Notify"):FireClient(
				player,
				if on
					then "Modo desarrollador: W A S D vuela, Espacio sube, Ctrl baja, doble Espacio deja de volar"
					else "Modo desarrollador apagado"
			)
		elseif command == "cure" then
			-- Va a ver, de a una por vez, la venda, el botiquín, la pila y las cajas fuertes 1 y 4.
			cureView = cureView % 5 + 1
			local name = ({ "bandage1", "medkit1", "battery1", "@vault1", "@vault4" })[cureView]
			local item = workspace:FindFirstChild("Objetos")
				and workspace.Objetos:FindFirstChild(name)
			local root = Vitality.rootOf(player)
			local vault = refs.vaults[tonumber(string.match(name, "^@vault(%d)$")) or 0]
			if vault and root then
				local door = vault.door.leaves[1].closed
				local floorY = refs.rooms[vault.room].center.Y
				local front = door * CFrame.new(0, 0, -12)
				local at = Vector3.new(front.X, floorY + 4, front.Z)
				root.CFrame = CFrame.lookAt(at, Vector3.new(door.X, at.Y, door.Z))
				player:SetAttribute("QAAim", (Vector3.new(door.X, at.Y, door.Z) - at).Unit)
				-- Para ver lo que guarda, la deja abierta (el código se probó aparte).
				Mansion.setDoorUnlocked(vault.door, true)
				print(`[QA] viendo {name}`)
			elseif item and item:IsA("BasePart") and root then
				local at = item.Position + Vector3.new(0, 2.5, 0) + Vector3.new(-3, 0, 3)
				root.CFrame = CFrame.lookAt(at, item.Position)
				player:SetAttribute("QAAim", (item.Position - at).Unit)
				print(`[QA] viendo {name}`)
			end
		elseif command == "cinema" then
			-- Vuelve a sentar al asesino y te deja recién entrado al living: arranca la escena.
			Cinema.debugReset()
			local root = Vitality.rootOf(player)
			if root then
				local center = refs.rooms.room1.center
				local at = center + Vector3.new(-refs.rooms.room1.size.X / 2 + 3, 4, 0)
				root.CFrame = CFrame.lookAt(at, at + Vector3.xAxis)
			end
		elseif command == "keys" then
			for n = 1, Config.KeyCount do
				Round.addKey(player, n)
			end
		elseif command == "books" then
			for n = 1, Config.BookCount do
				Round.addBook(player, `book{n}`)
			end
		elseif command == "next" then
			local root = Vitality.rootOf(player)
			if not root then
				return
			end
			local current = Vitality.getRoom(player)
			local n = current and tonumber(string.match(current, "room(%d+)")) or 0
			local target = if current == "attic"
				then "hall"
				elseif n >= 12 then "attic"
				else `room{n + 1}`
			root.CFrame = CFrame.new(refs.rooms[target].center + Vector3.new(4, 4, 4))
		elseif command == "stairs" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(10, 4, -56)
			end
		elseif command == "library" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(-32, 4, 12)
			end
		elseif command == "pedestal" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(refs.taserPedestal.Position + Vector3.new(0, 2.5, -4))
			end
		elseif TOUR_STOPS[command] then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(TOUR_STOPS[command])
			end
		elseif command == "escape" then
			-- Abre la puerta del túnel, se para pasando el umbral y arranca la fuga.
			local root = Vitality.rootOf(player)
			if root then
				local tunnel = refs.tunnel
				Mansion.setDoorUnlocked(refs.doors.exit, true)
				root.CFrame = CFrame.lookAt(
					tunnel.door + Vector3.new(4, 4, 0),
					tunnel.door + Vector3.new(30, 4, 0)
				)
				Round.beginEscape(player)
			end
		elseif
			command == "nextAnimal"
			or command == "nextHead"
			or command == "viewArcade"
			or command == "viewBar"
		then
			local root = Vitality.rootOf(player)
			if not root then
				return
			end
			local name = ""
			local spot = Vector3.zero
			if command == "nextAnimal" then
				name = Mansion.debugCycleAnimal()
				spot = refs.rooms.room11.center + Vector3.new(-10, 4, 0)
			elseif command == "nextHead" then
				name = Mansion.debugCycleHead()
				spot = refs.rooms.room1.center + Vector3.new(7, 9, 3)
			elseif command == "viewBar" then
				name = "barra"
				spot = refs.rooms.bar.center + Vector3.new(-6, 6.5, 0)
			else
				name = "arcades"
				spot = refs.rooms.gameRoom.center + Vector3.new(-8, 5, -6)
			end
			root.CFrame = CFrame.new(spot)
			Remotes.get("Notify"):FireClient(player, name)
		elseif command == "viewSeal" then
			local root = Vitality.rootOf(player)
			local views = Mansion.debugSealedViews()
			if root and #views > 0 then
				sealView = sealView % #views + 1
				local view = views[sealView]
				root.CFrame = CFrame.new(view.position)
				player:SetAttribute("QAAim", view.look)
				Remotes.get("Notify"):FireClient(player, `tapiado {sealView}/{#views}`)
			end
		elseif command == "lobbyTour" then
			-- Recorre el lobby: de cara a los círculos, la chimenea, la tienda, un círculo de cerca.
			local root = Vitality.rootOf(player)
			if root then
				local views = {
					{ Vector3.new(0, 7, 27), Vector3.new(0, -0.12, -1) },
					{ Vector3.new(-8, 7, 12), Vector3.new(-1, -0.05, -0.1) },
					{ Vector3.new(18, 7, 4), Vector3.new(1, -0.05, 0.1) },
					{ Vector3.new(-18, 6, -2), Vector3.new(0.2, -0.12, -1) },
					{ Vector3.new(0, 9, -4), Vector3.new(0, -0.05, 1) },
				}
				lobbyView = lobbyView % #views + 1
				local view = views[lobbyView]
				root.CFrame = CFrame.new(LobbyMap.Origin + view[1])
				player:SetAttribute("QAAim", view[2])
			end
		elseif command == "coneTest" then
			-- Prueba del cono de visión: un obstáculo de 4 de alto en el centro de la pieza 1, el
			-- asesino a un lado mirándolo y el jugador del otro, parado, agachado y parado otra vez.
			task.spawn(function()
				local room = refs.rooms.room1.center
				local block = Instance.new("Part")
				block.Name = "PruebaCono"
				block.Anchored = true
				block.Size = Vector3.new(8, 4, 1)
				block.Position = room + Vector3.new(0, 2.1, 0)
				block.Parent = workspace
				for _, crouching in { false, true, false } do
					local root = Vitality.rootOf(player)
					if not root then
						break
					end
					Vitality.setCrouching(player, crouching)
					root.CFrame = CFrame.new(room + Vector3.new(6, 4, 0))
					task.wait(0.7)
					Killer.debugPlace(1, room + Vector3.new(-16, 3.9, 0), room)
					task.wait(0.15)
					local sees = Killer.debugSense(1)
					local now = Vitality.rootOf(player)
					print(
						`[Cono] agachado={crouching} lo ve={sees ~= nil} altura del jugador={now and math.floor(
							now.Position.Y * 10
						) / 10}`
					)
				end
				block:Destroy()
			end)
		elseif command == "coneChase" then
			-- El asesino te ve parado y te persigue; te agachás detrás del obstáculo y se ve qué hace.
			task.spawn(function()
				local room = refs.rooms.room1.center
				local block = Instance.new("Part")
				block.Name = "PruebaCono"
				block.Anchored = true
				block.Size = Vector3.new(8, 4, 1)
				block.Position = room + Vector3.new(0, 2.1, 0)
				block.Parent = workspace
				local root = Vitality.rootOf(player)
				if root then
					Vitality.setCrouching(player, false)
					root.CFrame = CFrame.new(room + Vector3.new(6, 4, 0))
					Killer.debugPlace(1, room + Vector3.new(-16, 3.9, 0), room)
				end
				for second = 1, 16 do
					task.wait(1)
					if second == 2 then
						Vitality.setCrouching(player, true)
					end
					local line = string.sub(Killer.debugStatus(), 1, 110)
					print(`[Persecución] t={second} agachado={second >= 2} {line}`)
				end
				block:Destroy()
			end)
		elseif command == "aerial" then
			-- Vista desde arriba de toda la mansión, para revisar cómo encajan las piezas.
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(120, 420, 40)
				player:SetAttribute("QAAim", Vector3.new(0, -1, 0.0001))
			end
		elseif command == "linkTest" then
			-- Comprueba que cada pasillo se cruza de una pieza a la otra: un rayo a la altura del pecho
			-- de centro a centro solo debería chocar con puertas, tablones o barreras.
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local ignore: { Instance } = {}
			for _, model in workspace:GetChildren() do
				if model:IsA("Model") and model:FindFirstChildWhichIsA("Humanoid") then
					table.insert(ignore, model)
				end
			end
			local items = workspace:FindFirstChild("Objetos")
			if items then
				table.insert(ignore, items)
			end
			params.FilterDescendantsInstances = ignore
			for _, link in MapDef.corridors() do
				local a, b = refs.rooms[link[1]], refs.rooms[link[2]]
				local from = Vector3.new(a.center.X, a.center.Y + 4, a.center.Z)
				local to = Vector3.new(b.center.X, b.center.Y + 4, b.center.Z)
				local direction = to - from
				local result = workspace:Raycast(from, direction, params)
				local hit = if result then result.Instance.Name else "libre"
				print(
					`[Pasillo] {link[1]} - {link[2]}: largo {math.floor(direction.Magnitude)} primer choque: {hit}`
				)
			end
		elseif command == "soundCheck" then
			-- Comprueba qué audios candidatos cargan de verdad en un juego (no todos los del catálogo).
			runSoundCheck()
		elseif command == "buy" then
			-- Compra las dos ventajas y muestra lo que cambia en el jugador.
			local armor = Profile.buy(player, "armor")
			local stamina = Profile.buy(player, "stamina")
			print(
				`[QA] armadura={armor or "ok"} resistencia={stamina or "ok"} reducción={player:GetAttribute(
					"DamageReduction"
				)} multiplicador de estamina={player:GetAttribute("StaminaMult")}`
			)
		elseif command == "gems" then
			Profile.addGems(player, 10)
		elseif command == "shop" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(LobbyMap.Origin + Vector3.new(27, 4, -2))
				player:SetAttribute("QAAim", Vector3.new(1, -0.1, 0))
			end
		elseif command == "play" then
			-- Empieza una partida solo con vos, sin pasar por los círculos del lobby.
			Round.startMatch({ player }, "normal")
		elseif command == "wolfRoom" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(refs.altar.position + Vector3.new(-16, 4, 0))
				player:SetAttribute("QAAim", Vector3.new(1, -0.05, 0))
			end
		elseif command == "vault" then
			local root = Vitality.rootOf(player)
			local vault = refs.vaults[1]
			if root and vault then
				local front = vault.door.leaves[1].closed * CFrame.new(0, -1.5, -11)
				root.CFrame = CFrame.lookAt(front.Position, vault.door.position)
				player:SetAttribute("QAAim", (vault.door.position - front.Position).Unit)
				print(
					`[QA] códigos: {Round.debugCode(1)} {Round.debugCode(2)} {Round.debugCode(3)} {Round.debugCode(
						4
					)}`
				)
				Remotes.get("Keypad"):FireClient(player, 1)
			end
		elseif command == "diffMenu" then
			Remotes.get("SetDifficulty"):FireClient(player, 1, "normal", false, 1)
		elseif command == "lobby" then
			local root = Vitality.rootOf(player)
			if root then
				root.CFrame = CFrame.new(LobbyMap.Origin + Vector3.new(-30, 4, -24))
			end
		elseif command == "gear" then
			Items.debugGive(player)
		elseif command == "status" then
			print(`[QA] {Killer.debugStatus()} jugador={Vitality.getRoom(player)}`)
		elseif command == "summon" then
			local room = Vitality.getRoom(player)
			if room then
				Killer.debugTeleport(1, refs.rooms[room].center + Vector3.new(10, 0, 10))
			end
		elseif command == "summon2" then
			local room = Vitality.getRoom(player)
			if room then
				Killer.debugTeleport(2, refs.rooms[room].center + Vector3.new(10, 0, 10))
			end
		elseif command == "summon3" then
			local room = Vitality.getRoom(player)
			if room then
				Killer.debugTeleport(3, refs.rooms[room].center + Vector3.new(10, 0, 10))
			end
		elseif command == "lightning" then
			Weather.strike()
		elseif command == "damage" then
			Vitality.damage(player, Config.Killers.main.damage)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			print(`[QA] vida tras el golpe: {humanoid and humanoid.Health}`)
		end
	end)
end

return DebugTools
