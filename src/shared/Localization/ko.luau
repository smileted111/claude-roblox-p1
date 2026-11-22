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
	Survivor = "에너지 코어를 모두 고쳐 탈출하거나, 끝까지 잡히지 마세요!",
	Chaser = "시간 안에 생존자를 모두 잡으세요!",
	Spectator = "다음 스테이지까지 다른 플레이어를 지켜보세요.",
}

local SurvivorStates: { [Types.SurvivorState]: string } = {
	Normal = "정상",
	Injured = "부상",
	Downed = "쓰러짐",
	Jailed = "감옥",
	Frozen = "얼음",
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
	RevealSurvivors = "위치 감지",
}

local SkillDescriptions: { [Types.SkillKind]: string } = {
	Dash = "%d초 동안 이동 속도 +%d%%",
	RevealFootprints = "%d초 동안 생존자 발자국이 보임",
	Blink = "바라보는 쪽으로 %d스터드 순간이동 (벽은 못 넘음)",
	RevealSurvivors = "%d초 동안 숨지 않은 생존자 위치가 보임",
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
	SurvivorDowned = "%s 님이 쓰러졌습니다!",
	YouAreDowned = "쓰러졌습니다! %d초 안에 동료가 붕대로 살려줘야 해요.",
	SurvivorJailed = "%s 님이 감옥에 갇혔습니다!",
	YouAreJailed = "감옥에 갇혔습니다! 동료가 감옥 둘레에 %d초 서 있으면 풀려나요.",
	JailRescued = "%s 님이 감옥을 열어 %d명이 풀려났습니다!",
	ThawedBy = "%s 님이 %s 님을 땡!",
	SurvivorRevived = "%s 님이 %s 님을 살렸습니다!",
	AttackHitPause = "공격에 성공했습니다. %d초간 멈춥니다.",
	SurvivorEscaped = "%s 님이 탈출했습니다!",
	ExitOpened = "출구가 열렸습니다! 빨리 탈출하세요!",
	ChaserLeft = "추격자 %s 님이 나갔습니다.",
	AllChasersLeft = "추격자가 모두 나갔습니다. 이번 스테이지는 괴물만 남습니다.",
	AllChasersLeftEnd = "추격자가 모두 나가 이번 스테이지를 끝냅니다.",
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
	NextGameMode = "이번 스테이지는 %s 모드입니다.",
}

-- 화면 모드 이름 (Config.VisualModes)
local Modes: { [Types.VisualMode]: string } = {
	Night = "나이트",
	Casual = "캐주얼",
}

-- 게임 모드 이름 (Config.GameModes, 2026-11-22 사용자 요청)
local GameModes: { [Types.GameMode]: string } = {
	Survival = "서바이벌",
	CopsAndRobbers = "경찰과 도둑",
	FreezeTag = "얼음땡",
}

-- 게임 모드별 역할 이름·목표·결과 문구. 목표의 %d는 Config.GameModes.Jail.RescueTime (없는 문구는 무시됨)
export type ModeTexts = {
	ChaserName: string,
	SurvivorName: string,
	ChaserGoal: string,
	SurvivorGoal: string,
	ChaserTitle: string, -- 역할 공개 룰렛 제목
	YouAreChaser: string,
	YouAreSurvivor: string,
	ChaserWins: string,
	SurvivorsWin: string,
}

local GameModeTexts: { [Types.GameMode]: ModeTexts } = {
	Survival = {
		ChaserName = "추격자",
		SurvivorName = "생존자",
		ChaserGoal = "시간 안에 생존자를 모두 잡으세요!",
		SurvivorGoal = "에너지 코어를 모두 고쳐 탈출하거나, 끝까지 잡히지 마세요! 쓰러진 동료는 붕대로 살려요.",
		ChaserTitle = "이번 추격자는",
		YouAreChaser = "당신이 추격자입니다!",
		YouAreSurvivor = "당신은 생존자입니다!",
		ChaserWins = "추격자 승리!",
		SurvivorsWin = "생존자 승리!",
	},
	CopsAndRobbers = {
		ChaserName = "경찰",
		SurvivorName = "도둑",
		ChaserGoal = "도둑을 모두 잡아 감옥에 가두세요!",
		SurvivorGoal = "에너지 코어를 고쳐 탈출하거나 끝까지 버티세요! 감옥 둘레에 %d초 서 있으면 갇힌 동료가 풀려나요.",
		ChaserTitle = "이번 경찰은",
		YouAreChaser = "당신은 경찰입니다!",
		YouAreSurvivor = "당신은 도둑입니다!",
		ChaserWins = "경찰 승리!",
		SurvivorsWin = "도둑 승리!",
	},
	FreezeTag = {
		ChaserName = "술래",
		SurvivorName = "도망자",
		ChaserGoal = "도망자를 모두 잡거나, 모두 얼음이 되게 만드세요!",
		SurvivorGoal = "잡힐 것 같으면 얼음! 언 친구 옆에서 땡을 눌러 풀어 주세요. 모두 얼면 술래가 이겨요.",
		ChaserTitle = "이번 술래는",
		YouAreChaser = "당신이 술래입니다!",
		YouAreSurvivor = "당신은 도망자입니다!",
		ChaserWins = "술래 승리!",
		SurvivorsWin = "도망자 승리!",
	},
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
	GameModes = GameModes,
	GameModeTexts = GameModeTexts,

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
		Revive = "붕대로 살리기",
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
		Objective = "에너지 코어 %d/%d", -- 발전기(Generator)의 화면 이름 (2026-11-22 사용자 요청)
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
		HitPaused = "멈춤", -- 공격에 성공한 추격자가 멈춘 동안 (Config.Catch.Attack.HitPauseTime)
		DownedStatus = "%s %d초", -- 상태 이름, 살릴 수 있는 남은 초. 예: 쓰러짐 23초
		DownedMarker = "쓰러짐 %d초", -- 쓰러진 동료 머리 위 (생존자 화면)
		DownedMarkerHint = "붕대로 살리기",
		JailLabel = "감옥 · %d명", -- 감옥 위 표시: 갇힌 사람 수
		JailRescue = "구출 중 %d%%", -- 감옥 위 표시: 구출 진행
		Freeze = "얼음", -- 얼음땡 버튼 (FreezeController)
		Thaw = "땡",
		Frozen = "얼음 중", -- 내가 얼어 있을 때 얼음 버튼
		FreezeCooldown = "얼음 %d", -- 다시 얼 수 있기까지 남은 초
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
		GeneratorNoise = "에너지 코어 소리",
		WatcherAlert = "감시자 경보",
		SkillReveal = "생존자",
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
		GameModeSection = "게임 모드",
		Votes = "%d표",
		Played = "%s (플레이함)",
		Voted = "투표 %d/%d명", -- 맵을 고른 참가자 수, 참가자 수
		Hint = "가장 많이 투표된 것으로 진행해요. 다시 누르면 바꿀 수 있어요.",
		Watching = "참가자들이 다음 맵을 투표하고 있어요.",
		Choosing = "고르는 중...", -- 머리 위 표시: 아직 맵을 고르지 않음
		WantChaser = "추격자 하고 싶어요", -- 추격자 희망 버튼 (다시 누르면 해제)
		WantChaserHint = "켠 사람 중에서 추격자를 뽑아요", -- 추격자 희망 버튼 아래 설명
		Wishers = "%d명", -- 추격자 희망 인원
		TagChaser = "추격자 희망", -- 머리 위 표시
	},

	-- 로딩 화면 (ReplicatedFirst.Loading, LoadingController). 팁은 차례로 바뀐다
	Loading = {
		Title = "라스트 서바이벌",
		Joining = "게임을 불러오는 중",
		Stage = "%s 불러오는 중", -- 맵 이름
		Lobby = "로비로 돌아가는 중",
		Teleport = "혼자 하기 서버로 이동하는 중",
		Tips = {
			"달리면 소리가 나서 사냥개가 달려와요.",
			"옷장에 숨으면 괴물이 찾지 못해요. 너무 오래 있으면 숨소리가 들려요!",
			"에너지 코어를 고치면 조금씩 코인이 쌓여요.",
			"판자를 넘어뜨리면 추격자가 잠깐 기절해요.",
			"손전등을 비추면 그림자 괴물이 잠깐 멈춰요.",
			"부상당한 친구 옆에서 눌러 치료해 줄 수 있어요.",
			"쓰러진 친구는 붕대로 살릴 수 있어요. 시간이 지나면 잡혀요!",
			"같이 하기에는 괴물이 없어요. 추격자만 피하면 돼요.",
			"경찰과 도둑: 감옥 둘레에 5초 서 있으면 갇힌 동료가 풀려나요.",
			"얼음땡: 얼음이면 술래가 못 잡아요. 언 친구 옆에서 땡을 눌러 풀어 주세요.",
			'투표 창에서 "추격자 하고 싶어요"를 켜면 추격자가 될 수 있어요.',
		},
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
		Jail = "감옥", -- 감옥 표지판 (tools/mapgen/Jails.luau)
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
