--!strict
-- 맵에 붙이는 CollectionService 태그 이름 (CLAUDE.md 맵 규칙). 코드에서는 문자열 대신 이 상수를 쓴다.
-- 스테이지 맵은 ServerStorage.Maps.<StageId>에 두고, 진행 중에는 Workspace.CurrentMap에 복제된다.

local MapTags = table.freeze({
	SurvivorSpawn = "SurvivorSpawn", -- 생존자 시작 위치 (Part)
	ChaserSpawn = "ChaserSpawn", -- 추격자 대기실 안 시작 위치 (Part)
	ChaserGate = "ChaserGate", -- 준비 시간이 끝나면 열리는 대기실 문 (Part 또는 Model)
	MonsterSpawn = "MonsterSpawn", -- 괴물 생성 위치 (Attribute Monster: 그 종류를 먼저 놓을 자리. 없어도 됨)
	PatrolPoint = "PatrolPoint", -- 괴물 순찰 지점 (Attribute Route, Order)
	HideSpot = "HideSpot", -- 숨는 곳 (Model, PrimaryPart 필요. PrimaryPart 앞면(LookVector)이 열린 쪽)
	Generator = "Generator", -- 목표 장치
	Exit = "Exit", -- 출구 (Attribute ExitId)
	ItemSpawn = "ItemSpawn", -- 아이템 생성 위치
	Plank = "Plank", -- 판자 (Model: Board 파트 + 넘어진 자리 FallenPose 파트)
	Door = "Door", -- 문 (Model: Panel 파트 + 열린 자리 OpenPose 파트)
	DarkZone = "DarkZone", -- 어두운 구역 (보이지 않고 부딪히지 않는 상자. 그림자 괴물이 거의 투명해짐, S3-4)
	-- 감옥 (경찰과 도둑 모드, Model): Inside(갇힌 사람을 놓는 곳)·ReleasePoint(풀려난 사람이 서는 곳)·RescueZone(구출 구역 상자)
	-- 파트(모두 투명)와 막힌 우리. 다른 모드에서는 StageService가 맵에서 지운다 (server JailService)
	Jail = "Jail",
	-- 로비 (Workspace.Lobby, 맵 폴더가 아님)
	LobbyTogether = "LobbyTogether", -- 같이 하기 구역 발판. 위에 서 있으면 대기열
	LobbySolo = "LobbySolo", -- 혼자 하기 발판. "혼자 하기" 프롬프트가 생김
})

return MapTags
