--!strict
-- MatchService: 매치 시작·종료, 스테이지 순서, 참가자 (GDD 3장, 5장, 8장, 13.2)
--
-- 흐름: 대기 → 매치(투표 → 스테이지를 Config.Match.StagesPerMatch번) → 최종 결과 → 다시 대기 (GDD 3장)
--   대기 (일반 서버): 로비의 같이 하기 구역에 선 사람(LobbyService.getQueue)이 MinTogetherPlayers명 이상이면
--         LobbyWaitTime초 뒤 그때 구역에 있는 사람들로 시작한다. 그 사이 인원이 모자라면 다시 기다린다.
--         구역에 혼자 SoloOfferWaitTime초 있으면 혼자 하기를 제안한다 (LobbyService.offerSolo, GDD 5장).
--         Studio에서 혼자 하기를 고르면 이 서버에서 그 사람 혼자 매치를 시작한다 (예약 서버로 보낼 수 없어서).
--   대기 (혼자 하기 서버): 들어온 사람 혼자 SoloStartDelay초 뒤 시작한다. 매치가 끝나면 다시 시작한다.
--   매치: 참가자만 진행한다 (Player Attribute InMatch). 시작할 때 추격자 횟수(RoleService)와 매치 기록(RecordService)을
--         새로 시작하고, 스테이지마다 맵 투표(VoteService, Config.Match.VoteTime초) 뒤 StageService.runStage(맵, 참가자)를 부른다.
--         투표할 수 있는 맵은 Config.Match.MapPool 중 이번 매치에서 아직 플레이하지 않은 것 (2026-11-21 사용자 요청).
--         추격자는 스테이지마다 새로 뽑고, 잡혔던 사람도 다음 스테이지에 돌아온다.
--         스테이지 사이에는 참가자를 로비에 다시 만든다. 참가자가 모두 빠지거나 오류가 나면 매치를 그만두고 대기로.
--         "로비로 돌아가기"(ReturnToLobby 리모트): 참가자에서 빠져 로비로 간다. 그때까지 받은 보상은 남는다 (GDD 8장).
--         혼자 하기 서버에서는 일반 서버로 보낸다.
--   매치 중에 들어온 사람은 로비에서 다음 매치를 기다린다 (Notice MatchInProgress).
--   화면 모드: 첫 스테이지 투표에서 맵과 함께 정해(VoteService) MatchMode로 공개하고 알린다.
--         매치 동안 바뀌지 않는다. 스테이지 맵 색(StageService)·괴물 꾸미기(MonsterService)·조명(클라이언트)이 따른다.
--   최종 결과: 라스트 서바이버(또는 베스트 서바이버)와 기록을 참가자에게 MatchResult 리모트로 보내고
--         MatchResultTime초 보여준 뒤 대기로 돌아간다. 칭호 보너스 지급은 DataService.
-- 공개: ReplicatedStorage Attribute MatchRunning·MatchMode·StageIndex, Player Attribute InMatch (MatchState)
--
-- 캐릭터는 서버가 직접 만든다 (Players.CharacterAutoLoads = false).
--   로비(Workspace.Lobby의 SpawnLocation)에 만들고, 참가자는 준비 단계에 맵 시작 위치로 옮긴다 (StageService).
--   죽으면 Players.RespawnTime 뒤 StageService.respawn (참가자는 자기 역할의 시작 위치, 아니면 로비).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Match = require(ReplicatedStorage.Shared.Config.Match)
local VisualModes = require(ReplicatedStorage.Shared.Config.VisualModes)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterLoader = require(script.Parent.Parent.Util.CharacterLoader)
local PhaseTimer = require(script.Parent.Parent.Util.PhaseTimer)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local AchievementService = require(script.Parent.AchievementService)
local DataService = require(script.Parent.DataService)
local LanguageService = require(script.Parent.LanguageService)
local LobbyService = require(script.Parent.LobbyService)
local RecordService = require(script.Parent.RecordService)
local RoleService = require(script.Parent.RoleService)
local StageService = require(script.Parent.StageService)
local VoteService = require(script.Parent.VoteService)

local Attribute = MatchState.Attribute

local MatchService = {}

local participants: { [Player]: boolean } = {}

local function spawnInLobby(player: Player): ()
	CharacterLoader.load(player, nil, "로비")
end

-- 스테이지 사이에 참가자를 로비에 다시 만들고, 모두 끝날 때까지(최대 LobbyRespawnTimeout초) 기다린다.
-- 기다리지 않으면 혼자 하기(역할 공개 없이 바로 배치)에서 다음 스테이지 배치가 옛 캐릭터를 옮긴 뒤
-- 새 캐릭터가 로비에 생겨 생존자가 로비에 남는다.
local function respawnAllInLobby(players: { Player }): ()
	local pending = #players
	for _, player in players do
		task.spawn(function()
			spawnInLobby(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + Match.LobbyRespawnTimeout
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end

-- 캐릭터가 죽으면 RespawnTime 뒤 상황에 맞는 곳에 다시 만든다.
local function watchCharacter(player: Player, character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	if not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Once(function()
		task.wait(Players.RespawnTime)
		-- 그 사이 다른 이유로 새 캐릭터가 생겼으면 (스테이지 배치, 대기 장소 복귀) 그대로 둔다.
		if player.Character == character then
			StageService.respawn(player)
		end
	end)
end

local function onPlayerAdded(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	if MatchState.isMatchRunning() then
		Remotes.get("Notice"):FireClient(player, "MatchInProgress" :: Types.NoticeKey)
		print(`[Match] {player.Name} 입장 · 매치 진행 중이라 로비에서 대기`)
	else
		print(`[Match] {player.Name} 입장 · 로비`)
	end
	if not player.Character then
		spawnInLobby(player)
	end
end

-- 매치에 참가할 사람들이 정해질 때까지 기다린다.
local function waitForParticipants(): { Player }
	PhaseTimer.set("Waiting", "같이 하기 대기")
	local alonePlayer: Player? = nil
	local aloneSince = 0
	while true do
		local studioSolo = LobbyService.takeStudioSoloRequest()
		if studioSolo then
			LobbyService.publishQueue({})
			return { studioSolo }
		end

		local solo = LobbyService.isSoloServer()
		local needed = if solo then Match.MinPlayers else Match.MinTogetherPlayers
		local queue = LobbyService.getQueue()
		LobbyService.publishQueue(queue)
		if #queue >= needed then
			local delay = if solo then Match.SoloStartDelay else Match.LobbyWaitTime
			print(`[Match] 같이 하기 {#queue}명 · {delay}초 뒤 매치 시작`)
			local outcome = PhaseTimer.run("Waiting", delay, function(): boolean
				local current = LobbyService.getQueue()
				LobbyService.publishQueue(current)
				return #current < needed
			end)
			local final = LobbyService.getQueue()
			if outcome == "TimeUp" and #final >= needed then
				LobbyService.publishQueue({})
				return final
			end
			print("[Match] 인원이 모자라 대기를 다시 시작")
			PhaseTimer.set("Waiting", "같이 하기 대기")
			alonePlayer = nil
		elseif #queue == 1 and not solo then
			-- 혼자 오래 기다리면 혼자 하기를 제안한다 (거절하면 SoloOfferWaitTime 뒤 다시).
			local player = queue[1]
			local now = os.clock()
			if player ~= alonePlayer then
				alonePlayer = player
				aloneSince = now
			elseif now - aloneSince >= Match.SoloOfferWaitTime then
				LobbyService.offerSolo(player, math.floor(now - aloneSince))
				aloneSince = now
			end
		else
			if alonePlayer then
				LobbyService.clearOffer(alonePlayer)
			end
			alonePlayer = nil
		end
		task.wait(Match.PhaseTickInterval)
	end
end

-- 아직 매치에 남은 참가자 (UserId순)
local function activeParticipants(): { Player }
	local list: { Player } = {}
	for player in participants do
		if player.Parent == Players then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId
	end)
	return list
end

-- 스테이지 한 판. 오류가 나면 false. 처리기는 오류가 난 자리에서 불려서 traceback에 원래 위치가 남는다.
local function runStageSafely(stageId: Types.StageId, players: { Player }): boolean
	local ok = xpcall(function(): ()
		StageService.runStage(stageId, players)
	end, function(message: unknown): ()
		warn(
			`[Match] 스테이지 진행 중 오류로 매치를 그만둡니다: {debug.traceback(tostring(message))}`
		)
	end)
	if not ok then
		StageService.cleanup()
	end
	return ok
end

local function logMatchResult(result: Types.MatchResult): ()
	local lines: { string } = {}
	for _, record in result.players do
		table.insert(
			lines,
			`{record.name}[{table.concat(record.stages, "/")}] 점수 {record.score}`
				.. (if record.lastSurvivor then " ★라스트 서바이버" else "")
		)
	end
	local title = if #result.lastSurvivorUserIds > 0
		then `라스트 서바이버 {#result.lastSurvivorUserIds}명`
		elseif result.bestSurvivorUserId then `베스트 서바이버 {result.bestSurvivorUserId}`
		else "칭호 없음"
	print(`[Match] 최종 결과 · {title} · {table.concat(lines, ", ")}`)
end

-- 참가자 표시를 지운다 (매치가 끝나거나 참가자가 빠질 때).
local function leaveParticipants(): ()
	for player in participants do
		player:SetAttribute(Attribute.InMatch, nil)
	end
	table.clear(participants)
end

-- 맵(첫 스테이지는 화면 모드도)을 투표로 정한다. 첫 스테이지면 화면 모드를 공개하고 알린다.
local function voteStage(index: number, active: { Player }, played: { Types.StageId }): Types.StageId?
	local available: { Types.StageId } = {}
	for _, stageId in Match.MapPool do
		if not table.find(played, stageId) then
			table.insert(available, stageId)
		end
	end
	if #available == 0 then
		return nil
	end
	local withMode = index == 1
	local stageId, mode = VoteService.run(active, available, played, withMode)
	local notice = Remotes.get("Notice")
	local voters = activeParticipants()
	if withMode then
		local matchMode = mode or VisualModes.Default
		ReplicatedStorage:SetAttribute(Attribute.MatchMode, matchMode)
		for _, player in voters do
			notice:FireClient(
				player,
				"MatchMode" :: Types.NoticeKey,
				LanguageService.stringsFor(player).Modes[matchMode]
			)
		end
	end
	for _, player in voters do
		notice:FireClient(player, "NextMap" :: Types.NoticeKey, LanguageService.stringsFor(player).Stages[stageId])
	end
	return stageId
end

local function playStages(): ()
	local played: { Types.StageId } = {}
	for index = 1, Match.StagesPerMatch do
		local active = activeParticipants()
		if #active == 0 then
			print("[Match] 참가자가 모두 빠져 매치를 그만둠")
			RecordService.abortMatch()
			return
		end
		local stageId = voteStage(index, active, played)
		if not stageId then
			print("[Match] 투표할 맵이 남지 않아 스테이지를 더 하지 않음")
			break
		end
		active = activeParticipants()
		if #active == 0 then
			print("[Match] 참가자가 모두 빠져 매치를 그만둠")
			RecordService.abortMatch()
			return
		end
		table.insert(played, stageId)
		ReplicatedStorage:SetAttribute(Attribute.StageIndex, index)
		print(`[Match] 스테이지 {index}/{Match.StagesPerMatch} · {stageId} · 참가자 {#active}명`)
		if not runStageSafely(stageId, active) then
			RecordService.abortMatch()
			return
		end
		-- 잡혀서 캐릭터가 없는 사람도 다음 스테이지 전에 로비로 돌아온다.
		respawnAllInLobby(activeParticipants())
	end
	ReplicatedStorage:SetAttribute(Attribute.StageIndex, nil)

	local result = RecordService.finishMatch()
	if not result then
		return
	end
	DataService.grantMatch(result)
	AchievementService.onMatchResult(result)
	local active = activeParticipants()
	-- 최종 결과 화면의 "다시 하기"(같이 하기 구역으로)가 되도록 참가자 표시를 먼저 지운다.
	leaveParticipants()
	if #active > 0 then
		logMatchResult(result)
		local remote = Remotes.get("MatchResult")
		for _, player in active do
			remote:FireClient(player, result)
		end
		PhaseTimer.run("MatchResult", Match.MatchResultTime)
	end
end

local function runMatch(players: { Player }): ()
	leaveParticipants()
	local names: { string } = {}
	for _, player in players do
		participants[player] = true
		player:SetAttribute(Attribute.InMatch, true)
		table.insert(names, player.Name)
	end
	ReplicatedStorage:SetAttribute(Attribute.MatchRunning, true)
	RoleService.resetChaserCounts()
	RecordService.startMatch(Match.StagesPerMatch)
	print(
		`[Match] 매치 시작 · 참가자 {table.concat(names, ", ")} · 스테이지 {Match.StagesPerMatch}개 (맵 {table.concat(
			Match.MapPool,
			", "
		)} 중 투표)`
	)
	playStages()
	leaveParticipants()
	ReplicatedStorage:SetAttribute(Attribute.StageIndex, nil)
	ReplicatedStorage:SetAttribute(Attribute.MatchRunning, nil)
	ReplicatedStorage:SetAttribute(Attribute.MatchMode, nil)
end

-- 참가자가 매치에서 빠져 로비로 간다 (관전 화면의 "로비로 돌아가기").
local function onReturnToLobby(player: Player): ()
	if LobbyService.isSoloServer() then
		LobbyService.teleportToPublic(player)
		return
	end
	if not participants[player] then
		return
	end
	participants[player] = nil
	player:SetAttribute(Attribute.InMatch, nil)
	StageService.leaveMatch(player)
	task.spawn(spawnInLobby, player)
	print(`[Match] {player.Name} 로비로 돌아감 (매치에서 빠짐)`)
end

local function runLoop(): ()
	while true do
		runMatch(waitForParticipants())
	end
end

function MatchService.Init(): ()
	-- 들어올 때·죽었을 때·스테이지가 바뀔 때 캐릭터를 서버가 직접 만든다.
	Players.CharacterAutoLoads = false
end

function MatchService.Start(): ()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		participants[player] = nil
		print(`[Match] {player.Name} 퇴장`)
	end)
	RemoteHandler.connect("ReturnToLobby", function(player: Player)
		onReturnToLobby(player)
	end)

	task.spawn(runLoop)
end

return MatchService
