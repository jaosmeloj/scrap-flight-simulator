--!strict
-- Zones along the flight path (distance from the ramp lip). Reaching a zone for the first time pays Reward.
local Zones = {
	List = {
		{ Id = "Town", Name = "Town", Start = 0, Reward = 0 },
		{ Id = "Farm", Name = "Farmland", Start = 500, Reward = 150 },
		{ Id = "Desert", Name = "Desert", Start = 1500, Reward = 800 },
		{ Id = "Sea", Name = "Sea", Start = 4000, Reward = 3000 },
		{ Id = "Clouds", Name = "Cloud Kingdom", Start = 8500, Reward = 10000 },
	},
}

return Zones
