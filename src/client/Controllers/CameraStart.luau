--!strict
-- Puts the camera behind the cart, looking down the ramp, whenever the player is back at the top (Phase "Ready")
-- and again at the launch (Phase "Ramp"). The normal camera keeps working: the player can turn it as usual.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraConfig = require(ReplicatedStorage.Shared.Config.Camera)

local CameraStart = {}

local player = Players.LocalPlayer

local function myCartRoot(): BasePart?
	local carts = workspace:FindFirstChild("Carts")
	if not carts then
		return nil
	end
	for _, cart in carts:GetChildren() do
		if cart:IsA("Model") and cart:GetAttribute("Owner") == player.UserId then
			local root = cart:FindFirstChild("Root")
			if root and root:IsA("BasePart") then
				return root
			end
		end
	end
	return nil
end

local function placeBehind()
	-- the cart is built a moment after the phase changes: wait for it (up to ~2 s)
	local root: BasePart? = nil
	for _ = 1, 20 do
		root = myCartRoot()
		if root then
			break
		end
		task.wait(0.1)
	end
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return
	end
	local at = root.Position
	camera.CFrame = CFrame.lookAt(
		at + Vector3.new(-CameraConfig.Back, CameraConfig.Up, 0),
		at + Vector3.new(CameraConfig.LookAhead, CameraConfig.LookUp, 0)
	)
end

function CameraStart.start()
	player:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = player:GetAttribute("Phase")
		if phase == "Ready" or phase == "Ramp" then
			task.spawn(placeBehind)
		end
	end)
	if player:GetAttribute("Phase") == "Ready" then
		task.spawn(placeBehind)
	end
end

return CameraStart
