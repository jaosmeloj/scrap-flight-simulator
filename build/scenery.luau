--!strict
-- Scenery along the flight path (Workspace.Scenery), from the kit in ReplicatedStorage.Assets.SceneryKit.
-- Run in Studio (edit mode, MCP execute_luau or the command bar). It only replaces Workspace.Scenery (built by this
-- script), so nothing else in the place is touched. Same SEED = same layout.
-- Props never collide (the flight is not blocked; obstacles are out of v1): CanCollide/CanQuery/CanTouch off.
-- Zone ranges come from Config/Zones; the flight goes along +X from the ramp lip (X = 0), the field is ±1000 Z.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SEED = 7
local SIZE = 2.2 -- every prop is drawn this much bigger than the kit (the field is huge: small props vanish)
local DENSITY = 1.8 -- more props per stretch of path (steps are divided by this)
local ACROSS = { Rainbow = true, RockArch = true } -- arches: turned 90 degrees so they span the flight path
local BIG = { Mesa = true, Rainbow = true, CloudCastle = true, RockArch = true, Supermarket = true } -- already sized
local rng = Random.new(SEED)

local kit = ReplicatedStorage:FindFirstChild("Assets")
	and ReplicatedStorage.Assets:FindFirstChild("SceneryKit")
assert(kit, "ReplicatedStorage.Assets.SceneryKit is missing: import SceneryKit.fbx and assemble it first")

-- fresh copies of the configs (a plugin keeps old module versions cached)
local function fresh(module: ModuleScript): any
	local copy = module:Clone()
	copy.Parent = module.Parent
	local value = require(copy)
	copy:Destroy()
	return value
end
local Zones = fresh(ReplicatedStorage.Shared.Config.Zones)
local Looks = fresh(ReplicatedStorage.Shared.Config.SceneryLooks)

local WATER = -4 -- build/field.luau: the sea's water surface
local FIELD_END = 16000

local old = workspace:FindFirstChild("Scenery")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Scenery"

local folders: { [string]: Folder } = {}
local function folder(name: string): Folder
	if not folders[name] then
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		folders[name] = f
	end
	return folders[name]
end

local placed = 0
-- Places a kit model with its base at (x, y, z). `facePath` turns its front toward the flight path (Z = 0).
local function put(
	name: string,
	zone: string,
	x: number,
	y: number,
	z: number,
	scale: number?,
	facePath: boolean?
)
	local source = kit:FindFirstChild(name)
	if not source then
		warn("[scenery] missing kit model", name)
		return
	end
	local model = (source :: Model):Clone()
	local finalScale = (scale or 1) * (if BIG[name] then 1 else SIZE)
	if finalScale ~= 1 then
		model:ScaleTo(finalScale)
	end
	local yaw = if facePath
		then (if z < 0 then math.pi else 0) + rng:NextNumber(-0.25, 0.25)
		else rng:NextNumber(0, math.pi * 2)
	if ACROSS[name] then
		yaw = math.pi / 2
	end
	model:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local look = Looks.Groups[part.Name]
			if look then
				part.Material = (Enum.Material :: any)[look.Material] or Enum.Material.SmoothPlastic
				part.Color = Color3.fromRGB(look.Color[1], look.Color[2], look.Color[3])
			end
			if part.Name == "Window" then
				part.Transparency = Looks.GlassTransparency
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	model.Parent = folder(zone)
	placed += 1
end

local function zoneRange(id: string): (number, number)
	for i, zone in Zones.List do
		if zone.Id == id then
			local from = if i == 1 then -400 else zone.Start
			local to = if Zones.List[i + 1] then Zones.List[i + 1].Start else FIELD_END
			return from, to
		end
	end
	error("unknown zone " .. id)
end

local function side(): number
	return if rng:NextNumber() < 0.5 then -1 else 1
end

-- Walks a zone in steps; at each step `spawn(x)` places something.
local function along(id: string, step: number, spawn: (number) -> ())
	local from, to = zoneRange(id)
	step /= DENSITY
	local x = from + step * rng:NextNumber(0.2, 0.8)
	while x < to do
		spawn(x)
		x += step * rng:NextNumber(0.7, 1.3)
	end
end

-- Town: the supermarket beside the ramp start, rows of houses, trees, lamps and parked cars
put("Supermarket", "Town", -230, 0, -150, 1, true)
along("Town", 42, function(x)
	for _, s in { -1, 1 } do
		put(
			if rng:NextNumber() < 0.5 then "House1" else "House2",
			"Town",
			x,
			0,
			s * rng:NextNumber(90, 160),
			rng:NextNumber(0.9, 1.15),
			true
		)
		if rng:NextNumber() < 0.7 then
			put(
				"TreeTown",
				"Town",
				x + rng:NextNumber(-12, 12),
				0,
				s * rng:NextNumber(60, 80),
				rng:NextNumber(0.8, 1.2)
			)
		end
		if rng:NextNumber() < 0.4 then
			put(
				if rng:NextNumber() < 0.5 then "CarBlue" else "CarYellow",
				"Town",
				x + 8,
				0,
				s * rng:NextNumber(70, 85)
			)
		end
	end
	put("StreetLamp", "Town", x, 0, side() * 52, 1, true)
end)

-- Farm: barns, silos and windmills, cows, hay, corn and fences
along("Farm", 120, function(x)
	local s = side()
	put("Barn", "Farm", x, 0, s * rng:NextNumber(140, 260), rng:NextNumber(0.9, 1.2), true)
	put("Silo", "Farm", x + 30, 0, s * rng:NextNumber(170, 280), rng:NextNumber(0.9, 1.1))
	if rng:NextNumber() < 0.6 then
		put(
			"Windmill",
			"Farm",
			x + rng:NextNumber(-40, 40),
			0,
			-s * rng:NextNumber(150, 400),
			rng:NextNumber(1, 1.4)
		)
	end
end)
along("Farm", 40, function(x)
	local s = side()
	local herd = rng:NextInteger(1, 4)
	local z = s * rng:NextNumber(60, 220)
	for _ = 1, herd do
		put("Cow", "Farm", x + rng:NextNumber(-10, 10), 0, z + rng:NextNumber(-10, 10))
	end
	put("HayBale", "Farm", x + rng:NextNumber(-15, 15), 0, -s * rng:NextNumber(50, 200))
	if rng:NextNumber() < 0.5 then
		put("CornField", "Farm", x, 0, -s * rng:NextNumber(80, 300), rng:NextNumber(1, 1.6))
	end
	put("FarmFence", "Farm", x, 0, s * 45, 1, true)
	if rng:NextNumber() < 0.5 then
		put("TreeFarm", "Farm", x + 15, 0, s * rng:NextNumber(300, 700), rng:NextNumber(0.9, 1.4))
	end
end)

-- Desert: cacti near the path, rocks, skulls, oil pumps, rock arches over the path, mesas far out
along("Desert", 18, function(x)
	put(
		if rng:NextNumber() < 0.5 then "Cactus1" else "Cactus2",
		"Desert",
		x,
		0,
		side() * rng:NextNumber(30, 500),
		rng:NextNumber(0.8, 1.5)
	)
	if rng:NextNumber() < 0.35 then
		put("Rocks", "Desert", x + 5, 0, side() * rng:NextNumber(20, 600), rng:NextNumber(0.8, 2))
	end
	if rng:NextNumber() < 0.06 then
		put("Skull", "Desert", x, 0, side() * rng:NextNumber(40, 300), rng:NextNumber(1, 1.6))
	end
end)
along("Desert", 220, function(x)
	put("Mesa", "Desert", x, 0, side() * rng:NextNumber(350, 850), rng:NextNumber(1, 2.4))
	if rng:NextNumber() < 0.5 then
		put("OilPump", "Desert", x + 40, 0, side() * rng:NextNumber(80, 300), rng:NextNumber(1, 1.4), true)
	end
end)
along("Desert", 600, function(x)
	put("RockArch", "Desert", x, 0, 0, rng:NextNumber(2.5, 3.5), true) -- you fly through (or over) it
end)

-- Sea: islands with palms, a lighthouse, boats, buoys, rocks
along("Sea", 260, function(x)
	put("Island", "Sea", x, WATER - 4, side() * rng:NextNumber(60, 600), rng:NextNumber(1, 1.8)) -- beach above the water
	put("Boat", "Sea", x + 100, WATER - 1, side() * rng:NextNumber(40, 400), rng:NextNumber(1, 1.4)) -- hull in the water
end)
along("Sea", 90, function(x)
	put("Buoy", "Sea", x, WATER + 2.2, side() * rng:NextNumber(20, 120)) -- floats: its base sits at the surface
	if rng:NextNumber() < 0.5 then
		put("SeaRocks", "Sea", x + 30, WATER - 2, side() * rng:NextNumber(60, 700), rng:NextNumber(1, 2))
	end
end)
do
	local from, to = zoneRange("Sea")
	put("Lighthouse", "Sea", (from + to) / 2, WATER - 2, 140, 1.4, true)
	put("Lighthouse", "Sea", from + 300, WATER - 2, -180, 1.2, true)
end

-- Clouds: puffs at many heights, floating islands, rainbows over the path, the castle at the end
along("Clouds", 45, function(x)
	put(
		"CloudPuff",
		"Clouds",
		x,
		rng:NextNumber(15, 160),
		side() * rng:NextNumber(20, 800),
		rng:NextNumber(1, 2.5)
	)
end)
along("Clouds", 300, function(x)
	put(
		"FloatingIsland",
		"Clouds",
		x,
		rng:NextNumber(40, 160),
		side() * rng:NextNumber(80, 600),
		rng:NextNumber(1, 2)
	)
end)
along("Clouds", 1500, function(x)
	put("Rainbow", "Clouds", x, 0, 0, rng:NextNumber(2.2, 3), true) -- an arch over the flight path
end)
put("CloudCastle", "Clouds", FIELD_END - 600, 0, 0, 1.6, true)

root.Parent = workspace
return string.format("scenery built: %d models (seed %d)", placed, SEED)
