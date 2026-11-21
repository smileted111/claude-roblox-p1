--!strict
-- 한국어 문구 (원본 언어). 키와 타입은 이 파일이 정하고, en.luau가 같은 키로 영어를 둔다 (Localization 참고).
-- %d·%s가 들어간 문구는 string.format으로 채운다. 예: string.format(Strings.Hud.SurvivorsLeft, 3)
--   번역도 같은 서식 지정자를 같은 순서로 써야 한다 (LanguageService가 Studio에서 검사).
-- 바뀔 수 있는 수치(시간, 속도 등)는 문구에 직접 쓰지 않고 Config 값으로 채운다.

local Types = require(script.Parent.Parent.Types)

local Roles: { [Types.Role]: string } = {
	Survivor = "생존자",
	Chaser = "추격자",
	Spectator = "관전자",
}

-- 역할 공개 화면의 목표 한 줄 (GDD 1.3, 11장)
local RoleGoals: { [Types.Role]: string } = {
	Survivor = "발전기를 모두 고쳐 탈출하거나, 끝까지 잡히지 마세요!",
	Chaser = "시간 안에 생존자를 모두 잡으세요!",
	Spectator = "다음 스테이지까지 다른 플레이어를 지켜보세요.",
}

local SurvivorStates: { [Types.SurvivorState]: string } = {
	Normal = "정상",
	Injured = "부상",
	Caught = "잡힘",
	Escaped = "탈출",
}

local Phases: { [Types.MatchPhase]: string } = {
	Waiting = "대기",
	Voting = "투표",
	RoleReveal = "역할 공개",
	Preparation = "준비",
	Chase = "추격",
	StageResult = "스테이지 결과",
	MatchResult = "최종 결과",
}

-- 맵 이름 (GDD 4.2)
local Stages: { [Types.StageId]: string } = {
	Stage1 = "학교",
	Stage2 = "폐병원",
	Stage3 = "지하 연구소",
	Stage4 = "놀이공원",
	Stage5 = "폐쇄된 지하철",
}

local Monsters: { [Types.MonsterId]: string } = {
	Wanderer = "배회자",
	Hound = "사냥개",
	Watcher = "감시자",
	Shadow = "그림자",
	Giant = "거인",
}

local Chasers: { [Types.ChaserId]: string } = {
	Hunter = "사냥꾼",
	Tracker = "추적자",
	Wraith = "망령",
	Puppeteer = "조종자",
}

-- 추격자 스킬 이름과 설명 (GDD 7.1). 설명의 %d는 Config.Chasers 값으로 채운다
local Skills: { [Types.SkillKind]: string } = {
	Dash = "돌진",
	RevealFootprints = "흔적 보기",
	Blink = "순간이동",
	CallMonsters = "괴물 부르기",
}

local SkillDescriptions: { [Types.SkillKind]: string } = {
	Dash = "%d초 동안 이동 속도 +%d%%",
	RevealFootprints = "%d초 동안 생존자 발자국이 보임",
	Blink = "바라보는 쪽으로 %d스터드 순간이동 (벽은 못 넘음)",
	CallMonsters = "가장 가까운 괴물 %d마리를 내 자리로 부름",
}

local Items: { [Types.ItemId]: string } = {
	Flashlight = "손전등",
	Bandage = "붕대",
	SmokeBomb = "연막탄",
	AlarmClock = "알람시계",
	EnergyDrink = "에너지 드링크",
}

local Notices: { [Types.NoticeKey]: string } = {
	PreparationSurvivor = "흩어져서 숨을 곳을 찾으세요! 곧 추격자가 풀려납니다.",
	PreparationSolo = "흩어져서 숨을 곳을 찾으세요! 곧 괴물이 움직입니다.",
	PreparationChaser = "곧 대기실 문이 열립니다.",
	ChaserReleased = "추격자가 풀려났습니다!",
	SurvivorCaught = "%s 님이 잡혔습니다.",
	SurvivorEscaped = "%s 님이 탈출했습니다!",
	ExitOpened = "출구가 열렸습니다! 빨리 탈출하세요!",
	ChaserLeft = "추격자가 나갔습니다. 이번 스테이지는 괴물만 남습니다.",
	MatchInProgress = "매치가 진행 중입니다. 로비에서 다음 매치를 기다려 주세요.",
	SoloTeleporting = "혼자 하기 서버로 이동하는 중...",
	SoloTeleportFailed = "이동하지 못했습니다. 잠시 뒤 다시 시도해 주세요.",
	SoloStudio = "Studio에서는 이 서버에서 혼자 하기를 시작합니다.",
	ChaserUnlocked = "%s 해금!",
	NotEnoughCoins = "코인이 모자랍니다.",
	CoinsPurchased = "코인 %d개를 받았습니다!",
	VipActivated = "VIP가 되었습니다! 이름 색상·로비 이모트·코인 +20%%",
	MatchMode = "이번 매치는 %s 모드입니다.",
	NextMap = "투표 결과: 이번 스테이지는 %s입니다.",
}

-- 화면 모드 이름 (Config.VisualModes)
local Modes: { [Types.VisualMode]: string } = {
	Night = "나이트",
	Casual = "캐주얼",
}

local Ko = {
	Roles = Roles,
	RoleGoals = RoleGoals,
	SurvivorStates = SurvivorStates,
	Phases = Phases,
	Stages = Stages,
	Monsters = Monsters,
	Chasers = Chasers,
	Skills = Skills,
	SkillDescriptions = SkillDescriptions,
	Items = Items,
	Notices = Notices,
	Modes = Modes,

	-- 역할 공개 룰렛 (GDD 2.1)
	RoleReveal = {
		Choosing = "추격자를 정하는 중...",
		ChaserTitle = "이번 추격자는",
		YouAreChaser = "당신이 추격자입니다!",
		YouAreSurvivor = "당신은 생존자입니다!",
		Solo = "혼자 하기: 추격자 없이 괴물만 등장합니다.",
	},

	-- ProximityPrompt.ActionText (GDD 6장)
	Prompts = {
		Hide = "숨기",
		Unhide = "나오기",
		OpenHideSpot = "열어보기",
		Heal = "치료",
		Repair = "수리",
		PickUp = "줍기",
		PushPlank = "넘어뜨리기",
		OpenDoor = "열기",
		CloseDoor = "닫기",
	},

	-- HUD (GDD 11장)
	Hud = {
		WaitingForPlayers = "플레이어를 기다리는 중...",
		StartsIn = "%d초 후 시작",
		StageTitle = "스테이지 %d · %s",
		TimeLeft = "남은 시간",
		SurvivorsLeft = "남은 생존자 %d명",
		Objective = "발전기 %d/%d",
		Stamina = "스태미나",
		Attack = "공격",
		Skill = "스킬",
		Item = "아이템",
		Run = "달리기",
		Interact = "상호작용",
		AttackReady = "공격 가능",
		Repairing = "수리 중 %d%%",
		CoinGain = "+%d 코인", -- 스테이지 중 코인을 받았을 때 (수리 10%마다 등)
		Stunned = "기절!",
		Battery = "%s %d%%", -- 아이템 이름, 남은 배터리
		SkillReady = "%s 준비",
		SkillCooldown = "%s %d초",
		ExitOpen = "출구 열림!",
		Exit = "출구",
		Repaired = "작동 중",
		Clock = "%d:%02d", -- 분, 초. 예: 3:45
		PhaseClock = "%s %d:%02d", -- 단계 이름, 분, 초. 예: 추격 3:45
	},

	-- 조작 안내 (S3-5). 키 이름은 Config.Input.KeyNames
	Input = {
		KeyAction = "[%s] %s", -- 키, 동작. 예: [Shift] 달리기
		WithKey = "%s  [%s]", -- 상태 문구, 키. 예: 공격 가능  [클릭]
		MouseButton1 = "클릭",
		Tap = "화면 탭",
	},

	-- 추격자 화면의 위치 표시 (GDD 4.1, 6.2, 7장)
	Markers = {
		GeneratorNoise = "발전기 소리",
		WatcherAlert = "감시자 경보",
	} :: { [Types.MarkerReason]: string },

	-- 관전 (GDD 8장)
	Spectate = {
		Title = "관전 중",
		Previous = "이전",
		Next = "다음",
		NoTarget = "볼 수 있는 플레이어가 없습니다.",
		ReturnToLobby = "로비로 돌아가기",
		Joined = "%s · %s", -- 두 항목을 잇는다. 예: 생존자 · 부상, 남은 생존자 3명 · 추격 3:45
		Hidden = "숨음",
		KeyHint = "Q·E 또는 ←·→로 대상 바꾸기",
		GamepadHint = "LB·RB로 대상 바꾸기",
		ChatPrefix = "[관전]",
		ChatNotice = "관전자 채팅입니다. 메시지는 관전자끼리만 볼 수 있습니다.",
	},

	-- 서버가 연결을 끊을 때 (Player:Kick)
	System = {
		DataLoadFailed = "데이터를 불러오지 못했습니다. 다시 들어와 주세요.",
		DataSessionTaken = "다른 서버에서 데이터를 쓰고 있어 연결을 끊었습니다. 다시 들어와 주세요.",
		SoloServerFull = "혼자 하기 서버에는 들어올 수 없습니다.",
	},

	-- 로비 (GDD 3장, 5장, 11장)
	Lobby = {
		Together = "같이 하기",
		Solo = "혼자 하기",
		QueueCount = "같이 하기 대기 %d명",
		NeedMore = "한 명 더 오면 시작",
		SoloServer = "혼자 하기 서버",
		SoloOfferTitle = "혼자 시작할까요?",
		SoloOfferBody = "%d초 동안 다른 플레이어가 오지 않았습니다. 추격자 없이 괴물만 나오는 혼자 하기로 시작할까요? (보상 70%%)",
		SoloYes = "혼자 하기",
		SoloNo = "더 기다리기",
		ChaserOptOut = "추격자 안 하기",
		ChaserSelect = "추격자 선택",
		Selected = "선택됨",
		Select = "고르기",
		UnlockCost = "%d 코인 해금",
		Close = "닫기",
		Cooldown = "쿨다운 %d초",
		On = "켬",
		Off = "끔",
		Coins = "코인 %d",
		Level = "Lv %d",
		Shop = "상점",
		Emote = "이모트",
		ModeButton = "모드: %s",
		-- 로비 표지판 (Studio에서 만든 Workspace.Lobby의 SurfaceGui. 이 원문과 같아야 번역된다)
		TogetherHint = "초록 카펫 위에서 다른 플레이어를 기다려요",
		SoloHint = "파란 카펫 위에서 [혼자 하기]를 누르면 바로 시작",
	},

	-- 상점 (GDD 10장)
	Shop = {
		Title = "상점",
		Vip = "VIP",
		VipPerks = "채팅 이름 색상 · 로비 전용 이모트 · 버는 코인 +20%",
		Owned = "보유 중",
		NotReady = "준비 중",
		Robux = "R$ %d",
		Buy = "구매",
		CoinPack = "코인 %d",
		CoinsSection = "코인 구매",
		ChasersSection = "추격자 해금",
		AllUnlocked = "모두 해금했습니다",
		Unlock = "%d 코인",
		CosmeticsSection = "꾸미기",
		CosmeticsSoon = "생존자·추격자 스킨, 잡을 때 연출 (준비 중)",
		VipTag = "VIP",
	},

	-- 맵·화면 모드 투표 (VoteController)
	Vote = {
		Title = "투표",
		TimeLeft = "%d초 남음",
		ModeSection = "화면 모드",
		MapSection = "맵",
		Votes = "%d표",
		Played = "%s (플레이함)",
		Voted = "투표 %d/%d명", -- 맵을 고른 참가자 수, 참가자 수
		Hint = "가장 많이 투표된 것으로 진행해요. 다시 누르면 바꿀 수 있어요.",
		Watching = "참가자들이 다음 맵을 투표하고 있어요.",
		Choosing = "고르는 중...", -- 머리 위 표시: 아직 맵을 고르지 않음
	},

	-- 맵 표지판 (Studio에서 만든 맵·로비의 SurfaceGui. 이 원문과 같아야 번역된다)
	Signs = {
		FerrisWheel = "관람차",
		RollerCoaster = "롤러코스터",
		Viking = "바이킹",
		Carousel = "회전목마",
		HauntedHouse = "유령의 집",
		Popcorn = "팝콘",
		Souvenir = "기념품",
		IceCream = "아이스크림",
		Tickets = "매표소",
		StaffOnly = "직원 전용",
		Restroom = "화장실",
		ParkName = "별빛 놀이공원",
		Home = "우리 집",
	},

	-- 결과 (GDD 3.2, 3.4)
	Results = {
		StageTitle = "스테이지 결과",
		MatchTitle = "최종 결과",
		ChaserWins = "추격자 승리!",
		SurvivorsWin = "생존자 승리!",
		LastSurvivor = "라스트 서바이버",
		BestSurvivor = "베스트 서바이버",
		PlayAgain = "다시 하기",
		SoloSuccess = "살아남았습니다!",
		SoloFail = "잡혔습니다...",
		NoTitle = "이번 매치에는 끝까지 살아남은 사람이 없습니다.",
		Coins = "+%d 코인",
		ChaserCatches = "%d명 잡음",
		ColumnName = "이름",
		ColumnStage = "S%d",
		ColumnCatches = "잡은 수",
		ColumnCoins = "코인",
	},

	-- 스테이지 결과의 플레이어별 결과 (Types.StageOutcome)
	Outcomes = {
		Survived = "생존",
		Escaped = "탈출",
		Caught = "잡힘",
		Chaser = "추격자",
		Left = "나감",
		Absent = "-",
	} :: { [Types.StageOutcome]: string },
}

export type Text = typeof(Ko)

return Ko
