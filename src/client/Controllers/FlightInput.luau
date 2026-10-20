--!strict
-- Controls: SPACE at the top of the ramp = launch; in the air SPACE (or the BOOST button) = rocket,
-- W/S or Up/Down = nose up/down, A/D or Left/Right = steer.
-- SPACE no longer jumps: the jump action is sunk while seated, and the seat is never left by jumping.
-- Only input goes to the server (FlightInput); the server owns the physics and the fuel.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FlightInput = {}

local player = Players.LocalPlayer
local remote = Remotes.get(Remotes.Names.FlightInput)
local launchRemote = Remotes.get(Remotes.Names.LaunchNow)

local rocket = false
local up, down, left, right = false, false, false, false
local sent = { rocket = false, pitch = 0, steer = 0 }

local function push()
	local pitch = (if up then 1 else 0) - (if down then 1 else 0)
	local steer = (if right then 1 else 0) - (if left then 1 else 0)
	if rocket == sent.rocket and pitch == sent.pitch and steer == sent.steer then
		return
	end
	sent = { rocket = rocket, pitch = pitch, steer = steer }
	remote:FireServer(sent)
end

-- Used by the HUD's touch buttons.
function FlightInput.setRocket(on: boolean)
	rocket = on
	push()
end

function FlightInput.setPitch(value: number)
	up, down = value > 0, value < 0
	push()
end

function FlightInput.setSteer(value: number)
	left, right = value < 0, value > 0
	push()
end

local function onKey(input: InputObject, began: boolean)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA then
		if began and player:GetAttribute("Phase") == "Ready" then
			launchRemote:FireServer() -- SPACE at the top sends the cart down the ramp
		end
		rocket = began
	elseif key == Enum.KeyCode.W or key == Enum.KeyCode.Up then
		up = began
	elseif key == Enum.KeyCode.S or key == Enum.KeyCode.Down then
		down = began
	elseif key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
		left = began
	elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
		right = began
	else
		return
	end
	push()
end

function FlightInput.start()
	-- SPACE is the rocket: sink the jump (the InputBegan still arrives, with gameProcessed = true)
	ContextActionService:BindActionAtPriority("CartNoJump", function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.PlayerActions.CharacterJump)

	UserInputService.InputBegan:Connect(function(input)
		onKey(input, true)
	end)
	UserInputService.InputEnded:Connect(function(input)
		onKey(input, false)
	end)
	-- a new run starts with nothing held
	player:GetAttributeChangedSignal("Phase"):Connect(function()
		if player:GetAttribute("Phase") == "Ready" then
			rocket, up, down, left, right = false, false, false, false, false
			push()
		end
	end)
end

return FlightInput
