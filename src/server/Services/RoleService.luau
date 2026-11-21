--!strict
-- RoleService: 추격자 선정, 역할 배정 (GDD 2.1, 5장, 13.2)
--
-- 역할과 생존자 상태는 Player Attribute(MatchState.Attribute.Role, SurvivorState)로 공개한다. 바꾸는 곳은 이 모듈뿐이다.
--
-- 추격자 선정 (GDD 2.1, 질문지 Q2-1·Q2-2·Q2-4)
--   - 참가자가 Config.Match.MinPlayersForChaser명 이상일 때만 1명을 뽑는다. 그보다 적으면 솔로 (추격자 없음).
--   - "추격자 안 하기"를 켜지 않은 사람이 후보. 모두 켰으면 전원이 후보.
--   - 후보 중 추격자를 덜 해본 사람이 우선, 같으면 무작위.
--   - 추격자 횟수는 한 매치(스테이지 3개) 동안 센다. MatchService가 매치를 시작할 때 resetChaserCounts()를 부른다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Types = require(ReplicatedStorage.Shared.Types)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local DataService = require(script.Parent.DataService)

local Attribute = MatchState.Attribute

local RoleService = {}

local random = Random.new()
local chaserCounts: { [Player]: number } = {}

-- 상태를 먼저 쓴다. Role 변경을 듣는 쪽(SpectateService: 잡혔으면 잡힘 연출 뒤에 관전 시작)이 새 상태를 읽게 하기 위해서다.
local function setRole(player: Player, role: Types.Role?, state: Types.SurvivorState?): ()
	player:SetAttribute(Attribute.SurvivorState, state)
	player:SetAttribute(Attribute.Role, role)
end

-- 이번 매치에서 추격자를 한 횟수
function RoleService.getChaserCount(player: Player): number
	return chaserCounts[player] or 0
end

function RoleService.resetChaserCounts(): ()
	table.clear(chaserCounts)
end

-- 참가자 중 추격자 1명을 뽑고 횟수를 1 올린다. 솔로면 nil.
-- 두 번째 값은 후보 목록이다 (역할 공개 룰렛에 보여줌).
function RoleService.pickChaser(participants: { Player }): (Player?, { Player })
	if #participants < Match.MinPlayersForChaser then
		return nil, {}
	end

	local candidates: { Player } = {}
	for _, player in participants do
		if not MatchState.isChaserOptOut(player) then
			table.insert(candidates, player)
		end
	end
	if #candidates == 0 then
		candidates = table.clone(participants)
	end

	local fewest = math.huge
	for _, player in candidates do
		fewest = math.min(fewest, RoleService.getChaserCount(player))
	end
	local finalists: { Player } = {}
	for _, player in candidates do
		if RoleService.getChaserCount(player) == fewest then
			table.insert(finalists, player)
		end
	end

	local chaser = finalists[random:NextInteger(1, #finalists)]
	chaserCounts[chaser] = RoleService.getChaserCount(chaser) + 1
	return chaser, candidates
end

-- 추격자는 Chaser, 나머지는 Survivor(Normal)로 정한다.
function RoleService.assignRoles(participants: { Player }, chaser: Player?): ()
	for _, player in participants do
		if player == chaser then
			setRole(player, "Chaser", nil)
		else
			setRole(player, "Survivor", "Normal")
		end
	end
end

-- 매치에서 빠진 사람 (로비로 돌아감): 역할을 지운다.
function RoleService.clearRole(player: Player): ()
	setRole(player, nil, nil)
end

-- 생존자 상태를 바꾼다 (CatchService·출구 처리에서 부름). 잡히거나 탈출하면 스테이지가 끝날 때까지 관전자가 된다.
function RoleService.setSurvivorState(player: Player, state: Types.SurvivorState): ()
	if MatchState.getSurvivorState(player) == nil then
		warn(
			`[Role] {player.Name}: 이번 스테이지의 생존자가 아니라 상태를 바꾸지 않습니다 ({state})`
		)
		return
	end
	local role: Types.Role = if state == "Caught" or state == "Escaped" then "Spectator" else "Survivor"
	setRole(player, role, state)
end

-- 아직 잡히거나 탈출하지 않은 생존자
function RoleService.getActiveSurvivors(): { Player }
	local survivors: { Player } = {}
	for _, player in Players:GetPlayers() do
		local state = MatchState.getSurvivorState(player)
		if MatchState.getRole(player) == "Survivor" and (state == "Normal" or state == "Injured") then
			table.insert(survivors, player)
		end
	end
	return survivors
end

-- 지금 추격자 역할인 플레이어 (0명 또는 Config.Match.ChaserCount명)
function RoleService.getChasers(): { Player }
	local chasers: { Player } = {}
	for _, player in Players:GetPlayers() do
		if MatchState.getRole(player) == "Chaser" then
			table.insert(chasers, player)
		end
	end
	return chasers
end

-- 스테이지가 끝나면 모든 역할을 지운다 (대기 중에는 역할 없음).
function RoleService.clearAll(): ()
	for _, player in Players:GetPlayers() do
		setRole(player, nil, nil)
	end
end

function RoleService.Init(): ()
	-- 지금은 추격자 1명만 지원한다 (GDD 2장, 질문지 Q2-1). 값을 바꾸면 선정 코드도 바꿔야 한다.
	assert(Match.ChaserCount == 1, "Config.Match.ChaserCount는 1이어야 합니다")
end

function RoleService.Start(): ()
	-- 관전자도 보낼 수 있다 (다음 스테이지부터 적용되는 설정, Remotes.isSpectatorAllowed).
	RemoteHandler.connect("SetChaserOptOut", function(player: Player, optOut: unknown)
		if typeof(optOut) ~= "boolean" then
			return
		end
		player:SetAttribute(Attribute.ChaserOptOut, if optOut then true else nil)
		DataService.setChaserOptOut(player, optOut)
		print(`[Role] {player.Name}: 추격자 안 하기 = {optOut} (저장)`)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		chaserCounts[player] = nil
	end)
end

return RoleService
