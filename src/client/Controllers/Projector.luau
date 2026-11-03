--!strict
-- El proyector del living: las bobinas giran, la luz titila y en la pantalla corre una película vieja
-- en blanco y negro. Por ahora es la cuenta regresiva de una cola de película, con grano y rayas; la
-- animación definitiva va dentro del marco "Imagen" de la pantalla.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Projector = {}

-- Más lejos que esto no se anima: no se ve y ahorra trabajo.
local VISIBLE_RANGE = 140
local GRAIN_COUNT = 14
local SCRATCH_COUNT = 3

type Film = {
	image: Frame,
	sweep: Frame,
	number: TextLabel,
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

local function circle(parent: Instance, size: number)
	local ring = frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(size, size),
		BackgroundTransparency = 1,
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(36, 36, 36)
	stroke.Thickness = 3
	stroke.Parent = ring
end

local function buildFilm(screen: BasePart)
	local gui = screen:WaitForChild("Pelicula", 5)
	local image = gui and gui:WaitForChild("Imagen", 5)
	if not image or not image:IsA("Frame") then
		return
	end
	circle(image, 0.82)
	circle(image, 0.64)
	local dark = Color3.fromRGB(36, 36, 36)
	frame(image, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = dark,
	})
	frame(image, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = dark,
	})
	local sweep = frame(image, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(0.012, 0.41),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
	})
	local number = Instance.new("TextLabel")
	number.AnchorPoint = Vector2.new(0.5, 0.5)
	number.Position = UDim2.fromScale(0.5, 0.5)
	number.SizeConstraint = Enum.SizeConstraint.RelativeYY
	number.Size = UDim2.fromScale(0.5, 0.5)
	number.BackgroundTransparency = 1
	number.Font = Enum.Font.Garamond
	number.TextScaled = true
	number.TextColor3 = Color3.fromRGB(22, 22, 22)
	number.Text = "8"
	number.ZIndex = 2
	number.Parent = image

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
		sweep = sweep,
		number = number,
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
				-- Cuenta regresiva de 8 a 2 y vuelve a empezar, con el barrido de cada segundo.
				film.number.Text = tostring(8 - math.floor(now % 7))
				film.sweep.Rotation = (now % 1) * 360
				if noisy then
					local grey = random:NextInteger(168, 205)
					film.image.BackgroundColor3 = Color3.fromRGB(grey, grey, grey - 4)
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
