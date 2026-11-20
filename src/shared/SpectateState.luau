--!strict
-- 관전 모드에서 서버(SpectateService)와 클라이언트(SpectateController)가 함께 쓰는 이름 (GDD 8장).
-- 관전 상태 Attribute(Spectating, SpectateTarget)는 MatchState에 있다.
--
-- 관전자 채팅 채널: 서버가 TextChatService.TextChannels 아래에 만들고, 역할이 Spectator인 플레이어만 TextSource로 넣는다.
-- 클라이언트는 이 채널에 자기 TextSource가 있으면 입력창 대상을 이 채널로 바꾼다.

local SpectateState = {
	ChatChannelName = "Spectators",
}

return SpectateState
