--!strict
-- 추격자 공격과 아군 치료가 되는 단계, 치료 프롬프트의 이름·태그를 정의한다 (GDD 2.2, 7장).
-- 서버(CatchService)와 클라이언트(ChaserController, SurvivorController)가 같은 규칙을 쓰게 하기 위해서다.
--
-- 치료 프롬프트: 부상 상태 생존자의 HumanoidRootPart 아래에 서버가 만들고(HealPromptName), 태그(HealPromptTag)를 붙인다.
-- 숨어 있거나 부상이 아니게 되면 서버가 지운다. 서버에서는 켜 두고, 클라이언트가 자기가 치료할 수 있을 때만 로컬에서 켠다.
-- 살리기 프롬프트 (2026-11-22 사용자 요청): 쓰러진 생존자의 HumanoidRootPart 아래에 서버가 만든다 (RevivePromptName·Tag).
-- 살리거나 잡히면 서버가 지운다. 클라이언트는 자기가 붕대를 가진, 서 있는 생존자일 때만 로컬에서 켠다.

local Types = require(script.Parent.Types)

local CatchState = {
	HealPromptName = "HealPrompt",
	HealPromptTag = "HealPrompt",
	RevivePromptName = "RevivePrompt",
	RevivePromptTag = "RevivePrompt",
	ReviveItem = "Bandage" :: Types.ItemId, -- 살릴 때 쓰는 아이템 (사용자 요청: 붕대)
}

-- 생존자가 맞을 수 있는(추격자·괴물이 공격할 수 있는) 단계: 추격.
-- 준비 중에는 추격자가 대기실에 갇혀 있고 괴물도 움직이지 않으며, 결과 단계에서는 판정이 끝났다.
function CatchState.canHitInPhase(phase: Types.MatchPhase): boolean
	return phase == "Chase"
end

-- 생존자가 아군을 치료할 수 있는 단계: 추격 (부상은 추격 단계에만 생김)
function CatchState.canHealInPhase(phase: Types.MatchPhase): boolean
	return phase == "Chase"
end

-- 쓰러진 동료를 살릴 수 있는 단계: 추격 (쓰러짐은 추격 단계에만 생김)
function CatchState.canReviveInPhase(phase: Types.MatchPhase): boolean
	return phase == "Chase"
end

return CatchState
