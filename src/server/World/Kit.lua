--[[
	Kit
	Geometry toolkit for the environment builders. Everything is anchored,
	CanTouch=false (no Touched overhead) and created before being parented.

	Wedge orientation is *measured* at startup (Kit.calibrate raycasts a test
	WedgePart/CornerWedgePart) instead of assumed, so ramps, gables and
	pyramids come out right regardless of engine conventions.
]]

local Kit = {}

Kit.count = 0

-- Measured orientation: WedgePart slope rises toward local +Z * wedgeRise;
-- CornerWedgePart apex sits above local corner (apexX, apexZ).
local orientation = { wedgeRise = 1, apexX = 1, apexZ = -1, calibrated = false }
Kit.orientation = orientation

local Y = Vector3.new(0, 1, 0)

function Kit.calibrate(Env)
	local ok, err = pcall(function()
		local folder = Instance.new("Folder")
		folder.Name = "_KitCalibration"
		local wedge = Instance.new("WedgePart")
		wedge.Anchored = true
		wedge.Size = Vector3.new(4, 4, 4)
		wedge.CFrame = CFrame.new(0, 4000, 0)
		wedge.Parent = folder
		local corner = Instance.new("CornerWedgePart")
		corner.Anchored = true
		corner.Size = Vector3.new(4, 4, 4)
		corner.CFrame = CFrame.new(40, 4000, 0)
		corner.Parent = folder
		folder.Parent = Env.Workspace
		Env.waitFrame()

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { folder }
		local function topAt(part, lx, lz)
			local origin = part.CFrame:PointToWorldSpace(Vector3.new(lx, 10, lz))
			local hit = Env.raycast(origin, Vector3.new(0, -20, 0), params)
			return hit and hit.Position.Y or nil
		end
		local front, back = topAt(wedge, 0, -1.5), topAt(wedge, 0, 1.5)
		local corners = {}
		for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
			table.insert(corners, { c[1], c[2], topAt(corner, c[1] * 1.4, c[2] * 1.4) })
		end
		folder:Destroy()

		if front and back and math.abs(front - back) > 0.5 then
			orientation.wedgeRise = back > front and 1 or -1
			orientation.calibrated = true
		end
		local best
		for _, c in ipairs(corners) do
			if c[3] and (not best or c[3] > best[3]) then
				best = c
			end
		end
		if best then
			orientation.apexX, orientation.apexZ = best[1], best[2]
		end
	end)
	if not ok then
		warn("[Kit] wedge calibration failed, using defaults: " .. tostring(err))
	end
	return orientation
end

--------------------------------------------------------------- frames

-- Frame at pos whose LookVector (−Z) points along dir. Built explicitly with
-- fromMatrix so steep/vertical directions are well defined.
function Kit.frameAlong(pos, dir, upHint)
	local look = dir.Unit
	upHint = upHint or Y
	if math.abs(look:Dot(upHint)) > 0.98 then
		upHint = Vector3.new(1, 0, 0)
		if math.abs(look:Dot(upHint)) > 0.98 then
			upHint = Vector3.new(0, 0, 1)
		end
	end
	local right = look:Cross(upHint).Unit
	local up = right:Cross(look)
	return CFrame.fromMatrix(pos, right, up, -look)
end

function Kit.lookAt(pos, target)
	return Kit.frameAlong(pos, target - pos)
end

--------------------------------------------------------------- primitives

--[[
	opts (all optional): Name, Class ("Part"|"WedgePart"|"CornerWedgePart"),
	Shape, Transparency, Reflectance, NoCollide, NoQuery, NoShadow,
	Decor (= NoCollide + NoQuery)
]]
function Kit.part(parent, cf, size, material, color, opts)
	local p = Instance.new(opts and opts.Class or "Part")
	p.Anchored = true
	p.CanTouch = false
	if opts then
		if opts.Shape then
			p.Shape = opts.Shape
		end
		if opts.Name then
			p.Name = opts.Name
		end
		if opts.Transparency then
			p.Transparency = opts.Transparency
		end
		if opts.Reflectance then
			p.Reflectance = opts.Reflectance
		end
		if opts.NoCollide or opts.Decor then
			p.CanCollide = false
		end
		if opts.NoQuery or opts.Decor then
			p.CanQuery = false
		end
		if opts.NoShadow then
			p.CastShadow = false
		end
	end
	p.Size = size
	p.CFrame = cf
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	Kit.count += 1
	return p
end

function Kit.box(parent, cf, sx, sy, sz, material, color, opts)
	return Kit.part(parent, cf, Vector3.new(sx, sy, sz), material, color, opts)
end

local function withShape(opts, shape)
	local o = {}
	if opts then
		for k, v in pairs(opts) do
			o[k] = v
		end
	end
	o.Shape = shape
	return o
end

function Kit.ball(parent, pos, diameter, material, color, opts)
	return Kit.part(parent, CFrame.new(pos), Vector3.new(diameter, diameter, diameter), material, color, withShape(opts, Enum.PartType.Ball))
end

-- Cylinder between two world points.
function Kit.cylinder(parent, a, b, diameter, material, color, opts)
	local len = (b - a).Magnitude
	local cf = Kit.frameAlong((a + b) / 2, b - a) * CFrame.Angles(0, math.pi / 2, 0)
	return Kit.part(parent, cf, Vector3.new(len, diameter, diameter), material, color, withShape(opts, Enum.PartType.Cylinder))
end

-- Vertical cylinder standing on `base` (world point).
function Kit.column(parent, base, height, diameter, material, color, opts)
	local cf = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return Kit.part(parent, cf, Vector3.new(height, diameter, diameter), material, color, withShape(opts, Enum.PartType.Cylinder))
end

-- Box spanning world points a→b (length along its Z), w wide and h tall.
function Kit.beam(parent, a, b, w, h, material, color, opts)
	local dir = b - a
	return Kit.part(parent, Kit.frameAlong((a + b) / 2, dir), Vector3.new(w, h, dir.Magnitude), material, color, opts)
end

--[[
	slab(parent, frame, a, b, widthAxis, width, thickness, outward, ...)
	Rectangular plate whose centre line runs from local point a to b (in
	`frame`), extending `width` along local unit vector widthAxis. The plate is
	offset by half its thickness toward `outward` so its inner face lies on
	the a→b line (roofs sit on gables, ramps sit on stair nosings).
]]
function Kit.slab(parent, frame, a, b, widthAxis, width, thickness, outward, material, color, opts)
	local A, B = frame:PointToWorldSpace(a), frame:PointToWorldSpace(b)
	local vx = frame:VectorToWorldSpace(widthAxis).Unit
	local dir = (B - A)
	local vz = -dir.Unit
	local vy = vz:Cross(vx)
	local out = frame:VectorToWorldSpace(outward)
	local sign = vy:Dot(out) >= 0 and 1 or -1
	local center = (A + B) / 2 + vy * (sign * thickness / 2)
	local cf = CFrame.fromMatrix(center, vx, vy, vz)
	return Kit.part(parent, cf, Vector3.new(width, thickness, dir.Magnitude), material, color, opts)
end

-- Wedge whose slope rises toward the frame's local +Z (rise = 1) or −Z (rise = −1).
function Kit.wedge(parent, cf, size, rise, material, color, opts)
	local flip = (orientation.wedgeRise == rise) and CFrame.new() or CFrame.Angles(0, math.pi, 0)
	local o = {}
	if opts then
		for k, v in pairs(opts) do
			o[k] = v
		end
	end
	o.Class = "WedgePart"
	return Kit.part(parent, cf * flip, size, material, color, o)
end

local YAWS = { 0, math.pi / 2, math.pi, -math.pi / 2 }
local function apexYaw(dx, dz)
	for _, yaw in ipairs(YAWS) do
		local c, s = math.cos(yaw), math.sin(yaw)
		local rx = orientation.apexX * c + orientation.apexZ * s
		local rz = -orientation.apexX * s + orientation.apexZ * c
		if (rx > 0) == (dx > 0) and (rz > 0) == (dz > 0) then
			return yaw
		end
	end
	return 0
end

-- Square pyramid (four CornerWedgeParts) standing on baseCf.
function Kit.pyramid(parent, baseCf, size, height, material, color, opts)
	local o = {}
	if opts then
		for k, v in pairs(opts) do
			o[k] = v
		end
	end
	o.Class = "CornerWedgePart"
	local q = size / 2
	for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		local yaw = apexYaw(-c[1], -c[2])
		local cf = baseCf * CFrame.new(c[1] * q / 2, height / 2, c[2] * q / 2) * CFrame.Angles(0, yaw, 0)
		Kit.part(parent, cf, Vector3.new(q, height, q), material, color, o)
	end
end

--------------------------------------------------------------- architecture

--[[
	wall(parent, cf, length, height, t, columns, material, color, trim)
	cf: centre of the wall's bottom edge; wall runs along local X; local −Z is
	the exterior. columns: { { offset, width, gaps = { {bottom, top, kind} } } }
	where kind is "window" | "door" | "open". trim (optional):
	{ Material, Color, Shutters = Color3?, Door = Color3?, Ruin = Rng? }
]]
function Kit.wall(parent, cf, length, height, t, columns, material, color, trim)
	table.sort(columns, function(a, b)
		return a.offset < b.offset
	end)
	local ruin = trim and trim.Ruin
	local function piece(x0, x1, y0, y1)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		if ruin then
			if ruin:chance(0.18) and y0 > 0.5 then
				return -- missing chunk
			end
			if y1 > 4 and ruin:chance(0.35) then
				y1 = math.max(y0 + 0.5, y1 - ruin:range(1, y1 * 0.6))
			end
		end
		Kit.box(parent, cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), x1 - x0, y1 - y0, t, material, color)
	end
	local cursor = -length / 2
	for _, column in ipairs(columns) do
		local left, right = column.offset - column.width / 2, column.offset + column.width / 2
		piece(cursor, left, 0, height)
		table.sort(column.gaps, function(a, b)
			return a[1] < b[1]
		end)
		local y = 0
		for _, gap in ipairs(column.gaps) do
			piece(left, right, y, gap[1])
			y = gap[2]
			if trim and not ruin then
				local w = column.width
				local kind = gap[3] or "window"
				-- Lintel
				Kit.box(parent, cf * CFrame.new(column.offset, gap[2] + 0.22, -0.12), w + 0.7, 0.45, t + 0.3, trim.Material, trim.Color)
				if kind == "window" then
					Kit.box(parent, cf * CFrame.new(column.offset, gap[1] - 0.15, -0.2), w + 0.8, 0.3, t + 0.5, trim.Material, trim.Color)
					if trim.Shutters then
						local sh = gap[2] - gap[1]
						for side = -1, 1, 2 do
							Kit.box(parent, cf * CFrame.new(column.offset + side * (w * 0.75 + 0.05), gap[1] + sh / 2, -t / 2 - 0.12),
								w / 2, sh, 0.2, Enum.Material.WoodPlanks, trim.Shutters, { NoQuery = true })
						end
					end
				elseif kind == "door" and trim.Door then
					local dh = gap[2] - gap[1] - 0.1
					local leaf = w - 0.3
					-- Door leaf swung open against the interior.
					Kit.box(parent, cf * CFrame.new(left + 0.25, gap[1] + dh / 2, t / 2 + leaf / 2), 0.25, dh, leaf,
						Enum.Material.WoodPlanks, trim.Door, { Decor = true })
				end
			end
		end
		piece(left, right, y, height)
		cursor = right
	end
	piece(cursor, length / 2, 0, height)
end

--[[
	bays(length, floors, floorHeight, opts) -> columns
	Evenly spaced window columns, optional door on the ground floor.
	opts: Bay (spacing, default 8), WindowW, Sill, Head, Door ("center" | "left" | number offset | nil),
	DoorW, DoorH, SkipFloors = { [floor] = true }, Wide (ground-floor shop windows)
]]
function Kit.bays(length, floors, floorHeight, opts)
	opts = opts or {}
	local bay = opts.Bay or 8
	local n = math.max(1, math.floor(length / bay))
	local columns = {}
	local doorIndex
	if opts.Door == "center" then
		doorIndex = math.ceil(n / 2)
	elseif opts.Door == "left" then
		doorIndex = 1
	elseif opts.Door == "right" then
		doorIndex = n
	end
	for i = 1, n do
		local offset = -length / 2 + (i - 0.5) * (length / n)
		local column = { offset = offset, width = opts.WindowW or 3.4, gaps = {} }
		for f = 1, floors do
			local base = (f - 1) * floorHeight
			if f == 1 and i == doorIndex then
				column.width = opts.DoorW or 4.6
				table.insert(column.gaps, { 0, opts.DoorH or 8, "door" })
			elseif not (opts.SkipFloors and opts.SkipFloors[f]) then
				if f == 1 and opts.Wide then
					column.width = math.min(length / n - 1.4, 6)
					table.insert(column.gaps, { base + 2.4, base + 7.8, "window" })
				else
					table.insert(column.gaps, { base + (opts.Sill or 3.2), base + (opts.Head or 7.4), "window" })
				end
			end
		end
		if #column.gaps > 0 then
			table.insert(columns, column)
		end
	end
	return columns
end

--[[
	stairs(parent, cf, width, rise, run, material, color)
	cf: bottom-front-centre of the flight at the lower floor level; the flight
	climbs along local −Z. Solid step blocks plus an invisible ramp through the
	nosings so R6 characters walk up smoothly.
]]
function Kit.stairs(parent, cf, width, rise, run, material, color)
	local n = math.max(1, math.floor(rise + 0.5))
	local r, g = rise / n, run / n
	for i = 1, n do
		local h = i * r
		Kit.box(parent, cf * CFrame.new(0, h / 2, -(i - 0.5) * g), width, h, g, material, color)
	end
	Kit.slab(parent, cf, Vector3.new(0, 0, g), Vector3.new(0, rise, -(n - 1) * g), Vector3.new(1, 0, 0), width, 0.5,
		Vector3.new(0, -1, 0), material, color, { Transparency = 1, NoQuery = true, NoShadow = true, Name = "StairRamp" })
end

--[[
	gableRoof(parent, cf, w, d, pitch, overhang, roofMat, roofColor, gableMat, gableColor, t)
	cf at the centre of the wall tops; ridge along local X; gables at ±X.
]]
function Kit.gableRoof(parent, cf, w, d, pitch, overhang, roofMat, roofColor, gableMat, gableColor, t)
	local drop = overhang * pitch / (d / 2)
	local width = w + 2 * overhang
	local up = Vector3.new(0, 1, 0)
	for side = -1, 1, 2 do
		Kit.slab(parent, cf, Vector3.new(0, pitch, 0), Vector3.new(0, -drop, side * (d / 2 + overhang)),
			Vector3.new(1, 0, 0), width, 0.7, up, roofMat, roofColor)
		-- Gable triangle halves (rise toward the ridge).
		for gx = -1, 1, 2 do
			Kit.wedge(parent, cf * CFrame.new(gx * (w / 2 - t / 2), pitch / 2, side * d / 4),
				Vector3.new(t, pitch, d / 2), -side, gableMat, gableColor)
		end
	end
	Kit.box(parent, cf * CFrame.new(0, pitch + 0.45, 0), width + 0.2, 0.5, 1.1, roofMat, roofColor)
end

-- Flat roof slab on wall tops with an optional parapet. Returns the roof top Y (local).
function Kit.flatRoof(parent, cf, w, d, parapet, material, color, holes)
	local top = 1
	if holes then
		Kit.levelSlab(parent, cf * CFrame.new(0, 1, 0), -w / 2, w / 2, -d / 2, d / 2, holes, 1, material, color)
	else
		Kit.box(parent, cf * CFrame.new(0, 0.5, 0), w + 0.3, 1, d + 0.3, material, color)
	end
	if parapet and parapet > 0 then
		local t = 0.6
		Kit.box(parent, cf * CFrame.new(0, top + parapet / 2, -d / 2 + t / 2), w + 0.3, parapet, t, material, color)
		Kit.box(parent, cf * CFrame.new(0, top + parapet / 2, d / 2 - t / 2), w + 0.3, parapet, t, material, color)
		Kit.box(parent, cf * CFrame.new(-w / 2 + t / 2, top + parapet / 2, 0), t, parapet, d - 2 * t, material, color)
		Kit.box(parent, cf * CFrame.new(w / 2 - t / 2, top + parapet / 2, 0), t, parapet, d - 2 * t, material, color)
	end
	return top
end

-- Barrel-vault roof over span (local X) and length (local Z), springing from cf.
function Kit.archRoof(parent, cf, span, length, rise, segments, material, color)
	local pts = {}
	for i = 0, segments do
		local a = math.pi * i / segments
		table.insert(pts, Vector3.new(-math.cos(a) * span / 2, math.sin(a) * rise, 0))
	end
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) / 2
		Kit.slab(parent, cf, a, b, Vector3.new(0, 0, 1), length, 0.8, mid, material, color)
	end
	return pts
end

--[[
	levelSlab(parent, cf, x0, x1, z0, z1, holes, thickness, material, color)
	Floor plate covering [x0,x1]×[z0,z1] (local, top surface at cf.Y) minus
	axis-aligned rectangular holes { {hx0, hx1, hz0, hz1} } (stair wells).
	Supports up to one hole per z-band; built from at most 4 parts per hole.
]]
function Kit.levelSlab(parent, cf, x0, x1, z0, z1, holes, thickness, material, color)
	local function rect(ax, bx, az, bz)
		if bx - ax > 0.1 and bz - az > 0.1 then
			Kit.box(parent, cf * CFrame.new((ax + bx) / 2, -thickness / 2, (az + bz) / 2), bx - ax, thickness, bz - az, material, color)
		end
	end
	if not holes or #holes == 0 then
		rect(x0, x1, z0, z1)
		return
	end
	table.sort(holes, function(a, b)
		return a[3] < b[3]
	end)
	local z = z0
	for _, h in ipairs(holes) do
		rect(x0, x1, z, h[3])
		rect(x0, h[1], h[3], h[4])
		rect(h[2], x1, h[3], h[4])
		z = h[4]
	end
	rect(x0, x1, z, z1)
end

-- Post-and-rail railing between two world points at ground level.
function Kit.railing(parent, a, b, height, material, color, spacing)
	spacing = spacing or 5
	local len = (b - a).Magnitude
	local n = math.max(1, math.ceil(len / spacing))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		Kit.box(parent, CFrame.new(p + Vector3.new(0, height / 2, 0)), 0.25, height, 0.25, material, color)
	end
	local up = Vector3.new(0, height - 0.1, 0)
	Kit.beam(parent, a + up, b + up, 0.25, 0.2, material, color)
	Kit.beam(parent, a + up * 0.5, b + up * 0.5, 0.15, 0.15, material, color, { Decor = true })
end

-- Sign board with text on its front (−Z) face.
function Kit.sign(parent, cf, w, h, text, background, foreground)
	local board = Kit.box(parent, cf, w, h, 0.25, Enum.Material.WoodPlanks, background, { Name = "Sign" })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.MaxDistance = 220
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.Merriweather
	label.TextColor3 = foreground
	label.Parent = gui
	gui.Parent = board
	return board
end

-- Warm lamp head with a light source; lights are shadowless for performance.
function Kit.lamp(parent, pos, size, color, range, brightness)
	local head = Kit.box(parent, CFrame.new(pos), size, size * 0.6, size, Enum.Material.SmoothPlastic, color or Color3.fromRGB(255, 232, 190), { Decor = true, NoShadow = true, Name = "Lamp" })
	local light = Instance.new("PointLight")
	light.Range = range or 16
	light.Brightness = brightness or 1.1
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Shadows = false
	light.Parent = head
	return head
end

function Kit.model(parent, name, streaming)
	local m = Instance.new("Model")
	m.Name = name
	if streaming then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		pcall(function()
			m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
		end)
	end
	m.Parent = parent
	return m
end

return Kit
