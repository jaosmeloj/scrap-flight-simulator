local Flight = require("../src/shared/Config/Flight")
local Upgrades = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local Rules = require("../src/shared/Rules/Upgrades")
local Sim = require("../src/shared/Rules/FlightSim")
local FlightRules = require("../src/shared/Rules/Flight")
local G = 196.2

local function apply(o)
	for k, v in o.flight or {} do
		Flight[k] = v
	end
	for part, t in o.parts or {} do
		for k, v in t do
			Upgrades.Parts[part][k] = v
		end
	end
end
local function run(levels, rocket)
	local stats = Rules.stats(Upgrades, levels, Carts.List.Basic)
	local speed = math.sqrt(2 * G * 94 + 2 * (Flight.RampBasePush + stats.push) * 250)
	local r = Sim.simulate(
		FlightRules,
		Flight,
		stats,
		{ speed = speed, angle = 24, height = 26, gravity = G, rocketHeld = rocket }
	)
	return r
end
local function report(name)
	local b = run({})
	print(
		string.format(
			"== %s  bare flight %.0f total %.0f air %.1f",
			name,
			b.flightDistance,
			b.distance,
			b.airTime
		)
	)
	for _, key in Upgrades.Order do
		local row = {}
		for _, lvl in { 1, 3, 5, 10 } do
			local r = run({ [key] = lvl }, key == "Rocket")
			table.insert(row, string.format("L%d %.0f(%.1fs)", lvl, r.distance, r.airTime))
		end
		print("  " .. key .. ": " .. table.concat(row, "  "))
	end
	local mixes = {}
	for _, lvl in { 2, 5, 8, 10 } do
		local r = run({ Engine = lvl, Wings = lvl, Rocket = lvl, Wheels = lvl }, true)
		table.insert(mixes, string.format("all%d %.0f(%.0fs)", lvl, r.distance, r.airTime))
	end
	print("  " .. table.concat(mixes, "  "))
end
apply(require("./sweep_params"))
report("params")
