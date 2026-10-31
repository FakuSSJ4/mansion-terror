--!strict
-- Manchones de sangre en el piso donde el asesino golpea a un jugador.

local MAX_STAINS = 30
local STAIN_COLOR = Color3.fromRGB(58, 2, 4)

local Blood = {}

local folder: Folder?
local stains: { Instance } = {}

local function disc(parent: Instance, position: Vector3, diameter: number)
	local stain = Instance.new("Part")
	stain.Name = "Sangre"
	stain.Shape = Enum.PartType.Cylinder
	stain.Anchored = true
	stain.CanCollide = false
	stain.CanQuery = false
	stain.CanTouch = false
	stain.CastShadow = false
	-- Óvalo girado al azar: superpuestos no dejan ver círculos perfectos.
	stain.Size = Vector3.new(0.04, diameter, diameter * (0.45 + math.random() * 0.5))
	stain.CFrame = CFrame.new(position)
		* CFrame.Angles(0, math.random() * 2 * math.pi, 0)
		* CFrame.Angles(0, 0, math.rad(90))
	stain.Color = STAIN_COLOR
	stain.Material = Enum.Material.SmoothPlastic
	stain.Parent = parent
end

-- Un manchón grande con salpicaduras alrededor, sobre el piso que hay bajo `from`.
function Blood.splat(from: Vector3, ignore: { Instance })
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
	local group = Instance.new("Model")
	group.Name = "Mancha"
	group.Parent = folder

	local floor = hit.Position + Vector3.new(0, 0.1, 0)
	-- Charco central irregular y gotas que se alejan.
	for _ = 1, 5 do
		local angle = math.random() * 2 * math.pi
		local distance = math.random() * 1.4
		local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		disc(group, floor + offset, 2 + math.random() * 2)
	end
	for _ = 1, 6 do
		local angle = math.random() * 2 * math.pi
		local distance = 2.4 + math.random() * 3
		local offset = Vector3.new(math.cos(angle) * distance, 0.01, math.sin(angle) * distance)
		disc(group, floor + offset, 0.25 + math.random() * 0.7)
	end

	table.insert(stains, group)
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
