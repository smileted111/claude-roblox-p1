--!strict
-- 배회자 (GDD 4.1): 정해진 길을 순찰하다 생존자를 보면 쫓아온다.
-- MonsterService의 공통 상태 처리(순찰 → 의심 → 추격 → 공격 → 포기 후 순찰)를 그대로 쓴다. 그림자·거인도 이 흐름을 바탕으로 한다.

local MonsterTypes = require(script.Parent.MonsterTypes)

type Monster = MonsterTypes.Monster
type Target = MonsterTypes.Target
type Api = MonsterTypes.Api

local function tick(monster: Monster, now: number, dt: number, targets: { Target }, api: Api): ()
	local state = monster.state
	if state == "Idle" then
		api.resumePatrol(monster)
		api.tickPatrol(monster, now, targets)
	elseif state == "Patrol" then
		api.tickPatrol(monster, now, targets)
	elseif state == "Suspicious" then
		api.tickSuspicious(monster, now, dt, targets)
	elseif state == "Chase" then
		api.tickChase(monster, now, targets)
	elseif state == "Attack" then
		api.tickAttack(monster, now, targets)
	elseif state == "GiveUp" then
		api.tickGiveUp(monster, now, targets)
	end
end

local Wanderer: MonsterTypes.Behavior = {
	tick = tick,
	onNoise = nil,
	onIdle = nil,
	onSummon = nil,
	usesPatrolRoute = true,
}

return Wanderer
