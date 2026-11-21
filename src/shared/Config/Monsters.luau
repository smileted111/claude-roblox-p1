--!strict
-- 괴물 5종 (GDD 4.1). 속도는 Humanoid.WalkSpeed(스터드/초), 시야각은 정면 기준 전체 각도(도).
-- 모든 괴물에 공통인 규칙: 추격자는 공격하지 않는다 (GDD 2장), 숨은 생존자는 감지하지 못한다 (GDD 4.4).
-- "임시"라고 적은 값은 GDD에 수치가 없어 정한 초기값이다. 플레이테스트로 조정한다.

local Types = require(script.Parent.Parent.Types)

export type MonsterDef = {
	WalkSpeed: number, -- 0이면 움직이지 않음. 추격·돌진 속도
	PatrolSpeed: number?, -- 순찰할 때의 속도. 없으면 WalkSpeed
	Senses: { Types.Sense },
	SightRange: number, -- 볼 수 있는 거리. Sight가 없으면 0
	SightAngle: number, -- 시야각. Sight가 없으면 0
	HearingRange: number, -- 소리를 듣는 거리. Sound가 없으면 0
	CloseDetectRange: number?, -- 시야가 없어도 이 거리 안(벽 너머 제외)의 생존자는 알아챔 (사냥개)
	AttackRange: number, -- 0이면 공격하지 않음
	AttackCooldown: number, -- 공격 간격 (초)
	CatchesInstantly: boolean, -- 맞으면 부상 없이 바로 잡힘 (GDD 2.2)
	BreaksBarriers: boolean, -- 판자·문을 부수고 지나감
	BreaksHideSpots: boolean, -- 숨는 곳을 부숨 (GDD 4.4)
	ChaseGiveUpTime: number?, -- 돌진한 뒤 이 시간 안에 못 잡으면 포기 (초)
	AlertMarkerDuration: number?, -- 발견한 생존자 위치를 추격자에게 보여주는 시간 (초)
	AlertEyeColor: Color3?, -- 경보 중 눈 색 (감시자)
	FlashlightFreezeTime: number?, -- 손전등 빛을 받으면 멈추는 시간 (초, GDD 6.3 손전등과 같은 값)
	DarkTransparency: number?, -- 어두운 곳에서의 투명도 (1이면 완전히 안 보임)
	AgentRadius: number?, -- 길찾기 반지름. 없으면 Config.MonsterAI.Agent (큰 괴물)
	AgentHeight: number?, -- 길찾기 높이. 없으면 Config.MonsterAI.Agent
}

-- 시야 단계: GDD는 "짧음 / (보통) / 넓음"으로만 적었다.
local SHORT_SIGHT_RANGE = 40 -- 임시
local SHORT_SIGHT_ANGLE = 90 -- 임시
local NORMAL_SIGHT_RANGE = 60 -- 임시
local NORMAL_SIGHT_ANGLE = 110 -- 임시
local WIDE_SIGHT_RANGE = 100 -- 임시
local WIDE_SIGHT_ANGLE = 160 -- 임시

local ATTACK_RANGE = 5 -- 임시
local ATTACK_COOLDOWN = 2 -- 임시

local Monsters: { [Types.MonsterId]: MonsterDef } = {
	-- 배회자: 정해진 길을 순찰하다 생존자를 보면 쫓아옴
	Wanderer = {
		WalkSpeed = 12,
		Senses = { "Sight" },
		SightRange = SHORT_SIGHT_RANGE,
		SightAngle = SHORT_SIGHT_ANGLE,
		HearingRange = 0,
		AttackRange = ATTACK_RANGE,
		AttackCooldown = ATTACK_COOLDOWN,
		CatchesInstantly = false,
		BreaksBarriers = false,
		BreaksHideSpots = false,
	},
	-- 사냥개: 달리는 소리에 반응해 짧게 돌진, 5초 후 포기
	Hound = {
		WalkSpeed = 22,
		PatrolSpeed = 12, -- 임시: 순찰까지 22면 너무 빨라 소리를 낼 틈이 없음
		Senses = { "Sound" },
		SightRange = 0,
		SightAngle = 0,
		HearingRange = 60, -- 임시
		CloseDetectRange = 10, -- 임시
		AttackRange = ATTACK_RANGE,
		AttackCooldown = ATTACK_COOLDOWN,
		CatchesInstantly = false,
		BreaksBarriers = false,
		BreaksHideSpots = false,
		ChaseGiveUpTime = 5,
	},
	-- 감시자: 움직이지 않음. 생존자를 보면 경보 → 추격자에게 그 위치가 5초간 표시됨
	Watcher = {
		WalkSpeed = 0,
		Senses = { "Sight" },
		SightRange = WIDE_SIGHT_RANGE,
		SightAngle = WIDE_SIGHT_ANGLE,
		HearingRange = 0,
		AttackRange = 0,
		AttackCooldown = 0,
		CatchesInstantly = false,
		BreaksBarriers = false,
		BreaksHideSpots = false,
		AlertMarkerDuration = 5,
		AlertEyeColor = Color3.fromRGB(255, 60, 50), -- 임시
	},
	-- 그림자: 어두운 곳에서는 거의 안 보임. 손전등을 비추면 2초간 멈춤
	Shadow = {
		WalkSpeed = 16,
		Senses = { "Sight" },
		SightRange = NORMAL_SIGHT_RANGE,
		SightAngle = NORMAL_SIGHT_ANGLE,
		HearingRange = 0,
		AttackRange = ATTACK_RANGE,
		AttackCooldown = ATTACK_COOLDOWN,
		CatchesInstantly = false,
		BreaksBarriers = false,
		BreaksHideSpots = false,
		FlashlightFreezeTime = 2,
		DarkTransparency = 0.9, -- 임시
	},
	-- 거인: 판자·문을 부수고 지나감. 맞으면 즉시 잡힘
	Giant = {
		WalkSpeed = 10,
		Senses = { "Sight" },
		SightRange = NORMAL_SIGHT_RANGE,
		SightAngle = NORMAL_SIGHT_ANGLE,
		HearingRange = 0,
		AttackRange = ATTACK_RANGE,
		AttackCooldown = ATTACK_COOLDOWN,
		CatchesInstantly = true,
		BreaksBarriers = true,
		BreaksHideSpots = true,
		AgentRadius = 2.5, -- 임시: 모델 키 약 8.8
		AgentHeight = 9.5, -- 임시
	},
}

return Monsters
