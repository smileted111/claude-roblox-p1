--!strict
-- 채팅 메시지 이름(PrefixText) 꾸미기를 한 곳에서 한다 (GDD 8장 관전자 채팅, 10장 VIP 이름 색상).
-- TextChatService.OnIncomingMessage는 하나만 둘 수 있고 채널별 콜백과 겹치면 서로 덮어쓰므로,
-- 컨트롤러들은 addPrefixer로 꾸밈 함수를 더하고 여기서 차례로 적용한다.
--   SpectateController: 관전자 채널 메시지 앞에 [관전]
--   ShopController: VIP(Player Attribute Vip)의 이름에 [VIP]와 색 (Config.Shop.VipNameColor)

local TextChatService = game:GetService("TextChatService")

export type Prefixer = (message: TextChatMessage, prefix: string) -> string

local ChatStyle = {}

local prefixers: { Prefixer } = {}
local installed = false

local function onIncomingMessage(message: TextChatMessage): TextChatMessageProperties
	local prefix = message.PrefixText
	for _, prefixer in prefixers do
		prefix = prefixer(message, prefix)
	end
	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = prefix
	return properties
end

-- 꾸밈 함수를 더한다. 처음 부를 때 TextChatService.OnIncomingMessage를 건다 (새 채팅 시스템일 때만).
function ChatStyle.addPrefixer(prefixer: Prefixer): ()
	table.insert(prefixers, prefixer)
	if not installed and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		installed = true
		TextChatService.OnIncomingMessage = onIncomingMessage
	end
end

return ChatStyle
