--!strict
-- Shared server state: saved profiles and live sessions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CartsConfig = require(ReplicatedStorage.Shared.Config.Carts)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local CustomizeConfig = require(ReplicatedStorage.Shared.Config.Customize)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local CustomizeRules = require(ReplicatedStorage.Shared.Rules.Customize)

local State = {}

export type Profile = {
	version: number,
	coins: number,
	upgrades: { [string]: number },
	carts: { string }, -- owned cart ids
	cart: string, -- equipped cart id
	best: number, -- record distance (studs)
	zones: { string }, -- zones already reached (first-visit rewards paid)
	launches: number,
	custom: CustomizeRules.Custom, -- garage choices
	cosmetics: { string }, -- bought garage items ("Trail:Fire", "Sticker:Star", "Accessory:Flag")
}

export type Session = {
	saveEnabled: boolean,
	lastReset: number,
}

State.profiles = {} :: { [Player]: Profile }
State.sessions = {} :: { [Player]: Session }

function State.defaultProfile(): Profile
	local upgrades = {}
	for _, key in UpgradesConfig.Order do
		upgrades[key] = 0
	end
	return {
		version = DataConfig.ProfileVersion,
		coins = 0,
		upgrades = upgrades,
		carts = { CartsConfig.Default },
		cart = CartsConfig.Default,
		best = 0,
		zones = {},
		launches = 0,
		custom = CustomizeRules.default(CustomizeConfig),
		cosmetics = {},
	}
end

return State
