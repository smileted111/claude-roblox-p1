--!strict
-- 클라이언트 → 서버 리모트를 연결하는 공통 입구 (CLAUDE.md 서버 권한, GDD 8장).
-- 서버의 OnServerEvent는 모두 이 함수로 연결한다. handler가 불리기 전에 차례로 검사한다.
--   1. 빈도 제한: Config.RateLimits[name] (server/Util/RateLimit)
--   2. 관전자 거절: 역할이 Spectator인 플레이어의 요청은 Remotes.isSpectatorAllowed(name)가 아니면 모두 버린다.
--      잡힌 직후 잡힘 연출 중에도 역할은 이미 Spectator라 거절된다.
-- 인자 형식과 역할·단계·거리·쿨다운 검사는 handler가 한다. 인자는 클라이언트가 보낸 그대로라 unknown으로 받는다.
--
-- 사용 예:
--   RemoteHandler.connect("SetRunning", function(player: Player, wantsToRun: unknown)
--       if typeof(wantsToRun) ~= "boolean" then
--           return
--       end
--       ...
--   end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local RateLimits = require(ReplicatedStorage.Shared.Config.RateLimits)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RateLimit = require(script.Parent.RateLimit)

export type Handler = (player: Player, ...unknown) -> ()

local RemoteHandler = {}

function RemoteHandler.connect(name: Remotes.ClientEventName, handler: Handler): RBXScriptConnection
	local limiter = RateLimit.new(RateLimits[name])
	local spectatorAllowed = Remotes.isSpectatorAllowed(name)
	return Remotes.get(name).OnServerEvent:Connect(function(player: Player, ...: unknown)
		if not limiter.allow(player) then
			return
		end
		if not spectatorAllowed and MatchState.getRole(player) == "Spectator" then
			print(`[Remote] 관전자 {player.Name}의 {name} 요청 거절`)
			return
		end
		handler(player, ...)
	end)
end

return RemoteHandler
