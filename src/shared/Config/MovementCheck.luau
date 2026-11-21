--!strict
-- 서버의 이동 거리 검사 (docs/release-review.md 코드 #1). server/Services/MovementService가 쓴다.
-- 캐릭터 이동은 클라이언트가 하므로 속도 조작·순간이동 핵을 서버가 느슨하게 막는다. 렉 있는 사람이 끌려가지 않게
-- 처음에는 기준을 넉넉하게 잡았다. 모두 임시값이다 (플레이테스트·실서버 로그를 보고 조정).
--
-- Interval초마다 수평 이동 거리를 잰다. 허용 거리 = 예산 × CorrectMultiplier + Margin
--   예산: 서버가 정한 속도(WalkSpeed, 지난 구간과 이번 구간 중 빠른 쪽)로 갈 수 있었지만 아직 가지 않은 거리.
--         렉으로 위치가 몰려 와도 봐주도록 MaxBudgetTime초 분까지 모아 둔다.
--   허용 거리를 넘으면 마지막으로 인정한 위치로 되돌리고 경고를 남긴다.
--   예산 × LogMultiplier + Margin만 넘으면 되돌리지 않고 횟수만 세어 LogInterval초마다 출력한다.

export type MovementCheckConfig = {
	Enabled: boolean, -- false면 검사하지 않는다
	Interval: number, -- 검사 간격 (초)
	MaxBudgetTime: number, -- 예산을 모아 두는 최대 시간 (초)
	LogMultiplier: number, -- 기록만 하는 기준 배율
	CorrectMultiplier: number, -- 되돌리는 기준 배율
	Margin: number, -- 허용 거리에 더하는 여유 (스터드)
	TeleportGrace: number, -- 서버가 캐릭터를 옮기거나 새로 만든 뒤 검사하지 않는 시간 (초). 옮기기 전 위치가 늦게 와도 봐줌
	LogInterval: number, -- 기록만 한 횟수를 출력하는 간격 (초)
}

local MovementCheck: MovementCheckConfig = {
	Enabled = true,
	Interval = 0.5,
	MaxBudgetTime = 1.5,
	LogMultiplier = 1.5,
	CorrectMultiplier = 2, -- 허용 속도의 2배를 넘을 때만 되돌림
	Margin = 4,
	TeleportGrace = 1.5,
	LogInterval = 10,
}

return MovementCheck
