--!strict
-- Placeholder shop window: one row per upgrade (level, effect, next price, BUY) and one per cart (price, BUY /
-- EQUIP). Buying goes through the BuyUpgrade/BuyCart RemoteFunctions; the server checks everything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CartsConfig = require(ReplicatedStorage.Shared.Config.Carts)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local UpgradesConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local UpgradeRules = require(ReplicatedStorage.Shared.Rules.Upgrades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local Shop = {}

local player = Players.LocalPlayer
local window: Frame? = nil
local messageCallback: ((string) -> ())? = nil
local refreshers: { () -> () } = {}

local function coins(): number
	return player:GetAttribute("Coins") or 0
end

local function effectText(key: string, level: number): string
	local part = UpgradesConfig.Parts[key]
	if key == "Engine" then
		return "Thrust " .. part.ThrustPerLevel * level
	elseif key == "Wings" then
		local lift = 1 - (1 - part.BaseLift) * part.LiftKeep ^ level
		return string.format("Glide %d%%", math.floor(lift * 100 + 0.5))
	elseif key == "Rocket" then
		return string.format("Boost %d, fuel %.1fs", part.ThrustPerLevel * level, part.FuelPerLevel * level)
	elseif key == "FuelTank" then
		return string.format("Engine fuel %.1fs", part.BaseSeconds + part.SecondsPerLevel * level)
	end
	return "Ramp push +" .. part.PushPerLevel * level
end

local function say(text: string)
	if messageCallback then
		messageCallback(text)
	end
end

local function build(gui: ScreenGui): Frame
	local frame = Ui.new("Frame", {
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 470),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(16) })
	Ui.label({
		Text = "SHOP",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -90, 0, 40),
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
	local list = Ui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 1, -72),
		BackgroundTransparency = 1,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, { Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local order = 0
	local function row(title: string, icon: string): (TextLabel, TextLabel, TextButton)
		order += 1
		local item = Ui.new("Frame", {
			Size = UDim2.new(1, -12, 0, 72),
			BackgroundColor3 = Color3.fromRGB(44, 50, 66),
			LayoutOrder = order,
			Parent = list,
		}, { Ui.corner(10) })
		local textX = 12
		if icon ~= "" then
			Ui.new("ImageLabel", {
				Name = "Icon",
				Image = icon,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.fromOffset(64, 64),
				ScaleType = Enum.ScaleType.Fit,
				Parent = item,
			})
			textX = 78
		end
		Ui.label({
			Text = title,
			Position = UDim2.fromOffset(textX, 8),
			Size = UDim2.new(0.55, 0, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = item,
		})
		local info = Ui.label({
			Position = UDim2.fromOffset(textX, 40),
			Size = UDim2.new(0.6, -textX, 0, 22),
			TextColor3 = Ui.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = item,
		})
		local level = Ui.label({
			Position = UDim2.new(0.55, 0, 0, 8),
			Size = UDim2.new(0.15, 0, 0, 26),
			TextColor3 = Ui.Colors.Gold,
			Parent = item,
		})
		local buy = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(150, 46),
			BackgroundColor3 = Ui.Colors.Green,
			Parent = item,
		})
		return info, level, buy
	end

	for _, key in UpgradesConfig.Order do
		local part = UpgradesConfig.Parts[key]
		local info, levelLabel, buy = row(part.Name, Icons[key] or "")
		local function refresh()
			local level = player:GetAttribute("Lvl_" .. key) or 0
			local price = UpgradeRules.cost(UpgradesConfig, key, level)
			levelLabel.Text = string.format("Lv %d/%d", level, UpgradesConfig.MaxLevel)
			if price then
				info.Text = effectText(key, level) .. "  ->  " .. effectText(key, level + 1)
				buy.Text = Ui.number(price)
				buy.BackgroundColor3 = if coins() >= price
					then Ui.Colors.Green
					else Color3.fromRGB(110, 110, 120)
			else
				info.Text = effectText(key, level)
				buy.Text = "MAX"
				buy.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
			end
		end
		buy.Activated:Connect(function()
			local ok, message = Remotes.getFunction(Remotes.FunctionNames.BuyUpgrade):InvokeServer(key)
			say(if ok then message else (message or "Can't buy"))
		end)
		table.insert(refreshers, refresh)
	end

	for _, id in CartsConfig.Order do
		local cart = CartsConfig.List[id]
		local info, levelLabel, buy = row(cart.Name, Icons["Cart_" .. id] or "")
		info.Text = string.format(
			"Coins x%.2g, drag x%.2f, lift +%.2f",
			1 + cart.CoinBonus,
			cart.Drag,
			cart.LiftBonus
		)
		local function refresh()
			local owned = table.find(string.split(player:GetAttribute("OwnedCarts") or "", ","), id) ~= nil
			local equipped = player:GetAttribute("Cart") == id
			levelLabel.Text = if equipped then "IN USE" elseif owned then "OWNED" else ""
			if equipped then
				buy.Text = "EQUIPPED"
				buy.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
			elseif owned then
				buy.Text = "EQUIP"
				buy.BackgroundColor3 = Ui.Colors.Blue
			else
				buy.Text = Ui.number(cart.Price)
				buy.BackgroundColor3 = if coins() >= cart.Price
					then Ui.Colors.Green
					else Color3.fromRGB(110, 110, 120)
			end
		end
		buy.Activated:Connect(function()
			if player:GetAttribute("Cart") == id then
				return
			end
			local ok, message = Remotes.getFunction(Remotes.FunctionNames.BuyCart):InvokeServer(id)
			say(if ok then message else (message or "Can't buy"))
		end)
		table.insert(refreshers, refresh)
	end
	return frame
end

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

function Shop.onMessage(callback: (string) -> ())
	messageCallback = callback
end

function Shop.toggle()
	if window then
		window.Visible = not window.Visible
		refreshAll()
	end
end

function Shop.start()
	local gui = Ui.new("ScreenGui", {
		Name = "ShopGui",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})
	window = build(gui)
	player.AttributeChanged:Connect(refreshAll)
	refreshAll()
end

return Shop
