--!strict
-- 스테이지 구성 (GDD 4.2).
-- 괴물 수는 생존자 4명 기준이다. 실제 수는 MonsterScaling의 인원 배율을 곱해 정한다.
-- 화면에 보이는 맵 이름은 Strings.Stages, 매치에 나오는 순서는 Match.StageOrder에 있다.
-- 조명(Lighting)은 맵을 불러올 때 StageService가 적용한다. 형식과 대기 장소 값은 Config.Lighting에 있다.
-- 조명 값은 GDD에 수치가 없어 임시다. Stage1만 테스트 맵 화면을 보고 정했고, 나머지는 맵을 만들 때 다시 맞춘다.

local Lighting = require(script.Parent.Lighting)
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
	Lighting: Lighting.LightingPreset, -- 이 스테이지에 있는 동안의 조명
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
		-- 달빛 밤. 형태는 보이고 그늘은 어둡게 (임시)
		Lighting = {
			ClockTime = 0,
			Brightness = 1,
			Ambient = Color3.fromRGB(70, 70, 85),
			OutdoorAmbient = Color3.fromRGB(90, 95, 115),
			ExposureCompensation = 0,
			Atmosphere = {
				Density = 0.35,
				Haze = 0,
				Color = Color3.fromRGB(60, 65, 80),
				Decay = Color3.fromRGB(30, 30, 40),
			},
		},
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
		-- 차가운 녹색 밤, 조금 뿌옇게 (임시)
		Lighting = {
			ClockTime = 0,
			Brightness = 1,
			Ambient = Color3.fromRGB(65, 75, 70),
			OutdoorAmbient = Color3.fromRGB(80, 95, 90),
			ExposureCompensation = 0,
			Atmosphere = {
				Density = 0.4,
				Haze = 1,
				Color = Color3.fromRGB(60, 75, 70),
				Decay = Color3.fromRGB(25, 35, 30),
			},
		},
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
		-- 지하라 가장 어둡게. 그림자 괴물이 숨는 어두운 구역이 있음 (임시)
		Lighting = {
			ClockTime = 0,
			Brightness = 0.5,
			Ambient = Color3.fromRGB(55, 55, 65),
			OutdoorAmbient = Color3.fromRGB(65, 65, 80),
			ExposureCompensation = 0,
			Atmosphere = {
				Density = 0.45,
				Haze = 2,
				Color = Color3.fromRGB(40, 40, 50),
				Decay = Color3.fromRGB(20, 20, 25),
			},
		},
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
		-- 보랏빛 밤 (임시)
		Lighting = {
			ClockTime = 0,
			Brightness = 1,
			Ambient = Color3.fromRGB(75, 65, 85),
			OutdoorAmbient = Color3.fromRGB(95, 85, 115),
			ExposureCompensation = 0,
			Atmosphere = {
				Density = 0.35,
				Haze = 0.5,
				Color = Color3.fromRGB(70, 55, 80),
				Decay = Color3.fromRGB(35, 25, 40),
			},
		},
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
		-- 누런 지하 터널 (임시)
		Lighting = {
			ClockTime = 0,
			Brightness = 0.5,
			Ambient = Color3.fromRGB(60, 60, 55),
			OutdoorAmbient = Color3.fromRGB(70, 70, 65),
			ExposureCompensation = 0,
			Atmosphere = {
				Density = 0.45,
				Haze = 2,
				Color = Color3.fromRGB(55, 55, 45),
				Decay = Color3.fromRGB(25, 25, 20),
			},
		},
	},
}

return Stages
