-- lune run tools/glide -> wings only, every level: flight distance, total, air time
local Flight = require("../src/shared/Config/Flight")
local Upgrades = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local Rules = require("../src/shared/Rules/Upgrades")
local Sim = require("../src/shared/Rules/FlightSim")
local FR = require("../src/shared/Rules/Flight")
local G = 196.2
for lvl = 0, 10 do
	local stats = Rules.stats(Upgrades, { Wings = lvl }, Carts.List.Basic)
	local r = Sim.simulate(FR, Flight, stats, {
		speed = math.sqrt(2 * G * 94 + 2 * Flight.RampBasePush * 250),
		angle = 24,
		height = 26,
		gravity = G,
	})
	print(
		string.format(
			"wings %2d: flight %4d total %4d air %.1fs",
			lvl,
			r.flightDistance,
			r.distance,
			r.airTime
		)
	)
end
