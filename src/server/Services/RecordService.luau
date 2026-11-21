--!strict
-- RecordService: 매치 기록과 점수, 라스트 서바이버 판정 (GDD 3.2, 3.4, 9장). GDD 13.2 목록 밖에 추가한 서비스.
--
-- MatchService가 매치를 시작할 때 startMatch, StageService가 스테이지마다 startStage → finishStage,
-- 매치가 끝나면 MatchService가 finishMatch를 부른다. 매치 진행 상황은 저장하지 않는다 (GDD 13.3).
-- 스테이지 중 기여는 각 서비스가 알린다: addCatch(CatchService), addHeal(CatchService), addGeneratorProgress(S2-2).
--
-- 점수 (Config.Score): 생존 또는 탈출, 발전기 수리 기여, 치료, 추격자로 잡은 수와 승리.
-- 라스트 서바이버 (GDD 3.4, 질문지 Q1-5): 매치의 모든 스테이지에 참가했고(늦게 들어오거나 나가지 않음),
--   한 번도 잡히지 않았고, 생존자로 한 번 이상 살아남은 사람. 추격자였던 스테이지는 실패로 치지 않는다
--   (추격자는 스테이지마다 바뀌므로 3명 이상이면 모두 한 번은 추격자가 되기 때문).
-- 라스트 서바이버가 없으면 점수가 가장 높은 사람이 베스트 서바이버 (같으면 생존 스테이지가 많은 사람, 그다음 UserId순).
-- 코인 (Config.Rewards): 스테이지마다 참가·생존 또는 탈출·발전기·치료·잡은 수·추격자 승리로 계산하고,
--   매치가 끝나면 라스트 서바이버·베스트 서바이버 보너스를 더한다. 추격자 없이 진행한 스테이지(솔로)의 코인과
--   모든 스테이지가 솔로인 매치의 보너스에는 Config.Match.SoloRewardMultiplier를 곱한다 (GDD 5장).
--   VIP(Player Attribute Vip, ShopService)는 그 위에 Config.Shop.VipCoinBonus(+20%)를 더 받는다 (GDD 10장).
--   결과 화면에 보이는 코인이 실제로 받는 코인이다.
--   스테이지 코인은 스테이지가 끝날 때, 칭호 보너스는 매치가 끝날 때 DataService가 지급한다
--   (중간에 나가도 그때까지 받은 것은 남는다, GDD 8장).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local Score = require(ReplicatedStorage.Shared.Config.Score)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Types = require(ReplicatedStorage.Shared.Types)

type StageStats = {
	catches: number,
	generatorProgress: number,
	heals: number,
}

type MatchRecord = {
	stageIds: { Types.StageId },
	stageCount: number, -- 끝난 스테이지 수
	soloStages: number, -- 추격자 없이 진행한 스테이지 수
	players: { [number]: Types.MatchPlayerRecord }, -- UserId별
}

-- 스테이지가 끝났을 때 StageService가 알려주는 플레이어별 결과
export type StageEntry = {
	player: Player,
	outcome: Types.StageOutcome,
}

local RecordService = {}

local current: MatchRecord? = nil
local stageStats: { [number]: StageStats } = {} -- UserId별. 나간 사람의 기여도 스테이지 끝까지 남긴다

local function statsFor(player: Player): StageStats
	local stats = stageStats[player.UserId]
	if not stats then
		stats = { catches = 0, generatorProgress = 0, heals = 0 }
		stageStats[player.UserId] = stats
	end
	return stats
end

local function stageScore(outcome: Types.StageOutcome, stats: StageStats, chaserWon: boolean): number
	local score = stats.generatorProgress * Score.GeneratorRepaired
		+ stats.heals * Score.Heal
		+ stats.catches * Score.Catch
	if outcome == "Survived" then
		score += Score.Survived
	elseif outcome == "Escaped" then
		score += Score.Escaped
	elseif outcome == "Chaser" and chaserWon then
		score += Score.ChaserWin
	end
	return math.round(score)
end

-- VIP면 코인 배율 (1 + VipCoinBonus)
local function vipMultiplier(player: Player?): number
	return if player and MatchState.isVip(player) then 1 + Shop.VipCoinBonus else 1
end

local function stageCoins(
	outcome: Types.StageOutcome,
	stats: StageStats,
	chaserWon: boolean,
	solo: boolean,
	vip: number
): number
	if outcome == "Left" or outcome == "Absent" then
		return 0
	end
	local coins = Rewards.Participation
		+ stats.generatorProgress * Rewards.GeneratorRepaired
		+ stats.heals * Rewards.Heal
		+ stats.catches * Rewards.Catch
	if outcome == "Survived" then
		coins += Rewards.Survived
	elseif outcome == "Escaped" then
		coins += Rewards.Escaped
	elseif outcome == "Chaser" and chaserWon then
		coins += Rewards.ChaserWin
	end
	if solo then
		coins *= Match.SoloRewardMultiplier
	end
	return math.round(coins * vip)
end

local function newRecord(userId: number, name: string, stageCount: number): Types.MatchPlayerRecord
	local stages: { Types.StageOutcome } = {}
	for index = 1, stageCount do
		stages[index] = "Absent"
	end
	local record: Types.MatchPlayerRecord = {
		userId = userId,
		name = name,
		stages = stages,
		survivedStages = 0,
		escapes = 0,
		catches = 0,
		generatorProgress = 0,
		heals = 0,
		chaserWins = 0,
		score = 0,
		coins = 0,
		bonusCoins = 0,
		lastSurvivor = false,
	}
	return record
end

local function isLastSurvivor(record: Types.MatchPlayerRecord, stageCount: number): boolean
	if record.survivedStages == 0 then
		return false
	end
	for index = 1, stageCount do
		local outcome = record.stages[index]
		if outcome ~= "Survived" and outcome ~= "Escaped" and outcome ~= "Chaser" then
			return false
		end
	end
	return true
end

-- 새 매치를 시작한다. stageIds는 이번 매치의 스테이지 순서.
function RecordService.startMatch(stageIds: { Types.StageId }): ()
	current = {
		stageIds = table.clone(stageIds),
		stageCount = 0,
		soloStages = 0,
		players = {},
	}
	table.clear(stageStats)
end

-- 매치를 기록 없이 끝낸다 (오류·인원 부족으로 중단).
function RecordService.abortMatch(): ()
	current = nil
	table.clear(stageStats)
end

function RecordService.startStage(): ()
	table.clear(stageStats)
end

-- 추격자가 생존자를 잡았다 (괴물이 잡은 것은 세지 않음).
function RecordService.addCatch(chaser: Player): ()
	statsFor(chaser).catches += 1
end

function RecordService.addHeal(healer: Player): ()
	statsFor(healer).heals += 1
end

-- 발전기 수리 기여. amount는 발전기 1대를 1로 본 비율.
function RecordService.addGeneratorProgress(player: Player, amount: number): ()
	statsFor(player).generatorProgress += amount
end

-- 스테이지 결과를 기록하고 클라이언트에 보낼 결과를 돌려준다.
function RecordService.finishStage(
	stageId: Types.StageId,
	entries: { StageEntry },
	chaser: Player?,
	chaserWon: boolean
): Types.StageResult
	local record = current
	local stageIndex = 1
	if record then
		record.stageCount += 1
		stageIndex = record.stageCount
		if not chaser then
			record.soloStages += 1
		end
	end

	local players: { Types.StagePlayerResult } = {}
	for _, entry in entries do
		local player = entry.player
		local stats = statsFor(player)
		local score = stageScore(entry.outcome, stats, chaserWon)
		local coins = stageCoins(entry.outcome, stats, chaserWon, chaser == nil, vipMultiplier(player))
		table.insert(players, {
			userId = player.UserId,
			name = player.DisplayName,
			outcome = entry.outcome,
			catches = stats.catches,
			generatorProgress = math.round(stats.generatorProgress * 100) / 100,
			heals = stats.heals,
			score = score,
			coins = coins,
		})

		if record then
			local matchRecord = record.players[player.UserId]
			if not matchRecord then
				matchRecord = newRecord(player.UserId, player.DisplayName, #record.stageIds)
				record.players[player.UserId] = matchRecord
			end
			matchRecord.stages[stageIndex] = entry.outcome
			if entry.outcome == "Survived" or entry.outcome == "Escaped" then
				matchRecord.survivedStages += 1
			end
			if entry.outcome == "Escaped" then
				matchRecord.escapes += 1
			end
			matchRecord.catches += stats.catches
			matchRecord.generatorProgress += stats.generatorProgress
			matchRecord.heals += stats.heals
			matchRecord.score += score
			matchRecord.coins += coins
			if entry.outcome == "Chaser" and chaserWon then
				matchRecord.chaserWins += 1
			end
		end
	end
	table.sort(players, function(a: Types.StagePlayerResult, b: Types.StagePlayerResult): boolean
		return a.userId < b.userId
	end)
	table.clear(stageStats)

	return {
		stageId = stageId,
		stageIndex = stageIndex,
		solo = chaser == nil,
		chaserUserId = if chaser then chaser.UserId else nil,
		chaserWon = chaserWon,
		players = players,
	}
end

-- 매치를 끝내고 최종 결과를 돌려준다. 끝난 스테이지가 없으면 nil.
function RecordService.finishMatch(): Types.MatchResult?
	local record = current
	current = nil
	if not record or record.stageCount == 0 then
		return nil
	end

	local players: { Types.MatchPlayerRecord } = {}
	local lastSurvivorUserIds: { number } = {}
	for _, matchRecord in record.players do
		matchRecord.generatorProgress = math.round(matchRecord.generatorProgress * 100) / 100
		matchRecord.lastSurvivor = isLastSurvivor(matchRecord, record.stageCount)
		if matchRecord.lastSurvivor then
			table.insert(lastSurvivorUserIds, matchRecord.userId)
		end
		table.insert(players, matchRecord)
	end
	-- 점수 높은 순 (같으면 생존 스테이지 많은 순, UserId순)
	table.sort(players, function(a: Types.MatchPlayerRecord, b: Types.MatchPlayerRecord): boolean
		if a.score ~= b.score then
			return a.score > b.score
		end
		if a.survivedStages ~= b.survivedStages then
			return a.survivedStages > b.survivedStages
		end
		return a.userId < b.userId
	end)
	table.sort(lastSurvivorUserIds)

	local best: number? = nil
	if #lastSurvivorUserIds == 0 and players[1] and players[1].score > 0 then
		best = players[1].userId
	end
	-- 칭호 보너스 코인
	local solo = record.soloStages == record.stageCount
	local multiplier = if solo then Match.SoloRewardMultiplier else 1
	for _, matchRecord in players do
		local vip = vipMultiplier(Players:GetPlayerByUserId(matchRecord.userId))
		if matchRecord.lastSurvivor then
			matchRecord.bonusCoins = math.round(Rewards.LastSurvivorBonus * multiplier * vip)
		elseif matchRecord.userId == best then
			matchRecord.bonusCoins = math.round(Rewards.BestSurvivorBonus * multiplier * vip)
		end
		matchRecord.coins += matchRecord.bonusCoins
	end
	return {
		stageIds = table.move(record.stageIds, 1, record.stageCount, 1, {}),
		players = players,
		lastSurvivorUserIds = lastSurvivorUserIds,
		bestSurvivorUserId = best,
		solo = solo,
	}
end

function RecordService.Init(): () end

function RecordService.Start(): () end

return RecordService
