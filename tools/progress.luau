-- lune run tools/progress  -> how many flights / minutes a player needs to reach each milestone
-- Policy: after every flight buy the cheapest affordable upgrade (repeat), and the next cart when it is the
-- cheapest thing to buy. Same formulas as the game (Rules/FlightSim + Rules/Upgrades + Config).
local Flight = require("../src/shared/Config/Flight")
local Upgrades = require("../src/shared/Config/Upgrades")
local Carts = require("../src/shared/Config/Carts")
local Zones = require("../src/shared/Config/Zones")
local UpgradeRules = require("../src/shared/Rules/Upgrades")
local FlightRules = require("../src/shared/Rules/Flight")
local Sim = require("../src/shared/Rules/FlightSim")
local G = 196.2
local ok, overrides = pcall(require, "./progress_params")
if ok then
	for k, v in overrides.upgrades or {} do
		Upgrades[k] = v
	end
	for part, t in overrides.parts or {} do
		for k, v in t do
			Upgrades.Parts[part][k] = v
		end
	end
	for id, price in overrides.carts or {} do
		Carts.List[id].Price = price
	end
	for i, reward in overrides.zones or {} do
		Zones.List[i].Reward = reward
	end
	for k, v in overrides.flight or {} do
		Flight[k] = v
	end
end
local OVERHEAD = 9 -- seconds per run besides the air time: ramp ~3, return 3, clicking ~3

local levels = {}
for _, key in Upgrades.Order do
	levels[key] = 0
end
local cartIndex = 1
local coins, flights, seconds = 0, 0, 0
local visited = {}
local marks = {}
local function mark(name)
	if not marks[name] then
		marks[name] = true
		print(
			string.format(
				"%-22s flight %4d  %6.1f min  (best flight now %d studs)",
				name,
				flights,
				seconds / 60,
				_G.lastDistance or 0
			)
		)
	end
end
local function allAt(n)
	for _, key in Upgrades.Order do
		if levels[key] < n then
			return false
		end
	end
	return true
end
while flights < 3000 do
	local cart = Carts.List[Carts.Order[cartIndex]]
	local stats = UpgradeRules.stats(Upgrades, levels, cart)
	local speed = math.sqrt(2 * G * 94 + 2 * (Flight.RampBasePush + stats.push) * 250)
	local r = Sim.simulate(
		FlightRules,
		Flight,
		stats,
		{ speed = speed, angle = 24, height = 26, gravity = G, rocketHeld = true, pitch = 1 }
	)
	_G.lastDistance = math.floor(r.distance)
	flights += 1
	seconds += r.airTime + OVERHEAD + (r.distance - r.flightDistance) / 60
	coins += FlightRules.coins(Flight, r.distance, cart.CoinBonus or 0)
	for _, id in FlightRules.newZones(Zones.List, visited, r.distance) do
		table.insert(visited, id)
		for _, z in Zones.List do
			if z.Id == id then
				coins += z.Reward
				mark("zone " .. z.Name)
			end
		end
	end
	while true do
		local bestKey, bestCost = nil, math.huge
		for _, key in Upgrades.Order do
			local c = UpgradeRules.cost(Upgrades, key, levels[key])
			if c and c < bestCost then
				bestKey, bestCost = key, c
			end
		end
		local nextCart = Carts.Order[cartIndex + 1]
		local cartCost = nextCart and Carts.List[nextCart].Price or math.huge
		if cartCost <= bestCost and coins >= cartCost then
			coins -= cartCost
			cartIndex += 1
			mark("cart " .. nextCart)
		elseif bestKey and coins >= bestCost then
			coins -= bestCost
			levels[bestKey] += 1
			if levels[bestKey] == 1 then
				mark("first " .. bestKey)
			end
		else
			break
		end
	end
	if allAt(3) then
		mark("all level 3")
	end
	if allAt(5) then
		mark("all level 5")
	end
	if allAt(8) then
		mark("all level 8")
	end
	if allAt(10) then
		mark("all level 10")
	end
	if allAt(10) and cartIndex == #Carts.Order then
		mark("everything")
		break
	end
end
