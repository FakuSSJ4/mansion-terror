--!strict
-- El proyector del living: las bobinas giran, la luz titila y en la pantalla corre una película vieja (una escena 3D, ver `Footage`)
-- en blanco y negro con grano y rayas. La película misma (el chancho con la cámara y el sótano) la dibuja
-- `Footage` dentro del marco `Imagen` de la pantalla.

local Footage = require(script.Parent.Parent:WaitForChild("Footage"))

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Projector = {}

-- Más lejos que esto no se anima: no se ve y ahorra trabajo.
local VISIBLE_RANGE = 140
local GRAIN_COUNT = 14
local SCRATCH_COUNT = 3

type Film = {
	image: Frame,
	update: (number) -> (),
	grain: { Frame },
	scratches: { Frame },
	position: Vector3,
}

local films: { Film } = {}
local reels: { { part: BasePart, hub: CFrame, offset: CFrame } } = {}
local lights: { SpotLight } = {}

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

local function buildFilm(screen: BasePart)
	local gui = screen:WaitForChild("Pelicula", 5)
	local image = gui and gui:WaitForChild("Imagen", 5)
	if not image or not image:IsA("Frame") then
		return
	end
	-- Un ViewportFrame no se dibuja dentro de un SurfaceGui del workspace: hay que pasarlo a PlayerGui
	-- y apuntarlo a la pantalla con Adornee. Si la pantalla desaparece (nueva partida), se va con ella.
	local surface = gui :: SurfaceGui
	surface.Adornee = screen
	surface.ResetOnSpawn = false
	surface.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen.Destroying:Connect(function()
		surface:Destroy()
		for index = #films, 1, -1 do
			if films[index].image == image then
				table.remove(films, index)
			end
		end
	end)
	local update = Footage.build(image)

	local grain = {}
	for _ = 1, GRAIN_COUNT do
		table.insert(
			grain,
			frame(image, { BackgroundColor3 = Color3.fromRGB(28, 28, 28), ZIndex = 3 })
		)
	end
	local scratches = {}
	for _ = 1, SCRATCH_COUNT do
		table.insert(
			scratches,
			frame(image, {
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = Color3.fromRGB(235, 235, 235),
				BackgroundTransparency = 0.35,
				ZIndex = 3,
			})
		)
	end
	table.insert(films, {
		image = image,
		update = update,
		grain = grain,
		scratches = scratches,
		position = screen.Position,
	})
end

local function addReel(part: Instance)
	local hub = part:GetAttribute("Hub")
	if part:IsA("BasePart") and typeof(hub) == "CFrame" then
		table.insert(reels, { part = part, hub = hub, offset = hub:Inverse() * part.CFrame })
	end
end

local function addLight(part: Instance)
	local light = part:FindFirstChildOfClass("SpotLight")
	if light then
		table.insert(lights, light)
	end
end

local function watch(tag: string, callback: (Instance) -> ())
	for _, item in CollectionService:GetTagged(tag) do
		task.spawn(callback, item)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(callback)
end

function Projector.start()
	watch("ProjectorScreen", function(item)
		if item:IsA("BasePart") then
			buildFilm(item)
		end
	end)
	watch("ProjectorReel", addReel)
	watch("ProjectorLight", addLight)

	local random = Random.new()
	local nextNoise = 0
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local now = os.clock()
		local noisy = now >= nextNoise
		if noisy then
			-- La película va a unos 14 cuadros por segundo: el grano y el parpadeo cambian a ese ritmo.
			nextNoise = now + 1 / 14
		end
		local angle = now * 3
		for _, reel in reels do
			if reel.part.Parent then
				reel.part.CFrame = reel.hub * CFrame.Angles(angle, 0, 0) * reel.offset
			end
		end
		if noisy then
			for _, light in lights do
				light.Brightness = random:NextNumber(2.5, 3.2)
			end
		end
		for _, film in films do
			if (camera.CFrame.Position - film.position).Magnitude <= VISIBLE_RANGE then
				film.update(now)
				if noisy then
					for _, speck in film.grain do
						local size = random:NextInteger(2, 6)
						speck.Size = UDim2.fromOffset(size, size)
						speck.Position = UDim2.fromScale(random:NextNumber(), random:NextNumber())
						speck.Visible = random:NextNumber() < 0.6
					end
					for _, scratch in film.scratches do
						scratch.Position = UDim2.fromScale(random:NextNumber(), 0)
						scratch.Visible = random:NextNumber() < 0.35
					end
				end
			end
		end
	end)
end

return Projector
