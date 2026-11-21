-- Stage4 (놀이공원) 맵 (2026-11-21 사용자 요청). common.luau 뒤에 붙여 실행한다.
-- 미로가 아닌 탁 트인 공원: 바깥 담장 320×320 안에 큰길(가로·세로 십자)과 고리 길, 가운데 분수 광장.
--   북서 관람차, 북동 롤러코스터(높은 고리 트랙, 아래로 지나다닐 수 있음), 남동 바이킹, 남서 회전목마,
--   남서 모서리 유령의 집(어두운 구역), 서쪽 나무숲(어두운 구역), 남·북 가장자리 상점·화장실, 북동 모서리 직원 건물(추격자 대기실).
--   나무·벤치·가로등·도로를 곳곳에 둔다.
-- 높이 규칙 (카메라 높이 제한과 함께 벽 너머를 못 보게): 놀이기구 위쪽·나무 잎·지붕은 부딪히지 않는 장식이라 올라갈 수 없고,
--   부딪히는 것은 바닥 판(높이 1~1.2)·세로 기둥·울타리(높이 4)·건물 벽(12~14)뿐이다.
-- 판자 4·문 4는 Barriers.luau의 Stage4 항목 (상점 사이 골목, 상점·유령의 집 문).

local CollectionService = game:GetService("CollectionService")
local FT = 1 -- 바닥 윗면

local f, maps = Map.newStage("Stage4")
local S = f.structure
local W = f.walls
local rides = Map.folder(f.root, "Rides")
local scenery = Map.folder(f.root, "Scenery")
local signs = Map.folder(f.root, "Signs")

local COSMETIC = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function merge(a, b)
	local out = table.clone(a)
	for k, v in b or {} do
		out[k] = v
	end
	return out
end

local function cpart(parent, name, size, cframe, color, props)
	local p = Map.part(parent, name, size, Vector3.zero, color, props)
	p.CFrame = cframe
	return p
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- a에서 b까지 굵기 t인 막대
local function beam(parent, name, a, b, t, color, props)
	local length = (b - a).Magnitude
	return cpart(parent, name, Vector3.new(t, t, length), CFrame.lookAt((a + b) / 2, b), color, props)
end

-- 세운 원기둥 (Roblox 원기둥 축은 X라 Z로 90° 돌림)
local function column(parent, name, x, z, y1, y2, diameter, color, props)
	return cpart(
		parent,
		name,
		Vector3.new(y2 - y1, diameter, diameter),
		CFrame.new(x, (y1 + y2) / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		merge({ Shape = Enum.PartType.Cylinder }, props)
	)
end

-- 바닥에 깐 원판
local function disc(parent, name, x, z, yTop, diameter, thickness, color, props)
	return column(parent, name, x, z, yTop - thickness, yTop, diameter, color, props)
end

-- 표지판: 앞면이 face 쪽을 본다. text는 Localization Signs의 한국어 원문과 같아야 번역된다
local function sign(parent, text, position, face, width, height, color)
	local board = cpart(
		parent,
		"Sign",
		Vector3.new(width, height, 0.4),
		CFrame.lookAt(position, position + face),
		"Institutional white",
		merge(COSMETIC, { Color = color or rgb(250, 240, 220) })
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rgb(120, 40, 90)
	label.Text = text
	label.Parent = gui
	return board
end

-- 벽 한 줄. alongX면 z = fixed에서 x 방향 [a, b], 아니면 x = fixed에서 z 방향. gap = {가운데, 폭}
local function wallLine(parent, alongX, fixed, a, b, gap, height, color)
	local function piece(p1, p2)
		local length = p2 - p1
		if length <= 0.05 then
			return
		end
		local size = if alongX then Vector3.new(length, height, 2) else Vector3.new(2, height, length)
		local pos = if alongX
			then Vector3.new((p1 + p2) / 2, FT + height / 2, fixed)
			else Vector3.new(fixed, FT + height / 2, (p1 + p2) / 2)
		Map.part(parent, "Wall", size, pos, "White", { Color = color })
	end
	a -= 1
	b += 1
	if gap then
		piece(a, gap[1] - gap[2] / 2)
		piece(gap[1] + gap[2] / 2, b)
	else
		piece(a, b)
	end
end

-- 상점 건물: 벽 높이 12, 앞면(front = "N"/"S")에 문 틈, 줄무늬 차양 지붕(장식), 안쪽 판매대, 앞면 위 표지판
local function shop(name, x1, x2, z1, z2, front, doorX, doorWidth, wallColor, stripe, label)
	local folder = Map.folder(S, name)
	local walls = Map.folder(folder, "Walls")
	local h = 12
	local frontZ = if front == "N" then z2 else z1
	local backZ = if front == "N" then z1 else z2
	wallLine(walls, true, frontZ, x1, x2, { doorX, doorWidth }, h, wallColor)
	wallLine(walls, true, backZ, x1, x2, nil, h, wallColor)
	wallLine(walls, false, x1, z1, z2, nil, h, wallColor)
	wallLine(walls, false, x2, z1, z2, nil, h, wallColor)
	-- 차양 지붕 (줄무늬)
	local count = math.floor((x2 - x1 + 2) / 4)
	local width = (x2 - x1 + 2) / count
	for i = 0, count - 1 do
		local color = if i % 2 == 0 then stripe else rgb(255, 250, 245)
		Map.part(
			folder,
			"Awning",
			Vector3.new(width, 0.6, z2 - z1 + 6),
			Vector3.new(x1 - 1 + width * (i + 0.5), FT + h + 0.3, (z1 + z2) / 2 + (if front == "N" then 2 else -2)),
			"White",
			merge(COSMETIC, { Color = color })
		)
	end
	-- 판매대 (뒷벽 쪽)
	local counterZ = if front == "N" then z1 + 3 else z2 - 3
	Map.part(
		folder,
		"Counter",
		Vector3.new(x2 - x1 - 8, 3.5, 2),
		Vector3.new((x1 + x2) / 2, FT + 1.75, counterZ),
		"White",
		{ Color = rgb(235, 220, 200) }
	)
	if label then
		local faceZ = if front == "N" then 1 else -1
		sign(signs, label, Vector3.new(doorX, FT + 9.6, frontZ + faceZ * 1.3), Vector3.new(0, 0, faceZ), 10, 2.6)
	end
	return folder
end

local function fenceRect(parent, x1, x2, z1, z2, color)
	local h = 4
	local function rail(alongX, fixed, a, b)
		local length = b - a
		local size = if alongX then Vector3.new(length, h, 0.6) else Vector3.new(0.6, h, length)
		local pos = if alongX
			then Vector3.new((a + b) / 2, FT + h / 2, fixed)
			else Vector3.new(fixed, FT + h / 2, (a + b) / 2)
		Map.part(parent, "Fence", size, pos, "White", { Color = color })
	end
	rail(true, z1, x1, x2)
	rail(true, z2, x1, x2)
	rail(false, x1, z1, z2)
	rail(false, x2, z1, z2)
	for _, p in { { x1, z1 }, { x1, z2 }, { x2, z1 }, { x2, z2 } } do
		Map.part(parent, "FencePost", Vector3.new(1, h + 0.8, 1), Vector3.new(p[1], FT + (h + 0.8) / 2, p[2]), "White", {
			Color = rgb(255, 255, 255),
		})
	end
end

local function tree(x, z, scale)
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = "Tree"
	Map.part(model, "Trunk", Vector3.new(1.4, 7, 1.4) * scale, Vector3.new(x, FT + 3.5 * scale, z), "Brown", {
		Material = Enum.Material.Wood,
	})
	for _, c in
		{
			{ 0, 8, 0, 8.5, rgb(76, 160, 70) },
			{ 2, 9.6, 1, 6, rgb(96, 180, 80) },
			{ -1.8, 10.2, -1.2, 5.5, rgb(66, 145, 66) },
		}
	do
		local d = c[4] * scale
		Map.part(
			model,
			"Leaves",
			Vector3.new(d, d, d),
			Vector3.new(x + c[1] * scale, FT + c[2] * scale, z + c[3] * scale),
			"Bright green",
			merge(COSMETIC, { Shape = Enum.PartType.Ball, Color = c[5], Material = Enum.Material.Grass })
		)
	end
	model.Parent = scenery
end

-- 벤치: yaw는 앉는 사람이 보는 방향 (Map.yawFor)
local function bench(x, z, lookX, lookZ)
	local model = Instance.new("Model")
	model.Name = "Bench"
	local base = CFrame.lookAt(Vector3.new(x, FT, z), Vector3.new(x + lookX, FT, z + lookZ))
	local wood = rgb(170, 110, 60)
	cpart(model, "Seat", Vector3.new(5, 0.4, 1.6), base * CFrame.new(0, 1.8, 0), "Brown", { Color = wood })
	cpart(model, "Back", Vector3.new(5, 1.4, 0.3), base * CFrame.new(0, 2.9, 0.75), "Brown", { Color = wood })
	for _, lx in { -2.1, 2.1 } do
		cpart(model, "Leg", Vector3.new(0.4, 1.6, 1.4), base * CFrame.new(lx, 0.8, 0), "Black")
	end
	model.Parent = scenery
end

local LAMP_COLOR = rgb(255, 214, 150)
local function lampPost(x, z)
	local model = Instance.new("Model")
	model.Name = "LampPost"
	column(model, "Pole", x, z, FT, FT + 11, 0.5, "Black", { Color = rgb(40, 40, 48) })
	local head = Map.part(
		model,
		"Lamp",
		Vector3.new(1.6, 1.6, 1.6),
		Vector3.new(x, FT + 11.6, z),
		"White",
		merge(COSMETIC, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = LAMP_COLOR })
	)
	local light = Instance.new("PointLight")
	light.Color = LAMP_COLOR
	light.Range = 28
	light.Brightness = 1.3
	light.Shadows = false
	light.Parent = head
	model.Parent = f.lights
end

--------------------------------------------------------------------------------
-- 바닥·담장·도로

Map.part(S, "Floor", Vector3.new(330, 1, 330), Vector3.new(0, 0.5, 0), "Bright green", {
	Material = Enum.Material.Grass,
	Color = rgb(96, 160, 80),
})
local ROAD = rgb(214, 196, 160)
local function road(x, z, sx, sz, top)
	Map.part(S, "Road", Vector3.new(sx, 0.2, sz), Vector3.new(x, top - 0.1, z), "White", {
		Color = ROAD,
		Material = Enum.Material.Pavement,
		CanCollide = false,
	})
end
road(0, 0, 16, 318, FT + 0.06) -- 큰길 (남북)
road(0, 0, 318, 16, FT + 0.055) -- 큰길 (동서)
road(0, -110, 232, 12, FT + 0.05) -- 고리 길
road(0, 110, 232, 12, FT + 0.05)
road(-110, 0, 12, 208, FT + 0.05)
road(110, 0, 12, 208, FT + 0.05)
disc(S, "Plaza", 0, 0, FT + 0.08, 48, 0.3, "White", { Color = rgb(232, 214, 180), CanCollide = false })

-- 바깥 담장 (높이 14). 남쪽 정문(출구 1), 북쪽 뒷문(출구 2)
Map.wallX(W, -160, -160, 160, { { -6, 6 } })
Map.wallX(W, 160, -160, 160, { { -86, -74 } })
Map.wallZ(W, -160, -160, 160, {})
Map.wallZ(W, 160, -160, 160, {})
for _, wall in W:GetChildren() do
	wall.Material = Enum.Material.Brick
	wall.Color = rgb(170, 90, 80)
end
Map.exit(f.exits, 1, 0, -160, 12, false)
Map.exit(f.exits, 2, -80, 160, 12, false)

-- 정문 아치
for _, x in { -8, 8 } do
	Map.part(S, "GatePillar", Vector3.new(2.4, 18, 2.4), Vector3.new(x, FT + 9, -160), "White", { Color = rgb(250, 230, 120) })
end
Map.part(S, "GateArch", Vector3.new(19, 3, 2.4), Vector3.new(0, FT + 19.5, -160), "White", merge(COSMETIC, {
	Color = rgb(240, 110, 150),
}))
sign(signs, "별빛 놀이공원", Vector3.new(0, FT + 19.5, -158.6), Vector3.new(0, 0, 1), 16, 2.6, rgb(255, 245, 210))

-- 분수 (광장 가운데)
local fountain = Instance.new("Model")
fountain.Name = "Fountain"
disc(fountain, "Rim", 0, 0, FT + 2.5, 16, 2.5, "White", { Color = rgb(225, 225, 235), Material = Enum.Material.Marble })
disc(fountain, "Water", 0, 0, FT + 2.65, 14, 0.3, "White", merge(COSMETIC, {
	Color = rgb(110, 190, 255),
	Material = Enum.Material.Glass,
	Transparency = 0.25,
}))
column(fountain, "Pillar", 0, 0, FT + 2.5, FT + 7, 2, "White", { Color = rgb(225, 225, 235), Material = Enum.Material.Marble })
disc(fountain, "Bowl", 0, 0, FT + 7.6, 6, 0.6, "White", merge(COSMETIC, { Color = rgb(225, 225, 235) }))
Map.part(fountain, "Spout", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, FT + 8.3, 0), "White", merge(COSMETIC, {
	Shape = Enum.PartType.Ball,
	Material = Enum.Material.Neon,
	Color = rgb(160, 220, 255),
}))
fountain.Parent = S

--------------------------------------------------------------------------------
-- 관람차 (북서)

do
	local cx, cz = -56, 58
	local model = Instance.new("Model")
	model.Name = "FerrisWheel"
	local hubY = FT + 27
	local r = 22
	local center = Vector3.new(cx, hubY, cz)
	local base = CFrame.new(center)
	local frame = rgb(245, 245, 250)
	Map.part(model, "Platform", Vector3.new(32, 1, 9), Vector3.new(cx, FT + 0.5, cz), "White", { Color = rgb(200, 200, 210) })
	for _, side in { -1, 1 } do
		for _, dz in { -1, 1 } do
			beam(model, "Leg", Vector3.new(cx + side * 13, FT + 1, cz + dz * 3.5), center + Vector3.new(0, 0, dz * 1.6), 1.2, "White", merge(COSMETIC, { Color = frame }))
		end
	end
	cpart(model, "Hub", Vector3.new(4.4, 3.2, 3.2), base * CFrame.Angles(0, math.rad(90), 0), "White", merge(COSMETIC, {
		Shape = Enum.PartType.Cylinder,
		Color = rgb(250, 200, 90),
	}))
	local segments = 24
	for _, dz in { -1.4, 1.4 } do
		for i = 0, segments - 1 do
			local theta = i * 2 * math.pi / segments
			cpart(model, "Rim", Vector3.new(2 * math.pi * r / segments + 0.3, 0.7, 0.7), base * CFrame.new(0, 0, dz) * CFrame.Angles(0, 0, theta) * CFrame.new(0, r, 0), "White", merge(COSMETIC, { Color = frame }))
		end
		for i = 0, 11 do
			local theta = i * 2 * math.pi / 12
			cpart(model, "Spoke", Vector3.new(0.35, r, 0.35), base * CFrame.new(0, 0, dz) * CFrame.Angles(0, 0, theta) * CFrame.new(0, r / 2, 0), "White", merge(COSMETIC, { Color = frame }))
		end
	end
	local cabinColors = { rgb(255, 120, 140), rgb(255, 190, 90), rgb(255, 235, 110), rgb(130, 220, 140), rgb(110, 190, 255), rgb(190, 140, 255) }
	for i = 0, 11 do
		local theta = i * 2 * math.pi / 12 + math.pi / 12
		local p = center + Vector3.new(-math.sin(theta) * r, math.cos(theta) * r, 0)
		local color = cabinColors[i % #cabinColors + 1]
		Map.part(model, "Cabin", Vector3.new(3, 2.6, 3), p - Vector3.new(0, 2.4, 0), "White", merge(COSMETIC, { Color = color }))
		Map.part(model, "CabinRoof", Vector3.new(3.4, 0.4, 3.4), p - Vector3.new(0, 0.9, 0), "White", merge(COSMETIC, { Color = rgb(255, 255, 255) }))
		Map.part(model, "Hanger", Vector3.new(0.25, 1, 0.25), p - Vector3.new(0, 0.3, 0), "Black", COSMETIC)
	end
	model.Parent = rides
	fenceRect(rides, cx - 24, cx + 24, cz - 9, cz + 9, rgb(255, 255, 255))
	sign(signs, "관람차", Vector3.new(cx, FT + 6, cz - 9.6), Vector3.new(0, 0, -1), 8, 2.2)
end

--------------------------------------------------------------------------------
-- 롤러코스터 (북동). 트랙은 높이 15 이상이라 아래로 지나다닌다. 기둥만 부딪힌다

do
	local cx, cz, rx, rz = 80, 80, 46, 34
	local model = Instance.new("Model")
	model.Name = "RollerCoaster"
	local n = 44
	local points = {}
	for i = 0, n - 1 do
		local t = i / n * 2 * math.pi
		local y = FT + 15 + 5 * (1 + math.sin(2 * t)) + 7 * math.max(0, math.sin(t))
		points[i + 1] = Vector3.new(cx + rx * math.cos(t), y, cz + rz * math.sin(t))
	end
	for i, a in points do
		local b = points[i % n + 1]
		local length = (b - a).Magnitude + 0.2
		local cf = CFrame.lookAt((a + b) / 2, b)
		cpart(model, "Track", Vector3.new(3, 0.4, length), cf, "White", merge(COSMETIC, { Color = rgb(235, 70, 80) }))
		for _, s in { -1, 1 } do
			cpart(model, "Rail", Vector3.new(0.3, 0.3, length), cf * CFrame.new(s * 1.2, 0.35, 0), "White", merge(COSMETIC, {
				Color = rgb(245, 245, 250),
			}))
		end
		if i % 2 == 1 then
			column(model, "Support", a.X, a.Z, FT, a.Y - 0.3, 1.2, "White", { Color = rgb(255, 210, 80) })
		end
	end
	-- 열차 (트랙 위에 멈춰 있음)
	for k = 0, 3 do
		local a = points[8 + k]
		local b = points[9 + k]
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 1.1, 0)
		cpart(model, "Car", Vector3.new(2.6, 1.6, 3.2), cf, "White", merge(COSMETIC, {
			Color = if k % 2 == 0 then rgb(60, 140, 255) else rgb(255, 220, 80),
		}))
	end
	model.Parent = rides
	sign(signs, "롤러코스터", Vector3.new(cx - rx - 2, FT + 6, cz), Vector3.new(-1, 0, 0), 9, 2.2)
	column(signs, "SignPole", cx - rx - 2, cz, FT, FT + 4.9, 0.4, "White", COSMETIC)
end

--------------------------------------------------------------------------------
-- 바이킹 (남동). 배는 한쪽으로 기운 채 멈춰 있다

do
	local cx, cz = 56, -56
	local model = Instance.new("Model")
	model.Name = "Viking"
	local pivot = Vector3.new(cx, FT + 19, cz)
	local frame = rgb(90, 90, 110)
	Map.part(model, "Platform", Vector3.new(30, 1, 14), Vector3.new(cx, FT + 0.5, cz), "White", { Color = rgb(200, 200, 210) })
	for _, dz in { -5, 5 } do
		for _, side in { -1, 1 } do
			beam(model, "Frame", Vector3.new(cx + side * 11, FT + 1, cz + dz), pivot + Vector3.new(0, 0, dz), 1.4, "White", merge(COSMETIC, { Color = frame }))
		end
	end
	cpart(model, "Axle", Vector3.new(11.5, 1.2, 1.2), CFrame.new(pivot) * CFrame.Angles(0, math.rad(90), 0), "White", merge(COSMETIC, {
		Shape = Enum.PartType.Cylinder,
		Color = rgb(60, 60, 70),
	}))
	local ship = CFrame.new(pivot) * CFrame.Angles(0, 0, math.rad(18)) * CFrame.new(0, -12.5, 0)
	local wood = rgb(150, 90, 50)
	cpart(model, "Hull", Vector3.new(22, 1.6, 6), ship, "White", merge(COSMETIC, { Color = wood }))
	for _, s in { -1, 1 } do
		cpart(model, "HullSide", Vector3.new(22, 3, 0.6), ship * CFrame.new(0, 1.5, s * 3), "White", merge(COSMETIC, { Color = rgb(120, 70, 40) }))
		cpart(model, "Prow", Vector3.new(4, 4.4, 6.2), ship * CFrame.new(s * 12, 1.8, 0) * CFrame.Angles(0, 0, s * math.rad(-25)), "White", merge(COSMETIC, { Color = rgb(120, 70, 40) }))
		for _, dz in { -3.5, 3.5 } do
			beam(model, "Arm", pivot + Vector3.new(0, 0, dz), (ship * CFrame.new(s * 8, 3, dz)).Position, 0.8, "White", merge(COSMETIC, { Color = frame }))
		end
	end
	cpart(model, "DragonHead", Vector3.new(3, 2.4, 2), ship * CFrame.new(14.6, 4.6, 0), "White", merge(COSMETIC, { Color = rgb(90, 190, 110) }))
	for _, x in { -7.5, -2.5, 2.5, 7.5 } do
		cpart(model, "Seat", Vector3.new(1, 1, 5.4), ship * CFrame.new(x, 1.2, 0), "White", merge(COSMETIC, { Color = rgb(230, 60, 70) }))
	end
	cpart(model, "Mast", Vector3.new(0.6, 8, 0.6), ship * CFrame.new(0, 5.5, 0), "White", merge(COSMETIC, { Color = wood }))
	cpart(model, "Flag", Vector3.new(3, 2, 0.2), ship * CFrame.new(1.6, 8.4, 0), "White", merge(COSMETIC, { Color = rgb(240, 70, 70) }))
	model.Parent = rides
	fenceRect(rides, cx - 20, cx + 20, cz - 10, cz + 10, rgb(255, 255, 255))
	sign(signs, "바이킹", Vector3.new(cx, FT + 6, cz + 10.6), Vector3.new(0, 0, 1), 8, 2.2)
end

--------------------------------------------------------------------------------
-- 회전목마 (남서)

do
	local cx, cz = -56, -56
	local model = Instance.new("Model")
	model.Name = "Carousel"
	disc(model, "Platform", cx, cz, FT + 1.2, 24, 1.2, "White", { Color = rgb(250, 230, 200) })
	column(model, "CenterPole", cx, cz, FT + 1.2, FT + 13, 2.4, "White", { Color = rgb(250, 200, 90) })
	disc(model, "Roof", cx, cz, FT + 14, 27, 1, "White", merge(COSMETIC, { Color = rgb(240, 90, 120) }))
	disc(model, "RoofTop", cx, cz, FT + 15, 17, 1, "White", merge(COSMETIC, { Color = rgb(255, 250, 245) }))
	Map.part(model, "RoofBall", Vector3.new(3, 3, 3), Vector3.new(cx, FT + 16.4, cz), "White", merge(COSMETIC, {
		Shape = Enum.PartType.Ball,
		Color = rgb(255, 215, 80),
	}))
	local horseColors = { rgb(255, 255, 255), rgb(255, 200, 220), rgb(200, 230, 255), rgb(255, 240, 180) }
	for i = 0, 7 do
		local a = i * math.pi / 4
		local x, z = cx + 8.5 * math.cos(a), cz + 8.5 * math.sin(a)
		local face = CFrame.lookAt(Vector3.new(x, FT, z), Vector3.new(x - math.sin(a), FT, z + math.cos(a)))
		local lift = if i % 2 == 0 then 3.4 else 4.2
		column(model, "HorsePole", x, z, FT + 1.2, FT + 13.5, 0.3, "White", merge(COSMETIC, { Color = rgb(255, 215, 80) }))
		local color = horseColors[i % #horseColors + 1]
		cpart(model, "HorseBody", Vector3.new(1.2, 1.4, 3.2), face * CFrame.new(0, lift, 0), "White", merge(COSMETIC, { Color = color }))
		cpart(model, "HorseHead", Vector3.new(1, 1.6, 1.1), face * CFrame.new(0, lift + 1, -1.8) * CFrame.Angles(math.rad(20), 0, 0), "White", merge(COSMETIC, { Color = color }))
		cpart(model, "HorseMane", Vector3.new(0.4, 1.4, 1), face * CFrame.new(0, lift + 1.2, -1.2), "White", merge(COSMETIC, { Color = rgb(250, 140, 170) }))
	end
	for i = 0, 11 do
		local a = i * math.pi / 6
		Map.part(model, "Bulb", Vector3.new(0.6, 0.6, 0.6), Vector3.new(cx + 13.2 * math.cos(a), FT + 13.3, cz + 13.2 * math.sin(a)), "White", merge(COSMETIC, {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
			Color = rgb(255, 230, 150),
		}))
	end
	model.Parent = rides
	sign(signs, "회전목마", Vector3.new(cx + 15, FT + 5, cz + 10), Vector3.new(1, 0, 1).Unit, 8, 2.2)
	column(signs, "SignPole", cx + 15, cz + 10, FT, FT + 3.9, 0.4, "White", COSMETIC)
end

--------------------------------------------------------------------------------
-- 유령의 집 (남서 모서리, 어두운 구역). 동쪽 문(Barriers Door4)과 북쪽 열린 입구

local dark = Map.folder(f.root, "DarkZones")
do
	local house = Map.folder(S, "HauntedHouse")
	local walls = Map.folder(house, "Walls")
	local color = rgb(70, 50, 90)
	wallLine(walls, false, -124, -152, -126, { -139, 8 }, 14, color) -- 동쪽 (문)
	wallLine(walls, true, -126, -154, -124, { -139, 8 }, 14, color) -- 북쪽 (열린 입구)
	wallLine(walls, true, -152, -154, -124, nil, 14, color)
	wallLine(walls, false, -154, -152, -126, nil, 14, color)
	wallLine(walls, false, -139, -152, -135, nil, 14, color) -- 안쪽 칸막이
	Map.part(house, "Roof", Vector3.new(32, 0.6, 28), Vector3.new(-139, FT + 14.3, -139), "White", merge(COSMETIC, { Color = rgb(45, 30, 60) }))
	for _, p in { { -152, -150 }, { -126, -150 }, { -152, -128 }, { -126, -128 } } do
		Map.part(house, "Spire", Vector3.new(2.4, 5, 2.4), Vector3.new(p[1], FT + 17, p[2]), "White", merge(COSMETIC, { Color = rgb(45, 30, 60) }))
	end
	sign(signs, "유령의 집", Vector3.new(-122.6, FT + 10.5, -139), Vector3.new(1, 0, 0), 10, 2.6, rgb(60, 40, 70))
	Map.darkZone(dark, "DarkHauntedHouse", -139, -139, 28, 24)
end
-- 서쪽 나무숲 (어두운 구역, 가로등 없음)
Map.darkZone(dark, "DarkGrove", -138, 10, 40, 100)
for row, x in { -150, -138, -126 } do
	for col, z in { -34, -18, -2, 14, 30, 46 } do
		tree(x + (if col % 2 == 0 then 3 else -2), z + (if row == 2 then 6 else 0), 1.1)
	end
end

--------------------------------------------------------------------------------
-- 상점·화장실·매표소·직원 건물

local SHOP_WALL = rgb(255, 236, 200)
shop("PopcornShop", -74, -46, -150, -134, "N", -60, 8, SHOP_WALL, rgb(240, 80, 90), "팝콘")
shop("SouvenirShop", 46, 74, -150, -134, "N", 60, 8, SHOP_WALL, rgb(90, 150, 240), "기념품")
shop("IceCreamShop", -74, -46, 134, 150, "S", -60, 8, SHOP_WALL, rgb(255, 150, 200), "아이스크림")
shop("GiftShop", 46, 74, 134, 150, "S", 60, 8, SHOP_WALL, rgb(120, 200, 140), "기념품")
shop("RestroomSW", -100, -84, -148, -134, "N", -92, 6, rgb(220, 235, 255), rgb(120, 170, 230), "화장실")
shop("RestroomSE", 84, 100, -148, -134, "N", 92, 6, rgb(220, 235, 255), rgb(120, 170, 230), "화장실")
shop("Storage", -100, -84, 134, 148, "S", -92, 6, rgb(230, 220, 200), rgb(180, 150, 110), nil)
shop("RestroomNE", 84, 100, 134, 148, "S", 92, 6, rgb(220, 235, 255), rgb(120, 170, 230), "화장실")

for _, x in { -14, 14 } do
	local booth = Instance.new("Model")
	booth.Name = "TicketBooth"
	Map.part(booth, "Booth", Vector3.new(6, 9, 6), Vector3.new(x, FT + 4.5, -150), "White", { Color = rgb(255, 200, 120) })
	Map.part(booth, "Window", Vector3.new(4, 3, 0.3), Vector3.new(x, FT + 5, -146.9), "White", merge(COSMETIC, {
		Color = rgb(170, 220, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	}))
	Map.part(booth, "BoothRoof", Vector3.new(7.4, 0.8, 7.4), Vector3.new(x, FT + 9.4, -150), "White", merge(COSMETIC, { Color = rgb(240, 90, 110) }))
	booth.Parent = S
	sign(signs, "매표소", Vector3.new(x, FT + 7.4, -146.7), Vector3.new(0, 0, 1), 5, 1.4)
end

-- 직원 건물 = 추격자 대기실 (북동 모서리, 서쪽에 대기실 문)
do
	local staff = Map.folder(S, "StaffBuilding")
	local walls = Map.folder(staff, "Walls")
	local color = rgb(200, 200, 210)
	wallLine(walls, true, 136, 136, 159, nil, 14, color)
	wallLine(walls, false, 136, 136, 159, { 147.5, 8 }, 14, color)
	Map.part(staff, "Roof", Vector3.new(25, 0.6, 25), Vector3.new(147.5, FT + 14.3, 147.5), "White", merge(COSMETIC, { Color = rgb(120, 120, 135) }))
	sign(signs, "직원 전용", Vector3.new(134.6, FT + 12.2, 147.5), Vector3.new(-1, 0, 0), 8, 2, rgb(255, 230, 120))
	Map.marker(f.chaserRoom, "ChaserSpawn", "ChaserSpawn", 148, 148, 4, "Bright red", Map.yawFor(-1, 0))
	local gate = Map.part(f.chaserRoom, "ChaserGate", Vector3.new(1.6, 14, 8), Vector3.new(136, FT + 7, 147.5), "Deep orange")
	CollectionService:AddTag(gate, "ChaserGate")
end

--------------------------------------------------------------------------------
-- 나무·벤치·가로등

for _, p in
	{
		{ 12, 40 }, { -12, 40 }, { 12, -40 }, { -12, -40 },
		{ 12, 75 }, { -12, 75 }, { 12, -75 }, { -12, -75 },
		{ 40, 12 }, { 40, -12 }, { -40, 12 }, { -40, -12 },
		{ 75, -12 }, { -75, 12 }, { -75, -12 },
		{ -148, 148 }, { -120, 150 }, { 148, -148 }, { 150, -118 }, { 120, -150 },
		{ 148, 100 }, { 148, 20 }, { 30, 150 }, { -30, -150 }, { 30, -150 },
	}
do
	tree(p[1], p[2], 1)
end

for _, b in
	{
		{ 28, 11, 0, -1 }, { -28, 11, 0, -1 }, { 28, -11, 0, 1 }, { -28, -11, 0, 1 },
		{ 11, 28, -1, 0 }, { 11, -28, -1, 0 }, { -11, 28, 1, 0 }, { -11, -28, 1, 0 },
		{ -60, -101, 0, -1 }, { 60, 101, 0, 1 }, { 101, -60, 1, 0 }, { -101, 60, -1, 0 },
	}
do
	bench(b[1], b[2], b[3], b[4])
end

for _, p in
	{
		{ 11, 20 }, { -11, -20 }, { 20, -11 }, { -20, 11 },
		{ 11, 60 }, { -11, -60 }, { 60, -11 }, { -60, 11 },
		{ -11, 95 }, { 11, -95 }, { 95, 11 }, { -95, -11 },
		{ -104, -104 }, { 104, -104 }, { 104, 104 }, { -104, 104 },
		{ 122, 48 }, { -6, -144 }, { -79, 155 }, -- 발전기 5·출구 1·2 (맵 점검 "조명에서 먼 목표")
	}
do
	lampPost(p[1], p[2])
end

--------------------------------------------------------------------------------
-- 태그 (CLAUDE.md 맵 규칙)

Map.addMarkers(f, {
	survivorSpawns = {
		{ -30, -30 }, { 30, -30 }, { -30, 30 }, { 30, 30 },
		{ 0, -128 }, { -128, 80 }, { 128, -20 }, { 0, 128 },
	},
	monsterSpawns = {
		{ -110, 30 }, { 110, -30 }, { 30, 110 }, { -30, -110 }, { -128, 128 }, { 128, -128 },
	},
	patrol = {
		-- 고리 길
		A = { { -110, -110 }, { 0, -110 }, { 110, -110 }, { 110, 0 }, { 110, 110 }, { 0, 110 }, { -110, 110 }, { -110, 0 } },
		-- 광장 둘레
		B = { { -36, -36 }, { 0, -36 }, { 36, -36 }, { 36, 0 }, { 36, 36 }, { 0, 36 }, { -36, 36 }, { -36, 0 } },
	},
	itemSpawns = {
		{ -20, -60 }, { 20, 60 }, { -140, 0 }, { 140, 80 }, { -90, 128 },
		{ 90, -90 }, { 0, -140 }, { -66, -140 }, { 60, 142 }, { -146, -144 },
	},
	generators = { { -56, 30 }, { 80, 80 }, { 56, -28 }, { -84, -84 }, { 130, 40 } },
	hideSpots = {
		{ -150, 100, 1, 0 },
		{ 150, -60, -1, 0 },
		{ -108, -142, 1, 0 },
		{ 108, -142, -1, 0 },
		{ -30, 150, 0, -1 },
		{ 30, 150, 0, -1 },
		{ -60, 18, 0, -1 },
		{ 70, -18, 0, 1 },
	},
})
-- 숨는 곳은 공원 간이 화장실 색으로
local boothColors = { rgb(90, 160, 240), rgb(255, 140, 180), rgb(120, 210, 150), rgb(255, 200, 90) }
for i, model in f.hideSpots:GetChildren() do
	local color = boothColors[i % #boothColors + 1]
	for _, part in model:GetChildren() do
		if part.Name == "Body" then
			part.Color = color
		elseif part.Name == "DoorL" or part.Name == "DoorR" then
			part.Color = color:Lerp(Color3.new(1, 1, 1), 0.45)
		end
	end
end

f.root.Parent = maps
return "Stage4: " .. Map.count(f.root)
