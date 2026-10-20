--!strict
-- The run: cart on the ramp -> launch -> flight -> landing -> coins -> back to the ramp.
-- The server owns the cart's physics (network owner = server). Forces:
--   * LinearVelocity in Line mode along the cart's nose: ramp push (base + wheels), engine and rocket. Its target
--     speed is always above the current speed, so it only pushes (MaxForce = mass * accel), never brakes.
--   * VectorForce (world): wing lift (up, perpendicular to the velocity), air drag, and the sideways force that makes
--     the cart follow its nose when the player steers (A/D).
--   * AlignOrientation: the nose follows the velocity, tilted by the player's pitch (W/S).
-- The client only sends input (rocket held, pitch -1/0/1); fuel, distance and coins are computed here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local CartsConfig = require(ReplicatedStorage.Shared.Config.Carts)
local FlightConfig = require(ReplicatedStorage.Shared.Config.Flight)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local ZonesConfig = require(ReplicatedStorage.Shared.Config.Zones)
local RampConfig = require(ReplicatedStorage.Shared.Config.Ramp)
local FlightRules = require(ReplicatedStorage.Shared.Rules.Flight)
local LaneRules = require(ReplicatedStorage.Shared.Rules.Lanes)
local UpgradeRules = require(ReplicatedStorage.Shared.Rules.Upgrades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CartBuilder = require(script.Parent.CartBuilder)
local PlayerService = require(script.Parent.PlayerService)
local State = require(script.Parent.State)

local LaunchService = {}

export type Phase = "Ready" | "Ramp" | "Flight" | "Rolling" | "Landed"

export type Run = {
	player: Player,
	cart: Model,
	root: BasePart,
	seat: Seat,
	rocketFires: { Fire },
	trail: Trail?,
	lane: number,
	phase: Phase,
	stats: UpgradeRules.Stats,
	fuel: number,
	engineLeft: number, -- seconds the engine still runs (counts down in the air)
	pitch: number, -- -1..1 of MaxPitch
	heading: Vector3, -- last direction of travel (XY plane) the nose follows
	pitchInput: number,
	yaw: number, -- -1..1 of MaxYaw (A/D steering; + = right, toward +Z)
	yawInput: number,
	rocket: boolean,
	airTime: number,
	rampTime: number,
	rollTime: number,
	offGroundFor: number, -- while rolling: seconds without ground under the cart (it took off again)
	slowFor: number,
	distance: number,
	linear: LinearVelocity,
	force: VectorForce,
	align: AlignOrientation,
	hudAt: number,
	log: { { [string]: any } }, -- Studio telemetry samples
	logAt: number,
	inputTokens: number,
}

local runs: { [Player]: Run } = {}
local launchFolder: Folder? = nil
local cartsFolder: Folder

local function launchParts(): (BasePart?, BasePart?)
	local folder = launchFolder or workspace:FindFirstChild("Launch") :: Folder?
	launchFolder = folder
	if not folder then
		return nil, nil
	end
	return folder:FindFirstChild("Start") :: BasePart?, folder:FindFirstChild("Lip") :: BasePart?
end

local function setPhase(run: Run, phase: Phase)
	run.phase = phase
	run.player:SetAttribute("Phase", phase)
end

local function takenLanes(): { [number]: boolean }
	local taken = {}
	for _, run in runs do
		taken[run.lane] = true
	end
	return taken
end

local function destroyRun(player: Player)
	local run = runs[player]
	if run then
		runs[player] = nil
		run.cart:Destroy()
	end
end

local function makeConstraints(root: BasePart): (LinearVelocity, VectorForce, AlignOrientation)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = root
	local linear = Instance.new("LinearVelocity")
	linear.Attachment0 = attachment
	linear.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	linear.RelativeTo = Enum.ActuatorRelativeTo.World
	linear.LineDirection = Vector3.xAxis
	linear.MaxForce = 0
	linear.Enabled = false
	linear.Parent = root
	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	force.Enabled = false
	force.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Attachment0 = attachment
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.RigidityEnabled = false
	align.MaxTorque = math.huge
	align.Responsiveness = FlightConfig.AlignResponsiveness
	align.CFrame = CFrame.lookAt(Vector3.zero, Vector3.xAxis)
	align.Enabled = false
	align.Parent = root
	return linear, force, align
end

-- Builds the player's cart at their lane on top of the ramp and sits them in it.
function LaunchService.prepare(player: Player)
	local profile = State.profiles[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local start = launchParts()
	if not profile or not character or not humanoid or not start then
		if not start then
			warn("[Launch] Workspace.Launch.Start is missing: run build/ramp.luau in Studio")
		end
		return
	end
	destroyRun(player)
	local lane = LaneRules.free(takenLanes(), RampConfig.Lanes)
		or (#Players:GetPlayers() % RampConfig.Lanes) + 1
	local cartId = if CartsConfig.List[profile.cart] then profile.cart else CartsConfig.Default
	local built = CartBuilder.build(player, cartId, profile.upgrades, profile.custom)
	local offset = LaneRules.offset(lane, RampConfig.Lanes, RampConfig.LaneSpacing)
	local position = start.Position + Vector3.new(0, start.Size.Y / 2 + built.halfHeight + 0.05, offset)
	built.root.Anchored = true
	built.model:PivotTo(CFrame.lookAt(position, position + Vector3.xAxis))
	built.model.Parent = cartsFolder

	local linear, force, align = makeConstraints(built.root)
	local stats = UpgradeRules.stats(UpgradesConfig, profile.upgrades, CartsConfig.List[cartId])
	local run: Run = {
		player = player,
		cart = built.model,
		root = built.root,
		seat = built.seat,
		rocketFires = built.rocketFires,
		trail = built.trail,
		lane = lane,
		phase = "Ready",
		stats = stats,
		fuel = stats.fuel,
		engineLeft = stats.engineTime,
		pitch = 0,
		heading = Vector3.xAxis,
		pitchInput = 0,
		yaw = 0,
		yawInput = 0,
		rocket = false,
		airTime = 0,
		rampTime = 0,
		rollTime = 0,
		offGroundFor = 0,
		slowFor = 0,
		distance = 0,
		linear = linear,
		force = force,
		align = align,
		hudAt = 0,
		log = {},
		logAt = 0,
		inputTokens = FlightConfig.InputMaxPerSecond,
	}
	runs[player] = run
	setPhase(run, "Ready")
	player:SetAttribute("Fuel", stats.fuel)
	player:SetAttribute("FuelMax", stats.fuel)
	player:SetAttribute("EngineFuel", stats.engineTime)
	player:SetAttribute("EngineFuelMax", stats.engineTime)
	player:SetAttribute("Distance", 0)
	player:SetAttribute("Speed", 0)

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Carts"
		end
	end
	character:PivotTo(built.seat.CFrame * CFrame.new(0, 3, 0))
	built.seat:Sit(humanoid)
end

-- Sends the cart down the ramp.
function LaunchService.launch(player: Player): boolean
	local run = runs[player]
	if not run or run.phase ~= "Ready" then
		return false
	end
	local _, lip = launchParts()
	if not lip then
		return false
	end
	run.root.Anchored = false
	-- the player's own computer simulates their cart (smooth for them); the server still sets every force and
	-- caps the paid distance (Rules/Flight.maxDistance)
	run.root:SetNetworkOwner(player)
	run.linear.Enabled = true
	run.force.Enabled = true
	run.align.Enabled = true
	run.rampTime = 0
	if run.trail then
		run.trail.Enabled = true
	end
	setPhase(run, "Ramp")
	local profile = State.profiles[player]
	if profile then
		profile.launches += 1
	end
	return true
end

function LaunchService.getRun(player: Player): Run?
	return runs[player]
end

local function respawn(player: Player)
	destroyRun(player)
	if player.Parent then
		player:LoadCharacter()
	end
end

-- Studio only: send the flight samples to tools/telemetry_server.py (silently skipped when it isn't running).
local function sendTelemetry(run: Run, distance: number)
	if not RunService:IsStudio() or #run.log == 0 then
		return
	end
	local profile = State.profiles[run.player]
	local body = {
		player = run.player.Name,
		levels = if profile then profile.upgrades else {},
		cart = if profile then profile.cart else "",
		stats = run.stats,
		distance = distance,
		samples = run.log,
	}
	task.spawn(function()
		pcall(function()
			HttpService:PostAsync(FlightConfig.TelemetryUrl, HttpService:JSONEncode(body))
		end)
	end)
end

local function finish(run: Run, lipX: number)
	local player = run.player
	setPhase(run, "Landed")
	run.linear.Enabled = false
	run.force.Enabled = false
	run.align.Enabled = false
	for _, fire in run.rocketFires do
		fire.Enabled = false
	end
	if run.trail then
		run.trail.Enabled = false
	end
	run.root.AssemblyLinearVelocity = Vector3.zero
	run.root.AssemblyAngularVelocity = Vector3.zero
	run.root.Anchored = true
	local elapsed = run.rampTime + run.airTime
	local distance =
		math.min(math.max(0, run.root.Position.X - lipX), FlightRules.maxDistance(FlightConfig, elapsed))
	run.distance = distance
	player:SetAttribute("Distance", math.floor(distance))
	player:SetAttribute("Speed", 0)

	local profile = State.profiles[player]
	sendTelemetry(run, distance)
	if profile then
		local cart = CartsConfig.List[profile.cart] or CartsConfig.List[CartsConfig.Default]
		local coins = FlightRules.coins(FlightConfig, distance, cart.CoinBonus or 0)
		local record = distance > profile.best
		if record then
			profile.best = distance
		end
		local zoneNames = {}
		local zoneReward = 0
		for _, id in FlightRules.newZones(ZonesConfig.List, profile.zones, distance) do
			table.insert(profile.zones, id)
			for _, zone in ZonesConfig.List do
				if zone.Id == id then
					zoneReward += zone.Reward
					table.insert(zoneNames, zone.Name)
				end
			end
		end
		PlayerService.addCoins(player, coins + zoneReward)
		PlayerService.sync(player)
		Remotes.get(Remotes.Names.FlightResult):FireClient(player, {
			distance = math.floor(distance),
			coins = coins,
			record = record,
			zones = zoneNames,
			zoneReward = zoneReward,
		})
	end

	local cart = run.cart
	task.delay(FlightConfig.ReturnSeconds, function()
		local current = runs[player]
		if current and current.cart == cart then
			respawn(player)
		end
	end)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function step(dt: number)
	local _, lip = launchParts()
	if not lip then
		return
	end
	local lipX = lip.Position.X
	local gravity = workspace.Gravity
	local exclude: { Instance } = { cartsFolder }
	if launchFolder then
		local ramp = launchFolder:FindFirstChild("Ramp")
		if ramp then
			table.insert(exclude, ramp)
		end
	end
	for player, run in runs do
		if run.phase ~= "Ramp" and run.phase ~= "Flight" and run.phase ~= "Rolling" then
			continue
		end
		local ok, err = pcall(function()
			local root = run.root
			local v = root.AssemblyLinearVelocity
			local mass = root.AssemblyMass
			local speed = v.Magnitude
			local planar = Vector3.new(v.X, v.Y, 0)
			if FlightRules.alignable(FlightConfig, planar.Magnitude) then
				local heading = planar.Unit
				if heading.X < 0.05 then -- never point the nose backwards
					heading = Vector3.new(0.05, heading.Y, 0).Unit
				end
				run.heading = heading
			end
			local dir = run.heading
			-- sideways: the Z speed follows the steering (0 on the ramp: carts stay in their lanes)
			local horizontal = Vector2.new(v.X, v.Z).Magnitude
			local wantZ = if run.phase == "Ramp"
				then 0
				else FlightRules.sidewaysSpeed(FlightConfig, run.yaw, horizontal)
			local sideways = Vector3.new(0, 0, (wantZ - v.Z) * mass * FlightConfig.LateralDamping)

			if run.phase == "Ramp" then
				run.rampTime += dt
				run.align.CFrame = CFrame.lookAt(Vector3.zero, dir)
				run.linear.LineDirection = dir
				run.linear.LineVelocity = speed + FlightConfig.RampPushBoost
				run.linear.MaxForce = mass * (FlightConfig.RampBasePush + run.stats.push)
				run.force.Force = sideways
				if root.Position.X > lipX then
					run.airTime = 0
					setPhase(run, "Flight")
				elseif run.rampTime > FlightConfig.MaxFlightSeconds then
					finish(run, lipX) -- stuck on the ramp
				end
			else
				local rolling = run.phase == "Rolling"
				run.airTime += dt
				if rolling then
					run.pitchInput = 0
				end
				run.pitch = FlightRules.stepPitch(FlightConfig, run.pitch, run.pitchInput, dt)
				run.yaw = FlightRules.stepYaw(FlightConfig, run.yaw, run.yawInput, dt)
				local pitchRad = run.pitch * math.rad(FlightConfig.MaxPitchDegrees)
				local yawRad = run.yaw * math.rad(FlightConfig.MaxYawDegrees)
				local pitched = CFrame.fromAxisAngle(Vector3.zAxis, pitchRad):VectorToWorldSpace(dir)
				-- the cart's look: in a dive the nose follows only part of the angle (it reads as gliding)
				local diveAngle = math.atan2(dir.Y, dir.X)
				local lookDir = Vector3.new(
					math.cos(diveAngle * FlightConfig.GlideNoseShare),
					math.sin(diveAngle * FlightConfig.GlideNoseShare),
					0
				)
				local lookPitched = CFrame.fromAxisAngle(Vector3.zAxis, pitchRad):VectorToWorldSpace(lookDir)
				-- turning about -Y swings +X toward +Z (right)
				local nose = CFrame.fromAxisAngle(Vector3.yAxis, -yawRad):VectorToWorldSpace(pitched)
				local bank = math.rad(FlightConfig.BankDegrees) * run.yawInput
				local look = CFrame.fromAxisAngle(Vector3.yAxis, -yawRad):VectorToWorldSpace(lookPitched)
				run.align.CFrame = CFrame.lookAt(Vector3.zero, look) * CFrame.Angles(0, 0, -bank)

				-- engine and rocket keep pushing on the ground too, while there is fuel
				local burning = run.rocket and run.fuel > 0
				local thrust = FlightRules.thrustAccel(
					FlightConfig,
					run.stats.engine,
					run.stats.rocket,
					run.rocket,
					run.fuel,
					speed,
					run.engineLeft
				)
				run.engineLeft = math.max(0, run.engineLeft - dt)
				player:SetAttribute("EngineOn", run.engineLeft > 0 and run.stats.engine > 0)
				if rolling and thrust <= 0 then
					run.rollTime += dt -- the roll timer only runs once nothing pushes any more
				end
				if burning then
					run.fuel = math.max(0, run.fuel - dt)
				end
				for _, fire in run.rocketFires do
					fire.Enabled = burning and run.stats.rocket > 0
				end
				run.linear.Enabled = thrust > 0
				run.linear.LineDirection = nose
				run.linear.LineVelocity = math.min(speed + FlightConfig.EngineHeadroom, FlightConfig.MaxSpeed)
				run.linear.MaxForce = mass * thrust

				local airSpeed = planar.Magnitude
				local lift = FlightRules.liftAccel(FlightConfig, run.stats.lift, airSpeed, run.pitch, gravity)
				local drag = FlightRules.dragAccel(FlightConfig, run.stats.drag, speed, run.pitch)
				local liftDir = Vector3.yAxis -- arcade glide: the wings cancel part of gravity
				local against = if speed > 0.1 then -v.Unit else Vector3.zero

				run.distance = math.max(0, root.Position.X - lipX)
				if speed < FlightConfig.StopSpeed then
					run.slowFor += dt
				else
					run.slowFor = 0
				end
				local character = player.Character
				local filter = table.clone(exclude)
				if character then
					table.insert(filter, character)
				end
				rayParams.FilterDescendantsInstances = filter
				local grounded = workspace:Raycast(
					root.Position,
					Vector3.new(0, -FlightConfig.GroundProbe, 0),
					rayParams
				) ~= nil
				local inWater = root.Position.Y < FlightConfig.WaterLevel
				-- ground braking while rolling and nothing pushes (the Root slides without friction)
				local brake = if rolling and thrust <= 0
					then FlightRules.rollBrake(FlightConfig, v.X, grounded)
					else 0
				local brakeForce = Vector3.new(-math.sign(v.X) * brake, 0, 0)
				run.force.Force = (liftDir * lift + against * drag + brakeForce) * mass + sideways
				if RunService:IsStudio() and os.clock() - run.logAt >= 1 / FlightConfig.TelemetryHz then
					run.logAt = os.clock()
					table.insert(run.log, {
						t = math.floor(run.airTime * 100) / 100,
						phase = run.phase,
						x = math.floor(run.distance),
						y = math.floor(root.Position.Y * 10) / 10,
						vx = math.floor(v.X),
						vy = math.floor(v.Y),
						vz = math.floor(v.Z),
						lift = math.floor(lift),
						drag = math.floor(drag),
						thrust = math.floor(thrust),
						mass = math.floor(mass * 10) / 10,
						forceY = math.floor(run.force.Force.Y),
						gravityForce = math.floor(mass * gravity),
						pitch = math.floor(run.pitch * 100) / 100,
						owner = tostring(root:GetNetworkOwner()),
					})
				end
				if not rolling and FlightRules.touchedDown(FlightConfig, run.airTime, grounded) then
					setPhase(run, "Rolling")
					run.offGroundFor = 0
				elseif rolling then
					-- the engine (or a bump) lifted it off again: back to flying
					run.offGroundFor = if grounded then 0 else run.offGroundFor + dt
					if run.offGroundFor >= FlightConfig.RetakeoffSeconds then
						setPhase(run, "Flight")
						run.rollTime = 0
					end
				end
				if FlightRules.landed(FlightConfig, run.airTime, run.rollTime, inWater, run.slowFor) then
					finish(run, lipX)
					return
				end
			end

			-- HUD
			local now = os.clock()
			if now - run.hudAt >= 1 / FlightConfig.HudHz then
				run.hudAt = now
				player:SetAttribute("Speed", math.floor(speed))
				player:SetAttribute("Distance", math.floor(run.distance))
				player:SetAttribute("Fuel", math.floor(run.fuel * 10) / 10)
				player:SetAttribute("EngineFuel", math.floor(run.engineLeft * 10) / 10)
			end
		end)
		if not ok then
			warn("[Launch] step failed for", player.Name, err)
		end
	end
end

local function onInput(player: Player, payload: any)
	local run = runs[player]
	if not run or typeof(payload) ~= "table" then
		return
	end
	if run.inputTokens <= 0 then
		return -- rate limit
	end
	run.inputTokens -= 1
	if typeof(payload.rocket) == "boolean" then
		run.rocket = payload.rocket
	end
	if typeof(payload.pitch) == "number" and payload.pitch == payload.pitch then
		run.pitchInput = math.clamp(math.round(payload.pitch), -1, 1)
	end
	if typeof(payload.steer) == "number" and payload.steer == payload.steer then
		run.yawInput = math.clamp(math.round(payload.steer), -1, 1)
	end
end

local function characterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or not State.profiles[player] then
		return
	end
	-- wait until the character is in the world
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	task.wait(0.2)
	if player.Character ~= character then
		return
	end
	LaunchService.prepare(player)
	humanoid.Died:Connect(function()
		local run = runs[player]
		if run and run.cart then
			task.delay(Players.RespawnTime, function()
				if runs[player] == run then
					destroyRun(player)
				end
			end)
		end
	end)
	-- someone who leaves the seat before landing goes straight back to the ramp
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		local run = runs[player]
		if run and humanoid.SeatPart == nil and (run.phase == "Ready" or run.phase == "Ramp") then
			task.defer(function()
				if runs[player] == run and run.phase == "Ready" and humanoid.Parent then
					run.seat:Sit(humanoid)
				end
			end)
		end
	end)
end

-- Rebuilds the cart of a player waiting at the top (after buying an upgrade or a cart).
function LaunchService.refresh(player: Player)
	local run = runs[player]
	if run and run.phase == "Ready" then
		LaunchService.prepare(player)
	end
end

function LaunchService.start()
	cartsFolder = Instance.new("Folder")
	cartsFolder.Name = "Carts"
	cartsFolder.Parent = workspace

	Remotes.get(Remotes.Names.FlightInput).OnServerEvent:Connect(onInput)
	Remotes.get(Remotes.Names.LaunchNow).OnServerEvent:Connect(function(player: Player)
		LaunchService.launch(player)
	end)
	Remotes.get(Remotes.Names.ResetCart).OnServerEvent:Connect(function(player: Player)
		local session = State.sessions[player]
		local run = runs[player]
		if not session or not run or run.phase == "Ready" then
			return
		end
		local now = os.clock()
		if now - session.lastReset < FlightConfig.ResetCooldownSeconds then
			return
		end
		session.lastReset = now
		if run.phase ~= "Landed" then
			local _, lip = launchParts()
			if lip and (run.phase == "Flight" or run.phase == "Rolling") then
				finish(run, lip.Position.X) -- pays what was flown so far, then returns
				return
			end
		end
		respawn(player)
	end)

	PlayerService.onReady(function(player: Player)
		player.CharacterAdded:Connect(function(character)
			characterAdded(player, character)
		end)
		if player.Character then
			task.spawn(characterAdded, player, player.Character)
		end
	end)
	Players.PlayerRemoving:Connect(destroyRun)

	-- refill the input budget once per second
	task.spawn(function()
		while true do
			task.wait(1)
			for _, run in runs do
				run.inputTokens = FlightConfig.InputMaxPerSecond
			end
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return LaunchService
