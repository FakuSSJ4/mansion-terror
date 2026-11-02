--!strict
-- Secuencia de fuga: cámara de cine, el jugador que escapa corre solo por el patio y se ve
-- cómo le cierran la puerta al asesino. El servidor mueve al asesino y la puerta (Systems/Escape).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local EscapePath = require(Shared:WaitForChild("Rules"):WaitForChild("EscapePath"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Cinematic = require(script.Parent.Parent:WaitForChild("Cinematic"))

local Escape = {}

local player = Players.LocalPlayer
local STEP_NAME = "EscapeCinematic"
local UP = Vector3.yAxis

-- Tomas: hall visto por la espalda, portazo desde afuera, puerta de cerca y portón.
local SHOT_B = 2.1
local SHOT_C = 4.8
local SHOT_D = 6.8

type Payload = {
	escapee: Player,
	door: Vector3,
	out: Vector3,
	exit: Vector3,
	path: { Vector3 },
	pathLength: number,
}

local running = false

local ease = Cinematic.ease
local playLater = Cinematic.playLater
local setControls = Cinematic.setControls

local function pathPoints(path: { Vector3 }): { EscapePath.Point }
	local points = {}
	for _, point in path do
		table.insert(points, { point.X, point.Z })
	end
	return points
end

-- Temblor de cámara: cada golpe suma un sacudón que se apaga solo.
local function shakeAt(t: number): number
	local total = 0
	local slam = Config.EscapeSlamAt + 0.28
	if t >= slam then
		total += 1.1 * math.exp(-(t - slam) * 5)
	end
	local sinceStrike = t - Config.EscapeFirstStrike
	if sinceStrike >= 0 then
		local into = sinceStrike % Config.EscapeStrikeEvery
		total += 0.6 * math.exp(-into * 9)
	end
	return total
end

local function run(data: Payload)
	if running then
		return
	end
	running = true

	local camera = workspace.CurrentCamera
	local startedAt = os.clock()
	local duration = Config.EscapeSeconds
	local points = pathPoints(data.path)
	local pathLength = data.pathLength
	local out = data.out
	local right = out:Cross(UP)
	local door = data.door
	-- Arriba de la escalera, donde el túnel sale al bosque.
	local gate = data.exit
	local isEscapee = data.escapee == player
	local random = Random.new()

	local previousMode = player.CameraMode
	local hiddenGuis: { ScreenGui } = {}
	for _, gui in player:WaitForChild("PlayerGui"):GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			gui.Enabled = false
			table.insert(hiddenGuis, gui)
		end
	end
	local overlay, veil = Cinematic.overlay("EscapeCinematic")
	player.CameraMode = Enum.CameraMode.Classic
	setControls(false)
	camera.CameraType = Enum.CameraType.Scriptable

	playLater(Config.EscapeSlamAt + 0.25, Sounds.DoorSlam, 3.5)
	for k = 0, 8 do
		playLater(Config.EscapeFirstStrike + k * Config.EscapeStrikeEvery, Sounds.DoorPound, 1.6)
	end

	local flashed = false

	-- En el camino afuera hay niebla cerrada, y un cartel avisa que la historia sigue.
	local fogSaved = {
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
	}
	local fogOn = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.8, 0.16)
	label.Font = Enum.Font.Garamond
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(235, 228, 212)
	label.TextStrokeTransparency = 0.6
	label.Text = "Parte 2 próximamente"
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.ZIndex = 4
	label.Parent = overlay
	player:SetAttribute("Cinematic", true)
	local function escapeePosition(t: number): Vector3
		local root = data.escapee.Character
			and data.escapee.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root.Position
		end
		local at = EscapePath.pointAt(points, t * Config.EscapeRunSpeed)
		return Vector3.new(at[1], 3, at[2])
	end

	-- Corre por el recorrido siguiendo un punto que va un poco más adelante.
	local function drive(t: number)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") then
			return
		end
		local travelled = t * Config.EscapeRunSpeed
		if travelled < pathLength then
			local lead = EscapePath.pointAt(points, travelled + 4)
			humanoid:MoveTo(Vector3.new(lead[1], root.Position.Y, lead[2]))
			return
		end
		-- Llegó al final del camino: se queda quieto, mirando hacia adelante.
		humanoid:MoveTo(root.Position)
	end

	local function frame(t: number): (CFrame, number)
		local target: Vector3
		local position: Vector3
		local fov: number
		local who = escapeePosition(t)
		if t < SHOT_B then
			-- Desde el fondo del hall, a un costado del eje: el jugador se va por la puerta y el
			-- asesino pasa corriendo junto a la cámara hacia la salida.
			local u = ease(t / SHOT_B)
			position = door - out * 30 + right * 5 + UP * 6.5 + out * (4 * u)
			target = (who + UP * 3):Lerp(door + UP * 6, 0.45)
			fov = 66 - 8 * u
		elseif t < SHOT_C then
			-- Plano bajo desde afuera, sobre el eje de la puerta: el asesino viene corriendo desde
			-- la oscuridad y la puerta se le cierra en la cara.
			local u = (t - SHOT_B) / (SHOT_C - SHOT_B)
			position = door + out * (13 - 3 * u) + UP * 2.2
			target = door + UP * 5.5
			fov = 54
		elseif t < SHOT_D then
			-- Más arriba y más cerca: la puerta entera sacudiéndose con cada hachazo.
			local u = ease((t - SHOT_C) / (SHOT_D - SHOT_C))
			position = (door + out * 27 + UP * 9):Lerp(door + out * 19 + UP * 8, u)
			target = door + UP * 7
			fov = 48 - 7 * u
		else
			-- Final: desde atrás, sobre la escalera, mientras el jugador se aleja por el camino hacia
			-- la niebla; la cámara retrocede y sube, y él se pierde a lo lejos.
			local u = ease((t - SHOT_D) / (duration - SHOT_D))
			position = (gate - out * 8 + right * 0.5 + UP * 6.5):Lerp(
				gate - out * 30 + right * 1 + UP * 16,
				u
			)
			target = who + UP * (3 - 1.5 * u)
			fov = 54 + 4 * u
		end
		-- El portazo da un golpe de zoom, y los hachazos lo siguen sacudiendo.
		local slam = Config.EscapeSlamAt + 0.28
		if t >= slam and t < slam + 0.5 then
			fov -= 7 * math.exp(-(t - slam) * 7)
		end
		local weight = if t < SHOT_D then 1 else 0.15
		local amount = shakeAt(t) * weight
		local offset = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1)
		) * amount * 0.35
		local cframe = CFrame.lookAt(position + offset, target)
			* CFrame.Angles(0, 0, random:NextNumber(-1, 1) * amount * 0.02)
		return cframe, fov
	end

	local function finish()
		if not running then
			return
		end
		running = false
		if fogOn then
			Lighting.FogColor = fogSaved.FogColor
			Lighting.FogStart = fogSaved.FogStart
			Lighting.FogEnd = fogSaved.FogEnd
		end
		player:SetAttribute("Cinematic", false)
		RunService:UnbindFromRenderStep(STEP_NAME)
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		player.CameraMode = previousMode
		setControls(true)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = true
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

	local phaseWatch: RBXScriptConnection
	phaseWatch = workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		-- Si la partida se reinició en el medio, corta la secuencia.
		if workspace:GetAttribute("Phase") == "Playing" then
			phaseWatch:Disconnect()
			finish()
		end
	end)

	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 10, function()
		local t = os.clock() - startedAt
		if t >= duration then
			phaseWatch:Disconnect()
			-- Queda negro hasta que el cartel de victoria lo tapa.
			veil.BackgroundTransparency = 0
			finish()
			return
		end
		if isEscapee then
			drive(t)
		end
		-- Un relámpago corto justo antes del portazo, para ver al asesino en el hueco de la puerta.
		if not flashed and t >= Config.EscapeSlamAt - 0.2 then
			flashed = true
			local correction = Instance.new("ColorCorrectionEffect")
			correction.Brightness = 0.22
			correction.Contrast = 0.2
			correction.Parent = Lighting
			local fade = TweenService:Create(
				correction,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad),
				{ Brightness = 0, Contrast = 0 }
			)
			fade:Play()
			fade.Completed:Once(function()
				correction:Destroy()
			end)
		end
		-- En primera persona el cuerpo propio se oculta; acá tiene que verse.
		local character = data.escapee.Character
		if character then
			for _, item in character:GetDescendants() do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = 0
				end
			end
		end
		-- La niebla se cierra al salir del túnel y aparece el cartel.
		local fogAlpha = ease((t - (SHOT_D - 0.5)) / 1.5)
		if fogAlpha > 0 then
			fogOn = true
			Lighting.FogColor = fogSaved.FogColor:Lerp(Color3.fromRGB(150, 158, 172), fogAlpha)
			Lighting.FogStart = fogSaved.FogStart + (15 - fogSaved.FogStart) * fogAlpha
			Lighting.FogEnd = fogSaved.FogEnd + (95 - fogSaved.FogEnd) * fogAlpha
		end
		local textAlpha = ease((t - (SHOT_D + 2)) / 1.5)
		label.TextTransparency = 1 - textAlpha
		label.TextStrokeTransparency = 1 - textAlpha * 0.4
		local cframe, fov = frame(t)
		camera.CFrame = cframe
		camera.FieldOfView = fov
		local fade = ease((t - (duration - 1.2)) / 1.0)
		veil.BackgroundTransparency = 1 - fade
	end)
end

function Escape.start()
	Remotes.get("Escape").OnClientEvent:Connect(run)
end

return Escape
