--!strict
-- 카메라 (GDD 11장: 생존자·추격자 모두 3인칭, 추격자는 카메라 거리를 짧게). client/Controllers/CameraController가 쓴다.

export type CameraConfig = {
	ChaserMaxZoom: number, -- 추격자의 최대 카메라 거리 (스터드). 생존자는 StarterPlayer.CameraMaxZoomDistance(128) 그대로
}

local Camera: CameraConfig = {
	ChaserMaxZoom = 14, -- 임시: Roblox 기본 시작 거리(약 12.5)보다 조금 멀게. 높이 내려다보며 생존자를 찾지 못하게
}

return Camera
