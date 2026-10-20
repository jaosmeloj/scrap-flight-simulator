--!strict
-- Lanes at the top of the ramp (pure).
local Lanes = {}

-- Lanes from the middle of the ramp outwards: 7 lanes -> 4, 3, 5, 2, 6, 1, 7.
function Lanes.order(lanes: number): { number }
	local centre = math.floor((lanes + 1) / 2)
	local order = { centre }
	for step = 1, lanes do
		for _, lane in { centre - step, centre + step } do
			if lane >= 1 and lane <= lanes then
				table.insert(order, lane)
			end
		end
	end
	return order
end

-- Lane (1..lanes) for a player: the free one closest to the middle, nil when full.
function Lanes.free(taken: { [number]: boolean }, lanes: number): number?
	for _, lane in Lanes.order(lanes) do
		if not taken[lane] then
			return lane
		end
	end
	return nil
end

-- Z offset of a lane, centred on the ramp.
function Lanes.offset(lane: number, lanes: number, spacing: number): number
	return (lane - (lanes + 1) / 2) * spacing
end

return Lanes
