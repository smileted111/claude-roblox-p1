--!strict
-- CatchService: 피격·부상·쓰러짐·잡힘 판정과 아군 치료·살리기 (GDD 2.2, 7장, 12장, 13.2)
--
-- 추격자 공격 (ChaserAttack 리모트, 인자 없음)
--   빈도 제한·관전자 거절(server/Util/RemoteHandler) → 역할(추격자) → 단계(추격, CatchState.canHitInPhase)
--   → 기절·멈춤 아님 → 쿨다운(Config.Chasers.AttackCooldown) 순서로 검사한다.
--   판정: 추격자 HumanoidRootPart가 바라보는 쪽 AttackAngle도 안, AttackRange(+ Config.Catch.Attack.RangeSlack) 안에 있고
--         사이에 벽이 없는 생존자 중 가장 가까운 1명. 빗나가도 쿨다운은 돈다.
--   맞히면 추격자는 그 자리에 Config.Catch.Attack.HitPauseTime초 멈춘다 (MovementService.stun "AttackHit": 이동·공격·
--   스킬 모두 막힘). 추격자에게 알림 AttackHitPause ("공격에 성공했습니다. n초간 멈춥니다.") (2026-11-22 사용자 요청)
--   클라이언트(ChaserController)는 입력과 휘두르는 애니메이션·효과음만 맡는다.
--
-- 맞으면 (CatchService.hit — 괴물도 이 함수를 쓴다, S1-6)
--   정상 → 부상, 부상 → 쓰러짐 또는 잡힘. 맞은 직후 Config.Survivor.HitInvulnerableTime초 동안은 다시 맞지 않는다.
--   숨어 있는 생존자는 맞지 않는다 (추격자는 열어보기로 먼저 꺼내야 함).
--   부상이면 이동 속도는 MovementService가 SurvivorState를 보고 낮춘다.
--
-- 감옥 (경찰과 도둑 모드, 2026-11-22 사용자 요청): 이번 스테이지가 경찰과 도둑이면 (JailService.isEnabled) 부상 상태로 맞은 도둑은
--   쓰러지지 않고 감옥에 갇힌다 (JailService.imprison). 풀려난 직후(JailService.isProtected)에는 맞지 않는다.
--
-- 쓰러짐 (2026-11-22 사용자 요청, Config.Catch.Revive) — 서바이벌 모드
--   추격자가 있는 스테이지(같이 하기)에서 부상 상태로 맞았고 서 있는 다른 생존자가 있으면 잡히지 않고 그 자리에 쓰러진다.
--   (서 있는 생존자가 없으면 살려줄 사람이 없으므로 바로 잡힘. 솔로도 바로 잡힘.)
--   상태 Downed, 역할은 생존자 그대로. 캐릭터는 고정해 그 자리에 눕히고(밀려나지 않음), Player Attribute DownedUntil에
--   살릴 수 있는 마지막 서버 시각을 둔다. 모두에게 알림 SurvivorDowned, 본인에게는 YouAreDowned.
--   쓰러진 생존자는 움직이지도(MovementService) 숨지도(HideService) 고치지도(ObjectiveService) 아이템을 쓰지도(ItemService)
--   못하고, 추격자·괴물에게 맞지도 않는다.
--   DownedTime초 안에 아무도 못 살리면 잡힘 (쓰러뜨린 추격자의 잡은 수). 잡힘 연출 없이 화면만 어두워진다 (클라이언트).
--   서 있는 생존자가 모두 없어지면(마지막 생존자가 잡히거나 탈출·나감) StageService가 catchAllDowned로 모두 잡힘 처리한다.
--
-- 살리기 (붕대)
--   쓰러진 생존자의 HumanoidRootPart에 ProximityPrompt "붕대로 살리기"를 만든다 (HoldDuration = Revive.HoldTime,
--   이름·태그는 CatchState). 붕대를 가진, 서 있는 생존자에게만 보인다 (클라이언트 SurvivorController).
--   Triggered에서 서버가 다시 검사한다: 단계(추격), 살리는 사람이 숨지 않고 서 있는 생존자이고 자기 자신이 아님,
--   대상이 쓰러짐, 거리, 사이에 벽 없음, 누른 시간, 누르는 동안 살리는 사람이 맞지 않음, 붕대가 있음.
--   통과하면 붕대 1개를 쓰고(ItemService.takeItem) 대상은 부상 상태로 쓰러진 자리에 다시 선다 (Revive.InvulnerableTime초 무적).
--   매치 기록에는 치료 1회로 센다 (RecordService.addHeal). 모두에게 알림 SurvivorRevived.
--
-- 잡히면
--   RoleService.setSurvivorState(Caught)로 역할이 Spectator가 되고, 모두에게 알림(Notice SurvivorCaught)을 보낸다.
--   잡힘 연출 (Config.Catch.CaughtEffect): 잡힌 사람에게 CaughtBy 리모트(잡은 괴물·추격자 모델과 위치)를 보내 클라이언트가
--   카메라 연출을 하고(SurvivorController, Util/CaughtCinematic), 서버는 캐릭터를 고정한 채 잡은 쪽 반대로 밀며 뒤로
--   넘어뜨린다(KnockdownTime, 모두에게 보임). CinematicTime + FadeInTime 뒤(잡힌 사람 화면이 어두워진 뒤) 맵에서 지운다.
--   효과음과 연출을 받지 못했을 때의 암전은 클라이언트가 자기 SurvivorState를 보고 한다.
--   암전이 끝나면 관전이 시작된다 (SpectateService).
--
-- 아군 치료
--   부상 상태로 숨어 있지 않은 생존자의 HumanoidRootPart에 ProximityPrompt "치료"를 만든다
--   (HoldDuration = Config.Survivor.HealTime, 이름·태그는 CatchState). 누구에게 보일지는 클라이언트(SurvivorController)가 정한다.
--   Triggered에서 서버가 다시 검사한다: 단계(추격), 치료하는 사람이 숨지 않은 생존자이고 자기 자신이 아님, 대상이 부상,
--   거리, 사이에 벽 없음, 누른 시간(PromptButtonHoldBegan부터), 누르는 동안 두 사람 모두 맞지 않음. 통과하면 정상으로.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
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
local PromptUtil = require(ReplicatedStorage.Shared.Util.PromptUtil)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local HideService = require(script.Parent.HideService)
local ItemService = require(script.Parent.ItemService)
local JailService = require(script.Parent.JailService)
local MovementService = require(script.Parent.MovementService)
local RecordService = require(script.Parent.RecordService)
local RoleService = require(script.Parent.RoleService)

-- 치료·살리기 프롬프트를 누르기 시작한 기록. 서버에서 누른 시간을 확인한다.
type Hold = {
	target: Player,
	beganAt: number, -- os.clock
	endedAt: number?,
}

-- 쓰러진 생존자 한 명
type Downed = {
	token: number, -- 쓰러질 때마다 새 값. 시간 초과 예약이 옛 쓰러짐에 적용되지 않게 한다
	downedBy: Player?, -- 쓰러뜨린 추격자 (잡히면 그 사람의 잡은 수)
	standCFrame: CFrame?, -- 쓰러지기 전 서 있던 자리 (살아나면 여기 선다). 캐릭터가 없었으면 nil
	prompt: ProximityPrompt?, -- "붕대로 살리기"
}

local Attribute = MatchState.Attribute
local Revive = Catch.Revive

local CatchService = {}

local nextAttackAt: { [Player]: number } = {}
local invulnerableUntil: { [Player]: number } = {}
local lastHitAt: { [Player]: number } = {}
local healPrompts: { [Player]: ProximityPrompt } = {}
local healHolds: { [Player]: Hold } = {}
local reviveHolds: { [Player]: Hold } = {}
local downed: { [Player]: Downed } = {}
local nextDownToken = 0

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
	if MovementService.isStunned(chaser) then
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
	local def = Chasers[MatchState.getChaserType(chaser) or Match.DefaultChaser]
	nextAttackAt[chaser] = now + def.AttackCooldown - Catch.Attack.CooldownSlack

	local target = findAttackTarget(parts.rootPart, def)
	if target and CatchService.hit(target, `추격자 {chaser.Name}`, false, chaser) then
		-- 공격에 성공하면 그 자리에 멈춘다 (2026-11-22 사용자 요청)
		local pause = Catch.Attack.HitPauseTime
		MovementService.stun(chaser, pause, "AttackHit")
		Remotes.get("Notice"):FireClient(chaser, "AttackHitPause" :: Types.NoticeKey, pause)
		print(`[Catch] 추격자 {chaser.Name} 공격 성공 → {pause}초 멈춤`)
	else
		print(`[Catch] 추격자 {chaser.Name} 공격 → 빗나감`)
	end
end

-- 캐릭터를 from 반대쪽으로 distance만큼 밀며 뒤로 넘어뜨린다. 몸통은 고정된 채 트윈으로 움직인다.
local function knockDown(parts: CharacterParts.CharacterParts, from: Vector3, distance: number): ()
	local effect = Catch.CaughtEffect
	local root = parts.rootPart
	local position = root.Position
	local away = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
	away = if away.Magnitude > 0.05 then away.Unit else -root.CFrame.LookVector
	local ground = position.Y - (parts.humanoid.HipHeight + root.Size.Y / 2)
	local landing = Vector3.new(position.X, ground + 1, position.Z) + away * distance
	-- 잡은 쪽을 보고 선 채로 X축으로 돌리면 등 쪽(잡은 쪽 반대)으로 눕는다.
	local goal = CFrame.lookAt(landing, landing - away) * CFrame.Angles(math.rad(80), 0, 0)
	TweenService:Create(root, TweenInfo.new(effect.KnockdownTime, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		CFrame = goal,
	}):Play()
end

-- 잡은 쪽(괴물·추격자 모델)의 위치. 없으면 몸 앞쪽 (그 반대로 넘어진다).
local function catcherPosition(parts: CharacterParts.CharacterParts?, catcherModel: Model?): Vector3
	if catcherModel and catcherModel.Parent then
		return catcherModel:GetPivot().Position
	elseif parts then
		return parts.rootPart.Position - parts.rootPart.CFrame.LookVector
	end
	return Vector3.zero
end

-- 화면이 어두워진 뒤 잡힌 캐릭터를 맵에서 지운다.
local function removeCharacterLater(survivor: Player, character: Model): ()
	local effect = Catch.CaughtEffect
	task.delay(effect.CinematicTime + effect.FadeInTime, function()
		-- 그 사이 스테이지가 끝나 새 캐릭터가 생겼으면 옛 캐릭터만 지운다.
		if survivor.Character == character then
			survivor.Character = nil
		end
		character:Destroy()
	end)
end

-- 잡힌 생존자를 관전자로 바꾸고, 잡힘 연출(넘어짐)이 끝나 화면이 어두워진 뒤 캐릭터를 맵에서 지운다.
-- catcher는 잡은 괴물·추격자 모델 (카메라 연출과 넘어지는 방향. 없으면 추격자 캐릭터, 그것도 없으면 제자리에서 넘어짐).
local function catch(survivor: Player, source: string, attacker: Player?, catcher: Model?): ()
	local parts = CharacterParts.get(survivor)
	local catcherModel: Model? = catcher or (if attacker then attacker.Character else nil)
	local from = catcherPosition(parts, catcherModel)
	-- 상태보다 먼저 보내 클라이언트가 기본 암전 대신 연출을 고르게 한다.
	Remotes.get("CaughtBy"):FireClient(survivor, catcherModel, from)
	RoleService.setSurvivorState(survivor, "Caught")
	if attacker then
		RecordService.addCatch(attacker)
	end
	Remotes.get("Notice"):FireAllClients("SurvivorCaught" :: Types.NoticeKey, survivor.DisplayName)
	print(`[Catch] {source} → {survivor.Name} 잡힘 → 관전자`)

	if not parts then
		return
	end
	parts.rootPart.Anchored = true
	MovementService.markTeleported(survivor)
	knockDown(parts, from, Catch.CaughtEffect.KnockbackDistance)
	removeCharacterLater(survivor, parts.character)
end

--------------------------------------------------------------------------------
-- 쓰러짐과 살리기

local function clearDowned(survivor: Player): Downed?
	local entry = downed[survivor]
	downed[survivor] = nil
	if entry and entry.prompt then
		entry.prompt:Destroy()
	end
	if survivor.Parent then
		survivor:SetAttribute(Attribute.DownedUntil, nil)
	end
	return entry
end

-- 쓰러진 생존자를 잡힘으로 바꾼다 (시간 초과, 서 있는 생존자가 모두 없어짐). 잡힘 연출 없이 화면만 어두워진다.
local function catchDowned(survivor: Player, reason: string): ()
	local entry = clearDowned(survivor)
	if not entry or MatchState.getSurvivorState(survivor) ~= "Downed" then
		return
	end
	RoleService.setSurvivorState(survivor, "Caught")
	local downedBy = entry.downedBy
	if downedBy then
		RecordService.addCatch(downedBy)
	end
	Remotes.get("Notice"):FireAllClients("SurvivorCaught" :: Types.NoticeKey, survivor.DisplayName)
	print(`[Catch] {survivor.Name} 쓰러진 채 잡힘 ({reason}) → 관전자`)
	local parts = CharacterParts.get(survivor)
	if parts then
		removeCharacterLater(survivor, parts.character)
	end
end

-- 붕대로 살린다: 붕대 1개를 쓰고, 쓰러진 자리에 부상 상태로 다시 세운다.
local function revive(target: Player, reviver: Player): ()
	if not ItemService.takeItem(reviver, CatchState.ReviveItem) then
		return
	end
	local entry = clearDowned(target)
	RoleService.setSurvivorState(target, "Injured")
	invulnerableUntil[target] = os.clock() + Revive.InvulnerableTime
	local parts = CharacterParts.get(target)
	if parts then
		local root = parts.rootPart
		if entry and entry.standCFrame then
			root.CFrame = entry.standCFrame
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.Anchored = false
		MovementService.markTeleported(target)
	end
	RecordService.addHeal(reviver)
	Remotes.get("Notice"):FireAllClients("SurvivorRevived" :: Types.NoticeKey, reviver.DisplayName, target.DisplayName)
	print(`[Catch] {reviver.Name} → {target.Name} 붕대로 살림 → 부상`)
end

-- 누르기 시작·끝 시각을 기록한다. 연결은 프롬프트가 지워질 때(캐릭터와 함께 지워질 때 포함) 함께 끊긴다.
local function trackHolds(prompt: ProximityPrompt, holds: { [Player]: Hold }, target: Player): ()
	prompt.PromptButtonHoldBegan:Connect(function(player: Player)
		holds[player] = { target = target, beganAt = os.clock(), endedAt = nil }
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player: Player)
		local hold = holds[player]
		if hold and hold.target == target and hold.endedAt == nil then
			hold.endedAt = os.clock()
		end
	end)
end

-- 누른 기록을 꺼내 누른 시간이 충분했는지 본다. 누르기 끝(PromptButtonHoldEnded)과 Triggered 중 어느 쪽이 먼저 와도 맞게
-- 계산한다. 충분하면 누르기 시작 시각, 아니면 nil.
local function takeHold(
	holds: { [Player]: Hold },
	player: Player,
	target: Player,
	needed: number,
	slack: number
): number?
	local hold = holds[player]
	holds[player] = nil
	if not hold or hold.target ~= target then
		return nil
	end
	local heldFor = (hold.endedAt or os.clock()) - hold.beganAt
	if heldFor < needed - slack then
		return nil
	end
	return hold.beganAt
end

-- 두 생존자가 거리 안에 있고 사이에 벽이 없는가
local function isWithinReach(a: Player, b: Player, distance: number): boolean
	local aParts = CharacterParts.get(a)
	local bParts = CharacterParts.get(b)
	if not aParts or not bParts then
		return false
	end
	if (aParts.rootPart.Position - bParts.rootPart.Position).Magnitude > distance then
		return false
	end
	return isPathClear(aParts.rootPart, bParts.rootPart)
end

local function onReviveTriggered(reviver: Player, target: Player): ()
	local beganAt = takeHold(reviveHolds, reviver, target, Revive.HoldTime, Revive.HoldSlack)
	if not beganAt or reviver == target or not CatchState.canReviveInPhase(MatchState.getPhase()) then
		return
	end
	if not isActiveSurvivor(reviver) or MatchState.isHidden(reviver) then
		return
	end
	if not downed[target] or MatchState.getSurvivorState(target) ~= "Downed" then
		return
	end
	if (lastHitAt[reviver] or 0) >= beganAt then
		print(`[Catch] {reviver.Name} → {target.Name} 살리기 끊김 (누르는 동안 맞음)`)
		return
	end
	if not isWithinReach(reviver, target, Revive.PromptDistance + Revive.DistanceSlack) then
		return
	end
	revive(target, reviver)
end

local function createRevivePrompt(target: Player, rootPart: BasePart): ProximityPrompt
	local prompt = PromptUtil.new()
	prompt.Name = CatchState.RevivePromptName
	prompt.ActionText = Strings.Prompts.Revive
	prompt.ObjectText = target.DisplayName
	prompt.HoldDuration = Revive.HoldTime
	prompt.MaxActivationDistance = Revive.PromptDistance
	-- 프롬프트가 캐릭터 몸 안에 있어 시야 검사를 켜면 대상 자신의 몸에 가린다. 벽은 서버가 레이캐스트로 검사한다.
	prompt.RequiresLineOfSight = false
	prompt:AddTag(CatchState.RevivePromptTag)
	trackHolds(prompt, reviveHolds, target)
	prompt.Triggered:Connect(function(reviver: Player)
		onReviveTriggered(reviver, target)
	end)
	prompt.Parent = rootPart
	return prompt
end

-- 서 있는 다른 생존자가 있어 쓰러질 수 있는가 (서바이벌 모드만. 솔로는 게임 모드가 없고 살려줄 사람도 없다.
-- 얼음땡은 쓰러짐 없이 바로 잡힘)
local function canBeDowned(survivor: Player): boolean
	if not MatchState.hasChaser() or MatchState.getGameMode() ~= "Survival" then
		return false
	end
	for _, other in RoleService.getActiveSurvivors() do
		if other ~= survivor then
			return true
		end
	end
	return false
end

-- 그 자리에 쓰러뜨리고 Revive.DownedTime초 뒤 아직 쓰러져 있으면 잡힘으로 바꾼다.
local function down(survivor: Player, source: string, attacker: Player?, catcher: Model?): ()
	local parts = CharacterParts.get(survivor)
	nextDownToken += 1
	local token = nextDownToken
	local entry: Downed = {
		token = token,
		downedBy = attacker,
		standCFrame = if parts then parts.rootPart.CFrame else nil,
		prompt = nil,
	}
	downed[survivor] = entry
	survivor:SetAttribute(Attribute.DownedUntil, Workspace:GetServerTimeNow() + Revive.DownedTime)
	RoleService.setSurvivorState(survivor, "Downed")
	if parts then
		local catcherModel: Model? = catcher or (if attacker then attacker.Character else nil)
		parts.rootPart.Anchored = true
		MovementService.markTeleported(survivor)
		knockDown(parts, catcherPosition(parts, catcherModel), 0)
		entry.prompt = createRevivePrompt(survivor, parts.rootPart)
	end

	local notice = Remotes.get("Notice")
	for _, player in Players:GetPlayers() do
		if player ~= survivor then
			notice:FireClient(player, "SurvivorDowned" :: Types.NoticeKey, survivor.DisplayName)
		end
	end
	notice:FireClient(survivor, "YouAreDowned" :: Types.NoticeKey, Revive.DownedTime)
	print(`[Catch] {source} → {survivor.Name} 쓰러짐 ({Revive.DownedTime}초 안에 붕대로 살릴 수 있음)`)

	task.delay(Revive.DownedTime, function()
		local current = downed[survivor]
		if current and current.token == token then
			catchDowned(survivor, "시간 초과")
		end
	end)
end

-- 쓰러진 생존자를 모두 잡힘으로 바꾼다 (서 있는 생존자가 없어 살려줄 사람이 없을 때, StageService). 바꾼 수를 돌려준다.
function CatchService.catchAllDowned(reason: string): number
	local list: { Player } = {}
	for player in downed do
		table.insert(list, player)
	end
	for _, player in list do
		catchDowned(player, reason)
	end
	return #list
end

-- 쓰러진 생존자를 모두 부상 상태로 일으킨다 (추격자가 모두 나가 스테이지가 끝날 때, StageService). 붕대는 쓰지 않는다.
function CatchService.standUpAllDowned(): ()
	for player in table.clone(downed) do
		local entry = clearDowned(player)
		if MatchState.getSurvivorState(player) == "Downed" then
			RoleService.setSurvivorState(player, "Injured")
			local parts = CharacterParts.get(player)
			if parts then
				if entry and entry.standCFrame then
					parts.rootPart.CFrame = entry.standCFrame
				end
				parts.rootPart.Anchored = false
				MovementService.markTeleported(player)
			end
		end
	end
end

-- 스테이지가 끝나면 쓰러짐 기록을 지운다 (StageService.finish). 캐릭터는 MatchService가 로비에 새로 만든다.
function CatchService.clearStage(): ()
	for player in table.clone(downed) do
		clearDowned(player)
	end
	table.clear(reviveHolds)
end

--------------------------------------------------------------------------------
-- 맞기

-- 맞을 수 있는가: 추격 단계, 정상·부상인 생존자, 숨어 있지 않음, 맞은 직후 무적 시간이 아님, 감옥에서 막 풀려나지 않음
function CatchService.canBeHit(player: Player): boolean
	return CatchState.canHitInPhase(MatchState.getPhase())
		and isActiveSurvivor(player)
		and not HideService.isHidden(player)
		and os.clock() >= (invulnerableUntil[player] or 0)
		and not JailService.isProtected(player)
end

-- 생존자를 한 번 때린다: 정상 → 부상, 부상 → 감옥(경찰과 도둑) 또는 쓰러짐(살려줄 사람이 있을 때) 또는 잡힘.
-- instantCatch면 부상을 건너뛴다 (거인, S3-4).
-- source는 로그용 이름. attacker는 때린 추격자 (매치 기록의 잡은 수. 괴물이면 nil).
-- catcher는 때린 괴물 모델 (잡힘 연출용, 추격자는 attacker 캐릭터를 씀).
-- 맞힐 수 없는 상태(CatchService.canBeHit)면 false.
function CatchService.hit(
	survivor: Player,
	source: string,
	instantCatch: boolean?,
	attacker: Player?,
	catcher: Model?
): boolean
	if not CatchService.canBeHit(survivor) then
		return false
	end
	local now = os.clock()
	invulnerableUntil[survivor] = now + Survivor.HitInvulnerableTime
	lastHitAt[survivor] = now

	if MatchState.getSurvivorState(survivor) == "Normal" and not instantCatch then
		RoleService.setSurvivorState(survivor, "Injured")
		print(`[Catch] {source} → {survivor.Name} 부상`)
	elseif JailService.isEnabled() then
		-- 경찰과 도둑: 감옥에 갇힘
		JailService.imprison(survivor, source, attacker)
	elseif canBeDowned(survivor) then
		down(survivor, source, attacker, catcher)
	else
		catch(survivor, source, attacker, catcher)
	end
	return true
end

--------------------------------------------------------------------------------
-- 아군 치료

local function needsHealPrompt(player: Player): boolean
	return MatchState.getRole(player) == "Survivor"
		and MatchState.getSurvivorState(player) == "Injured"
		and not MatchState.isHidden(player)
end

local function onHealTriggered(healer: Player, target: Player): ()
	local beganAt = takeHold(healHolds, healer, target, Survivor.HealTime, Catch.Heal.HoldSlack)
	if not beganAt then
		return
	end
	if healer == target or not CatchState.canHealInPhase(MatchState.getPhase()) then
		return
	end
	if not isActiveSurvivor(healer) or MatchState.isHidden(healer) or not needsHealPrompt(target) then
		return
	end
	if (lastHitAt[healer] or 0) >= beganAt or (lastHitAt[target] or 0) >= beganAt then
		print(`[Catch] {healer.Name} → {target.Name} 치료 끊김 (누르는 동안 맞음)`)
		return
	end
	if not isWithinReach(healer, target, Catch.Heal.PromptDistance + Catch.Heal.DistanceSlack) then
		return
	end
	RoleService.setSurvivorState(target, "Normal")
	RecordService.addHeal(healer)
	print(`[Catch] {healer.Name} → {target.Name} 치료 → 정상`)
end

local function createHealPrompt(target: Player, rootPart: BasePart): ProximityPrompt
	local prompt = PromptUtil.new()
	prompt.Name = CatchState.HealPromptName
	prompt.ActionText = Strings.Prompts.Heal
	prompt.ObjectText = target.DisplayName
	prompt.HoldDuration = Survivor.HealTime
	prompt.MaxActivationDistance = Catch.Heal.PromptDistance
	-- 프롬프트가 캐릭터 몸 안에 있어 시야 검사를 켜면 대상 자신의 몸에 가린다. 벽은 서버가 레이캐스트로 검사한다.
	prompt.RequiresLineOfSight = false
	prompt:AddTag(CatchState.HealPromptTag)
	trackHolds(prompt, healHolds, target)
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
		reviveHolds[player] = nil
		downed[player] = nil
	end)

	RemoteHandler.connect("ChaserAttack", function(player: Player)
		onChaserAttack(player)
	end)
end

return CatchService
