--!strict
-- 괴물 AI 공통 설정 (GDD 4.4). 괴물마다 다른 속도·감지 값은 Monsters에 있다.

export type MonsterAIConfig = {
	TickInterval: number, -- AI 갱신 간격 (초). 괴물마다 시작 시점을 나눠 서버 부하를 분산한다
	PathRecomputeInterval: number, -- 길찾기 경로를 다시 계산하는 최소 간격 (초)
}

local MonsterAI: MonsterAIConfig = {
	TickInterval = 0.2,
	PathRecomputeInterval = 0.5, -- docs/studio-workflow.md S1-6
}

return MonsterAI
