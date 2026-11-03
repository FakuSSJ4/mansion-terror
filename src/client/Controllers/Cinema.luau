--!strict
-- Primer encuentro con el villano: cámara de cine mientras el asesino principal mira su película en el
-- living. El servidor mueve al asesino (Systems/Cinema); acá se ponen los planos: el proyector, el
-- trago de whisky, la mirada hacia los jugadores y cómo se levanta con el hacha. Q saltea la escena.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Cinematic = require(script.Parent.Parent:WaitForChild("Cinematic"))

local Cinema = {}

local player = Players.LocalPlayer
local STEP_NAME = "CinemaEncounter"
local UP = Vector3.yAxis

type Payload = {
	seat: Vector3,
	forward: Vector3,
	stand: Vector3,
	screen: Vector3,
	projector: Vector3,
	tableTop: Vector3,
	watcher: Vector3,
	seconds: number,
	done: boolean?,
}

local running = false
local finish: () -> () = function() end

local function flat(vector: Vector3): Vector3
	local v = Vector3.new(vector.X, 0, vector.Z)
	return if v.Magnitude > 0.01 then v.Unit else Vector3.new(0, 0, -1)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- El asesino principal, para seguirlo con la cámara cuando se levanta.
local function killerPosition(fallback: Vector3): Vector3
	for _, model in CollectionService:GetTagged("Killer") do
		if model:IsA("Model") and model.Name == "Asesino" and model.PrimaryPart then
			return model.PrimaryPart.Position
		end
	end
	return fallback
end

local function run(data: Payload)
	if data.done then
		finish()
		return
	end
	if running then
		return
	end
	running = true

	local timing = Config.Cinema
	local camera = workspace.CurrentCamera
	local startedAt = os.clock()
	local duration = data.seconds
	local random = Random.new()
	local forward = flat(data.forward)
	local right = forward:Cross(UP)
	local head = data.seat + UP * 3.5
	local toWatcher = flat(data.watcher - head)

	local previousMode = player.CameraMode
	local hiddenGuis: { ScreenGui } = {}
	for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			gui.Enabled = false
			table.insert(hiddenGuis, gui)
		end
	end
	local overlay, veil = Cinematic.overlay("CinemaEncounter")
	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.Position = UDim2.new(1, -24, 1, -14)
	hint.Size = UDim2.fromOffset(220, 28)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Garamond
	hint.TextSize = 20
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.TextColor3 = Color3.fromRGB(200, 200, 200)
	hint.Text = "Q para saltear"
	hint.ZIndex = 6
	hint.Parent = overlay
	player.CameraMode = Enum.CameraMode.Classic
	Cinematic.setControls(false)
	camera.CameraType = Enum.CameraType.Scriptable
	player:SetAttribute("Cinematic", true)

	local function frame(t: number): (CFrame, number)
		local position: Vector3
		local target: Vector3
		local fov: number
		if t < timing.drinkAt then
			-- Desde atrás del proyector: el haz, la pantalla y su cabeza recortada contra la película.
			local u = Cinematic.ease(t / timing.drinkAt)
			local from = data.projector - forward * 3 + UP * 0.6 + right * 1.5
			local to = data.projector + forward * 9 - UP * 3.5 + right * 2.5
			position = from:Lerp(to, u)
			target = data.screen:Lerp(head, 0.15)
			fov = 55 - 6 * u
		elseif t < timing.turnAt then
			-- De tres cuartos: el trago largo.
			local u = Cinematic.ease((t - timing.drinkAt) / (timing.turnAt - timing.drinkAt))
			-- Bien de costado y a la altura de la cara, así las piernas quedan fuera de cuadro.
			-- Del lado del muñón: el brazo que sube queda detrás del vaso y no le tapa la cara.
			local from = head + right * 4.2 + forward * 3.6 + UP * 0.7
			local to = head + right * 3.4 + forward * 3 + UP * 0.6
			position = from:Lerp(to, u)
			target = head + forward * 0.8 - UP * 0.2
			fov = 42
		elseif t < timing.standAt then
			-- Primer plano: gira la cabeza y mira a quien entró.
			-- Siempre entre él y el jugador, aunque se haya entrado pegado al sillón.
			local u = Cinematic.ease((t - timing.turnAt) / (timing.standAt - timing.turnAt))
			local room = math.min(6.5, flatDistance(data.watcher, head) * 0.6)
			local from = head + toWatcher * room + UP * 0.2
			local to = head + toWatcher * math.max(room - 1.9, 2.5) + UP * 0.1
			position = from:Lerp(to, u)
			target = head
			fov = 38
		else
			-- Desde los jugadores: se levanta, alza el hacha y ruge.
			local u = Cinematic.ease((t - timing.standAt) / (duration - timing.standAt))
			local killer = killerPosition(data.stand)
			-- Por encima del hombro del jugador, corrido a un costado para que no tape al asesino.
			local away = flat(data.watcher - killer)
			local shoulder = away:Cross(UP)
			position = data.watcher + away * (3.5 - u) + shoulder * 2.4 + UP * (3 - 0.6 * u)
			target = killer + UP * (1 + 1.2 * u)
			fov = 62 - 10 * u
		end
		local since = t - timing.roarAt
		local shake = if since > 0 then 1.2 * math.exp(-since * 3) else 0
		local offset = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1)
		) * shake * 0.25
		return CFrame.lookAt(position + offset, target), fov
	end

	local skipConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Q then
			Remotes.get("CinemaSkip"):FireServer()
		end
	end)

	finish = function()
		if not running then
			return
		end
		running = false
		skipConnection:Disconnect()
		player:SetAttribute("Cinematic", false)
		RunService:UnbindFromRenderStep(STEP_NAME)
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		player.CameraMode = previousMode
		Cinematic.setControls(true)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		-- Al volver el control, de cara al asesino: ya viene.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local killer = killerPosition(data.stand)
			root.CFrame =
				CFrame.lookAt(root.Position, Vector3.new(killer.X, root.Position.Y, killer.Z))
		end
		if humanoid then
			camera.CameraSubject = humanoid
		end
		for _, gui in hiddenGuis do
			gui.Enabled = true
		end
		TweenService:Create(veil, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.delay(0.5, function()
			overlay:Destroy()
		end)
	end

	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 10, function()
		local t = os.clock() - startedAt
		-- Por si el aviso del servidor no llega: un margen y se termina igual.
		if t >= duration + 1.5 then
			finish()
			return
		end
		-- El cuerpo propio solo se ve en el último plano (desde atrás del jugador); antes taparía al
		-- asesino si se entró muy cerca del sillón.
		local character = player.Character
		if character then
			local hidden = if t < timing.standAt then 1 else 0
			for _, item in character:GetDescendants() do
				if item:IsA("BasePart") or item:IsA("Decal") then
					item.LocalTransparencyModifier = hidden
				end
			end
		end
		local cframe, fov = frame(math.min(t, duration))
		camera.CFrame = cframe
		camera.FieldOfView = fov
		-- Entra en fundido desde el negro; cada cambio de plano es un corte seco.
		veil.BackgroundTransparency = Cinematic.ease(t / 0.7)
	end)
end

function Cinema.start()
	Remotes.get("Cinema").OnClientEvent:Connect(run)
end

return Cinema
