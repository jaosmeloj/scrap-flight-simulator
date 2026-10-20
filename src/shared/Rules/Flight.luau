--!strict
-- Flight math (pure: numbers in, numbers out). The server turns these accelerations into forces.
local Flight = {}

-- Lift acceleration (studs/s², straight UP): the wings cancel `lift` (0..1) of gravity, at full strength above
-- StallSpeed and fading out below it, so the cart floats (arcade glide: the forward speed is kept, only the fall
-- slows down). `pitch` is -1 (nose down) .. 1 (nose up). Never more than MaxLiftRatio * gravity: it always comes down.
function Flight.liftAccel(config: any, lift: number, speed: number, pitch: number, gravity: number): number
	local mult = 1 + math.clamp(pitch, -1, 1) * config.PitchLiftGain
	local airflow = math.clamp(speed / config.StallSpeed, 0, 1)
	local accel = gravity * math.max(lift, 0) * airflow * mult
	return math.clamp(accel, 0, gravity * config.MaxLiftRatio)
end

-- Drag acceleration (studs/s², against the velocity).
function Flight.dragAccel(config: any, drag: number, speed: number, pitch: number): number
	local mult = 1 + math.abs(math.clamp(pitch, -1, 1)) * config.PitchDrag
	return config.DragK * math.max(drag, 0) * speed * speed * mult
end

-- Forward push from the engine while it still runs (`engineLeft` seconds) + the rocket while held and fuelled.
-- Zero above MaxSpeed.
function Flight.thrustAccel(
	config: any,
	engine: number,
	rocket: number,
	rocketOn: boolean,
	fuel: number,
	speed: number,
	engineLeft: number?
): number
	if speed >= config.MaxSpeed then
		return 0
	end
	local accel = if (engineLeft or math.huge) > 0 then engine else 0
	if rocketOn and fuel > 0 then
		accel += rocket
	end
	return accel
end

-- Pitch after `dt` seconds with input -1/0/1 (held W = 1), as -1..1 of MaxPitch.
function Flight.stepPitch(config: any, pitch: number, input: number, dt: number): number
	local maxRad = math.rad(config.MaxPitchDegrees)
	local rate = config.PitchRate / maxRad -- in units of "full pitch per second"
	local target = math.clamp(input, -1, 1)
	if target == 0 then
		-- let go: ease back to level flight
		local back = rate * dt
		if math.abs(pitch) <= back then
			return 0
		end
		return pitch - back * math.sign(pitch)
	end
	return math.clamp(pitch + target * rate * dt, -1, 1)
end

-- Steering after `dt` seconds with input -1 (A, left) / 0 / 1 (D, right), as -1..1 of MaxYaw.
-- Letting go keeps the heading (like a plane): only holding the other key turns back.
function Flight.stepYaw(config: any, yaw: number, input: number, dt: number): number
	local rate = config.YawRate / math.rad(config.MaxYawDegrees) -- full yaw per second
	return math.clamp(yaw + math.clamp(input, -1, 1) * rate * dt, -1, 1)
end

-- Sideways speed (studs/s, + = right) the cart should have for a yaw of -1..1 at horizontal speed `speed`.
function Flight.sidewaysSpeed(config: any, yaw: number, speed: number): number
	return speed * math.sin(math.clamp(yaw, -1, 1) * math.rad(config.MaxYawDegrees))
end

-- Coins for a flight: distance * CoinsPerStud * (1 + bonus). Never negative.
function Flight.coins(config: any, distance: number, bonus: number?): number
	return math.max(0, math.floor(math.max(distance, 0) * config.CoinsPerStud * (1 + (bonus or 0))))
end

-- Index of the zone at `distance` (zones sorted by Start).
function Flight.zoneAt(zones: { { Start: number } }, distance: number): number
	local index = 1
	for i, zone in zones do
		if distance >= zone.Start then
			index = i
		end
	end
	return index
end

-- Zones reached for the first time on a flight of `distance` (ids not in `visited`), in order.
function Flight.newZones(
	zones: { { Id: string, Start: number } },
	visited: { string },
	distance: number
): { string }
	local found = {}
	for _, zone in zones do
		if distance >= zone.Start and zone.Start > 0 and not table.find(visited, zone.Id) then
			table.insert(found, zone.Id)
		end
	end
	return found
end

-- The cart touched the ground for real (contacts right after the lip don't count): it starts rolling.
function Flight.touchedDown(config: any, airTime: number, grounded: boolean): boolean
	return grounded and airTime >= config.MinFlightSeconds
end

-- The run is over: stopped (slower than StopSpeed for StopSeconds), in the water, rolled too long or flew too long.
-- `rollTime` = seconds since touchdown (0 while still in the air).
function Flight.landed(
	config: any,
	airTime: number,
	rollTime: number,
	inWater: boolean,
	slowFor: number
): boolean
	if airTime >= config.MaxFlightSeconds then
		return true
	end
	if airTime < config.MinFlightSeconds then
		return false
	end
	return inWater or slowFor >= config.StopSeconds or rollTime >= config.MaxRollSeconds
end

-- Ground braking (studs/s², against the forward motion) while rolling. It fades out near the stop so the cart
-- eases to rest instead of rocking back and forth.
function Flight.rollBrake(config: any, forwardSpeed: number, grounded: boolean): number
	if not grounded then
		return 0
	end
	return math.min(config.RollFriction, math.abs(forwardSpeed) * config.RollBrakeGain)
end

-- True when the velocity is fast enough to steer the nose by (otherwise keep the last heading).
function Flight.alignable(config: any, planarSpeed: number): boolean
	return planarSpeed >= config.MinAlignSpeed
end

-- Longest distance physically possible in `seconds` since the launch (the server caps the paid distance with it:
-- the player's computer simulates its own cart).
function Flight.maxDistance(config: any, seconds: number): number
	return config.MaxSpeed * math.max(seconds, 0)
end

return Flight
