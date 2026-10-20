--!strict
-- Placeholder launch ramp for Scrap Flight Simulator (phase 1). Run once in Studio (edit mode, MCP execute_luau or the command
-- bar); it replaces Workspace.Launch. The map phase swaps the look, but keeps the names the code uses:
--   Launch.Start  top platform centre (carts spawn on it, one lane per player along Z)
--   Launch.Ramp   folder with every ramp/platform part (ignored by the landing check)
--   Launch.Lip    the end of the ramp: flight distance = cart X - Lip X (flight goes to +X)
--   Launch.Ground the long field the carts land on (top at Y = 0)
-- The ramp profile is built by walking along it: flat top, curve down to -30°, long slope, curve up to +24°, lip.

local WIDTH = 90 -- 8 lanes x 10 studs + rails
local LIP_HEIGHT = 26 -- top of the lip above the ground
local THICK = 2
local SEG = 2 -- studs per ramp segment

local old = workspace:FindFirstChild("Launch")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Launch"
local rampFolder = Instance.new("Folder")
rampFolder.Name = "Ramp"
rampFolder.Parent = root

local frictionless = PhysicalProperties.new(1, 0, 0, 100, 100)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- profile: list of { length, angle at the end (degrees) }; the angle changes linearly along each piece
local pieces = {
	{ 50, 0 }, -- top platform run-up
	{ 36, -30 }, -- round over the top
	{ 170, -30 }, -- the drop
	{ 70, 24 }, -- curve up into the kicker
	{ 10, 24 }, -- lip
}
local points = { { x = 0, y = 0, a = 0 } }
local angle = 0
for _, piece in pieces do
	local length, target = piece[1], piece[2]
	local steps = math.max(1, math.floor(length / SEG))
	for i = 1, steps do
		local a0 = angle + (target - angle) * (i - 1) / steps
		local a1 = angle + (target - angle) * i / steps
		local mid = math.rad((a0 + a1) / 2)
		local last = points[#points]
		table.insert(points, { x = last.x + math.cos(mid) * SEG, y = last.y + math.sin(mid) * SEG, a = a1 })
	end
	angle = target
end
-- shift so the lip (last point) sits at x = 0, y = LIP_HEIGHT
local lipPoint = points[#points]
local dx, dy = -lipPoint.x, LIP_HEIGHT - lipPoint.y
for _, p in points do
	p.x += dx
	p.y += dy
end

for i = 1, #points - 1 do
	local a, b = points[i], points[i + 1]
	local from = Vector3.new(a.x, a.y, 0)
	local to = Vector3.new(b.x, b.y, 0)
	local length = (to - from).Magnitude
	local dir = (to - from).Unit
	local up = Vector3.new(-dir.Y, dir.X, 0)
	local centre = (from + to) / 2 - up * (THICK / 2)
	local cf = CFrame.fromMatrix(centre, dir, up)
	part({
		Name = "RampSegment",
		Size = Vector3.new(length + 0.05, THICK, WIDTH),
		CFrame = cf,
		Color = if math.floor(i / 6) % 2 == 0
			then Color3.fromRGB(232, 92, 60)
			else Color3.fromRGB(250, 214, 80),
		Material = Enum.Material.SmoothPlastic,
		CustomPhysicalProperties = frictionless,
		Parent = rampFolder,
	})
	for _, side in { -1, 1 } do
		part({
			Name = "Rail",
			Size = Vector3.new(length + 0.05, 3, 1),
			CFrame = cf * CFrame.new(0, 1.5 + THICK / 2, side * (WIDTH / 2 + 0.5)),
			Color = Color3.fromRGB(60, 64, 76),
			Material = Enum.Material.Metal,
			CustomPhysicalProperties = frictionless,
			Parent = rampFolder,
		})
	end
	-- support pillars every 10 segments
	if i % 10 == 0 then
		local height = b.y
		for _, side in { -1, 1 } do
			part({
				Name = "Pillar",
				Size = Vector3.new(2, height, 2),
				CFrame = CFrame.new(b.x, height / 2, side * (WIDTH / 2 - 2)),
				Color = Color3.fromRGB(120, 110, 100),
				Material = Enum.Material.Concrete,
				Parent = rampFolder,
			})
		end
	end
end

-- top platform behind the ramp start (lobby for now) and the spawn
local top = points[1]
local platformLength = 60
part({
	Name = "Platform",
	Size = Vector3.new(platformLength, THICK, WIDTH + 2),
	CFrame = CFrame.new(top.x - platformLength / 2, top.y - THICK / 2, 0),
	Color = Color3.fromRGB(90, 96, 110),
	Material = Enum.Material.Concrete,
	CustomPhysicalProperties = frictionless,
	Parent = rampFolder,
})
part({
	Name = "Start",
	Size = Vector3.new(6, THICK, 2),
	CFrame = CFrame.new(top.x + 4, top.y - THICK / 2, 0),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = root,
})
local spawn = workspace:FindFirstChildOfClass("SpawnLocation") or Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.CFrame = CFrame.new(top.x - platformLength + 8, top.y + 0.5, 0)
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = workspace

part({
	Name = "Lip",
	Size = Vector3.new(1, 1, WIDTH),
	CFrame = CFrame.new(0, LIP_HEIGHT, 0),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Parent = root,
})

-- landing field (the map phase replaces it with the zones)
part({
	Name = "Ground",
	Size = Vector3.new(2048, 4, 600),
	CFrame = CFrame.new(1024 - 200, -2, 0),
	Color = Color3.fromRGB(96, 168, 72),
	Material = Enum.Material.Grass,
	Parent = root,
})
part({
	Name = "Ground2",
	Size = Vector3.new(2048, 4, 600),
	CFrame = CFrame.new(1024 - 200 + 2048, -2, 0),
	Color = Color3.fromRGB(196, 170, 110),
	Material = Enum.Material.Sand,
	Parent = root,
})
-- distance markers every 100 studs
for d = 100, 4000, 100 do
	part({
		Name = "Marker",
		Size = Vector3.new(1, 0.2, 600),
		CFrame = CFrame.new(d, 0.1, 0),
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		Parent = root,
	})
end

local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
root.Parent = workspace
return string.format(
	"ramp built: top (%.0f, %.0f), lip (0, %d), %d segments",
	top.x,
	top.y,
	LIP_HEIGHT,
	#points - 1
)
