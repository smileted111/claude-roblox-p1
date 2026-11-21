--!strict
-- 서버와 클라이언트가 함께 쓰는 타입 (GDD 2·4·6·7장). 값은 없고 타입만 내보낸다.
-- 사용: local Types = require(ReplicatedStorage.Shared.Types) → Types.Role

-- 역할 (GDD 2장). 잡히거나 탈출한 생존자는 그 스테이지가 끝날 때까지 Spectator가 된다.
export type Role = "Survivor" | "Chaser" | "Spectator"

-- 생존자 상태 (GDD 2.2, 3.1). 정상 → 부상 → 잡힘. 출구로 나가면 탈출.
export type SurvivorState = "Normal" | "Injured" | "Caught" | "Escaped"

-- 매치 단계 (GDD 3.1, 3.4)
export type MatchPhase = "Waiting" | "RoleReveal" | "Preparation" | "Chase" | "StageResult" | "MatchResult"

-- 스테이지 (GDD 4.2). 맵은 ServerStorage.Maps.<StageId>
export type StageId = "Stage1" | "Stage2" | "Stage3" | "Stage4" | "Stage5"

-- 괴물 (GDD 4.1): 배회자, 사냥개, 감시자, 그림자, 거인
export type MonsterId = "Wanderer" | "Hound" | "Watcher" | "Shadow" | "Giant"

-- 괴물 AI 상태 (GDD 4.4). 대기(추격 단계 밖) → 순찰 → 의심 → 추격 → 공격, 놓치면 포기한 뒤 순찰로 돌아감.
-- 사냥개의 소리 돌진은 Chase, 움직이지 않는 감시자는 Patrol(감시)·Alert(경보)
export type MonsterAIState = "Idle" | "Patrol" | "Suspicious" | "Chase" | "Attack" | "GiveUp" | "Alert"

-- 추격자 (GDD 7.1): 사냥꾼, 추적자, 망령, 조종자
export type ChaserId = "Hunter" | "Tracker" | "Wraith" | "Puppeteer"

-- 생존자 아이템 (GDD 6.3): 손전등, 붕대, 연막탄, 알람시계, 에너지 드링크
export type ItemId = "Flashlight" | "Bandage" | "SmokeBomb" | "AlarmClock" | "EnergyDrink"

-- 괴물이 생존자를 알아채는 방법 (GDD 4.1, 4.4)
export type Sense = "Sight" | "Sound"

-- 추격자 고유 스킬 (GDD 7.1): 돌진, 흔적 보기, 순간이동, 괴물 부르기
export type SkillKind = "Dash" | "RevealFootprints" | "Blink" | "CallMonsters"

-- 추격자 해금 방법 (GDD 7.1)
export type UnlockKind = "Default" | "Coins"

-- 추격자 화면에 생존자 위치를 잠깐 표시하는 이유 (GDD 4.1 감시자 경보, 6.2 발전기 소리)
export type MarkerReason = "WatcherAlert" | "GeneratorNoise"

-- 괴물(사냥개)이 반응하는 소리 (GDD 4.1, 6.2, 6.3). server/Util/NoiseBus
export type NoiseKind = "Running" | "Generator" | "Alarm"

-- 클라이언트 효과음 (Config.Assets.Sounds, SoundController)
export type SoundKey = "ChaserAttack" | "SurvivorHit" | "SurvivorCaught" | "SurvivorHealed"

-- 클라이언트 애니메이션 (Config.Assets.Animations)
export type AnimationKey = "ChaserAttack"

-- 한 스테이지에서 플레이어 한 명의 결과 (GDD 3.2)
--   Survived 제한 시간이 끝날 때까지 잡히지 않음 / Escaped 출구로 탈출 / Caught 잡힘 / Chaser 그 스테이지의 추격자
--   Left 스테이지 중에 나감 / Absent 그 스테이지에 참가하지 않음 (늦게 들어옴)
export type StageOutcome = "Survived" | "Escaped" | "Caught" | "Chaser" | "Left" | "Absent"

-- 스테이지 결과의 플레이어 한 줄 (StageResult 리모트)
export type StagePlayerResult = {
	userId: number,
	name: string, -- DisplayName
	outcome: StageOutcome,
	catches: number, -- 추격자로 잡은 수
	generatorProgress: number, -- 발전기 수리 기여 (발전기 1대 = 1)
	heals: number, -- 아군 치료 횟수
	score: number, -- 이 스테이지 점수 (Config.Score)
	coins: number, -- 이 스테이지에서 받는 코인 (Config.Rewards, 솔로면 배율 적용)
}

-- 스테이지 결과 (StageResult 리모트, GDD 3.1·3.2)
export type StageResult = {
	stageId: StageId,
	stageIndex: number, -- 이번 매치의 몇 번째 스테이지인가 (1부터)
	solo: boolean, -- 추격자 없이 진행
	chaserUserId: number?, -- 처음 뽑힌 추격자
	chaserWon: boolean, -- 추격자가 남아 있고 생존자를 모두 잡음
	players: { StagePlayerResult },
}

-- 매치 기록의 플레이어 한 줄 (MatchResult 리모트, GDD 3.4)
export type MatchPlayerRecord = {
	userId: number,
	name: string,
	stages: { StageOutcome }, -- 스테이지 순서대로. 참가하지 않은 스테이지는 Absent
	survivedStages: number, -- 생존 + 탈출한 스테이지 수
	escapes: number,
	catches: number,
	generatorProgress: number,
	heals: number,
	chaserWins: number, -- 추격자로 이긴 스테이지 수
	score: number,
	coins: number, -- 이번 매치에서 받는 코인 (스테이지 코인 합 + 칭호 보너스, Config.Rewards)
	bonusCoins: number, -- 그중 매치가 끝날 때 받는 칭호 보너스 (스테이지 코인은 스테이지마다 지급)
	lastSurvivor: boolean,
}

-- 최종 결과 (MatchResult 리모트, GDD 3.4)
export type MatchResult = {
	stageIds: { StageId },
	players: { MatchPlayerRecord },
	lastSurvivorUserIds: { number }, -- 라스트 서바이버 (모든 스테이지 생존)
	bestSurvivorUserId: number?, -- 라스트 서바이버가 없을 때 최고 점수자 (베스트 서바이버)
	solo: boolean, -- 모든 스테이지를 추격자 없이 진행
}

-- 로비에서 보내는 요청 (LobbyRequest 리모트). JoinQueue: 같이 하기 구역으로 이동 (다시 하기 버튼),
-- AcceptSolo·DeclineSolo: "혼자 시작할까요?"에 대한 답
export type LobbyAction = "JoinQueue" | "AcceptSolo" | "DeclineSolo"

-- 로비의 추격자 선택 요청 (ChaserSelect 리모트)
export type ChaserSelectAction = "Select" | "Unlock"

-- 잠깐 띄우는 알림 문구의 키 (Strings.Notices)
export type NoticeKey =
	"PreparationSurvivor"
	| "PreparationSolo"
	| "PreparationChaser"
	| "ChaserReleased"
	| "SurvivorCaught"
	| "SurvivorEscaped"
	| "ExitOpened"
	| "ChaserLeft"
	| "MatchInProgress"
	| "SoloTeleporting"
	| "SoloTeleportFailed"
	| "SoloStudio"
	| "ChaserUnlocked"
	| "NotEnoughCoins"

return {}
