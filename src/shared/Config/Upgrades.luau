--!strict
-- Upgrade shop: 5 parts bolted onto the cart, 10 levels each.
-- Price of level n (going from n - 1 to n) = BaseCost * CostGrowth ^ (n - 1), rounded (Rules/Upgrades.cost).
-- `lune run tools/progress` shows how long a player takes to reach each milestone with these numbers.
-- Effect at level n = PerLevel * n (Rules/Upgrades.stats). Accelerations are in studs/s² (gravity is 196.2).
local Upgrades = {
	Order = { "Engine", "FuelTank", "Wings", "Rocket", "Wheels" }, -- shop order
	MaxLevel = 10,
	CostGrowth = 2.05, -- tuned with tools/progress (all parts at 10 in ~1h50 of active play)

	-- Which kit model shows at each level (Assets.CartKit.<Model>): the highest tier whose From <= level. A new look
	-- every 2 levels. Level 0 shows nothing, except the wheels (every cart has wheels).
	Visuals = {
		Engine = {
			{ From = 1, Model = "Engine1" }, -- fan
			{ From = 3, Model = "Engine2" }, -- lawnmower motor
			{ From = 5, Model = "Engine3" }, -- turbofan
			{ From = 7, Model = "Engine4" }, -- V8
			{ From = 9, Model = "Engine5" }, -- jet
		},
		Wings = {
			{ From = 1, Model = "Wings1" }, -- cardboard
			{ From = 3, Model = "Wings2" }, -- doors
			{ From = 5, Model = "Wings3" }, -- glider
			{ From = 7, Model = "Wings4" }, -- biplane
			{ From = 9, Model = "Wings5" }, -- jet
		},
		Tail = {
			{ From = 1, Model = "Tail1" },
			{ From = 3, Model = "Tail2" },
			{ From = 5, Model = "Tail3" },
			{ From = 7, Model = "Tail4" },
			{ From = 9, Model = "Tail5" },
		},
		Rocket = {
			{ From = 1, Model = "Rocket1" }, -- firework
			{ From = 3, Model = "Rocket2" }, -- soda bottles
			{ From = 5, Model = "Rocket3" }, -- steel rocket
			{ From = 7, Model = "Rocket4" }, -- rocket pod
			{ From = 9, Model = "Rocket5" }, -- twin boosters
		},
		FuelTank = {
			{ From = 1, Model = "Tank1" }, -- jerry can
			{ From = 3, Model = "Tank2" }, -- water cooler bottle
			{ From = 5, Model = "Tank3" }, -- gas bottles
			{ From = 7, Model = "Tank4" }, -- oil barrel
			{ From = 9, Model = "Tank5" }, -- steel drum
		},
		Wheels = {
			{ From = 0, Model = "Wheels0" }, -- casters
			{ From = 2, Model = "Wheels1" }, -- rubber
			{ From = 4, Model = "Wheels2" }, -- off-road
			{ From = 6, Model = "Wheels3" }, -- monster truck
			{ From = 8, Model = "Wheels4" }, -- racing
		},
	},
	-- Visuals that follow another part's level (the tail matches the wings).
	VisualLevelOf = { Tail = "Wings" },
	-- Where each part sits on the cart (studs, cart frame: +Y up, -Z = nose) and how much it grows per level inside
	-- its tier (wings get longer as you level them).
	Mounts = {
		Engine = { Offset = { 0, 2.4, 3.3 }, GrowPerLevel = 0.04 },
		Wings = { Offset = { 0, 2.5, 0 }, GrowPerLevel = 0.07 },
		Rocket = { Offset = { 0, 0.55, 3.2 }, GrowPerLevel = 0.05 },
		Wheels = { Offset = { 0, 0, 0 }, GrowPerLevel = 0 },
		FuelTank = { Offset = { 0, 1.0, -3.3 }, GrowPerLevel = 0.04 }, -- under the nose of the basket
		Tail = { Offset = { 0, 4.0, 4.6 }, GrowPerLevel = 0.04 }, -- behind the handle, above the engine
	},

	Parts = {
		Engine = {
			Name = "Engine",
			Description = "Pushes the cart forward while there is fuel in the tank.",
			BaseCost = 60,
			ThrustPerLevel = 25, -- forward acceleration while it runs, in the air and on the ground
		},
		FuelTank = {
			Name = "Fuel Tank",
			Description = "More fuel: the engine pushes for longer.",
			BaseCost = 50,
			BaseSeconds = 1.0, -- every cart carries a small can: the engine runs this long with no tank upgrade
			SecondsPerLevel = 0.7, -- engine run time added per tank level
		},
		Wings = {
			Name = "Wings",
			Description = "Glide: the wings carry part of your weight, so you fall slower and fly further.",
			BaseCost = 70,
			-- share of gravity the wings cancel = 1 - (1 - BaseLift) * LiftKeep ^ level: every level takes the same
			-- share off the weight that is left (smooth growth: 15% bare, ~26% at level 1, ~58% at 5, ~79% at 10)
			BaseLift = 0.15,
			LiftKeep = 0.87,
		},
		Rocket = {
			Name = "Rocket",
			Description = "Hold SPACE for a big boost until the fuel runs out.",
			BaseCost = 90,
			ThrustPerLevel = 34, -- extra forward acceleration while SPACE is held
			FuelPerLevel = 0.3, -- seconds of boost
		},
		Wheels = {
			Name = "Wheels",
			Description = "Faster down the ramp, faster take-off.",
			BaseCost = 45,
			PushPerLevel = 9, -- extra acceleration down the ramp
		},
	},
}

return Upgrades
