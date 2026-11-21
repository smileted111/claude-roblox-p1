--!strict
-- 클라이언트에 공개하는 매치 상태(Attribute)의 이름과 읽기 함수를 이 파일 한 곳에서 정의한다.
-- 쓰기는 서버만 한다 (MatchService, StageService, RoleService, MovementService, HideService, SpectateService,
-- VoteService, server/Util/PhaseTimer).
--
-- ReplicatedStorage의 Attribute (매치 전체)
--   Phase          Types.MatchPhase    현재 단계
--   PhaseEndsAt    number?             이 단계가 끝나는 서버 시각 (workspace:GetServerTimeNow() 기준). 끝이 정해지지 않으면 nil
--   TimeLeft       number?             남은 시간 (초, 올림한 정수). 1초마다 갱신. 끝이 정해지지 않으면 nil
--   StageId        Types.StageId?      진행 중인 스테이지(맵). 대기 중에는 nil
--   StageIndex     number?             이번 매치의 몇 번째 스테이지인가 (1부터, MatchService). 매치 밖에서는 nil
--   CameraCeiling  number?             스테이지 안 카메라 최대 높이 (월드 Y, StageService, Config.Camera). 맵이 없으면 nil
--   HasChaser      boolean?            이번 스테이지에 추격자가 있는가. 솔로이거나 추격자가 나가면 false
--   SurvivorsLeft  number?             아직 잡히거나 탈출하지 않은 생존자 수
--   GeneratorsDone  number?            다 고친 발전기 수 (ObjectiveService)
--   GeneratorsTotal number?            이번 스테이지 발전기 수. 스테이지 밖에서는 nil
--   ExitOpen       boolean?            출구가 열렸는가 (ObjectiveService)
--   QueueCount     number?             같이 하기 대기 인원 (LobbyService)
--   MatchMode      Types.VisualMode?   진행 중인 매치의 화면 모드 (MatchService, 첫 투표로 정함). 매치 밖에서는 nil
--   VoteMaps       string?             투표 중 고를 수 있는 맵 StageId를 쉼표로 이은 것 (VoteService). 투표 밖에서는 nil
--   VotePlayed     string?             이번 매치에서 이미 플레이해 고를 수 없는 맵 (쉼표, VoteService)
--   VoteMapCounts  string?             맵별 표 수 "Stage1:2,Stage4:1" (VoteService)
--   VoteModeCounts string?             화면 모드별 표 수 "Night:1,Casual:2". 모드를 투표하지 않는 스테이지는 nil
--   SoloServer     boolean?            혼자 하기 서버인가 (LobbyService)
--   MatchRunning   boolean?            매치 진행 중 (MatchService). 참가자가 아니면 로비에서 기다린다
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
--   FlashlightOn   boolean?                손전등을 켬 (ItemService)
--   FlashlightBattery number?              손전등 남은 배터리 0~1 (ItemService). 손전등이 없으면 nil
--   ChaserType     Types.ChaserId?         이번 스테이지 추격자 종류 (ChaserService). 추격자일 때만
--   SkillReadyAt   number?                 추격자 스킬을 다시 쓸 수 있는 서버 시각 (GetServerTimeNow 기준, ChaserService)
--   SelectedChaser Types.ChaserId?         로비에서 고른 추격자 (DataService에 저장)
--   UnlockedChasers string?                해금한 추격자 ChaserId를 쉼표로 이은 것 (DataService에 저장)
--   Coins, Level, Xp  number?              저장된 코인·레벨·경험치 (DataService). 데이터를 불러오기 전에는 nil
--   DataLoaded     boolean?                저장된 데이터를 불러옴 (DataService)
--   Vip            boolean?                게임패스 VIP를 가짐 (ShopService). 채팅 이름 색·로비 이모트·코인 +20%
--   VisualMode     Types.VisualMode?       로비에서 고른 화면 모드 (DataService에 저장, LobbyService가 바꿈).
--                                          로비 조명 미리보기, 모드 투표가 같거나 아무도 투표하지 않았을 때 쓴다
--   InMatch        boolean?                매치 참가자 (MatchService). 스테이지 사이 로비에 있을 때도 켜져 있다
--   Voter          boolean?                지금 투표에 참여할 수 있음 (VoteService)
--   VoteMap        Types.StageId?          내가 투표한 맵 (VoteService)
--   VoteMode       Types.VisualMode?       내가 투표한 화면 모드 (VoteService)

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
	QueueCount = "QueueCount",
	SoloServer = "SoloServer",
	MatchRunning = "MatchRunning",
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
	FlashlightOn = "FlashlightOn",
	FlashlightBattery = "FlashlightBattery",
	ChaserType = "ChaserType",
	SkillReadyAt = "SkillReadyAt",
	SelectedChaser = "SelectedChaser",
	UnlockedChasers = "UnlockedChasers",
	Coins = "Coins",
	Level = "Level",
	Xp = "Xp",
	DataLoaded = "DataLoaded",
	Vip = "Vip",
	MatchMode = "MatchMode",
	VisualMode = "VisualMode",
	StageIndex = "StageIndex",
	CameraCeiling = "CameraCeiling",
	VoteMaps = "VoteMaps",
	VotePlayed = "VotePlayed",
	VoteMapCounts = "VoteMapCounts",
	VoteModeCounts = "VoteModeCounts",
	InMatch = "InMatch",
	Voter = "Voter",
	VoteMap = "VoteMap",
	VoteMode = "VoteMode",
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

function MatchState.getQueueCount(): number
	return readNumber(ReplicatedStorage, Attribute.QueueCount) or 0
end

function MatchState.getStageIndex(): number?
	return readNumber(ReplicatedStorage, Attribute.StageIndex)
end

function MatchState.getCameraCeiling(): number?
	return readNumber(ReplicatedStorage, Attribute.CameraCeiling)
end

-- 쉼표로 이은 목록 (VoteMaps·VotePlayed) → 배열
local function readList(name: string): { string }
	local value = readString(ReplicatedStorage, name)
	if not value or value == "" then
		return {}
	end
	return string.split(value, ",")
end

-- "키:수,키:수" → { [키]: 수 }
local function readCounts(name: string): { [string]: number }
	local counts: { [string]: number } = {}
	for _, entry in readList(name) do
		local key, count = string.match(entry, "^([^:]+):(%d+)$")
		if key and count then
			counts[key] = tonumber(count) or 0
		end
	end
	return counts
end

-- 투표 중 고를 수 있는 맵 (투표 밖이면 빈 배열)
function MatchState.getVoteMaps(): { Types.StageId }
	return readList(Attribute.VoteMaps) :: { any }
end

-- 이번 매치에서 이미 플레이한 맵 (투표 중에만)
function MatchState.getVotePlayed(): { Types.StageId }
	return readList(Attribute.VotePlayed) :: { any }
end

function MatchState.getVoteMapCounts(): { [string]: number }
	return readCounts(Attribute.VoteMapCounts)
end

-- 화면 모드 표 수. 이번 투표에 모드가 없으면 nil
function MatchState.getVoteModeCounts(): { [string]: number }?
	if readString(ReplicatedStorage, Attribute.VoteModeCounts) == nil then
		return nil
	end
	return readCounts(Attribute.VoteModeCounts)
end

-- 목록 → 쉼표로 이은 글자 (서버가 쓸 때)
function MatchState.encodeList(list: { string }): string
	return table.concat(list, ",")
end

-- { 키 순서 }와 { [키]: 수 } → "키:수,키:수" (서버가 쓸 때)
function MatchState.encodeCounts(keys: { string }, counts: { [string]: number }): string
	local parts: { string } = {}
	for _, key in keys do
		table.insert(parts, `{key}:{counts[key] or 0}`)
	end
	return table.concat(parts, ",")
end

function MatchState.isInMatch(player: Player): boolean
	return player:GetAttribute(Attribute.InMatch) == true
end

function MatchState.isVoter(player: Player): boolean
	return player:GetAttribute(Attribute.Voter) == true
end

function MatchState.getVoteMap(player: Player): Types.StageId?
	return readString(player, Attribute.VoteMap) :: Types.StageId?
end

function MatchState.getVoteMode(player: Player): Types.VisualMode?
	return readString(player, Attribute.VoteMode) :: Types.VisualMode?
end

function MatchState.getMatchMode(): Types.VisualMode?
	return readString(ReplicatedStorage, Attribute.MatchMode) :: Types.VisualMode?
end

function MatchState.getVisualMode(player: Player): Types.VisualMode?
	return readString(player, Attribute.VisualMode) :: Types.VisualMode?
end

function MatchState.isSoloServer(): boolean
	return ReplicatedStorage:GetAttribute(Attribute.SoloServer) == true
end

function MatchState.isMatchRunning(): boolean
	return ReplicatedStorage:GetAttribute(Attribute.MatchRunning) == true
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

function MatchState.getChaserType(player: Player): Types.ChaserId?
	return readString(player, Attribute.ChaserType) :: Types.ChaserId?
end

function MatchState.getSkillReadyAt(player: Player): number?
	return readNumber(player, Attribute.SkillReadyAt)
end

function MatchState.getSelectedChaser(player: Player): Types.ChaserId?
	return readString(player, Attribute.SelectedChaser) :: Types.ChaserId?
end

function MatchState.isChaserUnlocked(player: Player, chaserId: Types.ChaserId): boolean
	local list = readString(player, Attribute.UnlockedChasers) or ""
	return table.find(string.split(list, ","), chaserId) ~= nil
end

function MatchState.getCoins(player: Player): number?
	return readNumber(player, Attribute.Coins)
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

function MatchState.isVip(player: Player): boolean
	return player:GetAttribute(Attribute.Vip) == true
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
