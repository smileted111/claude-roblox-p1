--!strict
-- 서버와 클라이언트가 함께 쓰는 타입 (GDD 2·4·6·7장). 값은 없고 타입만 내보낸다.
-- 사용: local Types = require(ReplicatedStorage.Shared.Types) → Types.Role

-- 역할 (GDD 2장). 잡히거나 탈출한 생존자는 그 스테이지가 끝날 때까지 Spectator가 된다.
export type Role = "Survivor" | "Chaser" | "Spectator"

-- 생존자 상태 (GDD 2.2, 3.1). 정상 → 부상 → 잡힘. 출구로 나가면 탈출.
-- 쓰러짐 (2026-11-22 사용자 요청): 추격자가 있는 스테이지(같이 하기)에서 부상 상태로 맞으면 그 자리에 쓰러진다.
--   동료가 붕대로 살리면 부상으로 일어나고, Config.Catch.Revive.DownedTime초 안에 못 살리면 잡힘.
-- 감옥 (경찰과 도둑 모드, 2026-11-22 사용자 요청): 부상 상태로 맞으면 감옥에 갇힌다. 동료가 감옥 둘레에 5초 서 있으면 정상으로 풀려남.
-- 얼음 (얼음땡 모드, 2026-11-22 사용자 요청): 스스로 얼면 움직이지 못하고 술래도 잡지 못한다. 다른 사람이 땡 하면 얼기 전 상태로.
export type SurvivorState = "Normal" | "Injured" | "Downed" | "Jailed" | "Frozen" | "Caught" | "Escaped"

-- 매치 단계 (GDD 3.1, 3.4). Voting: 스테이지마다 맵(첫 스테이지는 화면 모드도) 투표 (VoteService)
export type MatchPhase = "Waiting" | "Voting" | "RoleReveal" | "Preparation" | "Chase" | "StageResult" | "MatchResult"

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

-- 추격자 고유 스킬 (GDD 7.1): 돌진, 흔적 보기, 순간이동, 위치 감지 (조종자. 2026-11-22 괴물 부르기에서 바꿈)
export type SkillKind = "Dash" | "RevealFootprints" | "Blink" | "RevealSurvivors"

-- 추격자 해금 방법 (GDD 7.1)
export type UnlockKind = "Default" | "Coins"

-- 추격자 화면에 생존자 위치를 잠깐 표시하는 이유 (GDD 4.1 감시자 경보, 6.2 발전기 소리, 7.1 조종자 위치 감지)
export type MarkerReason = "WatcherAlert" | "GeneratorNoise" | "SkillReveal"

-- 움직이지 못하는 이유 (MovementService.stun, Player Attribute Stunned): 판자에 맞음 / 공격에 성공한 추격자가 멈춤
export type StunReason = "Plank" | "AttackHit"

-- 괴물(사냥개)이 반응하는 소리 (GDD 4.1, 6.2, 6.3). server/Util/NoiseBus
export type NoiseKind = "Running" | "Generator" | "Alarm"

-- 클라이언트 효과음 (Config.Assets.Sounds, SoundController)
export type SoundKey = "ChaserAttack" | "SurvivorHit" | "SurvivorCaught" | "SurvivorHealed"

-- 클라이언트 애니메이션 (Config.Assets.Animations)
export type AnimationKey = "ChaserAttack" | "VipEmote"

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
	chaserUserIds: { number }, -- 처음 뽑힌 추격자들 (솔로면 빈 배열)
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

-- 화면 모드 (Config.VisualModes): 나이트 = 어두운 공포 분위기(기본), 캐주얼 = 밝고 귀여운 배경
export type VisualMode = "Night" | "Casual"

-- 게임 모드 (Config.GameModes, 2026-11-22 사용자 요청). 같이 하기(추격자가 있는 스테이지)에서 스테이지마다 투표로 정한다.
--   Survival: 부상 상태로 맞으면 쓰러지고 동료가 붕대로 살림 / CopsAndRobbers: 경찰과 도둑. 잡히면 감옥, 동료가 5초 만져 구출
--   FreezeTag: 얼음땡. 얼음이면 잡히지 않고 다른 사람이 땡 해야 풀림 (참가자 3명 이상)
export type GameMode = "Survival" | "CopsAndRobbers" | "FreezeTag"

-- 서버가 공개하는 로딩 단계 (MatchState Loading, client LoadingController): 스테이지 맵을 불러와 옮기는 중 / 로비로 돌아가는 중
export type LoadingKind = "Stage" | "Lobby"

-- 투표 종류 (CastVote 리모트, VoteService): 맵, 화면 모드, 게임 모드, 추격자 희망 (켜고 끄기)
export type VoteKind = "Map" | "Mode" | "GameMode" | "Chaser"

-- 로비의 추격자 선택 요청 (ChaserSelect 리모트)
export type ChaserSelectAction = "Select" | "Unlock"

-- 조작 동작 (client InputController, Config.Input.Bindings). Item은 휴대폰 화면 버튼 전용(아이템이 있는 첫 칸을 씀)
-- Freeze·Thaw는 얼음땡 모드의 얼음·땡 (FreezeController)
export type InputAction =
	"Run"
	| "Item"
	| "Item1"
	| "Item2"
	| "Attack"
	| "Skill"
	| "SpectatePrevious"
	| "SpectateNext"
	| "Freeze"
	| "Thaw"

-- 지금 쓰는 입력 장치 (마지막 입력 종류로 정함). 화면의 키 안내와 휴대폰 버튼 표시를 바꾼다
export type InputPlatform = "KeyboardMouse" | "Gamepad" | "Touch"

-- 배지 (GDD 9장, Config.Badges)
export type BadgeKey = "FirstEscape" | "FirstLastSurvivor" | "SoloClear" | "CatchAll"

-- 휴대폰 화면 버튼 (GDD 11장: 달리기, 상호작용, 아이템, 스킬)
export type TouchButtonId = "Run" | "Interact" | "Item" | "Skill" | "Attack"

-- 잠깐 띄우는 알림 문구의 키 (Strings.Notices)
export type NoticeKey =
	"PreparationSurvivor"
	| "PreparationSolo"
	| "PreparationChaser"
	| "ChaserReleased"
	| "SurvivorCaught"
	| "SurvivorDowned"
	| "YouAreDowned"
	| "SurvivorRevived"
	| "SurvivorJailed"
	| "YouAreJailed"
	| "JailRescued"
	| "ThawedBy"
	| "AttackHitPause"
	| "SurvivorEscaped"
	| "ExitOpened"
	| "ChaserLeft"
	| "AllChasersLeft"
	| "AllChasersLeftEnd"
	| "MatchInProgress"
	| "SoloTeleporting"
	| "SoloTeleportFailed"
	| "SoloStudio"
	| "ChaserUnlocked"
	| "NotEnoughCoins"
	| "CoinsPurchased"
	| "VipActivated"
	| "MatchMode"
	| "NextMap"
	| "NextGameMode"

return {}
