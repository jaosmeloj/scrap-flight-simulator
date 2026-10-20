--!strict
-- Landing field for Scrap Flight Simulator (placeholder look until the map phase). Run in Studio (edit mode,
-- MCP execute_luau or the command bar). It only replaces what it built: Launch.Ground, Launch.Ground2, Launch.Marker
-- parts and the Launch.Field folder; the ramp and anything else are left alone.
-- The ground follows Config/Zones (each zone its own colour/material). The Sea is real Terrain water whose surface
-- is Y = -4: a cart that comes down there sinks below Config/Flight.WaterLevel and splashes (the run ends). Parts are at most 2048 studs long (Roblox limit).
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
local WATER_TOP = -4 -- the sea surface (a multiple of 4: Terrain voxels); Config/Flight.WaterLevel sits 2 above it
local WATER_DEPTH = 36
local Terrain = workspace.Terrain

local LOOKS = {
	Town = { Color = Color3.fromRGB(96, 168, 72), Material = Enum.Material.Grass, Top = 0 },
	Farm = { Color = Color3.fromRGB(150, 180, 70), Material = Enum.Material.Grass, Top = 0 },
	Desert = { Color = Color3.fromRGB(214, 184, 120), Material = Enum.Material.Sand, Top = 0 },
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
	if zone.Id == "Sea" then
		-- terrain: clear, sand floor, water up to the surface (in chunks: FillBlock regions stay small)
		local x = from
		while x < to do
			local length = math.min(512, to - x)
			local cx = x + length / 2
			Terrain:FillBlock(CFrame.new(cx, -24, 0), Vector3.new(length, 56, WIDTH), Enum.Material.Air)
			Terrain:FillBlock(
				CFrame.new(cx, WATER_TOP - WATER_DEPTH - 4, 0),
				Vector3.new(length, 8, WIDTH),
				Enum.Material.Sand
			)
			Terrain:FillBlock(
				CFrame.new(cx, WATER_TOP - WATER_DEPTH / 2, 0),
				Vector3.new(length, WATER_DEPTH, WIDTH),
				Enum.Material.Water
			)
			x += length
		end
		continue
	end
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
	local inSea = false
	for i, zone in list do
		local to = if list[i + 1] then list[i + 1].Start else FIELD_END
		if d >= zone.Start and d < to and zone.Id == "Sea" then
			inSea = true
		end
	end
	if inSea then
		continue -- no lines on the water
	end
	local top = 0
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
Terrain.WaterColor = Color3.fromRGB(30, 140, 190)
Terrain.WaterTransparency = 0.35
Terrain.WaterReflectance = 0.4
Terrain.WaterWaveSize = 0.35
Terrain.WaterWaveSpeed = 12
Terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(220, 196, 140))
return string.format(
	"field built: %d ground tiles to %d studs, %d markers",
	tiles,
	FIELD_END,
	FIELD_END // 100
)
