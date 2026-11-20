--!strict
-- StageService: 맵 불러오기, 스테이지 한 판 진행과 타이머 (GDD 3.1, 3.2, 5장, 13.2). 목표 장치·출구는 S2-2에서 추가한다.
--
-- 한 스테이지: 역할 공개 → 준비 → 추격 → 결과 (MatchService가 runStage로 부름)
--   역할 공개  Config.Match.RoleRevealTime   추격자를 뽑고 룰렛 신호(RoleReveal)를 보냄. 솔로는 생략 (GDD 3.1)
--   준비       Config.Match.PreparationTime  맵을 Workspace.CurrentMap에 복제하고 조명을 Config.Stages[id].Lighting으로.
--                                            생존자는 SurvivorSpawn, 추격자는 ChaserSpawn에 배치.
--                                            ChaserGate는 닫아 둠. 숨는 곳 준비(HideService)
--                                            괴물 생성(MonsterService). 괴물은 추격 단계부터 움직인다
--   추격       Config.Stages[id].TimeLimit   ChaserGate를 엶
--   결과       Config.Match.StageResultTime  결과를 출력 창에 남김. 끝나면 맵을 지우고 역할을 비우고,
--                                            조명을 대기 장소 값(Config.Lighting.Lobby)으로 되돌림
--
-- 조기 종료: 남은 생존자가 없으면 (모두 잡힘·탈출·나감) 바로 결과로 간다 (GDD 3.2, 5장).
-- 추격자가 나가면 새로 뽑지 않고 괴물만으로 계속한다 (GDD 5장, 질문지 Q6-5).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LightingConfig = require(ReplicatedStorage.Shared.Config.Lighting)
local MapObjects = require(ReplicatedStorage.Shared.Config.MapObjects)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local PhaseTimer = require(script.Parent.Parent.Util.PhaseTimer)
local HideService = require(script.Parent.HideService)
local MonsterService = require(script.Parent.MonsterService)
local RoleService = require(script.Parent.RoleService)

local MAPS_FOLDER = "Maps" -- ServerStorage.Maps
local CURRENT_MAP_NAME = "CurrentMap" -- Workspace.CurrentMap

type EndReason = "TimeUp" | "NoSurvivorsLeft"

type StageRun = {
	stageId: Types.StageId,
	survivors: { Player }, -- 처음 생존자로 배정된 사람 (결과 기록용)
	chaser: Player?, -- 추격자가 나가면 nil
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

-- 조명 값을 Lighting과 그 안의 Atmosphere에 적용한다. 서버에서 바꾸면 모든 클라이언트에 복제된다.
local function applyLighting(preset: LightingConfig.LightingPreset, label: string): ()
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.ExposureCompensation = preset.ExposureCompensation

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
	atmosphere.Density = preset.Atmosphere.Density
	atmosphere.Haze = preset.Atmosphere.Haze
	atmosphere.Color = preset.Atmosphere.Color
	atmosphere.Decay = preset.Atmosphere.Decay
	print(`[Stage] 조명: {label}`)
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
	map.Parent = Workspace
	print(`[Stage] 맵 불러옴: ServerStorage.{MAPS_FOLDER}.{mapName} → Workspace.{CURRENT_MAP_NAME}`)
	applyLighting(Stages[stageId].Lighting, stageId)
	return map
end

function StageService.unloadMap(): ()
	local map = Workspace:FindFirstChild(CURRENT_MAP_NAME)
	if map then
		map:Destroy()
		print(`[Stage] 맵 제거: Workspace.{CURRENT_MAP_NAME}`)
	end
end

-- 살아 있는 캐릭터를 돌려준다. 없거나 죽었으면 새로 만든다 (LoadCharacterAsync는 멈춤).
local function ensureCharacter(player: Player): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		player:LoadCharacterAsync()
		character = player.Character
	end
	return character
end

-- 캐릭터를 시작 위치 Part의 윗면에 세운다. 방향은 Part의 방향을 따른다.
local function placeAt(player: Player, spawnPart: BasePart): ()
	if not isInGame(player) then
		return
	end
	local character = ensureCharacter(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		warn(`[Stage] {player.Name}: 캐릭터가 없어 시작 위치로 옮기지 못했습니다`)
		return
	end
	local standHeight = spawnPart.Size.Y / 2 + humanoid.HipHeight + rootPart.Size.Y / 2
	character:PivotTo(spawnPart.CFrame * CFrame.new(0, standHeight, 0))
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
	if chaser and not isInGame(chaser) then
		run.chaser = nil
		ReplicatedStorage:SetAttribute(Attribute.HasChaser, false)
		Remotes.get("Notice"):FireAllClients("ChaserLeft" :: Types.NoticeKey)
		print(`[Stage] 추격자 {chaser.Name} 이탈 → 이번 스테이지는 괴물만으로 계속`)
	end

	local survivorsLeft = #RoleService.getActiveSurvivors()
	if survivorsLeft ~= MatchState.getSurvivorsLeft() then
		ReplicatedStorage:SetAttribute(Attribute.SurvivorsLeft, survivorsLeft)
		print(`[Stage] 남은 생존자 {survivorsLeft}명`)
	end
	return survivorsLeft == 0
end

local function logResult(run: StageRun, reason: EndReason): ()
	local reasonText = if reason == "TimeUp" then "제한 시간 종료" else "남은 생존자 없음"
	local lines: { string } = {}
	local succeeded = 0
	for _, player in run.survivors do
		local outcome: string
		if not isInGame(player) then
			outcome = "나감"
		else
			local state = MatchState.getSurvivorState(player)
			if state == "Escaped" then
				outcome = "탈출"
				succeeded += 1
			elseif state == "Caught" then
				outcome = "잡힘"
			else
				-- 시간이 끝날 때까지 잡히지 않음 (GDD 3.2)
				outcome = "생존"
				succeeded += 1
			end
		end
		table.insert(lines, `{player.Name}={outcome}`)
	end

	local summary: string
	if not run.hadChaser then
		summary = `솔로 · 성공 {succeeded}/{#run.survivors}`
	elseif run.chaser and succeeded == 0 then
		summary = `추격자 {run.chaser.Name} 승리`
	else
		summary = `생존자 성공 {succeeded}/{#run.survivors}`
	end
	print(`[Stage] 종료 ({reasonText}) · {summary} · {table.concat(lines, ", ")}`)
end

local function finish(): ()
	MonsterService.clear()
	HideService.clearMap()
	StageService.unloadMap()
	applyLighting(LightingConfig.Lobby, "대기 장소")
	RoleService.clearAll()
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

-- 죽은 플레이어를 다시 내보낸다. 스테이지 밖이면 대기 장소(Workspace의 SpawnLocation),
-- 스테이지 중이면 자기 역할의 시작 위치 (맵을 불러오기 전이면 대기 장소). 관전자는 내보내지 않는다.
function StageService.respawn(player: Player): ()
	if not isInGame(player) then
		return
	end
	local run = current
	if not run then
		player:LoadCharacterAsync()
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
		player:LoadCharacterAsync()
	end
	print(`[Stage] {player.Name} 다시 생성 ({role})`)
end

-- 스테이지 한 판을 진행한다. 결과 단계까지 끝나면 맵을 지우고 돌아온다.
-- 시작할 때 서버에 있는 모든 플레이어가 참가자다.
function StageService.runStage(stageId: Types.StageId): ()
	assert(current == nil, "이미 스테이지가 진행 중입니다")
	local stage = Stages[stageId]
	local participants = Players:GetPlayers()
	local chaser, candidates = RoleService.pickChaser(participants)
	RoleService.assignRoles(participants, chaser)

	local run: StageRun = {
		stageId = stageId,
		survivors = RoleService.getActiveSurvivors(),
		chaser = chaser,
		hadChaser = chaser ~= nil,
		map = nil,
		gateClosedTransparency = {},
	}
	current = run
	ReplicatedStorage:SetAttribute(Attribute.StageId, stageId)
	ReplicatedStorage:SetAttribute(Attribute.HasChaser, chaser ~= nil)
	ReplicatedStorage:SetAttribute(Attribute.SurvivorsLeft, #run.survivors)

	print(`[Stage] 스테이지 {stage.Number} ({Strings.Stages[stageId]}) 시작 · 참가자 {#participants}명`)
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
		Remotes.get("RoleReveal"):FireAllClients(chaser.UserId, candidateIds)
		outcome = PhaseTimer.run("RoleReveal", Match.RoleRevealTime, shouldEnd)
	else
		print("[Stage] 솔로라 역할 공개를 건너뜀")
	end

	-- 준비: 생존자는 흩어지고 추격자는 대기실에 갇혀 있음
	if outcome == "TimeUp" then
		local map = loadMap(stageId)
		run.map = map
		HideService.setupMap(map)
		MonsterService.spawnForStage(map, stageId, #run.survivors, run.hadChaser)
		setGateOpen(run, false)
		placeParticipants(run, map)
		local notice = Remotes.get("Notice")
		for _, player in RoleService.getActiveSurvivors() do
			notice:FireClient(player, "PreparationSurvivor" :: Types.NoticeKey)
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
			Remotes.get("Notice"):FireAllClients("ChaserReleased" :: Types.NoticeKey)
		end
		outcome = PhaseTimer.run("Chase", stage.TimeLimit, shouldEnd)
	end

	-- 결과
	logResult(run, if outcome == "TimeUp" then "TimeUp" else "NoSurvivorsLeft")
	if #Players:GetPlayers() > 0 then
		PhaseTimer.run("StageResult", Match.StageResultTime)
	end
	finish()
end

function StageService.Init(): () end

function StageService.Start(): ()
	-- 플레이스에 저장된 Lighting은 Studio에서 맵을 만들 때 쓰는 값이다. 서버가 시작하면 대기 장소 조명으로 바꾼다.
	applyLighting(LightingConfig.Lobby, "대기 장소")
end

return StageService
