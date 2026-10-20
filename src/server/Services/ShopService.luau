--!strict
-- Upgrade and cart shop. The client asks; the server checks the part/cart exists, the level, the price and the
-- player's coins, then applies and rebuilds the waiting cart.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CartsConfig = require(ReplicatedStorage.Shared.Config.Carts)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local UpgradeRules = require(ReplicatedStorage.Shared.Rules.Upgrades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local LaunchService = require(script.Parent.LaunchService)
local PlayerService = require(script.Parent.PlayerService)
local State = require(script.Parent.State)

local ShopService = {}

local function buyUpgrade(player: Player, key: any): (boolean, string)
	local profile = State.profiles[player]
	if not profile or typeof(key) ~= "string" or UpgradesConfig.Parts[key] == nil then
		return false, "Unknown upgrade"
	end
	local current = profile.upgrades[key] or 0
	local price = UpgradeRules.cost(UpgradesConfig, key, current)
	if price == nil then
		return false, "Max level"
	end
	if not PlayerService.spend(player, price) then
		return false, "Not enough coins"
	end
	profile.upgrades[key] = current + 1
	PlayerService.sync(player)
	LaunchService.refresh(player)
	return true, string.format("%s level %d!", UpgradesConfig.Parts[key].Name, current + 1)
end

local function buyCart(player: Player, cartId: any): (boolean, string)
	local profile = State.profiles[player]
	if not profile or typeof(cartId) ~= "string" or CartsConfig.List[cartId] == nil then
		return false, "Unknown cart"
	end
	local cart = CartsConfig.List[cartId]
	if not table.find(profile.carts, cartId) then
		if not PlayerService.spend(player, cart.Price) then
			return false, "Not enough coins"
		end
		table.insert(profile.carts, cartId)
	end
	profile.cart = cartId
	PlayerService.sync(player)
	LaunchService.refresh(player)
	return true, cart.Name .. " equipped!"
end

function ShopService.start()
	Remotes.getFunction(Remotes.FunctionNames.BuyUpgrade).OnServerInvoke = buyUpgrade
	Remotes.getFunction(Remotes.FunctionNames.BuyCart).OnServerInvoke = buyCart
end

return ShopService
