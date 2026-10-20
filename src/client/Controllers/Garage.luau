--!strict
-- Garage window: your cart spinning in a 3D preview (a copy of your real cart, rebuilt by the server on every
-- change) and tabs to pick part models, paint, stickers, accessories, trails and the rocket flame colour.
-- Choices go through the Customize RemoteFunction; the server checks unlocks and prices (CustomizeService).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CustomizeConfig = require(ReplicatedStorage.Shared.Config.Customize)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local CustomizeRules = require(ReplicatedStorage.Shared.Rules.Customize)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local Garage = {}

local player = Players.LocalPlayer
local window: Frame? = nil
local content: ScrollingFrame? = nil
local viewport: ViewportFrame? = nil
local currentTab = "Parts"
local messageCallback: ((string) -> ())? = nil
local tabButtons: { [string]: TextButton } = {}

local TABS = { "Parts", "Paint", "Stickers", "Accessories", "Trails", "Flames" }
local GREY = Color3.fromRGB(110, 110, 120)

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function custom(): CustomizeRules.Custom
	local raw = player:GetAttribute("Custom")
	if typeof(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and typeof(decoded) == "table" then
			return decoded :: any
		end
	end
	return CustomizeRules.default(CustomizeConfig)
end

local function owned(): { string }
	return string.split(player:GetAttribute("Cosmetics") or "", ",")
end

local function levels(): { [string]: number }
	local result = {}
	for _, key in UpgradesConfig.Order do
		result[key] = player:GetAttribute("Lvl_" .. key) or 0
	end
	return result
end

local function ask(action: string, a: any, b: any)
	local ok, message = Remotes.getFunction(Remotes.FunctionNames.Customize):InvokeServer(action, a, b)
	if messageCallback then
		messageCallback(if ok then message else (message or "Can't do that"))
	end
end

local function clear()
	if not content then
		return
	end
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local order = 0
local function section(title: string)
	order += 1
	Ui.label({
		Text = title,
		Size = UDim2.new(1, -12, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = content,
	})
end

-- A wrapping row of buttons; returns the container.
local function grid(cellSize: UDim2): Frame
	order += 1
	return Ui.new("Frame", {
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = content,
	}, {
		Ui.new("UIGridLayout", { CellSize = cellSize, CellPadding = UDim2.fromOffset(6, 6) }),
	})
end

local function selectedStroke(button: GuiObject, selected: boolean)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(0, 0, 0)
		stroke.Thickness = if selected then 4 else 2
		stroke.Transparency = if selected then 0 else 0.4
	end
end

local function renderParts()
	local choice = custom()
	local lv = levels()
	for _, slot in CustomizeConfig.ModelSlots do
		local levelKey = UpgradesConfig.VisualLevelOf[slot] or slot
		local partName = UpgradesConfig.Parts[levelKey] and UpgradesConfig.Parts[levelKey].Name or levelKey
		section(if slot == "Tail" then "Tail (with wings)" else partName)
		local row = grid(UDim2.fromOffset(122, 44))
		local showing = CustomizeRules.modelFor(UpgradesConfig, slot, lv, choice.models[slot])
		local auto = Ui.button({
			Text = "NEWEST",
			BackgroundColor3 = Ui.Colors.Blue,
			Parent = row,
		})
		selectedStroke(auto, choice.models[slot] == nil)
		auto.Activated:Connect(function()
			ask("model", slot, "")
		end)
		local unlocked = CustomizeRules.unlockedModels(UpgradesConfig, slot, lv)
		for _, tier in UpgradesConfig.Visuals[slot] do
			local isUnlocked = table.find(unlocked, tier.Model) ~= nil
			local name = CustomizeConfig.ModelNames[tier.Model] or tier.Model
			local button = Ui.button({
				Text = if isUnlocked then name else (name .. "\nLv " .. tier.From),
				BackgroundColor3 = if isUnlocked then Ui.Colors.Green else GREY,
				Parent = row,
			})
			selectedStroke(button, choice.models[slot] ~= nil and showing == tier.Model)
			button.Activated:Connect(function()
				if isUnlocked then
					ask("model", slot, tier.Model)
				elseif messageCallback then
					messageCallback(string.format("Reach %s level %d to unlock", partName, tier.From))
				end
			end)
		end
	end
end

local function swatches(list: { any }, selectedId: string?, onPick: (string) -> (), withDefault: boolean)
	local row = grid(UDim2.fromOffset(44, 44))
	if withDefault then
		local reset = Ui.button({ Text = "X", BackgroundColor3 = GREY, Parent = row })
		selectedStroke(reset, selectedId == nil)
		reset.Activated:Connect(function()
			onPick("")
		end)
	end
	for _, entry in list do
		local swatch = Ui.button({ Text = "", BackgroundColor3 = rgb(entry.Color), Parent = row })
		selectedStroke(swatch, selectedId == entry.Id)
		swatch.Activated:Connect(function()
			onPick(entry.Id)
		end)
	end
end

local function renderPaint()
	local choice = custom()
	local names = { Frame = "Cart frame", Accent = "Details", Parts = "Parts", Wheels = "Wheel hubs" }
	for _, zone in CustomizeConfig.PaintZoneOrder do
		section(names[zone] or zone)
		swatches(CustomizeConfig.Paints, choice.paint[zone], function(id)
			ask("paint", zone, id)
		end, true)
	end
end

local function renderFlames()
	section("Rocket flame colour")
	swatches(CustomizeConfig.Flames, custom().flame, function(id)
		ask("flame", id)
	end, false)
end

local function renderShopList(
	action: string,
	kind: string,
	list: { any },
	equipped: string,
	images: { [string]: string }?
)
	local mine = owned()
	for _, item in list do
		order += 1
		local row = Ui.new("Frame", {
			Size = UDim2.new(1, -12, 0, 60),
			BackgroundColor3 = Color3.fromRGB(44, 50, 66),
			LayoutOrder = order,
			Parent = content,
		}, { Ui.corner(10) })
		local textX = 12
		local image = images and images[item.Id]
		if image and image ~= "" then
			Ui.new("ImageLabel", {
				Image = image,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.fromOffset(52, 52),
				Parent = row,
			})
			textX = 66
		end
		Ui.label({
			Text = item.Name,
			Position = UDim2.fromOffset(textX, 14),
			Size = UDim2.new(0.55, -textX, 0, 32),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		local has = CustomizeRules.owns(mine, kind, item)
		local isOn = equipped == item.Id
		local button = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(140, 42),
			Text = if isOn then "EQUIPPED" elseif has then "EQUIP" else Ui.number(item.Price),
			BackgroundColor3 = if isOn
				then GREY
				elseif has then Ui.Colors.Blue
				elseif (player:GetAttribute("Coins") or 0) >= item.Price then Ui.Colors.Green
				else GREY,
			Parent = row,
		})
		button.Activated:Connect(function()
			if not isOn then
				ask(action, item.Id)
			end
		end)
	end
end

local function render()
	if not content or not window or not window.Visible then
		return
	end
	local canvas = content.CanvasPosition
	clear()
	order = 0
	local choice = custom()
	if currentTab == "Parts" then
		renderParts()
	elseif currentTab == "Paint" then
		renderPaint()
	elseif currentTab == "Flames" then
		renderFlames()
	elseif currentTab == "Trails" then
		renderShopList("trail", "Trail", CustomizeConfig.Trails, choice.trail, nil)
	elseif currentTab == "Stickers" then
		renderShopList(
			"sticker",
			"Sticker",
			CustomizeConfig.Stickers,
			choice.sticker,
			CustomizeConfig.StickerImages
		)
	elseif currentTab == "Accessories" then
		renderShopList("accessory", "Accessory", CustomizeConfig.Accessories, choice.accessory, nil)
	end
	content.CanvasPosition = canvas -- keep the scroll where it was
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == currentTab then Ui.Colors.Gold else Ui.Colors.Blue
	end
end

-- 3D preview: a copy of the player's real cart, turning slowly.
local previewModel: Model? = nil
local previewCamera: Camera? = nil
local angle = 0

local function myCart(): Model?
	local carts = workspace:FindFirstChild("Carts")
	if not carts then
		return nil
	end
	for _, cart in carts:GetChildren() do
		if cart:IsA("Model") and cart:GetAttribute("Owner") == player.UserId then
			return cart
		end
	end
	return nil
end

local function refreshPreview()
	if not viewport then
		return
	end
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	local cart = myCart()
	if not cart then
		return
	end
	local copy = cart:Clone()
	copy:PivotTo(CFrame.new())
	copy.Parent = viewport
	previewModel = copy
end

local function build(gui: ScreenGui)
	local frame = Ui.new("Frame", {
		Name = "Garage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.82),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(16), Ui.new("UISizeConstraint", { MaxSize = Vector2.new(1180, 700) }) })
	Ui.label({
		Text = "GARAGE",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(0.4, 0, 0, 40),
		Parent = frame,
	})
	local close = Ui.button({
		Text = "X",
		BackgroundColor3 = Ui.Colors.Red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(44, 40),
		Parent = frame,
	})
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	local view = Ui.new("ViewportFrame", {
		Name = "Preview",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(0.45, -16, 1, -76),
		BackgroundColor3 = Color3.fromRGB(70, 90, 120),
		Ambient = Color3.fromRGB(150, 150, 160),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-1, -1.5, -0.6),
		Parent = frame,
	}, { Ui.corner(12) })
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = view
	view.CurrentCamera = camera
	viewport = view
	previewCamera = camera

	local tabs = Ui.new("Frame", {
		Position = UDim2.new(0.45, 12, 0, 60),
		Size = UDim2.new(0.55, -40, 0, 40),
		BackgroundTransparency = 1,
		Parent = frame,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, name in TABS do
		local tab = Ui.button({
			Text = name,
			Size = UDim2.new(1 / #TABS, -6, 1, 0),
			LayoutOrder = i,
			Parent = tabs,
		})
		tab.Activated:Connect(function()
			currentTab = name
			if content then
				content.CanvasPosition = Vector2.zero
			end
			render()
		end)
		tabButtons[name] = tab
	end

	content = Ui.new("ScrollingFrame", {
		Position = UDim2.new(0.45, 12, 0, 108),
		Size = UDim2.new(0.55, -40, 1, -124),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	return frame
end

function Garage.onMessage(callback: (string) -> ())
	messageCallback = callback
end

function Garage.toggle()
	if window then
		window.Visible = not window.Visible
		if window.Visible then
			refreshPreview()
			render()
		end
	end
end

function Garage.start()
	local gui = Ui.new("ScreenGui", {
		Name = "GarageGui",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = build(gui)
	-- re-draw when the choices, unlocks or coins change; the preview follows the rebuilt cart
	player.AttributeChanged:Connect(function(name)
		if name == "Custom" or name == "Cosmetics" or name == "Coins" or string.sub(name, 1, 4) == "Lvl_" then
			render()
		end
	end)
	task.spawn(function()
		local carts = workspace:WaitForChild("Carts")
		carts.ChildAdded:Connect(function(child)
			if child:GetAttribute("Owner") == player.UserId and window and window.Visible then
				task.wait() -- let the parts arrive
				refreshPreview()
			end
		end)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not (window and window.Visible and previewCamera) then
			return
		end
		angle += dt * 0.5
		local target = Vector3.new(0, 2.5, 0)
		previewCamera.CFrame =
			CFrame.lookAt(target + Vector3.new(math.sin(angle) * 22, 9, math.cos(angle) * 22), target)
	end)
end

return Garage
