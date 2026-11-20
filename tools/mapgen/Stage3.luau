-- Stage3 (지하 연구소) 블록 맵: 좁은 통로와 어두운 구역 (docs/studio-workflow.md S2-1). common.luau 뒤에 붙여 실행한다.
-- 약 300×300. 폭 10(벽 사이 실제 8)의 좁은 통로가 x·z = ±40, ±120에 바둑판으로 나 있고,
-- 그 사이 칸(블록)은 연구실(70×70, 문 2~4개), 가장자리 작은 방(문 1개), 막힌 블록, 모서리 창고·추격자 대기실이다.
-- 어두운 구역(DarkZone 태그, S3-4 그림자 괴물용): 통로 x=-120, 통로 z=120, 연구실 (0,-80), (80,0). 이곳에는 비상등이 없다.

local f, maps = Map.newStage("Stage3")
Map.part(f.structure, "Floor", Vector3.new(320, 1, 320), Vector3.new(0, 0.5, 0), "Dark stone grey")
local W = f.walls
local DOOR = 8

-- 바깥 벽: 서쪽 출구 1 (z 35~45, 통로 z=40 끝), 남쪽 출구 2 (x 35~45, 통로 x=40 끝)
Map.wallX(W, -150, -150, 150, { { 35, 45 } })
Map.wallX(W, 150, -150, 150, {})
Map.wallZ(W, -150, -150, 150, { { 35, 45 } })
Map.wallZ(W, 150, -150, 150, {})

-- 블록 경계 (통로 중심 -120, -40, 40, 120에서 ±5)
local RANGES = { { -150, -125 }, { -115, -45 }, { -35, 35 }, { 45, 115 }, { 125, 150 } }

-- 문: 방향(S·N·W·E)별 문 가운데 위치 목록. "solid"는 막힌 블록
local blocks = {
	["1,1"] = { N = { -137.5 } }, -- 창고
	["5,1"] = "solid",
	["1,5"] = "solid",
	["5,5"] = {}, -- 추격자 대기실 (서쪽에 대기실 문)
	["1,2"] = { E = { -80 } },
	["1,3"] = "solid",
	["1,4"] = { E = { 80 } },
	["5,2"] = { W = { -80 } },
	["5,3"] = "solid",
	["5,4"] = { W = { 80 } },
	["2,1"] = "solid",
	["3,1"] = { N = { 0 } },
	["4,1"] = "solid",
	["2,5"] = "solid",
	["3,5"] = { S = { 0 } },
	["4,5"] = "solid",
}
-- 연구실 9칸: 가운데는 네 방향, (i+j) 짝수는 동서, 홀수는 남북으로 문
for i = 2, 4 do
	for j = 2, 4 do
		local cx = (RANGES[i][1] + RANGES[i][2]) / 2
		local cz = (RANGES[j][1] + RANGES[j][2]) / 2
		if i == 3 and j == 3 then
			blocks["3,3"] = { W = { cz }, E = { cz }, S = { cx }, N = { cx } }
		elseif (i + j) % 2 == 0 then
			blocks[`{i},{j}`] = { W = { cz }, E = { cz } }
		else
			blocks[`{i},{j}`] = { S = { cx }, N = { cx } }
		end
	end
end

local function gapsOf(centers)
	local result = {}
	for _, c in centers or {} do
		table.insert(result, Map.door(c, DOOR))
	end
	return result
end

for i = 1, 5 do
	for j = 1, 5 do
		local spec = blocks[`{i},{j}`]
		local x1, x2 = RANGES[i][1], RANGES[i][2]
		local z1, z2 = RANGES[j][1], RANGES[j][2]
		if spec == "solid" then
			Map.part(
				f.structure,
				"Block",
				Vector3.new(x2 - x1, 14, z2 - z1),
				Vector3.new((x1 + x2) / 2, 8, (z1 + z2) / 2),
				"Black"
			)
		else
			local westGaps = gapsOf(spec.W)
			if i == 5 and j == 5 then
				table.insert(westGaps, Map.door(137.5, DOOR)) -- 대기실 문
			end
			if z1 > -150 then
				Map.wallX(W, z1, x1, x2, gapsOf(spec.S))
			end
			if z2 < 150 then
				Map.wallX(W, z2, x1, x2, gapsOf(spec.N))
			end
			if x1 > -150 then
				Map.wallZ(W, x1, z1, z2, westGaps)
			end
			if x2 < 150 then
				Map.wallZ(W, x2, z1, z2, gapsOf(spec.E))
			end
		end
	end
end

-- 추격자 대기실 (북동쪽 모서리)
Map.marker(f.chaserRoom, "ChaserSpawn", "ChaserSpawn", 137.5, 137.5, 4, "Bright red", Map.yawFor(-1, 0))
local gate = Map.part(f.chaserRoom, "ChaserGate", Vector3.new(1.6, 14, DOOR), Vector3.new(125, 8, 137.5), "Deep orange")
game:GetService("CollectionService"):AddTag(gate, "ChaserGate")

Map.addMarkers(f, {
	survivorSpawns = {
		{ -80, -95 },
		{ 0, -60 },
		{ 95, -80 },
		{ -95, 0 },
		{ 0, 20 },
		{ -80, 95 },
		{ 0, 137.5 },
		{ 137.5, -80 },
	},
	-- 감시자(움직이지 않음)는 Monster 속성이 있는 자리에 먼저 놓인다 (S2-3). 출구로 가는 통로를 바라봄
	monsterSpawns = {
		{ -120, 40, monster = "Watcher", yaw = Map.yawFor(-1, 0) },
		{ 40, -120, monster = "Watcher", yaw = Map.yawFor(0, -1) },
		{ 120, -40 },
		{ -40, 120 },
		{ 40, 40 },
		{ -120, -120 },
	},
	patrol = {
		-- 바깥 통로 고리
		A = {
			{ -120, -120 },
			{ 0, -120 },
			{ 120, -120 },
			{ 120, 0 },
			{ 120, 120 },
			{ 0, 120 },
			{ -120, 120 },
			{ -120, 0 },
		},
		-- 안쪽 통로 고리
		B = { { -40, -40 }, { 0, -40 }, { 40, -40 }, { 40, 0 }, { 40, 40 }, { 0, 40 }, { -40, 40 }, { -40, 0 } },
	},
	itemSpawns = {
		{ -137.5, -137.5 },
		{ -137.5, 90 },
		{ 137.5, 80 },
		{ -20, -137.5 },
		{ 25, 137.5 },
		{ -100, -60 },
		{ 60, -100 },
		{ 100, 20 },
		{ -60, 20 },
		{ 20, -20 },
	},
	generators = { { -80, -80 }, { 80, -80 }, { 0, 0 }, { -80, 80 }, { 80, 80 } },
	hideSpots = {
		{ -147.25, -140, 1, 0 },
		{ -147.25, -100, 1, 0 },
		{ -147.25, 100, 1, 0 },
		{ 147.25, -100, -1, 0 },
		{ -20, -147.25, 0, 1 },
		{ 20, 147.25, 0, -1 },
		{ -100, -112.25, 0, 1 },
		{ 100, 112.25, 0, -1 },
	},
})
Map.exit(f.exits, 1, -150, 40, 10, true)
Map.exit(f.exits, 2, 40, -150, 10, false)

-- 어두운 구역
local dark = Map.folder(f.root, "DarkZones")
Map.darkZone(dark, "DarkCorridorWest", -120, 0, 10, 300)
Map.darkZone(dark, "DarkCorridorNorth", 0, 120, 300, 10)
Map.darkZone(dark, "DarkLabSouth", 0, -80, 70, 70)
Map.darkZone(dark, "DarkLabEast", 80, 0, 70, 70)

-- 비상등 (붉은색). 어두운 구역에는 두지 않는다
local lampColor = Color3.fromRGB(255, 110, 80)
for _, p in
	{
		{ -40, -40 },
		{ 40, -40 },
		{ 40, 40 },
		{ -40, 40 },
		{ -80, -80 },
		{ 80, -80 },
		{ 0, 0 },
		{ -80, 80 },
		{ 80, 80 },
		{ 0, 80 },
		{ -80, 0 },
		{ 0, -120 },
	}
do
	Map.lamp(f.lights, p[1], p[2], lampColor, 22, 1.2)
end

for _, d in f.walls:GetChildren() do
	d.BrickColor = BrickColor.new("Smoky grey")
end

f.root.Parent = maps
return "Stage3: " .. Map.count(f.root)
