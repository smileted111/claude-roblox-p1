--!strict
-- 입력 키 (GDD 11장). 모바일 화면 버튼과 게임패드 버튼 정리는 S3-5에서 이 파일을 넓힌다.
-- 추격자 스킬 키가 E라서(docs/studio-workflow.md S3-3) 상호작용(ProximityPrompt) 키는 Roblox 기본 E 대신 F를 쓴다.

export type InputConfig = {
	InteractKey: Enum.KeyCode, -- 모든 ProximityPrompt의 키보드 키 (숨기·수리·치료·줍기·판자·문·혼자 하기)
	InteractGamepad: Enum.KeyCode, -- 모든 ProximityPrompt의 게임패드 버튼
	SkillKeys: { Enum.KeyCode }, -- 추격자 스킬 (키보드, 게임패드)
}

local Input: InputConfig = {
	InteractKey = Enum.KeyCode.F,
	InteractGamepad = Enum.KeyCode.ButtonX,
	SkillKeys = { Enum.KeyCode.E, Enum.KeyCode.ButtonY },
}

return Input
