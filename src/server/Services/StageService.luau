--!strict
-- StageService: 맵 불러오기, 스테이지 한 판 진행과 타이머 (GDD 3.1, 3.2, 5장, 13.2). 목표 장치·출구는 ObjectiveService.
--
-- 한 스테이지: 역할 공개 → 준비 → 추격 → 결과 (MatchService가 runStage로 부름)
--   역할 공개  Config.Match.RoleRevealTime   추격자를 뽑고 룰렛 신호(RoleReveal)를 보냄. 솔로는 생략 (GDD 3.1)
--   준비       Config.Match.PreparationTime  맵을 Workspace.CurrentMap에 복제한다. 매치 화면 모드가 캐주얼이면
--                                            맵 색을 파스텔로 바꾼다 (Util/MapStyler). 조명은 클라이언트(VisualModeController)가 바꾼다.
--                                            카메라 높이 제한(바닥 윗면 + Config.Camera.StageCeilingHeight)을 CameraCeiling으로 공개.
--                                            생존자는 SurvivorSpawn, 추격자는 전용 외형(ChaserService)으로 ChaserSpawn에 배치.
--                                            ChaserGate는 닫아 둠. 숨는 곳(HideService)·발전기와 출구(ObjectiveService)·
--                                            아이템(ItemService)·판자와 문(BarrierService) 준비
--                                            괴물 생성(MonsterService). 괴물은 추격 단계부터 움직인다
--   추격       Config.Stages[id].TimeLimit   ChaserGate를 엶
--   결과       Config.Match.StageResultTime  추격이 일찍 끝났으면(마지막 생존자가 잡힘 등) 잡힘 연출 시간
--                                            (Config.Match.CaughtEffectTime)을 기다린 뒤,
--                                            결과를 RecordService에 기록하고 코인·통계를 지급(DataService),
--                                            StageResult 리모트로 보냄.
--                                            끝나면 맵을 지우고 역할을 비움
--
-- 참가자: MatchService가 넘겨준 매치 참가자만 역할을 받는다. 로비에 있는 다른 사람은 상관없다.
--   신호(역할 공개·알림·결과)는 참가자에게만 보낸다. "로비로 돌아가기"로 빠진 참가자(leaveMatch)는 나간 것으로 본다.
-- 조기 종료: 남은 생존자가 없으면 (모두 잡힘·탈출·나감) 바로 결과로 간다 (GDD 3.2, 5장).
-- 추격자가 나가면(게임에서 나감·로비로 돌아감) 새로 뽑지 않고 괴물만으로 계속한다 (GDD 5장, 질문지 Q6-5).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Camera = require(ReplicatedStorage.Shared.Config.Camera)
local MapObjects = require(ReplicatedStorage.Shared.Config.MapObjects)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local VisualModes = require(ReplicatedStorage.Shared.Config.VisualModes)
local MapStyler = require(ReplicatedStorage.Shared.Util.MapStyler)
local CharacterLoader = require(script.Parent.Parent.Util.CharacterLoader)
local PhaseTimer = require(script.Parent.Parent.Util.PhaseTimer)
local BarrierService = require(script.Parent.BarrierService)
local ChaserService = require(script.Parent.ChaserService)
local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local HideService = require(script.Parent.HideService)
local ItemService = require(script.Parent.ItemService)
local MonsterService = require(script.Parent.MonsterService)
local MovementService = require(script.Parent.MovementService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local RecordService = require(script.Parent.RecordService)
local RoleService = require(script.Parent.RoleService)

local MAPS_FOLDER = "Maps" -- ServerStorage.Maps
local CURRENT_MAP_NAME = "CurrentMap" -- Workspace.CurrentMap

type EndReason = "TimeUp" | "NoSurvivorsLeft"

type StageRun = {
	stageId: Types.StageId,
	participants: { Player }, -- 이 스테이지 참가자 (MatchService가 넘김)
	left: { [Player]: boolean }, -- 스테이지 중에 로비로 돌아간 참가자
	survivors: { Player }, -- 처음 생존자로 배정된 사람 (결과 기록용)
	chaser: Player?, -- 추격자가 나가면 nil
	originalChaser: Player?, -- 처음 뽑힌 추격자 (결과 기록용)
	hadChaser: boolean,
	map: Instance?, -- 준비 단계에서 불러옴
	gateClosedTransparency: { [BasePart]: number },
}

local Attribute = MatchState.Attribute

local StageService = {}

local random = Random.new()
local current: StageRun? = nil

local function names(players: { Player }): string
	local list: { string } = {}
	for _, player in players do
		table.insert(list, player.Name)
	end
	return if #list > 0 then table.concat(list, ", ") else "없음"
end

local function isInGame(player: Player): boolean
	return player.Parent == Players
end

-- 아직 이 스테이지에 남아 있는 참가자인가 (게임에서 나가거나 로비로 돌아가지 않음)
local function isInMatch(run: StageRun, player: Player): boolean
	return isInGame(player) and not run.left[player] and table.find(run.participants, player) ~= nil
end

-- 남아 있는 참가자에게만 리모트를 보낸다.
local function fireParticipants(run: StageRun, name: Remotes.ServerEventName, ...: any): ()
	local remote = Remotes.get(name)
	for _, player in run.participants do
		if isInMatch(run, player) then
			remote:FireClient(player, ...)
		end
	end
end

-- 맵 안에서 태그가 붙은 파트. ServerStorage의 원본 맵에도 같은 태그가 있어서 CollectionService:GetTagged 대신 맵 안만 찾는다.
local function taggedParts(map: Instance, tag: string): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:HasTag(tag) then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- 대기실 문을 이루는 파트. 문은 Part 하나이거나 Part를 담은 Model이다.
local function gateParts(map: Instance): { BasePart }
	local parts: { BasePart } = {}
	for _, descendant in map:GetDescendants() do
		if descendant:HasTag(MapTags.ChaserGate) then
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
			for _, child in descendant:GetDescendants() do
				if child:IsA("BasePart") then
					table.insert(parts, child)
				end
			end
		end
	end
	return parts
end

local function setGateOpen(run: StageRun, open: boolean): ()
	local map = run.map
	if not map then
		return
	end
	for _, part in gateParts(map) do
		if run.gateClosedTransparency[part] == nil then
			run.gateClosedTransparency[part] = part.Transparency
		end
		part.CanCollide = not open
		-- 열린 문이 괴물 시야(레이캐스트)를 가리지 않게 한다.
		part.CanQuery = not open
		part.Transparency = if open then MapObjects.ChaserGate.OpenTransparency else run.gateClosedTransparency[part]
	end
	print(`[Stage] 대기실 문 {if open then "열림" else "닫힘"}`)
end

local function loadMap(stageId: Types.StageId): Instance
	StageService.unloadMap()
	local mapName = Stages[stageId].MapFolder
	local maps = ServerStorage:FindFirstChild(MAPS_FOLDER)
	local source = maps and maps:FindFirstChild(mapName)
	assert(source, `ServerStorage.{MAPS_FOLDER}.{mapName} 맵이 없습니다`)

	local map = source:Clone()
	map.Name = CURRENT_MAP_NAME
	assert(
		#taggedParts(map, MapTags.SurvivorSpawn) > 0,
		`{mapName}: {MapTags.SurvivorSpawn} 태그가 붙은 Part가 없습니다`
	)
	assert(
		#taggedParts(map, MapTags.ChaserSpawn) > 0,
		`{mapName}: {MapTags.ChaserSpawn} 태그가 붙은 Part가 없습니다`
	)
	if #gateParts(map) == 0 then
		warn(`[Stage] {mapName}: {MapTags.ChaserGate} 태그가 붙은 문이 없습니다`)
	end
	-- 캐주얼 모드: 다른 서비스가 맵을 준비(원래 색 기억 등)하기 전에 칠한다.
	local mode = MatchState.getMatchMode() or VisualModes.Default
	local styled = if mode == "Casual" then MapStyler.apply(map, VisualModes.Casual.Palette, {}) else 0
	-- 카메라 높이 제한: 시작 위치 표시(바닥 위에 놓임)의 가장 낮은 아랫면을 바닥 윗면으로 본다.
	local floorTop = math.huge
	for _, spawnPart in taggedParts(map, MapTags.SurvivorSpawn) do
		floorTop = math.min(floorTop, spawnPart.Position.Y - spawnPart.Size.Y / 2)
	end
	ReplicatedStorage:SetAttribute(Attribute.CameraCeiling, floorTop + Camera.StageCeilingHeight)
	map.Parent = Workspace
	print(
		`[Stage] 맵 불러옴: ServerStorage.{MAPS_FOLDER}.{mapName} → Workspace.{CURRENT_MAP_NAME} · 화면 모드 {mode}`
			.. (if styled > 0 then ` (파트 {styled}개 색 바꿈)` else "")
	)
	return map
end

function StageService.unloadMap(): ()
	local map = Workspace:FindFirstChild(CURRENT_MAP_NAME)
	if map then
		map:Destroy()
		print(`[Stage] 맵 제거: Workspace.{CURRENT_MAP_NAME}`)
	end
end

-- 살아 있는 캐릭터를 돌려준다. 없거나 죽었으면 새로 만든다 (멈춤). 만들지 못하면 nil.
local function ensureCharacter(player: Player): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return CharacterLoader.load(player, nil, "스테이지 배치")
	end
	return character
end

-- 캐릭터를 시작 위치 Part의 윗면에 세운다. 방향은 Part의 방향을 따른다.
local function placeAt(player: Player, spawnPart: BasePart): ()
	if not isInGame(player) then
		return
	end
	-- 추격자는 전용 외형으로 새로 불러온다 (ChaserService). 생존자는 지금 캐릭터 그대로.
	local character = if MatchState.getRole(player) == "Chaser"
		then ChaserService.loadCharacter(player)
		else ensureCharacter(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		warn(`[Stage] {player.Name}: 캐릭터가 없어 시작 위치로 옮기지 못했습니다`)
		return
	end
	local standHeight = spawnPart.Size.Y / 2 + humanoid.HipHeight + rootPart.Size.Y / 2
	character:PivotTo(spawnPart.CFrame * CFrame.new(0, standHeight, 0))
	MovementService.markTeleported(player)
end

local function shuffled<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- 그 역할의 시작 위치 하나. 생존자는 SurvivorSpawn 중 무작위, 추격자는 ChaserSpawn.
local function spawnFor(map: Instance, role: Types.Role): BasePart?
	local tag = if role == "Chaser" then MapTags.ChaserSpawn else MapTags.SurvivorSpawn
	local spawns = taggedParts(map, tag)
	if #spawns == 0 then
		return nil
	end
	return spawns[random:NextInteger(1, #spawns)]
end

-- 생존자는 서로 다른 SurvivorSpawn에 (자리가 모자라면 돌아가며), 추격자는 ChaserSpawn에 놓는다.
-- LoadCharacterAsync가 멈출 수 있어서 플레이어마다 따로 실행한다.
local function placeParticipants(run: StageRun, map: Instance): ()
	local survivorSpawns = shuffled(taggedParts(map, MapTags.SurvivorSpawn))
	local survivors = RoleService.getActiveSurvivors()
	for index, player in survivors do
		task.spawn(placeAt, player, survivorSpawns[(index - 1) % #survivorSpawns + 1])
	end

	local chaser = run.chaser
	local chaserSpawn = spawnFor(map, "Chaser")
	if chaser and chaserSpawn then
		task.spawn(placeAt, chaser, chaserSpawn)
	end
	print(
		`[Stage] 배치: 생존자 {#survivors}명 → {MapTags.SurvivorSpawn}`
			.. (if chaser then `, 추격자 {chaser.Name} → {MapTags.ChaserSpawn}` else "")
	)
end

-- 단계 타이머가 Config.Match.PhaseTickInterval마다 부른다. 추격자 이탈을 처리하고 남은 생존자 수를 공개한다.
-- 남은 생존자가 없으면 true (스테이지 조기 종료).
local function updateAndCheckEnd(run: StageRun): boolean
	local chaser = run.chaser
	if chaser and not isInMatch(run, chaser) then
		run.chaser = nil
		ReplicatedStorage:SetAttribute(Attribute.HasChaser, false)
		fireParticipants(run, "Notice", "ChaserLeft" :: Types.NoticeKey)
		print(`[Stage] 추격자 {chaser.Name} 이탈 → 이번 스테이지는 괴물만으로 계속`)
	end

	local survivorsLeft = #RoleService.getActiveSurvivors()
	if survivorsLeft ~= MatchState.getSurvivorsLeft() then
		ReplicatedStorage:SetAttribute(Attribute.SurvivorsLeft, survivorsLeft)
		print(`[Stage] 남은 생존자 {survivorsLeft}명`)
	end
	return survivorsLeft == 0
end

-- 플레이어별 결과를 정해 RecordService에 기록하고 출력 창에 남긴다 (GDD 3.2).
-- 생존자 성공: 탈출했거나 제한 시간이 끝날 때까지 잡히지 않음. 추격자 승리: 추격자가 남아 있고 성공한 생존자가 없음.
local function recordResult(run: StageRun, reason: EndReason): Types.StageResult
	local reasonText = if reason == "TimeUp" then "제한 시간 종료" else "남은 생존자 없음"
	local entries: { RecordService.StageEntry } = {}
	local lines: { string } = {}
	local succeeded = 0
	for _, player in run.survivors do
		local outcome: Types.StageOutcome
		if not isInMatch(run, player) then
			outcome = "Left"
		else
			local state = MatchState.getSurvivorState(player)
			if state == "Escaped" then
				outcome = "Escaped"
			elseif state == "Caught" then
				outcome = "Caught"
			else
				outcome = "Survived"
			end
		end
		if outcome == "Survived" or outcome == "Escaped" then
			succeeded += 1
		end
		local entry: RecordService.StageEntry = { player = player, outcome = outcome }
		table.insert(entries, entry)
		table.insert(lines, `{player.Name}={outcome}`)
	end
	local original = run.originalChaser
	if original then
		local outcome: Types.StageOutcome = if isInMatch(run, original) then "Chaser" else "Left"
		local entry: RecordService.StageEntry = { player = original, outcome = outcome }
		table.insert(entries, entry)
		table.insert(lines, `{original.Name}={outcome}`)
	end

	local chaserWon = run.chaser ~= nil and succeeded == 0
	local summary: string
	if not run.hadChaser then
		summary = `솔로 · 성공 {succeeded}/{#run.survivors}`
	elseif chaserWon and run.chaser then
		summary = `추격자 {run.chaser.Name} 승리`
	else
		summary = `생존자 성공 {succeeded}/{#run.survivors}`
	end
	print(`[Stage] 종료 ({reasonText}) · {summary} · {table.concat(lines, ", ")}`)
	return RecordService.finishStage(run.stageId, entries, original, chaserWon)
end

local function finish(): ()
	MonsterService.clear()
	ObjectiveService.clearMap()
	ItemService.clearMap()
	BarrierService.clearMap()
	HideService.clearMap()
	StageService.unloadMap()
	RoleService.clearAll()
	ReplicatedStorage:SetAttribute(Attribute.CameraCeiling, nil)
	ReplicatedStorage:SetAttribute(Attribute.StageId, nil)
	ReplicatedStorage:SetAttribute(Attribute.HasChaser, nil)
	ReplicatedStorage:SetAttribute(Attribute.SurvivorsLeft, nil)
	current = nil
end

-- 스테이지가 진행 중인가 (역할 공개부터 결과까지)
function StageService.isRunning(): boolean
	return current ~= nil
end

-- 오류로 runStage가 중간에 멈췄을 때 MatchService가 부른다.
function StageService.cleanup(): ()
	finish()
end

-- 죽은 플레이어를 다시 내보낸다. 스테이지 밖이거나 참가자가 아니면 로비(Workspace.Lobby의 SpawnLocation),
-- 스테이지 중인 참가자는 자기 역할의 시작 위치 (맵을 불러오기 전이면 로비). 관전자는 내보내지 않는다.
function StageService.respawn(player: Player): ()
	if not isInGame(player) then
		return
	end
	local run = current
	if not run or not isInMatch(run, player) then
		CharacterLoader.load(player, nil, "로비")
		return
	end
	local role = MatchState.getRole(player)
	if role ~= "Survivor" and role ~= "Chaser" then
		return
	end
	local spawnPart = run.map and spawnFor(run.map, role)
	if spawnPart then
		placeAt(player, spawnPart)
	else
		CharacterLoader.load(player, nil, "로비")
	end
	print(`[Stage] {player.Name} 다시 생성 ({role})`)
end

-- 참가자가 스테이지 중에 로비로 돌아간다 (MatchService). 역할을 지우고 나간 것으로 기록한다.
function StageService.leaveMatch(player: Player): ()
	local run = current
	if run and table.find(run.participants, player) then
		run.left[player] = true
		RoleService.clearRole(player)
		print(`[Stage] {player.Name} 스테이지에서 빠짐 (로비로)`)
	end
end

-- 스테이지 한 판을 진행한다. 결과 단계까지 끝나면 맵을 지우고 돌아온다 (MatchService가 스테이지마다 부름).
-- participants만 역할을 받는다. 추격자는 스테이지마다 새로 뽑고(GDD 3.3), 잡혔던 사람도 다음 스테이지에는 생존자로 돌아온다.
function StageService.runStage(stageId: Types.StageId, participants: { Player }): ()
	assert(current == nil, "이미 스테이지가 진행 중입니다")
	local stage = Stages[stageId]
	local chaser, candidates = RoleService.pickChaser(participants)
	RoleService.assignRoles(participants, chaser)

	local run: StageRun = {
		stageId = stageId,
		participants = table.clone(participants),
		left = {},
		survivors = RoleService.getActiveSurvivors(),
		chaser = chaser,
		originalChaser = chaser,
		hadChaser = chaser ~= nil,
		map = nil,
		gateClosedTransparency = {},
	}
	current = run
	RecordService.startStage()
	ReplicatedStorage:SetAttribute(Attribute.StageId, stageId)
	ReplicatedStorage:SetAttribute(Attribute.HasChaser, chaser ~= nil)
	ReplicatedStorage:SetAttribute(Attribute.SurvivorsLeft, #run.survivors)

	print(
		`[Stage] 스테이지 {MatchState.getStageIndex() or 1} · 맵 {stage.Number} ({Strings.Stages[stageId]}) 시작 · 참가자 {#participants}명`
	)
	if chaser then
		print(
			`[Role] 추격자: {chaser.Name} (이번이 {RoleService.getChaserCount(chaser)}번째) · 생존자: {names(
				run.survivors
			)}` .. ` · 후보 {#candidates}명`
		)
	else
		print(
			`[Role] 솔로 (참가자 {Match.MinPlayersForChaser}명 미만): 추격자 없음 · 생존자: {names(
				run.survivors
			)}`
		)
	end

	local function shouldEnd(): boolean
		return updateAndCheckEnd(run)
	end

	local outcome: PhaseTimer.Outcome = "TimeUp"

	-- 역할 공개 (솔로는 생략)
	if chaser then
		local candidateIds: { number } = {}
		for _, player in candidates do
			table.insert(candidateIds, player.UserId)
		end
		fireParticipants(run, "RoleReveal", chaser.UserId, candidateIds)
		outcome = PhaseTimer.run("RoleReveal", Match.RoleRevealTime, shouldEnd)
	else
		print("[Stage] 솔로라 역할 공개를 건너뜀")
	end

	-- 준비: 생존자는 흩어지고 추격자는 대기실에 갇혀 있음
	if outcome == "TimeUp" then
		local map = loadMap(stageId)
		run.map = map
		HideService.setupMap(map)
		ObjectiveService.setupMap(map, stageId)
		ItemService.setupMap(map)
		BarrierService.setupMap(map)
		MonsterService.spawnForStage(map, stageId, #run.survivors, run.hadChaser)
		setGateOpen(run, false)
		placeParticipants(run, map)
		local notice = Remotes.get("Notice")
		local survivorNotice: Types.NoticeKey = if run.chaser then "PreparationSurvivor" else "PreparationSolo"
		for _, player in RoleService.getActiveSurvivors() do
			notice:FireClient(player, survivorNotice)
		end
		if run.chaser then
			notice:FireClient(run.chaser, "PreparationChaser" :: Types.NoticeKey)
		end
		outcome = PhaseTimer.run("Preparation", Match.PreparationTime, shouldEnd)
	end

	-- 추격
	if outcome == "TimeUp" then
		setGateOpen(run, true)
		if run.chaser then
			fireParticipants(run, "Notice", "ChaserReleased" :: Types.NoticeKey)
		end
		outcome = PhaseTimer.run("Chase", stage.TimeLimit, shouldEnd)
		if outcome == "EndedEarly" then
			-- 마지막 생존자가 잡혔으면(혼자 하기 등) 잡힘 연출이 끝날 때까지 결과를 띄우지 않는다.
			task.wait(Match.CaughtEffectTime)
		end
	end

	-- 결과
	local result = recordResult(run, if outcome == "TimeUp" then "TimeUp" else "NoSurvivorsLeft")
	DataService.grantStage(result)
	AchievementService.onStageResult(result)
	fireParticipants(run, "StageResult", result)
	local anyoneLeft = false
	for _, player in run.participants do
		anyoneLeft = anyoneLeft or isInMatch(run, player)
	end
	if anyoneLeft then
		PhaseTimer.run("StageResult", Match.StageResultTime)
	end
	finish()
end

function StageService.Init(): () end

function StageService.Start(): () end

return StageService
