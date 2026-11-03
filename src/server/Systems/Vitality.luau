--!strict
-- Vida, energía, cargas de taser y pieza actual de cada jugador.
-- El estado va en atributos del jugador, que replican solos al cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Vitals = require(Shared:WaitForChild("Rules"):WaitForChild("Vitals"))

local Blood = require(script.Parent:WaitForChild("Blood"))
local Mansion = require(script.Parent:WaitForChild("Mansion"))

local Vitality = {}

local lobbySpawn: SpawnLocation? = nil

-- Dónde aparecen los jugadores al entrar al servidor (la pieza se arma antes de Vitality.start).
function Vitality.setLobbySpawn(spawn: SpawnLocation)
	lobbySpawn = spawn
end

local diedEvent = Instance.new("BindableEvent")
Vitality.Died = diedEvent.Event
local killedEvent = Instance.new("BindableEvent")
Vitality.Killed = killedEvent.Event

type RunState = { wants: boolean, exhausted: boolean, stamina: number }
local runStates: { [Player]: RunState } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

function Vitality.rootOf(player: Player): BasePart?
	local character = player.Character
	if not character or not humanoidOf(player) then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Si el jugador está en partida: ni en el lobby ni leyendo el tutorial.
function Vitality.isPlaying(player: Player): boolean
	return not player:GetAttribute("InTutorial") and not player:GetAttribute("InLobby")
end

-- Cuánto aguanta corriendo: la ventaja de estamina de la tienda lo multiplica.
function Vitality.maxStamina(player: Player): number
	return Config.StaminaSeconds * ((player:GetAttribute("StaminaMult") :: number?) or 1)
end

function Vitality.anyAlive(): boolean
	for _, player in Players:GetPlayers() do
		if
			humanoidOf(player)
			and not player:GetAttribute("Spectating")
			and not player:GetAttribute("InLobby")
		then
			return true
		end
	end
	return false
end

function Vitality.getRoom(player: Player): string?
	return player:GetAttribute("Room") :: string?
end

function Vitality.canReach(player: Player, position: Vector3): boolean
	local root = Vitality.rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= Config.InteractRange + 4
end

-- `source` es de dónde viene el golpe: la sangre salpica en sentido contrario.
function Vitality.damage(player: Player, amount: number, source: Vector3?)
	local humanoid = humanoidOf(player)
	if humanoid and not player:GetAttribute("GodMode") and Vitality.isPlaying(player) then
		-- La armadura de la tienda baja el daño un porcentaje.
		local reduction = (player:GetAttribute("DamageReduction") :: number?) or 0
		humanoid.Health = Vitals.damage(humanoid.Health, amount * (1 - reduction))
		Remotes.get("Hit"):FireClient(player)
		local root = Vitality.rootOf(player)
			or (player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
		if root and player.Character then
			Blood.splat((root :: BasePart).Position, { player.Character }, source)
		end
		if humanoid.Health <= 0 then
			player:SetAttribute("Spectating", true)
			killedEvent:Fire(player)
		end
	end
end

-- Devuelve false si no hacía falta curar.
function Vitality.heal(player: Player, amount: number): boolean
	local humanoid = humanoidOf(player)
	if not humanoid or not Vitals.canTakePill(humanoid.Health, humanoid.MaxHealth) then
		return false
	end
	humanoid.Health = Vitals.heal(humanoid.Health, amount, humanoid.MaxHealth)
	return true
end

-- El grupo de colisión del modo desarrollador atraviesa las puertas cerradas.
function Vitality.applyDevCollision(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local group = if player:GetAttribute("GodMode") then "DevPlayer" else "Default"
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") then
			item.CollisionGroup = group
		end
	end
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	task.delay(1, Vitality.applyDevCollision, player)
	humanoid.MaxHealth = Config.MaxHealth
	humanoid.Health = Config.MaxHealth
	humanoid.WalkSpeed = Config.WalkSpeed
	-- Nadie salta: el servidor lo fija para todos los personajes.
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	player:SetAttribute("Room", if player:GetAttribute("InLobby") then "lobby" else "hall")
	local state = runStates[player]
	if state then
		state.stamina = Vitality.maxStamina(player)
		state.exhausted = false
	end
	player:SetAttribute("Crouching", false)
	humanoid.Died:Once(function()
		diedEvent:Fire(player)
	end)
end

function Vitality.resetPlayer(player: Player)
	player:SetAttribute("TaserCharges", 0)
	player:SetAttribute("TaserTaken", false)
	player:SetAttribute("HasFlashlight", false)
	player:SetAttribute("FlashlightOn", false)
	player:SetAttribute("HasLadder", false)
	player:SetAttribute("HasGoldKey", false)
	player:SetAttribute("Spectating", false)
	player:SetAttribute("Escaping", false)
	-- LoadCharacter cede el hilo y falla si el jugador ya se fue.
	task.spawn(function()
		if player.Parent then
			player:LoadCharacter()
		end
	end)
end

local function step(dt: number)
	for player, state in runStates do
		local humanoid = humanoidOf(player)
		local root = Vitality.rootOf(player)
		if humanoid and root then
			local velocity = root.AssemblyLinearVelocity
			local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 1
			local crouching = player:GetAttribute("Crouching") == true
			local maxStamina = Vitality.maxStamina(player)
			local running = state.wants
				and moving
				and not crouching
				and not state.exhausted
				and state.stamina > 0
			if running then
				state.stamina = math.max(state.stamina - dt, 0)
				state.exhausted = state.stamina <= 0
			else
				state.stamina = math.min(
					state.stamina + dt * maxStamina / Config.StaminaRecoverySeconds,
					maxStamina
				)
			end
			-- Durante el tutorial no se puede caminar, así estar protegido no da ventaja.
			humanoid.WalkSpeed = if player:GetAttribute("Escaping")
				then Config.EscapeSpeed
				elseif player:GetAttribute("Entering") then Config.EntranceSpeed
				elseif player:GetAttribute("InTutorial") or player:GetAttribute("Watching") then 0
				elseif player:GetAttribute("GodMode") then Config.DevWalkSpeed
				elseif running then Config.RunSpeed
				elseif crouching then Config.CrouchSpeed
				else Config.WalkSpeed
			player:SetAttribute("Running", running)
			player:SetAttribute("Stamina", state.stamina / maxStamina)
			local room = Mansion.roomAt(root.Position)
			if room and room ~= player:GetAttribute("Room") then
				player:SetAttribute("Room", room)
			end
		end
	end
end

-- Agacharse: más bajo (cabe detrás de un sillón), más lento y no corre. Se achica el cuerpo con la
-- escala de altura del Humanoid; si el personaje no la tiene, se baja la cadera.
function Vitality.setCrouching(player: Player, wants: boolean)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	player:SetAttribute("Crouching", wants)
	local info = TweenInfo.new(0.18)
	local height = humanoid:FindFirstChild("BodyHeightScale")
	if height and height:IsA("NumberValue") then
		TweenService:Create(height, info, { Value = if wants then Config.CrouchScale else 1 })
			:Play()
	else
		local base = (humanoid:GetAttribute("BaseHipHeight") :: number?) or humanoid.HipHeight
		humanoid:SetAttribute("BaseHipHeight", base)
		TweenService:Create(humanoid, info, {
			HipHeight = if wants then base * Config.CrouchScale else base,
		}):Play()
	end
end
function Vitality.start()
	Players.CharacterAutoLoads = false

	-- Un script vacío llamado Health anula la regeneración automática.
	local noRegen = Instance.new("Script")
	noRegen.Name = "Health"
	noRegen.Parent = StarterPlayer:WaitForChild("StarterCharacterScripts")

	local function onPlayer(player: Player)
		runStates[player] = { wants = false, exhausted = false, stamina = Config.StaminaSeconds }
		player:SetAttribute("Crouching", false)
		player:SetAttribute("TaserCharges", 0)
		player:SetAttribute("TaserTaken", false)
		player:SetAttribute("Stamina", 1)
		player:SetAttribute("InTutorial", true)
		-- Todos arrancan en el lobby; la partida los lleva a la mansión.
		player:SetAttribute("InLobby", true)
		player.RespawnLocation = lobbySpawn
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
		-- Los personajes se cargan a mano: el que muere no reaparece hasta reiniciar la partida.
		if player.Character then
			setupCharacter(player, player.Character)
		else
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		runStates[player] = nil
	end)

	Remotes.get("TutorialDone").OnServerEvent:Connect(function(player)
		player:SetAttribute("InTutorial", false)
	end)

	local lastCrouch: { [Player]: number } = {}
	Remotes.get("Crouch").OnServerEvent:Connect(function(player, wants)
		local now = os.clock()
		if
			typeof(wants) ~= "boolean"
			or now - (lastCrouch[player] or 0) < 0.15
			or player:GetAttribute("Escaping")
			or player:GetAttribute("Spectating")
		then
			return
		end
		lastCrouch[player] = now
		Vitality.setCrouching(player, wants)
	end)
	Remotes.get("Run").OnServerEvent:Connect(function(player, wants)
		local state = runStates[player]
		if state and typeof(wants) == "boolean" then
			state.wants = wants
			if not wants then
				state.exhausted = false
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			step(elapsed)
			elapsed = 0
		end
	end)
end

return Vitality
