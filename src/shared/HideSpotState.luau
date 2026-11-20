--!strict
-- 숨는 곳(HideSpot 태그 Model)의 ProximityPrompt 이름, 공개 Attribute, 숨기·열어보기가 되는 단계를 정의한다 (GDD 6.1).
-- 쓰기는 서버 HideService만 한다. 숨어 있는 플레이어 쪽 Attribute(Hidden)는 MatchState에 있다.
--
-- 숨는 곳 Model의 Attribute
--   OccupantUserId  number?   숨어 있는 생존자의 UserId. 비어 있으면 nil (한 곳에 한 명)
--   Breathing       boolean?  숨소리 상태. 한 곳에 Config.MapObjects.HideSpot.BreathAfter초 이상 숨어 있음
--   Revealed        boolean?  숨소리 상태에서 추격자가 BreathRevealRadius 안에 와서 강조 표시(Highlight) 중
--
-- ProximityPrompt: PrimaryPart 앞면 바로 앞의 Attachment(PromptAttachmentName) 아래에 서버가 만든다.
-- 서버에서는 모두 켜 두고, 클라이언트가 자기 역할·상태에 맞는 것만 로컬에서 켠다.
--   HidePrompt    "숨기"      생존자, 비어 있는 곳 (SurvivorController)
--   UnhidePrompt  "나오기"    그곳에 숨은 생존자 (SurvivorController)
--   OpenPrompt    "열어보기"  추격자, ChaserOpenTime초 누르기 (ChaserController)

local Types = require(script.Parent.Types)

local Attribute = table.freeze({
	OccupantUserId = "OccupantUserId",
	Breathing = "Breathing",
	Revealed = "Revealed",
})

local Prompt = table.freeze({
	Hide = "HidePrompt",
	Unhide = "UnhidePrompt",
	Open = "OpenPrompt",
})

local HideSpotState = {
	Attribute = Attribute,
	Prompt = Prompt,
	PromptAttachmentName = "PromptAttachment",
}

function HideSpotState.getOccupantUserId(spot: Instance): number?
	local value = spot:GetAttribute(Attribute.OccupantUserId)
	if typeof(value) == "number" then
		return value
	end
	return nil
end

function HideSpotState.isBreathing(spot: Instance): boolean
	return spot:GetAttribute(Attribute.Breathing) == true
end

function HideSpotState.isRevealed(spot: Instance): boolean
	return spot:GetAttribute(Attribute.Revealed) == true
end

-- 생존자가 숨을 수 있는 단계: 준비(흩어져 숨을 곳 찾기)와 추격
function HideSpotState.canHideInPhase(phase: Types.MatchPhase): boolean
	return phase == "Preparation" or phase == "Chase"
end

-- 추격자가 열어볼 수 있는 단계: 추격 (준비 중에는 대기실에 갇혀 있음)
function HideSpotState.canOpenInPhase(phase: Types.MatchPhase): boolean
	return phase == "Chase"
end

return HideSpotState
