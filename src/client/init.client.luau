--!strict
local Controllers = script:WaitForChild("Controllers")

-- each controller starts on its own: one error must not stop the others
for _, name in { "FlightInput", "Shop", "Garage", "Hud", "Propellers", "CameraStart" } do
	local ok, err = xpcall(function()
		require(Controllers:WaitForChild(name) :: ModuleScript).start()
	end, debug.traceback)
	if not ok then
		warn("[Client] " .. name .. " failed to start:", err)
	end
end
print("[Client] started")
