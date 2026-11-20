--!strict
-- 추격자 공격·잡힘·아군 치료 (GDD 2.2, 7장, 12장). 공격 거리·각도·쿨다운은 추격자마다 Config.Chasers에,
-- 맞은 뒤 무적 시간과 치료 시간은 Config.Survivor에, 잡힘 연출 시간은 Config.Match.CaughtEffectTime에 있다.
-- 모두 GDD에 수치가 없어 정한 임시값이다. 플레이테스트로 조정한다.

export type AttackConfig = {
	RangeSlack: number, -- 서버 거리 검사의 여유. 요청이 오는 동안 생존자가 움직인 거리를 봐줌 (스터드)
	CooldownSlack: number, -- 서버 쿨다운 검사의 여유. 요청이 도착하는 간격의 흔들림을 봐줌 (초)
}

export type HealConfig = {
	PromptDistance: number, -- "치료" 프롬프트가 보이는 거리 (스터드)
	DistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	HoldSlack: number, -- 서버가 누른 시간을 검사할 때의 여유 (초)
}

export type CaughtEffectConfig = {
	FadeInTime: number, -- 화면이 어두워지는 시간 (초). 서버는 이만큼 뒤에 캐릭터를 맵에서 지운다
	FadeOutTime: number, -- 잡힘 연출이 끝나고 화면이 다시 밝아지는 시간 (초)
}

export type HitFlashConfig = {
	Color: Color3, -- 맞았을 때 화면에 잠깐 덮는 색. 피를 떠올리게 하는 빨강은 쓰지 않는다 (GDD 12장)
	StartTransparency: number, -- 0~1
	Duration: number, -- 사라지는 데 걸리는 시간 (초)
}

export type CatchConfig = {
	Attack: AttackConfig,
	Heal: HealConfig,
	CaughtEffect: CaughtEffectConfig,
	HitFlash: HitFlashConfig,
}

local Catch: CatchConfig = {
	Attack = {
		RangeSlack = 2, -- 임시: 달리기 24 기준 약 0.08초
		CooldownSlack = 0.1, -- 임시
	},
	Heal = {
		PromptDistance = 8, -- 임시
		DistanceSlack = 4, -- 임시
		HoldSlack = 0.25, -- 임시
	},
	CaughtEffect = {
		FadeInTime = 0.3, -- 임시
		FadeOutTime = 0.5, -- 임시
	},
	HitFlash = {
		Color = Color3.fromRGB(235, 235, 245), -- 임시
		StartTransparency = 0.4, -- 임시
		Duration = 0.4, -- 임시
	},
}

return Catch
