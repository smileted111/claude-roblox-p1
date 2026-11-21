--!strict
-- 거인 (GDD 2.2, 4.1, 4.4): 배회자처럼 순찰하다 생존자를 보면 쫓는다 (느림 10, 보통 시야).
--   공격에 맞으면 부상 없이 바로 잡힌다 (CatchesInstantly → CatchService.hit).
--   판자·문을 부수고 지나간다 (BreaksBarriers): 순찰·추격 중 앞쪽 BreakBarrierRadius 안의 넘어진 판자·닫힌 문을 부순다.
--   숨는 곳을 부순다 (BreaksHideSpots): 쫓던 생존자가 숨으면 그 숨는 곳으로 가서 BreakHideSpotReach 안에서 부수고 꺼낸다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterAI = require(ReplicatedStorage.Shared.Config.MonsterAI)
local Wanderer = require(script.Parent.Wanderer)
local MonsterTypes = require(script.Parent.MonsterTypes)

type Monster = MonsterTypes.Monster
type Target = MonsterTypes.Target
type Api = MonsterTypes.Api

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 쫓던 생존자가 숨었으면 그 숨는 곳으로 가서 부순다. 그렇게 했으면 true (이번 갱신은 끝).
local function huntHidden(monster: Monster, now: number, api: Api): boolean
	local target = monster.target
	if not monster.def.BreaksHideSpots or not target or not api.isHidden(target) then
		return false
	end
	local state = monster.state
	if state ~= "Chase" and state ~= "Suspicious" then
		return false
	end
	local spot = api.hiddenSpotPosition(target)
	if not spot then
		return false
	end
	monster.lastSeenAt = now -- 숨는 곳을 아는 동안은 놓치지 않는다
	monster.lastSeenPosition = spot
	if flatDistance(spot, monster.rootPart.Position) <= MonsterAI.BreakHideSpotReach then
		api.stopMoving(monster)
		api.breakHideSpot(target, `괴물 {monster.name}`)
	else
		if api.checkStuck(monster, now, true) then
			monster.forceRepath = true
		end
		api.travelTo(monster, spot, now, false)
	end
	return true
end

local function tick(monster: Monster, now: number, dt: number, targets: { Target }, api: Api): ()
	if monster.def.BreaksBarriers and monster.state ~= "Idle" and monster.state ~= "Attack" then
		local ahead = monster.rootPart.Position
			+ monster.rootPart.CFrame.LookVector * (MonsterAI.BreakBarrierRadius / 2)
		if api.breakBarriers(ahead, MonsterAI.BreakBarrierRadius, `괴물 {monster.name}`) > 0 then
			monster.forceRepath = true
		end
	end
	if huntHidden(monster, now, api) then
		return
	end
	Wanderer.tick(monster, now, dt, targets, api)
end

local Giant: MonsterTypes.Behavior = {
	tick = tick,
	onNoise = nil,
	onIdle = nil,
	onSummon = nil,
	usesPatrolRoute = true,
}

return Giant
