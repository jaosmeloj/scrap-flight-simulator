local Config = require("../src/shared/Config/Customize")
local Upgrades = require("../src/shared/Config/Upgrades")
local Customize = require("../src/shared/Rules/Customize")

return function(check)
	local levels = { Engine = 6, Wings = 3, Wheels = 0 }
	local engines = Customize.unlockedModels(Upgrades, "Engine", levels)
	check("engine 6 unlocks the first 3 engines", #engines == 3 and engines[3] == "Engine3")
	check("no rocket level = no rocket models", #Customize.unlockedModels(Upgrades, "Rocket", levels) == 0)
	check(
		"wheels 0 still have the casters",
		Customize.unlockedModels(Upgrades, "Wheels", levels)[1] == "Wheels0"
	)
	check("the tail unlocks with the wings", #Customize.unlockedModels(Upgrades, "Tail", levels) == 2)

	check("no choice = newest unlocked", Customize.modelFor(Upgrades, "Engine", levels, nil) == "Engine3")
	check(
		"a chosen older model is kept",
		Customize.modelFor(Upgrades, "Engine", levels, "Engine1") == "Engine1"
	)
	check(
		"a locked choice falls back to the newest",
		Customize.modelFor(Upgrades, "Engine", levels, "Engine5") == "Engine3"
	)
	check(
		"a choice from another slot is ignored",
		Customize.modelFor(Upgrades, "Engine", levels, "Wings1") == "Engine3"
	)
	check(
		"nothing to show without the part",
		Customize.modelFor(Upgrades, "Rocket", levels, "Rocket1") == nil
	)

	check(
		"every kit model in the slots has a name",
		(function()
			for _, slot in Config.ModelSlots do
				for _, tier in Upgrades.Visuals[slot] do
					if not Config.ModelNames[tier.Model] then
						return false
					end
				end
			end
			return true
		end)()
	)

	local fire = Customize.find(Config.Trails, "Fire")
	check("find by id", fire ~= nil and fire.Name == "Fire")
	check(
		"find ignores bad ids",
		Customize.find(Config.Trails, 42) == nil and Customize.find(Config.Trails, "Nope") == nil
	)
	check("free items are always owned", Customize.owns({}, "Trail", Customize.find(Config.Trails, "None")))
	check("paid items need buying", not Customize.owns({}, "Trail", fire))
	check("bought items are owned", Customize.owns({ "Trail:Fire" }, "Trail", fire))
	check("owned keys are per kind", not Customize.owns({ "Sticker:Fire" }, "Trail", fire))

	local default = Customize.default(Config)
	check(
		"default custom: nothing equipped, default flame",
		default.trail == "None" and default.flame == Config.DefaultFlame
	)
	check(
		"every sticker but None has an image slot",
		(function()
			for _, sticker in Config.Stickers do
				if sticker.Id ~= "None" and Config.StickerImages[sticker.Id] == nil then
					return false
				end
			end
			return true
		end)()
	)
	check(
		"every accessory but None has a model and an offset",
		(function()
			for _, acc in Config.Accessories do
				if acc.Id ~= "None" and (typeof(acc.Model) ~= "string" or #acc.Offset ~= 3) then
					return false
				end
			end
			return true
		end)()
	)
end
