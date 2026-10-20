--!strict
-- Garage: everything the player can change on the look of their cart (no effect on the flight).
-- Colours are RGB 0-255 (plain numbers so the Rules tests can load this file outside Roblox).
local Customize = {
	-- Part models: a model can be picked once its tier is unlocked (Config/Upgrades.Visuals: From <= part level).
	-- Slot order in the garage; "Tail" follows the wings level (Config/Upgrades.VisualLevelOf).
	ModelSlots = { "Engine", "Wings", "Tail", "Rocket", "FuelTank", "Wheels" },
	ModelNames = {
		Engine1 = "Fan",
		Engine2 = "Lawnmower",
		Engine3 = "Turbofan",
		Engine4 = "V8",
		Engine5 = "Jet",
		Wings1 = "Cardboard",
		Wings2 = "Doors",
		Wings3 = "Glider",
		Wings4 = "Biplane",
		Wings5 = "Jet Wings",
		Tail1 = "Cardboard Fin",
		Tail2 = "Plank",
		Tail3 = "Glider Tail",
		Tail4 = "Biplane Tail",
		Tail5 = "Twin Fins",
		Rocket1 = "Firework",
		Rocket2 = "Soda Bottles",
		Rocket3 = "Steel Rocket",
		Rocket4 = "Rocket Pod",
		Rocket5 = "Twin Boosters",
		Tank1 = "Jerry Can",
		Tank2 = "Water Bottle",
		Tank3 = "Gas Bottles",
		Tank4 = "Oil Barrel",
		Tank5 = "Steel Drum",
		Wheels0 = "Casters",
		Wheels1 = "Rubber",
		Wheels2 = "Off-road",
		Wheels3 = "Monster",
		Wheels4 = "Racing",
	},

	-- Paint (free): each zone recolours these kit groups (Config/CartLooks group names).
	PaintZones = {
		Frame = { "Frame", "Wire", "Gold" }, -- the cart's tubes and basket
		Accent = { "Accent", "Grip", "Panel" }, -- handle, bumpers, plastic panels
		Parts = { "Body", "Fabric", "Cardboard", "TankRed", "TankBlue" }, -- engine, wings, tail, rocket and tank bodies
		Wheels = { "Hub" },
	},
	PaintZoneOrder = { "Frame", "Accent", "Parts", "Wheels" },
	Paints = {
		{ Id = "Red", Color = { 220, 50, 44 } },
		{ Id = "Orange", Color = { 246, 140, 40 } },
		{ Id = "Yellow", Color = { 250, 214, 60 } },
		{ Id = "Lime", Color = { 140, 220, 60 } },
		{ Id = "Green", Color = { 46, 160, 80 } },
		{ Id = "Teal", Color = { 40, 180, 170 } },
		{ Id = "Blue", Color = { 50, 110, 230 } },
		{ Id = "Purple", Color = { 140, 70, 210 } },
		{ Id = "Pink", Color = { 240, 110, 180 } },
		{ Id = "White", Color = { 240, 240, 244 } },
		{ Id = "Silver", Color = { 170, 174, 184 } },
		{ Id = "Black", Color = { 36, 36, 42 } },
		{ Id = "Gold", Color = { 255, 196, 60 } },
		{ Id = "Brown", Color = { 130, 86, 50 } },
	},

	-- Rocket flame colour (free): { main, secondary }
	Flames = {
		{ Id = "Orange", Color = { 255, 150, 40 }, Secondary = { 255, 60, 20 } },
		{ Id = "Blue", Color = { 80, 170, 255 }, Secondary = { 40, 60, 255 } },
		{ Id = "Green", Color = { 120, 255, 90 }, Secondary = { 20, 160, 40 } },
		{ Id = "Purple", Color = { 200, 110, 255 }, Secondary = { 110, 30, 200 } },
		{ Id = "Pink", Color = { 255, 130, 200 }, Secondary = { 230, 40, 130 } },
		{ Id = "White", Color = { 255, 255, 255 }, Secondary = { 180, 200, 255 } },
	},
	DefaultFlame = "Orange",

	-- Bought with coins, kept forever. "None" is always owned.
	Trails = {
		{ Id = "None", Name = "No Trail", Price = 0 },
		{ Id = "Smoke", Name = "Smoke", Price = 1500, Colors = { { 230, 230, 230 }, { 120, 120, 120 } } },
		{ Id = "Fire", Name = "Fire", Price = 6000, Colors = { { 255, 220, 80 }, { 255, 60, 20 } } },
		{ Id = "Ghost", Name = "Ghost", Price = 15000, Colors = { { 160, 255, 255 }, { 60, 120, 255 } } },
		{
			Id = "Rainbow",
			Name = "Rainbow",
			Price = 40000,
			Colors = {
				{ 255, 60, 60 },
				{ 255, 200, 40 },
				{ 80, 230, 80 },
				{ 60, 140, 255 },
				{ 190, 80, 255 },
			},
		},
		{ Id = "Gold", Name = "Gold Dust", Price = 120000, Colors = { { 255, 240, 160 }, { 255, 180, 30 } } },
	},
	TrailLifetime = 0.8,
	TrailWidth = 2.2,

	-- Stickers go on the plates (front and both sides). Image ids read from the imported Sticker_<Id> cards (TextureID).
	Stickers = {
		{ Id = "None", Name = "No Sticker", Price = 0 },
		{ Id = "Number7", Name = "Number 7", Price = 500 },
		{ Id = "Star", Name = "Star", Price = 800 },
		{ Id = "Bolt", Name = "Lightning", Price = 1500 },
		{ Id = "Flames", Name = "Flames", Price = 3000 },
		{ Id = "Heart", Name = "Heart", Price = 3000 },
		{ Id = "Skull", Name = "Skull", Price = 6000 },
		{ Id = "Checker", Name = "Checkered", Price = 10000 },
		{ Id = "Crown", Name = "Crown", Price = 25000 },
	},
	StickerImages = {
		Number7 = "rbxassetid://117910933928284",
		Star = "rbxassetid://97323092166738",
		Bolt = "rbxassetid://73180788968217",
		Flames = "rbxassetid://93322721988706",
		Heart = "rbxassetid://90453852036562",
		Skull = "rbxassetid://71747116894782",
		Checker = "rbxassetid://102031404112790",
		Crown = "rbxassetid://118644460629827",
	},
	-- plate size (studs) and where it sits on the cart (cart frame: +Y up, -Z nose); Face = side the sticker shows on
	StickerPlates = {
		{ Name = "Front", Size = { 1.8, 1.2, 0.08 }, Offset = { 0, 3.0, -3.3 }, Face = "Front" },
		{ Name = "Left", Size = { 0.08, 1.4, 2.4 }, Offset = { -2.42, 2.7, 0 }, Face = "Left" },
		{ Name = "Right", Size = { 0.08, 1.4, 2.4 }, Offset = { 2.42, 2.7, 0 }, Face = "Right" },
	},

	-- Accessories (one at a time): kit model + where it sits on the cart
	Accessories = {
		{ Id = "None", Name = "No Accessory", Price = 0 },
		{ Id = "Antenna", Name = "Antenna", Price = 2000, Model = "AccAntenna", Offset = { -2.1, 4.0, 3.0 } },
		{ Id = "Flag", Name = "Flag", Price = 5000, Model = "AccFlag", Offset = { 2.1, 4.0, 3.0 } },
		{
			Id = "Headlights",
			Name = "Headlights",
			Price = 9000,
			Model = "AccHeadlights",
			Offset = { 0, 3.9, -3.1 },
		},
		{ Id = "Horns", Name = "Bull Horns", Price = 20000, Model = "AccHorns", Offset = { 0, 4.1, -3.1 } },
		{
			Id = "Siren",
			Name = "Siren",
			Price = 50000,
			Model = "AccSiren",
			Offset = { 0, 4.1, -2.4 },
		},
	},
}

return Customize
