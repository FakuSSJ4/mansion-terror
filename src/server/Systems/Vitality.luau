--!strict
-- Vida, energía, cargas de taser y pieza actual de cada jugador.
-- El estado va en atributos del jugador, que replican solos al cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Vitals = require(Shared:WaitForChild("Rules"):WaitForChild("Vitals"))

local Mansion = require(script.Parent:WaitForChild("Mansion"))

local Vitality = {}

local diedEvent = Instance.new("BindableEvent")
Vitality.Died = diedEvent.Event

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

function Vitality.getRoom(player: Player): string?
	return player:GetAttribute("Room") :: string?
end

function Vitality.canReach(player: Player, position: Vector3): boolean
	local root = Vitality.rootOf(player)
	return root ~= nil and (root.Position - position).Magnitude <= Config.InteractRange + 4
end

function Vitality.damage(player: Player, amount: number)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.Health = Vitals.damage(humanoid.Health, amount)
		Remotes.get("Hit"):FireClient(player)
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

function Vitality.addCharges(player: Player, amount: number)
	player:SetAttribute(
		"TaserCharges",
		((player:GetAttribute("TaserCharges") :: number?) or 0) + amount
	)
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = Config.MaxHealth
	humanoid.Health = Config.MaxHealth
	humanoid.WalkSpeed = Config.WalkSpeed
	player:SetAttribute("Room", "hall")
	local state = runStates[player]
	if state then
		state.stamina = Config.StaminaSeconds
		state.exhausted = false
	end
	humanoid.Died:Once(function()
		diedEvent:Fire(player)
	end)
end

function Vitality.resetPlayer(player: Player)
	player:SetAttribute("TaserCharges", 0)
	player:SetAttribute("TaserTaken", false)
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
			local running = state.wants and moving and not state.exhausted and state.stamina > 0
			if running then
				state.stamina = math.max(state.stamina - dt, 0)
				state.exhausted = state.stamina <= 0
			else
				state.stamina = math.min(
					state.stamina + dt * Config.StaminaSeconds / Config.StaminaRecoverySeconds,
					Config.StaminaSeconds
				)
			end
			humanoid.WalkSpeed = if running then Config.RunSpeed else Config.WalkSpeed
			player:SetAttribute("Running", running)
			player:SetAttribute("Stamina", state.stamina / Config.StaminaSeconds)
			local room = Mansion.roomAt(root.Position)
			if room and room ~= player:GetAttribute("Room") then
				player:SetAttribute("Room", room)
			end
		end
	end
end

function Vitality.start()
	-- Un script vacío llamado Health anula la regeneración automática.
	local noRegen = Instance.new("Script")
	noRegen.Name = "Health"
	noRegen.Parent = StarterPlayer:WaitForChild("StarterCharacterScripts")

	local function onPlayer(player: Player)
		runStates[player] = { wants = false, exhausted = false, stamina = Config.StaminaSeconds }
		player:SetAttribute("TaserCharges", 0)
		player:SetAttribute("TaserTaken", false)
		player:SetAttribute("Stamina", 1)
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
		if player.Character then
			setupCharacter(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		runStates[player] = nil
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
