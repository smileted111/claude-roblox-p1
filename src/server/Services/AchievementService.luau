--!strict
-- AchievementService: 배지 지급 (GDD 9장). GDD 13.2 목록 밖에 추가한 서비스 (Roblox BadgeService와 이름이 겹치지 않게).
-- 배지 ID는 Config.Badges (0이면 아직 만들지 않아 건너뜀). 결과가 정해질 때 StageService·MatchService가 부른다.
--   FirstEscape        스테이지 결과에서 출구로 탈출 (Escaped)
--   CatchAll           추격자로 한 스테이지에서 생존자를 모두 잡음 (StageResult.chaserWon)
--   FirstLastSurvivor  같이 하기 매치의 라스트 서바이버 (솔로 매치는 SoloClear로 따로)
--   SoloClear          혼자 하기 매치(모든 스테이지 솔로)의 모든 스테이지에서 살아남음 (라스트 서바이버 조건과 같음)
-- 지급: BadgeService:UserHasBadgeAsync로 이미 가졌는지 보고 AwardBadgeAsync (둘 다 pcall, 실패하면 경고만).
--   같은 서버에서 한 번 준(또는 가진 것을 확인한) 배지는 다시 묻지 않는다. 결과 처리를 멈추지 않게 task.spawn으로.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Badges = require(ReplicatedStorage.Shared.Config.Badges)
local Types = require(ReplicatedStorage.Shared.Types)

local AchievementService = {}

local known: { [number]: { [Types.BadgeKey]: boolean } } = {} -- UserId → 가진 것이 확인된 배지

local function award(userId: number, key: Types.BadgeKey): ()
	local badgeId = Badges[key]
	if badgeId == 0 then
		return
	end
	local owned = known[userId]
	if not owned then
		owned = {}
		known[userId] = owned
	end
	if owned[key] then
		return
	end
	owned[key] = true -- 확인하는 동안 다시 부르지 않게
	task.spawn(function()
		local okHas, has = pcall(function(): boolean
			return BadgeService:UserHasBadgeAsync(userId, badgeId)
		end)
		if okHas and has then
			return
		end
		local okAward, result = pcall(function(): boolean
			return BadgeService:AwardBadgeAsync(userId, badgeId)
		end)
		if okAward and result then
			print(`[Badge] {userId} 배지 {key} ({badgeId})`)
		else
			owned[key] = nil -- 다음에 다시 시도
			local reason = if okAward then "AwardBadgeAsync가 false를 돌려줌" else tostring(result)
			warn(`[Badge] {userId} 배지 {key} 지급 실패: {reason}`)
		end
	end)
end

-- 스테이지 결과 (StageService)
function AchievementService.onStageResult(result: Types.StageResult): ()
	for _, entry in result.players do
		if entry.outcome == "Escaped" then
			award(entry.userId, "FirstEscape")
		elseif entry.outcome == "Chaser" and result.chaserWon then
			award(entry.userId, "CatchAll")
		end
	end
end

-- 최종 결과 (MatchService)
function AchievementService.onMatchResult(result: Types.MatchResult): ()
	for _, userId in result.lastSurvivorUserIds do
		award(userId, if result.solo then "SoloClear" else "FirstLastSurvivor")
	end
end

function AchievementService.Init(): () end

function AchievementService.Start(): ()
	Players.PlayerRemoving:Connect(function(player: Player)
		known[player.UserId] = nil
	end)
end

return AchievementService
