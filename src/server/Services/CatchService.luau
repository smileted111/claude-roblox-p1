--!strict
-- CatchService: 피격·부상·잡힘 판정과 아군 치료 (GDD 2.2, 7장, 12장, 13.2)
--
-- 추격자 공격 (ChaserAttack 리모트, 인자 없음)
--   빈도 제한·관전자 거절(server/Util/RemoteHandler) → 역할(추격자) → 단계(추격, CatchState.canHitInPhase)
--   → 쿨다운(Config.Chasers.AttackCooldown) 순서로 검사한다.
--   판정: 추격자 HumanoidRootPart가 바라보는 쪽 AttackAngle도 안, AttackRange(+ Config.Catch.Attack.RangeSlack) 안에 있고
--         사이에 벽이 없는 생존자 중 가장 가까운 1명. 빗나가도 쿨다운은 돈다.
--   클라이언트(ChaserController)는 입력과 휘두르는 애니메이션·효과음만 맡는다.
--
-- 맞으면 (CatchService.hit — 괴물도 이 함수를 쓴다, S1-6)
--   정상 → 부상, 부상 → 잡힘. 맞은 직후 Config.Survivor.HitInvulnerableTime초 동안은 다시 맞지 않는다.
--   숨어 있는 생존자는 맞지 않는다 (추격자는 열어보기로 먼저 꺼내야 함).
--   부상이면 이동 속도는 MovementService가 SurvivorState를 보고 낮춘다.
--
-- 잡히면
--   RoleService.setSurvivorState(Caught)로 역할이 Spectator가 되고, 모두에게 알림(Notice SurvivorCaught)을 보낸다.
--   캐릭터를 그 자리에 고정했다가 Config.Catch.CaughtEffect.FadeInTime초 뒤(잡힌 사람 화면이 어두워진 뒤) 맵에서 지운다.
--   화면 암전 Config.Match.CaughtEffectTime초와 효과음은 클라이언트(SurvivorController)가 자기 SurvivorState를 보고 한다.
--   암전이 끝나면 관전이 시작된다 (SpectateService).
--
-- 아군 치료
--   부상 상태로 숨어 있지 않은 생존자의 HumanoidRootPart에 ProximityPrompt "치료"를 만든다
--   (HoldDuration = Config.Survivor.HealTime, 이름·태그는 CatchState). 누구에게 보일지는 클라이언트(SurvivorController)가 정한다.
--   Triggered에서 서버가 다시 검사한다: 단계(추격), 치료하는 사람이 숨지 않은 생존자이고 자기 자신이 아님, 대상이 부상,
--   거리, 사이에 벽 없음, 누른 시간(PromptButtonHoldBegan부터), 누르는 동안 두 사람 모두 맞지 않음. 통과하면 정상으로.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local CatchState = require(ReplicatedStorage.Shared.CatchState)
local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survivor = require(ReplicatedStorage.Shared.Config.Survivor)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local HideService = require(script.Parent.HideService)
local RecordService = require(script.Parent.RecordService)
local RoleService = require(script.Parent.RoleService)

-- 치료 프롬프트를 누르기 시작한 기록. 서버에서 누른 시간을 확인한다.
type HealHold = {
	target: Player,
	beganAt: number, -- os.clock
	endedAt: number?,
}

local Attribute = MatchState.Attribute

local CatchService = {}

local nextAttackAt: { [Player]: number } = {}
local invulnerableUntil: { [Player]: number } = {}
local lastHitAt: { [Player]: number } = {}
local healPrompts: { [Player]: ProximityPrompt } = {}
local healHolds: { [Player]: HealHold } = {}

-- 벽 검사: 캐릭터는 빼고, 충돌하는 파트만 막는 것으로 본다 (열린 대기실 문, 시작 위치 표시 등은 통과).
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.RespectCanCollide = true

local function isActiveSurvivor(player: Player): boolean
	local state = MatchState.getSurvivorState(player)
	return MatchState.getRole(player) == "Survivor" and (state == "Normal" or state == "Injured")
end

-- 두 파트 사이에 벽이 없는가
local function isPathClear(from: BasePart, to: BasePart): boolean
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	wallParams.FilterDescendantsInstances = characters
	return Workspace:Raycast(from.Position, to.Position - from.Position, wallParams) == nil
end

-- 대상이 추격자 앞쪽 공격 범위 안에 있으면 거리를, 아니면 nil을 돌려준다.
local function attackDistance(chaserRoot: BasePart, targetRoot: BasePart, def: Chasers.ChaserDef): number?
	local offset = targetRoot.Position - chaserRoot.Position
	local distance = offset.Magnitude
	if distance > def.AttackRange + Catch.Attack.RangeSlack then
		return nil
	end
	-- 방향은 수평으로만 본다. 바로 위아래처럼 수평 거리가 거의 없으면 앞쪽으로 친다.
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	local look = chaserRoot.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatOffset.Magnitude > 1e-3 and flatLook.Magnitude > 1e-3 then
		local minDot = math.cos(math.rad(def.AttackAngle / 2))
		if flatOffset.Unit:Dot(flatLook.Unit) < minDot then
			return nil
		end
	end
	return distance
end

-- 공격 범위 안에서 맞을 수 있는 가장 가까운 생존자
local function findAttackTarget(chaserRoot: BasePart, def: Chasers.ChaserDef): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, survivor in RoleService.getActiveSurvivors() do
		local parts = if CatchService.canBeHit(survivor) then CharacterParts.get(survivor) else nil
		local distance = parts and attackDistance(chaserRoot, parts.rootPart, def)
		if parts and distance and distance < bestDistance and isPathClear(chaserRoot, parts.rootPart) then
			best = survivor
			bestDistance = distance
		end
	end
	return best
end

local function onChaserAttack(chaser: Player): ()
	if MatchState.getRole(chaser) ~= "Chaser" or not CatchState.canHitInPhase(MatchState.getPhase()) then
		return
	end
	local now = os.clock()
	if now < (nextAttackAt[chaser] or 0) then
		return
	end
	local parts = CharacterParts.get(chaser)
	if not parts then
		return
	end
	local def = Chasers[Match.DefaultChaser]
	nextAttackAt[chaser] = now + def.AttackCooldown - Catch.Attack.CooldownSlack

	local target = findAttackTarget(parts.rootPart, def)
	if target then
		CatchService.hit(target, `추격자 {chaser.Name}`, false, chaser)
	else
		print(`[Catch] 추격자 {chaser.Name} 공격 → 빗나감`)
	end
end

-- 잡힌 생존자를 관전자로 바꾸고, 화면이 어두워진 뒤 캐릭터를 맵에서 지운다.
local function catch(survivor: Player, source: string, attacker: Player?): ()
	local parts = CharacterParts.get(survivor)
	RoleService.setSurvivorState(survivor, "Caught")
	if attacker then
		RecordService.addCatch(attacker)
	end
	Remotes.get("Notice"):FireAllClients("SurvivorCaught" :: Types.NoticeKey, survivor.DisplayName)
	print(`[Catch] {source} → {survivor.Name} 잡힘 → 관전자`)

	if not parts then
		return
	end
	local character = parts.character
	parts.rootPart.Anchored = true
	task.delay(Catch.CaughtEffect.FadeInTime, function()
		-- 그 사이 스테이지가 끝나 새 캐릭터가 생겼으면 옛 캐릭터만 지운다.
		if survivor.Character == character then
			survivor.Character = nil
		end
		character:Destroy()
	end)
end

-- 맞을 수 있는가: 추격 단계, 정상·부상인 생존자, 숨어 있지 않음, 맞은 직후 무적 시간이 아님
function CatchService.canBeHit(player: Player): boolean
	return CatchState.canHitInPhase(MatchState.getPhase())
		and isActiveSurvivor(player)
		and not HideService.isHidden(player)
		and os.clock() >= (invulnerableUntil[player] or 0)
end

-- 생존자를 한 번 때린다: 정상 → 부상, 부상 → 잡힘. instantCatch면 바로 잡힘 (거인, S3-4).
-- source는 로그용 이름. attacker는 때린 추격자 (매치 기록의 잡은 수. 괴물이면 nil).
-- 맞힐 수 없는 상태(CatchService.canBeHit)면 false.
function CatchService.hit(survivor: Player, source: string, instantCatch: boolean?, attacker: Player?): boolean
	if not CatchService.canBeHit(survivor) then
		return false
	end
	local now = os.clock()
	invulnerableUntil[survivor] = now + Survivor.HitInvulnerableTime
	lastHitAt[survivor] = now

	if MatchState.getSurvivorState(survivor) == "Normal" and not instantCatch then
		RoleService.setSurvivorState(survivor, "Injured")
		print(`[Catch] {source} → {survivor.Name} 부상`)
	else
		catch(survivor, source, attacker)
	end
	return true
end

local function needsHealPrompt(player: Player): boolean
	return MatchState.getRole(player) == "Survivor"
		and MatchState.getSurvivorState(player) == "Injured"
		and not MatchState.isHidden(player)
end

local function onHealTriggered(healer: Player, target: Player): ()
	-- 누르기 끝(PromptButtonHoldEnded)과 Triggered 중 어느 쪽이 먼저 와도 맞게 계산한다.
	local hold = healHolds[healer]
	healHolds[healer] = nil
	if not hold or hold.target ~= target then
		return
	end
	local heldFor = (hold.endedAt or os.clock()) - hold.beganAt
	if heldFor < Survivor.HealTime - Catch.Heal.HoldSlack then
		return
	end
	if healer == target or not CatchState.canHealInPhase(MatchState.getPhase()) then
		return
	end
	if not isActiveSurvivor(healer) or MatchState.isHidden(healer) or not needsHealPrompt(target) then
		return
	end
	if (lastHitAt[healer] or 0) >= hold.beganAt or (lastHitAt[target] or 0) >= hold.beganAt then
		print(`[Catch] {healer.Name} → {target.Name} 치료 끊김 (누르는 동안 맞음)`)
		return
	end
	local healerParts = CharacterParts.get(healer)
	local targetParts = CharacterParts.get(target)
	if not healerParts or not targetParts then
		return
	end
	local distance = (healerParts.rootPart.Position - targetParts.rootPart.Position).Magnitude
	if distance > Catch.Heal.PromptDistance + Catch.Heal.DistanceSlack then
		return
	end
	if not isPathClear(healerParts.rootPart, targetParts.rootPart) then
		return
	end
	RoleService.setSurvivorState(target, "Normal")
	RecordService.addHeal(healer)
	print(`[Catch] {healer.Name} → {target.Name} 치료 → 정상`)
end

local function createHealPrompt(target: Player, rootPart: BasePart): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = CatchState.HealPromptName
	prompt.ActionText = Strings.Prompts.Heal
	prompt.ObjectText = target.DisplayName
	prompt.HoldDuration = Survivor.HealTime
	prompt.MaxActivationDistance = Catch.Heal.PromptDistance
	-- 프롬프트가 캐릭터 몸 안에 있어 시야 검사를 켜면 대상 자신의 몸에 가린다. 벽은 서버가 레이캐스트로 검사한다.
	prompt.RequiresLineOfSight = false
	prompt:AddTag(CatchState.HealPromptTag)

	-- 연결은 프롬프트가 지워질 때(캐릭터와 함께 지워질 때 포함) 함께 끊긴다.
	prompt.PromptButtonHoldBegan:Connect(function(healer: Player)
		healHolds[healer] = { target = target, beganAt = os.clock(), endedAt = nil }
	end)
	prompt.PromptButtonHoldEnded:Connect(function(healer: Player)
		local hold = healHolds[healer]
		if hold and hold.target == target and hold.endedAt == nil then
			hold.endedAt = os.clock()
		end
	end)
	prompt.Triggered:Connect(function(healer: Player)
		onHealTriggered(healer, target)
	end)

	prompt.Parent = rootPart
	return prompt
end

-- 부상 상태로 숨어 있지 않으면 지금 캐릭터에 치료 프롬프트를 두고, 아니면 지운다.
local function refreshHealPrompt(player: Player): ()
	local parts = if needsHealPrompt(player) then CharacterParts.get(player) else nil
	local existing = healPrompts[player]
	if existing and parts and existing.Parent == parts.rootPart then
		return
	end
	if existing then
		healPrompts[player] = nil
		existing:Destroy()
	end
	if parts then
		healPrompts[player] = createHealPrompt(player, parts.rootPart)
	end
end

local function watchPlayer(player: Player): ()
	local function refresh(): ()
		refreshHealPrompt(player)
	end
	player:GetAttributeChangedSignal(Attribute.Role):Connect(refresh)
	player:GetAttributeChangedSignal(Attribute.SurvivorState):Connect(refresh)
	player:GetAttributeChangedSignal(Attribute.Hidden):Connect(refresh)
	player.CharacterAdded:Connect(refresh)
	refresh()
end

function CatchService.Init(): () end

function CatchService.Start(): ()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		nextAttackAt[player] = nil
		invulnerableUntil[player] = nil
		lastHitAt[player] = nil
		healPrompts[player] = nil
		healHolds[player] = nil
	end)

	RemoteHandler.connect("ChaserAttack", function(player: Player)
		onChaserAttack(player)
	end)
end

return CatchService
