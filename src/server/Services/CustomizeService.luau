--!strict
-- Garage. The client asks (Remotes Customize: action, a, b); the server checks every id against Config/Customize,
-- the unlocks (part levels) and the price, saves the choice in profile.custom and rebuilds the waiting cart.
--   "model", slot, kitModel|""   pick an unlocked model for a slot ("" = newest)
--   "paint", zone, paintId|""    free paint ("" = the cart's own colours)
--   "flame", flameId             free rocket flame colour
--   "trail"|"sticker"|"accessory", id   buys it the first time (coins), then equips it
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizeConfig = require(ReplicatedStorage.Shared.Config.Customize)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local CustomizeRules = require(ReplicatedStorage.Shared.Rules.Customize)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LaunchService = require(script.Parent.LaunchService)
local PlayerService = require(script.Parent.PlayerService)
local State = require(script.Parent.State)

local CustomizeService = {}

local LISTS = {
	trail = { list = CustomizeConfig.Trails, kind = "Trail" },
	sticker = { list = CustomizeConfig.Stickers, kind = "Sticker" },
	accessory = { list = CustomizeConfig.Accessories, kind = "Accessory" },
}

local function apply(player: Player, message: string): (boolean, string)
	PlayerService.sync(player)
	LaunchService.refresh(player)
	return true, message
end

local function handle(player: Player, action: any, a: any, b: any): (boolean, string)
	local profile = State.profiles[player]
	if not profile or typeof(action) ~= "string" then
		return false, "Not ready"
	end
	local custom = profile.custom
	if action == "model" then
		if
			typeof(a) ~= "string"
			or not table.find(CustomizeConfig.ModelSlots, a)
			or typeof(b) ~= "string"
		then
			return false, "Unknown part"
		end
		if
			b ~= "" and not table.find(CustomizeRules.unlockedModels(UpgradesConfig, a, profile.upgrades), b)
		then
			return false, "Locked: level up this part first"
		end
		custom.models[a] = if b == "" then nil else b
		return apply(
			player,
			if b == "" then "Newest model" else (CustomizeConfig.ModelNames[b] or b) .. " equipped"
		)
	elseif action == "paint" then
		if typeof(a) ~= "string" or not CustomizeConfig.PaintZones[a] or typeof(b) ~= "string" then
			return false, "Unknown paint"
		end
		if b ~= "" and not CustomizeRules.find(CustomizeConfig.Paints, b) then
			return false, "Unknown colour"
		end
		custom.paint[a] = if b == "" then nil else b
		return apply(player, "Painted!")
	elseif action == "flame" then
		if not CustomizeRules.find(CustomizeConfig.Flames, a) then
			return false, "Unknown flame"
		end
		custom.flame = a
		return apply(player, a .. " flames!")
	end
	local entry = LISTS[action]
	if not entry then
		return false, "Unknown action"
	end
	local item = CustomizeRules.find(entry.list, a)
	if not item then
		return false, "Unknown item"
	end
	if not CustomizeRules.owns(profile.cosmetics, entry.kind, item) then
		if not PlayerService.spend(player, item.Price) then
			return false, "Not enough coins"
		end
		table.insert(profile.cosmetics, CustomizeRules.ownedKey(entry.kind, item.Id))
	end
	(custom :: any)[action] = item.Id
	return apply(player, item.Name .. " equipped!")
end

function CustomizeService.start()
	Remotes.getFunction(Remotes.FunctionNames.Customize).OnServerInvoke = handle
end

return CustomizeService
