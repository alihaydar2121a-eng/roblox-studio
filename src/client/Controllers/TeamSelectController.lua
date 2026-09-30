--[[
	TeamSelectController
	Deployment screen: choose a side or auto-balance. Shown while the player has
	no team, and reopenable with [M] while waiting to respawn. The server
	validates balance and timing; this UI only sends requests.
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Net.Remotes)

local Ui = require(script.Parent.Parent.UI.Ui)
local Theme = require(script.Parent.Parent.UI.Theme)

local TeamSelectController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gui
local countLabels = {}
local requestRemote

local OVERVIEW = CFrame.lookAt(Vector3.new(-520, 260, -520), Vector3.new(40, 0, 0))

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
		label.Text = ("%d soldiers deployed"):format(teamCount(id))
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

function TeamSelectController.show()
	refreshCounts()
	gui.Enabled = true
	if not isAlive() then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = OVERVIEW
	end
end

function TeamSelectController.hide()
	gui.Enabled = false
end

local function request(teamId)
	requestRemote:FireServer(teamId)
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
	local backdrop = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 12, 14),
		BackgroundTransparency = 0.35,
		Parent = gui,
	})
	Ui.new("UIScale", { Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.2), Parent = backdrop })
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.12, 0),
		Size = UDim2.fromOffset(700, 50),
		Text = "OPERATION IRONFRONT",
		TextSize = 42,
		Parent = backdrop,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.12, 52),
		Size = UDim2.fromOffset(700, 24),
		Text = "Kestrel Valley · Capture and hold objectives A, B and C",
		TextSize = 18,
		TextColor3 = Theme.Muted,
		Font = Enum.Font.Gotham,
		Parent = backdrop,
	})

	local row = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(620, 260),
		BackgroundTransparency = 1,
		Parent = backdrop,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 20),
		}),
	})
	for _, def in ipairs(GameConfig.Teams) do
		local color = Theme.teamColor(def.Id)
		local card = Ui.new("TextButton", {
			Size = UDim2.fromOffset(300, 260),
			BackgroundColor3 = Theme.Panel,
			BackgroundTransparency = 0.1,
			AutoButtonColor = true,
			Text = "",
			Parent = row,
		}, { Ui.corner(10), Ui.stroke(color, 3, 0) })
		Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Parent = card,
		}, { Ui.corner(10) })
		Ui.label({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30), Text = def.ShortName, TextSize = 30, Parent = card })
		Ui.label({ Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 30), Text = def.Name, TextSize = 22, Parent = card })
		countLabels[def.Id] = Ui.label({
			Position = UDim2.fromOffset(0, 140),
			Size = UDim2.new(1, 0, 0, 20),
			Text = "",
			TextSize = 15,
			TextColor3 = Theme.Muted,
			Font = Enum.Font.Gotham,
			Parent = card,
		})
		Ui.label({ Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 30), Text = "DEPLOY", TextSize = 22, TextColor3 = color, Parent = card })
		card.Activated:Connect(function()
			request(def.Id)
		end)
	end

	local auto = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.52, 150),
		Size = UDim2.fromOffset(260, 44),
		BackgroundColor3 = Color3.fromRGB(60, 64, 70),
		Text = "AUTO-BALANCE",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Theme.Text,
		Parent = backdrop,
	}, { Ui.corner(8) })
	auto.Activated:Connect(function()
		request("Auto")
	end)
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(800, 40),
		TextWrapped = true,
		Text = "PC: WASD move · Mouse aim · LMB fire · R reload · Alt free cursor · Tab scoreboard\nMobile: on-screen FIRE / R buttons · aim with the screen centre",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = Theme.Muted,
		Parent = backdrop,
	})
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
		end
	end)

	player:GetPropertyChangedSignal("Team"):Connect(function()
		if hasTeam() then
			TeamSelectController.hide()
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
