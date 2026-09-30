local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)
local toColor = require(ReplicatedStorage.Shared.Util.Color)

local Theme = {
	Panel = Color3.fromRGB(20, 22, 26),
	PanelTransparency = 0.25,
	Text = Color3.fromRGB(240, 240, 236),
	Muted = Color3.fromRGB(170, 172, 176),
	Neutral = Color3.fromRGB(200, 200, 200),
	Warning = Color3.fromRGB(255, 196, 80),
	Hit = Color3.fromRGB(255, 255, 255),
	Headshot = Color3.fromRGB(255, 214, 90),
	Kill = Color3.fromRGB(255, 120, 90),
	TeamColors = {},
	TeamNames = {},
	TeamShort = {},
}

for _, def in ipairs(GameConfig.Teams) do
	Theme.TeamColors[def.Id] = toColor(def.UiColor)
	Theme.TeamNames[def.Id] = def.Name
	Theme.TeamShort[def.Id] = def.ShortName
end

function Theme.teamColor(teamId)
	return Theme.TeamColors[teamId] or Theme.Neutral
end

return Theme
