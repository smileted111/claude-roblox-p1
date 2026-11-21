--!strict
-- 사냥개 (GDD 4.1): 생존자가 달리는 소리·발전기 소리(·알람시계)를 들으면 그 위치로 빠르게 돌진하고,
-- ChaseGiveUpTime(5초) 안에 못 잡으면 포기한다. 시야가 없어서 순찰 중에는 보지 못하고, 아주 가까이
-- (CloseDetectRange, 벽 너머 제외) 있는 생존자만 알아챈다.
--   순찰  순찰 경로를 PatrolSpeed로 걷는다. 소리가 들리거나 가까이 생존자가 있으면 돌진
--   추격  (돌진) WalkSpeed로 소리 난 곳까지 간다. 그동안 새 소리가 나면 목표만 바꾸고 시간은 늘리지 않는다.
--         가까이 생존자가 있으면 그쪽으로 곧장 가서 공격. 소리 난 곳에 닿으면 남은 시간 동안 그 자리에서 냄새를 맡는다
--   공격  공통 처리. 끝나면 돌진으로 돌아간다
--   포기  돌진 시간이 끝남 → GiveUpTime초 뒤 순찰

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterAI = require(ReplicatedStorage.Shared.Config.MonsterAI)
local NoiseBus = require(script.Parent.Parent.Util.NoiseBus)
local MonsterTypes = require(script.Parent.MonsterTypes)

type Monster = MonsterTypes.Monster
type Target = MonsterTypes.Target
type Api = MonsterTypes.Api

-- 로그용 소리 이름
local NOISE_NAMES = {
	Running = "달리는 소리",
	Generator = "발전기 소리",
	Alarm = "알람 소리",
}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 돌진을 시작한다. 이미 돌진 중이면 목표만 바꾼다.
local function dash(monster: Monster, goal: Vector3, now: number, reason: string, api: Api): ()
	monster.noiseGoal = goal
	if monster.state == "Chase" then
		return
	end
	monster.dashUntil = now + (monster.def.ChaseGiveUpTime or 0)
	monster.target = nil
	api.stopMoving(monster)
	api.setState(monster, "Chase", reason)
end

local function tickDash(monster: Monster, now: number, targets: { Target }, api: Api): ()
	if now >= monster.dashUntil then
		api.giveUp(monster, `{monster.def.ChaseGiveUpTime}초 안에 못 잡음`)
		return
	end
	local near = api.findNearbyTarget(monster, targets, monster.def.CloseDetectRange or 0)
	if near then
		api.remember(monster, near, now)
		monster.noiseGoal = near.rootPart.Position
		if not api.tryStartAttack(monster, near, now) then
			api.moveDirect(monster, near.rootPart.Position)
		end
		return
	end
	local goal = monster.noiseGoal
	if not goal then
		api.giveUp(monster, "목표 없음")
		return
	end
	if flatDistance(goal, monster.rootPart.Position) <= MonsterAI.ArriveDistance then
		api.stopMoving(monster)
		return
	end
	if api.checkStuck(monster, now, true) then
		monster.forceRepath = true
	end
	api.travelTo(monster, goal, now, false)
end

local function tick(monster: Monster, now: number, _dt: number, targets: { Target }, api: Api): ()
	if monster.state == "Idle" then
		api.resumePatrol(monster)
	end
	local state = monster.state
	if state == "Patrol" or state == "GiveUp" then
		local near = api.findNearbyTarget(monster, targets, monster.def.CloseDetectRange or 0)
		if near then
			api.remember(monster, near, now)
			dash(monster, near.rootPart.Position, now, `{near.player.Name} 가까이`, api)
		elseif state == "Patrol" then
			api.tickPatrol(monster, now, targets)
		else
			api.tickGiveUp(monster, now, targets)
		end
	elseif state == "Chase" then
		tickDash(monster, now, targets, api)
	elseif state == "Attack" then
		api.tickAttack(monster, now, targets)
	end
end

local function onNoise(monster: Monster, noise: NoiseBus.Noise, now: number, api: Api): ()
	local state = monster.state
	if state ~= "Patrol" and state ~= "GiveUp" and state ~= "Chase" then
		return
	end
	local who = if noise.source then ` ({noise.source.Name})` else ""
	dash(monster, noise.position, now, `{NOISE_NAMES[noise.kind]}{who}`, api)
end

local Hound: MonsterTypes.Behavior = {
	tick = tick,
	onNoise = onNoise,
	onIdle = nil,
	usesPatrolRoute = true,
}

return Hound
