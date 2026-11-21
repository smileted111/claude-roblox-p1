--!strict
-- 추적자 — 흔적 보기 (GDD 7.1): Duration초(8초) 동안 Interval초마다 숨지 않은 생존자의 발 위치를 추격자에게만 보낸다.
-- 클라이언트(ChaserController)가 그 자리에 Lifetime초 동안 빛나는 발자국을 찍는다.
-- 서버가 위치를 보내므로 추격자 화면에 아직 스트리밍되지 않은 먼 생존자의 발자국도 보인다.

local ChaserTypes = require(script.Parent.ChaserTypes)

local Tracker: ChaserTypes.Skill = {
	use = function(context: ChaserTypes.SkillContext, api: ChaserTypes.SkillApi): boolean
		local def = context.def
		local player = context.player
		local duration = def.Duration or 0
		local interval = def.Interval or 0.5
		local lifetime = def.Lifetime or 3
		task.spawn(function()
			local endsAt = os.clock() + duration
			while os.clock() < endsAt and api.isActive(player) do
				local positions = api.survivorFootPositions()
				if #positions > 0 then
					api.sendFootprints(player, positions, lifetime)
				end
				task.wait(interval)
			end
		end)
		return true
	end,
}

return Tracker
