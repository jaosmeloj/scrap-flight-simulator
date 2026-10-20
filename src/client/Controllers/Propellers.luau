--!strict
-- Spins every cart's propellers on this screen: the server tags each blade's Motor6D (CartBuilder); here its
-- Transform turns about the cart's Z axis, at a speed set by the owner's phase (Config/CartLooks.PropellerSpin).
-- Purely visual and local: nothing is sent to the server.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CartLooks = require(ReplicatedStorage.Shared.Config.CartLooks)

local Propellers = {}

type Spin = { angle: number, speed: number }

local spins: { [Motor6D]: Spin } = {}

local function targetSpeed(motor: Motor6D): number
	local owner = Players:GetPlayerByUserId(motor:GetAttribute("Owner") or 0)
	local phase = owner and owner:GetAttribute("Phase")
	if phase == "Flight" and owner and owner:GetAttribute("EngineOn") == false then
		phase = "Rolling" -- engine out of fuel: the prop just windmills
	end
	return CartLooks.PropellerSpin[phase or ""] or 0
end

function Propellers.start()
	local function added(instance: Instance)
		if instance:IsA("Motor6D") then
			spins[instance] = { angle = 0, speed = 0 }
		end
	end
	CollectionService:GetInstanceAddedSignal(CartLooks.PropellerTag):Connect(added)
	CollectionService:GetInstanceRemovedSignal(CartLooks.PropellerTag):Connect(function(instance)
		spins[instance :: Motor6D] = nil
	end)
	for _, instance in CollectionService:GetTagged(CartLooks.PropellerTag) do
		added(instance)
	end

	RunService.RenderStepped:Connect(function(dt)
		local ease = math.min(1, CartLooks.PropellerEase * dt)
		for motor, spin in spins do
			if not motor.Parent then
				spins[motor] = nil
				continue
			end
			spin.speed += (targetSpeed(motor) - spin.speed) * ease
			spin.angle = (spin.angle + spin.speed * dt) % (math.pi * 2)
			motor.Transform = CFrame.Angles(0, 0, spin.angle)
		end
	end)
end

return Propellers
