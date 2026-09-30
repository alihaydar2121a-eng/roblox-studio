--[[
	UniformService
	Dresses characters in original team uniforms built from body colours and
	simple welded parts (helmet, vest, armband). Player clothing/accessories are
	stripped for readability; the player's own head colour and face are kept.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local toColor = require(Shared.Util.Color)

local UniformService = {}

local headCache = {} -- userId -> { HeadColor, Face }

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
	local uniform = teamConfig.Uniform
	local head = fetchHead(player.UserId)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = head.HeadColor
	description.Face = head.Face
	description.TorsoColor = toColor(uniform.Torso)
	description.LeftArmColor = toColor(uniform.Arms)
	description.RightArmColor = toColor(uniform.Arms)
	description.LeftLegColor = toColor(uniform.Legs)
	description.RightLegColor = toColor(uniform.Legs)
	return description
end

local function weldGear(character, attachTo, name, size, offset, color, material, meshType, meshScale)
	local anchor = character:FindFirstChild(attachTo)
	if not anchor then
		return
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false -- shots pass through gear and hit the body part underneath
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = anchor.CFrame * offset
	if meshType then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = meshType
		mesh.Scale = meshScale or Vector3.one
		mesh.Parent = part
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
end

function UniformService.applyGear(character, teamConfig)
	local uniform = teamConfig.Uniform
	weldGear(
		character, "Head", "Helmet", Vector3.new(1.35, 0.7, 1.35), CFrame.new(0, 0.42, 0),
		toColor(uniform.Helmet), Enum.Material.SmoothPlastic, Enum.MeshType.Sphere, Vector3.new(1, 1, 1)
	)
	weldGear(
		character, "Torso", "Vest", Vector3.new(2.15, 1.5, 1.15), CFrame.new(0, 0.15, 0),
		toColor(uniform.Vest), Enum.Material.Fabric
	)
	weldGear(
		character, "Left Arm", "Armband", Vector3.new(1.08, 0.3, 1.08), CFrame.new(0, 0.55, 0),
		toColor(uniform.Band), Enum.Material.SmoothPlastic
	)
	weldGear(
		character, "Right Arm", "Armband", Vector3.new(1.08, 0.3, 1.08), CFrame.new(0, 0.55, 0),
		toColor(uniform.Band), Enum.Material.SmoothPlastic
	)
end

Players.PlayerRemoving:Connect(function(player)
	headCache[player.UserId] = nil
end)

return UniformService
