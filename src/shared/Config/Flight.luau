--!strict
-- Flight physics and rewards. Speeds in studs/s, accelerations in studs/s² (Roblox gravity is 196.2).
-- The launch axis is world +X: distance = X of the cart minus X of the ramp lip (Workspace.Launch.Lip).
local Flight = {
	-- ramp
	RampBasePush = 40, -- push every cart gets down the ramp (wheels add Config/Upgrades.Wheels.PushPerLevel)
	RampPushBoost = 60, -- the ramp push always aims this much above the current speed (pure push, never brakes)

	-- air
	-- glide: the wings cancel a share of gravity = lift stat (0.14 at wing level 1 .. 0.9 at 10), at full strength
	-- above StallSpeed and fading to nothing as the cart slows to a stop; never more than MaxLiftRatio * gravity
	-- (wings alone never climb: they slow the fall into a long glide)
	StallSpeed = 90,
	MaxLiftRatio = 0.92,
	GlideNoseShare = 0.45, -- the nose follows only this share of the dive angle (looks like gliding, not diving)
	DragK = 0.00025, -- drag accel = DragK * cart drag * speed²
	LateralDamping = 4, -- how fast the sideways speed follows the nose (on the ramp: keeps carts in their lanes)
	MaxSpeed = 600, -- engine and rocket stop pushing above this
	EngineHeadroom = 100, -- engine/rocket aim this much above the current speed

	-- pitch (W/S): nose up = more lift and more drag
	MaxPitchDegrees = 25,
	PitchRate = 1.6, -- radians/s the nose moves while W/S is held
	PitchLiftGain = 0.25, -- at full nose up lift is x1.25 (x0.75 at full nose down)
	PitchDrag = 0.6, -- at full pitch drag is x1.6

	-- steering (A/D): the nose turns left/right up to MaxYawDegrees (it stays turned when you let go); the cart's
	-- sideways speed follows the nose, so turning costs forward distance
	MaxYawDegrees = 35,
	YawRate = 0.9, -- radians/s the nose turns while A/D is held
	BankDegrees = 18, -- the cart leans into the turn while A/D is held

	-- orientation
	AlignResponsiveness = 25,
	MinAlignSpeed = 8, -- slower than this the nose keeps its last heading (a tiny velocity is just noise)

	-- landing
	MinFlightSeconds = 0.6, -- ignore ground contacts right after the lip
	GroundProbe = 4, -- studs below the cart centre that count as touching the ground
	-- after touching down the cart rolls on (no engine, no rocket) and the distance counts where it stops
	-- braking while the wheels touch the ground = min(RollFriction, speed * RollBrakeGain): the cart rolls about
	-- speed / gain studs after touchdown (~80 at 200 studs/s) and eases to rest (no jerk at the end)
	RollFriction = 400,
	RetakeoffSeconds = 0.35, -- rolling with no ground under the cart this long = flying again
	RollBrakeGain = 2.5,
	MaxRollSeconds = 10,
	StopSpeed = 4, -- slower than this for StopSeconds = stopped
	StopSeconds = 1,
	WaterLevel = -2, -- Y below which the cart is in the water (set by the map phase)
	MaxFlightSeconds = 90,
	ReturnSeconds = 3, -- back to the ramp this long after landing

	-- rewards
	CoinsPerStud = 0.2,

	-- input from the client
	InputMaxPerSecond = 30,
	ResetCooldownSeconds = 2,

	-- HUD values (player attributes) refresh rate
	HudHz = 10,

	-- Studio only: every flight is sent to tools/telemetry_server.py (needs Allow HTTP Requests) to tune the feel
	TelemetryUrl = "http://127.0.0.1:8770/flight",
	TelemetryHz = 10,
}

return Flight
