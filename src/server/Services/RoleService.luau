--!strict
-- RoleService: 추격자 선정, 역할 배정 (GDD 2.1, 5장, 13.2)
--
-- 역할과 생존자 상태는 Player Attribute(MatchState.Attribute.Role, SurvivorState)로 공개한다. 바꾸는 곳은 이 모듈뿐이다.
--
-- 추격자 선정 (GDD 2.1, 질문지 Q2-1·Q2-2·Q2-4)
--   - 참가자가 Config.Match.MinPlayersForChaser명 이상일 때만 뽑는다. 그보다 적으면 솔로 (추격자 없음).
--   - 인원: 참가자 Config.Match.PlayersPerChaser(2)명당 1명, 내림 (2026-11-22 사용자 요청. 2·3명 → 1, 4·5명 → 2, 8명 → 4).
--   - 투표 창에서 "추격자 희망"을 켠 참가자부터 무작위로 채운다. 모자라면 나머지에서 GDD 2.1 규칙으로 채운다:
--     "추격자 안 하기"를 켜지 않은 사람이 먼저(모자라면 켠 사람도), 그중 추격자를 덜 해본 사람이 우선, 같으면 무작위.
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

-- 참가자 수에 맞는 추격자 수 (솔로면 0)
function RoleService.chaserCountFor(participantCount: number): number
	if participantCount < Match.MinPlayersForChaser then
		return 0
	end
	return math.max(1, math.floor(participantCount / Match.PlayersPerChaser))
end

local function shuffled(list: { Player }): { Player }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- 참가자 중 추격자를 뽑고(chaserCountFor명) 각자 횟수를 1 올린다. 솔로면 빈 배열.
-- 두 번째 값은 역할 공개 룰렛에 돌릴 이름 목록이다 (참가자 모두).
-- wishers: 투표 창에서 "추격자 희망"을 켠 참가자 (VoteService, 2026-11-21 사용자 요청). 그중에서 먼저 무작위로 뽑고
--   ("추격자 안 하기"·횟수 규칙보다 먼저), 모자란 자리는 GDD 2.1 규칙으로 채운다.
function RoleService.pickChasers(participants: { Player }, wishers: { Player }?): ({ Player }, { Player })
	local count = RoleService.chaserCountFor(#participants)
	if count == 0 then
		return {}, {}
	end

	local chosen: { Player } = {}
	local wanting: { Player } = {}
	for _, player in wishers or {} do
		if table.find(participants, player) and player.Parent == Players then
			table.insert(wanting, player)
		end
	end
	for _, player in shuffled(wanting) do
		if #chosen < count then
			table.insert(chosen, player)
		end
	end
	local fromWishers = #chosen

	-- 남은 자리: "추격자 안 하기"를 켜지 않은 사람 먼저, 그다음 덜 해본 사람, 같으면 무작위 (섞은 뒤 안정 정렬 대신 순위 키)
	if #chosen < count then
		local rest: { Player } = {}
		for _, player in shuffled(participants) do
			if not table.find(chosen, player) then
				table.insert(rest, player)
			end
		end
		local order: { [Player]: number } = {}
		for index, player in rest do
			order[player] = index
		end
		table.sort(rest, function(a: Player, b: Player): boolean
			local aOut, bOut = MatchState.isChaserOptOut(a), MatchState.isChaserOptOut(b)
			if aOut ~= bOut then
				return bOut
			end
			local aCount, bCount = RoleService.getChaserCount(a), RoleService.getChaserCount(b)
			if aCount ~= bCount then
				return aCount < bCount
			end
			return order[a] < order[b]
		end)
		for _, player in rest do
			if #chosen < count then
				table.insert(chosen, player)
			end
		end
	end

	for _, chaser in chosen do
		chaserCounts[chaser] = RoleService.getChaserCount(chaser) + 1
	end
	if fromWishers > 0 then
		print(`[Role] 추격자 {count}명 중 {fromWishers}명을 희망자 {#wanting}명에서 무작위로 뽑음`)
	end
	return chosen, table.clone(participants)
end

-- 추격자는 Chaser, 나머지는 Survivor(Normal)로 정한다.
function RoleService.assignRoles(participants: { Player }, chasers: { Player }): ()
	for _, player in participants do
		if table.find(chasers, player) then
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
-- 쓰러짐(Downed)은 생존자 역할 그대로 둔다 (동료가 살릴 수 있음).
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

-- 아직 잡히거나 탈출하지 않고 서 있는 생존자 (쓰러진 생존자는 빠진다)
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

-- 지금 추격자 역할인 플레이어 (솔로면 0명)
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
	assert(Match.PlayersPerChaser >= 1, "Config.Match.PlayersPerChaser는 1 이상이어야 합니다")
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
