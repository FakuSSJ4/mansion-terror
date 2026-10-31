--!strict
-- Salpicaduras de sangre en el piso donde el asesino golpea a un jugador.
-- Cada una es una sola parte invisible con el dibujo en la superficie, para no cargar el juego.

local MAX_STAINS = 25
local CANVAS_STUDS = 18
local PIXELS_PER_STUD = 24

local WET = Color3.fromRGB(175, 8, 12)
local DARK = Color3.fromRGB(95, 2, 6)

local Blood = {}

local folder: Folder?
local stains: { Instance } = {}

local function canvas(position: Vector3): SurfaceGui
	local stain = Instance.new("Part")
	stain.Name = "Sangre"
	stain.Anchored = true
	stain.CanCollide = false
	stain.CanQuery = false
	stain.CanTouch = false
	stain.CastShadow = false
	stain.Transparency = 1
	stain.Size = Vector3.new(CANVAS_STUDS, 0.05, CANVAS_STUDS)
	stain.Position = position
	stain.Parent = folder
	table.insert(stains, stain)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 1
	gui.Parent = stain
	return gui
end

local function blob(
	gui: SurfaceGui,
	x: number,
	y: number,
	length: number,
	width: number,
	degrees: number,
	color: Color3
)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, x, 0.5, y)
	frame.Size = UDim2.fromOffset(length, width)
	frame.Rotation = degrees
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
end

-- Charco central, chorros en el sentido del golpe y gotas que se van achicando.
function Blood.splat(from: Vector3, ignore: { Instance }, source: Vector3?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, Vector3.new(0, -12, 0), params)
	if not hit then
		return
	end

	if not folder then
		local created = Instance.new("Folder")
		created.Name = "Manchas"
		created.Parent = workspace
		folder = created
	end

	local away = if source then from - source else Vector3.zero
	-- En la cara superior de la parte, X de la pantalla es -X del mundo y Y es -Z.
	local heading = if away.Magnitude > 0.1
		then math.atan2(-away.Z, -away.X)
		else math.random() * 2 * math.pi

	local gui = canvas(hit.Position + Vector3.new(0, 0.08, 0))

	-- Charco irregular.
	for _ = 1, 7 do
		local angle = math.random() * 2 * math.pi
		local distance = math.random() * 22
		local size = 34 + math.random() * 46
		blob(
			gui,
			math.cos(angle) * distance,
			math.sin(angle) * distance,
			size,
			size * (0.5 + math.random() * 0.5),
			math.random() * 180,
			if math.random() < 0.3 then DARK else WET
		)
	end

	-- Chorros abiertos en abanico, cortados en tramos que se afinan para no verse como rayas.
	for _ = 1, 7 do
		local angle = heading + (math.random() - 0.5) * 1.6
		local bend = (math.random() - 0.5) * 0.25
		local distance = 30
		local width = 7 + math.random() * 6
		for _ = 1, 4 do
			local length = 12 + math.random() * 22
			blob(
				gui,
				math.cos(angle) * (distance + length / 2),
				math.sin(angle) * (distance + length / 2),
				length,
				width,
				math.deg(angle),
				WET
			)
			distance += length + math.random() * 12
			angle += bend
			width = math.max(width * 0.7, 2)
		end
	end

	-- Gotas: más chicas cuanto más lejos, estiradas hacia afuera.
	for _ = 1, 24 do
		local angle = heading + (math.random() - 0.5) * 3.4
		local distance = 45 + math.random() * 150
		local size = math.max(16 - distance * 0.07, 3) * (0.5 + math.random())
		blob(
			gui,
			math.cos(angle) * distance,
			math.sin(angle) * distance,
			size * 1.8,
			size,
			math.deg(angle),
			if math.random() < 0.25 then DARK else WET
		)
	end

	if #stains > MAX_STAINS then
		table.remove(stains, 1):Destroy()
	end
end

function Blood.clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(stains)
end

return Blood
