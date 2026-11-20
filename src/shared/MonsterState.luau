--!strict
-- 괴물 모델이 있는 곳, 공개 Attribute, 괴물이 움직이는 단계를 정의한다 (GDD 4장).
-- 쓰기는 서버 MonsterService만 한다. 클라이언트는 읽기만 한다 (예: 추격자 화면의 괴물 위치, 질문지 Q2-8).
--
-- ServerStorage.MonsterModels.<MonsterId>   괴물 모델 원본 (서버만 보임).
--                                           Humanoid, PrimaryPart(HumanoidRootPart), Head(시야의 눈 위치)가 필요하다
-- Workspace.Monsters                        지금 활동하는 괴물 모델. 스테이지가 끝나면 지운다
--
-- 괴물 Model의 Attribute
--   MonsterId  Types.MonsterId       괴물 종류
--   State      Types.MonsterAIState  AI 상태

local Types = require(script.Parent.Types)

local MonsterState = {
	ModelsFolderName = "MonsterModels",
	FolderName = "Monsters",
	Attribute = table.freeze({
		MonsterId = "MonsterId",
		State = "State",
	}),
}

-- 괴물이 움직이고 생존자를 쫓는 단계: 추격. 준비 중에는 제자리에 서 있다 (docs/studio-workflow.md S1-6).
function MonsterState.canActInPhase(phase: Types.MatchPhase): boolean
	return phase == "Chase"
end

return MonsterState
