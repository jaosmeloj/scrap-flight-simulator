-- lune run tools/compare -> simulator vs. the recorded flight (engine 3, wings 4, wheels 3, W held)
local Flight = require("../src/shared/Config/Flight")
local Upgrades = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local Rules = require("../src/shared/Rules/Upgrades")
local Sim = require("../src/shared/Rules/FlightSim")
local FR = require("../src/shared/Rules/Flight")
local G = 196.2
local levels = { Engine = 3, Wings = 4, Wheels = 3 }
for _, gain in { 0.5, 0.25 } do
	Flight.PitchLiftGain = gain
	local stats = Rules.stats(Upgrades, levels, Carts.List.Basic)
	-- recorded: leaves the lip at vx 255, vy 103 (276 studs/s, ~22 degrees)
	local r =
		Sim.simulate(FR, Flight, stats, { speed = 276, angle = 22, height = 30, gravity = G, pitch = 1 })
	print(
		string.format(
			"gain %.2f: flight %d total %d air %.1fs",
			gain,
			r.flightDistance,
			r.distance,
			r.airTime
		)
	)
end
print("recorded (gain 0.50): total 2071-2133, air ~10.9s")
