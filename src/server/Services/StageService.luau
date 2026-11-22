--!strict
-- StageService: 맵 불러오기, 스테이지 한 판 진행과 타이머 (GDD 3.1, 3.2, 5장, 13.2). 목표 장치·출구는 ObjectiveService.
--
-- 한 스테이지: 역할 공개 → 준비 → 추격 → 결과 (MatchService가 runStage로 부름)
--   역할 공개  Config.Match.RoleRevealTime   추격자를 뽑고(참가자 2명당 1명, RoleService) 룰렛 신호(RoleReveal)를
--                                            보냄. 솔로는 생략 (GDD 3.1)
--   (로딩)                                   맵을 불러와 참가자를 옮기는 동안 Loading = "Stage" (참가자 화면에 로딩 화면,
--                                            client LoadingController). 켠 뒤 Config.Loading.CoverTime초 기다려 화면이 다
--                                            덮은 다음 옮기고, 모두 옮기면(최대 Config.Loading.PlacementTimeout초) 끈다.
--                                            스테이지가 끝나 맵을 지울 때 Loading = "Lobby"를 켜고 (같이 CoverTime초 기다림)
--                                            MatchService가 로비에 다시 만든 뒤 끈다.
--   준비       Config.Match.PreparationTime  맵을 Workspace.CurrentMap에 복제한다. 매치 화면 모드가 캐주얼이면
--                                            맵 색을 파스텔로 바꾼다 (Util/MapStyler). 조명은 클라이언트(VisualModeController)가 바꾼다.
--                                            카메라 높이 제한(바닥 윗면 + Config.Camera.StageCeilingHeight)을 CameraCeiling으로 공개.
--                                            생존자는 SurvivorSpawn, 추격자는 전용 외형(ChaserService)으로 ChaserSpawn에 배치
--                                            (여럿이면 ChaserSpawn을 돌아가며, 한 자리에는 Config.MapObjects.ChaserSpawn.Spacing씩 벌려서).
--                                            ChaserGate는 닫아 둠. 숨는 곳(HideService)·발전기와 출구(ObjectiveService)·
--                                            아이템(ItemService)·판자와 문(BarrierService) 준비. 감옥(JailService)은
--                                            게임 모드가 경찰과 도둑일 때만 남기고 아니면 맵에서 지운다
--                                            괴물 생성(MonsterService)은 추격자가 없는 스테이지(솔로)에서만
--                                            (Config.Match.MonstersWithChasers = false, 2026-11-22 사용자 요청: 같이 하기는
--                                            플레이어끼리). 괴물이 없으면 손전등·알람시계 대신 붕대를 놓는다 (ItemService).
--                                            괴물은 추격 단계부터 움직인다
--   추격       Config.Stages[id].TimeLimit   ChaserGate를 엶
--   결과       Config.Match.StageResultTime  추격이 일찍 끝났으면(마지막 생존자가 잡힘 등) 잡힘 연출 시간
--                                            (Config.Match.CaughtEffectTime)을 기다린 뒤,
--                                            결과를 RecordService에 기록하고 코인·통계를 지급(DataService),
--                                            StageResult 리모트로 보냄.
--                                            끝나면 맵을 지우고 역할을 비움
--
-- 게임 모드 (2026-11-22 사용자 요청, Config.GameModes): 투표로 정한 모드를 추격자가 있는 스테이지에 쓴다
--   (ReplicatedStorage GameMode, 솔로는 nil). 경찰과 도둑이면 부상으로 맞은 도둑은 감옥에 갇힌다 (CatchService·JailService).
--   얼음땡이면 생존자가 얼고 서로 땡 해 준다 (FreezeService). 참가자 수가 그 모드의 Config.GameModes.MinPlayers보다 적으면
--   (투표 뒤 누가 나감) 그 스테이지는 Config.GameModes.Default로 한다.
-- 참가자: MatchService가 넘겨준 매치 참가자만 역할을 받는다. 로비에 있는 다른 사람은 상관없다.
--   신호(역할 공개·알림·결과)는 참가자에게만 보낸다. "로비로 돌아가기"로 빠진 참가자(leaveMatch)는 나간 것으로 본다.
-- 조기 종료: 서 있는 생존자가 없으면 (모두 잡힘·탈출·나감) 쓰러진 생존자를 모두 잡힘으로 바꾸고(CatchService.catchAllDowned,
--   살려줄 사람이 없으므로) 바로 결과로 간다 (GDD 3.2, 5장).
-- 추격자가 나가면(게임에서 나감·로비로 돌아감) 새로 뽑지 않는다. 남은 추격자로 계속하고, 모두 나가면 괴물이 있는
--   스테이지는 괴물만으로 계속하고(GDD 5장, 질문지 Q6-5), 괴물이 없는 스테이지(같이 하기)는 쓰러진 생존자를 일으키고
--   남은 생존자를 성공으로 바로 결과로 간다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Camera = require(ReplicatedStorage.Shared.Config.Camera)
local GameModes = require(ReplicatedStorage.Shared.Config.GameModes)
local Loading = require(ReplicatedStorage.Shared.Config.Loading)
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
local CatchService = require(script.Parent.CatchService)
local DataService = require(script.Parent.DataService)
local FreezeService = require(script.Parent.FreezeService)
local JailService = require(script.Parent.JailService)
local HideService = require(script.Parent.HideService)
local ItemService = require(script.Parent.ItemService)
local MonsterService = require(script.Parent.MonsterService)
local MovementService = require(script.Parent.MovementService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local RecordService = require(script.Parent.RecordService)
local RoleService = require(script.Parent.RoleService)

local MAPS_FOLDER = "Maps" -- ServerStorage.Maps
local CURRENT_MAP_NAME = "CurrentMap" -- Workspace.CurrentMap

type EndReason = "TimeUp" | "NoSurvivorsLeft" | "ChasersLeft"

type StageRun = {
	stageId: Types.StageId,
	participants: { Player }, -- 이 스테이지 참가자 (MatchService가 넘김)
	left: { [Player]: boolean }, -- 스테이지 중에 로비로 돌아간 참가자
	survivors: { Player }, -- 처음 생존자로 배정된 사람 (결과 기록용)
	chasers: { Player }, -- 아직 남은 추격자 (나가면 빠짐)
	originalChasers: { Player }, -- 처음 뽑힌 추격자 (결과 기록용)
	hadChaser: boolean,
	hasMonsters: boolean, -- 이번 스테이지에 괴물이 나오는가 (솔로, 또는 Config.Match.MonstersWithChasers)
	gameMode: Types.GameMode?, -- 추격자가 있는 스테이지의 게임 모드 (솔로면 nil)
	endReason: EndReason?, -- 조기 종료 이유 (updateAndCheckEnd가 정함)
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

-- 캐릭터를 시작 위치 Part의 윗면에 세운다. 방향은 Part의 방향을 따른다. sideOffset만큼 Part의 오른쪽으로 옮겨 세운다.
local function placeAt(player: Player, spawnPart: BasePart, sideOffset: number?): ()
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
	character:PivotTo(spawnPart.CFrame * CFrame.new(sideOffset or 0, standHeight, 0))
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

-- 같은 자리에 서는 순서(0부터)별 옆 거리: 0, +Spacing, -Spacing, +2Spacing, ...
local function sideOffsetFor(slot: number): number
	local step = (slot + 1) // 2
	local sign = if slot % 2 == 1 then 1 else -1
	return step * sign * MapObjects.ChaserSpawn.Spacing
end

-- 생존자는 서로 다른 SurvivorSpawn에 (자리가 모자라면 돌아가며), 추격자는 ChaserSpawn에 놓는다.
-- LoadCharacterAsync가 멈출 수 있어서 플레이어마다 따로 실행한다.
-- 모두 옮길 때까지(최대 Config.Loading.PlacementTimeout초) 기다린다 (로딩 화면을 그동안 띄움).
local function placeParticipants(run: StageRun, map: Instance): ()
	local pending = 0
	local function place(player: Player, spawnPart: BasePart, sideOffset: number?): ()
		pending += 1
		task.spawn(function()
			placeAt(player, spawnPart, sideOffset)
			pending -= 1
		end)
	end
	local survivorSpawns = shuffled(taggedParts(map, MapTags.SurvivorSpawn))
	local survivors = RoleService.getActiveSurvivors()
	for index, player in survivors do
		place(player, survivorSpawns[(index - 1) % #survivorSpawns + 1])
	end

	local chaserSpawns = shuffled(taggedParts(map, MapTags.ChaserSpawn))
	if #chaserSpawns > 0 then
		for index, chaser in run.chasers do
			local spawnPart = chaserSpawns[(index - 1) % #chaserSpawns + 1]
			local slot = (index - 1) // #chaserSpawns
			place(chaser, spawnPart, sideOffsetFor(slot))
		end
	end
	local deadline = os.clock() + Loading.PlacementTimeout
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
	print(
		`[Stage] 배치: 생존자 {#survivors}명 → {MapTags.SurvivorSpawn}`
			.. (if #run.chasers > 0 then `, 추격자 {names(run.chasers)} → {MapTags.ChaserSpawn}` else "")
			.. (if pending > 0 then ` (시간 안에 못 옮긴 사람 {pending}명)` else "")
	)
end

-- 단계 타이머가 Config.Match.PhaseTickInterval마다 부른다. 추격자 이탈을 처리하고 남은 생존자 수를 공개한다.
-- 스테이지를 일찍 끝내야 하면 run.endReason을 정하고 true.
local function updateAndCheckEnd(run: StageRun): boolean
	local hadAny = #run.chasers > 0
	for index = #run.chasers, 1, -1 do
		local chaser = run.chasers[index]
		if not isInMatch(run, chaser) then
			table.remove(run.chasers, index)
			print(`[Stage] 추격자 {chaser.Name} 이탈 (남은 추격자 {#run.chasers}명)`)
			if #run.chasers > 0 then
				fireParticipants(run, "Notice", "ChaserLeft" :: Types.NoticeKey, chaser.DisplayName)
			end
		end
	end
	if hadAny and #run.chasers == 0 then
		ReplicatedStorage:SetAttribute(Attribute.HasChaser, false)
		if run.hasMonsters then
			fireParticipants(run, "Notice", "AllChasersLeft" :: Types.NoticeKey)
			print("[Stage] 추격자가 모두 나감 → 이번 스테이지는 괴물만으로 계속")
		else
			fireParticipants(run, "Notice", "AllChasersLeftEnd" :: Types.NoticeKey)
			print(
				"[Stage] 추격자가 모두 나감 → 괴물이 없어 스테이지를 끝냄 (남은 생존자 성공)"
			)
			CatchService.standUpAllDowned()
			JailService.releaseAll()
			run.endReason = "ChasersLeft"
			return true
		end
	end

	local survivorsLeft = #RoleService.getActiveSurvivors()
	if survivorsLeft ~= MatchState.getSurvivorsLeft() then
		ReplicatedStorage:SetAttribute(Attribute.SurvivorsLeft, survivorsLeft)
		print(`[Stage] 남은 생존자 {survivorsLeft}명`)
	end
	if survivorsLeft == 0 then
		-- 서 있는 생존자가 없으면 쓰러진 사람을 살려줄 사람도 없다.
		local caught = CatchService.catchAllDowned("서 있는 생존자 없음")
		if caught > 0 then
			print(`[Stage] 쓰러진 생존자 {caught}명 잡힘 (살려줄 사람 없음)`)
		end
		run.endReason = "NoSurvivorsLeft"
		return true
	end
	return false
end

-- 플레이어별 결과를 정해 RecordService에 기록하고 출력 창에 남긴다 (GDD 3.2).
-- 생존자 성공: 탈출했거나 제한 시간이 끝날 때까지 잡히지 않음. 추격자 승리: 추격자가 남아 있고 성공한 생존자가 없음.
local function recordResult(run: StageRun, reason: EndReason): Types.StageResult
	local reasonText = if reason == "TimeUp"
		then "제한 시간 종료"
		elseif reason == "ChasersLeft" then "추격자가 모두 나감"
		else "남은 생존자 없음"
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
			elseif state == "Caught" or state == "Downed" or state == "Jailed" then
				-- 쓰러지거나 감옥에 갇힌 채 끝남: 살아나지·풀려나지 못했으므로 잡힘
				outcome = "Caught"
			elseif state == "Frozen" then
				-- 얼음땡: 시간이 끝나거나 술래가 모두 나갈 때 언 사람은 잡히지 않았으므로 생존. 모두 얼어 끝나면 술래 승리라 잡힘
				outcome = if reason == "NoSurvivorsLeft" then "Caught" else "Survived"
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
	for _, original in run.originalChasers do
		local outcome: Types.StageOutcome = if isInMatch(run, original) then "Chaser" else "Left"
		local entry: RecordService.StageEntry = { player = original, outcome = outcome }
		table.insert(entries, entry)
		table.insert(lines, `{original.Name}={outcome}`)
	end

	local chaserWon = #run.chasers > 0 and succeeded == 0
	local summary: string
	if not run.hadChaser then
		summary = `솔로 · 성공 {succeeded}/{#run.survivors}`
	elseif chaserWon then
		summary = `추격자 {names(run.chasers)} 승리`
	else
		summary = `생존자 성공 {succeeded}/{#run.survivors}`
	end
	print(`[Stage] 종료 ({reasonText}) · {summary} · {table.concat(lines, ", ")}`)
	return RecordService.finishStage(run.stageId, entries, run.originalChasers, chaserWon)
end

local function finish(): ()
	-- 맵을 지우고 로비에 다시 만들 때까지 참가자 화면에 로딩 화면 (MatchService가 다 만든 뒤 끈다).
	ReplicatedStorage:SetAttribute(Attribute.Loading, "Lobby" :: Types.LoadingKind)
	task.wait(Loading.CoverTime) -- 로딩 화면이 다 덮은 뒤에 맵을 지운다
	MonsterService.clear()
	CatchService.clearStage()
	JailService.clearMap()
	FreezeService.clearStage()
	ObjectiveService.clearMap()
	ItemService.clearMap()
	BarrierService.clearMap()
	HideService.clearMap()
	StageService.unloadMap()
	RoleService.clearAll()
	ReplicatedStorage:SetAttribute(Attribute.CameraCeiling, nil)
	ReplicatedStorage:SetAttribute(Attribute.StageId, nil)
	ReplicatedStorage:SetAttribute(Attribute.HasChaser, nil)
	ReplicatedStorage:SetAttribute(Attribute.GameMode, nil)
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
	-- 감옥에 갇힌 사람은 다시 감옥 안에
	if MatchState.getSurvivorState(player) == "Jailed" and JailService.placeInJail(player) then
		print(`[Stage] {player.Name} 다시 생성 (감옥)`)
		return
	end
	local spawnPart = run.map and spawnFor(run.map, role)
	if spawnPart then
		placeAt(player, spawnPart)
		-- 얼음땡에서 언 채 새로 생겼으면 그 자리에서 다시 얼린다
		FreezeService.relock(player)
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
-- chaserWishers: 투표 창에서 "추격자 희망"을 켠 참가자 (그중에서 먼저 무작위로 추격자, RoleService.pickChasers).
-- gameMode: 투표로 정한 게임 모드 (없으면 Config.GameModes.Default). 추격자가 없는 스테이지(솔로)에는 쓰지 않는다.
function StageService.runStage(
	stageId: Types.StageId,
	participants: { Player },
	chaserWishers: { Player }?,
	gameMode: Types.GameMode?
): ()
	assert(current == nil, "이미 스테이지가 진행 중입니다")
	local stage = Stages[stageId]
	local chasers, candidates = RoleService.pickChasers(participants, chaserWishers)
	RoleService.assignRoles(participants, chasers)
	local hadChaser = #chasers > 0
	local mode = gameMode or GameModes.Default
	if hadChaser and #participants < GameModes.MinPlayers[mode] then
		print(
			`[Stage] 게임 모드 {mode}는 {GameModes.MinPlayers[mode]}명부터라 참가자 {#participants}명으로는 {GameModes.Default}로 진행`
		)
		mode = GameModes.Default
	end

	local run: StageRun = {
		stageId = stageId,
		participants = table.clone(participants),
		left = {},
		survivors = RoleService.getActiveSurvivors(),
		chasers = table.clone(chasers),
		originalChasers = chasers,
		hadChaser = hadChaser,
		hasMonsters = not hadChaser or Match.MonstersWithChasers,
		gameMode = if hadChaser then mode else nil,
		endReason = nil,
		map = nil,
		gateClosedTransparency = {},
	}
	current = run
	RecordService.startStage()
	ReplicatedStorage:SetAttribute(Attribute.StageId, stageId)
	ReplicatedStorage:SetAttribute(Attribute.HasChaser, hadChaser)
	ReplicatedStorage:SetAttribute(Attribute.GameMode, run.gameMode)
	ReplicatedStorage:SetAttribute(Attribute.SurvivorsLeft, #run.survivors)

	print(
		`[Stage] 스테이지 {MatchState.getStageIndex() or 1} · 맵 {stage.Number} ({Strings.Stages[stageId]}) 시작 · 참가자 {#participants}명`
	)
	if hadChaser then
		local counts: { string } = {}
		for _, chaser in chasers do
			table.insert(counts, `{chaser.Name}({RoleService.getChaserCount(chaser)}번째)`)
		end
		print(
			`[Role] 추격자 {#chasers}명: {table.concat(counts, ", ")} · 생존자: {names(run.survivors)}`
				.. ` · 괴물 {if run.hasMonsters then "있음" else "없음"} · 게임 모드 {run.gameMode}`
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
	if hadChaser then
		local chaserIds: { number } = {}
		for _, chaser in chasers do
			table.insert(chaserIds, chaser.UserId)
		end
		local candidateIds: { number } = {}
		for _, player in candidates do
			table.insert(candidateIds, player.UserId)
		end
		fireParticipants(run, "RoleReveal", chaserIds, candidateIds)
		outcome = PhaseTimer.run("RoleReveal", Match.RoleRevealTime, shouldEnd)
	else
		print("[Stage] 솔로라 역할 공개를 건너뜀")
	end

	-- 준비: 생존자는 흩어지고 추격자는 대기실에 갇혀 있음
	if outcome == "TimeUp" then
		ReplicatedStorage:SetAttribute(Attribute.Loading, "Stage" :: Types.LoadingKind)
		task.wait(Loading.CoverTime) -- 로딩 화면이 다 덮은 뒤에 옮긴다
		local map = loadMap(stageId)
		run.map = map
		HideService.setupMap(map)
		ObjectiveService.setupMap(map, stageId)
		ItemService.setupMap(map, run.hasMonsters)
		BarrierService.setupMap(map)
		JailService.setupMap(map, run.gameMode == "CopsAndRobbers")
		if run.hasMonsters then
			MonsterService.spawnForStage(map, stageId, #run.survivors, run.hadChaser)
		else
			MonsterService.clear()
			print("[Stage] 같이 하기: 괴물 없음 (Config.Match.MonstersWithChasers = false)")
		end
		setGateOpen(run, false)
		placeParticipants(run, map)
		ReplicatedStorage:SetAttribute(Attribute.Loading, nil)
		local notice = Remotes.get("Notice")
		local survivorNotice: Types.NoticeKey = if #run.chasers > 0 then "PreparationSurvivor" else "PreparationSolo"
		for _, player in RoleService.getActiveSurvivors() do
			notice:FireClient(player, survivorNotice)
		end
		for _, chaser in run.chasers do
			notice:FireClient(chaser, "PreparationChaser" :: Types.NoticeKey)
		end
		outcome = PhaseTimer.run("Preparation", Match.PreparationTime, shouldEnd)
	end

	-- 추격
	if outcome == "TimeUp" then
		setGateOpen(run, true)
		if #run.chasers > 0 then
			fireParticipants(run, "Notice", "ChaserReleased" :: Types.NoticeKey)
		end
		outcome = PhaseTimer.run("Chase", stage.TimeLimit, shouldEnd)
		if outcome == "EndedEarly" then
			-- 마지막 생존자가 잡혔으면(혼자 하기 등) 잡힘 연출이 끝날 때까지 결과를 띄우지 않는다.
			task.wait(Match.CaughtEffectTime)
		end
	end

	-- 결과
	local result = recordResult(run, if outcome == "TimeUp" then "TimeUp" else run.endReason or "NoSurvivorsLeft")
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
