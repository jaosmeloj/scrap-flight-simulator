-- lune run tools/tune  -> distance table per upgrade level (tuning aid; same formulas as the game)
local Flight = require("../src/shared/Config/Flight")
local Upgrades = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local Rules = require("../src/shared/Rules/Upgrades")
local Sim = require("../src/shared/Rules/FlightSim")
local FlightRules = require("../src/shared/Rules/Flight")

local G = 196.2
-- lip exit speed: frictionless drop of 94 studs + ramp push (base + wheels) over ~250 studs
local function exitSpeed(push)
	return math.sqrt(2 * G * 94 + 2 * (Flight.RampBasePush + push) * 250)
end
local function run(levels, rocket)
	local stats = Rules.stats(Upgrades, levels, Carts.List.Basic)
	local r = Sim.simulate(FlightRules, Flight, stats, {
		speed = exitSpeed(stats.push),
		angle = 24,
		height = 26,
		gravity = G,
		rocketHeld = rocket,
		pitch = 1,
	})
	return r.distance, r.airTime
end
print(string.format("bare: %.0f studs (%.1fs)", run({})))
for _, key in Upgrades.Order do
	local row = {}
	for _, lvl in { 1, 3, 5, 10 } do
		local d = run({ [key] = lvl }, key == "Rocket")
		table.insert(row, string.format("L%d %.0f", lvl, d))
	end
	print(key .. ": " .. table.concat(row, "  "))
end
print(
	string.format(
		"all 5: %.0f   all 10: %.0f",
		run({ Engine = 5, FuelTank = 5, Wings = 5, Rocket = 5, Wheels = 5 }, true),
		run({ Engine = 10, FuelTank = 10, Wings = 10, Rocket = 10, Wheels = 10 }, true)
	)
)
