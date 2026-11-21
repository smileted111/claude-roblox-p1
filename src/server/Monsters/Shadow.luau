--!strict
-- 그림자 (GDD 4.1): 배회자처럼 순찰하다 생존자를 보면 쫓는다 (속도 16, 보통 시야).
-- 어두운 구역(DarkZone 태그 상자) 안에 있으면 몸 전체가 DarkTransparency(0.9)만큼 투명해져 거의 안 보인다.
-- 손전등 빛을 받으면 FlashlightFreezeTime(2초) 동안 멈춘다 (MonsterService.freezeInBeam이 frozenUntil을 정함).

local Wanderer = require(script.Parent.Wanderer)
local MonsterTypes = require(script.Parent.MonsterTypes)

type Monster = MonsterTypes.Monster
type Target = MonsterTypes.Target
type Api = MonsterTypes.Api

-- 모델의 보이는 파트와 원래 투명도. 어두운 곳에서 바꿨다가 되돌린다.
type Look = {
	parts: { [BasePart]: number },
	dark: boolean,
}

local looks: { [Model]: Look } = setmetatable({}, { __mode = "k" }) :: any

local function getLook(model: Model): Look
	local look = looks[model]
	if look then
		return look
	end
	local parts: { [BasePart]: number } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			parts[descendant] = descendant.Transparency
		end
	end
	look = { parts = parts, dark = false }
	looks[model] = look
	return look
end

local function setDark(monster: Monster, dark: boolean): ()
	local look = getLook(monster.model)
	if look.dark == dark then
		return
	end
	look.dark = dark
	local transparency = monster.def.DarkTransparency or 0
	for part, original in look.parts do
		part.Transparency = if dark then math.max(original, transparency) else original
	end
end

local function tick(monster: Monster, now: number, dt: number, targets: { Target }, api: Api): ()
	setDark(monster, api.isInDarkZone(monster.rootPart.Position))
	if now < monster.frozenUntil then
		api.stopMoving(monster)
		return
	end
	Wanderer.tick(monster, now, dt, targets, api)
end

local Shadow: MonsterTypes.Behavior = {
	tick = tick,
	onNoise = nil,
	onIdle = function(monster: Monster): ()
		setDark(monster, false)
		monster.frozenUntil = 0
	end,
	onSummon = nil,
	usesPatrolRoute = true,
}

return Shadow
