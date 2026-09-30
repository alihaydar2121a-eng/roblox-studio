--[[
	SoundPlayer
	Plays configured placeholder sounds; entries with empty IDs are skipped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.SoundConfig)

local SoundPlayer = {}

function SoundPlayer.play(name, position)
	local def = SoundConfig[name]
	if not def or def.Id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	if position then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = workspace.Terrain
		sound.Parent = holder
		sound.Ended:Once(function()
			holder:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	sound:Play()
end

return SoundPlayer
