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

-- 잠깐 띄우는 알림 문구의 키 (Strings.Notices)
export type NoticeKey =
	"PreparationSurvivor"
	| "PreparationChaser"
	| "ChaserReleased"
	| "SurvivorCaught"
	| "SurvivorEscaped"
	| "ExitOpened"
	| "ChaserLeft"

return {}
