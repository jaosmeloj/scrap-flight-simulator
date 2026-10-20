local Lanes = require("../src/shared/Rules/Lanes")

return function(check)
	check("first player gets the middle lane", Lanes.free({}, 7) == 4)
	check("next players alternate outwards", Lanes.free({ [4] = true }, 7) == 3)
	check("then the other side", Lanes.free({ [4] = true, [3] = true }, 7) == 5)
	local order = Lanes.order(7)
	check("every lane once", #order == 7 and order[6] == 1 and order[7] == 7)
	check("middle lane is centred", Lanes.offset(4, 7, 10) == 0)
	check("outer lanes", Lanes.offset(1, 7, 10) == -30 and Lanes.offset(7, 7, 10) == 30)
	check("full ramp has no lane", Lanes.free({ true, true }, 2) == nil)
end
