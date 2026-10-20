-- lune run tools/gain -> distance gain of level 1 of each part (on engine 3 for the tank)
local Flight = require("../src/shared/Config/Flight")
local Upgrades = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local UpgradeRules = require("../src/shared/Rules/Upgrades")
local FlightRules = require("../src/shared/Rules/Flight")
local Sim = require("../src/shared/Rules/FlightSim")
local G = 196.2
local function fly(levels, rocket)
	local stats = UpgradeRules.stats(Upgrades, levels, Carts.List.Basic)
	local speed = math.sqrt(2 * G * 94 + 2 * (Flight.RampBasePush + stats.push) * 250)
	return Sim.simulate(
		FlightRules,
		Flight,
		stats,
		{ speed = speed, angle = 24, height = 26, gravity = G, rocketHeld = rocket, pitch = 1 }
	).distance
end
for _, key in Upgrades.Order do
	local base = if key == "FuelTank" then { Engine = 3, Wings = 3 } else {}
	local with = table.clone(base)
	with[key] = 1
	local a, b = fly(base), fly(with, key == "Rocket")
	print(string.format("%-9s %5.0f -> %5.0f  (+%.1f%%)", key, a, b, (b / a - 1) * 100))
end
