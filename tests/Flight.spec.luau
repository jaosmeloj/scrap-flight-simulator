local Config = require("../src/shared/Config/Flight")
local Zones = require("../src/shared/Config/Zones")
local Flight = require("../src/shared/Rules/Flight")

local G = 196.2

local function near(a, b, eps)
	return math.abs(a - b) < (eps or 1e-6)
end

return function(check)
	local lift50 = G * 0.1 * (50 / Config.StallSpeed)
	check("below stall speed lift fades", near(Flight.liftAccel(Config, 0.1, 50, 0, G), lift50))
	check(
		"above stall speed lift = share of gravity",
		near(Flight.liftAccel(Config, 0.5, 300, 0, G), G * 0.5)
	)
	check(
		"nose up adds lift",
		near(Flight.liftAccel(Config, 0.1, 50, 1, G), lift50 * (1 + Config.PitchLiftGain))
	)
	check(
		"nose down removes lift",
		near(Flight.liftAccel(Config, 0.1, 50, -1, G), lift50 * (1 - Config.PitchLiftGain))
	)
	check(
		"lift is capped at MaxLiftRatio * g",
		near(Flight.liftAccel(Config, 1, 400, 1, G), G * Config.MaxLiftRatio)
	)
	check("no lift standing still", Flight.liftAccel(Config, 1, 0, 0, G) == 0)

	local drag100 = Config.DragK * 100 * 100
	check("drag grows with speed²", near(Flight.dragAccel(Config, 1, 100, 0), drag100))
	check("pitch adds drag", near(Flight.dragAccel(Config, 1, 100, -1), drag100 * (1 + Config.PitchDrag)))
	check("lighter cart drags less", near(Flight.dragAccel(Config, 0.5, 100, 0), drag100 / 2))

	check("engine only without SPACE", Flight.thrustAccel(Config, 60, 200, false, 3, 100) == 60)
	check("rocket adds while held with fuel", Flight.thrustAccel(Config, 60, 200, true, 3, 100) == 260)
	check("no rocket without fuel", Flight.thrustAccel(Config, 60, 200, true, 0, 100) == 60)
	check("no push above max speed", Flight.thrustAccel(Config, 60, 200, true, 3, Config.MaxSpeed) == 0)
	check("engine stops when its time is up", Flight.thrustAccel(Config, 60, 200, false, 3, 100, 0) == 0)
	check(
		"rocket still works after the engine stops",
		Flight.thrustAccel(Config, 60, 200, true, 3, 100, 0) == 200
	)

	check("W raises the nose", Flight.stepPitch(Config, 0, 1, 0.05) > 0)
	check("pitch is clamped to 1", Flight.stepPitch(Config, 0.99, 1, 1) == 1)
	check("letting go eases back to level", Flight.stepPitch(Config, 0.01, 0, 0.1) == 0)
	check("letting go from nose down rises", Flight.stepPitch(Config, -0.9, 0, 0.05) > -0.9)

	check("D turns right", Flight.stepYaw(Config, 0, 1, 0.1) > 0)
	check("A turns left", Flight.stepYaw(Config, 0, -1, 0.1) < 0)
	check("letting go keeps the heading", Flight.stepYaw(Config, 0.4, 0, 0.5) == 0.4)
	check("turning is capped", Flight.stepYaw(Config, 0.99, 1, 2) == 1)
	check("no turn = no sideways speed", Flight.sidewaysSpeed(Config, 0, 200) == 0)
	check("inside the field the steering wins", Flight.keepInField(Config, 100, 55) == 55)
	check(
		"past the right edge it pushes back left",
		Flight.keepInField(Config, Config.FieldHalfWidth + 1, 55) == -Config.EdgePushSpeed
	)
	check(
		"past the left edge it pushes back right",
		Flight.keepInField(Config, -Config.FieldHalfWidth - 1, -55) == Config.EdgePushSpeed
	)
	check(
		"full right = speed * sin(MaxYaw)",
		near(Flight.sidewaysSpeed(Config, 1, 200), 200 * math.sin(math.rad(Config.MaxYawDegrees)))
	)
	check("coins = distance * 0.2", Flight.coins(Config, 150, 0) == 30)
	check("bonus multiplies", Flight.coins(Config, 150, 0.5) == 45)
	check("negative distance pays 0", Flight.coins(Config, -20, 0) == 0)

	check("zone at 0 is Town", Flight.zoneAt(Zones.List, 0) == 1)
	check("zone at 650 is Farm", Flight.zoneAt(Zones.List, 650) == 2)
	check("zone past the last start is Clouds", Flight.zoneAt(Zones.List, Zones.List[5].Start + 1) == 5)
	local new = Flight.newZones(Zones.List, { "Farm" }, 2000)
	check("new zones skip visited and Town", #new == 1 and new[1] == "Desert")

	check("contact right after the lip does not count", not Flight.touchedDown(Config, 0.2, true))
	check("ground contact starts rolling", Flight.touchedDown(Config, 2, true))
	check("in the air is not a touchdown", not Flight.touchedDown(Config, 2, false))
	check("rolling on is not the end", not Flight.landed(Config, 2, 1, false, 0))
	check("water ends the run", Flight.landed(Config, 2, 0, true, 0))
	check("stopping ends the run", Flight.landed(Config, 2, 3, false, 1.2))
	check("still flying", not Flight.landed(Config, 2, 0, false, 0.3))
	check("rolling too long ends", Flight.landed(Config, 5, Config.MaxRollSeconds, false, 0))
	check("time limit ends", Flight.landed(Config, Config.MaxFlightSeconds, 0, false, 0))
	check(
		"brakes while rolling",
		Flight.rollBrake(Config, 80, true) == math.min(Config.RollFriction, 80 * Config.RollBrakeGain)
	)
	check("brake is capped", Flight.rollBrake(Config, 10000, true) == Config.RollFriction)
	check("no brake in the air", Flight.rollBrake(Config, 80, false) == 0)
	check("brake fades near the stop", Flight.rollBrake(Config, 2, true) == 2 * Config.RollBrakeGain)
	check("no brake when stopped", Flight.rollBrake(Config, 0, true) == 0)
	check("slow velocity does not steer the nose", not Flight.alignable(Config, 3))
	check("fast velocity steers the nose", Flight.alignable(Config, 40))
	check("distance cap = max speed * time", Flight.maxDistance(Config, 2) == Config.MaxSpeed * 2)
end
