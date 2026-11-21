--!strict
-- 사냥꾼 — 돌진 (GDD 7.1): Duration초 동안 이동 속도 × SpeedMultiplier (2초, +50%)

local ChaserTypes = require(script.Parent.ChaserTypes)

local Hunter: ChaserTypes.Skill = {
	use = function(context: ChaserTypes.SkillContext, api: ChaserTypes.SkillApi): boolean
		local def = context.def
		api.boost(context.player, def.SpeedMultiplier or 1, def.Duration or 0)
		return true
	end,
}

return Hunter
