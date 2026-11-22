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
	BrokenColor: Color3, -- 거인이 부순 숨는 곳의 색 (더 숨을 수 없음)
}

-- 에너지 코어(발전기) 가운데의 번개 모양 (2026-11-22 사용자 요청, ObjectiveService.addBolt)
export type GeneratorBoltConfig = {
	Color: Color3, -- 고치기 전 번개 색 (Neon)
	RepairedColor: Color3, -- 다 고친 뒤 번개 색
	HeightFraction: number, -- 번개 크기: Strokes 좌표(높이 1 기준)에 몸체 높이 × 이 값을 곱한다
	Thickness: number, -- 선 굵기 (Strokes와 같은 높이 1 기준)
	DepthMargin: number, -- 몸체 앞뒤로 튀어나오는 두께 (스터드). 앞뒤 두 면에 모두 보이게
	Strokes: { { number } }, -- 선 {x1, y1, x2, y2}. 가운데가 0, 높이 1 기준, x는 넓은 면의 오른쪽, y는 위
}

export type GeneratorConfig = {
	RepairTimeSolo: number, -- 혼자 작동시키는 시간 (초)
	RepairTimeGroup: number, -- 2명 이상이 함께 작동시키는 시간 (초)
	NoiseMarkerDuration: number, -- 작동 소리로 추격자 화면에 위치를 표시하는 시간 (초)
	NoiseInterval: number, -- 고치는 동안 소리(추격자 표시·사냥개 반응)를 내는 간격 (초)
	NoiseRadius: number, -- 작동 소리가 들리는 거리 (스터드, 사냥개)
	PromptDistance: number, -- "수리" 프롬프트가 보이는 거리 (스터드)
	DistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	TickInterval: number, -- 수리 진행과 탈출을 확인하는 간격 (초)
	ProgressPublishStep: number, -- 진행 Attribute를 이 단위로 반올림해 공개 (0~1)
	RepairedColor: Color3, -- 다 고친 발전기 색
	Bolt: GeneratorBoltConfig,
}

export type ExitConfig = {
	OpenCount: number, -- 발전기를 모두 작동시키면 열리는 출구 수
	EscapeMargin: number, -- 출구 파트 상자를 이만큼 넓힌 곳에 들어가면 탈출 (스터드)
	LeaveDelay: number, -- 탈출한 캐릭터를 맵에서 지우기까지 (초)
	OpenColor: Color3, -- 열린 출구 색 (Neon)
	OpenTransparency: number, -- 열린 출구 투명도
	MarkerMaxDistance: number, -- 열린 출구 위 "출구" 표시가 보이는 거리 (스터드)
}

export type PlankConfig = {
	ChaserStunTime: number, -- 넘어진 판자에 맞은 추격자의 기절 시간 (초)
	PromptDistance: number, -- "넘어뜨리기" 프롬프트가 보이는 거리 (스터드)
	DistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	FallTime: number, -- 넘어지는 데 걸리는 시간 (초)
	HitMargin: number, -- 넘어진 판자 자리에서 이만큼 넓힌 곳에 있는 추격자가 맞음 (스터드)
}

export type DoorConfig = {
	PromptDistance: number, -- "열기"·"닫기" 프롬프트가 보이는 거리 (스터드)
	DistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	SwingTime: number, -- 열리고 닫히는 데 걸리는 시간 (초)
	ToggleCooldown: number, -- 한 문을 다시 열고 닫을 수 있기까지 (초)
	StartOpen: boolean, -- 스테이지 시작 때 열려 있는가
}

export type ItemPickupConfig = {
	SpawnFraction: number, -- ItemSpawn 중 아이템을 놓는 비율 (0~1, 반올림)
	PromptDistance: number, -- "줍기" 프롬프트가 보이는 거리 (스터드)
	DistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	Size: number, -- 맵에 놓인 아이템 상자 크기 (스터드)
	Height: number, -- 바닥 표시 위로 띄우는 높이 (스터드)
}

export type ChaserGateConfig = {
	OpenTransparency: number, -- 열린 대기실 문의 투명도 (1이면 안 보임). 열리면 통과할 수 있게 충돌도 끈다
}

-- 추격자가 여럿이면 ChaserSpawn을 돌아가며 쓰고, 한 자리에 여럿이면 그 Part의 오른쪽·왼쪽으로 Spacing씩 벌려 세운다.
-- 맵마다 ChaserSpawn 좌우로 11스터드 이상 비어 있어 4명(0, +4, -4, +8)까지 들어간다 (2026-11-22 확인).
export type ChaserSpawnConfig = {
	Spacing: number, -- 같은 자리에 선 추격자 사이 거리 (스터드)
}

export type MapObjectsConfig = {
	ChaserGate: ChaserGateConfig,
	ChaserSpawn: ChaserSpawnConfig,
	HideSpot: HideSpotConfig,
	Generator: GeneratorConfig,
	Exit: ExitConfig,
	Plank: PlankConfig,
	Door: DoorConfig,
	ItemPickup: ItemPickupConfig,
}

local MapObjects: MapObjectsConfig = {
	ChaserGate = {
		OpenTransparency = 1, -- 임시
	},
	ChaserSpawn = {
		Spacing = 4, -- 임시
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
		BrokenColor = Color3.fromRGB(40, 35, 30), -- 임시
	},
	Generator = {
		RepairTimeSolo = 12,
		RepairTimeGroup = 7, -- GDD는 "2명이면 7초". 3명 이상도 같은 값을 쓴다
		NoiseMarkerDuration = 2, -- docs/studio-workflow.md S2-2
		NoiseInterval = 4, -- 임시: 고치는 동안 4초마다 2초씩 위치가 드러남
		NoiseRadius = 80, -- 임시
		PromptDistance = 8, -- 임시
		DistanceSlack = 4, -- 임시
		TickInterval = 0.1, -- 임시
		ProgressPublishStep = 0.01, -- 임시
		RepairedColor = Color3.fromRGB(120, 230, 120), -- 임시
		Bolt = {
			Color = Color3.fromRGB(255, 214, 50), -- 임시
			RepairedColor = Color3.fromRGB(170, 245, 255), -- 임시
			HeightFraction = 0.8, -- 임시: 높이 5 몸체에서 번개 높이 약 4.9
			Thickness = 0.15, -- 임시
			DepthMargin = 0.15, -- 임시
			-- 위아래 선을 가운데 꺾임 길이만큼 벌려야 한 줄 사선으로 보이지 않는다 (2026-11-22 화면 확인).
			-- 몸체를 뚫고 지나가 한쪽 면은 ⚡, 반대쪽 면은 좌우가 뒤집힌 모양으로 보인다.
			Strokes = {
				{ 0.28, 0.5, -0.2, 0.03 }, -- 위: 오른쪽 위에서 왼쪽 아래로
				{ -0.2, 0, 0.2, 0 }, -- 가운데: 오른쪽으로 꺾음
				{ 0.2, -0.03, -0.28, -0.5 }, -- 아래: 다시 왼쪽 아래로
			},
		},
	},
	Exit = {
		OpenCount = 1, -- 출구 2곳 중 1곳
		EscapeMargin = 2, -- 임시
		LeaveDelay = 0.3, -- 임시
		OpenColor = Color3.fromRGB(90, 255, 120), -- 임시
		OpenTransparency = 0.4, -- 임시
		MarkerMaxDistance = 400, -- 임시: 맵 어디서든 보이게
	},
	Plank = {
		ChaserStunTime = 2,
		PromptDistance = 7, -- 임시
		DistanceSlack = 4, -- 임시
		FallTime = 0.25, -- 임시
		HitMargin = 2.5, -- 임시
	},
	Door = {
		PromptDistance = 7, -- 임시
		DistanceSlack = 4, -- 임시
		SwingTime = 0.3, -- 임시
		ToggleCooldown = 0.6, -- 임시
		StartOpen = true, -- 임시
	},
	ItemPickup = {
		SpawnFraction = 0.6, -- 임시: ItemSpawn 10곳이면 6곳
		PromptDistance = 7, -- 임시
		DistanceSlack = 4, -- 임시
		Size = 1.4, -- 임시
		Height = 1.5, -- 임시
	},
}

return MapObjects
