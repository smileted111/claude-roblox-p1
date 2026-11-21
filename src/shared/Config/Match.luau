--!strict
-- 매치 흐름과 시간 (GDD 1·2·3·5·8장). 추격 단계 제한 시간은 스테이지마다 달라서 Stages.TimeLimit에 있다.
-- "임시"라고 적은 값은 GDD에 수치가 없어 정한 초기값이다.

local Types = require(script.Parent.Parent.Types)

export type MatchConfig = {
	MinPlayers: number, -- 매치를 시작하는 최소 인원 (혼자 하기 서버)
	MinTogetherPlayers: number, -- 같이 하기 구역에 이만큼 모이면 매치를 시작 (일반 서버)
	MaxPlayers: number,
	LobbyWaitTime: number, -- 대기 단계 시간 (초)
	RoleRevealTime: number, -- 역할 공개 룰렛 (초)
	PreparationTime: number, -- 준비: 생존자는 흩어지고 추격자는 대기실 (초)
	StageResultTime: number, -- 스테이지 결과 표시 (초)
	MatchResultTime: number, -- 최종 결과 표시 (초)
	StageOrder: { Types.StageId }, -- 한 매치에 나오는 스테이지 순서
	ChaserCount: number, -- 스테이지마다 뽑는 추격자 수
	MinPlayersForChaser: number, -- 이 인원 이상이면 추격자를 뽑음. 아래면 솔로 (괴물만)
	DefaultChaser: Types.ChaserId, -- 추격자 종류. 로비에서 고르는 기능(S3-3) 전까지 모든 추격자가 이 종류
	CaughtEffectTime: number, -- 잡힘 연출 뒤 관전 시작까지 (초)
	SpectateSwitchDelay: number, -- 관전 대상이 잡히면 다음 대상으로 넘어가기까지 (초)
	SoloOfferWaitTime: number, -- 같이 하기 대기 중 혼자면 솔로를 제안하기까지 (초)
	SoloStartDelay: number, -- 혼자 하기 서버에 들어온 뒤 매치를 시작하기까지 (초)
	QueueZoneHeight: number, -- 같이 하기 발판 위로 이 높이까지 서 있으면 대기열 (스터드)
	SoloRewardMultiplier: number, -- 솔로 보상 배율
	PhaseTickInterval: number, -- 단계 타이머가 남은 시간을 갱신하고 조기 종료 조건을 확인하는 간격 (초)
}

local Match: MatchConfig = {
	MinPlayers = 1,
	MinTogetherPlayers = 2, -- GDD 5장: 혼자면 30초 뒤 솔로를 제안
	MaxPlayers = 8,
	LobbyWaitTime = 10, -- docs/studio-workflow.md S1-3
	RoleRevealTime = 5,
	PreparationTime = 15,
	StageResultTime = 10,
	MatchResultTime = 15, -- 임시
	StageOrder = { "Stage1", "Stage2", "Stage3" },
	ChaserCount = 1,
	MinPlayersForChaser = 2,
	DefaultChaser = "Hunter", -- 임시: 기본 해금 추격자 (GDD 7.1)
	CaughtEffectTime = 2,
	SpectateSwitchDelay = 1,
	SoloOfferWaitTime = 30,
	SoloStartDelay = 5, -- 임시
	QueueZoneHeight = 10, -- 임시
	SoloRewardMultiplier = 0.7,
	PhaseTickInterval = 0.2, -- 임시
}

return Match
