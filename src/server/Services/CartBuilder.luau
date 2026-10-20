--!strict
-- Builds a player's cart: the invisible Root slider + Seat (always made here), the body and the parts their upgrade
-- levels give (engine, wings, rocket, wheels).
-- Looks come from the kit models in ReplicatedStorage.Assets.CartKit (assets/3d/cart_kit.py, one Import 3D):
--   Cart_<CartId> for the body, and Config/Upgrades.Visuals picks Engine1..3 / Wings1..3 / Rocket1..3 / Wheels0..3.
-- Each kit MeshPart is named after a look group (Config/CartLooks). Without the kit, placeholder parts are used.
-- Local frame: forward = -Z, up = +Y, Root centre at the origin (its bottom slides on the ramp).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CartLooks = require(ReplicatedStorage.Shared.Config.CartLooks)
local CustomizeConfig = require(ReplicatedStorage.Shared.Config.Customize)
local CartsConfig = require(ReplicatedStorage.Shared.Config.Carts)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local CustomizeRules = require(ReplicatedStorage.Shared.Rules.Customize)
local UpgradeRules = require(ReplicatedStorage.Shared.Rules.Upgrades)

local CartBuilder = {}

export type Built = {
	model: Model,
	root: BasePart,
	seat: Seat,
	rocketFires: { Fire },
	trail: Trail?, -- garage trail, enabled by LaunchService while flying
	halfHeight: number, -- distance from the Root centre to its bottom
}

local ROOT_SIZE = Vector3.new(4.6, 1, 6.4)

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function cartColor(cartId: string): Color3
	local cart = CartsConfig.List[cartId] or CartsConfig.List[CartsConfig.Default]
	return rgb(cart.Color)
end

local function kit(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("CartKit")
	local model = folder and folder:FindFirstChild(name)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

-- Welds a part to the root as a weightless, non-colliding decoration.
local function attach(part: BasePart, root: BasePart, model: Model)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function add(model: Model, root: BasePart, props: { [string]: any }): BasePart
	local p: BasePart = Instance.new("Part")
	if props.Shape then
		(p :: Part).Shape = props.Shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Shape" and key ~= "Offset" then
			(p :: any)[key] = value
		end
	end
	p.CFrame = root.CFrame * (props.Offset :: CFrame)
	attach(p, root, model)
	return p
end

-- Clones a kit model, paints it by group, places it at `offset` (scaled) and welds it to the root.
local function addKit(
	model: Model,
	root: BasePart,
	name: string,
	offset: CFrame,
	scale: number,
	cartId: string?,
	fires: { Fire }
): boolean
	local source = kit(name)
	if not source then
		return false
	end
	local clone = source:Clone()
	if scale ~= 1 then
		clone:ScaleTo(scale)
	end
	clone:PivotTo(root.CFrame * offset)
	local overrides = if cartId then CartLooks.Carts[cartId] else nil
	for _, part in clone:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local look = (overrides and overrides[part.Name]) or CartLooks.Groups[part.Name]
		if look then
			part.Material = (Enum.Material :: any)[look.Material] or Enum.Material.SmoothPlastic
			part.Color = rgb(look.Color)
		end
		if
			cartId
			and (part.Name == "Accent" or part.Name == "Grip")
			and not (overrides and overrides[part.Name])
		then
			part.Color = cartColor(cartId)
		end
		if part.Name == "Glass" or part.Name == "Gem" then
			part.Transparency = CartLooks.GlassTransparency
		end
		if part.Name == "Nozzle" then
			-- exhaust: one fire per ring (twin boosters have two rings in one mesh)
			local twin = part.Size.X > 1.5
			for _, x in (if twin then { -1, 1 } else { 0 }) :: { number } do
				local nozzle = Instance.new("Attachment")
				nozzle.Name = "Exhaust"
				nozzle.Position = Vector3.new(x * (part.Size.X / 2 - 0.6), 0, 0)
				nozzle.Parent = part
				local fire = Instance.new("Fire")
				fire.Enabled = false
				fire.Size = 4
				fire.Heat = 12
				fire.Color = Color3.fromRGB(255, 150, 40)
				fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
				fire.Parent = nozzle
				table.insert(fires, fire)
			end
		end
		attach(part, root, model)
		if part.Name == "Blade" then
			-- propeller: a Motor6D instead of the weld, the client turns its Transform (Controllers/Propellers)
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			if weld then
				weld:Destroy()
			end
			local motor = Instance.new("Motor6D")
			motor.Name = "Spin"
			motor.Part0 = root
			motor.Part1 = part
			motor.C0 = root.CFrame:Inverse() * part.CFrame -- spins about the blade's centre, along the cart's Z
			motor.C1 = CFrame.new()
			motor:SetAttribute("Owner", model:GetAttribute("Owner"))
			CollectionService:AddTag(motor, CartLooks.PropellerTag)
			motor.Parent = part
		end
	end
	clone:Destroy()
	return true
end

local function mountOffset(key: string): CFrame
	local offset = UpgradesConfig.Mounts[key].Offset
	return CFrame.new(offset[1], offset[2], offset[3])
end

local function placeholderBody(model: Model, root: BasePart, cartId: string)
	local body = cartColor(cartId)
	local function wall(name: string, size: Vector3, offset: Vector3)
		add(model, root, {
			Name = name,
			Size = size,
			Offset = CFrame.new(offset),
			Color = body,
			Material = Enum.Material.DiamondPlate,
			Transparency = 0.1,
		})
	end
	wall("Floor", Vector3.new(4.4, 0.2, 6), Vector3.new(0, 1.1, 0))
	wall("SideL", Vector3.new(0.2, 2.6, 6), Vector3.new(-2.2, 2.4, 0))
	wall("SideR", Vector3.new(0.2, 2.6, 6), Vector3.new(2.2, 2.4, 0))
	wall("Front", Vector3.new(4.4, 2.6, 0.2), Vector3.new(0, 2.4, -3))
	wall("Back", Vector3.new(4.4, 2.6, 0.2), Vector3.new(0, 2.4, 3))
	add(model, root, {
		Name = "Handle",
		Size = Vector3.new(4.2, 0.35, 0.35),
		Color = Color3.fromRGB(214, 48, 48),
		Offset = CFrame.new(0, 5.1, 3.4),
	})
end

local function placeholderParts(model: Model, root: BasePart, levels: { [string]: number }, fires: { Fire })
	local wings = levels.Wings or 0
	if wings > 0 then
		local span = 1.5 + 0.6 * wings
		for _, side in { -1, 1 } do
			add(model, root, {
				Name = "Wing",
				Size = Vector3.new(span, 0.25, 2.8),
				Color = Color3.fromRGB(240, 240, 236),
				Offset = CFrame.new(side * (2.3 + span / 2), 2.6, -0.2),
			})
		end
	end
	if (levels.Engine or 0) > 0 then
		add(model, root, {
			Name = "Engine",
			Size = Vector3.new(1.6, 1.6, 1.4),
			Color = Color3.fromRGB(60, 62, 70),
			Offset = CFrame.new(0, 2.6, 4.1),
		})
	end
	local rocket = levels.Rocket or 0
	if rocket > 0 then
		local length = 1.6 + 0.2 * rocket
		local tube = add(model, root, {
			Name = "Rocket",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(length, 1.2, 1.2),
			Color = Color3.fromRGB(230, 80, 40),
			Offset = CFrame.new(0, 0.9, 3 + length / 2) * CFrame.Angles(0, math.rad(90), 0),
		})
		-- the tube is turned 90° about Y, so its local -X points to the back of the cart (+Z)
		local nozzle = Instance.new("Attachment")
		nozzle.Name = "Exhaust"
		nozzle.Position = Vector3.new(-(length / 2 + 0.2), 0, 0)
		nozzle.Parent = tube
		local fire = Instance.new("Fire")
		fire.Enabled = false
		fire.Size = 4
		fire.Heat = 12
		fire.Parent = nozzle
		table.insert(fires, fire)
	end
end

-- Builds the cart at the origin (the caller pivots it). `levels` = upgrade levels.
-- Garage looks on top of the built cart: paint, rocket flame colour, stickers, accessory, trail.
local function applyCustom(
	model: Model,
	root: BasePart,
	custom: CustomizeRules.Custom,
	fires: { Fire }
): Trail?
	for zone, paintId in custom.paint do
		local groups = CustomizeConfig.PaintZones[zone]
		local paint = CustomizeRules.find(CustomizeConfig.Paints, paintId)
		if groups and paint then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and table.find(groups, part.Name) then
					part.Color = rgb(paint.Color)
				end
			end
		end
	end
	local flame = CustomizeRules.find(CustomizeConfig.Flames, custom.flame)
	if flame then
		for _, fire in fires do
			fire.Color = rgb(flame.Color)
			fire.SecondaryColor = rgb(flame.Secondary)
		end
	end
	local image = CustomizeConfig.StickerImages[custom.sticker]
	if image and image ~= "" then
		for _, plate in CustomizeConfig.StickerPlates do
			local o = plate.Offset
			local p = add(model, root, {
				Name = "StickerPlate",
				Size = Vector3.new(plate.Size[1], plate.Size[2], plate.Size[3]),
				Color = Color3.fromRGB(245, 245, 245),
				Transparency = 1, -- only the sticker shows
				Offset = CFrame.new(o[1], o[2], o[3]),
			})
			local decal = Instance.new("Decal")
			decal.Texture = image
			decal.Face = (Enum.NormalId :: any)[plate.Face]
			decal.Parent = p
		end
	end
	local accessory = CustomizeRules.find(CustomizeConfig.Accessories, custom.accessory)
	if accessory and accessory.Model then
		local o = accessory.Offset
		addKit(model, root, accessory.Model, CFrame.new(o[1], o[2], o[3]), 1, nil, fires)
	end
	local trailInfo = CustomizeRules.find(CustomizeConfig.Trails, custom.trail)
	if trailInfo and trailInfo.Colors then
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailTop"
		a0.Position = Vector3.new(0, 2.6, 3.4)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailBottom"
		a1.Position = Vector3.new(0, 0.4, 3.4)
		a1.Parent = root
		local keys = {}
		local colors = trailInfo.Colors
		for i, c in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#colors - 1, 1), rgb(c)))
		end
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(keys)
		trail.Transparency = NumberSequence.new(0.15, 1)
		trail.Lifetime = CustomizeConfig.TrailLifetime
		trail.WidthScale = NumberSequence.new(1, 0.3)
		trail.LightEmission = 0.6
		trail.FaceCamera = true
		trail.Enabled = false
		trail.Parent = root
		return trail
	end
	return nil
end

function CartBuilder.build(
	player: Player,
	cartId: string,
	levels: { [string]: number },
	custom: CustomizeRules.Custom?
): Built
	local model = Instance.new("Model")
	model.Name = "Cart_" .. player.Name
	model:SetAttribute("Owner", player.UserId)

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	-- frictionless slider: the ramp push and the air forces do the work
	root.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0, 100, 100)
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.Transparency = 1
	seat.CFrame = root.CFrame * CFrame.new(0, 1.5, 0.6)
	attach(seat, root, model)

	local fires: { Fire } = {}
	if not addKit(model, root, "Cart_" .. cartId, CFrame.new(), 1, cartId, fires) then
		placeholderBody(model, root, cartId)
	end
	local usedKit = kit("Engine1") ~= nil
	if usedKit then
		for key in UpgradesConfig.Visuals do
			local levelKey = UpgradesConfig.VisualLevelOf[key] or key
			local auto, scale = UpgradeRules.visual(UpgradesConfig, key, levels[levelKey] or 0)
			-- the garage may pick an older unlocked model for this slot
			local name = if custom
				then CustomizeRules.modelFor(UpgradesConfig, key, levels, custom.models[key])
				else auto
			if name then
				addKit(model, root, name, mountOffset(key), scale, nil, fires)
			end
		end
	else
		placeholderParts(model, root, levels, fires)
	end

	local trail = if custom then applyCustom(model, root, custom, fires) else nil

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Carts"
		end
	end
	return {
		model = model,
		root = root,
		seat = seat,
		rocketFires = fires,
		trail = trail,
		halfHeight = root.Size.Y / 2,
	}
end

return CartBuilder
