--!strict
-- Tiny helpers to build the placeholder UI in code (phase 3 replaces the look, not the wiring).
local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(28, 32, 44),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(190, 196, 210),
	Gold = Color3.fromRGB(255, 208, 64),
	Green = Color3.fromRGB(72, 196, 96),
	Red = Color3.fromRGB(220, 68, 60),
	Blue = Color3.fromRGB(64, 140, 232),
	Fuel = Color3.fromRGB(255, 140, 40),
}

function Ui.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: number?): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Ui.stroke(thickness: number?): UIStroke
	return Ui.new(
		"UIStroke",
		{ Thickness = thickness or 2, Color = Color3.fromRGB(0, 0, 0), Transparency = 0.4 }
	)
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Ui.Colors.Text,
		TextScaled = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local label = Ui.new("TextLabel", defaults)
	Ui.stroke(1.5).Parent = label
	return label
end

function Ui.button(props: { [string]: any }): TextButton
	local defaults = {
		BackgroundColor3 = Ui.Colors.Blue,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Ui.Colors.Text,
		TextScaled = true,
		AutoButtonColor = true,
		-- text outline from the text itself: the UIStroke below draws the BORDER only (a "Contextual" stroke on a
		-- TextButton outlines the letters, and a thick selection stroke turned the text into a blob)
		TextStrokeTransparency = 0.6,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Ui.new("TextButton", defaults)
	Ui.corner(10).Parent = button
	local border = Ui.stroke(2)
	border.Name = "Border"
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = button
	Ui.new("UIPadding", {
		PaddingTop = UDim.new(0.15, 0),
		PaddingBottom = UDim.new(0.15, 0),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = button,
	})
	return button
end

-- 1234567 -> "1,234,567"
function Ui.number(value: number): string
	local text = tostring(math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

return Ui
