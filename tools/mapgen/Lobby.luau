-- 로비: 아늑하고 풍족한 통나무집 거실 (2026-11-21 사용자 요청, 처음 블록 로비는 S3-2).
-- Studio MCP execute_luau로 Edit 모드에서 실행한다 (게임 코드가 아님). Workspace.Lobby를 새로 만든다 (스폰도 새로).
-- 스테이지 맵(원점, ±160)과 겹치지 않게 z = 460 ~ 540, x = ±50. 바닥 윗면 y = 1, 천장 아랫면 y = 19.
--   방: 꿀색 나무 바닥(가장자리 호두색 테두리), 통나무를 쌓은 벽 + 아래 나무 판벽, 판자 천장과 굵은 들보·모서리 기둥,
--       들보에 매단 꼬마전구, 나무 샹들리에 2개, 벽 등불 4개.
--   북쪽: 돌 벽난로(통나무 선반, 불·불빛, "우리 집" 판, 장작 더미, 괘종시계, 흔들의자, 털 러그, 고양이)와 스폰 러그.
--   북서 거실: 가죽 L자 소파, 커피 테이블, 안락의자, TV 장식장과 양쪽 큰 책장, 스탠드, 겹친 러그.
--   북동 주방: 원목 조리대·가스레인지·싱크·위 선반(유리병·접시), 매달린 냄비, 냉장고, 사과 상자, 긴 식탁과 의자 6개·펜던트 등.
--   남동: 피아노, 안락의자·발받침, 지구본, 큰 책장 / 동쪽 현관문(리스·발매트·우산 통)
--   남쪽 벽 아래 두 카펫 (태그는 S3-2와 같음): 같이 하기 (LobbyTogether, 초록) / 혼자 하기 (LobbySolo, 파랑, 서버가 프롬프트를 단다).
--   창문(나무 틀·커튼·꽃 상자), 화분과 매단 화분, 액자.
-- 표지판 글자는 Localization Lobby.Together·TogetherHint·Solo·SoloHint, Signs.Home의 한국어 원문과 같아야 번역된다.
-- 캐주얼 모드: 이름이 Wall·Floor이거나 Walls 폴더인 파트가 없어 모두 원래 나무색을 흰색 쪽으로 35% 섞는다 (MapStyler) —
--   파스텔 벽 대신 밝은 원목 느낌이 남는다.

local CollectionService = game:GetService("CollectionService")
local CENTER_Z = 500
local FT = 1 -- 바닥 윗면
local TOP = 19 -- 천장 아랫면
local X1, X2, Z1, Z2 = -50, 50, 460, 540 -- 벽 안쪽 면

local DECOR = { CanCollide = false, CanQuery = false, CanTouch = false }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- 나무색
local HONEY = rgb(196, 140, 84)
local OAK = rgb(170, 116, 68)
local CHERRY = rgb(150, 86, 56)
local WALNUT = rgb(104, 66, 40)
local DARK = rgb(74, 46, 30)
local LOG_A = rgb(158, 104, 62)
local LOG_B = rgb(140, 90, 54)
local CREAM = rgb(250, 240, 220)
local WARM = rgb(255, 200, 140)

local function merge(a, b)
	local out = table.clone(a or {})
	for k, v in b or {} do
		out[k] = v
	end
	return out
end

local function part(parent, name, size, cframe, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = if typeof(cframe) == "Vector3" then CFrame.new(cframe) else cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function wood(parent, name, size, cframe, color, props)
	return part(parent, name, size, cframe, color, merge({ Material = Enum.Material.Wood }, props))
end

local function deco(parent, name, size, cframe, color, props)
	return part(parent, name, size, cframe, color, merge(DECOR, props))
end

local function ball(parent, name, d, position, color, props)
	return deco(parent, name, Vector3.new(d, d, d), position, color, merge({ Shape = Enum.PartType.Ball }, props))
end

-- 세운 원기둥
local function cyl(parent, name, height, diameter, position, color, props)
	return part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, merge({ Shape = Enum.PartType.Cylinder }, props))
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- (x, z)에 서서 (lookX, lookZ) 쪽을 보는 바닥 기준 CFrame. 앞 = -Z
local function facing(x, z, lookX, lookZ)
	return CFrame.lookAt(Vector3.new(x, FT, z), Vector3.new(x + lookX, FT, z + lookZ))
end

-- 앞면이 face 쪽을 보는 글자판
local function textBoard(parent, name, size, position, face, color, lines)
	local board = deco(parent, name, size, CFrame.lookAt(position, position + face), color, { Material = Enum.Material.Wood })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	for _, line in lines do
		local label = Instance.new("TextLabel")
		label.Position = line.position
		label.Size = line.size
		label.BackgroundTransparency = 1
		label.Font = line.font
		label.TextScaled = true
		label.TextColor3 = line.color
		label.Text = line.text
		label.Parent = gui
	end
	return board
end

-- 책장: base 앞(-Z)이 방 쪽. 칸마다 책을 채우고 사이사이 화분·유리병
local BOOK_COLORS = { rgb(170, 50, 50), rgb(60, 100, 170), rgb(210, 170, 60), rgb(70, 140, 80), rgb(130, 80, 150), rgb(200, 110, 60), rgb(230, 220, 200) }
local function bookshelf(parent, base, width, height, depth, seed)
	local m = model(parent, "Bookshelf")
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	wood(m, "Back", Vector3.new(width, height, 0.3), at(0, height / 2, depth / 2 - 0.15), WALNUT)
	for _, x in { -width / 2 + 0.2, width / 2 - 0.2 } do
		wood(m, "Side", Vector3.new(0.4, height, depth), at(x, height / 2, 0), CHERRY)
	end
	local shelves = math.floor(height / 2.2)
	local gap = height / shelves
	for i = 0, shelves do
		wood(m, "Shelf", Vector3.new(width, 0.3, depth), at(0, math.min(i * gap + 0.15, height - 0.15), 0), CHERRY)
	end
	for row = 0, shelves - 1 do
		local y = row * gap + 0.3
		local x = -width / 2 + 0.6
		local n = 0
		while x < width / 2 - 0.7 do
			n += 1
			local key = (seed * 7 + row * 5 + n * 3) % 11
			if key == 0 then
				-- 작은 화분
				cyl(m, "Pot", 0.8, 0.9, at(x + 0.4, y + 0.4, 0).Position, rgb(190, 110, 80), DECOR)
				ball(m, "Leaves", 1.1, at(x + 0.4, y + 1.1, 0).Position, rgb(90, 160, 90), { Material = Enum.Material.Grass })
				x += 1.1
			elseif key == 5 then
				-- 유리병
				cyl(m, "Jar", 1, 0.7, at(x + 0.35, y + 0.5, 0).Position, rgb(200, 230, 240), merge(DECOR, { Material = Enum.Material.Glass, Transparency = 0.3 }))
				x += 0.9
			else
				local h = 1.2 + ((seed + row + n) % 4) * 0.18
				local w = 0.35 + ((n + seed) % 3) * 0.08
				local tilt = if key == 7 then 12 else 0
				deco(m, "Book", Vector3.new(w, h, depth - 0.5), at(x + w / 2, y + h / 2, 0) * CFrame.Angles(0, 0, math.rad(tilt)), BOOK_COLORS[(seed + row * 3 + n) % #BOOK_COLORS + 1])
				x += w + 0.05
			end
		end
	end
	return m
end

-- 소파 (base 앞이 앉은 사람이 보는 쪽)
local function sofa(parent, base, width, color, name)
	local m = model(parent, name or "Sofa")
	local depth = 4.4
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	part(m, "Seat", Vector3.new(width, 1.8, depth), at(0, 0.9, 0), color, { Material = Enum.Material.Leather })
	part(m, "Back", Vector3.new(width, 3.4, 1.2), at(0, 2.8, depth / 2 - 0.6), color, { Material = Enum.Material.Leather })
	for _, x in { -width / 2 + 0.6, width / 2 - 0.6 } do
		part(m, "Arm", Vector3.new(1.2, 2.8, depth), at(x, 1.4, 0), color, { Material = Enum.Material.Leather })
	end
	local cushions = math.max(1, math.floor((width - 2.4) / 3.2))
	local cw = (width - 2.4) / cushions
	for i = 0, cushions - 1 do
		deco(m, "Cushion", Vector3.new(cw - 0.15, 0.7, depth - 1.4), at(-width / 2 + 1.2 + cw * (i + 0.5), 2.15, -0.4), color:Lerp(rgb(255, 255, 255), 0.12), { Material = Enum.Material.Leather })
	end
	for i, c in { rgb(220, 180, 90), rgb(170, 60, 50) } do
		local x = (if i == 1 then -1 else 1) * (width / 2 - 1.8)
		deco(m, "Pillow", Vector3.new(1.8, 1.6, 0.6), at(x, 3.1, depth / 2 - 1.4) * CFrame.Angles(math.rad(-15), 0, math.rad(i == 1 and 10 or -10)), c, { Material = Enum.Material.Fabric })
	end
	for _, x in { -width / 2 + 0.4, width / 2 - 0.4 } do
		for _, z in { -depth / 2 + 0.4, depth / 2 - 0.4 } do
			wood(m, "Foot", Vector3.new(0.4, 0.3, 0.4), at(x, -0.15 + 0.15, z), DARK)
		end
	end
	return m
end

local function chair(parent, base, color)
	local m = model(parent, "Chair")
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	wood(m, "Seat", Vector3.new(2, 0.35, 2), at(0, 2, 0), color)
	wood(m, "Back", Vector3.new(2, 2.4, 0.3), at(0, 3.3, 0.85), color)
	for _, x in { -0.65, 0, 0.65 } do
		wood(m, "Spindle", Vector3.new(0.15, 2, 0.15), at(x, 3.2, 0.85), DARK, DECOR)
	end
	for _, x in { -0.8, 0.8 } do
		for _, z in { -0.8, 0.8 } do
			wood(m, "Leg", Vector3.new(0.25, 1.85, 0.25), at(x, 0.93, z), DARK)
		end
	end
	deco(m, "Pad", Vector3.new(1.7, 0.2, 1.7), at(0, 2.27, -0.05), rgb(170, 60, 50), { Material = Enum.Material.Fabric })
	return m
end

local function floorLamp(parent, x, z, range)
	local m = model(parent, "FloorLamp")
	cyl(m, "Base", 0.3, 1.8, Vector3.new(x, FT + 0.15, z), DARK)
	cyl(m, "Pole", 7, 0.3, Vector3.new(x, FT + 3.5, z), WALNUT, DECOR)
	cyl(m, "Shade", 1.8, 2.6, Vector3.new(x, FT + 7.4, z), rgb(245, 225, 185), DECOR)
	local bulb = ball(m, "Bulb", 0.8, Vector3.new(x, FT + 7, z), rgb(255, 230, 180), { Material = Enum.Material.Neon })
	light(bulb, WARM, range or 18, 1)
	return m
end

local function plant(parent, x, z, scale)
	scale = scale or 1
	local m = model(parent, "Plant")
	cyl(m, "Pot", 2 * scale, 2.4 * scale, Vector3.new(x, FT + scale, z), rgb(185, 105, 75))
	cyl(m, "Soil", 0.1, 2.1 * scale, Vector3.new(x, FT + 2 * scale + 0.02, z), rgb(80, 55, 40), DECOR)
	for _, p in { { 0, 3.6, 0, 3.2 }, { 0.9, 4.6, 0.4, 2.4 }, { -0.8, 4.8, -0.5, 2.2 }, { 0.2, 5.6, -0.2, 1.8 } } do
		ball(m, "Leaves", p[4] * scale, Vector3.new(x + p[1] * scale, FT + p[2] * scale, z + p[3] * scale), rgb(80, 150, 80), { Material = Enum.Material.Grass })
	end
	return m
end

-- 들보에 매단 화분
local function hangingPlant(parent, x, z)
	local m = model(parent, "HangingPlant")
	deco(m, "Rope", Vector3.new(0.12, 2.6, 0.12), Vector3.new(x, TOP - 2.1, z), rgb(200, 180, 140))
	cyl(m, "Basket", 1, 2, Vector3.new(x, TOP - 3.8, z), rgb(170, 120, 70), merge(DECOR, { Material = Enum.Material.Fabric }))
	for _, p in { { 0, -3.2, 0, 1.8 }, { 0.7, -4.4, 0.3, 1 }, { -0.6, -4.8, -0.2, 1 }, { 0.1, -5.3, 0.5, 0.8 } } do
		ball(m, "Vine", p[4], Vector3.new(x + p[1], TOP + p[2], z + p[3]), rgb(90, 165, 85), { Material = Enum.Material.Grass })
	end
	return m
end

local old = workspace:FindFirstChild("Lobby")
if old then
	old:Destroy()
end
local lobby = Instance.new("Folder")
lobby.Name = "Lobby"
local structure = Instance.new("Folder")
structure.Name = "Structure"
structure.Parent = lobby
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = lobby

--------------------------------------------------------------------------------
-- 방: 바닥, 바깥 막벽, 통나무 벽, 판벽, 천장·들보·기둥, 꼬마전구, 샹들리에, 벽 등불

part(structure, "WoodFloor", Vector3.new(100, 1, 80), Vector3.new(0, 0.5, CENTER_Z), HONEY, { Material = Enum.Material.WoodPlanks })
for _, b in
	{
		{ Vector3.new(100, 0.06, 1.6), Vector3.new(0, FT + 0.03, Z1 + 0.8) },
		{ Vector3.new(100, 0.06, 1.6), Vector3.new(0, FT + 0.03, Z2 - 0.8) },
		{ Vector3.new(1.6, 0.06, 80), Vector3.new(X1 + 0.8, FT + 0.03, CENTER_Z) },
		{ Vector3.new(1.6, 0.06, 80), Vector3.new(X2 - 0.8, FT + 0.03, CENTER_Z) },
	}
do
	deco(decor, "FloorBorder", b[1], b[2], WALNUT, { Material = Enum.Material.WoodPlanks })
end

local H = TOP - FT
part(structure, "BackWall", Vector3.new(104, H, 2), Vector3.new(0, FT + H / 2, Z1 - 1), DARK, { Material = Enum.Material.Wood })
part(structure, "BackWall", Vector3.new(104, H, 2), Vector3.new(0, FT + H / 2, Z2 + 1), DARK, { Material = Enum.Material.Wood })
part(structure, "BackWall", Vector3.new(2, H, 84), Vector3.new(X1 - 1, FT + H / 2, CENTER_Z), DARK, { Material = Enum.Material.Wood })
part(structure, "BackWall", Vector3.new(2, H, 84), Vector3.new(X2 + 1, FT + H / 2, CENTER_Z), DARK, { Material = Enum.Material.Wood })

-- 판벽 (높이 4.5): 판, 세로 덧대, 위 손잡이 띠
local PANEL_H = 4.5
local function wainscot(alongX, fixed, inward, a, b)
	local length = b - a
	local mid = (a + b) / 2
	local function at(along, y, depthOffset)
		local d = fixed + inward * depthOffset
		return if alongX then Vector3.new(along, y, d) else Vector3.new(d, y, along)
	end
	local function size(lengthSize, h, depth)
		return if alongX then Vector3.new(lengthSize, h, depth) else Vector3.new(depth, h, lengthSize)
	end
	wood(structure, "Wainscot", size(length, PANEL_H, 0.4), at(mid, FT + PANEL_H / 2, 0.2), WALNUT)
	wood(decor, "Rail", size(length, 0.45, 0.9), at(mid, FT + PANEL_H + 0.1, 0.45), HONEY, DECOR)
	wood(decor, "Baseboard", size(length, 0.6, 0.6), at(mid, FT + 0.3, 0.3), DARK, DECOR)
	local step = 5
	local t = a + step / 2
	while t < b do
		wood(decor, "Batten", size(0.35, PANEL_H - 0.9, 0.15), at(t, FT + PANEL_H / 2, 0.47), CHERRY, DECOR)
		t += step
	end
end
wainscot(true, Z1, 1, X1, X2)
wainscot(true, Z2, -1, X1, X2)
wainscot(false, X1, 1, Z1, Z2)
wainscot(false, X2, -1, Z1, Z2)

-- 통나무 벽: 판벽 위부터 천장까지, 벽면에 반쯤 묻혀 앞으로 둥글게 나온다
local LOG_D = 1.5
local logBottom = FT + PANEL_H + 0.3
local logCount = math.floor((TOP - logBottom) / LOG_D)
for i = 0, logCount - 1 do
	local y = logBottom + LOG_D / 2 + i * LOG_D
	local color = if i % 2 == 0 then LOG_A else LOG_B
	part(structure, "Log", Vector3.new(100, LOG_D, LOG_D), CFrame.new(0, y, Z1), color, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
	part(structure, "Log", Vector3.new(100, LOG_D, LOG_D), CFrame.new(0, y, Z2), color, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
	part(structure, "Log", Vector3.new(80, LOG_D, LOG_D), CFrame.new(X1, y, CENTER_Z) * CFrame.Angles(0, math.rad(90), 0), color, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
	part(structure, "Log", Vector3.new(80, LOG_D, LOG_D), CFrame.new(X2, y, CENTER_Z) * CFrame.Angles(0, math.rad(90), 0), color, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
end
local plateY = logBottom + logCount * LOG_D
deco(decor, "TopPlate", Vector3.new(100, TOP - plateY + 0.1, 1.2), Vector3.new(0, (plateY + TOP) / 2, Z1 + 0.6), DARK, { Material = Enum.Material.Wood })
deco(decor, "TopPlate", Vector3.new(100, TOP - plateY + 0.1, 1.2), Vector3.new(0, (plateY + TOP) / 2, Z2 - 0.6), DARK, { Material = Enum.Material.Wood })

-- 천장(판자), 들보, 기둥
part(structure, "Ceiling", Vector3.new(104, 1, 84), Vector3.new(0, TOP + 0.5, CENTER_Z), CHERRY, { Material = Enum.Material.WoodPlanks })
for _, x in { -40, -20, 0, 20, 40 } do
	deco(decor, "Beam", Vector3.new(1.8, 1.5, 80), Vector3.new(x, TOP - 0.75, CENTER_Z), DARK, { Material = Enum.Material.Wood })
end
for _, z in { 480, 520 } do
	deco(decor, "CrossBeam", Vector3.new(100, 1.3, 1.6), Vector3.new(0, TOP - 1.9, z), WALNUT, { Material = Enum.Material.Wood })
end
for _, p in { { X1 + 1, Z1 + 1 }, { X2 - 1, Z1 + 1 }, { X1 + 1, Z2 - 1 }, { X2 - 1, Z2 - 1 }, { X1 + 1, CENTER_Z }, { X2 - 1, CENTER_Z } } do
	cyl(structure, "Post", H, 2.2, Vector3.new(p[1], FT + H / 2, p[2]), DARK, { Material = Enum.Material.Wood })
end

-- 들보에 매단 꼬마전구 (빛은 없이 반짝임만)
for _, z in { 480, 520 } do
	for i = 0, 31 do
		local x = -46.5 + i * 3
		local sag = math.sin((i % 4) / 4 * math.pi) * 0.6
		ball(decor, "Bulb", 0.4, Vector3.new(x, TOP - 2.9 - sag, z), if i % 3 == 0 then rgb(255, 220, 140) elseif i % 3 == 1 then rgb(255, 180, 120) else rgb(255, 240, 190), { Material = Enum.Material.Neon })
	end
end

-- 나무 샹들리에
local function chandelier(x, z)
	local m = model(decor, "Chandelier")
	local y = TOP - 4.6
	deco(m, "Chain", Vector3.new(0.25, 3.4, 0.25), Vector3.new(x, TOP - 2.9, z), rgb(60, 50, 40))
	for i = 0, 7 do
		local a = i * math.pi / 4
		deco(m, "Ring", Vector3.new(1.9, 0.4, 0.5), CFrame.new(x + math.cos(a) * 2.3, y, z + math.sin(a) * 2.3) * CFrame.Angles(0, -a + math.pi / 2, 0), WALNUT, { Material = Enum.Material.Wood })
		local cx, cz = x + math.cos(a + math.pi / 8) * 2.4, z + math.sin(a + math.pi / 8) * 2.4
		cyl(m, "Candle", 0.8, 0.3, Vector3.new(cx, y + 0.6, cz), CREAM, DECOR)
		ball(m, "Flame", 0.3, Vector3.new(cx, y + 1.15, cz), rgb(255, 200, 110), { Material = Enum.Material.Neon })
	end
	for i = 0, 3 do
		local a = i * math.pi / 2
		deco(m, "Arm", Vector3.new(2.4, 0.25, 0.25), CFrame.new(x + math.cos(a) * 1.15, y + 0.4, z + math.sin(a) * 1.15) * CFrame.Angles(0, -a, math.rad(12)), WALNUT)
	end
	local core = ball(m, "Core", 0.9, Vector3.new(x, y + 0.6, z), rgb(255, 220, 160), { Material = Enum.Material.Neon })
	light(core, WARM, 44, 1.5)
end
chandelier(-20, CENTER_Z)
chandelier(20, CENTER_Z)

-- 벽 등불 (랜턴)
local function sconce(position, face)
	local m = model(decor, "Sconce")
	local base = CFrame.lookAt(position, position + face)
	deco(m, "Bracket", Vector3.new(0.3, 0.3, 1.2), base * CFrame.new(0, 0.9, -0.4), rgb(50, 40, 35))
	deco(m, "Lantern", Vector3.new(0.9, 1.3, 0.9), base * CFrame.new(0, 0, -0.9), rgb(60, 45, 35))
	local glow = deco(m, "Glow", Vector3.new(0.7, 0.9, 0.95), base * CFrame.new(0, 0, -0.9), rgb(255, 200, 120), { Material = Enum.Material.Neon, Transparency = 0.15 })
	deco(m, "Cap", Vector3.new(1.1, 0.3, 1.1), base * CFrame.new(0, 0.75, -0.9), rgb(50, 40, 35))
	light(glow, WARM, 16, 0.9)
end
local LOG_FACE = LOG_D / 2 + 0.1
sconce(Vector3.new(X1 + LOG_FACE, FT + 10, 489), Vector3.new(1, 0, 0))
sconce(Vector3.new(X2 - LOG_FACE, FT + 10, 499), Vector3.new(-1, 0, 0))
sconce(Vector3.new(-6, FT + 10, Z1 + LOG_FACE), Vector3.new(0, 0, 1))
sconce(Vector3.new(6, FT + 10, Z1 + LOG_FACE), Vector3.new(0, 0, 1))

--------------------------------------------------------------------------------
-- 같이 하기·혼자 하기 카펫과 표지판 (남쪽 벽)

local function rug(name, size, x, z, color, border, stripe, tag)
	local pad = part(lobby, name, size, Vector3.new(x, FT + 0.1, z), color, { Material = Enum.Material.Fabric, CanCollide = false })
	CollectionService:AddTag(pad, tag)
	deco(decor, name .. "Border", size + Vector3.new(1.6, -0.04, 1.6), Vector3.new(x, FT + 0.06, z), border, { Material = Enum.Material.Fabric })
	for _, dz in { -size.Z / 2 + 1.6, size.Z / 2 - 1.6 } do
		deco(decor, name .. "Stripe", Vector3.new(size.X - 2, 0.04, 0.6), Vector3.new(x, FT + 0.22, z + dz), stripe, { Material = Enum.Material.Fabric })
	end
	return pad
end
rug("TogetherPad", Vector3.new(24, 0.2, 20), -22, CENTER_Z - 18, rgb(110, 170, 100), rgb(70, 120, 70), rgb(230, 210, 160), "LobbyTogether")
rug("SoloPad", Vector3.new(20, 0.2, 16), 22, CENTER_Z - 18, rgb(100, 145, 200), rgb(60, 95, 150), rgb(230, 210, 160), "LobbySolo")

local SIGN_Z = Z1 + LOG_D / 2 + 0.2
local function padSign(name, x, title, hint, color)
	deco(decor, name .. "Frame", Vector3.new(19.4, 7.4, 0.4), Vector3.new(x, FT + 9.6, SIGN_Z), HONEY, { Material = Enum.Material.Wood })
	textBoard(decor, name, Vector3.new(18, 6, 0.3), Vector3.new(x, FT + 9.6, SIGN_Z + 0.3), Vector3.new(0, 0, 1), WALNUT, {
		{ position = UDim2.fromScale(0, 0.04), size = UDim2.fromScale(1, 0.56), font = Enum.Font.FredokaOne, color = color, text = title },
		{ position = UDim2.fromScale(0.05, 0.62), size = UDim2.fromScale(0.9, 0.3), font = Enum.Font.GothamMedium, color = CREAM, text = hint },
	})
end
padSign("TogetherSign", -22, "같이 하기", "초록 카펫 위에서 다른 플레이어를 기다려요", rgb(150, 230, 140))
padSign("SoloSign", 22, "혼자 하기", "파란 카펫 위에서 [혼자 하기]를 누르면 바로 시작", rgb(150, 200, 255))

-- 남쪽 벽 가운데 둥근 벽시계
do
	local clock = model(decor, "WallClock")
	local face = CFrame.lookAt(Vector3.new(0, FT + 13, SIGN_Z), Vector3.new(0, FT + 13, CENTER_Z))
	deco(clock, "Rim", Vector3.new(0.5, 4.6, 4.6), face * CFrame.Angles(0, math.rad(90), 0), WALNUT, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
	deco(clock, "Face", Vector3.new(0.2, 3.9, 3.9), face * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, math.rad(90), 0), CREAM, { Shape = Enum.PartType.Cylinder })
	deco(clock, "HourHand", Vector3.new(0.2, 1.1, 0.1), face * CFrame.new(0, 0.45, -0.35), DARK)
	deco(clock, "MinuteHand", Vector3.new(1.5, 0.15, 0.1), face * CFrame.new(0.6, 0, -0.35), DARK)
end
hangingPlant(decor, 0, 470)
hangingPlant(decor, -40, 470)
hangingPlant(decor, 40, 470)
hangingPlant(decor, -40, 530)
plant(decor, -46, 464.5, 1)

--------------------------------------------------------------------------------
-- 벽난로 (북쪽 벽 가운데), 장작, 괘종시계, 흔들의자, 털 러그, 고양이, 스폰 러그

do
	local fire = model(lobby, "Fireplace")
	local face = Z2 - LOG_D / 2 -- 통나무 앞
	local STONE = rgb(150, 140, 128)
	part(fire, "Hearth", Vector3.new(18, 0.6, 6), Vector3.new(0, FT + 0.3, face - 3.2), rgb(120, 115, 108), { Material = Enum.Material.Slate })
	part(fire, "Body", Vector3.new(15, 10, 3.6), Vector3.new(0, FT + 5, face - 1.6), STONE, { Material = Enum.Material.Cobblestone })
	deco(fire, "Opening", Vector3.new(7.5, 5.5, 0.3), Vector3.new(0, FT + 2.75, face - 3.45), rgb(28, 20, 18))
	wood(fire, "Lintel", Vector3.new(9, 0.9, 0.8), Vector3.new(0, FT + 6, face - 3.55), DARK)
	part(fire, "Mantel", Vector3.new(18, 1.4, 1.4), CFrame.new(0, FT + 10.6, face - 3.2) * CFrame.Angles(0, 0, 0), WALNUT, { Shape = Enum.PartType.Block, Material = Enum.Material.Wood })
	part(fire, "Chimney", Vector3.new(9, TOP - FT - 11.3, 3), Vector3.new(0, (FT + 11.3 + TOP) / 2, face - 1.4), STONE, { Material = Enum.Material.Cobblestone })
	for i, x in { -1.2, 0, 1.2 } do
		deco(fire, "Log", Vector3.new(3.2, 0.8, 0.8), CFrame.new(x * 0.8, FT + 1, face - 2.6) * CFrame.Angles(0, math.rad(60 * i), 0), rgb(110, 70, 40), { Shape = Enum.PartType.Cylinder })
	end
	local flame = ball(fire, "Flame", 2, Vector3.new(0, FT + 1.9, face - 2.6), rgb(255, 150, 60), { Material = Enum.Material.Neon, Transparency = 0.2 })
	ball(fire, "FlameTop", 1.2, Vector3.new(0.2, FT + 3, face - 2.6), rgb(255, 210, 90), { Material = Enum.Material.Neon, Transparency = 0.2 })
	local effect = Instance.new("Fire")
	effect.Size = 3.5
	effect.Heat = 5
	effect.Color = rgb(255, 140, 60)
	effect.SecondaryColor = rgb(255, 220, 120)
	effect.Parent = flame
	light(flame, rgb(255, 150, 80), 30, 2.2)
	textBoard(fire, "HomeSign", Vector3.new(8, 2.2, 0.3), Vector3.new(0, FT + 14, face - 3.3), Vector3.new(0, 0, -1), WALNUT, {
		{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 1), font = Enum.Font.FredokaOne, color = rgb(255, 215, 140), text = "우리 집" },
	})
	-- 선반 위: 양초, 액자, 작은 화분, 유리병
	local shelfY = FT + 11.3
	for _, x in { -7, 7 } do
		cyl(fire, "Candle", 1.2, 0.5, Vector3.new(x, shelfY + 0.6, face - 3.2), CREAM, DECOR)
		ball(fire, "CandleFlame", 0.35, Vector3.new(x, shelfY + 1.4, face - 3.2), rgb(255, 200, 100), { Material = Enum.Material.Neon })
	end
	for _, p in { { -4.6, rgb(140, 200, 240) }, { 4.4, rgb(250, 200, 140) } } do
		deco(fire, "PhotoFrame", Vector3.new(2, 2.4, 0.3), CFrame.new(p[1], shelfY + 1.2, face - 3) * CFrame.Angles(math.rad(-10), 0, 0), WALNUT)
		deco(fire, "Photo", Vector3.new(1.6, 2, 0.1), CFrame.new(p[1], shelfY + 1.2, face - 3.18) * CFrame.Angles(math.rad(-10), 0, 0), p[2])
	end
	cyl(fire, "Pot", 0.9, 1, Vector3.new(-2.4, shelfY + 0.45, face - 3.2), rgb(185, 105, 75), DECOR)
	ball(fire, "Leaves", 1.3, Vector3.new(-2.4, shelfY + 1.3, face - 3.2), rgb(90, 160, 90), { Material = Enum.Material.Grass })
	cyl(fire, "Jar", 1.2, 0.8, Vector3.new(2.3, shelfY + 0.6, face - 3.2), rgb(220, 190, 120), merge(DECOR, { Material = Enum.Material.Glass, Transparency = 0.25 }))

	-- 장작 더미 (오른쪽)
	local stack = model(fire, "Firewood")
	for row, count in { 4, 3, 2 } do
		for i = 0, count - 1 do
			local x = 11 + (i - (count - 1) / 2) * 1.25
			part(stack, "Firewood", Vector3.new(3.2, 1.2, 1.2), CFrame.new(x, FT + 0.6 + (row - 1) * 1.05, face - 2) * CFrame.Angles(0, math.rad(90), 0), if (row + i) % 2 == 0 then rgb(150, 100, 60) else rgb(125, 82, 50), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Wood })
		end
	end
	-- 괘종시계 (왼쪽)
	local clock = model(fire, "GrandfatherClock")
	wood(clock, "Case", Vector3.new(2.8, 9, 1.8), Vector3.new(-12, FT + 4.5, face - 1.2), WALNUT)
	wood(clock, "Crown", Vector3.new(3.2, 0.8, 2.1), Vector3.new(-12, FT + 9.3, face - 1.2), DARK)
	deco(clock, "Face", Vector3.new(0.1, 2, 2), CFrame.new(-12, FT + 7.6, face - 2.15) * CFrame.Angles(0, math.rad(90), 0), CREAM, { Shape = Enum.PartType.Cylinder })
	deco(clock, "Window", Vector3.new(1.6, 3.6, 0.1), Vector3.new(-12, FT + 3.8, face - 2.15), rgb(200, 180, 120), { Material = Enum.Material.Glass, Transparency = 0.4 })
	ball(clock, "Pendulum", 0.8, Vector3.new(-12, FT + 2.6, face - 1.9), rgb(220, 180, 70), { Material = Enum.Material.Metal })
	-- 흔들의자
	local rocking = model(fire, "RockingChair")
	local rb = facing(-10, face - 9, 0.5, 1)
	wood(rocking, "Seat", Vector3.new(2.4, 0.35, 2.4), rb * CFrame.new(0, 2, 0), OAK)
	wood(rocking, "Back", Vector3.new(2.4, 3.4, 0.3), rb * CFrame.new(0, 3.7, 1.1) * CFrame.Angles(math.rad(-10), 0, 0), OAK)
	for _, x in { -1.1, 1.1 } do
		wood(rocking, "Rocker", Vector3.new(0.3, 0.4, 3.6), rb * CFrame.new(x, 0.3, 0), DARK)
		wood(rocking, "Leg", Vector3.new(0.25, 1.6, 0.25), rb * CFrame.new(x, 1.1, 0.8), DARK)
		wood(rocking, "Leg", Vector3.new(0.25, 1.6, 0.25), rb * CFrame.new(x, 1.1, -0.8), DARK)
	end
	deco(rocking, "Blanket", Vector3.new(2.2, 0.3, 2.6), rb * CFrame.new(0, 2.3, 0.1), rgb(190, 70, 60), { Material = Enum.Material.Fabric })
	-- 털 러그와 고양이
	deco(fire, "FurRug", Vector3.new(12, 0.1, 3.4), Vector3.new(0, FT + 0.05, face - 7.2), rgb(240, 230, 210), { Material = Enum.Material.Fabric })
	local cat = model(fire, "Cat")
	local cz = face - 7.2
	cyl(cat, "Cushion", 0.6, 3.2, Vector3.new(8, FT + 0.3, cz), rgb(190, 70, 70), merge(DECOR, { Material = Enum.Material.Fabric }))
	deco(cat, "Body", Vector3.new(1.6, 1, 2.4), Vector3.new(8, FT + 1.1, cz), rgb(240, 160, 80))
	ball(cat, "Head", 1.2, Vector3.new(8, FT + 1.5, cz - 1.4), rgb(240, 160, 80))
	for _, x in { -0.35, 0.35 } do
		deco(cat, "Ear", Vector3.new(0.35, 0.35, 0.2), CFrame.new(8 + x, FT + 2.1, cz - 1.4) * CFrame.Angles(0, 0, math.rad(45)), rgb(240, 160, 80))
		ball(cat, "Eye", 0.18, Vector3.new(8 + x * 0.8, FT + 1.6, cz - 1.95), rgb(40, 40, 40))
	end
	deco(cat, "Tail", Vector3.new(0.3, 0.3, 1.6), CFrame.new(8.6, FT + 1, cz + 1.6) * CFrame.Angles(0, math.rad(40), 0), rgb(240, 160, 80))
end

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "SpawnLocation"
spawnLocation.Anchored = true
spawnLocation.Size = Vector3.new(14, 0.2, 10)
spawnLocation.CFrame = CFrame.new(0, FT + 0.1, CENTER_Z + 22)
spawnLocation.Color = rgb(200, 140, 95)
spawnLocation.Material = Enum.Material.Fabric
spawnLocation.TopSurface = Enum.SurfaceType.Smooth
spawnLocation.Duration = 0
spawnLocation.Neutral = true
spawnLocation.AllowTeamChangeOnTouch = false
spawnLocation.Parent = lobby
deco(decor, "SpawnRugBorder", Vector3.new(15.6, 0.16, 11.6), Vector3.new(0, FT + 0.06, CENTER_Z + 22), rgb(150, 85, 60), { Material = Enum.Material.Fabric })

--------------------------------------------------------------------------------
-- 거실 (북서): TV 장식장, 양쪽 책장, L자 가죽 소파, 커피 테이블, 안락의자, 러그, 스탠드

do
	local living = model(lobby, "LivingRoom")
	local wallX = X1 + LOG_D / 2 -- 통나무 앞
	local z = CENTER_Z + 14
	-- TV 장식장과 TV
	wood(living, "TVCabinet", Vector3.new(3, 3.2, 12), Vector3.new(wallX + 1.6, FT + 1.6, z), CHERRY)
	for _, dz in { -3, 0, 3 } do
		deco(living, "CabinetDoor", Vector3.new(0.1, 2.4, 2.6), Vector3.new(wallX + 3.12, FT + 1.6, z + dz), OAK)
		ball(living, "Knob", 0.25, Vector3.new(wallX + 3.2, FT + 1.6, z + dz + 1), rgb(220, 180, 80))
	end
	deco(living, "TV", Vector3.new(0.5, 5.2, 9.2), Vector3.new(wallX + 1.2, FT + 6, z), rgb(30, 30, 35))
	deco(living, "Screen", Vector3.new(0.1, 4.6, 8.6), Vector3.new(wallX + 1.5, FT + 6, z), rgb(110, 160, 210), { Material = Enum.Material.Neon, Transparency = 0.35 })
	bookshelf(living, facing(wallX + 1.6, z - 9, 1, 0), 5, 11, 3, 1)
	bookshelf(living, facing(wallX + 1.6, z + 9, 1, 0), 5, 11, 3, 2)
	-- 러그 두 겹
	deco(living, "LivingRug", Vector3.new(24, 0.1, 22), Vector3.new(-36, FT + 0.05, z), rgb(150, 60, 50), { Material = Enum.Material.Fabric })
	deco(living, "LivingRugInner", Vector3.new(18, 0.1, 16), Vector3.new(-36, FT + 0.07, z), rgb(220, 190, 140), { Material = Enum.Material.Fabric })
	-- L자 소파: 서쪽(TV)을 보는 긴 소파 + 남쪽을 보는 짧은 소파
	local LEATHER = rgb(120, 72, 46)
	sofa(living, facing(-26, z, -1, 0), 14, LEATHER, "Sofa")
	sofa(living, facing(-33, z + 9.6, 0, -1), 9, LEATHER, "SofaSide")
	deco(living, "Throw", Vector3.new(0.4, 2.6, 3.4), CFrame.new(-24, FT + 3.1, z - 3) * CFrame.Angles(0, 0, math.rad(-10)), rgb(200, 150, 80), { Material = Enum.Material.Fabric })
	-- 커피 테이블
	wood(living, "CoffeeTop", Vector3.new(5, 0.5, 8), Vector3.new(-36, FT + 2.1, z), WALNUT)
	for _, p in { { -2, -3.4 }, { 2, -3.4 }, { -2, 3.4 }, { 2, 3.4 } } do
		wood(living, "CoffeeLeg", Vector3.new(0.5, 1.85, 0.5), Vector3.new(-36 + p[1], FT + 0.93, z + p[2]), DARK)
	end
	cyl(living, "Mug", 0.6, 0.6, Vector3.new(-35.2, FT + 2.65, z - 2), CREAM, DECOR)
	cyl(living, "Mug2", 0.6, 0.6, Vector3.new(-36.6, FT + 2.65, z - 1.2), rgb(200, 80, 70), DECOR)
	deco(living, "BookStack", Vector3.new(1.6, 0.6, 2), CFrame.new(-36.4, FT + 2.65, z + 2) * CFrame.Angles(0, math.rad(15), 0), rgb(70, 110, 160))
	cyl(living, "Candle", 0.8, 0.6, Vector3.new(-35.4, FT + 2.75, z + 0.4), CREAM, DECOR)
	ball(living, "CandleFlame", 0.3, Vector3.new(-35.4, FT + 3.3, z + 0.4), rgb(255, 200, 100), { Material = Enum.Material.Neon })
	deco(living, "Board", Vector3.new(2, 0.2, 2), Vector3.new(-37, FT + 2.45, z + 3.2), rgb(220, 200, 160))
	-- 안락의자 (남쪽에서 북쪽을 봄)
	sofa(living, facing(-37, z - 10, 0, 1), 4.6, rgb(150, 70, 50), "Armchair")
	floorLamp(living, -25.5, z + 9, 18)
	plant(living, -46, CENTER_Z + 36, 1.1)
end

--------------------------------------------------------------------------------
-- 주방 (북동): 조리대·가스레인지·싱크, 위 선반, 매달린 냄비, 냉장고, 사과 상자, 긴 식탁

do
	local kitchen = model(lobby, "Kitchen")
	local wallZ = Z2 - LOG_D / 2
	local cz = wallZ - 2
	wood(kitchen, "Counter", Vector3.new(24, 3.8, 4), Vector3.new(32, FT + 1.9, cz), CHERRY)
	wood(kitchen, "Butcherblock", Vector3.new(24.4, 0.6, 4.4), Vector3.new(32, FT + 4.1, cz), HONEY, { Material = Enum.Material.WoodPlanks })
	for i = 0, 5 do
		deco(kitchen, "CabinetDoor", Vector3.new(3.6, 2.8, 0.1), Vector3.new(22 + i * 4, FT + 1.8, cz - 2.02), OAK)
		ball(kitchen, "Knob", 0.3, Vector3.new(23.4 + i * 4, FT + 2.6, cz - 2.12), rgb(220, 180, 80))
	end
	deco(kitchen, "Stove", Vector3.new(4.2, 0.2, 3.2), Vector3.new(25, FT + 4.5, cz), rgb(40, 40, 45))
	for _, p in { { -1, -0.7 }, { 1, -0.7 }, { -1, 0.7 }, { 1, 0.7 } } do
		cyl(kitchen, "Burner", 0.1, 1, Vector3.new(25 + p[1], FT + 4.65, cz + p[2]), rgb(90, 90, 95), DECOR)
	end
	cyl(kitchen, "Pot", 1.2, 1.8, Vector3.new(24, FT + 5.25, cz - 0.6), rgb(190, 110, 60), merge(DECOR, { Material = Enum.Material.Metal }))
	cyl(kitchen, "Kettle", 1, 1.2, Vector3.new(26.2, FT + 5.1, cz + 0.6), rgb(200, 60, 50), merge(DECOR, { Material = Enum.Material.Metal }))
	deco(kitchen, "Sink", Vector3.new(3.8, 0.3, 2.8), Vector3.new(36, FT + 4.45, cz), rgb(190, 195, 205), { Material = Enum.Material.Metal })
	deco(kitchen, "Faucet", Vector3.new(0.3, 1.5, 0.3), Vector3.new(36, FT + 5.2, cz + 1.5), rgb(200, 170, 90), { Material = Enum.Material.Metal })
	deco(kitchen, "CuttingBoard", Vector3.new(2.6, 0.2, 1.8), Vector3.new(30.5, FT + 4.5, cz - 0.4), rgb(210, 170, 110))
	ball(kitchen, "Tomato", 0.6, Vector3.new(30.2, FT + 4.85, cz - 0.4), rgb(220, 50, 40))
	deco(kitchen, "Bread", Vector3.new(1.6, 0.8, 0.9), Vector3.new(41, FT + 4.8, cz - 0.3), rgb(210, 150, 80))
	-- 위 선반 두 줄: 유리병과 세운 접시
	for row, y in { 10.5, 13.5 } do
		wood(kitchen, "WallShelf", Vector3.new(22, 0.4, 1.6), Vector3.new(32, FT + y, wallZ - 0.8), WALNUT, DECOR)
		for i = 0, 8 do
			local x = 23 + i * 2.2
			if (i + row) % 3 == 0 then
				cyl(kitchen, "Plate", 0.15, 1.4, Vector3.new(x, FT + y + 0.9, wallZ - 0.6), CREAM, DECOR)
			else
				local tint = BOOK_COLORS[(i * 2 + row) % #BOOK_COLORS + 1]
				cyl(kitchen, "Jar", 1.2, 0.9, Vector3.new(x, FT + y + 0.8, wallZ - 0.8), rgb(220, 240, 245), merge(DECOR, { Material = Enum.Material.Glass, Transparency = 0.35 }))
				cyl(kitchen, "JarFill", 0.7, 0.75, Vector3.new(x, FT + y + 0.55, wallZ - 0.8), tint, DECOR)
				cyl(kitchen, "Lid", 0.2, 0.95, Vector3.new(x, FT + y + 1.5, wallZ - 0.8), WALNUT, DECOR)
			end
		end
	end
	-- 매달린 냄비 걸이
	deco(kitchen, "PotRack", Vector3.new(12, 0.3, 0.3), Vector3.new(30, TOP - 4.2, wallZ - 5.5), rgb(60, 50, 45), { Material = Enum.Material.Metal })
	for _, x in { 24.5, 35.5 } do
		deco(kitchen, "RackChain", Vector3.new(0.15, 3.4, 0.15), Vector3.new(x, TOP - 2.5, wallZ - 5.5), rgb(60, 50, 45))
	end
	for i, x in { 25.5, 28, 30.5, 33, 35 } do
		local d = 1.2 + (i % 2) * 0.4
		deco(kitchen, "Hook", Vector3.new(0.1, 0.8, 0.1), Vector3.new(x, TOP - 4.7, wallZ - 5.5), rgb(60, 50, 45))
		cyl(kitchen, "HangingPot", 0.5, d, Vector3.new(x, TOP - 5.3 - d / 4, wallZ - 5.5), if i % 2 == 0 then rgb(190, 110, 60) else rgb(70, 70, 75), merge(DECOR, { Material = Enum.Material.Metal }))
	end
	-- 냉장고 (북동 모서리)
	part(kitchen, "Fridge", Vector3.new(4.4, 9, 4.4), Vector3.new(X2 - 3.6, FT + 4.5, wallZ - 2.6), rgb(235, 225, 205))
	deco(kitchen, "FridgeHandle", Vector3.new(0.3, 2.6, 0.3), Vector3.new(X2 - 5.4, FT + 6, wallZ - 4.85), rgb(160, 150, 140))
	deco(kitchen, "Magnet", Vector3.new(0.8, 0.8, 0.1), Vector3.new(X2 - 3.2, FT + 6.6, wallZ - 4.85), rgb(255, 120, 140))
	-- 사과 상자
	local crate = model(kitchen, "AppleCrate")
	wood(crate, "Crate", Vector3.new(3, 1.8, 2.4), Vector3.new(17.5, FT + 0.9, wallZ - 2.5), OAK)
	for i = 0, 5 do
		ball(crate, "Apple", 0.7, Vector3.new(16.6 + (i % 3) * 0.9, FT + 2, wallZ - 3 + math.floor(i / 3) * 0.9), if i % 2 == 0 then rgb(210, 40, 40) else rgb(130, 190, 60))
	end
	-- 긴 식탁과 의자 6개, 펜던트 등
	local tz = CENTER_Z + 6
	local tx = 30
	wood(kitchen, "TableTop", Vector3.new(14, 0.6, 5.6), Vector3.new(tx, FT + 3.5, tz), WALNUT, { Material = Enum.Material.WoodPlanks })
	for _, p in { { -6.2, -2.2 }, { 6.2, -2.2 }, { -6.2, 2.2 }, { 6.2, 2.2 } } do
		wood(kitchen, "TableLeg", Vector3.new(0.6, 3.2, 0.6), Vector3.new(tx + p[1], FT + 1.6, tz + p[2]), DARK)
	end
	deco(kitchen, "Runner", Vector3.new(13, 0.05, 1.6), Vector3.new(tx, FT + 3.83, tz), rgb(170, 60, 50), { Material = Enum.Material.Fabric })
	for _, dx in { -4, 0, 4 } do
		chair(kitchen, facing(tx + dx, tz - 3.9, 0, 1), OAK)
		chair(kitchen, facing(tx + dx, tz + 3.9, 0, -1), OAK)
		for _, dz in { -1.6, 1.6 } do
			cyl(kitchen, "Plate", 0.1, 1.4, Vector3.new(tx + dx, FT + 3.86, tz + dz), CREAM, DECOR)
		end
	end
	cyl(kitchen, "FruitBowl", 0.6, 2, Vector3.new(tx - 1.8, FT + 4.1, tz), CREAM, DECOR)
	for i, c in { rgb(230, 60, 60), rgb(255, 200, 60), rgb(120, 200, 80) } do
		ball(kitchen, "Fruit", 0.7, Vector3.new(tx - 1.8 + (i - 2) * 0.55, FT + 4.6, tz + (i % 2) * 0.3), c)
	end
	cyl(kitchen, "Vase", 1.4, 0.8, Vector3.new(tx + 2, FT + 4.5, tz), rgb(120, 170, 200), merge(DECOR, { Material = Enum.Material.Glass, Transparency = 0.2 }))
	for i, c in { rgb(255, 120, 150), rgb(255, 220, 90), rgb(255, 255, 255) } do
		ball(kitchen, "Flower", 0.6, Vector3.new(tx + 2 + (i - 2) * 0.4, FT + 5.6 + (i % 2) * 0.3, tz), c)
	end
	for _, dx in { -3.5, 3.5 } do
		local pm = model(kitchen, "Pendant")
		deco(pm, "Cord", Vector3.new(0.15, 5, 0.15), Vector3.new(tx + dx, TOP - 2.5, tz), rgb(40, 35, 30))
		cyl(pm, "Shade", 1.2, 2.6, Vector3.new(tx + dx, TOP - 5.6, tz), rgb(60, 90, 70), merge(DECOR, { Material = Enum.Material.Metal }))
		local bulb = ball(pm, "Bulb", 0.8, Vector3.new(tx + dx, TOP - 6.3, tz), rgb(255, 230, 180), { Material = Enum.Material.Neon })
		light(bulb, WARM, 22, 1)
	end
end

--------------------------------------------------------------------------------
-- 남동: 피아노, 안락의자·발받침, 지구본, 큰 책장 / 동쪽 현관문

do
	local nook = model(lobby, "ReadingNook")
	local wallX = X2 - LOG_D / 2
	-- 피아노 (동쪽 벽, 방 쪽을 봄)
	local piano = model(nook, "Piano")
	local pb = facing(wallX - 1.2, 489, -1, 0)
	part(piano, "Body", Vector3.new(6.4, 4.8, 2.4), pb * CFrame.new(0, 2.4, 0), rgb(40, 25, 20), { Material = Enum.Material.Wood })
	part(piano, "KeyShelf", Vector3.new(6, 0.4, 1.2), pb * CFrame.new(0, 2.7, -1.6), rgb(40, 25, 20), { Material = Enum.Material.Wood })
	deco(piano, "WhiteKeys", Vector3.new(5.6, 0.15, 0.9), pb * CFrame.new(0, 2.96, -1.65), rgb(245, 240, 230))
	for i = 0, 10 do
		if i % 7 ~= 2 and i % 7 ~= 6 then
			deco(piano, "BlackKey", Vector3.new(0.22, 0.15, 0.5), pb * CFrame.new(-2.6 + i * 0.52, 3.08, -1.45), rgb(20, 20, 20))
		end
	end
	deco(piano, "Music", Vector3.new(1.8, 1.3, 0.1), pb * CFrame.new(0, 4.2, -1.1) * CFrame.Angles(math.rad(-15), 0, 0), CREAM)
	cyl(piano, "Candle", 1, 0.45, (pb * CFrame.new(2.6, 5.3, 0)).Position, CREAM, DECOR)
	ball(piano, "CandleFlame", 0.3, (pb * CFrame.new(2.6, 6, 0)).Position, rgb(255, 200, 100), { Material = Enum.Material.Neon })
	part(piano, "Bench", Vector3.new(3.2, 1.8, 1.3), pb * CFrame.new(0, 0.9, -3.4), rgb(40, 25, 20), { Material = Enum.Material.Wood })
	-- 안락의자와 발받침, 협탁
	sofa(nook, facing(38, 470, -1, 1), 4.6, rgb(90, 120, 80), "Armchair")
	wood(nook, "Ottoman", Vector3.new(2.4, 1.6, 2.4), Vector3.new(35, FT + 0.8, 473.5), rgb(90, 120, 80), { Material = Enum.Material.Fabric })
	wood(nook, "SideTable", Vector3.new(2.4, 2.8, 2.4), Vector3.new(42, FT + 1.4, 474.5), OAK)
	for i, c in { rgb(170, 50, 50), rgb(60, 100, 170), rgb(210, 170, 60) } do
		deco(nook, "Book", Vector3.new(1.6, 0.3, 1.2), Vector3.new(42, FT + 2.95 + i * 0.3, 474.5), c)
	end
	floorLamp(nook, 44.5, 469, 16)
	-- 지구본
	local globe = model(nook, "Globe")
	wood(globe, "Stand", Vector3.new(1.6, 2.6, 1.6), Vector3.new(34.5, FT + 1.3, 465), WALNUT)
	deco(globe, "Ring", Vector3.new(0.15, 2.5, 2.5), CFrame.new(34.5, FT + 3.9, 465) * CFrame.Angles(0, math.rad(90), 0), rgb(200, 170, 60), { Shape = Enum.PartType.Cylinder })
	ball(globe, "Earth", 2.1, Vector3.new(34.5, FT + 3.9, 465), rgb(80, 150, 220))
	for _, p in { { 0.6, 0.4, -0.7 }, { -0.7, -0.2, -0.6 }, { 0.2, -0.6, 0.8 } } do
		ball(globe, "Land", 0.9, Vector3.new(34.5 + p[1], FT + 3.9 + p[2], 465 + p[3]), rgb(110, 180, 90))
	end
	-- 큰 책장 (남쪽 벽 동쪽 끝)
	bookshelf(nook, facing(43, Z1 + LOG_D / 2 + 1.6, 0, 1), 9, 11, 3, 3)
	-- 현관문 (동쪽 벽)
	local dz = CENTER_Z + 8
	local door = model(nook, "FrontDoor")
	wood(door, "DoorFrame", Vector3.new(0.6, 11, 7.4), Vector3.new(wallX - 0.2, FT + 5.5, dz), DARK, DECOR)
	wood(door, "Door", Vector3.new(0.4, 10, 6), Vector3.new(wallX - 0.5, FT + 5, dz), CHERRY, DECOR)
	for _, y in { 2.5, 7.5 } do
		wood(door, "Panel", Vector3.new(0.1, 3.4, 4.4), Vector3.new(wallX - 0.75, FT + y, dz), OAK, DECOR)
	end
	ball(door, "Knob", 0.5, Vector3.new(wallX - 0.9, FT + 5, dz - 2.2), rgb(220, 180, 70), { Material = Enum.Material.Metal })
	cyl(door, "Wreath", 0.4, 2.8, Vector3.new(wallX - 0.9, FT + 8.2, dz), rgb(70, 130, 70), merge(DECOR, { Material = Enum.Material.Grass }))
	ball(door, "Bow", 0.6, Vector3.new(wallX - 1.15, FT + 7, dz), rgb(200, 40, 50))
	deco(door, "Doormat", Vector3.new(4, 0.1, 6), Vector3.new(wallX - 3, FT + 0.05, dz), rgb(150, 110, 70), { Material = Enum.Material.Fabric })
	-- 우산 통 통나무 통과 코트 걸이
	cyl(nook, "Barrel", 3, 2.4, Vector3.new(wallX - 2, FT + 1.5, dz + 6.5), OAK, { Material = Enum.Material.Wood })
	for _, y in { 0.6, 2.4 } do
		cyl(nook, "Hoop", 0.25, 2.5, Vector3.new(wallX - 2, FT + y, dz + 6.5), rgb(70, 70, 75), merge(DECOR, { Material = Enum.Material.Metal }))
	end
	for i, c in { rgb(200, 60, 60), rgb(60, 110, 180) } do
		deco(nook, "Umbrella", Vector3.new(0.3, 3.6, 0.3), CFrame.new(wallX - 2 + (i - 1.5) * 0.6, FT + 3.6, dz + 6.5) * CFrame.Angles(0, 0, math.rad((i - 1.5) * 16)), c)
	end
	plant(nook, wallX - 2.5, dz - 7, 1)
end

--------------------------------------------------------------------------------
-- 창문(나무 틀·커튼·꽃 상자)과 액자

local function window(x, z, faceX)
	local w = model(decor, "Window")
	local front = x - faceX * (LOG_D / 2 + 0.2) -- 통나무 앞
	local function at(depth)
		return front - faceX * depth
	end
	deco(w, "Frame", Vector3.new(0.5, 8.4, 9.4), Vector3.new(at(0), FT + 10, z), WALNUT, { Material = Enum.Material.Wood })
	deco(w, "Sky", Vector3.new(0.1, 7.4, 8.4), Vector3.new(at(0.3), FT + 10, z), rgb(170, 210, 245))
	deco(w, "MullionV", Vector3.new(0.1, 7.4, 0.35), Vector3.new(at(0.38), FT + 10, z), CREAM)
	deco(w, "MullionH", Vector3.new(0.1, 0.35, 8.4), Vector3.new(at(0.38), FT + 10, z), CREAM)
	wood(w, "Sill", Vector3.new(1.4, 0.5, 10), Vector3.new(at(0.6), FT + 5.6, z), OAK, DECOR)
	wood(w, "FlowerBox", Vector3.new(1.2, 1, 8), Vector3.new(at(0.7), FT + 6.3, z), CHERRY, DECOR)
	for i = 0, 6 do
		ball(w, "Flower", 0.8, Vector3.new(at(0.7), FT + 7.1, z - 3.3 + i * 1.1), if i % 3 == 0 then rgb(255, 120, 150) elseif i % 3 == 1 then rgb(255, 220, 90) else rgb(250, 250, 250))
	end
	for _, dz in { -5.6, 5.6 } do
		deco(w, "Curtain", Vector3.new(0.5, 10, 2.6), Vector3.new(at(0.9), FT + 9.4, z + dz), rgb(170, 55, 45), { Material = Enum.Material.Fabric })
		deco(w, "Tieback", Vector3.new(0.6, 0.3, 2.7), Vector3.new(at(0.95), FT + 7.5, z + dz), rgb(220, 180, 90))
	end
	deco(w, "CurtainRod", Vector3.new(0.3, 0.3, 14), Vector3.new(at(0.9), FT + 14.6, z), DARK)
end
window(X1, CENTER_Z - 22, -1)
window(X1, CENTER_Z - 2, -1)
window(X2, CENTER_Z - 24, 1)
window(X2, CENTER_Z + 26, 1)

local function picture(position, face, size, color)
	local p = model(decor, "Picture")
	deco(p, "Frame", Vector3.new(size.X + 0.8, size.Y + 0.8, 0.3), CFrame.lookAt(position, position + face), rgb(190, 150, 70), { Material = Enum.Material.Wood })
	deco(p, "Art", Vector3.new(size.X, size.Y, 0.1), CFrame.lookAt(position + face * 0.18, position + face * 2), color)
	deco(p, "Hill", Vector3.new(size.X, size.Y * 0.35, 0.1), CFrame.lookAt(position + face * 0.22 - Vector3.new(0, size.Y * 0.32, 0), position + face * 2 - Vector3.new(0, size.Y * 0.32, 0)), rgb(110, 160, 90))
	deco(p, "Sun", Vector3.new(size.X * 0.22, size.X * 0.22, 0.1), CFrame.lookAt(position + face * 0.25 + Vector3.new(size.X * 0.2, size.Y * 0.2, 0), position + face * 2), rgb(255, 210, 90), { Shape = Enum.PartType.Ball })
end
local northFront = Z2 - LOG_D / 2 - 0.2
picture(Vector3.new(-18, FT + 11, northFront), Vector3.new(0, 0, -1), Vector2.new(5, 3.6), rgb(150, 200, 235))
picture(Vector3.new(18, FT + 11.5, northFront - 1.6), Vector3.new(0, 0, -1), Vector2.new(4, 3), rgb(240, 190, 150))
picture(Vector3.new(X1 + LOG_D / 2 + 0.2, FT + 11, CENTER_Z + 30), Vector3.new(1, 0, 0), Vector2.new(4, 5), rgb(230, 200, 160))

lobby.Parent = workspace
local parts, lights = 0, 0
for _, d in lobby:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("PointLight") then
		lights += 1
	end
end
return `Lobby built · 파트 {parts} · 조명 {lights}`
