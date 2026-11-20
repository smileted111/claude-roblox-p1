--!strict
-- 맵에 붙이는 CollectionService 태그 이름 (CLAUDE.md 맵 규칙). 코드에서는 문자열 대신 이 상수를 쓴다.
-- 스테이지 맵은 ServerStorage.Maps.<StageId>에 두고, 진행 중에는 Workspace.CurrentMap에 복제된다.

local MapTags = table.freeze({
	SurvivorSpawn = "SurvivorSpawn", -- 생존자 시작 위치 (Part)
	ChaserSpawn = "ChaserSpawn", -- 추격자 대기실 안 시작 위치 (Part)
	ChaserGate = "ChaserGate", -- 준비 시간이 끝나면 열리는 대기실 문 (Part 또는 Model)
	MonsterSpawn = "MonsterSpawn", -- 괴물 생성 위치
	PatrolPoint = "PatrolPoint", -- 괴물 순찰 지점 (Attribute Route, Order)
	HideSpot = "HideSpot", -- 숨는 곳 (Model, PrimaryPart 필요)
	Generator = "Generator", -- 목표 장치
	Exit = "Exit", -- 출구 (Attribute ExitId)
	ItemSpawn = "ItemSpawn", -- 아이템 생성 위치
	Plank = "Plank", -- 판자
	Door = "Door", -- 문
})

return MapTags
