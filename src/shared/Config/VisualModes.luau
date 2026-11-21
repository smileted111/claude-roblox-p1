--!strict
-- 화면 모드 (2026-11-21 사용자 요청): 나이트(기본, GDD 12장의 어두운 공포 분위기)와 캐주얼(밝고 귀여운 배경).
-- 게임 규칙·괴물·보상은 같고 조명과 맵 색만 다르다.
-- 고르기: 로비 패널의 [모드] 버튼 (Player Attribute VisualMode, DataService에 저장).
-- 매치 모드: 같이 하기는 대기열 다수결(같으면 Default), 혼자 하기는 본인 선택 (LobbyService.decideMode).
--   같은 매치 참가자는 모두 같은 모드라 밝기로 생기는 유불리가 없다.
-- 조명은 client/Controllers/VisualModeController, 스테이지 맵 색은 StageService가 맵을 불러올 때 (shared/Util/MapStyler).
-- 값은 모두 임시다 (화면을 보고 조정).

local Lighting = require(script.Parent.Lighting)
local Types = require(script.Parent.Parent.Types)

export type Palette = {
	WallColors: { Color3 }, -- 벽(이름 Wall이거나 Walls 폴더 안) 색. 위치에 따라 돌아가며 칠한다
	WallCellSize: number, -- 벽 색을 바꾸는 위치 간격 (스터드)
	FloorColor: Color3, -- 이름이 Floor인 파트
	PastelBlend: number, -- 그 밖의 파트 색을 흰색 쪽으로 섞는 비율 (0~1). 발전기·출구 등의 색 구분은 남는다
}

export type CasualConfig = {
	LobbyLighting: Lighting.LightingPreset,
	StageLighting: Lighting.LightingPreset, -- 모든 스테이지
	Palette: Palette,
}

export type VisualModesConfig = {
	Modes: { Types.VisualMode }, -- 고를 수 있는 모드 (버튼 순서)
	Default: Types.VisualMode, -- 저장된 값이 없거나 다수결이 같을 때
	Casual: CasualConfig,
}

local VisualModes: VisualModesConfig = {
	Modes = { "Night", "Casual" },
	Default = "Night",
	Casual = {
		-- 맑은 한낮
		LobbyLighting = {
			ClockTime = 13,
			Brightness = 3,
			Ambient = Color3.fromRGB(150, 150, 160),
			OutdoorAmbient = Color3.fromRGB(170, 170, 180),
			ExposureCompensation = 0.1,
			Atmosphere = {
				Density = 0.25,
				Haze = 0,
				Color = Color3.fromRGB(199, 220, 255),
				Decay = Color3.fromRGB(120, 160, 220),
			},
			ColorCorrection = {
				Brightness = 0.03,
				Contrast = 0.05,
				Saturation = 0.2,
				TintColor = Color3.fromRGB(255, 250, 245),
			},
		},
		-- 맑은 오후. 실내·벽 그늘도 어둡지 않게 주변광을 높게
		StageLighting = {
			ClockTime = 14,
			Brightness = 2.5,
			Ambient = Color3.fromRGB(140, 140, 150),
			OutdoorAmbient = Color3.fromRGB(160, 160, 175),
			ExposureCompensation = 0,
			Atmosphere = {
				Density = 0.2,
				Haze = 0,
				Color = Color3.fromRGB(200, 225, 255),
				Decay = Color3.fromRGB(120, 160, 220),
			},
			ColorCorrection = {
				Brightness = 0.02,
				Contrast = 0.05,
				Saturation = 0.25,
				TintColor = Color3.fromRGB(255, 255, 255),
			},
		},
		Palette = {
			WallColors = {
				Color3.fromRGB(255, 182, 213), -- 분홍
				Color3.fromRGB(170, 240, 209), -- 민트
				Color3.fromRGB(167, 214, 255), -- 하늘
				Color3.fromRGB(255, 240, 165), -- 레몬
				Color3.fromRGB(207, 186, 255), -- 라벤더
				Color3.fromRGB(255, 205, 170), -- 살구
			},
			WallCellSize = 8,
			FloorColor = Color3.fromRGB(186, 232, 160), -- 연두
			PastelBlend = 0.35,
		},
	},
}

return VisualModes
