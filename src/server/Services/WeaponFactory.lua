--[[
	WeaponFactory
	Builds weapon Tools from primitive parts (no external meshes). The barrel
	points along the Handle's -Z axis; a "Muzzle" attachment marks the tip.
	Grip values may need visual tuning in Studio (see docs/STUDIO_VALIDATION.md).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local toColor = require(Shared.Util.Color)

local WeaponFactory = {}

local function part(parent, name, size, color, material, offset, handle)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = parent
	if handle then
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
	end
	return p
end

function WeaponFactory.create(weapon)
	local tool = Instance.new("Tool")
	tool.Name = weapon.DisplayName
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.RequiresHandle = true
	tool.ToolTip = weapon.DisplayName
	tool:SetAttribute("WeaponId", weapon.Id)
	-- Hold the rifle forward in the R6 tool pose.
	tool.Grip = CFrame.new(0, -0.1, 0.35) * CFrame.Angles(0, 0, 0)

	local body = toColor(weapon.BodyColor)
	local accent = toColor(weapon.AccentColor)

	local handle = part(tool, "Handle", Vector3.new(0.35, 0.55, 1.6), body, Enum.Material.Metal)
	handle.CFrame = CFrame.new()
	part(tool, "Barrel", Vector3.new(0.18, 0.18, 1.6), body, Enum.Material.Metal, CFrame.new(0, 0.12, -1.55), handle)
	part(tool, "Stock", Vector3.new(0.3, 0.5, 1.0), accent, Enum.Material.WoodPlanks, CFrame.new(0, -0.05, 1.25), handle)
	part(tool, "Magazine", Vector3.new(0.25, 0.7, 0.35), body, Enum.Material.Metal, CFrame.new(0, -0.55, -0.35) * CFrame.Angles(math.rad(-12), 0, 0), handle)
	part(tool, "Foregrip", Vector3.new(0.3, 0.3, 0.8), accent, Enum.Material.WoodPlanks, CFrame.new(0, -0.05, -0.95), handle)
	part(tool, "Sight", Vector3.new(0.12, 0.18, 0.5), body, Enum.Material.Metal, CFrame.new(0, 0.36, -0.1), handle)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.12, -2.4)
	muzzle.Parent = handle

	return tool
end

return WeaponFactory
