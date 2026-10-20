--!strict
-- Garage rules (pure): what a player may pick, and what their cart ends up showing.
local Customize = {}

export type Custom = {
	models: { [string]: string }, -- slot -> chosen kit model ("" or missing = newest unlocked)
	paint: { [string]: string }, -- zone -> paint id
	trail: string,
	flame: string,
	sticker: string,
	accessory: string,
}

function Customize.default(config: any): Custom
	return {
		models = {},
		paint = {},
		trail = "None",
		flame = config.DefaultFlame,
		sticker = "None",
		accessory = "None",
	}
end

-- The part level a visual slot follows (the tail follows the wings).
function Customize.levelFor(upgrades: any, slot: string, levels: { [string]: number }): number
	local key = upgrades.VisualLevelOf[slot] or slot
	local level = levels[key]
	return if typeof(level) == "number" then level else 0
end

-- Kit models of a slot the player has unlocked (tiers with From <= level), oldest first.
function Customize.unlockedModels(upgrades: any, slot: string, levels: { [string]: number }): { string }
	local tiers = upgrades.Visuals[slot]
	local found = {}
	if not tiers then
		return found
	end
	local level = Customize.levelFor(upgrades, slot, levels)
	for _, tier in tiers do
		if level >= tier.From then
			table.insert(found, tier.Model)
		end
	end
	return found
end

-- Model the cart shows in a slot: the chosen one if still unlocked, otherwise the newest unlocked (nil = none).
function Customize.modelFor(
	upgrades: any,
	slot: string,
	levels: { [string]: number },
	chosen: string?
): string?
	local unlocked = Customize.unlockedModels(upgrades, slot, levels)
	if chosen and chosen ~= "" and table.find(unlocked, chosen) then
		return chosen
	end
	return unlocked[#unlocked]
end

-- Entry of a list (Trails, Stickers, Accessories, Paints, Flames) by id, or nil.
function Customize.find(list: { any }, id: any): any
	if typeof(id) ~= "string" then
		return nil
	end
	for _, entry in list do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

-- Key used in the owned list for a bought item ("Trail:Fire").
function Customize.ownedKey(kind: string, id: string): string
	return kind .. ":" .. id
end

-- The player owns this item (free ones always count).
function Customize.owns(owned: { string }, kind: string, entry: any): boolean
	return entry ~= nil and (entry.Price == 0 or table.find(owned, Customize.ownedKey(kind, entry.Id)) ~= nil)
end

return Customize
