--[[
	EffectsController
	Cosmetic, non-graphic combat effects: tracers, muzzle light, dust puffs.
	Effects are local-only parts under a client folder and are short-lived.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net.Remotes)
local SoundPlayer = require(script.Parent.SoundPlayer)

local EffectsController = {}

local folder
local MAX_REMOTE_TRACER_DISTANCE = 600 -- skip far-away cosmetic tracers for performance

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end

function EffectsController.tracer(from, to)
	local length = (to - from).Magnitude
	if length < 1 then
		return
	end
	local tracer = fxPart({
		Size = Vector3.new(0.08, 0.08, math.min(length, 60)),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -math.min(length, 60) / 2),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 226, 160),
		Transparency = 0.2,
	})
	-- Slide the streak toward the target and fade.
	local travel = CFrame.lookAt(from, to) * CFrame.new(0, 0, -math.max(length - 30, 0))
	TweenService:Create(tracer, TweenInfo.new(0.09, Enum.EasingStyle.Linear), { CFrame = travel, Transparency = 1 }):Play()
	Debris:AddItem(tracer, 0.12)
end

function EffectsController.impact(position)
	local puff = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = CFrame.new(position),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(180, 174, 160),
		Transparency = 0.3,
	})
	TweenService:Create(puff, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1.6, 1.6, 1.6),
		Transparency = 1,
	}):Play()
	Debris:AddItem(puff, 0.4)
end

-- Brief muzzle light + small flash sprite at a world position.
function EffectsController.flashAt(position)
	local flash = fxPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.5, 0.5, 0.5),
		CFrame = CFrame.new(position),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 214, 150),
		Transparency = 0.25,
	})
	local light = Instance.new("PointLight")
	light.Brightness = 2.5
	light.Range = 9
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.05), { Size = Vector3.new(0.9, 0.9, 0.9), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.06)
end

-- Muzzle position of a character's third-person weapon (nil if none).
function EffectsController.muzzleOf(character)
	local model = character and character:FindFirstChild("WeaponModel")
	local handle = model and model:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	return muzzle and muzzle.WorldPosition or nil
end

function EffectsController.start()
	folder = Instance.new("Folder")
	folder.Name = "ClientFx"
	folder.Parent = workspace

	local camera = workspace.CurrentCamera
	Remotes.get("ShotFx").OnClientEvent:Connect(function(shooter, origin, hitPosition)
		if shooter == Players.LocalPlayer or typeof(origin) ~= "Vector3" or typeof(hitPosition) ~= "Vector3" then
			return
		end
		if (camera.CFrame.Position - origin).Magnitude > MAX_REMOTE_TRACER_DISTANCE then
			return
		end
		local character = shooter and shooter.Character
		local start = EffectsController.muzzleOf(character) or origin
		EffectsController.flashAt(start)
		EffectsController.tracer(start, hitPosition)
		EffectsController.impact(hitPosition)
		local model = character and character:FindFirstChild("WeaponModel")
		SoundPlayer.play("Shot_" .. tostring(model and model:GetAttribute("WeaponId")), origin)
	end)
end

return EffectsController
