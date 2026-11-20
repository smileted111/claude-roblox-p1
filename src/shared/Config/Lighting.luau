--!strict
-- 조명 값 (GDD 12장: 어둡지만 형태는 잘 보이게, 손전등과 비상등이 주요 광원).
-- Lighting은 서버 하나에 하나뿐이라 StageService가 대기 장소 ↔ 스테이지를 오갈 때 값을 바꾼다.
-- 스테이지별 값은 Config.Stages의 Lighting에 있고, 여기에는 형식과 대기 장소 값만 둔다.
-- GDD에 수치가 없어 모두 임시 값이다. Studio 플레이테스트 화면을 보고 정했다.

export type AtmosphereValues = {
	Density: number, -- 0~1. 클수록 먼 곳이 대기 색에 묻힘
	Haze: number, -- 0~10. 지평선 근처 뿌연 정도
	Color: Color3, -- 대기 색
	Decay: Color3, -- 해에서 먼 쪽 대기 색
}

export type LightingPreset = {
	ClockTime: number, -- 0~24. 0이면 자정
	Brightness: number, -- 해·달 빛의 세기
	Ambient: Color3, -- 하늘이 안 보이는 곳(실내·그늘)의 기본 밝기
	OutdoorAmbient: Color3, -- 하늘이 보이는 곳의 기본 밝기
	ExposureCompensation: number, -- 화면 전체 노출 (-3~3)
	Atmosphere: AtmosphereValues, -- Lighting 안 Atmosphere에 적용
}

export type LightingConfig = {
	Lobby: LightingPreset, -- 대기 장소 (스테이지 밖)
}

local Lighting: LightingConfig = {
	-- 늦은 오후의 밝은 하늘. 스테이지(밤)와 달라서 대기 중인지 바로 알 수 있게 (임시)
	Lobby = {
		ClockTime = 16.5,
		Brightness = 2,
		Ambient = Color3.fromRGB(80, 75, 75),
		OutdoorAmbient = Color3.fromRGB(128, 120, 115),
		ExposureCompensation = 0,
		Atmosphere = {
			Density = 0.3,
			Haze = 0.5,
			Color = Color3.fromRGB(199, 180, 160),
			Decay = Color3.fromRGB(106, 100, 110),
		},
	},
}

return Lighting
