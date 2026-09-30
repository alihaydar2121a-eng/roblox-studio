--[[
	Builder
	Small helpers for constructing anchored environment geometry.
]]

local Builder = {}

function Builder.part(parent, props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "ClassName" then
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

function Builder.folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

--[[
	wall(parent, baseCFrame, length, height, thickness, openings, props)
	baseCFrame: centre of the wall's bottom edge; the wall runs along its X axis.
	openings: list of columns { offset = x centre, width, gaps = { {bottom, top}, ... } }.
	Produces solid piers between columns and solid pieces between gaps.
]]
function Builder.wall(parent, baseCFrame, length, height, thickness, openings, props)
	table.sort(openings, function(a, b)
		return a.offset < b.offset
	end)
	local function piece(x0, x1, y0, y1)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		Builder.part(parent, {
			Size = Vector3.new(x1 - x0, y1 - y0, thickness),
			CFrame = baseCFrame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0),
			Material = props.Material,
			Color = props.Color,
		})
	end
	local cursor = -length / 2
	for _, column in ipairs(openings) do
		local left, right = column.offset - column.width / 2, column.offset + column.width / 2
		piece(cursor, left, 0, height)
		table.sort(column.gaps, function(a, b)
			return a[1] < b[1]
		end)
		local y = 0
		for _, gap in ipairs(column.gaps) do
			piece(left, right, y, gap[1])
			y = gap[2]
		end
		piece(left, right, y, height)
		cursor = right
	end
	piece(cursor, length / 2, 0, height)
end

function Builder.distanceToSegment2D(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local lenSq = dx * dx + dz * dz
	local t = 0
	if lenSq > 0 then
		t = math.clamp(((px - ax) * dx + (pz - az) * dz) / lenSq, 0, 1)
	end
	local cx, cz = ax + dx * t, az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

return Builder
