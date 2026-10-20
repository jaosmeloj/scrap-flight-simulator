--!strict
-- Offline flight simulation with the same formulas the server uses (Rules/Flight), in the vertical plane of the
-- launch. Used by the tests (and to tune Config/Flight + Config/Upgrades) to check that every upgrade level adds
-- distance you can feel. Pure: numbers in, numbers out. The Rules/Flight module is passed in (the same file is
-- required from Roblox and from Lune, which find modules differently).

local FlightSim = {}

export type Options = {
	speed: number, -- speed leaving the lip (studs/s)
	angle: number, -- lip angle (degrees, up)
	height: number, -- lip height above the landing ground (studs)
	gravity: number,
	rocketHeld: boolean?, -- SPACE held the whole flight
	pitch: number?, -- nose input held the whole flight (-1..1); players learn to hold W (1)
	dt: number?,
}

export type Result = { distance: number, airTime: number, flightDistance: number }

-- `Flight` = Rules/Flight, `stats` = Rules/Upgrades.stats(...). Returns where the cart stops (flight + roll) and the air time.
function FlightSim.simulate(Flight: any, config: any, stats: any, options: Options): Result
	local dt = options.dt or 1 / 60
	local g = options.gravity
	local a = math.rad(options.angle)
	local x, y = 0, options.height
	local vx, vy = options.speed * math.cos(a), options.speed * math.sin(a)
	local fuel = stats.fuel
	local engineLeft = stats.engineTime or 0
	local t = 0
	-- air
	while y > 0 and t < config.MaxFlightSeconds do
		local speed = math.sqrt(vx * vx + vy * vy)
		local dx, dy = vx / math.max(speed, 1e-6), vy / math.max(speed, 1e-6)
		local pitch = options.pitch or 0
		local lift = Flight.liftAccel(config, stats.lift, speed, pitch, g)
		local drag = Flight.dragAccel(config, stats.drag, speed, pitch)
		local rocketOn = options.rocketHeld == true
		local thrust =
			Flight.thrustAccel(config, stats.engine, stats.rocket, rocketOn, fuel, speed, engineLeft)
		engineLeft = math.max(0, engineLeft - dt)
		if rocketOn and fuel > 0 then
			fuel = math.max(0, fuel - dt)
		end
		local ax = -dx * drag + dx * thrust
		local ay = lift - dy * drag + dy * thrust - g
		vx += ax * dt
		vy += ay * dt
		x += vx * dt
		y += vy * dt
		t += dt
	end
	local flightDistance = x
	-- roll: ground braking + air drag, no engine (the server cuts thrust at touchdown)
	local roll = 0
	while vx > config.StopSpeed and roll < config.MaxRollSeconds do
		local brake = Flight.rollBrake(config, vx, true) + Flight.dragAccel(config, stats.drag, vx, 0)
		vx = math.max(0, vx - brake * dt)
		x += vx * dt
		roll += dt
	end
	return { distance = x, airTime = t, flightDistance = flightDistance }
end

return FlightSim
