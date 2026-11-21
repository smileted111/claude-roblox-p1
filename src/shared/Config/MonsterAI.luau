--!strict
-- 괴물 AI 공통 설정 (GDD 4.4). 괴물마다 다른 속도·감지·공격 값은 Monsters에 있다.
-- "임시"라고 적은 값은 GDD에 수치가 없어 정한 초기값이다. 플레이테스트로 조정한다.

-- 길찾기 에이전트 (PathfindingService:CreatePath). 괴물 모델보다 조금 크게 잡아 벽 모서리에 걸리지 않게 한다.
export type AgentConfig = {
	Radius: number,
	Height: number,
	CanJump: boolean,
}

export type MonsterAIConfig = {
	TickInterval: number, -- AI 갱신 간격 (초). 괴물마다 시작 시점을 나눠 서버 부하를 분산한다
	PathRecomputeInterval: number, -- 길찾기 경로를 다시 계산하는 최소 간격 (초)
	Agent: AgentConfig,
	WaypointReachDistance: number, -- 경로의 중간 지점에 이만큼 가까워지면 다음 지점으로 (스터드, 수평 거리)
	ArriveDistance: number, -- 순찰 지점·마지막으로 본 위치에 도착했다고 보는 거리 (스터드, 수평 거리)
	GoalChangeTolerance: number, -- 목표가 이만큼 움직였을 때만 길을 다시 찾음 (스터드)
	DirectChaseDistance: number, -- 추격 대상이 보이고 이 거리 안이면 길찾기 없이 곧장 다가감 (스터드)
	InstantChaseDistance: number, -- 이 거리 안에서 생존자를 보면 의심 없이 바로 추격 (스터드)
	SuspicionTime: number, -- 의심 중 생존자를 이만큼 보면 추격 (초, 본 시간의 합)
	LoseSightTime: number, -- 의심·추격 중 대상이 이만큼 안 보이면 포기 (초)
	GiveUpTime: number, -- 포기한 뒤 제자리에 서 있는 시간. 끝나면 순찰로 (초)
	AttackWindup: number, -- 공격 동작을 시작하고 명중 판정까지 (초). 이 사이에 멀어지면 빗나감
	StuckTime: number, -- 움직이려는데 이만큼 거의 제자리면 막힌 것으로 보고 길을 다시 찾음 (초)
	StuckDistance: number, -- 막힘 판정에서 움직였다고 보는 최소 거리 (스터드)
	SpawnSpacing: number, -- 한 MonsterSpawn에 두 마리 이상 나올 때 옆으로 띄우는 거리 (스터드)
	AnimationFadeTime: number, -- 애니메이션을 바꿀 때 섞는 시간 (초)
	WalkAnimationSpeed: number, -- 걷기 애니메이션을 1배속으로 틀 때의 이동 속도 (스터드/초)
	BreakBarrierRadius: number, -- 거인이 앞쪽 이 반경 안의 넘어진 판자·닫힌 문을 부숨 (스터드)
	BreakHideSpotReach: number, -- 거인이 숨는 곳에 이만큼 가까이 가면 부숨 (스터드, 수평 거리)
	AlarmLureTime: number, -- 알람시계 소리를 들은 괴물(사냥개 밖)이 그 자리를 찾아가는 시간 (초)
}

local MonsterAI: MonsterAIConfig = {
	TickInterval = 0.2, -- GDD 4.4
	PathRecomputeInterval = 0.5, -- docs/studio-workflow.md S1-6
	Agent = {
		Radius = 2, -- 임시
		Height = 6, -- 임시: 배회자 모델 키 약 5.7
		CanJump = false, -- 임시: 블록 맵은 평평함
	},
	WaypointReachDistance = 2.5, -- 임시
	ArriveDistance = 3, -- 임시
	GoalChangeTolerance = 2, -- 임시
	DirectChaseDistance = 15, -- 임시
	InstantChaseDistance = 12, -- 임시
	SuspicionTime = 0.8, -- 임시
	LoseSightTime = 4, -- 임시
	GiveUpTime = 2, -- 임시
	AttackWindup = 0.4, -- 임시: 걷는 생존자(16)는 이 사이 6.4스터드 멀어져 피할 수 있음
	StuckTime = 2, -- 임시
	StuckDistance = 1, -- 임시
	SpawnSpacing = 4, -- 임시
	AnimationFadeTime = 0.2, -- 임시
	WalkAnimationSpeed = 16, -- 임시: Roblox 기본 R15 걷기 애니메이션 기준
	BreakBarrierRadius = 7, -- 임시
	BreakHideSpotReach = 6, -- 임시
	AlarmLureTime = 8, -- 임시
}

return MonsterAI
