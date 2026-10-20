-- Feel of the upgrades, measured with the flight simulator (same formulas as the server).
local Flight = require("../src/shared/Config/Flight")
local Upgrades = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local Zones = require("../src/shared/Config/Zones")
local UpgradeRules = require("../src/shared/Rules/Upgrades")
local FlightRules = require("../src/shared/Rules/Flight")
local FlightSim = require("../src/shared/Rules/FlightSim")

local G = 196.2
local DROP, RAMP_LENGTH, LIP_ANGLE, LIP_HEIGHT = 94, 250, 24, 26 -- build/ramp.luau

local function fly(levels, rocket)
	local stats = UpgradeRules.stats(Upgrades, levels, Carts.List.Basic)
	local speed = math.sqrt(2 * G * DROP + 2 * (Flight.RampBasePush + stats.push) * RAMP_LENGTH)
	return FlightSim.simulate(FlightRules, Flight, stats, {
		speed = speed,
		angle = LIP_ANGLE,
		height = LIP_HEIGHT,
		gravity = G,
		rocketHeld = rocket,
		pitch = 1, -- players hold W (nose up) to glide
	})
end

return function(check)
	local bare = fly({})
	check("bare cart flies 250-450 studs", bare.distance > 250 and bare.distance < 450)
	check("the roll after touchdown is short", bare.distance - bare.flightDistance < 120)
	for _, key in Upgrades.Order do
		-- the tank only matters with an engine and wings that keep the cart up: measure it on engine 3 + wings 3
		local base = if key == "FuelTank" then { Engine = 3, Wings = 3 } else {}
		local function with(lvl)
			local levels = table.clone(base)
			levels[key] = lvl
			return levels
		end
		local before = fly(base).distance
		local one = fly(with(1), key == "Rocket")
		check(key .. " level 1 adds at least 5%", one.distance > before * 1.05)
		local previous = one.distance
		local growing = true
		for lvl = 2, Upgrades.MaxLevel do
			local d = fly(with(lvl), key == "Rocket").distance
			if d < previous - 1 then
				growing = false
			end
			previous = d
		end
		check(key .. ": every level flies at least as far", growing)
	end
	check("wings 10 glide at least 2.5x longer in the air", fly({ Wings = 10 }).airTime > bare.airTime * 2.5)
	local engine5 = fly({ Engine = 5 }).distance
	local wings5 = fly({ Wings = 5 }).distance
	local both5 = fly({ Engine = 5, Wings = 5 }).distance
	check(
		"engine + wings fly further than each alone added up",
		both5 - bare.distance > (engine5 - bare.distance) + (wings5 - bare.distance)
	)
	local all10 = {}
	for _, key in Upgrades.Order do
		all10[key] = 10
	end
	local maxed = fly(all10, true).distance
	check("a maxed cart reaches the last zone", maxed >= Zones.List[#Zones.List].Start)
	check(
		"nothing flies forever (lands before the time limit)",
		fly(all10, true).airTime < Flight.MaxFlightSeconds - 1
	)
end
