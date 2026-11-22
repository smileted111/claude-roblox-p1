--!strict
-- 조종자 — 위치 감지 (GDD 7.1): 숨지 않은 생존자(연막 안 제외)의 지금 위치를 Duration초 동안 내 화면에 표시한다
-- (ChaserMarker, 감시자 경보와 같은 표시). 2026-11-22 사용자 요청으로 괴물 부르기에서 바꿨다 (같이 하기에 괴물이 없어서).
-- 보일 생존자가 없어도 쓴 것으로 본다 (모두 숨었다는 정보를 얻으므로 쿨다운이 돈다).

local ChaserTypes = require(script.Parent.ChaserTypes)

local Puppeteer: ChaserTypes.Skill = {
	use = function(context: ChaserTypes.SkillContext, api: ChaserTypes.SkillApi): boolean
		api.revealSurvivors(context.player, context.def.Duration or 0)
		return true
	end,
}

return Puppeteer
