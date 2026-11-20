--!strict
-- 추격자 4종 (GDD 4.1, 7장). 지금은 네 종류의 속도·공격 값이 같고 스킬만 다르다.
-- "임시"라고 적은 값은 GDD에 수치가 없어 정한 초기값이다. 플레이테스트로 조정한다.

local Types = require(script.Parent.Parent.Types)

export type SkillDef = {
	Kind: Types.SkillKind,
	Cooldown: number, -- 초
	Duration: number?, -- 효과 지속 시간 (초)
	SpeedMultiplier: number?, -- 이동 속도 배율
	Distance: number?, -- 이동 거리 (스터드)
	MonsterCount: number?, -- 부르는 괴물 수
}

export type ChaserDef = {
	Unlock: Types.UnlockKind,
	WalkSpeed: number,
	AttackCooldown: number, -- 근접 공격 간격 (초)
	AttackRange: number, -- 추격자 앞쪽 공격 판정 거리 (스터드, HumanoidRootPart 중심 사이)
	AttackAngle: number, -- 추격자 앞쪽 공격 판정 각도 (도). 바라보는 방향을 가운데로 이 각도 안
	Skill: SkillDef,
}

local WALK_SPEED = 20
local ATTACK_COOLDOWN = 1.5
local ATTACK_RANGE = 6 -- 임시
local ATTACK_ANGLE = 120 -- 임시

local Chasers: { [Types.ChaserId]: ChaserDef } = {
	-- 사냥꾼 — 돌진: 2초간 이동 속도 +50%
	Hunter = {
		Unlock = "Default",
		WalkSpeed = WALK_SPEED,
		AttackCooldown = ATTACK_COOLDOWN,
		AttackRange = ATTACK_RANGE,
		AttackAngle = ATTACK_ANGLE,
		Skill = {
			Kind = "Dash",
			Cooldown = 20,
			Duration = 2,
			SpeedMultiplier = 1.5,
		},
	},
	-- 추적자 — 흔적 보기: 8초간 생존자 발자국이 보임
	Tracker = {
		Unlock = "Default",
		WalkSpeed = WALK_SPEED,
		AttackCooldown = ATTACK_COOLDOWN,
		AttackRange = ATTACK_RANGE,
		AttackAngle = ATTACK_ANGLE,
		Skill = {
			Kind = "RevealFootprints",
			Cooldown = 30,
			Duration = 8,
		},
	},
	-- 망령 — 순간이동: 바라보는 방향으로 짧게 이동
	Wraith = {
		Unlock = "Coins",
		WalkSpeed = WALK_SPEED,
		AttackCooldown = ATTACK_COOLDOWN,
		AttackRange = ATTACK_RANGE,
		AttackAngle = ATTACK_ANGLE,
		Skill = {
			Kind = "Blink",
			Cooldown = 25,
			Distance = 20, -- 임시 ("짧게")
		},
	},
	-- 조종자 — 괴물 부르기: 가장 가까운 괴물 2마리를 내 위치로 부름
	Puppeteer = {
		Unlock = "Coins",
		WalkSpeed = WALK_SPEED,
		AttackCooldown = ATTACK_COOLDOWN,
		AttackRange = ATTACK_RANGE,
		AttackAngle = ATTACK_ANGLE,
		Skill = {
			Kind = "CallMonsters",
			Cooldown = 35,
			MonsterCount = 2,
		},
	},
}

return Chasers
