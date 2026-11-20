--!strict
-- 플레이어별 호출 빈도 제한 (토큰 버킷). 클라이언트 → 서버 리모트 처리의 맨 앞에서 쓴다.
--
-- 플레이어마다 MaxCalls개의 토큰을 주고, Window초 동안 MaxCalls개가 고르게 다시 찬다.
-- 짧게 몰아서 MaxCalls번까지는 허용하고, 그 뒤로는 평균 빈도를 넘는 호출을 거절한다.
--
-- 사용 예:
--   local attackLimit = RateLimit.new(RateLimits.ChaserAttack)
--   Remotes.get("ChaserAttack").OnServerEvent:Connect(function(player: Player)
--       if not attackLimit.allow(player) then
--           return
--       end
--       ...
--   end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimits = require(ReplicatedStorage.Shared.Config.RateLimits)

export type RateLimiter = {
	-- 허용하면 true를 돌려주고 토큰을 1개 쓴다.
	allow: (player: Player) -> boolean,
	-- 그 플레이어의 기록을 지운다 (토큰이 가득 찬 상태로 돌아감).
	reset: (player: Player) -> (),
	-- 플레이어 퇴장 연결을 끊는다. 서버가 끝날 때까지 쓰는 제한기는 부르지 않아도 된다.
	destroy: () -> (),
}

type Bucket = {
	tokens: number,
	updatedAt: number,
}

local RateLimit = {}

function RateLimit.new(rule: RateLimits.RateLimitRule): RateLimiter
	assert(rule.MaxCalls >= 1, "RateLimit: MaxCalls는 1 이상이어야 합니다")
	assert(rule.Window > 0, "RateLimit: Window는 0보다 커야 합니다")

	local capacity = rule.MaxCalls
	local refillPerSecond = rule.MaxCalls / rule.Window
	local buckets: { [Player]: Bucket } = {}

	local function allow(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			buckets[player] = { tokens = capacity - 1, updatedAt = now }
			return true
		end

		bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.updatedAt) * refillPerSecond)
		bucket.updatedAt = now
		if bucket.tokens < 1 then
			return false
		end
		bucket.tokens -= 1
		return true
	end

	local function reset(player: Player): ()
		buckets[player] = nil
	end

	local removingConnection = Players.PlayerRemoving:Connect(reset)

	local function destroy(): ()
		removingConnection:Disconnect()
		table.clear(buckets)
	end

	return {
		allow = allow,
		reset = reset,
		destroy = destroy,
	}
end

return RateLimit
