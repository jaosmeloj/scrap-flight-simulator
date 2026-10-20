--!strict
-- Player lifecycle: load the profile, leaderstats (Coins, Record), and mirror the profile into player attributes
-- the client reads (Lvl_<Part>, Cart, OwnedCarts, Best). Coins change only through PlayerService.addCoins.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local DataService = require(script.Parent.DataService)
local State = require(script.Parent.State)

local PlayerService = {}

local readyCallbacks: { (Player) -> () } = {}

local function leaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = folder
	local record = Instance.new("IntValue")
	record.Name = "Record"
	record.Parent = folder
	folder.Parent = player
end

-- Copies the profile to leaderstats and attributes.
function PlayerService.sync(player: Player)
	local profile = State.profiles[player]
	if not profile then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Coins") :: IntValue).Value = profile.coins;
		(stats:FindFirstChild("Record") :: IntValue).Value = math.floor(profile.best)
	end
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("Best", math.floor(profile.best))
	for _, key in UpgradesConfig.Order do
		player:SetAttribute("Lvl_" .. key, profile.upgrades[key] or 0)
	end
	player:SetAttribute("Cart", profile.cart)
	player:SetAttribute("OwnedCarts", table.concat(profile.carts, ","))
	-- garage: choices as JSON, bought items as a list (the Garage window reads both)
	player:SetAttribute("Custom", HttpService:JSONEncode(profile.custom))
	player:SetAttribute("Cosmetics", table.concat(profile.cosmetics, ","))
end

function PlayerService.addCoins(player: Player, amount: number)
	local profile = State.profiles[player]
	if not profile or amount == 0 then
		return
	end
	profile.coins = math.max(0, profile.coins + math.floor(amount))
	PlayerService.sync(player)
end

-- Spends coins if the player has them. Returns true when spent.
function PlayerService.spend(player: Player, amount: number): boolean
	local profile = State.profiles[player]
	if not profile or amount < 0 or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	PlayerService.sync(player)
	return true
end

-- Runs `callback(player)` once each player's profile is loaded (and for players already loaded).
function PlayerService.onReady(callback: (Player) -> ())
	table.insert(readyCallbacks, callback)
	for player in State.profiles do
		task.spawn(callback, player)
	end
end

local function added(player: Player)
	leaderstats(player)
	local profile, saveEnabled = DataService.load(player)
	if not player.Parent then
		-- left during the load: free the lock without rewriting the profile
		if saveEnabled then
			DataService.releaseLock(player)
		end
		return
	end
	State.profiles[player] = profile
	State.sessions[player] = { saveEnabled = saveEnabled, lastReset = 0 }
	PlayerService.sync(player)
	for _, callback in readyCallbacks do
		task.spawn(callback, player)
	end
end

local function removing(player: Player)
	-- no yield before the save
	DataService.save(player, true)
	State.profiles[player] = nil
	State.sessions[player] = nil
end

function PlayerService.start()
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(removing)
	for _, player in Players:GetPlayers() do
		task.spawn(added, player)
	end
end

return PlayerService
