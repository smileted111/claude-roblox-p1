-- 블록 맵 생성 공용 함수 (Studio MCP execute_luau로 Edit 모드에서 실행한다. 게임 코드가 아님).
-- 각 스테이지 스크립트(StageN.luau) 앞에 이 파일 내용을 붙여서 한 번에 실행한다.
-- 규칙은 Stage1(S1-2)과 같다: 바닥 윗면 y=1, 벽 높이 14·두께 2, 모든 파트 Anchored, 태그별 색 (CLAUDE.md 맵 규칙).

local CollectionService = game:GetService("CollectionService")

local WALL_HEIGHT = 14
local WALL_THICKNESS = 2
local FLOOR_TOP = 1
local WALL_Y = FLOOR_TOP + WALL_HEIGHT / 2

local Map = {}

function Map.part(parent, name, size, position, color, props)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.BrickColor = BrickColor.new(color)
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

function Map.folder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- gaps: {{from, to}, ...} 구간을 빼고 [a, b]를 나눈 조각들
local function segments(a, b, gaps)
	local sorted = table.clone(gaps or {})
	table.sort(sorted, function(x, y)
		return x[1] < y[1]
	end)
	local result = {}
	local cursor = a
	for _, gap in sorted do
		if gap[1] > cursor then
			table.insert(result, { cursor, gap[1] })
		end
		cursor = math.max(cursor, gap[2])
	end
	if b > cursor then
		table.insert(result, { cursor, b })
	end
	return result
end

-- z 위치에서 x 방향으로 [x1, x2] 벽. 끝을 두께의 절반씩 늘려 모서리를 막는다.
function Map.wallX(parent, z, x1, x2, gaps, color)
	for _, seg in segments(x1 - WALL_THICKNESS / 2, x2 + WALL_THICKNESS / 2, gaps) do
		local length = seg[2] - seg[1]
		if length > 0.05 then
			Map.part(
				parent,
				"Wall",
				Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS),
				Vector3.new((seg[1] + seg[2]) / 2, WALL_Y, z),
				color or "Medium stone grey"
			)
		end
	end
end

-- x 위치에서 z 방향으로 [z1, z2] 벽
function Map.wallZ(parent, x, z1, z2, gaps, color)
	for _, seg in segments(z1 - WALL_THICKNESS / 2, z2 + WALL_THICKNESS / 2, gaps) do
		local length = seg[2] - seg[1]
		if length > 0.05 then
			Map.part(
				parent,
				"Wall",
				Vector3.new(WALL_THICKNESS, WALL_HEIGHT, length),
				Vector3.new(x, WALL_Y, (seg[1] + seg[2]) / 2),
				color or "Medium stone grey"
			)
		end
	end
end

-- 가운데 c, 폭 w인 문 구간
function Map.door(c, w)
	w = w or 10
	return { c - w / 2, c + w / 2 }
end

-- 바닥 위의 얇은 표시 파트 (시작 위치·순찰 지점 등). 충돌하지 않는다.
-- yaw: y축 회전(도). 0이면 -Z를 봄 (Roblox 기본 앞)
function Map.marker(parent, name, tag, x, z, size, color, yaw, attributes)
	local part = Map.part(parent, name, Vector3.new(size, 0.2, size), Vector3.new(x, FLOOR_TOP + 0.1, z), color, {
		CanCollide = false,
	})
	if yaw then
		part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, math.rad(yaw), 0)
	end
	if attributes then
		for key, value in attributes do
			part:SetAttribute(key, value)
		end
	end
	CollectionService:AddTag(part, tag)
	return part
end

-- 바라보는 방향(LookVector)을 수평 벡터로 받아 y축 회전(도)으로
function Map.yawFor(lookX, lookZ)
	return math.deg(math.atan2(-lookX, -lookZ))
end

-- Stage1과 같은 옷장: Body(PrimaryPart) 5×8×3.5, 앞면(LookVector)에 문짝 2개와 손잡이
function Map.closet(parent, name, x, z, lookX, lookZ)
	local model = Instance.new("Model")
	model.Name = name
	local base = CFrame.lookAt(Vector3.new(x, FLOOR_TOP + 4, z), Vector3.new(x + lookX, FLOOR_TOP + 4, z + lookZ))
	local function piece(pieceName, size, offset, color)
		local p = Map.part(model, pieceName, size, Vector3.zero, color)
		p.CFrame = base * CFrame.new(offset)
		return p
	end
	local body = piece("Body", Vector3.new(5, 8, 3.5), Vector3.zero, "Reddish brown")
	piece("DoorL", Vector3.new(2.3, 7.4, 0.2), Vector3.new(1.2, 0, -1.85), "Dark orange")
	piece("DoorR", Vector3.new(2.3, 7.4, 0.2), Vector3.new(-1.2, 0, -1.85), "Dark orange")
	piece("HandleL", Vector3.new(0.2, 1, 0.3), Vector3.new(0.4, 0.3, -2.1), "Black")
	piece("HandleR", Vector3.new(0.2, 1, 0.3), Vector3.new(-0.4, 0.3, -2.1), "Black")
	model.PrimaryPart = body
	CollectionService:AddTag(model, "HideSpot")
	model.Parent = parent
	return model
end

function Map.generator(parent, name, x, z)
	local part = Map.part(parent, name, Vector3.new(6, 5, 4), Vector3.new(x, FLOOR_TOP + 2.5, z), "Cyan")
	CollectionService:AddTag(part, "Generator")
	return part
end

-- 바깥 벽의 틈을 막는 출구. alongZ면 x 고정 벽(서·동쪽), 아니면 z 고정 벽(남·북쪽)
function Map.exit(parent, exitId, x, z, width, alongZ)
	local size = if alongZ then Vector3.new(1.6, WALL_HEIGHT, width) else Vector3.new(width, WALL_HEIGHT, 1.6)
	local part = Map.part(parent, `Exit{exitId}`, size, Vector3.new(x, WALL_Y, z), "Dark green")
	part:SetAttribute("ExitId", exitId)
	CollectionService:AddTag(part, "Exit")
	return part
end

-- 비상등: 벽 위쪽의 작은 Neon 파트 + PointLight (그림자 끔, 모바일 성능)
function Map.lamp(parent, x, z, color, range, brightness)
	local part =
		Map.part(parent, "Lamp", Vector3.new(1.2, 0.4, 1.2), Vector3.new(x, FLOOR_TOP + 13, z), "Institutional white", {
			Material = Enum.Material.Neon,
			Color = color,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 22
	light.Brightness = brightness or 1.2
	light.Shadows = false
	light.Parent = part
	return part
end

-- 그림자 괴물용 어두운 구역 (S3-4). 보이지 않고 아무것과도 부딪히지 않는 상자
function Map.darkZone(parent, name, x, z, sizeX, sizeZ)
	local part = Map.part(parent, name, Vector3.new(sizeX, WALL_HEIGHT, sizeZ), Vector3.new(x, WALL_Y, z), "Black", {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	CollectionService:AddTag(part, "DarkZone")
	return part
end

function Map.newStage(stageName)
	local maps = game:GetService("ServerStorage"):FindFirstChild("Maps")
	assert(maps, "ServerStorage.Maps가 없습니다")
	local old = maps:FindFirstChild(stageName)
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = stageName
	local f = {
		root = root,
		structure = Map.folder(root, "Structure"),
		survivorSpawns = Map.folder(root, "SurvivorSpawns"),
		chaserRoom = Map.folder(root, "ChaserRoom"),
		monsterSpawns = Map.folder(root, "MonsterSpawns"),
		patrolPoints = Map.folder(root, "PatrolPoints"),
		hideSpots = Map.folder(root, "HideSpots"),
		generators = Map.folder(root, "Generators"),
		exits = Map.folder(root, "Exits"),
		itemSpawns = Map.folder(root, "ItemSpawns"),
		lights = Map.folder(root, "Lights"),
	}
	f.walls = Map.folder(f.structure, "Walls")
	return f, maps
end

-- 공통 표시 파트 묶음
function Map.addMarkers(f, spec)
	for i, p in spec.survivorSpawns do
		Map.marker(f.survivorSpawns, `SurvivorSpawn{i}`, "SurvivorSpawn", p[1], p[2], 4, "Deep blue")
	end
	for i, p in spec.monsterSpawns do
		local attrs = if p.monster then { Monster = p.monster } else nil
		Map.marker(f.monsterSpawns, `MonsterSpawn{i}`, "MonsterSpawn", p[1], p[2], 5, "Magenta", p.yaw, attrs)
	end
	for route, points in spec.patrol do
		for order, p in points do
			Map.marker(f.patrolPoints, `Patrol{route}_{order}`, "PatrolPoint", p[1], p[2], 3, "New Yeller", nil, {
				Route = route,
				Order = order,
			})
		end
	end
	for i, p in spec.itemSpawns do
		Map.marker(f.itemSpawns, `ItemSpawn{i}`, "ItemSpawn", p[1], p[2], 3, "Pink")
	end
	for i, p in spec.generators do
		Map.generator(f.generators, `Generator{i}`, p[1], p[2])
	end
	for i, p in spec.hideSpots do
		Map.closet(f.hideSpots, `HideSpot{i}`, p[1], p[2], p[3], p[4])
	end
end

-- 태그별 개수
function Map.count(root)
	local counts = {}
	for _, d in root:GetDescendants() do
		for _, tag in d:GetTags() do
			counts[tag] = (counts[tag] or 0) + 1
		end
	end
	local lines = {}
	for tag, n in counts do
		table.insert(lines, `{tag}={n}`)
	end
	table.sort(lines)
	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return table.concat(lines, ", ") .. ` · 파트 {parts}개`
end
