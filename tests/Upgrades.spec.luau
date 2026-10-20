local Config = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local Upgrades = require("../src/shared/Rules/Upgrades")

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

return function(check)
	check(
		"first engine level costs the base cost",
		Upgrades.cost(Config, "Engine", 0) == Config.Parts.Engine.BaseCost
	)
	check(
		"price grows CostGrowth x per level",
		Upgrades.cost(Config, "Engine", 1)
			== math.floor(Config.Parts.Engine.BaseCost * Config.CostGrowth + 0.5)
	)
	check("max level has no price", Upgrades.cost(Config, "Wings", Config.MaxLevel) == nil)
	check("unknown part has no price", Upgrades.cost(Config, "Cannon", 0) == nil)
	check("negative level has no price", Upgrades.cost(Config, "Engine", -1) == nil)

	local zero = Upgrades.stats(Config, {}, Carts.List.Basic)
	check(
		"bare cart: no engine, no rocket, no fuel",
		zero.engine == 0 and zero.rocket == 0 and zero.fuel == 0
	)
	check("bare cart still has the base lift", near(zero.lift, Config.Parts.Wings.BaseLift))
	check("no engine = no engine time", zero.engineTime == 0)
	check("basic cart drag is 1", zero.drag == 1)

	local maxed = Upgrades.stats(
		Config,
		{ Engine = 10, FuelTank = 10, Wings = 10, Rocket = 10, Wheels = 10 },
		Carts.List.Golden
	)
	local parts = Config.Parts
	check("engine 10 = 10 x thrust per level", maxed.engine == 10 * parts.Engine.ThrustPerLevel)
	check(
		"rocket 10 = 10 x thrust and fuel per level",
		maxed.rocket == 10 * parts.Rocket.ThrustPerLevel and near(maxed.fuel, 10 * parts.Rocket.FuelPerLevel)
	)
	check(
		"wings 10 + golden bonus",
		near(
			maxed.lift,
			math.min(
				1 - (1 - parts.Wings.BaseLift) * parts.Wings.LiftKeep ^ 10 + Carts.List.Golden.LiftBonus,
				1
			)
		)
	)
	check("wheels 10 = 90 push", maxed.push == 90)
	check("golden cart drag 0.5", maxed.drag == 0.5)
	check(
		"tank 10 holds base + 10 x per level of engine fuel",
		near(maxed.engineTime, parts.FuelTank.BaseSeconds + 10 * parts.FuelTank.SecondsPerLevel)
	)
	local smallTank = Upgrades.stats(Config, { Engine = 3 }, nil)
	check(
		"an engine without tank upgrades still has the base can",
		near(smallTank.engineTime, parts.FuelTank.BaseSeconds)
	)
	check(
		"a tank without an engine gives no engine time",
		Upgrades.stats(Config, { FuelTank = 5 }, nil).engineTime == 0
	)
	check("tank level 1 shows the jerry can", (Upgrades.visual(Config, "FuelTank", 1)) == "Tank1")
	check("tank level 9 shows the drum", (Upgrades.visual(Config, "FuelTank", 9)) == "Tank5")

	local over = Upgrades.stats(Config, { Engine = 99, Wings = "x" }, nil)
	check("levels above max are capped", over.engine == 10 * parts.Engine.ThrustPerLevel)
	check("broken level counts as 0", near(over.lift, Config.Parts.Wings.BaseLift))
	check("no cart = drag 1", over.drag == 1)

	check("engine level 0 shows nothing", Upgrades.visual(Config, "Engine", 0) == nil)
	local model, scale = Upgrades.visual(Config, "Engine", 1)
	check("engine level 1 = fan", model == "Engine1" and scale == 1)
	model, scale = Upgrades.visual(Config, "Wings", 6)
	local grow = Config.Mounts.Wings.GrowPerLevel
	check("wings level 6 = glider, grown 1 level", model == "Wings3" and math.abs(scale - (1 + grow)) < 1e-9)
	check("engine level 10 = jet", (Upgrades.visual(Config, "Engine", 10)) == "Engine5")
	check("a new look every 2 levels", (Upgrades.visual(Config, "Rocket", 3)) == "Rocket2")
	check("wheels level 0 still has casters", (Upgrades.visual(Config, "Wheels", 0)) == "Wheels0")
	check("wheels level 9 = racing", (Upgrades.visual(Config, "Wheels", 9)) == "Wheels4")
	check(
		"the tail follows the wings",
		Config.VisualLevelOf.Tail == "Wings" and (Upgrades.visual(Config, "Tail", 7)) == "Tail4"
	)
	check("unknown part shows nothing", Upgrades.visual(Config, "Cannon", 3) == nil)
end
