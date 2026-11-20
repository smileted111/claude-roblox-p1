--!strict
-- 클라이언트에 공개하는 매치 상태(Attribute)의 이름과 읽기 함수를 이 파일 한 곳에서 정의한다.
-- 쓰기는 서버만 한다 (MatchService, StageService, RoleService, server/Util/PhaseTimer).
--
-- ReplicatedStorage의 Attribute (매치 전체)
--   Phase          Types.MatchPhase    현재 단계
--   PhaseEndsAt    number?             이 단계가 끝나는 서버 시각 (workspace:GetServerTimeNow() 기준). 끝이 정해지지 않으면 nil
--   TimeLeft       number?             남은 시간 (초, 올림한 정수). 1초마다 갱신. 끝이 정해지지 않으면 nil
--   StageId        Types.StageId?      진행 중인 스테이지. 대기 중에는 nil
--   HasChaser      boolean?            이번 스테이지에 추격자가 있는가. 솔로이거나 추격자가 나가면 false
--   SurvivorsLeft  number?             아직 잡히거나 탈출하지 않은 생존자 수
--
-- Player의 Attribute (플레이어별)
--   Role           Types.Role?             이번 스테이지의 역할. 대기 중에는 nil
--   SurvivorState  Types.SurvivorState?    생존자 상태. 이번 스테이지의 생존자(였던 사람)만 있음
--   ChaserOptOut   boolean?                "추격자 안 하기" 설정 (GDD 2.1)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)

local Attribute = table.freeze({
	Phase = "Phase",
	PhaseEndsAt = "PhaseEndsAt",
	TimeLeft = "TimeLeft",
	StageId = "StageId",
	HasChaser = "HasChaser",
	SurvivorsLeft = "SurvivorsLeft",
	Role = "Role",
	SurvivorState = "SurvivorState",
	ChaserOptOut = "ChaserOptOut",
})

local function readString(instance: Instance, name: string): string?
	local value = instance:GetAttribute(name)
	if typeof(value) == "string" then
		return value
	end
	return nil
end

local function readNumber(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return nil
end

local MatchState = {
	Attribute = Attribute,
}

function MatchState.getPhase(): Types.MatchPhase
	local phase = readString(ReplicatedStorage, Attribute.Phase) :: Types.MatchPhase?
	return phase or "Waiting"
end

function MatchState.getTimeLeft(): number?
	return readNumber(ReplicatedStorage, Attribute.TimeLeft)
end

function MatchState.getStageId(): Types.StageId?
	return readString(ReplicatedStorage, Attribute.StageId) :: Types.StageId?
end

function MatchState.hasChaser(): boolean
	return ReplicatedStorage:GetAttribute(Attribute.HasChaser) == true
end

function MatchState.getSurvivorsLeft(): number
	return readNumber(ReplicatedStorage, Attribute.SurvivorsLeft) or 0
end

function MatchState.getRole(player: Player): Types.Role?
	return readString(player, Attribute.Role) :: Types.Role?
end

function MatchState.getSurvivorState(player: Player): Types.SurvivorState?
	return readString(player, Attribute.SurvivorState) :: Types.SurvivorState?
end

function MatchState.isChaserOptOut(player: Player): boolean
	return player:GetAttribute(Attribute.ChaserOptOut) == true
end

return MatchState
