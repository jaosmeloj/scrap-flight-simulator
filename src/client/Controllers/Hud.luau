--!strict
-- Placeholder HUD: coins/record, live distance/speed, fuel bar, result popup, buttons (Launch, Shop, Back to ramp)
-- and touch flight buttons. Reads player attributes set by the server (Coins, Best, Phase, Distance, Speed, Fuel,
-- FuelMax = rocket, EngineFuel, EngineFuelMax = the tank) and listens to FlightResult. SPACE launches (FlightInput); the LAUNCH button is for touch/mouse.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local FlightInput = require(script.Parent.FlightInput)
local Garage = require(script.Parent.Garage)
local Shop = require(script.Parent.Shop)
local Ui = require(script.Parent.Ui)

local Hud = {}

local player = Players.LocalPlayer

local function attr(name: string, default: any): any
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

function Hud.start()
	local gui = Ui.new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- coins and record (top left)
	local stats = Ui.new("Frame", {
		Name = "Stats",
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(220, 74),
		Parent = gui,
	}, { Ui.corner(12) })
	local coins = Ui.label({
		Name = "Coins",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 36),
		TextColor3 = Ui.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stats,
	})
	local record = Ui.label({
		Name = "Record",
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 0, 24),
		TextColor3 = Ui.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stats,
	})

	-- centre top: launch hint / distance
	local headline = Ui.label({
		Name = "Headline",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(520, 56),
		Parent = gui,
	})
	local subline = Ui.label({
		Name = "Subline",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(420, 30),
		TextColor3 = Ui.Colors.Muted,
		Parent = gui,
	})

	-- fuel bars (bottom centre): engine tank and rocket, each shown only when the cart has it
	local bars = Ui.new("Frame", {
		Name = "FuelBars",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(360, 84),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})
	Ui.label({
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 20),
		Text = "SPACE: ROCKET   W/S: TILT   A/D: STEER",
		LayoutOrder = 0,
		Parent = bars,
	})
	local function fuelBar(name: string, title: string, color: Color3, order: number): (Frame, Frame)
		local back = Ui.new("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = Ui.Colors.Panel,
			BackgroundTransparency = 0.2,
			LayoutOrder = order,
			Parent = bars,
		}, { Ui.corner(8) })
		local fill = Ui.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = color,
			Parent = back,
		}, { Ui.corner(8) })
		Ui.label({ Name = "Title", Size = UDim2.fromScale(1, 1), Text = title, ZIndex = 2, Parent = back })
		return back, fill
	end
	local engineBack, engineFill = fuelBar("Engine", "ENGINE FUEL", Ui.Colors.Green, 1)
	local fuelBack, fuelFill = fuelBar("Rocket", "ROCKET (SPACE)", Ui.Colors.Fuel, 2)

	-- buttons (right)
	local column = Ui.new("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(190, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local launch = Ui.button({
		Name = "LaunchNow",
		Text = "LAUNCH",
		BackgroundColor3 = Ui.Colors.Green,
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = 1,
		Parent = column,
	})
	local shop = Ui.button({
		Name = "Shop",
		Text = "SHOP",
		BackgroundColor3 = Ui.Colors.Gold,
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = 3,
		Parent = column,
	})
	local garage = Ui.button({
		Name = "Garage",
		Text = "GARAGE",
		BackgroundColor3 = Color3.fromRGB(150, 80, 220),
		Size = UDim2.new(1, 0, 0, 50),
		LayoutOrder = 3,
		Parent = column,
	})
	local reset = Ui.button({
		Name = "Reset",
		Text = "BACK TO RAMP",
		BackgroundColor3 = Ui.Colors.Red,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 4,
		Parent = column,
	})

	-- touch flight buttons (bottom right)
	local touch = Ui.new("Frame", {
		Name = "Touch",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(240, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local boost = Ui.button({
		Name = "Boost",
		Text = "BOOST",
		BackgroundColor3 = Ui.Colors.Fuel,
		Position = UDim2.fromOffset(120, 0),
		Size = UDim2.fromOffset(120, 120),
		Parent = touch,
	})
	local tiltUp = Ui.button({ Name = "Up", Text = "UP", Size = UDim2.fromOffset(110, 56), Parent = touch })
	local tiltDown = Ui.button({
		Name = "Down",
		Text = "DOWN",
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.fromOffset(110, 56),
		Parent = touch,
	})
	local function hold(button: GuiButton, on: () -> (), off: () -> ())
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				on()
			end
		end)
		button.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				off()
			end
		end)
	end
	hold(boost, function()
		FlightInput.setRocket(true)
	end, function()
		FlightInput.setRocket(false)
	end)
	hold(tiltUp, function()
		FlightInput.setPitch(1)
	end, function()
		FlightInput.setPitch(0)
	end)
	hold(tiltDown, function()
		FlightInput.setPitch(-1)
	end, function()
		FlightInput.setPitch(0)
	end)

	-- touch steering (bottom left)
	local steer = Ui.new("Frame", {
		Name = "Steer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(240, 90),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local steerLeft =
		Ui.button({ Name = "Left", Text = "LEFT", Size = UDim2.fromOffset(110, 90), Parent = steer })
	local steerRight = Ui.button({
		Name = "Right",
		Text = "RIGHT",
		Position = UDim2.fromOffset(130, 0),
		Size = UDim2.fromOffset(110, 90),
		Parent = steer,
	})
	hold(steerLeft, function()
		FlightInput.setSteer(-1)
	end, function()
		FlightInput.setSteer(0)
	end)
	hold(steerRight, function()
		FlightInput.setSteer(1)
	end, function()
		FlightInput.setSteer(0)
	end)

	-- result popup
	local result = Ui.new("Frame", {
		Name = "Result",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(420, 170),
		BackgroundColor3 = Ui.Colors.Panel,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { Ui.corner(16) })
	local resultTitle = Ui.label({
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 60),
		Parent = result,
	})
	local resultBody = Ui.label({
		Position = UDim2.fromOffset(12, 76),
		Size = UDim2.new(1, -24, 0, 84),
		TextColor3 = Ui.Colors.Gold,
		TextWrapped = true,
		Parent = result,
	})
	local toast = Ui.label({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.fromOffset(460, 34),
		Visible = false,
		Parent = gui,
	})
	local toastToken = 0
	local function notify(text: string)
		toastToken += 1
		local token = toastToken
		toast.Text = text
		toast.Visible = true
		task.delay(2.5, function()
			if toastToken == token then
				toast.Visible = false
			end
		end)
	end

	-- wiring
	launch.Activated:Connect(function()
		Remotes.get(Remotes.Names.LaunchNow):FireServer()
	end)
	reset.Activated:Connect(function()
		Remotes.get(Remotes.Names.ResetCart):FireServer()
	end)
	shop.Activated:Connect(function()
		Shop.toggle()
	end)
	Shop.onMessage(notify)
	garage.Activated:Connect(function()
		Garage.toggle()
	end)
	Garage.onMessage(notify)

	local function refreshStats()
		coins.Text = "Coins " .. Ui.number(attr("Coins", 0))
		record.Text = "Record " .. Ui.number(attr("Best", 0)) .. " studs"
	end
	for _, name in { "Coins", "Best" } do
		player:GetAttributeChangedSignal(name):Connect(refreshStats)
	end
	refreshStats()

	Remotes.get(Remotes.Names.FlightResult).OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		resultTitle.Text = Ui.number(payload.distance or 0)
			.. " studs!"
			.. (if payload.record then "  NEW RECORD" else "")
		local lines = { "+" .. Ui.number(payload.coins or 0) .. " coins" }
		for _, zone in payload.zones or {} do
			table.insert(lines, "Reached " .. zone .. "!")
		end
		if (payload.zoneReward or 0) > 0 then
			table.insert(lines, "+" .. Ui.number(payload.zoneReward) .. " zone reward")
		end
		resultBody.Text = table.concat(lines, "  ")
		result.Visible = true
		task.delay(3, function()
			result.Visible = false
		end)
	end)
	Remotes.get(Remotes.Names.Notify).OnClientEvent:Connect(function(text)
		if typeof(text) == "string" then
			notify(text)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local phase = attr("Phase", "")
		local flying = phase == "Ramp" or phase == "Flight" or phase == "Rolling"
		launch.Visible = phase == "Ready"
		garage.Visible = phase == "Ready"
		touch.Visible = UserInputService.TouchEnabled and flying
		steer.Visible = touch.Visible
		local fuelMax = attr("FuelMax", 0)
		local engineMax = attr("EngineFuelMax", 0)
		fuelBack.Visible = fuelMax > 0
		engineBack.Visible = engineMax > 0
		bars.Visible = flying
		if fuelMax > 0 then
			fuelFill.Size = UDim2.fromScale(math.clamp(attr("Fuel", 0) / fuelMax, 0, 1), 1)
		end
		if engineMax > 0 then
			engineFill.Size = UDim2.fromScale(math.clamp(attr("EngineFuel", 0) / engineMax, 0, 1), 1)
		end
		if flying then
			headline.Text = Ui.number(attr("Distance", 0)) .. " studs"
			subline.Text = Ui.number(attr("Speed", 0)) .. " studs/s"
		elseif phase == "Ready" then
			headline.Text = if UserInputService.KeyboardEnabled
				then "Press SPACE to launch!"
				else "Tap LAUNCH!"
			subline.Text = "In the air: SPACE rocket, W/S tilt, A/D steer"
		else
			headline.Text = ""
			subline.Text = ""
		end
	end)
end

return Hud
