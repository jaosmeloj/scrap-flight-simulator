--!strict
-- Look of the kit models (assets/3d/cart_kit.py -> Import 3D -> ReplicatedStorage.Assets.CartKit).
-- Each MeshPart is named after its group; the group gets a Roblox material and an RGB colour (0-255).
-- "Accent" on a cart body takes the cart's own colour (Config/Carts.List.<Id>.Color).
local CartLooks = {
	Groups = {
		Frame = { Material = "Metal", Color = { 170, 174, 184 } },
		Wire = { Material = "Metal", Color = { 196, 200, 208 } },
		Grip = { Material = "SmoothPlastic", Color = { 214, 44, 40 } },
		Accent = { Material = "SmoothPlastic", Color = { 214, 44, 40 } },
		Panel = { Material = "SmoothPlastic", Color = { 70, 76, 90 } },
		Rubber = { Material = "Rubber", Color = { 28, 28, 32 } },
		Hub = { Material = "Metal", Color = { 200, 202, 210 } },
		Body = { Material = "SmoothPlastic", Color = { 96, 102, 116 } },
		Metal = { Material = "Metal", Color = { 120, 124, 134 } },
		Dark = { Material = "Metal", Color = { 40, 40, 46 } },
		Blade = { Material = "Wood", Color = { 168, 112, 60 } },
		Gold = { Material = "Foil", Color = { 255, 196, 60 } },
		Gem = { Material = "Glass", Color = { 70, 150, 255 } },
		Cardboard = { Material = "Cardboard", Color = { 196, 150, 96 } },
		Tape = { Material = "Fabric", Color = { 230, 220, 190 } },
		Wood = { Material = "Wood", Color = { 160, 110, 60 } },
		Fabric = { Material = "Fabric", Color = { 244, 236, 214 } },
		Nozzle = { Material = "Metal", Color = { 30, 30, 34 } },
		Glass = { Material = "Glass", Color = { 150, 210, 255 } },
		TankRed = { Material = "SmoothPlastic", Color = { 220, 46, 34 } },
		TankBlue = { Material = "SmoothPlastic", Color = { 40, 100, 220 } },
		Lamp = { Material = "Neon", Color = { 255, 230, 160 } },
		Horn = { Material = "SmoothPlastic", Color = { 236, 226, 196 } },
		SirenRed = { Material = "Neon", Color = { 255, 40, 40 } },
		SirenBlue = { Material = "Neon", Color = { 40, 90, 255 } },
	},
	-- per cart overrides (on top of Groups)
	Carts = {
		Market = { Panel = { Material = "SmoothPlastic", Color = { 64, 172, 96 } } },
		Industrial = { Accent = { Material = "SmoothPlastic", Color = { 240, 190, 30 } } },
		Racing = { Panel = { Material = "SmoothPlastic", Color = { 250, 250, 250 } } },
		Golden = { Accent = { Material = "SmoothPlastic", Color = { 150, 60, 210 } } },
	},
	GlassTransparency = 0.35,

	-- Propellers ("Blade" parts of the engines) spin on each player's screen (Client/Controllers/Propellers).
	-- Radians per second by the owner's phase; the spin eases between speeds.
	PropellerSpin = { Ready = 6, Ramp = 30, Flight = 55, Rolling = 12, Landed = 0 },
	PropellerEase = 2.5, -- how fast the spin speed catches up (per second)
	PropellerTag = "Propeller", -- CollectionService tag on the Motor6D that turns a blade
}

return CartLooks
