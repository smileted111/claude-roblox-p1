--!strict
-- 배지 (GDD 9장). 배지 ID는 Creator Hub → 이 게임 → 배지(Badges)에서 만든 뒤 넣는다. 0이면 아직 없음 (주지 않음).
-- 조건은 server AchievementService에 있다.

local Types = require(script.Parent.Parent.Types)

local Badges: { [Types.BadgeKey]: number } = {
	FirstEscape = 0, -- 사용자 입력 필요: 첫 탈출 (출구로 탈출한 스테이지)
	FirstLastSurvivor = 0, -- 사용자 입력 필요: 첫 라스트 서바이버 (같이 하기 매치)
	SoloClear = 0, -- 사용자 입력 필요: 솔로 클리어 (혼자 하기 매치의 모든 스테이지에서 살아남음)
	CatchAll = 0, -- 사용자 입력 필요: 추격자로 한 스테이지에서 생존자를 모두 잡음
}

return Badges
