--!strict
-- 클라이언트 → 서버 리모트의 호출 빈도 제한 (CLAUDE.md 서버 권한). 키는 Remotes.ClientEventName.
-- 게임 규칙의 쿨다운(공격 1.5초 등)과 별개로, 비정상적으로 잦은 호출만 걸러낸다. 모두 임시값.
-- 사용: src/server/Util/RateLimit.luau의 RateLimit.new(RateLimits.ChaserAttack)

local Remotes = require(script.Parent.Parent.Remotes)

export type RateLimitRule = {
	MaxCalls: number, -- Window초 동안 허용하는 호출 수
	Window: number, -- 초
}

local RateLimits: { [Remotes.ClientEventName]: RateLimitRule } = {
	SetRunning = { MaxCalls = 10, Window = 1 },
	ChaserAttack = { MaxCalls = 4, Window = 1 },
	UseSkill = { MaxCalls = 2, Window = 1 },
	UseItem = { MaxCalls = 4, Window = 1 },
	SpectateCycle = { MaxCalls = 5, Window = 1 },
	SetChaserOptOut = { MaxCalls = 2, Window = 1 },
	ReturnToLobby = { MaxCalls = 1, Window = 5 },
	LobbyRequest = { MaxCalls = 3, Window = 2 },
	ChaserSelect = { MaxCalls = 4, Window = 2 },
	SetVisualMode = { MaxCalls = 3, Window = 2 },
	CastVote = { MaxCalls = 6, Window = 2 },
	Freeze = { MaxCalls = 2, Window = 1 },
	Thaw = { MaxCalls = 3, Window = 1 },
}

return RateLimits
