--!strict
-- 아이템(GDD 6.3)과 환경 장치(판자·문, GDD 6.4)의 프롬프트 태그·Attribute 이름, 쓸 수 있는 단계를 정의한다.
-- 쓰기는 서버 ItemService(아이템)·BarrierService(판자·문)만 한다. 플레이어 아이템 칸(Item1·Item2)은 MatchState에 있다.
--
-- 맵에 놓인 아이템: Workspace.CurrentMap 아래 Part. Attribute ItemId, 프롬프트 태그 PickupPromptTag ("줍기")
-- 연막 구역: 서버가 만든 투명 Part (태그 SmokeZoneTag, Attribute Radius). 그 안의 생존자는 괴물·추격자에게 보이지 않는다
-- 판자 (Plank 태그 Model): 프롬프트 태그 PlankPromptTag ("넘어뜨리기"), 넘어지면 Attribute Fallen
-- 문 (Door 태그 Model): 프롬프트 태그 DoorPromptTag ("열기"·"닫기"), 열려 있으면 Attribute Open

local Types = require(script.Parent.Types)

local ItemState = {
	PickupPromptTag = "ItemPickupPrompt",
	SmokeZoneTag = "SmokeZone",
	PlankPromptTag = "PlankPrompt",
	DoorPromptTag = "DoorPrompt",
	Attribute = table.freeze({
		ItemId = "ItemId",
		Radius = "Radius",
		Fallen = "Fallen",
		Open = "Open",
	}),
	-- 판자·문 Model 안의 파트 이름 (CLAUDE.md 맵 규칙)
	PlankBoardName = "Board",
	PlankFallenPoseName = "FallenPose",
	DoorPanelName = "Panel",
	DoorOpenPoseName = "OpenPose",
}

-- 아이템을 줍거나 쓸 수 있는 단계, 판자를 넘어뜨리고 문을 여닫을 수 있는 단계: 준비·추격
function ItemState.canInteractInPhase(phase: Types.MatchPhase): boolean
	return phase == "Preparation" or phase == "Chase"
end

-- 아이템을 쓸 수 있는 단계: 추격 (부상·스태미나·연막은 추격 단계에서만 의미가 있다)
function ItemState.canUseInPhase(phase: Types.MatchPhase): boolean
	return phase == "Chase"
end

return ItemState
