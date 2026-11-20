--!strict
-- MatchService: 매치 시작·종료, 스테이지 순서 (GDD 3장, 13.2)
--
-- 흐름: 대기 → 스테이지 한 판(StageService.runStage) → 다시 대기
--   대기: Config.Match.MinPlayers명 이상이면 LobbyWaitTime초 뒤 시작. 그 사이 인원이 모자라면 처음부터 다시 기다린다.
--   지금은 Config.Match.StageOrder의 첫 스테이지(Stage1)만 반복한다.
--   S2-1에서 StageOrder의 스테이지 3개를 차례로 진행하고 최종 결과(MatchResult)를 넣는다.
--
-- 캐릭터는 서버가 직접 만든다 (Players.CharacterAutoLoads = false).
--   스테이지 밖: 들어오거나 죽으면 대기 장소(Workspace의 SpawnLocation)에 만든다.
--   스테이지 중: 새로 들어온 사람은 다음 스테이지까지 관전자(캐릭터 없음).
--               죽은 참가자는 Players.RespawnTime 뒤 자기 역할의 시작 위치에 다시 만든다 (StageService.respawn).
--   스테이지가 끝나면 모두 대기 장소에 다시 만든다 (잡힌 사람도 돌아옴).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Match = require(ReplicatedStorage.Shared.Config.Match)
local Types = require(ReplicatedStorage.Shared.Types)
local PhaseTimer = require(script.Parent.Parent.Util.PhaseTimer)
local RoleService = require(script.Parent.RoleService)
local StageService = require(script.Parent.StageService)

local MatchService = {}

local function hasEnoughPlayers(): boolean
	return #Players:GetPlayers() >= Match.MinPlayers
end

local function spawnInLobby(player: Player): ()
	if player.Parent == Players then
		player:LoadCharacterAsync()
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

	if StageService.isRunning() then
		RoleService.setSpectator(player)
		print(`[Match] {player.Name} 입장 · 스테이지 진행 중이라 다음 스테이지까지 관전`)
	else
		print(`[Match] {player.Name} 입장 · 대기 장소`)
		if not player.Character then
			spawnInLobby(player)
		end
	end
end

local function waitForPlayers(): ()
	while true do
		if not hasEnoughPlayers() then
			PhaseTimer.set("Waiting", `플레이어 {Match.MinPlayers}명 이상 기다리는 중`)
			repeat
				task.wait(Match.PhaseTickInterval)
			until hasEnoughPlayers()
		end
		print(`[Match] 플레이어 {#Players:GetPlayers()}명 · {Match.LobbyWaitTime}초 뒤 스테이지 시작`)
		local outcome = PhaseTimer.run("Waiting", Match.LobbyWaitTime, function(): boolean
			return not hasEnoughPlayers()
		end)
		if outcome == "TimeUp" then
			return
		end
		print("[Match] 인원이 모자라 대기를 처음부터 다시 시작")
	end
end

local function runLoop(): ()
	-- 지금은 스테이지 1만 반복한다 (S2-1에서 StageOrder 전체로).
	local stageId: Types.StageId = Match.StageOrder[1]
	while true do
		waitForPlayers()
		-- 오류가 나도 루프는 계속 돈다. 처리기는 오류가 난 자리에서 불려서 traceback에 원래 위치가 남는다.
		local ok = xpcall(function(): ()
			StageService.runStage(stageId)
		end, function(message: unknown): ()
			warn(
				`[Match] 스테이지 진행 중 오류로 대기로 돌아갑니다: {debug.traceback(
					tostring(message)
				)}`
			)
		end)
		if not ok then
			StageService.cleanup()
		end
		for _, player in Players:GetPlayers() do
			task.spawn(spawnInLobby, player)
		end
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
		print(`[Match] {player.Name} 퇴장`)
	end)

	task.spawn(runLoop)
end

return MatchService
