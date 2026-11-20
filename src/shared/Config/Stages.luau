--!strict
-- 스테이지 구성 (GDD 4.2).
-- 괴물 수는 생존자 4명 기준이다. 실제 수는 MonsterScaling의 인원 배율을 곱해 정한다.
-- 화면에 보이는 맵 이름은 Strings.Stages, 매치에 나오는 순서는 Match.StageOrder에 있다.

local Types = require(script.Parent.Parent.Types)

export type MonsterGroup = {
	Monster: Types.MonsterId,
	Count: number,
}

export type StageDef = {
	Number: number, -- 스테이지 번호
	MapFolder: string, -- ServerStorage.Maps 안의 맵 폴더 이름
	Monsters: { MonsterGroup }, -- 생존자 4명 기준 괴물 구성
	GeneratorCount: number, -- 작동해야 출구가 열리는 발전기 수
	TimeLimit: number, -- 추격 단계 제한 시간 (초)
	PostLaunch: boolean, -- true면 출시 후 추가하는 스테이지 (GDD 15장 M3)
}

local Stages: { [Types.StageId]: StageDef } = {
	-- 폐교
	Stage1 = {
		Number = 1,
		MapFolder = "Stage1",
		Monsters = {
			{ Monster = "Wanderer", Count = 3 },
		},
		GeneratorCount = 3,
		TimeLimit = 240,
		PostLaunch = false,
	},
	-- 폐병원
	Stage2 = {
		Number = 2,
		MapFolder = "Stage2",
		Monsters = {
			{ Monster = "Wanderer", Count = 2 },
			{ Monster = "Hound", Count = 2 },
		},
		GeneratorCount = 4,
		TimeLimit = 240,
		PostLaunch = false,
	},
	-- 지하 연구소
	Stage3 = {
		Number = 3,
		MapFolder = "Stage3",
		Monsters = {
			{ Monster = "Hound", Count = 2 },
			{ Monster = "Watcher", Count = 2 },
			{ Monster = "Shadow", Count = 2 },
		},
		GeneratorCount = 5,
		TimeLimit = 300,
		PostLaunch = false,
	},
	-- 놀이공원 (출시 후)
	Stage4 = {
		Number = 4,
		MapFolder = "Stage4",
		Monsters = {
			{ Monster = "Wanderer", Count = 2 },
			{ Monster = "Shadow", Count = 2 },
			{ Monster = "Giant", Count = 1 },
		},
		GeneratorCount = 5,
		TimeLimit = 300,
		PostLaunch = true,
	},
	-- 폐쇄된 지하철 (출시 후)
	Stage5 = {
		Number = 5,
		MapFolder = "Stage5",
		Monsters = {
			{ Monster = "Hound", Count = 3 },
			{ Monster = "Watcher", Count = 2 },
			{ Monster = "Giant", Count = 1 },
		},
		GeneratorCount = 6,
		TimeLimit = 300,
		PostLaunch = true,
	},
}

return Stages
