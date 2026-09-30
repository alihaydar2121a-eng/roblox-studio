--[[
	Ui
	Tiny declarative helper: Ui.new(className, props, children).
	Props may include Parent; children is an array of instances.
]]

local Ui = {}

function Ui.new(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

function Ui.corner(radius)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

function Ui.stroke(color, thickness, transparency)
	return Ui.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 1,
		Transparency = transparency or 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px)
	local u = UDim.new(0, px)
	return Ui.new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

function Ui.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(240, 240, 236),
		TextStrokeTransparency = 0.6,
		TextSize = 16,
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	return Ui.new("TextLabel", defaults)
end

return Ui
