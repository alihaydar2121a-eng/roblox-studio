--[[
	ObjectiveMarkers
	World-space objective indicators (letter + distance) that stay visible at
	any range. Anchors are local-only parts created from replicated zone
	positions, so they work even when the objective geometry is not streamed in.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ui = require(script.Parent.Parent.UI.Ui)
local Theme = require(script.Parent.Parent.UI.Theme)

local ObjectiveMarkers = {}

local player = Players.LocalPlayer

function ObjectiveMarkers.start()
	local zones = ReplicatedStorage:WaitForChild("GameState"):WaitForChild("Zones")
	local folder = Instance.new("Folder")
	folder.Name = "ObjectiveMarkers"
	folder.Parent = workspace

	local markers = {}
	local function addMarker(config)
		local pos = config:GetAttribute("Position")
		if not pos then
			return
		end
		local anchor = Ui.new("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.one,
			CFrame = CFrame.new(pos + Vector3.new(0, 26, 0)),
			Parent = folder,
		})
		local billboard = Ui.new("BillboardGui", {
			Adornee = anchor,
			AlwaysOnTop = true,
			LightInfluence = 0,
			Size = UDim2.fromOffset(60, 56),
			MaxDistance = 5000,
			Parent = anchor,
		})
		local diamond = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			BackgroundColor3 = Theme.Panel,
			BackgroundTransparency = 0.3,
			Parent = billboard,
		}, { Ui.corner(17) })
		local stroke = Ui.stroke(Theme.Neutral, 2, 0)
		stroke.Parent = diamond
		local letter = Ui.label({ Size = UDim2.fromScale(1, 1), Text = config.Name, TextSize = 18, Parent = diamond })
		local distance = Ui.label({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 18),
			Text = "",
			TextSize = 13,
			Parent = billboard,
		})
		local function refresh()
			local owner = config:GetAttribute("Owner") or ""
			stroke.Color = config:GetAttribute("Contested") and Theme.Warning or Theme.teamColor(owner ~= "" and owner or nil)
			letter.TextColor3 = Theme.teamColor(owner ~= "" and owner or nil)
		end
		config.AttributeChanged:Connect(refresh)
		refresh()
		markers[config] = { anchor = anchor, distance = distance }
	end

	for _, config in ipairs(zones:GetChildren()) do
		addMarker(config)
	end
	zones.ChildAdded:Connect(addMarker)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		for _, marker in pairs(markers) do
			if root then
				marker.distance.Text = ("%dm"):format(math.floor((marker.anchor.Position - root.Position).Magnitude * 0.28))
			else
				marker.distance.Text = ""
			end
		end
	end)
end

return ObjectiveMarkers
