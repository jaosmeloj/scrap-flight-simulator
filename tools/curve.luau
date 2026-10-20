-- lune run tools/curve -> distance with every part at the same level, for each cart (tuning aid)
local Flight = require("../src/shared/Config/Flight")
local Upgrades = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local UpgradeRules = require("../src/shared/Rules/Upgrades")
local FlightRules = require("../src/shared/Rules/Flight")
local Sim = require("../src/shared/Rules/FlightSim")
local ok, o = pcall(require, "./curve_params")
if ok then
	for part, t in o.parts or {} do
		for k, v in t do
			Upgrades.Parts[part][k] = v
		end
	end
	for k, v in o.flight or {} do
		Flight[k] = v
	end
	for id, t in o.carts or {} do
		for k, v in t do
			Carts.List[id][k] = v
		end
	end
end
local G = 196.2
for _, cartId in { "Basic", "Golden" } do
	local row = {}
	for n = 0, 10 do
		local levels = {}
		for _, key in Upgrades.Order do
			levels[key] = n
		end
		local stats = UpgradeRules.stats(Upgrades, levels, Carts.List[cartId])
		local speed = math.sqrt(2 * G * 94 + 2 * (Flight.RampBasePush + stats.push) * 250)
		local r = Sim.simulate(
			FlightRules,
			Flight,
			stats,
			{ speed = speed, angle = 24, height = 26, gravity = G, rocketHeld = true, pitch = 1 }
		)
		table.insert(row, string.format("%d:%d", n, r.distance))
	end
	print(cartId .. "  " .. table.concat(row, " "))
end
