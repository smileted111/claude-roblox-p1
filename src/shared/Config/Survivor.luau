--!strict
-- 생존자 이동·스태미나·부상 (GDD 2.2, 4.1, 6장).
-- "임시"라고 적은 값은 GDD에 수치가 없어 정한 초기값이다. 플레이테스트로 조정한다.

export type StaminaConfig = {
	Max: number,
	RunDrainPerSecond: number, -- 달리는 동안 초당 소모량
	RegenPerSecond: number, -- 달리지 않을 때 초당 회복량
	RegenDelay: number, -- 달리기를 멈춘 뒤 회복이 시작되기까지 (초)
	MinToStartRun: number, -- 이 값 이상이어야 달리기를 시작할 수 있음 (바닥난 직후 다시 달리는 것을 막음)
}

export type SurvivorConfig = {
	WalkSpeed: number,
	RunSpeed: number,
	InjuredSpeedMultiplier: number, -- 부상 상태의 걷기·달리기 속도 배율
	Stamina: StaminaConfig,
	HitInvulnerableTime: number, -- 맞은 직후 다시 맞지 않는 시간 (초)
	HealTime: number, -- 아군을 치료하는 데 걸리는 시간 (초)
	RunNoiseRadius: number, -- 달리는 소리가 들리는 거리 (스터드, 사냥개)
	RunNoiseInterval: number, -- 달리는 동안 소리를 내는 간격 (초)
	InventorySlots: number, -- 아이템 칸 수
}

local Survivor: SurvivorConfig = {
	WalkSpeed = 16,
	RunSpeed = 24,
	InjuredSpeedMultiplier = 0.9, -- 이동 속도 -10%
	Stamina = {
		Max = 100, -- 임시
		RunDrainPerSecond = 20, -- 임시: 가득 찬 상태에서 5초 달림
		RegenPerSecond = 10, -- 임시: 바닥에서 가득 차기까지 10초
		RegenDelay = 1, -- 임시
		MinToStartRun = 25, -- 임시
	},
	HitInvulnerableTime = 1, -- docs/studio-workflow.md S1-5
	HealTime = 4,
	RunNoiseRadius = 50, -- 임시
	RunNoiseInterval = 0.5, -- 임시
	InventorySlots = 2,
}

return Survivor
