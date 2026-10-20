local Profile = require("../src/shared/Rules/Profile")

return function(check)
	check("fresh lock of another server blocks", Profile.lockedByOther({ id = "B", at = 100 }, "A", 150, 180))
	check("stale lock does not block", not Profile.lockedByOther({ id = "B", at = 100 }, "A", 400, 180))
	check("own lock does not block", not Profile.lockedByOther({ id = "A", at = 100 }, "A", 150, 180))
	check("broken lock does not block", not Profile.lockedByOther("x", "A", 150, 180))
	check("owns its lock", Profile.ownsLock({ id = "A", at = 1 }, "A"))
	check("does not own a freed lock", not Profile.ownsLock(nil, "A"))

	local default = { coins = 0, upgrades = { Engine = 0, Wings = 0 }, owned = { "Basic" } }
	local merged = Profile.merge(
		default,
		{ coins = 50, upgrades = { Engine = 3 }, owned = { "Basic", "Market" }, extra = 7 }
	)
	check("saved coins win", merged.coins == 50)
	check(
		"saved level wins, missing level keeps default",
		merged.upgrades.Engine == 3 and merged.upgrades.Wings == 0
	)
	check("saved list replaces the default list", #merged.owned == 2)
	check("unknown fields are kept", merged.extra == 7)
	check("wrong type is ignored", Profile.merge(default, { coins = "lots" }).coins == 0)
	check("default is not touched", default.upgrades.Engine == 0)
	check("no save = default", Profile.merge(default, nil).coins == 0)

	local copy = Profile.deepCopy(default)
	copy.upgrades.Engine = 9
	check("deep copy does not share tables", default.upgrades.Engine == 0)
end
