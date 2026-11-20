-- Stage2 (폐병원) 블록 맵: 긴 복도 2개와 병실 (docs/studio-workflow.md S2-1). common.luau 뒤에 붙여 실행한다.
-- 약 300×300. 남쪽 병동 6칸 / 복도 A (z -62~-48) / 가운데 병실 8칸 + 세로 복도 / 복도 B (z 48~62) / 북쪽 병동 6칸 + 추격자 대기실.
-- 서·동쪽 끝의 홀(x ±136~±150)이 두 복도를 이어 크게 도는 동선, 가운데 세로 복도와 병실 사이 문이 작은 동선을 만든다.

local f, maps = Map.newStage("Stage2")
Map.part(f.structure, "Floor", Vector3.new(320, 1, 320), Vector3.new(0, 0.5, 0), "Medium stone grey")
local W = f.walls
local door = Map.door

-- 바깥 벽: 서쪽 출구 1 (z -6~6), 동쪽 출구 2 (z -106~-94)
Map.wallX(W, -150, -150, 150, {})
Map.wallX(W, 150, -150, 150, {})
Map.wallZ(W, -150, -150, 150, { { -6, 6 } })
Map.wallZ(W, 150, -150, 150, { { -106, -94 } })

-- 서·동쪽 홀 경계: 복도 A·B 입구, 가운데 병실 문, 남·북 병동 첫 칸 문
local hallGaps = { { -62, -48 }, door(-25), door(25), { 48, 62 }, door(-105), door(105) }
Map.wallZ(W, -136, -150, 150, hallGaps)
Map.wallZ(W, 136, -150, 150, hallGaps)

-- 복도 A (남쪽)
local southRooms = { -113.5, -68, -22.5, 22.5, 68, 113.5 }
local gaps = {}
for _, c in southRooms do
	table.insert(gaps, door(c))
end
Map.wallX(W, -62, -136, 136, gaps)
local middleRooms = { -104, -39.5, 39.5, 104 }
local middleGaps = { { -7, 7 } } -- 세로 복도
for _, c in middleRooms do
	table.insert(middleGaps, door(c))
end
Map.wallX(W, -48, -136, 136, middleGaps)

-- 복도 B (북쪽). 가운데 (x -5~5)는 추격자 대기실 문
Map.wallX(W, 48, -136, 136, middleGaps)
local northRooms = { -113.5, -68, -30, 30, 68, 113.5 }
gaps = { door(0, 10) }
for _, c in northRooms do
	table.insert(gaps, door(c))
end
Map.wallX(W, 62, -136, 136, gaps)

-- 가운데 세로 복도 (x -7~7)와 병실 칸막이
Map.wallZ(W, -7, -48, 48, { door(-25), door(25) })
Map.wallZ(W, 7, -48, 48, { door(-25), door(25) })
Map.wallX(W, 0, -136, -7, { door(-104) })
Map.wallX(W, 0, 7, 136, { door(104) })
Map.wallZ(W, -72, -48, 48, { door(-25), door(25) })
Map.wallZ(W, 72, -48, 48, { door(-25), door(25) })

-- 남쪽 병동 칸막이 (일부는 뒤쪽에 문을 내 이웃 병실과 이어짐)
for _, x in { -91, -45, 0, 45, 91 } do
	Map.wallZ(W, x, -150, -62, if x == -91 or x == 45 then { door(-135) } else {})
end
-- 북쪽 병동 칸막이. x -15~15는 추격자 대기실
for _, x in { -91, -45, -15, 15, 45, 91 } do
	Map.wallZ(W, x, 62, 150, if x == -91 or x == 45 then { door(135) } else {})
end

-- 추격자 대기실
Map.marker(f.chaserRoom, "ChaserSpawn", "ChaserSpawn", 0, 132, 4, "Bright red")
local gate = Map.part(f.chaserRoom, "ChaserGate", Vector3.new(10, 14, 1.6), Vector3.new(0, 8, 62), "Deep orange")
game:GetService("CollectionService"):AddTag(gate, "ChaserGate")

Map.addMarkers(f, {
	survivorSpawns = {
		{ -113.5, -120 },
		{ 22.5, -125 },
		{ 113.5, -125 },
		{ -104, -20 },
		{ 39.5, 20 },
		{ 104, -20 },
		{ -68, 110 },
		{ 113.5, 110 },
	},
	monsterSpawns = {
		{ -100, -55 },
		{ 100, 55 },
		{ 0, -20 },
		{ 143, -30 },
	},
	patrol = {
		-- 큰 동선: 복도 A → 동쪽 홀 → 복도 B → 서쪽 홀
		A = { { -120, -55 }, { 0, -55 }, { 120, -55 }, { 143, 0 }, { 120, 55 }, { 0, 55 }, { -120, 55 }, { -143, 0 } },
		-- 가운데: 세로 복도와 병실 8칸
		B = {
			{ 0, -30 },
			{ -39.5, -25 },
			{ -104, -25 },
			{ -104, 25 },
			{ -39.5, 25 },
			{ 0, 30 },
			{ 39.5, 25 },
			{ 104, 25 },
			{ 104, -25 },
			{ 39.5, -25 },
		},
	},
	itemSpawns = {
		{ -68, -100 },
		{ 68, -100 },
		{ -22.5, -140 },
		{ -30, 85 },
		{ 68, 85 },
		{ -120, 40 },
		{ 39.5, -40 },
		{ -143, -120 },
		{ 143, 120 },
		{ 113.5, -140 },
	},
	generators = { { -68, -135 }, { 120, 35 }, { 68, 135 }, { -120, -35 } },
	hideSpots = {
		{ -113.5, -147.25, 0, 1 },
		{ 22.5, -147.25, 0, 1 },
		{ 113.5, -147.25, 0, 1 },
		{ -68, 147.25, 0, -1 },
		{ 30, 147.25, 0, -1 },
		{ -133.25, 40, 1, 0 },
		{ 133.25, -40, -1, 0 },
		{ -147.25, 80, 1, 0 },
	},
})
Map.exit(f.exits, 1, -150, 0, 12, true)
Map.exit(f.exits, 2, 150, -100, 12, true)

-- 형광등 (차가운 녹색)
local lampColor = Color3.fromRGB(170, 255, 190)
for _, p in { { -90, -55 }, { 30, -55 }, { 110, -55 }, { -30, 55 }, { 90, 55 }, { 0, 0 }, { -143, -90 }, { 143, 90 } } do
	Map.lamp(f.lights, p[1], p[2], lampColor, 24, 1.2)
end

-- 병원 벽은 밝은 회색
for _, d in f.walls:GetChildren() do
	d.BrickColor = BrickColor.new("Light stone grey")
end

f.root.Parent = maps
return "Stage2: " .. Map.count(f.root)
