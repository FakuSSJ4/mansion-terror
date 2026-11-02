--!strict
-- Entrada a la mansión: cámara de cine mientras el equipo cruza la puerta principal desde el patio y
-- se cierra de un portazo detrás. El servidor abre y cierra la puerta (Systems/Entrance); acá cada
-- jugador camina solo hasta su lugar y se ve la escena.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Cinematic = require(script.Parent.Parent:WaitForChild("Cinematic"))

local Entrance = {}

local player = Players.LocalPlayer
local STEP_NAME = "EntranceCinematic"
local UP = Vector3.yAxis
-- Hacia el patio, saliendo de la casa.
local OUT = Vector3.new(0, 0, -1)
-- Cambio de plano: del patio a adentro del hall.
local CUT = 3.0
-- Segundos hasta que el jugador empieza a caminar (la puerta ya se está abriendo).
local WALK_FROM = 0.7

type Payload = {
	door: Vector3,
	target: Vector3,
	seconds: number,
}

local running = false

local function run(data: Payload)
	if running then
		return
	end
	running = true

	local camera = workspace.CurrentCamera
	local startedAt = os.clock()
	local duration = data.seconds
	local slamAt = Config.EntranceSlamAt
	local door = data.door
	local random = Random.new()

	local previousMode = player.CameraMode
	local hiddenGuis: { ScreenGui } = {}
	for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			gui.Enabled = false
			table.insert(hiddenGuis, gui)
		end
	end
	local overlay, veil = Cinematic.overlay("EntranceCinematic")
	player.CameraMode = Enum.CameraMode.Classic
	Cinematic.setControls(false)
	camera.CameraType = Enum.CameraType.Scriptable
	player:SetAttribute("Cinematic", true)

	-- El portazo: un golpe seco y, apenas después, el eco grave que retumba por toda la casa.
	Cinematic.playLater(slamAt + 0.2, Sounds.DoorSlam, 3.5)
	Cinematic.playLater(slamAt + 0.28, Sounds.Thunder, 0.8)

	local function who(): Vector3
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root.Position
		end
		return data.target
	end

	local function walk(t: number)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") then
			return
		end
		-- La cámara en primera persona apaga el giro automático: sin esto camina de espaldas. El
		-- personaje mira siempre hacia donde va (primero hacia la puerta, después hacia adentro).
		humanoid.AutoRotate = false
		local flat =
			Vector3.new(data.target.X - root.Position.X, 0, data.target.Z - root.Position.Z)
		if flat.Magnitude > 1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
		if t >= WALK_FROM then
			humanoid:MoveTo(data.target)
		end
	end

	local function shakeAt(t: number): number
		local since = t - (slamAt + 0.2)
		if since < 0 then
			return 0
		end
		return 1.4 * math.exp(-since * 4)
	end

	local function frame(t: number): (CFrame, number)
		local position: Vector3
		local target: Vector3
		local fov: number
		local me = who()
		if t < CUT then
			-- Desde el patio, bajo y por detrás del jugador: se ve cómo la puerta se abre sola.
			local u = Cinematic.ease(t / CUT)
			position = Vector3.new(me.X + 4, me.Y + 1.4 + u * 1.2, me.Z - 7 + u * 2)
			target = door + UP * 6 + Vector3.new(0, 0, 2)
			fov = 64 - 8 * u
		else
			-- Adentro del hall, de frente a la entrada: entran los jugadores y la puerta se les
			-- cierra a la espalda.
			local u = Cinematic.ease((t - CUT) / (duration - CUT))
			position = door - OUT * 24 + Vector3.new(-5 + u * 2, 4.5, 0)
			target = (door + UP * 6):Lerp(me + UP * 2, 0.15)
			fov = 62 - 6 * u
		end
		local slam = slamAt + 0.2
		if t >= slam and t < slam + 0.6 then
			fov -= 9 * math.exp(-(t - slam) * 8)
		end
		local amount = shakeAt(t)
		local offset = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1)
		) * amount * 0.4
		local cframe = CFrame.lookAt(position + offset, target)
			* CFrame.Angles(0, 0, random:NextNumber(-1, 1) * amount * 0.025)
		return cframe, fov
	end

	local function finish()
		if not running then
			return
		end
		running = false
		player:SetAttribute("Cinematic", false)
		RunService:UnbindFromRenderStep(STEP_NAME)
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		player.CameraMode = previousMode
		Cinematic.setControls(true)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		-- Al volver el control, mira hacia adentro del hall (nunca hacia la puerta que se cerró).
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.CFrame = CFrame.lookAt(root.Position, root.Position - OUT)
		end
		if humanoid then
			humanoid.AutoRotate = true
			camera.CameraSubject = humanoid
		end
		for _, gui in hiddenGuis do
			gui.Enabled = true
		end
		TweenService:Create(veil, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function()
			overlay:Destroy()
		end)
	end

	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 10, function()
		local t = os.clock() - startedAt
		if t >= duration then
			finish()
			return
		end
		walk(t)
		-- En primera persona el cuerpo propio se oculta; acá tiene que verse.
		local character = player.Character
		if character then
			for _, item in character:GetDescendants() do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = 0
				end
			end
		end
		local cframe, fov = frame(t)
		camera.CFrame = cframe
		camera.FieldOfView = fov
		-- Entra en fundido desde el negro y vuelve al juego con otro fundido corto.
		local fadeIn = 1 - Cinematic.ease(t / 0.8)
		local fadeOut = Cinematic.ease((t - (duration - 0.7)) / 0.6)
		veil.BackgroundTransparency = 1 - math.max(fadeIn, fadeOut)
	end)
end

function Entrance.start()
	Remotes.get("Entrance").OnClientEvent:Connect(run)
end

return Entrance
