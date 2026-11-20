--!strict
-- 화면 UI의 크기·시간 값 (GDD 11장, 질문지 Q10-4). 색·글꼴은 client/Util/UiStyle에 있다.
-- GDD에 수치가 없어 모두 임시값이다. 플레이테스트 화면을 보고 조정한다.

export type RoleRevealConfig = {
	SpinTime: number, -- 룰렛이 도는 시간 (초). Match.RoleRevealTime보다 짧아야 역할 공개 단계 안에 결과가 보인다
	SpinStartInterval: number, -- 처음 이름이 바뀌는 간격 (초)
	SpinEndInterval: number, -- 멈추기 직전 이름이 바뀌는 간격 (초)
	ResultHoldTime: number, -- 룰렛이 멈춘 뒤 내 역할과 목표를 보여주는 시간 (초). 솔로는 준비 단계 시작부터
	FadeTime: number, -- 사라지는 시간 (초)
}

export type UiConfig = {
	ReferenceSize: Vector2, -- 이 화면 크기(픽셀)에서 UIScale 1. 더 작은 화면은 비율대로 줄인다
	MinScale: number, -- 휴대폰에서 줄이는 한계
	MaxScale: number,
	RoleReveal: RoleRevealConfig,
	NoticeDuration: number, -- 알림 문구를 띄워 두는 시간 (초)
	NoticeFadeTime: number, -- 알림이 사라지는 시간 (초)
	MaxNotices: number, -- 한 번에 쌓여 보이는 알림 수. 넘으면 오래된 것부터 지움
	TimerWarningTime: number, -- 추격 단계 남은 시간이 이 이하면 시계를 강조색으로 (초)
}

local Ui: UiConfig = {
	ReferenceSize = Vector2.new(1100, 620), -- 임시
	MinScale = 0.6, -- 임시
	MaxScale = 1, -- 임시
	RoleReveal = {
		SpinTime = 3, -- 임시: 역할 공개 5초 중 3초 돌고 2초 결과
		SpinStartInterval = 0.05, -- 임시
		SpinEndInterval = 0.35, -- 임시
		ResultHoldTime = 4, -- 임시: 역할 공개 남은 2초 + 준비 단계 첫 2초
		FadeTime = 0.4, -- 임시
	},
	NoticeDuration = 3.5, -- 임시
	NoticeFadeTime = 0.5, -- 임시
	MaxNotices = 3, -- 임시
	TimerWarningTime = 30, -- 임시
}

return Ui
