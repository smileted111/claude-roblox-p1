--!strict
-- 인원에 따른 괴물 수 보정 (GDD 4.3, 5장).
-- 종류별 실제 수 = 반올림(Stages의 수 × 배율). 그 구간의 MinPerType보다 적으면 MinPerType으로 올린다.
-- 동시에 활동하는 괴물은 모두 합쳐 MaxActive를 넘지 않는다.

export type Bracket = {
	HasChaser: boolean, -- 이번 스테이지에 추격자가 있는가
	MinSurvivors: number,
	MaxSurvivors: number,
	Multiplier: number,
	MinPerType: number, -- 종류마다 최소 마리 수
}

export type MonsterScalingConfig = {
	Brackets: { Bracket },
	DefaultMultiplier: number, -- 어느 구간에도 맞지 않을 때 (GDD 표에 없는 조합)
	MaxActive: number,
}

local MonsterScaling: MonsterScalingConfig = {
	Brackets = {
		-- 솔로: 생존자 1명, 추격자 없음
		{ HasChaser = false, MinSurvivors = 1, MaxSurvivors = 1, Multiplier = 0.7, MinPerType = 1 },
		{ HasChaser = true, MinSurvivors = 1, MaxSurvivors = 2, Multiplier = 0.6, MinPerType = 0 },
		{ HasChaser = true, MinSurvivors = 3, MaxSurvivors = 5, Multiplier = 1.0, MinPerType = 0 },
		{ HasChaser = true, MinSurvivors = 6, MaxSurvivors = 7, Multiplier = 1.3, MinPerType = 0 },
	},
	DefaultMultiplier = 1.0,
	MaxActive = 20,
}

return MonsterScaling
