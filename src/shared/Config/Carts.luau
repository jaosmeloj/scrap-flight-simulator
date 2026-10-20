--!strict
-- Cart bodies. A better cart is lighter on the air (less drag), carries a bit more lift and earns more coins per
-- flight (CoinBonus: +0.5 = x1.5).
-- Color is RGB 0-255 (plain numbers so the Rules tests can load this file outside Roblox).
-- Model: ReplicatedStorage.Assets.Carts.<Id> when it exists, otherwise the placeholder cart built by code.
local Carts = {
	Default = "Basic",
	Order = { "Basic", "Market", "Industrial", "Racing", "Golden" },
	List = {
		Basic = {
			Name = "Shopping Cart",
			Price = 0,
			Drag = 1.0,
			LiftBonus = 0,
			CoinBonus = 0,
			Color = { 190, 196, 204 },
		},
		Market = {
			Name = "Market Cart",
			Price = 2500,
			Drag = 0.88,
			LiftBonus = 0.02,
			CoinBonus = 0.25,
			Color = { 64, 156, 96 },
		},
		Industrial = {
			Name = "Industrial Cart",
			Price = 30000,
			Drag = 0.76,
			LiftBonus = 0.04,
			CoinBonus = 0.5,
			Color = { 232, 176, 40 },
		},
		Racing = {
			Name = "Racing Cart",
			Price = 140000,
			Drag = 0.62,
			LiftBonus = 0.06,
			CoinBonus = 1.0,
			Color = { 214, 48, 48 },
		},
		Golden = {
			Name = "Golden Cart",
			Price = 500000,
			Drag = 0.5,
			LiftBonus = 0.08,
			CoinBonus = 2.0,
			Color = { 255, 204, 60 },
		},
	},
}

return Carts
