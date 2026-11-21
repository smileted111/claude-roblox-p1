--!strict
-- 클라이언트에 공개하는 매치 상태(Attribute)의 이름과 읽기 함수를 이 파일 한 곳에서 정의한다.
-- 쓰기는 서버만 한다 (MatchService, StageService, RoleService, MovementService, HideService, SpectateService,
-- server/Util/PhaseTimer).
--
-- ReplicatedStorage의 Attribute (매치 전체)
--   Phase          Types.MatchPhase    현재 단계
--   PhaseEndsAt    number?             이 단계가 끝나는 서버 시각 (workspace:GetServerTimeNow() 기준). 끝이 정해지지 않으면 nil
--   TimeLeft       number?             남은 시간 (초, 올림한 정수). 1초마다 갱신. 끝이 정해지지 않으면 nil
--   StageId        Types.StageId?      진행 중인 스테이지. 대기 중에는 nil
--   HasChaser      boolean?            이번 스테이지에 추격자가 있는가. 솔로이거나 추격자가 나가면 false
--   SurvivorsLeft  number?             아직 잡히거나 탈출하지 않은 생존자 수
--   GeneratorsDone  number?            다 고친 발전기 수 (ObjectiveService)
--   GeneratorsTotal number?            이번 스테이지 발전기 수. 스테이지 밖에서는 nil
--   ExitOpen       boolean?            출구가 열렸는가 (ObjectiveService)
--
-- Player의 Attribute (플레이어별)
--   Role           Types.Role?             이번 스테이지의 역할. 대기 중에는 nil
--   SurvivorState  Types.SurvivorState?    생존자 상태. 이번 스테이지의 생존자(였던 사람)만 있음
--   ChaserOptOut   boolean?                "추격자 안 하기" 설정 (GDD 2.1)
--   Stamina        number?                 스태미나 (0 ~ Config.Survivor.Stamina.Max, 정수로 반올림) (MovementService)
--   Running        boolean?                지금 달리는 중인가 (MovementService)
--   Hidden         boolean?                숨는 곳에 숨어 있는가 (HideService). 어디에 숨었는지는 HideSpotState
--   Spectating     boolean?                관전 화면을 보는 중 (SpectateService). 잡힘 연출이 끝난 뒤부터 스테이지가 끝날 때까지
--   SpectateTarget number?                 관전 대상의 UserId (SpectateService). 관전 중이라도 볼 대상이 없으면 nil
--   RepairProgress number?                 지금 고치는 발전기의 진행 0~1 (ObjectiveService). 고치는 중이 아니면 nil
--   Item1, Item2   Types.ItemId?           아이템 칸 (ItemService). 비면 nil
--   Stunned        boolean?                기절 중 (판자에 맞은 추격자, MovementService). 움직이지도 공격하지도 못함

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)

local Attribute = table.freeze({
	Phase = "Phase",
	PhaseEndsAt = "PhaseEndsAt",
	TimeLeft = "TimeLeft",
	StageId = "StageId",
	HasChaser = "HasChaser",
	SurvivorsLeft = "SurvivorsLeft",
	GeneratorsDone = "GeneratorsDone",
	GeneratorsTotal = "GeneratorsTotal",
	ExitOpen = "ExitOpen",
	Role = "Role",
	SurvivorState = "SurvivorState",
	ChaserOptOut = "ChaserOptOut",
	Stamina = "Stamina",
	Running = "Running",
	Hidden = "Hidden",
	Spectating = "Spectating",
	SpectateTarget = "SpectateTarget",
	RepairProgress = "RepairProgress",
	Item1 = "Item1",
	Item2 = "Item2",
	Stunned = "Stunned",
})

-- 아이템 칸 번호 → Attribute 이름 (칸 수는 Config.Survivor.InventorySlots)
local ITEM_SLOT_ATTRIBUTES = { Attribute.Item1, Attribute.Item2 }

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

-- 다 고친 발전기 수와 전체 수. 스테이지 밖이면 전체가 nil
function MatchState.getGenerators(): (number, number?)
	return readNumber(ReplicatedStorage, Attribute.GeneratorsDone) or 0,
		readNumber(ReplicatedStorage, Attribute.GeneratorsTotal)
end

function MatchState.isExitOpen(): boolean
	return ReplicatedStorage:GetAttribute(Attribute.ExitOpen) == true
end

function MatchState.getRepairProgress(player: Player): number?
	return readNumber(player, Attribute.RepairProgress)
end

function MatchState.getItemSlotAttribute(slot: number): string?
	return ITEM_SLOT_ATTRIBUTES[slot]
end

function MatchState.getItem(player: Player, slot: number): Types.ItemId?
	local name = ITEM_SLOT_ATTRIBUTES[slot]
	return if name then readString(player, name) :: Types.ItemId? else nil
end

function MatchState.isStunned(player: Player): boolean
	return player:GetAttribute(Attribute.Stunned) == true
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

function MatchState.getStamina(player: Player): number?
	return readNumber(player, Attribute.Stamina)
end

function MatchState.isRunning(player: Player): boolean
	return player:GetAttribute(Attribute.Running) == true
end

function MatchState.isHidden(player: Player): boolean
	return player:GetAttribute(Attribute.Hidden) == true
end

function MatchState.isSpectating(player: Player): boolean
	return player:GetAttribute(Attribute.Spectating) == true
end

function MatchState.getSpectateTargetUserId(player: Player): number?
	return readNumber(player, Attribute.SpectateTarget)
end

return MatchState
