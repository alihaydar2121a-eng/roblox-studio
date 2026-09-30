--[[
	HudController
	Builds and updates the in-match HUD: tickets + timer, objective strip,
	capture progress, health, ammo, crosshair, hitmarkers, damage direction,
	kill feed, notifications, respawn countdown and round-end banner.
	All match data is read from ReplicatedStorage.GameState attributes.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local MapLayout = require(Shared.Config.MapLayout)
local Remotes = require(Shared.Net.Remotes)

local Ui = require(script.Parent.Parent.UI.Ui)
local Theme = require(script.Parent.Parent.UI.Theme)
local WeaponController = require(script.Parent.WeaponController)
local SoundPlayer = require(script.Parent.SoundPlayer)

local HudController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local gameState, zonesFolder
local gui, refs = nil, {}
local teamIds = {}
for _, def in ipairs(GameConfig.Teams) do
	table.insert(teamIds, def.Id)
end

local function panel(props, children)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or Theme.PanelTransparency
	props.BorderSizePixel = 0
	table.insert(children, Ui.corner(6))
	return Ui.new("Frame", props, children)
end

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function myTeamId()
	local team = player.Team
	return (team and not player.Neutral) and team:GetAttribute("TeamId") or nil
end

------------------------------------------------------------------ build

local function buildTop()
	local top = Ui.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(420, 96),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.tickets = {}
	for i, id in ipairs(teamIds) do
		local box = panel({
			Size = UDim2.fromOffset(150, 40),
			Position = i == 1 and UDim2.fromOffset(0, 0) or UDim2.new(1, -150, 0, 0),
			Parent = top,
		}, {})
		Ui.new("Frame", {
			Size = UDim2.new(0, 6, 1, 0),
			Position = i == 1 and UDim2.fromOffset(0, 0) or UDim2.new(1, -6, 0, 0),
			BackgroundColor3 = Theme.teamColor(id),
			BorderSizePixel = 0,
			Parent = box,
		})
		Ui.label({
			Size = UDim2.new(1, -16, 0, 14),
			Position = UDim2.fromOffset(8, 3),
			Text = Theme.TeamShort[id],
			TextSize = 12,
			TextColor3 = Theme.teamColor(id),
			TextXAlignment = i == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			Parent = box,
		})
		refs.tickets[id] = Ui.label({
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 16),
			Text = "0",
			TextSize = 22,
			TextXAlignment = i == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right,
			Parent = box,
		})
	end
	local timerBox = panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(100, 40),
		Parent = top,
	}, {})
	refs.timer = Ui.label({ Size = UDim2.fromScale(1, 1), Text = "20:00", TextSize = 22, Parent = timerBox })

	-- Objective strip
	local strip = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(160, 44),
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.Name,
		}),
	})
	refs.zoneChips = {}
	for _, config in ipairs(zonesFolder:GetChildren()) do
		local chip = panel({ Name = config.Name, Size = UDim2.fromOffset(44, 44), ClipsDescendants = true, Parent = strip }, {})
		local fill = Ui.new("Frame", {
			Name = "Fill",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BorderSizePixel = 0,
			BackgroundColor3 = Theme.Neutral,
			BackgroundTransparency = 0.2,
			Parent = chip,
		})
		local letter = Ui.label({ Size = UDim2.fromScale(1, 1), Text = config.Name, TextSize = 22, ZIndex = 2, Parent = chip })
		local stroke = Ui.stroke(Theme.Neutral, 2, 0)
		stroke.Parent = chip
		refs.zoneChips[config.Name] = { chip = chip, fill = fill, letter = letter, stroke = stroke, config = config }
	end
end

local function buildBottom()
	-- Health (bottom-left)
	local health = panel({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(240, 34),
		Parent = gui,
	}, { Ui.padding(6) })
	local bar = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(60, 60, 60),
		BorderSizePixel = 0,
		Parent = health,
	}, { Ui.corner(4) })
	refs.healthFill = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(230, 230, 220),
		BorderSizePixel = 0,
		Parent = bar,
	}, { Ui.corner(4) })
	refs.healthText = Ui.label({ Size = UDim2.fromScale(1, 1), Text = "100", TextSize = 16, ZIndex = 2, TextColor3 = Color3.fromRGB(20, 20, 20), TextStrokeTransparency = 1, Parent = bar })
	refs.health = health

	-- Ammo (bottom-right)
	local ammo = panel({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(200, 64),
		Parent = gui,
	}, { Ui.padding(8) })
	refs.weaponName = Ui.label({ Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 14, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Right, Parent = ammo })
	refs.ammoText = Ui.label({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30), Text = "", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Right, Parent = ammo })
	refs.ammo = ammo
end

local function buildCenter()
	-- Crosshair: four ticks that spread with weapon bloom.
	local cross = Ui.new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	refs.crossTicks = {}
	for i = 0, 3 do
		local vertical = i % 2 == 0
		local tick = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = vertical and UDim2.fromOffset(2, 8) or UDim2.fromOffset(8, 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = cross,
		}, { Ui.stroke(Color3.new(0, 0, 0), 1, 0.5) })
		refs.crossTicks[i] = tick
	end
	Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = cross,
	})
	refs.crosshair = cross

	-- Hitmarker: an X of four short bars.
	local hit = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	refs.hitBars = {}
	for i = 0, 3 do
		local angle = 45 + i * 90
		local r = 9
		local bar = Ui.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(math.rad(angle)) * r, 0.5, math.sin(math.rad(angle)) * r),
			Size = UDim2.fromOffset(8, 2),
			Rotation = angle,
			BorderSizePixel = 0,
			BackgroundColor3 = Theme.Hit,
			Parent = hit,
		})
		table.insert(refs.hitBars, bar)
	end
	refs.hitmarker = hit

	-- Damage direction indicator: a chevron orbiting the screen centre.
	refs.damageArrow = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Text = "▲",
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 190, 120),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})

	-- Capture progress (shown while standing in an objective)
	local capture = panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(280, 46),
		Visible = false,
		Parent = gui,
	}, { Ui.padding(6) })
	refs.captureText = Ui.label({ Size = UDim2.new(1, 0, 0, 16), Text = "", TextSize = 14, Parent = capture })
	local track = Ui.new("Frame", {
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Color3.fromRGB(60, 60, 60),
		BorderSizePixel = 0,
		Parent = capture,
	}, { Ui.corner(4) })
	refs.captureFill = Ui.new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track }, { Ui.corner(4) })
	refs.capture = capture

	-- Centre messages: respawn countdown, notifications, round end.
	refs.respawn = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(500, 60),
		Text = "",
		TextSize = 26,
		Visible = false,
		Parent = gui,
	})
	refs.notice = Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(600, 28),
		Text = "",
		TextSize = 18,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Parent = gui,
	})
	local banner = panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(520, 110),
		Visible = false,
		Parent = gui,
	}, {})
	refs.bannerTitle = Ui.label({ Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 10), Text = "", TextSize = 34, Parent = banner })
	refs.bannerSub = Ui.label({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 70), Text = "", TextSize = 16, TextColor3 = Theme.Muted, Parent = banner })
	refs.banner = banner
end

local function buildKillFeed()
	refs.killFeed = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 70),
		Size = UDim2.fromOffset(320, 180),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

------------------------------------------------------------------ behaviour

local hitToken = 0
local function showHitmarker(info)
	hitToken += 1
	local token = hitToken
	local color = info.killed and Theme.Kill or (info.headshot and Theme.Headshot or Theme.Hit)
	for _, bar in ipairs(refs.hitBars) do
		bar.BackgroundColor3 = color
	end
	refs.hitmarker.Size = info.killed and UDim2.fromOffset(36, 36) or UDim2.fromOffset(28, 28)
	refs.hitmarker.Visible = true
	SoundPlayer.play("Hitmarker")
	task.delay(info.killed and 0.3 or 0.12, function()
		if token == hitToken then
			refs.hitmarker.Visible = false
		end
	end)
end

local damageFrom, damageTime = nil, 0
local function onDamage(info)
	if type(info) == "table" and typeof(info.from) == "Vector3" then
		damageFrom, damageTime = info.from, os.clock()
	end
end

local function escapeRich(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local feedOrder = 0
local function addKillFeed(entry)
	if type(entry) ~= "table" then
		return
	end
	feedOrder += 1
	local line = panel({ Size = UDim2.fromOffset(320, 24), LayoutOrder = -feedOrder, Parent = refs.killFeed }, {})
	local killerColor = Theme.teamColor(entry.killerTeam)
	local victimColor = Theme.teamColor(entry.victimTeam)
	local text
	if entry.killer then
		text = ('<font color="#%s">%s</font>  %s  <font color="#%s">%s</font>'):format(
			killerColor:ToHex(), escapeRich(entry.killer), entry.headshot and "[HEADSHOT]" or "›", victimColor:ToHex(), escapeRich(entry.victim)
		)
	else
		text = ('<font color="#%s">%s</font> was taken out'):format(victimColor:ToHex(), escapeRich(entry.victim))
	end
	Ui.label({ Size = UDim2.fromScale(1, 1), Text = text, RichText = true, TextSize = 14, Parent = line })
	local children = {}
	for _, child in ipairs(refs.killFeed:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 5 then
		table.sort(children, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	task.delay(6, function()
		if line.Parent then
			line:Destroy()
		end
	end)
end

local noticeToken = 0
local function notify(text, kind)
	if type(text) ~= "string" then
		return
	end
	noticeToken += 1
	local token = noticeToken
	refs.notice.Text = text
	refs.notice.TextColor3 = kind == "Warning" and Theme.Warning or Theme.Text
	refs.notice.TextTransparency = 0
	refs.notice.TextStrokeTransparency = 0.5
	if kind == "Captured" then
		SoundPlayer.play("Capture")
	end
	task.delay(3, function()
		if token == noticeToken then
			TweenService:Create(refs.notice, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end
HudController.notify = notify

local function updateZoneChip(chipRefs)
	local config = chipRefs.config
	local owner = config:GetAttribute("Owner") or ""
	local control = config:GetAttribute("Control") or 0
	local contested = config:GetAttribute("Contested")
	local capturing = config:GetAttribute("Capturing") or ""
	-- Fill shows the leading side's share of control.
	local leadTeam = control > 0 and teamIds[1] or (control < 0 and teamIds[2] or nil)
	chipRefs.fill.Size = UDim2.fromScale(1, math.abs(control))
	chipRefs.fill.BackgroundColor3 = Theme.teamColor(leadTeam)
	chipRefs.stroke.Color = contested and Theme.Warning or Theme.teamColor(owner ~= "" and owner or nil)
	chipRefs.letter.TextColor3 = (capturing ~= "" or contested) and Theme.Warning or Theme.Text
end

local function updateFrame()
	local now = workspace:GetServerTimeNow()
	local phase = gameState:GetAttribute("Phase")
	local endsAt = gameState:GetAttribute("EndsAt") or now

	for _, id in ipairs(teamIds) do
		refs.tickets[id].Text = tostring(gameState:GetAttribute("Tickets_" .. id) or 0)
	end
	refs.timer.Text = formatTime(phase == "Active" and endsAt - now or 0)

	-- Round end banner
	if phase == "Ended" then
		local winner = gameState:GetAttribute("Winner")
		refs.banner.Visible = true
		if winner == "Draw" then
			refs.bannerTitle.Text = "DRAW"
			refs.bannerTitle.TextColor3 = Theme.Text
		else
			refs.bannerTitle.Text = string.upper(Theme.TeamNames[winner] or "?") .. " WINS"
			refs.bannerTitle.TextColor3 = Theme.teamColor(winner)
		end
		refs.bannerSub.Text = ("Next battle in %d"):format(math.max(0, math.ceil(endsAt - now)))
	else
		refs.banner.Visible = false
	end

	-- Character-dependent HUD
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local alive = humanoid ~= nil and humanoid.Health > 0
	refs.health.Visible = alive
	if alive then
		local fraction = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		refs.healthFill.Size = UDim2.fromScale(fraction, 1)
		refs.healthFill.BackgroundColor3 = fraction > 0.35 and Color3.fromRGB(230, 230, 220) or Color3.fromRGB(255, 170, 90)
		refs.healthText.Text = tostring(math.ceil(humanoid.Health))
	end

	local weapon = WeaponController.getWeapon()
	refs.ammo.Visible = alive and weapon ~= nil
	refs.crosshair.Visible = alive and weapon ~= nil
	if weapon then
		refs.weaponName.Text = weapon.DisplayName
		if player:GetAttribute("Reloading") then
			refs.ammoText.Text = "RELOADING"
		else
			refs.ammoText.Text = ("%d / %d"):format(WeaponController.getAmmo(), player:GetAttribute("Reserve") or 0)
		end
	end

	-- Respawn countdown
	local respawnAt = player:GetAttribute("RespawnAt")
	if respawnAt and not alive and phase == "Active" then
		refs.respawn.Visible = true
		refs.respawn.Text = ("Redeploying in %d   ·   [M] change team"):format(math.max(0, math.ceil(respawnAt - now)))
	else
		refs.respawn.Visible = false
	end

	-- Capture progress for the zone we're standing in
	local inZone = nil
	if alive and root then
		for _, config in ipairs(zonesFolder:GetChildren()) do
			local pos, radius = config:GetAttribute("Position"), config:GetAttribute("Radius")
			if pos and radius then
				local offset = root.Position - pos
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) <= GameConfig.Capture.HeightTolerance then
					inZone = config
					break
				end
			end
		end
	end
	refs.capture.Visible = inZone ~= nil
	if inZone then
		local control = inZone:GetAttribute("Control") or 0
		local mine = myTeamId()
		local sign = mine == teamIds[1] and 1 or -1
		local mineControl = control * sign -- -1..1 from my perspective
		refs.captureFill.Size = UDim2.fromScale((mineControl + 1) / 2, 1)
		refs.captureFill.BackgroundColor3 = Theme.teamColor(mine)
		local label
		if inZone:GetAttribute("Contested") then
			label = "CONTESTED"
		elseif inZone:GetAttribute("Owner") == mine then
			label = "SECURED"
		elseif inZone:GetAttribute("Capturing") == mine then
			label = "CAPTURING"
		else
			label = "HOLD TO CAPTURE"
		end
		refs.captureText.Text = ("%s — %s %s"):format(inZone.Name, inZone:GetAttribute("Name") or "", label)
	end

	-- Damage direction
	local arrow = refs.damageArrow
	local age = os.clock() - damageTime
	if damageFrom and age < 1.2 and root then
		local toSource = damageFrom - root.Position
		local look = camera.CFrame.LookVector
		local angle = math.atan2(toSource.X, toSource.Z) - math.atan2(look.X, look.Z)
		local r = 90
		arrow.Position = UDim2.new(0.5, -math.sin(angle) * r, 0.5, -math.cos(angle) * r)
		arrow.Rotation = -math.deg(angle)
		arrow.TextTransparency = age / 1.2
	else
		arrow.TextTransparency = 1
	end
end

local function onFired(spreadDegrees)
	local gap = 6 + spreadDegrees * 6
	refs.crossTicks[0].Position = UDim2.new(0.5, 0, 0.5, -gap)
	refs.crossTicks[2].Position = UDim2.new(0.5, 0, 0.5, gap)
	refs.crossTicks[1].Position = UDim2.new(0.5, gap, 0.5, 0)
	refs.crossTicks[3].Position = UDim2.new(0.5, -gap, 0.5, 0)
end

function HudController.setVisible(visible)
	if gui then
		gui.Enabled = visible
	end
end

function HudController.start()
	gameState = ReplicatedStorage:WaitForChild("GameState")
	zonesFolder = gameState:WaitForChild("Zones")
	-- Zones are created before the match starts; wait until all are present.
	while #zonesFolder:GetChildren() < #MapLayout.Zones do
		zonesFolder.ChildAdded:Wait()
	end

	gui = Ui.new("ScreenGui", {
		Name = "IronfrontHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local scale = Ui.new("UIScale", { Parent = gui })
	local function rescale()
		scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.65, 1.25)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	buildTop()
	buildBottom()
	buildCenter()
	buildKillFeed()
	onFired(0)

	for _, chipRefs in pairs(refs.zoneChips) do
		chipRefs.config.AttributeChanged:Connect(function()
			updateZoneChip(chipRefs)
		end)
		updateZoneChip(chipRefs)
	end

	Remotes.get("HitConfirm").OnClientEvent:Connect(function(info)
		if type(info) == "table" then
			showHitmarker(info)
		end
	end)
	Remotes.get("DamageTaken").OnClientEvent:Connect(onDamage)
	Remotes.get("KillFeed").OnClientEvent:Connect(addKillFeed)
	Remotes.get("Notify").OnClientEvent:Connect(notify)
	WeaponController.Fired:Connect(onFired)

	local lastPhase = gameState:GetAttribute("Phase")
	gameState:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = gameState:GetAttribute("Phase")
		if phase == "Ended" and lastPhase ~= "Ended" then
			SoundPlayer.play("Victory")
		end
		lastPhase = phase
	end)

	RunService.RenderStepped:Connect(updateFrame)
end

return HudController
