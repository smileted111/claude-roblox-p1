-- 판자·문 배치 (docs/studio-workflow.md S2-4). common.luau 뒤에 붙여 실행한다. Stage1~4 맵에 Barriers 폴더를 새로 만든다.
-- ONLY에 스테이지 이름을 넣으면 그 맵만 다시 만든다 (예: Stage4를 새로 만든 뒤 ONLY = "Stage4").
-- 판자 (Plank 태그 Model): Board(통로 한쪽 벽에 세워 둠) + FallenPose(넘어지면 통로를 가로막는 자리, 투명).
--   높이 9라 점프로 넘지 못한다. 고리 동선이 있는 통로에만 둔다 (막혀도 돌아갈 길이 있게).
-- 문 (Door 태그 Model): Panel(문 틈을 막는 닫힌 자리) + OpenPose(경첩을 축으로 90° 연 자리, 투명).

local CollectionService = game:GetService("CollectionService")
local ONLY = nil -- 예: "Stage4"
local PLANK_HEIGHT = 9
local DOOR_HEIGHT = 12
local ROT90 = CFrame.Angles(0, math.rad(90), 0)

local function hidden(part)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- (cx, cz): 통로 가운데. alongX: 통로가 x 방향이면 true. width: 벽 사이 빈 폭
local function plank(parent, name, cx, cz, alongX, width)
	local y = 1 + PLANK_HEIGHT / 2
	local model = Instance.new("Model")
	model.Name = name
	local length = width + 0.6
	local fallen = CFrame.new(cx, y, cz) * (if alongX then ROT90 else CFrame.identity)
	local idle = if alongX
		then CFrame.new(cx + length / 2, y, cz + width / 2 - 0.5)
		else CFrame.new(cx + width / 2 - 0.5, y, cz + length / 2) * ROT90
	local board = Map.part(model, "Board", Vector3.new(length, PLANK_HEIGHT, 1), Vector3.zero, "Brown")
	board.CFrame = idle
	local pose = Map.part(model, "FallenPose", Vector3.new(length, PLANK_HEIGHT, 1), Vector3.zero, "Brown")
	pose.CFrame = fallen
	hidden(pose)
	model.PrimaryPart = board
	CollectionService:AddTag(model, "Plank")
	model.Parent = parent
end

-- (cx, cz): 문 틈 가운데. wallAlongX: 벽이 x 방향이면 true. side: 열리는 쪽 (+1이면 +z 또는 +x 쪽 방으로)
local function door(parent, name, cx, cz, wallAlongX, width, side)
	local y = 1 + DOOR_HEIGHT / 2
	local model = Instance.new("Model")
	model.Name = name
	local closed = CFrame.new(cx, y, cz) * (if wallAlongX then CFrame.identity else ROT90)
	local open = if wallAlongX
		then CFrame.new(cx - width / 2 + 0.25, y, cz + side * width / 2) * ROT90
		else CFrame.new(cx + side * width / 2, y, cz - width / 2 + 0.25)
	local panel = Map.part(model, "Panel", Vector3.new(width, DOOR_HEIGHT, 0.5), Vector3.zero, "Dark taupe")
	panel.CFrame = closed
	local pose = Map.part(model, "OpenPose", Vector3.new(width, DOOR_HEIGHT, 0.5), Vector3.zero, "Dark taupe")
	pose.CFrame = open
	hidden(pose)
	model.PrimaryPart = panel
	CollectionService:AddTag(model, "Door")
	model.Parent = parent
end

local specs = {
	Stage1 = {
		planks = {
			{ -100, -102, true, 14 }, -- 남쪽 복도
			{ 80, 102, true, 14 }, -- 북쪽 복도
			{ -142, 70, false, 14 }, -- 서쪽 복도
			{ 0, -70, false, 14 }, -- 가운데 복도
		},
		doors = {
			{ -75, -110, true, 10, -1 },
			{ 75, -110, true, 10, -1 },
			{ -70, 0, true, 10, 1 },
			{ 50, 110, true, 10, 1 },
		},
	},
	Stage2 = {
		planks = {
			{ -90, -55, true, 12 }, -- 복도 A
			{ 90, 55, true, 12 }, -- 복도 B
			{ 143, 10, false, 12 }, -- 동쪽 홀
			{ 0, 0, false, 12 }, -- 가운데 세로 복도
		},
		doors = {
			{ -68, -62, true, 10, -1 },
			{ 39.5, 48, true, 10, -1 },
			{ 68, 62, true, 10, 1 },
			{ 72, 25, false, 10, 1 },
		},
	},
	Stage3 = {
		planks = {
			{ -60, -40, true, 8 },
			{ 40, 60, false, 8 },
			{ -80, 120, true, 8 },
			{ -120, -100, false, 8 },
		},
		doors = {
			{ -35, 0, false, 8, 1 },
			{ -45, -80, false, 8, -1 },
			{ 45, 80, false, 8, 1 },
			{ 0, -115, true, 8, 1 },
		},
	},
	-- 놀이공원: 판자는 남·북 가장자리 상점과 화장실 사이 골목(폭 8), 문은 상점 3곳과 유령의 집 동쪽 문
	Stage4 = {
		planks = {
			{ -79, -146, false, 8 },
			{ 79, -146, false, 8 },
			{ -79, 138, false, 8 },
			{ 79, 138, false, 8 },
		},
		doors = {
			{ -60, -134, true, 8, -1 },
			{ 60, -134, true, 8, -1 },
			{ -60, 134, true, 8, 1 },
			{ -124, -139, false, 8, -1 },
		},
	},
}

local results = {}
for stageName, spec in specs do
	if ONLY and stageName ~= ONLY then
		continue
	end
	local map = game:GetService("ServerStorage").Maps[stageName]
	local old = map:FindFirstChild("Barriers")
	if old then
		old:Destroy()
	end
	local folder = Map.folder(map, "Barriers")
	for i, p in spec.planks do
		plank(folder, `Plank{i}`, p[1], p[2], p[3], p[4])
	end
	for i, d in spec.doors do
		door(folder, `Door{i}`, d[1], d[2], d[3], d[4], d[5])
	end
	table.insert(results, `{stageName}: 판자 {#spec.planks}, 문 {#spec.doors}`)
end
table.sort(results)
return table.concat(results, "\n")
