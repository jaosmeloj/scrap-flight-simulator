--!strict
-- Upgrade prices and the flight stats a set of levels gives (pure: config in, numbers out).
local Upgrades = {}

export type Levels = { [string]: number }

export type Stats = {
	engine: number, -- forward accel while the engine runs
	engineTime: number, -- seconds of engine fuel (the tank), 0 without an engine
	lift: number, -- lift coefficient (wings + cart bonus)
	rocket: number, -- extra forward accel while SPACE is held
	fuel: number, -- seconds of rocket
	push: number, -- ramp push accel (wheels)
	drag: number, -- cart drag multiplier
}

local function level(levels: Levels, key: string): number
	local value = levels[key]
	if typeof(value) ~= "number" then
		return 0
	end
	return math.max(0, math.floor(value))
end

-- Price to go from `current` to `current + 1`; nil at max level or for an unknown part.
function Upgrades.cost(config: any, key: string, current: number): number?
	local part = config.Parts[key]
	if part == nil or current >= config.MaxLevel or current < 0 then
		return nil
	end
	return math.floor(part.BaseCost * config.CostGrowth ^ current + 0.5)
end

-- Flight stats for the player's levels and cart (cart = one entry of Config/Carts.List).
function Upgrades.stats(config: any, levels: Levels, cart: any): Stats
	local parts = config.Parts
	local cap = config.MaxLevel
	local function lvl(key: string): number
		return math.min(level(levels, key), cap)
	end
	return {
		engine = parts.Engine.ThrustPerLevel * lvl("Engine"),
		engineTime = if lvl("Engine") > 0
			then parts.FuelTank.BaseSeconds + parts.FuelTank.SecondsPerLevel * lvl("FuelTank")
			else 0,
		lift = math.min(
			1
				- (1 - parts.Wings.BaseLift) * parts.Wings.LiftKeep ^ lvl("Wings")
				+ (cart and cart.LiftBonus or 0),
			1
		),
		rocket = parts.Rocket.ThrustPerLevel * lvl("Rocket"),
		fuel = parts.Rocket.FuelPerLevel * lvl("Rocket"),
		push = parts.Wheels.PushPerLevel * lvl("Wheels"),
		drag = if cart then cart.Drag else 1,
	}
end

-- Kit model for a part at level `current` and the scale to draw it at, or nil when nothing shows (level 0).
function Upgrades.visual(config: any, key: string, current: number): (string?, number)
	local tiers = config.Visuals[key]
	local mount = config.Mounts[key]
	if tiers == nil then
		return nil, 1
	end
	local chosen = nil
	for _, tier in tiers do
		if current >= tier.From then
			chosen = tier
		end
	end
	if chosen == nil then
		return nil, 1
	end
	local grow = if mount then mount.GrowPerLevel else 0
	return chosen.Model, 1 + (current - chosen.From) * grow
end

return Upgrades
