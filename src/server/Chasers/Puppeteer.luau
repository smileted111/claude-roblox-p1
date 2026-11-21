--!strict
-- 조종자 — 괴물 부르기 (GDD 7.1): 가장 가까운 움직이는 괴물 MonsterCount마리(2)를 추격자 자리로 부른다.
-- 불린 괴물은 Duration초 동안 그 자리로 오고, 오는 길에 생존자를 보면 평소처럼 쫓는다 (MonsterService.summon).
-- 부를 괴물이 없으면 쓰지 않은 것으로 본다 (쿨다운 없음).

local ChaserTypes = require(script.Parent.ChaserTypes)

local Puppeteer: ChaserTypes.Skill = {
	use = function(context: ChaserTypes.SkillContext, api: ChaserTypes.SkillApi): boolean
		local def = context.def
		local called = api.summonMonsters(
			context.parts.rootPart.Position,
			def.MonsterCount or 0,
			def.Duration or 0,
			`조종자 {context.player.Name}`
		)
		return called > 0
	end,
}

return Puppeteer
