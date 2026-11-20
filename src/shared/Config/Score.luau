--!strict
-- 매치 점수 (GDD 3.4 "라스트 서바이버가 없으면 매치 최고 점수자", GDD 9장의 코인 지급 항목과 같은 기준).
-- 점수는 베스트 서바이버를 고르는 데만 쓴다. 코인은 Config.Rewards (S2-5).
-- GDD에 수치가 없어 모두 임시값이다.

export type ScoreConfig = {
	Survived: number, -- 제한 시간이 끝날 때까지 잡히지 않은 스테이지
	Escaped: number, -- 출구로 탈출한 스테이지 (Survived 대신)
	GeneratorRepaired: number, -- 발전기 1대 분량 수리 (여럿이 고치면 기여한 만큼 나눔)
	Heal: number, -- 아군 치료 1번
	Catch: number, -- 추격자로 잡은 1명
	ChaserWin: number, -- 추격자로 생존자를 모두 잡은 스테이지
}

local Score: ScoreConfig = {
	Survived = 100, -- 임시
	Escaped = 150, -- 임시
	GeneratorRepaired = 50, -- 임시
	Heal = 30, -- 임시
	Catch = 60, -- 임시
	ChaserWin = 100, -- 임시
}

return Score
