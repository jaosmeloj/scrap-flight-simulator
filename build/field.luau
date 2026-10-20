--!strict
-- Landing field for Scrap Flight Simulator (placeholder look until the map phase). Run in Studio (edit mode,
-- MCP execute_luau or the command bar). It only replaces what it built: Launch.Ground, Launch.Ground2, Launch.Marker
-- parts and the Launch.Field folder; the ramp and anything else are left alone.
-- The ground follows Config/Zones (each zone its own colour/material); the Sea is lower than Config/Flight.WaterLevel,
-- so a cart that comes down there splashes (the run ends). Parts are at most 2048 studs long (Roblox limit).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local launch = workspace:FindFirstChild("Launch")
assert(launch, "Workspace.Launch is missing: run build/ramp.luau first")

-- fresh copy of the zone config (a plugin keeps old module versions cached)
local zonesModule = ReplicatedStorage.Shared.Config.Zones:Clone()
zonesModule.Parent = ReplicatedStorage.Shared.Config
local Zones = require(zonesModule :: ModuleScript)
zonesModule:Destroy()

local FIELD_END = 16000 -- studs past the lip
local FIELD_START = -400 -- under the ramp
local WIDTH = 2000 -- Z (the server keeps carts within Config/Flight.FieldHalfWidth)
local TILE = 2000
local SEA_DROP = 6 -- the sea surface sits this far below the ground (below the water level)

local LOOKS = {
	Town = { Color = Color3.fromRGB(96, 168, 72), Material = Enum.Material.Grass, Top = 0 },
	Farm = { Color = Color3.fromRGB(150, 180, 70), Material = Enum.Material.Grass, Top = 0 },
	Desert = { Color = Color3.fromRGB(214, 184, 120), Material = Enum.Material.Sand, Top = 0 },
	Sea = { Color = Color3.fromRGB(50, 130, 200), Material = Enum.Material.Glass, Top = -SEA_DROP },
	Clouds = { Color = Color3.fromRGB(245, 248, 255), Material = Enum.Material.Fabric, Top = 0 },
}

for _, child in launch:GetChildren() do
	if
		child.Name == "Ground"
		or child.Name == "Ground2"
		or child.Name == "Marker"
		or child.Name == "Field"
	then
		child:Destroy()
	end
end
local field = Instance.new("Folder")
field.Name = "Field"

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = field
	return p
end

-- zone ranges along X (the first zone also covers the ground under the ramp)
local list = Zones.List
local tiles = 0
for i, zone in list do
	local from = if i == 1 then FIELD_START else zone.Start
	local to = if list[i + 1] then list[i + 1].Start else FIELD_END
	local look = LOOKS[zone.Id] or LOOKS.Town
	local x = from
	while x < to do
		local length = math.min(TILE, to - x)
		part({
			Name = "Ground_" .. zone.Id,
			Size = Vector3.new(length, 4, WIDTH),
			CFrame = CFrame.new(x + length / 2, look.Top - 2, 0),
			Color = look.Color,
			Material = look.Material,
			Transparency = if zone.Id == "Sea" then 0.15 else 0,
		})
		tiles += 1
		x += length
	end
end

-- distance markers: a thin line every 100 studs, a thicker one every 500
for d = 100, FIELD_END, 100 do
	local major = d % 500 == 0
	local top = 0
	for i, zone in list do
		local to = if list[i + 1] then list[i + 1].Start else FIELD_END
		if d >= zone.Start and d < to and zone.Id == "Sea" then
			top = -SEA_DROP
		end
	end
	part({
		Name = "Marker",
		Size = Vector3.new(if major then 3 else 1, 0.2, WIDTH),
		CFrame = CFrame.new(d, top + 0.1, 0),
		Color = if major then Color3.fromRGB(255, 230, 90) else Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

field.Parent = launch
return string.format(
	"field built: %d ground tiles to %d studs, %d markers",
	tiles,
	FIELD_END,
	FIELD_END // 100
)
