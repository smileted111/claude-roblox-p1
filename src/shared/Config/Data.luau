--!strict
-- 플레이어 데이터 저장 (GDD 9장, 13.3). 저장은 서버 DataService가 ProfileStore로 한다.
-- 레벨·경험치 값은 GDD에 수치가 없어 임시값이다.

export type LeaderboardConfig = {
	Enabled: boolean, -- false면 OrderedDataStore에 쓰지 않는다 (자리만. 시즌 리더보드는 M3)
	SurvivedStages: string, -- 누적 생존 스테이지 OrderedDataStore 이름
	Catches: string, -- 누적 잡은 수 OrderedDataStore 이름
}

export type DataConfig = {
	StoreName: string, -- 게시된 게임에서 쓰는 ProfileStore 이름
	StudioStoreName: string, -- Studio 테스트용. 실제 플레이어 데이터와 섞이지 않게 이름을 다르게 한다
	KeyPrefix: string, -- 프로필 키 = KeyPrefix .. UserId
	Version: number, -- 저장 형식 버전. 형식이 바뀌면 올리고 DataService에서 옮겨 준다
	XpPerScore: number, -- 스테이지 점수(Config.Score) 1점당 경험치
	LevelBaseXp: number, -- 레벨 1 → 2에 필요한 경험치
	LevelXpStep: number, -- 레벨이 하나 오를 때마다 늘어나는 필요 경험치
	MaxReceipts: number, -- 처리한 개발자 상품 영수증을 기억하는 개수 (S3-6)
	Leaderboards: LeaderboardConfig,
}

local Data: DataConfig = {
	StoreName = "PlayerData_v1",
	StudioStoreName = "PlayerData_Studio_v1",
	KeyPrefix = "Player_",
	Version = 1,
	XpPerScore = 0.5, -- 임시
	LevelBaseXp = 100, -- 임시
	LevelXpStep = 50, -- 임시
	MaxReceipts = 50, -- 임시
	Leaderboards = {
		Enabled = false, -- 자리만 (docs/studio-workflow.md S3-1)
		SurvivedStages = "Leaderboard_SurvivedStages_v1",
		Catches = "Leaderboard_Catches_v1",
	},
}

return Data
