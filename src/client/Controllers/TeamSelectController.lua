--[[
	TeamSelectController
	Compact deployment panel docked to the left edge over a slow cinematic orbit
	of Millbrook. Shown while the player has no team, reopenable with [M] while
	redeploying. The server validates balance and timing; this UI only sends
	requests.
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local MapLayout = require(Shared.Config.MapLayout)
local Remotes = require(Shared.Net.Remotes)

local Ui = require(script.Parent.Parent.UI.Ui)
local Theme = require(script.Parent.Parent.UI.Theme)

local TeamSelectController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gui, panel, status
local countLabels = {}
local requestRemote
local orbitAngle = math.rad(215)
local orbitConnection

local PANEL_WIDTH = 330

local function teamCount(teamId)
	for _, team in ipairs(Teams:GetTeams()) do
		if team:GetAttribute("TeamId") == teamId then
			return #team:GetPlayers()
		end
	end
	return 0
end

local function refreshCounts()
	for id, label in pairs(countLabels) do
		local n = teamCount(id)
		label.Text = ("%d deployed"):format(n)
	end
end

local function hasTeam()
	return player.Team ~= nil and not player.Neutral
end

local function isAlive()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- Orbit focus: objective B's replicated ground position, else the layout centre.
local function focusPoint()
	local state = ReplicatedStorage:FindFirstChild("GameState")
	local zones = state and state:FindFirstChild("Zones")
	local b = zones and zones:FindFirstChild("B")
	local pos = b and b:GetAttribute("Position")
	if pos then
		return pos
	end
	local c = MapLayout.Sites.Village.Center
	return Vector3.new(c[1], 14, c[2])
end

local function startOrbit()
	if orbitConnection then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		orbitAngle += dt * 0.025
		local focus = focusPoint()
		local radius, height = 300, 150
		local eye = focus + Vector3.new(math.cos(orbitAngle) * radius, height, math.sin(orbitAngle) * radius)
		-- Aim slightly below the focus so the frame is mostly battlefield, not sky.
		camera.CFrame = CFrame.lookAt(eye, focus - Vector3.new(0, 25, 0))
	end)
end

local function stopOrbit()
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end
end

function TeamSelectController.show()
	refreshCounts()
	gui.Enabled = true
	panel.Position = UDim2.new(0, -PANEL_WIDTH, 0, 0)
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
	if not isAlive() then
		startOrbit()
	end
end

function TeamSelectController.hide()
	gui.Enabled = false
	stopOrbit()
end

local function request(teamId)
	requestRemote:FireServer(teamId)
end

local function hover(button, base, over)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = over }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
end

local function build()
	gui = Ui.new("ScreenGui", {
		Name = "IronfrontDeploy",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = Ui.new("UIScale", { Parent = gui })
	local function rescale()
		scale.Scale = math.clamp(camera.ViewportSize.Y / 820, 0.62, 1.1)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Left-docked translucent column; the battlefield stays visible to the right.
	panel = Ui.new("Frame", {
		Name = "Panel",
		Size = UDim2.new(0, PANEL_WIDTH, 1, 0),
		BackgroundColor3 = Color3.fromRGB(12, 14, 16),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		Ui.new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 0.9) }),
		}),
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 26), PaddingTop = UDim.new(0, 70), PaddingBottom = UDim.new(0, 20) }),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Ui.label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), Text = "OPERATION IRONFRONT", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	Ui.label({
		LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), Text = "KESTREL VALLEY  ·  CAPTURE A · B · C", TextSize = 13, Font = Enum.Font.GothamMedium,
		TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
	})
	Ui.new("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(80, 84, 88), BorderSizePixel = 0, Parent = panel })
	Ui.label({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 16), Text = "CHOOSE YOUR SIDE", TextSize = 12, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

	for index, def in ipairs(GameConfig.Teams) do
		local color = Theme.teamColor(def.Id)
		local base = Color3.fromRGB(30, 33, 36)
		local card = Ui.new("TextButton", {
			LayoutOrder = 4 + index,
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundColor3 = base,
			AutoButtonColor = false,
			Text = "",
			Parent = panel,
		}, { Ui.corner(6), Ui.stroke(color, 1, 0.55) })
		hover(card, base, Color3.fromRGB(44, 48, 52))
		Ui.new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = card }, { Ui.corner(3) })
		Ui.label({ Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -110, 0, 22), Text = def.Name, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		countLabels[def.Id] = Ui.label({
			Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -110, 0, 18), Text = "", TextSize = 13, Font = Enum.Font.GothamMedium,
			TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
		})
		Ui.label({
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(84, 30), Text = "DEPLOY ›",
			TextSize = 15, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right, Parent = card,
		})
		card.Activated:Connect(function()
			request(def.Id)
		end)
	end

	local autoBase = Color3.fromRGB(58, 62, 68)
	local auto = Ui.new("TextButton", {
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = autoBase,
		AutoButtonColor = false,
		Text = "AUTO-BALANCE",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Theme.Text,
		Parent = panel,
	}, { Ui.corner(6) })
	hover(auto, autoBase, Color3.fromRGB(78, 84, 92))
	auto.Activated:Connect(function()
		request("Auto")
	end)

	status = Ui.label({
		LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 18), Text = "", TextSize = 13, Font = Enum.Font.GothamMedium,
		TextColor3 = Theme.Warning, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 22, 1, -18),
		Size = UDim2.fromOffset(PANEL_WIDTH - 40, 64),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "PC  WASD move · Mouse aim · LMB fire · R reload · Alt cursor · Tab scores\nPAD  R2 fire · X reload\nMOBILE  FIRE / R buttons · aim at screen centre",
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.Muted,
		Parent = gui,
	})
end

local function refreshStatus()
	local state = ReplicatedStorage:FindFirstChild("GameState")
	local mapStatus = state and state:GetAttribute("MapStatus")
	status.Text = (mapStatus ~= "Ready") and "Preparing battlefield…" or ""
end

function TeamSelectController.start()
	requestRemote = Remotes.get("RequestTeam")
	build()

	for _, team in ipairs(Teams:GetTeams()) do
		team.PlayerAdded:Connect(refreshCounts)
		team.PlayerRemoved:Connect(refreshCounts)
	end
	Teams.ChildAdded:Connect(function(team)
		if team:IsA("Team") then
			team.PlayerAdded:Connect(refreshCounts)
			team.PlayerRemoved:Connect(refreshCounts)
			refreshCounts()
		end
	end)
	local state = ReplicatedStorage:WaitForChild("GameState")
	state:GetAttributeChangedSignal("MapStatus"):Connect(refreshStatus)
	refreshStatus()

	player:GetPropertyChangedSignal("Team"):Connect(function()
		if hasTeam() and isAlive() then
			TeamSelectController.hide()
		elseif hasTeam() then
			status.Text = "Deploying…"
		end
	end)
	player.CharacterAdded:Connect(function()
		TeamSelectController.hide()
		camera.CameraType = Enum.CameraType.Custom
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.M then
			return
		end
		if gui.Enabled and hasTeam() then
			TeamSelectController.hide()
		elseif not isAlive() then
			TeamSelectController.show()
		end
	end)

	if not hasTeam() then
		TeamSelectController.show()
	end
end

return TeamSelectController
