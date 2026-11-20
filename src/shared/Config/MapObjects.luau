--!strict
-- 맵 장치 수치 (GDD 6.1, 6.2, 6.4). 항목 이름은 CLAUDE.md의 맵 태그와 같다.

export type HideSpotConfig = {
	BreathAfter: number, -- 한 곳에 이만큼 숨어 있으면 숨소리가 남 (초)
	BreathRevealRadius: number, -- 숨소리 상태일 때 추격자가 이 거리 안에 오면 숨는 곳이 드러남 (스터드)
	ChaserOpenTime: number, -- 추격자가 숨는 곳을 열어보는 시간 (초)
}

export type GeneratorConfig = {
	RepairTimeSolo: number, -- 혼자 작동시키는 시간 (초)
	RepairTimeGroup: number, -- 2명 이상이 함께 작동시키는 시간 (초)
	NoiseMarkerDuration: number, -- 작동 소리로 추격자 화면에 위치를 표시하는 시간 (초)
}

export type ExitConfig = {
	OpenCount: number, -- 발전기를 모두 작동시키면 열리는 출구 수
}

export type PlankConfig = {
	ChaserStunTime: number, -- 넘어진 판자에 맞은 추격자의 기절 시간 (초)
}

export type MapObjectsConfig = {
	HideSpot: HideSpotConfig,
	Generator: GeneratorConfig,
	Exit: ExitConfig,
	Plank: PlankConfig,
}

local MapObjects: MapObjectsConfig = {
	HideSpot = {
		BreathAfter = 20,
		BreathRevealRadius = 12, -- docs/studio-workflow.md S1-4
		ChaserOpenTime = 1,
	},
	Generator = {
		RepairTimeSolo = 12,
		RepairTimeGroup = 7, -- GDD는 "2명이면 7초". 3명 이상도 같은 값을 쓴다
		NoiseMarkerDuration = 2, -- docs/studio-workflow.md S2-2
	},
	Exit = {
		OpenCount = 1, -- 출구 2곳 중 1곳
	},
	Plank = {
		ChaserStunTime = 2,
	},
}

return MapObjects
