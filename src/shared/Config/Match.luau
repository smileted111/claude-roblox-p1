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
	MapPool: { Types.StageId }, -- 투표로 고를 수 있는 맵 (투표 화면 순서). 한 매치에서 한 번 플레이한 맵은 다시 고를 수 없다
	StagesPerMatch: number, -- 한 매치의 스테이지 수 (맵 수보다 많으면 맵이 떨어질 때 끝남)
	VoteTime: number, -- 스테이지마다 맵(첫 스테이지는 화면 모드도) 투표 시간 (초)
	ChaserCount: number, -- 스테이지마다 뽑는 추격자 수
	MinPlayersForChaser: number, -- 이 인원 이상이면 추격자를 뽑음. 아래면 솔로 (괴물만)
	DefaultChaser: Types.ChaserId, -- 추격자 종류. 로비에서 고르는 기능(S3-3) 전까지 모든 추격자가 이 종류
	CaughtEffectTime: number, -- 잡힘 연출 뒤 관전 시작까지 (초)
	SpectateSwitchDelay: number, -- 관전 대상이 잡히면 다음 대상으로 넘어가기까지 (초)
	SoloOfferWaitTime: number, -- 같이 하기 대기 중 혼자면 솔로를 제안하기까지 (초)
	SoloStartDelay: number, -- 혼자 하기 서버에 들어온 뒤 매치를 시작하기까지 (초)
	QueueZoneHeight: number, -- 같이 하기 발판 위로 이 높이까지 서 있으면 대기열 (스터드)
	SoloPromptDistance: number, -- 혼자 하기 발판 프롬프트가 보이는 거리 (스터드, 발판 가운데에서)
	SoloPromptDistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	LobbyRespawnTimeout: number, -- 스테이지 사이에 참가자를 로비에 다시 만들 때 기다리는 최대 시간 (초)
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
	MapPool = { "Stage1", "Stage2", "Stage3", "Stage4" }, -- 학교·폐병원·지하 연구소·놀이공원 (2026-11-21 사용자 요청)
	StagesPerMatch = 3, -- GDD 1장: 3 스테이지
	VoteTime = 10, -- 2026-11-21 사용자 요청
	ChaserCount = 1,
	MinPlayersForChaser = 2,
	DefaultChaser = "Hunter", -- 임시: 기본 해금 추격자 (GDD 7.1)
	CaughtEffectTime = 2,
	SpectateSwitchDelay = 1,
	SoloOfferWaitTime = 30,
	SoloStartDelay = 5, -- 임시
	QueueZoneHeight = 10, -- 임시
	SoloPromptDistance = 10, -- 임시
	SoloPromptDistanceSlack = 4, -- 임시: 다른 프롬프트의 DistanceSlack과 비슷하게
	LobbyRespawnTimeout = 10, -- 임시
	SoloRewardMultiplier = 0.7,
	PhaseTickInterval = 0.2, -- 임시
}

return Match
