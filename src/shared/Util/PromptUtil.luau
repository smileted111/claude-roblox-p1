--!strict
-- ProximityPrompt를 만들 때 쓰는 공용 함수. 모든 상호작용 프롬프트의 키를 Config.Input으로 맞춘다
-- (추격자 스킬 키 E와 겹치지 않게 키보드 F, 게임패드 X).

local Input = require(script.Parent.Parent.Config.Input)

local PromptUtil = {}

function PromptUtil.new(): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.KeyboardKeyCode = Input.InteractKey
	prompt.GamepadKeyCode = Input.InteractGamepad
	return prompt
end

return PromptUtil
