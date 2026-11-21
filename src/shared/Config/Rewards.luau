--!strict
-- 코인 보상 (GDD 3.4, 5장, 9장). 값은 모두 임시다. 실제 지급·저장은 S3-1(DataService).
-- 스테이지마다 그 스테이지 기록으로 코인을 계산하고(RecordService), 매치가 끝나면 칭호 보너스를 더한다.
-- 솔로(추격자 없이 진행한 스테이지·매치)는 모든 코인에 Config.Match.SoloRewardMultiplier(70%)를 곱한다 (GDD 5장).
-- 발전기 수리 코인 (2026-11-21 사용자 요청): 스테이지 결과가 아니라 수리하는 동안 바로 준다. 내가 고친 몫(여럿이 고치면
--   나눈 몫)이 RepairCoinStep(발전기 1대의 10%) 쌓일 때마다 RepairCoins를 계정에 더하고 저장한다 (ObjectiveService →
--   DataService.addCoins). 솔로·VIP 배율은 붙이지 않는다. 그래서 스테이지 결과의 GeneratorRepaired는 0이다.

export type RewardsConfig = {
	Survived: number, -- 제한 시간이 끝날 때까지 잡히지 않은 스테이지
	Escaped: number, -- 출구로 탈출한 스테이지 (Survived 대신)
	GeneratorRepaired: number, -- 스테이지 결과에서 발전기 1대 분량 수리 (여럿이 고치면 기여한 만큼). 수리 코인으로 옮겨 0
	RepairCoinStep: number, -- 수리 코인을 주는 단위 (발전기 1대 = 1)
	RepairCoins: number, -- RepairCoinStep만큼 고칠 때마다 바로 주는 코인
	Heal: number, -- 아군 치료 1번
	Catch: number, -- 추격자로 잡은 1명
	ChaserWin: number, -- 추격자로 생존자를 모두 잡은 스테이지
	Participation: number, -- 스테이지에 참가 (잡혀도 받음)
	LastSurvivorBonus: number, -- 매치가 끝날 때 라스트 서바이버
	BestSurvivorBonus: number, -- 매치가 끝날 때 베스트 서바이버
}

local Rewards: RewardsConfig = {
	Survived = 20, -- 임시
	Escaped = 30, -- 임시
	GeneratorRepaired = 0, -- 수리 중 바로 주는 코인(RepairCoinStep마다 RepairCoins)으로 옮김. 발전기 1대 = 10코인으로 전과 같음
	RepairCoinStep = 0.1, -- 사용자 요청: 10%마다
	RepairCoins = 1, -- 사용자 요청
	Heal = 5, -- 임시
	Catch = 15, -- 임시
	ChaserWin = 25, -- 임시
	Participation = 5, -- 임시
	LastSurvivorBonus = 100, -- 임시
	BestSurvivorBonus = 30, -- 임시
}

return Rewards
