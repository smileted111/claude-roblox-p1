--!strict
-- 게임 중 로딩 화면 (2026-11-21 사용자 요청). 서버 StageService·MatchService와 클라이언트 LoadingController가 쓴다.
-- 화면 모양과 처음 들어올 때의 시간 값은 ReplicatedFirst(src/first)에 있다 (공용 Config보다 먼저 돌아서).
-- 값은 모두 임시다.

export type LoadingConfig = {
	MinVisibleTime: number, -- 로딩 화면을 최소로 보여주는 시간 (초). 너무 짧게 번쩍이지 않게
	ReadyTimeout: number, -- 서버 로딩이 끝난 뒤 내 캐릭터가 바닥 위에 서기를 기다리는 최대 시간 (초)
	GroundCheckDistance: number, -- 캐릭터 아래로 바닥(스트리밍으로 들어온 맵 파트)을 찾는 거리 (스터드)
	PlacementTimeout: number, -- 서버가 참가자를 스테이지 시작 위치로 옮기기를 기다리는 최대 시간 (초)
	CoverTime: number, -- 서버가 Loading을 켠 뒤 맵을 바꾸고 참가자를 옮기기 전에 기다리는 시간 (초).
	--   로딩 화면이 다 덮을 때까지(ReplicatedFirst LoadingScreen의 FADE_TIME 0.35초보다 길게). 켜고 끄는 것이 같은
	--   프레임이면 클라이언트에 전달되지 않아 화면이 아예 안 뜬다.
}

local Loading: LoadingConfig = {
	MinVisibleTime = 1.2, -- 임시
	ReadyTimeout = 6, -- 임시
	GroundCheckDistance = 30, -- 임시
	PlacementTimeout = 8, -- 임시
	CoverTime = 0.4, -- 임시
}

return Loading
