--!strict
-- 카메라 (GDD 11장: 생존자·추격자 모두 3인칭, 추격자는 카메라 거리를 짧게). client/Controllers/CameraController가 쓴다.
-- 높이 제한 (2026-11-21 사용자 요청): 스테이지 안에서는 카메라가 맵 바닥 윗면 + StageCeilingHeight보다 높이 올라가지 않는다.
--   벽(높이 14) 위로 올라가 벽 너머를 내려다보지 못하게 한다. 높이는 StageService가 맵을 불러올 때 공개한다 (MatchState CameraCeiling).

export type CameraConfig = {
	ChaserMaxZoom: number, -- 추격자의 최대 카메라 거리 (스터드). 생존자는 StarterPlayer.CameraMaxZoomDistance(128) 그대로
	StageCeilingHeight: number, -- 스테이지 안 카메라 최대 높이 (바닥 윗면에서, 스터드). 벽 높이(14)보다 낮게
}

local Camera: CameraConfig = {
	ChaserMaxZoom = 14, -- 임시: Roblox 기본 시작 거리(약 12.5)보다 조금 멀게. 높이 내려다보며 생존자를 찾지 못하게
	StageCeilingHeight = 13, -- 임시: 벽 윗면(14)보다 1스터드 아래. 11이면 점프 때 카메라가 머리에 붙었다 떨어져 끊겨 보여 올림 (사용자 요청)
}

return Camera
