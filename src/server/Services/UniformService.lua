--[[
	UniformService
	Dresses R6 characters as Ashford Coalition or Varn Directorate soldiers:
	uniform body colours via HumanoidDescription (player clothing and
	accessories removed; head colour and face kept), plus the faction kit from
	Shared.Config.GearModels welded to each limb. Imported Blender gear under
	ReplicatedStorage.ImportedAssets.Gear.<Team>.<Piece> is used when present.
	Everything is cosmetic: massless, no collision, not queryable, so combat
	hit detection still uses the standard R6 body parts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GearModels = require(Shared.Config.GearModels)
local ModelBuilder = require(Shared.Assets.ModelBuilder)

local UniformService = {}

local headCache = {} -- userId -> { HeadColor, Face }

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function fetchHead(userId)
	local cached = headCache[userId]
	if cached then
		return cached
	end
	local result = { HeadColor = Color3.fromRGB(204, 170, 140), Face = 0 }
	if userId > 0 then
		local ok, description = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		if ok and description then
			result.HeadColor = description.HeadColor
			result.Face = description.Face
		end
	end
	headCache[userId] = result
	return result
end

function UniformService.getDescription(player, teamConfig)
	local kit = GearModels[teamConfig.Id]
	local head = fetchHead(player.UserId)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = head.HeadColor
	description.Face = head.Face
	description.TorsoColor = rgb(kit.Uniform.Torso)
	description.LeftArmColor = rgb(kit.Uniform.Arms)
	description.RightArmColor = rgb(kit.Uniform.Arms)
	description.LeftLegColor = rgb(kit.Uniform.Legs)
	description.RightLegColor = rgb(kit.Uniform.Legs)
	return description
end

local LIMBS = {
	{ Part = "Head", Piece = "Head" },
	{ Part = "Torso", Piece = "Torso" },
	{ Part = "Right Arm", Piece = "Arm" },
	{ Part = "Left Arm", Piece = "Arm", Mirror = true, Imported = "Arm_L" },
	{ Part = "Right Leg", Piece = "Leg" },
	{ Part = "Left Leg", Piece = "Leg", Mirror = true, Imported = "Leg_L" },
}

function UniformService.applyGear(character, teamConfig, player)
	local teamId = teamConfig.Id
	local kit = GearModels[teamId]
	if not kit then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Gear"
	local variants = GearModels.variantsFor(player and player.UserId or 0)
	local sources = {}
	for _, limb in ipairs(LIMBS) do
		local anchor = character:FindFirstChild(limb.Part)
		if anchor then
			local built
			local imported = ModelBuilder.findImported("Gear", teamId, limb.Imported or limb.Piece)
			if imported then
				built = ModelBuilder.attachImported(imported, {
					anchor = anchor, parent = folder, palette = kit.Palette, materials = GearModels.Materials, variants = variants,
				})
			end
			if built then
				sources.imported = true
			else
				ModelBuilder.build(kit[limb.Piece], {
					anchor = anchor, parent = folder, palette = kit.Palette, materials = GearModels.Materials,
					mirror = limb.Mirror, variants = variants, name = limb.Piece,
				})
				sources.primitives = true
			end
		end
	end
	folder:SetAttribute("Source", sources.imported and (sources.primitives and "mixed" or "imported") or "primitives")
	folder.Parent = character
end

Players.PlayerRemoving:Connect(function(player)
	headCache[player.UserId] = nil
end)

return UniformService
