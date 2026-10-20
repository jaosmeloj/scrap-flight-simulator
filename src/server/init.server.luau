--!strict
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.init()

-- carts (and their riders) never collide with each other: everyone shares the ramp in lanes
PhysicsService:RegisterCollisionGroup("Carts")
PhysicsService:CollisionGroupSetCollidable("Carts", "Carts", false)

local Services = script:WaitForChild("Services")
-- each system starts on its own: one error must not stop the others
for _, name in { "DataService", "PlayerService", "LaunchService", "ShopService", "CustomizeService" } do
	local ok, err = xpcall(function()
		require(Services:WaitForChild(name) :: ModuleScript).start()
	end, debug.traceback)
	if not ok then
		warn("[Server] " .. name .. " failed to start:", err)
	end
end
print("[Server] started")
