--!strict
-- 캐주얼 모드의 맵 색 (Config.VisualModes.Casual.Palette). 서버는 불러온 스테이지 맵 복제본에, 클라이언트는 로비 미리보기에 쓴다.
-- 바꾸지 않는 파트: Neon(조명·발판), 투명한 파트(Transparency 1), 글자판(SurfaceGui가 있는 표지판).
-- 바꾼 파트의 원래 색은 saved 표에 남겨 restore로 되돌린다.

local VisualModes = require(script.Parent.Parent.Config.VisualModes)

export type Saved = { [BasePart]: Color3 }

local WHITE = Color3.new(1, 1, 1)

local MapStyler = {}

local function colorFor(part: BasePart, palette: VisualModes.Palette): Color3?
	if part.Material == Enum.Material.Neon or part.Transparency >= 1 then
		return nil
	end
	if part:FindFirstChildWhichIsA("SurfaceGui") then
		return nil
	end
	if part.Name == "Floor" then
		return palette.FloorColor
	end
	local parent = part.Parent
	if part.Name == "Wall" or (parent ~= nil and parent.Name == "Walls") then
		-- 같은 벽은 늘 같은 색이 되도록 위치로 고른다.
		local cell = palette.WallCellSize
		local position = part.Position
		local index = (math.floor(position.X / cell) * 7 + math.floor(position.Z / cell) * 13) % #palette.WallColors
		return palette.WallColors[index + 1]
	end
	return part.Color:Lerp(WHITE, palette.PastelBlend)
end

-- 파트 하나를 칠한다. 칠했으면 true.
function MapStyler.applyPart(part: BasePart, palette: VisualModes.Palette, saved: Saved): boolean
	if saved[part] then
		return false
	end
	local color = colorFor(part, palette)
	if not color then
		return false
	end
	saved[part] = part.Color
	part.Color = color
	return true
end

-- root 아래 파트를 모두 칠하고 칠한 수를 돌려준다.
function MapStyler.apply(root: Instance, palette: VisualModes.Palette, saved: Saved): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and MapStyler.applyPart(descendant, palette, saved) then
			count += 1
		end
	end
	return count
end

-- 칠한 파트를 원래 색으로 되돌리고 saved를 비운다.
function MapStyler.restore(saved: Saved): ()
	for part, color in saved do
		if part.Parent then
			part.Color = color
		end
	end
	table.clear(saved)
end

return MapStyler
