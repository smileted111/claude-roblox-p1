--!strict
-- MonsterService: 괴물 생성·AI의 공통 부분 (GDD 4.1, 4.3, 4.4, 7장, 13.2)
-- 종류별 동작은 server/Monsters/<Name>.luau (MonsterTypes.Behavior)에 있다: 배회자·사냥개·감시자·그림자·거인.
-- 동작이나 모델이 없는 종류는 배회자로 대신하고 경고를 남긴다.
-- 손전등(ItemService)이 비추면 freezeInBeam으로 그림자를 멈춘다. 알람시계 소리는 사냥개(onNoise) 밖의 움직이는 괴물도
-- 순찰·포기 중이면 Config.MonsterAI.AlarmLureTime초 동안 찾아오게 한다 (GDD 6.3).
--
-- 생성 (StageService가 준비 단계에서 맵을 불러온 뒤 spawnForStage, 스테이지가 끝나면 clear를 부름)
--   종류별 수 = 반올림(Config.Stages의 수 × Config.MonsterScaling의 인원 배율). 그 구간의 MinPerType보다 적으면 올림.
--   모두 합쳐 MonsterScaling.MaxActive를 넘지 않게 종류를 돌아가며 한 마리씩 채운다 (computeCounts).
--   ServerStorage.MonsterModels.<MonsterId>를 복제해 Workspace.Monsters에 둔다 (MonsterState).
--   넣기 전에 매치 화면 모드에 맞춰 꾸민다: 캐주얼은 귀엽게, 나이트는 공포 소품 (Util/MonsterLooks, Config.MonsterLooks).
--   MonsterSpawn 자리: Attribute Monster가 그 종류인 자리 → 종류 지정이 없는 자리 → 가장 덜 쓴 자리 순서로 고른다.
--   한 자리에 둘 이상이면 옆으로 띄운다. 괴물은 자리 파트가 보는 방향을 본다 (감시자).
--   순찰 경로(PatrolPoint의 Route·Order)는 움직이는 괴물에게만, 괴물이 적은 경로부터 배정하고 가장 가까운 지점부터 돈다.
--   추격자에게는 괴물 모델을 항상 스트리밍한다 (ModelStreamingMode PersistentPerPlayer). 추격자 화면의
--   괴물 위치 아이콘(ChaserController)이 맵 어디서든 보이게 하기 위해서다 (질문지 Q2-8).
--
-- AI: Heartbeat 하나가 모든 괴물을 갱신한다. 괴물마다 Config.MonsterAI.TickInterval 간격이고,
--     시작 시점을 괴물 수로 나눠 한 프레임에 몰리지 않게 한다. 갱신 중에는 멈추지(yield) 않는다.
--   추격 단계가 아니면 대기(Idle): 제자리에 서 있다 (준비 중에는 움직이지 않음, MonsterState.canActInPhase).
--   추격 단계에서는 종류별 동작(Behavior.tick)을 부른다. 공통 상태 처리(Api)는 배회자식 흐름이다:
--   순찰  경로의 다음 지점으로 걷는다. 생존자를 보면 의심 (InstantChaseDistance 안이면 바로 추격)
--   의심  마지막으로 본 곳으로 다가간다. SuspicionTime초 동안 보면 추격. 가 봐도 없으면 포기
--   추격  대상에게 다가간다. 보이고 가까우면 곧장, 아니면 길찾기. AttackRange 안이면 공격
--   공격  멈춰서 대상을 보고 AttackWindup초 뒤 판정. 맞으면 CatchService.hit (정상 → 부상 → 잡힘). 끝나면 추격
--         잡았으면 덮치듯 뛰어오르며 공격 동작을 한 번 더 하고 Config.Catch.CaughtEffect.MonsterPause초 동안 그 자리에 선다
--         (잡힌 사람의 카메라 연출이 이 괴물을 비춘다)
--   포기  대상이 LoseSightTime초 동안 안 보이거나 마지막으로 본 곳에 없으면 GiveUpTime초 서 있다가 순찰
--   순찰할 때는 PatrolSpeed(있으면), 나머지 상태에서는 WalkSpeed로 걷는다.
--
-- 감지
--   시야(Sight): SightRange 안, 앞쪽 SightAngle 안(추격 중에는 각도를 보지 않음), 눈(Head)에서 생존자의
--     몸통이나 머리까지 레이캐스트가 벽(충돌하는 파트)에 막히지 않아야 한다.
--   소리(Sound): server/Util/NoiseBus의 소리 사건이 min(HearingRange, 소리 반경) 안이면 Behavior.onNoise.
--   대상은 숨지 않고 연막 안에 있지 않은(ItemService.isConcealed) 정상·부상 생존자뿐이다.
--   추격자는 감지·공격하지 않는다 (GDD 2장, 질문지 Q2-7).
--   거리를 먼저 검사하므로 생존자에게서 먼 괴물은 레이캐스트 없이 이동만 한다 (GDD 4.4).
-- 먼 괴물 (GDD 4.4): 모든 생존자·추격자에게서 FarDistance보다 멀면 FarTickInterval마다만 갱신하고 대상 목록을 비워
--   시야 판정을 건너뛴다 (순찰 이동·경로 따라가기는 그대로). FarDistance가 가장 먼 시야보다 커서 보이는 동작은 같다.
--   소리(onNoise)는 갱신과 따로라 먼 괴물도 듣는다. 스테이지가 끝나면 전체 갱신 중 먼 갱신 횟수를 출력한다.
--
-- 길찾기: 괴물마다 Path 하나. 경로 계산은 괴물마다 PathRecomputeInterval초 이상 간격으로만 한다.
--   ComputeAsync는 멈추므로 따로 실행하고, 결과가 올 때까지는 이전 경로를 따라간다.
--   모든 괴물을 합쳐 동시에 MaxConcurrentPaths개까지만 계산하고, 넘으면 다음 갱신으로 미룬다 (서버 비용 상한).
--   스테이지가 끝나면 계산·미룬 횟수를 출력한다 (성능 확인용).
--   경로 중간 지점은 갱신 때와 MoveToFinished 때 넘긴다.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MonsterAI = require(ReplicatedStorage.Shared.Config.MonsterAI)
local MonsterScaling = require(ReplicatedStorage.Shared.Config.MonsterScaling)
local MonsterState = require(ReplicatedStorage.Shared.MonsterState)
local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survivor = require(ReplicatedStorage.Shared.Config.Survivor)
local Types = require(ReplicatedStorage.Shared.Types)
local VisualModes = require(ReplicatedStorage.Shared.Config.VisualModes)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local Giant = require(script.Parent.Parent.Monsters.Giant)
local Hound = require(script.Parent.Parent.Monsters.Hound)
local MonsterTypes = require(script.Parent.Parent.Monsters.MonsterTypes)
local Shadow = require(script.Parent.Parent.Monsters.Shadow)
local Wanderer = require(script.Parent.Parent.Monsters.Wanderer)
local Watcher = require(script.Parent.Parent.Monsters.Watcher)
local MonsterLooks = require(script.Parent.Parent.Util.MonsterLooks)
local NoiseBus = require(script.Parent.Parent.Util.NoiseBus)
local BarrierService = require(script.Parent.BarrierService)
local CatchService = require(script.Parent.CatchService)
local HideService = require(script.Parent.HideService)
local ItemService = require(script.Parent.ItemService)
local RoleService = require(script.Parent.RoleService)

type AIState = Types.MonsterAIState
type Monster = MonsterTypes.Monster
type Target = MonsterTypes.Target
type Route = MonsterTypes.Route
type Animations = MonsterTypes.Animations

-- 종류별 동작. 없는 종류는 FALLBACK_MONSTER로 대신한다 (그림자·거인 S3-4).
local BEHAVIORS: { [Types.MonsterId]: MonsterTypes.Behavior } = {
	Wanderer = Wanderer,
	Hound = Hound,
	Watcher = Watcher,
	Shadow = Shadow,
	Giant = Giant,
}
local FALLBACK_MONSTER: Types.MonsterId = "Wanderer"

local PATROL_ROUTE_ATTRIBUTE = "Route" -- PatrolPoint의 경로 이름 (CLAUDE.md 맵 규칙)
local PATROL_ORDER_ATTRIBUTE = "Order" -- PatrolPoint의 순서
local SPAWN_MONSTER_ATTRIBUTE = "Monster" -- MonsterSpawn에 먼저 놓을 괴물 종류 (CLAUDE.md 맵 규칙)
local MOVING_SPEED = 0.1 -- Humanoid.Running 속도가 이보다 크면 걷는 중으로 본다 (멈춰 있을 때의 흔들림을 걸러냄)

local STATE_NAMES: { [AIState]: string } = {
	Idle = "대기",
	Patrol = "순찰",
	Suspicious = "의심",
	Chase = "추격",
	Attack = "공격",
	GiveUp = "포기",
	Alert = "경보",
}

local Config = MonsterAI
local Attribute = MonsterState.Attribute

local MonsterService = {}

local random = Random.new()
local monsters: { Monster } = {}
local monsterFolder: Folder? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local serial = 0
local darkZones: { BasePart } = {} -- 지금 맵의 DarkZone 상자
local computingPaths = 0 -- 지금 계산 중인 경로 수 (모든 괴물 합계)
local pathStats = { computed = 0, deferred = 0 } -- 이번 스테이지의 길찾기 계산·미룸 횟수
local tickStats = { total = 0, far = 0 } -- 이번 스테이지의 AI 갱신 횟수와 그중 먼 괴물 갱신
local NO_TARGETS: { Target } = {} -- 먼 괴물에게 주는 빈 대상 목록 (바꾸지 않는다)
local api: MonsterTypes.Api

-- 시야 검사: 캐릭터와 괴물은 빼고, 충돌하는 파트만 시야를 가리는 것으로 본다 (열린 대기실 문, 바닥 표시 등은 통과).
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.RespectCanCollide = true

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

-- 맵 안에서 태그가 붙은 파트. ServerStorage의 원본 맵에도 같은 태그가 있어서 맵 안만 찾는다.
local function taggedParts(map: Instance, tag: string): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:HasTag(tag) then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function hasSense(monster: Monster, sense: Types.Sense): boolean
	return table.find(monster.def.Senses, sense) ~= nil
end

--------------------------------------------------------------------------------
-- 수 계산과 순찰 경로

local function findBracket(survivorCount: number, hasChaser: boolean): MonsterScaling.Bracket?
	for _, bracket in MonsterScaling.Brackets do
		local inRange = survivorCount >= bracket.MinSurvivors and survivorCount <= bracket.MaxSurvivors
		if bracket.HasChaser == hasChaser and inRange then
			return bracket
		end
	end
	return nil
end

-- 이번 스테이지에 나올 종류별 괴물 수 (GDD 4.3). Stages의 순서를 따른다.
function MonsterService.computeCounts(
	stageId: Types.StageId,
	survivorCount: number,
	hasChaser: boolean
): { Stages.MonsterGroup }
	local bracket = findBracket(survivorCount, hasChaser)
	local multiplier = if bracket then bracket.Multiplier else MonsterScaling.DefaultMultiplier
	local minPerType = if bracket then bracket.MinPerType else 0

	local wanted: { number } = {}
	local result: { Stages.MonsterGroup } = {}
	for index, group in Stages[stageId].Monsters do
		-- 작은 값을 더해 부동소수점 오차로 x.5가 x.4999…가 되어 내림되는 것을 막는다.
		wanted[index] = math.max(math.round(group.Count * multiplier + 1e-9), minPerType)
		result[index] = { Monster = group.Monster, Count = 0 }
	end

	-- 동시 최대 수를 넘으면 한 종류만 빠지지 않게 종류를 돌아가며 한 마리씩 채운다.
	local total = 0
	local added = true
	while added and total < MonsterScaling.MaxActive do
		added = false
		for index, group in result do
			if group.Count < wanted[index] and total < MonsterScaling.MaxActive then
				group.Count += 1
				total += 1
				added = true
			end
		end
	end
	return result
end

local function loadRoutes(map: Instance): { Route }
	type Point = { order: number, position: Vector3 }
	local byName: { [string]: { Point } } = {}
	for _, part in taggedParts(map, MapTags.PatrolPoint) do
		local routeName = part:GetAttribute(PATROL_ROUTE_ATTRIBUTE)
		local order = part:GetAttribute(PATROL_ORDER_ATTRIBUTE)
		if typeof(routeName) == "string" and typeof(order) == "number" then
			local points = byName[routeName] or {}
			byName[routeName] = points
			table.insert(points, { order = order, position = part.Position })
		else
			warn(
				`[Monster] {part:GetFullName()}: {MapTags.PatrolPoint}에는 {PATROL_ROUTE_ATTRIBUTE}(문자열)·{PATROL_ORDER_ATTRIBUTE}(숫자) Attribute가 필요합니다`
			)
		end
	end

	local routes: { Route } = {}
	for name, points in byName do
		table.sort(points, function(a: Point, b: Point): boolean
			return a.order < b.order
		end)
		local positions: { Vector3 } = {}
		for _, point in points do
			table.insert(positions, point.position)
		end
		table.insert(routes, { name = name, points = positions })
	end
	table.sort(routes, function(a: Route, b: Route): boolean
		return a.name < b.name
	end)
	return routes
end

local function nearestPointIndex(route: Route, position: Vector3): number
	local best = 1
	local bestDistance = math.huge
	for index, point in route.points do
		local distance = flatDistance(point, position)
		if distance < bestDistance then
			best = index
			bestDistance = distance
		end
	end
	return best
end

-- 배정된 괴물이 가장 적은 경로. 같으면 position에서 가까운 경로.
local function pickRoute(routes: { Route }, routeUse: { [string]: number }, position: Vector3): Route?
	local best: Route? = nil
	local bestUse = math.huge
	local bestDistance = math.huge
	for _, route in routes do
		local use = routeUse[route.name] or 0
		local distance = flatDistance(route.points[nearestPointIndex(route, position)], position)
		if use < bestUse or (use == bestUse and distance < bestDistance) then
			best = route
			bestUse = use
			bestDistance = distance
		end
	end
	if best then
		routeUse[best.name] = bestUse + 1
	end
	return best
end

-- 괴물 한 마리를 놓을 MonsterSpawn: 그 종류로 지정된 빈자리 → 지정 없는 빈자리 → 가장 덜 쓴 자리.
-- 두 번째 값은 그 자리에 이미 놓인 수 (옆으로 띄우는 데 씀).
local function pickSpawn(kind: Types.MonsterId, spawns: { BasePart }, used: { [BasePart]: number }): (BasePart, number)
	local function firstUnused(match: (BasePart) -> boolean): BasePart?
		for _, spawnPart in spawns do
			if (used[spawnPart] or 0) == 0 and match(spawnPart) then
				return spawnPart
			end
		end
		return nil
	end
	local chosen = firstUnused(function(spawnPart: BasePart): boolean
		return spawnPart:GetAttribute(SPAWN_MONSTER_ATTRIBUTE) == kind
	end) or firstUnused(function(spawnPart: BasePart): boolean
		return spawnPart:GetAttribute(SPAWN_MONSTER_ATTRIBUTE) == nil
	end)
	if not chosen then
		local fewest = math.huge
		for _, spawnPart in spawns do
			if (used[spawnPart] or 0) < fewest then
				chosen = spawnPart
				fewest = used[spawnPart] or 0
			end
		end
	end
	local spawnPart = chosen :: BasePart
	local lap = used[spawnPart] or 0
	used[spawnPart] = lap + 1
	return spawnPart, lap
end

--------------------------------------------------------------------------------
-- 상태와 이동

local function setState(monster: Monster, state: AIState, detail: string?): ()
	if monster.state == state then
		return
	end
	local suffix = if detail then ` ({detail})` else ""
	print(`[Monster] {monster.name} {STATE_NAMES[monster.state]} → {STATE_NAMES[state]}{suffix}`)
	monster.state = state
	monster.stateSince = os.clock()
	monster.model:SetAttribute(Attribute.State, state)
	local def = monster.def
	monster.humanoid.WalkSpeed = if state == "Patrol" and def.PatrolSpeed then def.PatrolSpeed else def.WalkSpeed
end

-- 경로의 지금 중간 지점으로 걷는다. 이미 가까운 지점은 건너뛴다.
local function moveAlongPath(monster: Monster): ()
	local waypoints = monster.waypoints
	local position = monster.rootPart.Position
	while
		monster.waypointIndex <= #waypoints
		and flatDistance(waypoints[monster.waypointIndex].Position, position) <= Config.WaypointReachDistance
	do
		monster.waypointIndex += 1
	end
	local waypoint = waypoints[monster.waypointIndex]
	if waypoint then
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			monster.humanoid.Jump = true
		end
		monster.humanoid:MoveTo(waypoint.Position)
	end
end

local function clearPath(monster: Monster): ()
	monster.pathRequest += 1 -- 진행 중인 경로 계산 결과는 버린다
	monster.pathGoal = nil
	monster.waypoints = {}
	monster.waypointIndex = 1
end

local function stopMoving(monster: Monster): ()
	clearPath(monster)
	monster.humanoid:MoveTo(monster.rootPart.Position)
end

-- 길찾기 없이 곧장 걸어간다 (보이는 가까운 대상).
local function moveDirect(monster: Monster, position: Vector3): ()
	if monster.pathGoal or #monster.waypoints > 0 then
		clearPath(monster)
	end
	monster.humanoid:MoveTo(position)
end

local function requestPath(monster: Monster, goal: Vector3, now: number): ()
	monster.pathRequest += 1
	local request = monster.pathRequest
	monster.computing = true
	monster.forceRepath = false
	monster.lastPathAt = now
	local start = monster.rootPart.Position
	computingPaths += 1
	pathStats.computed += 1

	task.spawn(function()
		local ok = pcall(function()
			monster.path:ComputeAsync(start, goal)
		end)
		computingPaths = math.max(0, computingPaths - 1)
		monster.computing = false
		if not monster.alive or request ~= monster.pathRequest then
			return
		end
		monster.pathGoal = goal
		monster.waypointIndex = 1
		if ok and monster.path.Status == Enum.PathStatus.Success then
			monster.waypoints = monster.path:GetWaypoints()
			moveAlongPath(monster)
		else
			-- 길이 없으면 곧장 걸어 본다. 막히면 막힘 판정이 다시 길을 찾게 한다.
			monster.waypoints = {}
			monster.humanoid:MoveTo(goal)
		end
	end)
end

-- goal까지 길을 찾아 걷는다. 목표가 GoalChangeTolerance 넘게 바뀌었거나 막혔을 때만,
-- 그것도 마지막 계산에서 PathRecomputeInterval초가 지났을 때만 다시 계산한다.
-- directWhileNoPath: 따라갈 경로가 아직 없으면 그동안 곧장 걸어간다. 대상이 보일 때만 쓴다 (사이에 벽이 없음).
local function travelTo(monster: Monster, goal: Vector3, now: number, directWhileNoPath: boolean): ()
	local current = monster.pathGoal
	local goalChanged = current == nil or (current - goal).Magnitude > Config.GoalChangeTolerance
	local canCompute = not monster.computing and now - monster.lastPathAt >= Config.PathRecomputeInterval
	if (goalChanged or monster.forceRepath) and canCompute then
		if computingPaths < Config.MaxConcurrentPaths then
			requestPath(monster, goal, now)
		else
			pathStats.deferred += 1
		end
	end
	if directWhileNoPath and #monster.waypoints == 0 then
		monster.humanoid:MoveTo(goal)
	else
		moveAlongPath(monster)
	end
end

-- 움직이려는데 StuckTime초 동안 StuckDistance도 못 갔으면 true. 움직이려 하지 않으면 기록만 새로 한다.
local function checkStuck(monster: Monster, now: number, wantsToMove: boolean): boolean
	local position = monster.rootPart.Position
	if not wantsToMove or flatDistance(position, monster.stuckCheckPosition) >= Config.StuckDistance then
		monster.stuckCheckPosition = position
		monster.stuckCheckAt = now
		return false
	end
	if now - monster.stuckCheckAt >= Config.StuckTime then
		monster.stuckCheckPosition = position
		monster.stuckCheckAt = now
		return true
	end
	return false
end

local function face(monster: Monster, position: Vector3): ()
	local origin = monster.rootPart.Position
	local direction = flat(position - origin)
	if direction.Magnitude > 1e-3 then
		monster.rootPart.CFrame = CFrame.lookAt(origin, origin + direction)
	end
end

--------------------------------------------------------------------------------
-- 감지

local function collectTargets(): { Target }
	local targets: { Target } = {}
	for _, player in RoleService.getActiveSurvivors() do
		local concealed = HideService.isHidden(player) or ItemService.isConcealed(player)
		local parts = if concealed then nil else CharacterParts.get(player)
		if parts then
			local head = parts.character:FindFirstChild("Head")
			table.insert(targets, {
				player = player,
				rootPart = parts.rootPart,
				head = if head and head:IsA("BasePart") then head else nil,
			})
		end
	end
	return targets
end

local function refreshSightFilter(): ()
	local ignore: { Instance } = {}
	if monsterFolder then
		table.insert(ignore, monsterFolder)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	sightParams.FilterDescendantsInstances = ignore
end

-- 눈에서 대상의 몸통이나 머리까지 벽이 없는가
local function hasLineOfSight(monster: Monster, target: Target): boolean
	local eye = monster.eye.Position
	if Workspace:Raycast(eye, target.rootPart.Position - eye, sightParams) == nil then
		return true
	end
	local head = target.head
	return head ~= nil and Workspace:Raycast(eye, head.Position - eye, sightParams) == nil
end

local function canSee(monster: Monster): boolean
	return monster.def.SightRange > 0 and hasSense(monster, "Sight")
end

local function isInSight(monster: Monster, target: Target, checkAngle: boolean): boolean
	local offset = target.rootPart.Position - monster.eye.Position
	if offset.Magnitude > monster.def.SightRange then
		return false
	end
	if checkAngle then
		local flatOffset = flat(offset)
		local flatLook = flat(monster.rootPart.CFrame.LookVector)
		if flatOffset.Magnitude > 1e-3 and flatLook.Magnitude > 1e-3 then
			local minDot = math.cos(math.rad(monster.def.SightAngle / 2))
			if flatOffset.Unit:Dot(flatLook.Unit) < minDot then
				return false
			end
		end
	end
	return hasLineOfSight(monster, target)
end

-- 보이는 생존자 중 preferred가 있으면 그 사람, 없으면 가장 가까운 사람.
local function findVisibleTarget(
	monster: Monster,
	targets: { Target },
	checkAngle: boolean,
	preferred: Player?
): Target?
	if not canSee(monster) then
		return nil
	end
	local best: Target? = nil
	local bestDistance = math.huge
	local origin = monster.rootPart.Position
	for _, target in targets do
		if isInSight(monster, target, checkAngle) then
			if target.player == preferred then
				return target
			end
			local distance = (target.rootPart.Position - origin).Magnitude
			if distance < bestDistance then
				best = target
				bestDistance = distance
			end
		end
	end
	return best
end

-- 시야각 안에 보이는 생존자 모두 (감시자)
local function findVisibleTargets(monster: Monster, targets: { Target }): { Target }
	local seen: { Target } = {}
	if canSee(monster) then
		for _, target in targets do
			if isInSight(monster, target, true) then
				table.insert(seen, target)
			end
		end
	end
	return seen
end

-- range 안에서 벽에 가리지 않은 가장 가까운 생존자 (시야각·시각 감각과 상관없음. 사냥개가 가까이 있는 생존자를 알아챔)
local function findNearbyTarget(monster: Monster, targets: { Target }, range: number): Target?
	if range <= 0 then
		return nil
	end
	local best: Target? = nil
	local bestDistance = range
	local origin = monster.rootPart.Position
	for _, target in targets do
		local distance = (target.rootPart.Position - origin).Magnitude
		if distance <= bestDistance and hasLineOfSight(monster, target) then
			best = target
			bestDistance = distance
		end
	end
	return best
end

local function findTarget(targets: { Target }, player: Player?): Target?
	for _, target in targets do
		if target.player == player then
			return target
		end
	end
	return nil
end

local function markForChasers(position: Vector3, duration: number, reason: Types.MarkerReason): ()
	local remote = Remotes.get("ChaserMarker")
	for _, chaser in RoleService.getChasers() do
		remote:FireClient(chaser, position, duration, reason)
	end
end

--------------------------------------------------------------------------------
-- 공통 상태 처리 (배회자식 흐름)

local function remember(monster: Monster, target: Target, now: number): ()
	monster.target = target.player
	monster.lastSeenPosition = target.rootPart.Position
	monster.lastSeenAt = now
end

local function startChase(monster: Monster, target: Target, now: number, reason: string): ()
	remember(monster, target, now)
	setState(monster, "Chase", `{target.player.Name}, {reason}`)
end

-- 순찰·포기 중 생존자를 봤을 때: 가까우면 바로 추격, 아니면 의심.
-- 순찰 경로를 계속 따라가면 본 생존자에게서 돌아설 수 있어서 먼저 멈춘다.
local function notice(monster: Monster, target: Target, now: number): ()
	stopMoving(monster)
	local distance = (target.rootPart.Position - monster.rootPart.Position).Magnitude
	if distance <= Config.InstantChaseDistance then
		startChase(monster, target, now, `가까움 {math.round(distance)}스터드`)
		return
	end
	remember(monster, target, now)
	monster.suspicion = 0
	setState(monster, "Suspicious", `{target.player.Name}, {math.round(distance)}스터드`)
end

local function giveUp(monster: Monster, reason: string): ()
	monster.target = nil
	monster.lastSeenPosition = nil
	monster.noiseGoal = nil
	stopMoving(monster)
	setState(monster, "GiveUp", reason)
end

-- 대상을 놓쳤을 때 포기하는 이유 (로그용)
local function lostReason(monster: Monster): string
	local target = monster.target
	if target and HideService.isHidden(target) then
		return `{target.Name} 숨음`
	end
	return "놓침"
end

local function resumePatrol(monster: Monster): ()
	local route = monster.route
	if route then
		monster.routeIndex = nearestPointIndex(route, monster.rootPart.Position)
	end
	clearPath(monster)
	setState(monster, "Patrol")
end

-- 마지막으로 본 곳으로 가 본다. LoseSightTime초가 지났거나 가 봐도 없으면 포기한다.
local function searchLastSeen(monster: Monster, now: number): ()
	local goal = monster.lastSeenPosition
	if now - monster.lastSeenAt >= Config.LoseSightTime or not goal then
		giveUp(monster, lostReason(monster))
		return
	end
	if flatDistance(goal, monster.rootPart.Position) <= Config.ArriveDistance then
		giveUp(monster, `{lostReason(monster)}, 마지막 위치에 없음`)
		return
	end
	if checkStuck(monster, now, true) then
		monster.forceRepath = true
	end
	travelTo(monster, goal, now, false)
end

local function tickPatrol(monster: Monster, now: number, targets: { Target }): ()
	local seen = findVisibleTarget(monster, targets, true, nil)
	if seen then
		notice(monster, seen, now)
		return
	end
	local route = monster.route
	if not route or monster.humanoid.WalkSpeed <= 0 then
		return
	end
	local position = monster.rootPart.Position
	if flatDistance(route.points[monster.routeIndex], position) <= Config.ArriveDistance then
		monster.routeIndex = monster.routeIndex % #route.points + 1
	end
	local goal = route.points[monster.routeIndex]
	if checkStuck(monster, now, flatDistance(goal, position) > Config.ArriveDistance) then
		-- 갈 수 없는 지점이면 다음 지점으로 넘어간다.
		monster.routeIndex = monster.routeIndex % #route.points + 1
		goal = route.points[monster.routeIndex]
		monster.forceRepath = true
	end
	travelTo(monster, goal, now, false)
end

local function tickSuspicious(monster: Monster, now: number, dt: number, targets: { Target }): ()
	local seen = findVisibleTarget(monster, targets, true, monster.target)
	if not seen then
		searchLastSeen(monster, now)
		return
	end
	if seen.player ~= monster.target then
		monster.suspicion = 0
	end
	remember(monster, seen, now)
	monster.suspicion += dt
	local distance = (seen.rootPart.Position - monster.rootPart.Position).Magnitude
	if monster.suspicion >= Config.SuspicionTime then
		startChase(monster, seen, now, "확인")
		return
	elseif distance <= Config.InstantChaseDistance then
		startChase(monster, seen, now, `가까움 {math.round(distance)}스터드`)
		return
	end
	if checkStuck(monster, now, true) then
		monster.forceRepath = true
	end
	travelTo(monster, seen.rootPart.Position, now, true)
end

-- 사거리 안이고 쿨다운이 지났으면 멈춰서 공격을 시작한다.
local function tryStartAttack(monster: Monster, target: Target, now: number): boolean
	local def = monster.def
	local distance = (target.rootPart.Position - monster.rootPart.Position).Magnitude
	if def.AttackRange <= 0 or distance > def.AttackRange or now < monster.nextAttackAt then
		return false
	end
	stopMoving(monster)
	face(monster, target.rootPart.Position)
	monster.nextAttackAt = now + def.AttackCooldown
	monster.attackHitAt = now + Config.AttackWindup
	monster.animations.attack:Play(Config.AnimationFadeTime)
	setState(monster, "Attack", target.player.Name)
	return true
end

local function tickChase(monster: Monster, now: number, targets: { Target }): ()
	-- 쫓는 중에는 대상이 등 뒤로 돌아가도 놓치지 않게 시야각을 보지 않는다.
	local seen = findVisibleTarget(monster, targets, false, monster.target)
	if not seen then
		searchLastSeen(monster, now)
		return
	end
	if seen.player ~= monster.target then
		print(`[Monster] {monster.name} 추격 대상 바꿈 → {seen.player.Name}`)
	end
	remember(monster, seen, now)
	if tryStartAttack(monster, seen, now) then
		return
	end

	local def = monster.def
	if def.WalkSpeed <= 0 then
		return
	end
	local targetPosition = seen.rootPart.Position
	local distance = (targetPosition - monster.rootPart.Position).Magnitude
	if checkStuck(monster, now, distance > def.AttackRange) then
		monster.forceRepath = true
		monster.pathOnlyUntil = now + Config.StuckTime
	end
	if distance <= Config.DirectChaseDistance and now >= monster.pathOnlyUntil then
		moveDirect(monster, targetPosition)
	else
		travelTo(monster, targetPosition, now, true)
	end
end

local function tickAttack(monster: Monster, now: number, targets: { Target }): ()
	if now < monster.attackHitAt then
		return
	end
	local target = findTarget(targets, monster.target)
	local inReach = target ~= nil
		and (target.rootPart.Position - monster.rootPart.Position).Magnitude <= monster.def.AttackRange
		and hasLineOfSight(monster, target)
	if target and inReach then
		if
			not CatchService.hit(
				target.player,
				`괴물 {monster.name}`,
				monster.def.CatchesInstantly,
				nil,
				monster.model
			)
		then
			print(`[Monster] {monster.name} 공격 → {target.player.Name} 맞힐 수 없음 (무적 시간 등)`)
		elseif MatchState.getSurvivorState(target.player) == "Caught" then
			-- 잡힘 연출: 덮치듯 뛰어오르고 공격 동작을 한 번 더 한 뒤 잠깐 그 자리에 선다.
			face(monster, target.rootPart.Position)
			stopMoving(monster)
			monster.humanoid.Jump = true
			monster.animations.attack:Play(Config.AnimationFadeTime)
			monster.catchPauseUntil = now + Catch.CaughtEffect.MonsterPause
			monster.target = nil
		end
	else
		print(`[Monster] {monster.name} 공격 → 빗나감`)
	end
	monster.stuckCheckAt = now
	setState(monster, "Chase")
end

local function tickGiveUp(monster: Monster, now: number, targets: { Target }): ()
	local seen = findVisibleTarget(monster, targets, true, nil)
	if seen then
		notice(monster, seen, now)
	elseif now - monster.stateSince >= Config.GiveUpTime then
		resumePatrol(monster)
	end
end

api = {
	setState = setState,
	tickPatrol = tickPatrol,
	tickSuspicious = tickSuspicious,
	tickChase = tickChase,
	tickAttack = tickAttack,
	tickGiveUp = tickGiveUp,
	resumePatrol = resumePatrol,
	giveUp = giveUp,
	remember = remember,
	travelTo = travelTo,
	moveDirect = moveDirect,
	stopMoving = stopMoving,
	checkStuck = checkStuck,
	findVisibleTarget = findVisibleTarget,
	findVisibleTargets = findVisibleTargets,
	findNearbyTarget = findNearbyTarget,
	tryStartAttack = tryStartAttack,
	markForChasers = markForChasers,
	isInDarkZone = function(position: Vector3): boolean
		for _, zone in darkZones do
			local localPosition = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if
				math.abs(localPosition.X) <= half.X
				and math.abs(localPosition.Y) <= half.Y
				and math.abs(localPosition.Z) <= half.Z
			then
				return true
			end
		end
		return false
	end,
	isHidden = function(player: Player): boolean
		return HideService.isHidden(player)
	end,
	hiddenSpotPosition = function(player: Player): Vector3?
		return HideService.getHiddenSpotPosition(player)
	end,
	breakHideSpot = function(player: Player, source: string): boolean
		return HideService.breakSpotOf(player, source)
	end,
	breakBarriers = function(position: Vector3, radius: number, source: string): number
		return BarrierService.breakNear(position, radius, source)
	end,
}

local function tick(monster: Monster, now: number, dt: number, active: boolean, targets: { Target }): ()
	if active and now < monster.catchPauseUntil then
		return
	end
	if not active then
		if monster.state ~= "Idle" then
			monster.target = nil
			monster.noiseGoal = nil
			stopMoving(monster)
			setState(monster, "Idle")
			local onIdle = monster.behavior.onIdle
			if onIdle then
				onIdle(monster)
			end
		end
		return
	end
	monster.behavior.tick(monster, now, dt, targets, api)
end

-- 조종자가 부름: 마지막으로 본 곳을 position으로 두고 의심 상태로 찾아오게 한다.
-- LoseSightTime 계산이 seconds초 뒤에 끝나도록 lastSeenAt을 미래로 둔다.
local function defaultSummon(monster: Monster, position: Vector3, now: number, seconds: number, source: string): ()
	monster.target = nil
	monster.lastSeenPosition = position
	monster.lastSeenAt = now + seconds - Config.LoseSightTime
	monster.suspicion = 0
	stopMoving(monster)
	setState(monster, "Suspicious", `부름: {source}`)
end

-- position에 가까운 움직이는 괴물 count마리를 seconds초 동안 position으로 부른다. 부른 수를 돌려준다.
-- 조종자 스킬이 위치 감지로 바뀌어(2026-11-22) 지금 부르는 곳은 없다. 괴물과 추격자가 함께 나오는 스테이지
-- (Config.Match.MonstersWithChasers)에 부르기 스킬을 다시 넣을 때 쓴다.
function MonsterService.summon(position: Vector3, count: number, seconds: number, source: string): number
	if not MonsterState.canActInPhase(MatchState.getPhase()) then
		return 0
	end
	local movers: { Monster } = {}
	for _, monster in monsters do
		if monster.alive and monster.def.WalkSpeed > 0 and monster.state ~= "Attack" then
			table.insert(movers, monster)
		end
	end
	table.sort(movers, function(a: Monster, b: Monster): boolean
		return (a.rootPart.Position - position).Magnitude < (b.rootPart.Position - position).Magnitude
	end)
	local now = os.clock()
	local called = math.min(count, #movers)
	for index = 1, called do
		local monster = movers[index]
		local onSummon = monster.behavior.onSummon
		if onSummon then
			onSummon(monster, position, now, seconds, api)
		else
			defaultSummon(monster, position, now, seconds, source)
		end
	end
	print(`[Monster] {source} → 괴물 {called}마리 부름`)
	return called
end

-- 소리 사건: 들리는 거리 안의 소리를 듣는 괴물에게 전한다 (추격 단계만).
local function onNoise(noise: NoiseBus.Noise): ()
	if #monsters == 0 or not MonsterState.canActInPhase(MatchState.getPhase()) then
		return
	end
	local now = os.clock()
	for _, monster in monsters do
		local listener = monster.behavior.onNoise
		local distance = (monster.rootPart.Position - noise.position).Magnitude
		if listener and monster.alive and hasSense(monster, "Sound") then
			if distance <= math.min(monster.def.HearingRange, noise.radius) then
				listener(monster, noise, now, api)
			end
		elseif noise.kind == "Alarm" and monster.alive and monster.def.WalkSpeed > 0 and distance <= noise.radius then
			-- 알람시계: 소리를 듣지 못하는 괴물도 순찰·포기 중이면 확인하러 온다 (GDD 6.3 "괴물을 유인")
			if monster.state == "Patrol" or monster.state == "GiveUp" then
				defaultSummon(monster, noise.position, now, Config.AlarmLureTime, "알람시계 소리")
			end
		end
	end
end

-- 손전등 빛 (ItemService): origin에서 direction으로 range·angle(전체 각도) 원뿔 안에 있고 벽에 가리지 않은
-- 손전등에 멈추는 괴물(FlashlightFreezeTime, 그림자)을 멈춘다. 멈춘 수를 돌려준다.
-- 각도는 시야 판정처럼 수평으로만 잰다 (바로 앞까지 다가온 괴물이 아래로 기운 빛 밖으로 빠지지 않게).
function MonsterService.freezeInBeam(origin: Vector3, direction: Vector3, range: number, angle: number): number
	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if #monsters == 0 or flatDirection.Magnitude < 1e-3 then
		return 0
	end
	local look = flatDirection.Unit
	local minDot = math.cos(math.rad(angle / 2))
	local now = os.clock()
	local frozen = 0
	refreshSightFilter()
	for _, monster in monsters do
		local freezeTime = monster.def.FlashlightFreezeTime
		if freezeTime and monster.alive then
			local offset = monster.rootPart.Position - origin
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			local distance = offset.Magnitude
			local facing = flatOffset.Magnitude < 1e-3 or flatOffset.Unit:Dot(look) >= minDot
			if distance <= range and facing then
				if Workspace:Raycast(origin, offset, sightParams) == nil then
					if now >= monster.frozenUntil then
						print(`[Monster] {monster.name} 손전등에 멈춤 ({freezeTime}초)`)
					end
					monster.frozenUntil = now + freezeTime
					frozen += 1
				end
			end
		end
	end
	return frozen
end

--------------------------------------------------------------------------------
-- 생성·제거

local function destroyMonster(monster: Monster): ()
	monster.alive = false
	for _, connection in monster.connections do
		connection:Disconnect()
	end
	table.clear(monster.connections)
	monster.path:Destroy()
	monster.model:Destroy()
end

local function isGone(monster: Monster): boolean
	return not monster.rootPart:IsDescendantOf(Workspace) or monster.humanoid.Health <= 0
end

-- 먼 괴물 판정의 기준이 되는 위치: 남은 생존자(숨은 사람 포함)와 추격자
local function observerPositions(): { Vector3 }
	local positions: { Vector3 } = {}
	for _, player in RoleService.getActiveSurvivors() do
		local parts = CharacterParts.get(player)
		if parts then
			table.insert(positions, parts.rootPart.Position)
		end
	end
	for _, chaser in RoleService.getChasers() do
		local parts = CharacterParts.get(chaser)
		if parts then
			table.insert(positions, parts.rootPart.Position)
		end
	end
	return positions
end

local function isFar(position: Vector3, observers: { Vector3 }): boolean
	for _, observer in observers do
		if (observer - position).Magnitude <= Config.FarDistance then
			return false
		end
	end
	return true
end

local function step(): ()
	local now = os.clock()
	local due: { Monster } = {}
	for _, monster in monsters do
		if now >= monster.nextTickAt then
			table.insert(due, monster)
		end
	end
	if #due == 0 then
		return
	end

	local active = MonsterState.canActInPhase(MatchState.getPhase())
	local targets: { Target } = {}
	local observers: { Vector3 } = {}
	if active then
		targets = collectTargets()
		refreshSightFilter()
		observers = observerPositions()
	end
	for _, monster in due do
		local far = active and isFar(monster.rootPart.Position, observers)
		-- 시작 시점을 나눈 간격이 유지되도록 갱신 간격 단위로 넘긴다.
		local interval = if far then Config.FarTickInterval else Config.TickInterval
		while monster.nextTickAt <= now do
			monster.nextTickAt += interval
		end
		local dt = now - monster.lastTickAt
		monster.lastTickAt = now
		if isGone(monster) then
			print(`[Monster] {monster.name} 사라짐 (맵 밖으로 떨어짐 등)`)
			destroyMonster(monster)
			local index = table.find(monsters, monster)
			if index then
				table.remove(monsters, index)
			end
		else
			if active then
				tickStats.total += 1
				if far then
					tickStats.far += 1
				end
			end
			tick(monster, now, dt, active, if far then NO_TARGETS else targets)
		end
	end
end

local function loadAnimation(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	return track
end

local function setupAnimations(humanoid: Humanoid): Animations
	-- 서버에서 Animator로 재생하면 모든 클라이언트에 복제된다.
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local ids = Assets.MonsterAnimations
	return {
		idle = loadAnimation(animator, ids.Idle, Enum.AnimationPriority.Idle),
		walk = loadAnimation(animator, ids.Walk, Enum.AnimationPriority.Movement),
		attack = loadAnimation(animator, ids.Attack, Enum.AnimationPriority.Action),
	}
end

-- 서 있기·걷기 애니메이션을 이동 속도에 맞춰 바꾸고, 경로 중간 지점에 닿으면 바로 다음 지점으로 간다.
local function connectHumanoid(monster: Monster): ()
	local animations = monster.animations
	animations.idle:Play()
	table.insert(
		monster.connections,
		monster.humanoid.Running:Connect(function(speed: number)
			if speed > MOVING_SPEED then
				if not animations.walk.IsPlaying then
					animations.walk:Play(Config.AnimationFadeTime)
				end
				animations.walk:AdjustSpeed(speed / Config.WalkAnimationSpeed)
			elseif animations.walk.IsPlaying then
				animations.walk:Stop(Config.AnimationFadeTime)
			end
		end)
	)
	table.insert(
		monster.connections,
		monster.humanoid.MoveToFinished:Connect(function()
			if monster.alive and #monster.waypoints > 0 then
				moveAlongPath(monster)
			end
		end)
	)
end

local function setupHumanoid(humanoid: Humanoid, def: Monsters.MonsterDef): ()
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	-- 넘어지거나 의자에 앉거나 벽을 타지 않게 한다.
	for _, state in
		{
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.Climbing,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
end

-- 모델을 복제해 spawnPart 위에 세운다. lap은 같은 자리에 몇 번째로 놓이는지 (옆으로 띄움).
local function createMonster(
	kind: Types.MonsterId,
	template: Model,
	spawnPart: BasePart,
	lap: number,
	route: Route?,
	parent: Folder
): Monster?
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model.PrimaryPart
	local head = model:FindFirstChild("Head")
	if not humanoid or not rootPart or not head or not head:IsA("BasePart") then
		warn(
			`[Monster] ServerStorage.{MonsterState.ModelsFolderName}.{kind}: Humanoid, PrimaryPart(HumanoidRootPart), Head가 필요합니다`
		)
		model:Destroy()
		return nil
	end

	serial += 1
	local def = Monsters[kind]
	setupHumanoid(humanoid, def)
	local standHeight = spawnPart.Size.Y / 2 + humanoid.HipHeight + rootPart.Size.Y / 2
	model:PivotTo(spawnPart.CFrame * CFrame.new(lap * Config.SpawnSpacing, standHeight, 0))
	model.Name = `{kind}{serial}`
	MonsterLooks.apply(model, kind, MatchState.getMatchMode() or VisualModes.Default)
	model:SetAttribute(Attribute.MonsterId, kind)
	model:SetAttribute(Attribute.State, "Idle")
	-- 추격자 화면의 괴물 위치 아이콘이 멀리서도 보이게 추격자에게는 항상 스트리밍한다.
	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model.Parent = parent
	for _, chaser in RoleService.getChasers() do
		model:AddPersistentPlayer(chaser)
	end
	-- 괴물의 물리는 서버가 맡는다. 가까운 플레이어에게 넘어가면 움직임이 끊기고 조작될 수 있다.
	if rootPart:CanSetNetworkOwnership() then
		rootPart:SetNetworkOwner(nil)
	end

	local now = os.clock()
	local agent = Config.Agent
	local agentRadius = def.AgentRadius or agent.Radius
	local agentHeight = def.AgentHeight or agent.Height
	local monster: Monster = {
		name = `{Strings.Monsters[kind]}#{serial}`,
		kind = kind,
		def = def,
		behavior = BEHAVIORS[kind],
		model = model,
		humanoid = humanoid,
		rootPart = rootPart,
		eye = head,
		path = PathfindingService:CreatePath({
			AgentRadius = agentRadius,
			AgentHeight = agentHeight,
			AgentCanJump = agent.CanJump,
			AgentCanClimb = false,
		}),
		animations = setupAnimations(humanoid),
		connections = {},
		alive = true,

		state = "Idle",
		stateSince = now,
		nextTickAt = now,
		lastTickAt = now,

		route = route,
		routeIndex = if route then nearestPointIndex(route, rootPart.Position) else 1,

		target = nil,
		lastSeenPosition = nil,
		lastSeenAt = 0,
		suspicion = 0,
		nextAttackAt = 0,
		attackHitAt = 0,

		pathRequest = 0,
		computing = false,
		lastPathAt = -math.huge,
		pathGoal = nil,
		waypoints = {},
		waypointIndex = 1,
		forceRepath = false,
		pathOnlyUntil = 0,

		stuckCheckPosition = rootPart.Position,
		stuckCheckAt = now,

		noiseGoal = nil,
		dashUntil = 0,
		alertedAt = {},
		frozenUntil = 0,
		catchPauseUntil = 0,
	}
	connectHumanoid(monster)
	return monster
end

-- 괴물을 모두 지우고 갱신을 멈춘다. 스테이지가 끝날 때(맵을 지우기 전) 부른다.
function MonsterService.clear(): ()
	local count = #monsters
	for _, monster in monsters do
		destroyMonster(monster)
	end
	table.clear(monsters)
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if monsterFolder then
		monsterFolder:Destroy()
		monsterFolder = nil
	end
	table.clear(darkZones)
	if count > 0 then
		print(
			`[Monster] 괴물 {count}마리 제거 · 길찾기 {pathStats.computed}회 (동시 상한으로 미룸 {pathStats.deferred}회)`
				.. ` · AI 갱신 {tickStats.total}회 (먼 괴물 {tickStats.far}회)`
		)
	end
	pathStats.computed = 0
	pathStats.deferred = 0
	tickStats.total = 0
	tickStats.far = 0
end

-- 불러온 맵의 MonsterSpawn에 이번 스테이지의 괴물을 만든다. 추격 단계가 되어야 움직인다.
function MonsterService.spawnForStage(
	map: Instance,
	stageId: Types.StageId,
	survivorCount: number,
	hasChaser: boolean
): ()
	MonsterService.clear()
	local groups = MonsterService.computeCounts(stageId, survivorCount, hasChaser)
	local spawns = shuffled(taggedParts(map, MapTags.MonsterSpawn))
	if #spawns == 0 then
		warn(
			`[Monster] {stageId}: {MapTags.MonsterSpawn} 태그가 붙은 Part가 없어 괴물을 만들지 않습니다`
		)
		return
	end
	local routes = loadRoutes(map)
	if #routes == 0 then
		warn(`[Monster] {stageId}: {MapTags.PatrolPoint}가 없어 괴물이 제자리에 서 있습니다`)
	end

	local stale = Workspace:FindFirstChild(MonsterState.FolderName)
	if stale then
		stale:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = MonsterState.FolderName
	folder.Parent = Workspace
	monsterFolder = folder
	darkZones = taggedParts(map, MapTags.DarkZone)

	local templates = ServerStorage:FindFirstChild(MonsterState.ModelsFolderName)
	local function findTemplate(kind: Types.MonsterId): Model?
		local template = templates and templates:FindFirstChild(kind)
		return if template and template:IsA("Model") then template else nil
	end
	local routeUse: { [string]: number } = {}
	local spawnUse: { [BasePart]: number } = {}
	local made: { [Types.MonsterId]: number } = {}
	local madeOrder: { Types.MonsterId } = {}
	for _, group in groups do
		local kind = group.Monster
		local template = findTemplate(kind)
		if group.Count > 0 and (not BEHAVIORS[kind] or not template) then
			local reason = if BEHAVIORS[kind]
				then `ServerStorage.{MonsterState.ModelsFolderName}.{kind} 모델이 없어`
				else "아직 동작을 만들지 않아"
			warn(
				`[Monster] {Strings.Monsters[kind]}({kind}) {group.Count}마리: {reason} {Strings.Monsters[FALLBACK_MONSTER]}로 대신합니다`
			)
			kind = FALLBACK_MONSTER
			template = findTemplate(kind)
		end
		if group.Count > 0 and not template then
			warn(
				`[Monster] ServerStorage.{MonsterState.ModelsFolderName}.{kind} 모델이 없어 {Strings.Monsters[kind]} {group.Count}마리를 건너뜁니다`
			)
		elseif template then
			for _ = 1, group.Count do
				local spawnPart, lap = pickSpawn(kind, spawns, spawnUse)
				local route = if BEHAVIORS[kind].usesPatrolRoute
					then pickRoute(routes, routeUse, spawnPart.Position)
					else nil
				local monster = createMonster(kind, template, spawnPart, lap, route, folder)
				if monster then
					table.insert(monsters, monster)
					if not made[kind] then
						table.insert(madeOrder, kind)
					end
					made[kind] = (made[kind] or 0) + 1
				end
			end
		end
	end
	local summary: { string } = {}
	for _, kind in madeOrder do
		table.insert(summary, `{Strings.Monsters[kind]} {made[kind]}`)
	end

	-- 갱신 시작 시점을 괴물 수로 나눈다 (GDD 4.4).
	local now = os.clock()
	for index, monster in monsters do
		monster.nextTickAt = now + (index - 1) / #monsters * Config.TickInterval
		monster.lastTickAt = now
	end
	if #monsters > 0 then
		heartbeatConnection = RunService.Heartbeat:Connect(step)
	end

	local who = if hasChaser then `생존자 {survivorCount}명 + 추격자` else `솔로 생존자 {survivorCount}명`
	print(
		`[Monster] {stageId} ({who}) → {table.concat(summary, ", ")} 생성 · MonsterSpawn {#spawns}곳 · 순찰 경로 {#routes}개`
	)
	for _, monster in monsters do
		local routeName = if monster.route then monster.route.name else "없음"
		print(`[Monster] {monster.name} → 순찰 경로 {routeName}`)
	end
end

function MonsterService.Init(): ()
	-- 먼 괴물 단순화가 보이는 동작을 바꾸지 않으려면 FarDistance가 가장 먼 시야보다 충분히 커야 한다.
	local farthestSight = 0
	for _, def in Monsters do
		farthestSight = math.max(farthestSight, def.SightRange)
	end
	local needed = farthestSight + Survivor.RunSpeed * Config.FarTickInterval
	if Config.FarDistance < needed then
		warn(
			`[Monster] Config.MonsterAI.FarDistance({Config.FarDistance})가 가장 먼 시야 + 달리기 거리({needed})보다 작아 먼 괴물이 생존자를 늦게 볼 수 있습니다`
		)
	end
end

function MonsterService.Start(): ()
	NoiseBus.subscribe(onNoise)
	-- ItemService는 MonsterService를 require하지 않는다 (MonsterService가 ItemService를 씀). 손전등 빛을 여기로 받는다.
	ItemService.setBeamHandler(MonsterService.freezeInBeam)
end

return MonsterService
