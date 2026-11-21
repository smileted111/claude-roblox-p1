--!strict
-- 감시자 (GDD 4.1): 움직이지 않고 넓은 시야(SightRange·SightAngle)로 본다. 공격하지 않는다.
-- 생존자를 보면 경보 → 추격자 화면에 그 생존자 위치를 AlertMarkerDuration(5초) 동안 표시한다 (추격자에게만).
-- 같은 생존자를 계속 보고 있으면 표시가 끝날 때마다 다시 알린다. 솔로(추격자 없음)에서는 표시할 사람이 없다.
--   순찰(감시)  MonsterSpawn 파트가 보는 방향을 지켜본다
--   경보        누군가 보이는 동안. 눈 색을 AlertEyeColor로 바꿔 생존자도 들킨 것을 알 수 있다

local MonsterTypes = require(script.Parent.MonsterTypes)

type Monster = MonsterTypes.Monster
type Target = MonsterTypes.Target
type Api = MonsterTypes.Api

-- 괴물 모델의 눈 (EyeL·EyeR Neon 파트와 Head 안의 PointLight). 원래 색을 기억해 둔다.
type Eyes = {
	parts: { BasePart },
	lights: { PointLight },
	color: Color3,
}

local eyesByModel: { [Model]: Eyes } = setmetatable({}, { __mode = "k" }) :: any

local function getEyes(model: Model): Eyes
	local eyes = eyesByModel[model]
	if eyes then
		return eyes
	end
	local parts: { BasePart } = {}
	local lights: { PointLight } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant.Name == "EyeL" or descendant.Name == "EyeR") then
			table.insert(parts, descendant)
		elseif descendant:IsA("PointLight") then
			table.insert(lights, descendant)
		end
	end
	eyes = {
		parts = parts,
		lights = lights,
		color = if parts[1] then parts[1].Color else Color3.new(1, 1, 1),
	}
	eyesByModel[model] = eyes
	return eyes
end

local function setEyeColor(monster: Monster, alert: boolean): ()
	local eyes = getEyes(monster.model)
	local color = if alert then monster.def.AlertEyeColor or eyes.color else eyes.color
	for _, part in eyes.parts do
		part.Color = color
	end
	for _, light in eyes.lights do
		light.Color = color
	end
end

local function tick(monster: Monster, now: number, _dt: number, targets: { Target }, api: Api): ()
	if monster.state == "Idle" then
		api.setState(monster, "Patrol", "감시 시작")
	end
	local duration = monster.def.AlertMarkerDuration or 0
	local seen = api.findVisibleTargets(monster, targets)
	for _, target in seen do
		local last = monster.alertedAt[target.player]
		if not last or now - last >= duration then
			monster.alertedAt[target.player] = now
			api.markForChasers(target.rootPart.Position, duration, "WatcherAlert")
			print(`[Monster] {monster.name} 경보 → {target.player.Name}`)
		end
	end
	if #seen > 0 and monster.state ~= "Alert" then
		api.setState(monster, "Alert", seen[1].player.Name)
		setEyeColor(monster, true)
	elseif #seen == 0 and monster.state == "Alert" then
		api.setState(monster, "Patrol", "안 보임")
		setEyeColor(monster, false)
	end
end

local Watcher: MonsterTypes.Behavior = {
	tick = tick,
	onNoise = nil,
	onIdle = function(monster: Monster): ()
		setEyeColor(monster, false)
	end,
	usesPatrolRoute = false,
}

return Watcher
