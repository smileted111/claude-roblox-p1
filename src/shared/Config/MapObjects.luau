--!strict
-- 맵 장치 수치 (GDD 6.1, 6.2, 6.4). 항목 이름은 CLAUDE.md의 맵 태그와 같다.

export type HideSpotConfig = {
	BreathAfter: number, -- 한 곳에 이만큼 숨어 있으면 숨소리가 남 (초)
	BreathRevealRadius: number, -- 숨소리 상태일 때 추격자가 이 거리 안에 오면 숨는 곳이 드러남 (스터드)
	ChaserOpenTime: number, -- 추격자가 숨는 곳을 열어보는 시간 (초). 프롬프트를 이만큼 누르고 있어야 함
	PromptDistance: number, -- 숨기·나오기·열어보기 프롬프트가 보이는 거리 (스터드)
	PromptFrontOffset: number, -- 프롬프트 위치: PrimaryPart 앞면에서 이만큼 앞 (스터드)
	ExitDistance: number, -- 나올 때 PrimaryPart 앞면에서 이만큼 앞에 섬 (스터드)
	DistanceSlack: number, -- 서버 거리 검사의 여유. 지연 시간 동안 움직인 거리를 봐줌 (스터드)
	OpenHoldSlack: number, -- 서버가 열어보기를 누른 시간을 검사할 때의 여유 (초)
	HideCooldown: number, -- 숨거나 나온 뒤 다시 나오기·숨기까지 (초)
	FoundHideCooldown: number, -- 추격자에게 들켜 밖으로 나온 뒤 다시 숨기까지 (초)
	CheckInterval: number, -- 숨소리·강조 표시를 확인하는 간격 (초)
	RevealColor: Color3, -- 강조 표시 색
	RevealFillTransparency: number, -- 강조 표시 채우기 투명도 (0~1)
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

export type ChaserGateConfig = {
	OpenTransparency: number, -- 열린 대기실 문의 투명도 (1이면 안 보임). 열리면 통과할 수 있게 충돌도 끈다
}

export type MapObjectsConfig = {
	ChaserGate: ChaserGateConfig,
	HideSpot: HideSpotConfig,
	Generator: GeneratorConfig,
	Exit: ExitConfig,
	Plank: PlankConfig,
}

local MapObjects: MapObjectsConfig = {
	ChaserGate = {
		OpenTransparency = 1, -- 임시
	},
	HideSpot = {
		BreathAfter = 20,
		BreathRevealRadius = 12, -- docs/studio-workflow.md S1-4
		ChaserOpenTime = 1,
		PromptDistance = 8, -- 임시
		PromptFrontOffset = 1, -- 임시
		ExitDistance = 2.5, -- 임시
		DistanceSlack = 4, -- 임시
		OpenHoldSlack = 0.25, -- 임시
		HideCooldown = 1, -- 임시
		FoundHideCooldown = 3, -- 임시: 들킨 직후 바로 다시 숨어 추격자의 열어보기를 되풀이시키는 것을 막음
		CheckInterval = 0.2, -- 임시
		RevealColor = Color3.fromRGB(255, 80, 60), -- 임시
		RevealFillTransparency = 0.6, -- 임시
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
