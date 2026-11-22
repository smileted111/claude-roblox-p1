--!strict
-- 추격자 공격·잡힘·아군 치료 (GDD 2.2, 7장, 12장). 공격 거리·각도·쿨다운은 추격자마다 Config.Chasers에,
-- 맞은 뒤 무적 시간과 치료 시간은 Config.Survivor에, 잡힘 연출 시간은 Config.Match.CaughtEffectTime에 있다.
-- 모두 GDD에 수치가 없어 정한 임시값이다. 플레이테스트로 조정한다.

export type AttackConfig = {
	RangeSlack: number, -- 서버 거리 검사의 여유. 요청이 오는 동안 생존자가 움직인 거리를 봐줌 (스터드)
	CooldownSlack: number, -- 서버 쿨다운 검사의 여유. 요청이 도착하는 간격의 흔들림을 봐줌 (초)
	HitPauseTime: number, -- 공격에 성공한 추격자가 그 자리에 멈추는 시간 (초). 이동·공격·스킬 모두 막힘
}

export type HealConfig = {
	PromptDistance: number, -- "치료" 프롬프트가 보이는 거리 (스터드)
	DistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	HoldSlack: number, -- 서버가 누른 시간을 검사할 때의 여유 (초)
}

-- 쓰러짐과 살리기 (2026-11-22 사용자 요청). 추격자가 있는 스테이지에서 부상 상태로 맞으면 쓰러지고(서 있는 다른 생존자가
-- 있을 때만), 붕대를 가진 동료가 HoldTime초 눌러 살리면 부상으로 일어난다. DownedTime초 안에 못 살리면 잡힘.
export type ReviveConfig = {
	DownedTime: number, -- 쓰러진 뒤 살릴 수 있는 시간 (초)
	HoldTime: number, -- "살리기" 프롬프트를 누르고 있어야 하는 시간 (초)
	PromptDistance: number, -- "살리기" 프롬프트가 보이는 거리 (스터드)
	DistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	HoldSlack: number, -- 서버가 누른 시간을 검사할 때의 여유 (초)
	InvulnerableTime: number, -- 일어난 직후 다시 맞지 않는 시간 (초)
	MarkerHeight: number, -- 쓰러진 동료 위 표시(생존자 화면)를 띄우는 높이 (스터드, HumanoidRootPart 위)
}

-- 잡힘 연출 (2026-11-21 사용자 요청으로 더 생동감 있게): 잡히는 순간 화면 번쩍임·흔들림, 잡힌 사람 카메라가
-- 잡은 괴물(추격자)의 얼굴로 돌며 당겨지고(CinematicTime), 그 뒤 FadeInTime 동안 암전. 그 사이 캐릭터는 뒤로 밀려 넘어지고
-- (모두에게 보임), 잡은 괴물은 덮치듯 뛰어오르고 MonsterPause 동안 그 자리에 선다.
-- 전체(CinematicTime + FadeInTime)는 Config.Match.CaughtEffectTime(관전 시작)보다 짧아야 한다.
export type CaughtEffectConfig = {
	CinematicTime: number, -- 잡힌 사람 카메라가 잡은 쪽을 비추는 시간 (초)
	FadeInTime: number, -- 연출 뒤 화면이 어두워지는 시간 (초). 서버는 CinematicTime + FadeInTime 뒤에 캐릭터를 지운다
	FadeOutTime: number, -- 잡힘 연출이 끝나고 화면이 다시 밝아지는 시간 (초)
	KnockdownTime: number, -- 캐릭터가 뒤로 넘어지는 시간 (초)
	KnockbackDistance: number, -- 넘어지며 밀려나는 거리 (스터드)
	ShakeStrength: number, -- 카메라 흔들림 세기 (스터드, 점점 줄어듦)
	ZoomFieldOfView: number, -- 클로즈업 끝의 시야각 (도). 기본 70에서 좁혀 당겨 보이게
	CameraDistance: number, -- 클로즈업 카메라와 잡은 쪽 머리 사이 거리 (괴물 머리 크기 비율을 곱함)
	CameraAngle: number, -- 잡은 쪽 정면에서 옆으로 돈 각도 (도). 뒤로 넘어지는 내 캐릭터가 카메라를 가리지 않게
	ImpactFlashColor: Color3, -- 잡히는 순간 번쩍임 색 (피를 떠올리게 하는 빨강은 쓰지 않는다)
	MonsterPause: number, -- 잡은 괴물이 덮친 뒤 그 자리에 서 있는 시간 (초). 연출(CinematicTime + FadeInTime)보다 길게
}

export type HitFlashConfig = {
	Color: Color3, -- 맞았을 때 화면에 잠깐 덮는 색. 피를 떠올리게 하는 빨강은 쓰지 않는다 (GDD 12장)
	StartTransparency: number, -- 0~1
	Duration: number, -- 사라지는 데 걸리는 시간 (초)
}

export type CatchConfig = {
	Attack: AttackConfig,
	Heal: HealConfig,
	Revive: ReviveConfig,
	CaughtEffect: CaughtEffectConfig,
	HitFlash: HitFlashConfig,
}

local Catch: CatchConfig = {
	Attack = {
		RangeSlack = 2, -- 임시: 달리기 24 기준 약 0.08초
		CooldownSlack = 0.1, -- 임시
		HitPauseTime = 10, -- 2026-11-22 사용자 요청
	},
	Heal = {
		PromptDistance = 8, -- 임시
		DistanceSlack = 4, -- 임시
		HoldSlack = 0.25, -- 임시
	},
	Revive = {
		DownedTime = 30, -- 2026-11-22 사용자 요청
		HoldTime = 4, -- 임시: 치료(Survivor.HealTime)와 같게
		PromptDistance = 8, -- 임시
		DistanceSlack = 4, -- 임시
		HoldSlack = 0.25, -- 임시
		InvulnerableTime = 2, -- 임시
		MarkerHeight = 3, -- 임시
	},
	CaughtEffect = {
		CinematicTime = 1.35, -- 임시
		FadeInTime = 0.3, -- 임시
		FadeOutTime = 0.5, -- 임시
		KnockdownTime = 0.45, -- 임시
		KnockbackDistance = 3, -- 임시
		ShakeStrength = 0.5, -- 임시
		ZoomFieldOfView = 42, -- 임시
		CameraDistance = 5, -- 임시
		CameraAngle = 55, -- 임시
		ImpactFlashColor = Color3.fromRGB(255, 255, 255), -- 임시
		MonsterPause = 1.8, -- 임시: 연출(1.35 + 0.3)보다 길게. 그 전에 돌아서면 카메라가 괴물 뒤통수를 비춤
	},
	HitFlash = {
		Color = Color3.fromRGB(235, 235, 245), -- 임시
		StartTransparency = 0.4, -- 임시
		Duration = 0.4, -- 임시
	},
}

return Catch
