--!strict
-- MovementService: 이동 속도와 스태미나 (GDD 2.2, 4.1)
--
-- 속도(Humanoid.WalkSpeed)는 서버만 정한다. 클라이언트는 달리기 의사만 보낸다 (SetRunning, SurvivorController).
--   생존자  걷기 Config.Survivor.WalkSpeed, 달리기 RunSpeed. 부상이면 둘 다 × InjuredSpeedMultiplier. 숨어 있으면 0
--   추격자  Config.Chasers[이번 추격자 종류(Player Attribute ChaserType)].WalkSpeed. 돌진 스킬 중에는 × 배율 (boost)
--   그 외   대기 장소 등. Config.Survivor.WalkSpeed, 달리기 없음
--   기절    누구든 0 (판자에 맞은 추격자, MovementService.stun). Player Attribute Stunned
--
-- 스태미나 (Config.Survivor.Stamina)
--   생존자가 달리기 의사를 보내고 실제로 움직이는(MoveDirection) 동안 RunDrainPerSecond씩 준다.
--   달리기를 멈추고 RegenDelay초가 지나면 RegenPerSecond씩 찬다.
--   바닥나면 달리기가 끊기고, MinToStartRun 이상 찰 때까지 다시 달릴 수 없다.
--   역할이 바뀌거나 캐릭터가 새로 생기면 가득 찬다.
-- 스태미나와 달리는 중인지는 Player Attribute(MatchState.Attribute.Stamina, Running)로 공개한다.
-- 달리는 동안 Config.Survivor.RunNoiseInterval초마다 소리 사건(server/Util/NoiseBus, 반경 RunNoiseRadius)을 낸다.
--   사냥개가 이 소리에 반응한다 (GDD 4.1).
--
-- 이동 거리 검사 (Config.MovementCheck, docs/release-review.md 코드 #1): 스테이지의 생존자·추격자만.
--   서버가 정한 속도보다 훨씬 멀리 가면 마지막으로 인정한 위치로 되돌린다 (속도 조작·순간이동 핵).
--   서버가 캐릭터를 옮기는 곳(스테이지 배치, 숨기·나오기, 판자에 밀림, 망령 순간이동)은 markTeleported를 불러
--   잠깐 검사를 쉬고 새 위치부터 다시 잰다. 캐릭터가 새로 생기거나 역할이 바뀔 때도 같다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MovementCheck = require(ReplicatedStorage.Shared.Config.MovementCheck)
local Survivor = require(ReplicatedStorage.Shared.Config.Survivor)
local NoiseBus = require(script.Parent.Parent.Util.NoiseBus)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)

-- WalkSpeed는 float로 저장되어 14.4 같은 값이 정확히 같지 않으므로 이 차이 이상일 때만 바꾼다.
local SPEED_EPSILON = 0.01

type MoveCheck = {
	position: Vector3?, -- 마지막으로 인정한 위치. nil이면 다음 검사에서 새로 잡는다
	at: number, -- 마지막 검사 시각 (os.clock)
	budget: number, -- 허용 속도로 갈 수 있었지만 아직 가지 않은 거리 (스터드)
	speed: number, -- 이번 구간에 서버가 허용한 가장 빠른 속도
	previousSpeed: number, -- 지난 구간의 값 (속도가 줄어든 것이 클라이언트에 늦게 닿는 동안을 봐줌)
	graceUntil: number, -- 이때까지 검사하지 않는다 (os.clock)
	suspicious: number, -- 기록 기준만 넘은 횟수 (LogInterval마다 출력하고 지움)
	loggedAt: number, -- 마지막으로 출력한 시각 (os.clock)
}

type RunState = {
	wantsToRun: boolean, -- 클라이언트가 보낸 달리기 의사
	running: boolean, -- 지금 실제로 달리는 중
	stamina: number,
	lastRunAt: number, -- 마지막으로 달린 시각 (os.clock). 회복 지연 계산용
	nextNoiseAt: number, -- 다음 달리는 소리를 낼 시각 (os.clock)
	stunnedUntil: number, -- 기절이 끝나는 시각 (os.clock)
	boostUntil: number, -- 속도 증가가 끝나는 시각 (os.clock)
	boostMultiplier: number,
	shownStamina: number?, -- 마지막으로 Attribute에 쓴 값
	check: MoveCheck,
}

local Attribute = MatchState.Attribute
local StaminaConfig = Survivor.Stamina

local MovementService = {}

local states: { [Player]: RunState } = {}
local nextCheckAt = 0 -- 다음 이동 거리 검사 시각 (os.clock)

local function getLivingHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function canRun(player: Player): boolean
	return MatchState.getRole(player) == "Survivor" and not MatchState.isHidden(player)
end

local function speedFor(player: Player, state: RunState, running: boolean, now: number): number
	if now < state.stunnedUntil then
		return 0
	end
	local role = MatchState.getRole(player)
	local boost = if now < state.boostUntil then state.boostMultiplier else 1
	if role == "Chaser" then
		local chaserType = MatchState.getChaserType(player) or Match.DefaultChaser
		return Chasers[chaserType].WalkSpeed * boost
	end
	if role ~= "Survivor" then
		return Survivor.WalkSpeed
	end
	if MatchState.isHidden(player) then
		return 0
	end
	local speed = if running then Survivor.RunSpeed else Survivor.WalkSpeed
	if MatchState.getSurvivorState(player) == "Injured" then
		speed *= Survivor.InjuredSpeedMultiplier
	end
	return speed
end

local function publish(player: Player, state: RunState): ()
	local shown = math.round(state.stamina)
	if shown ~= state.shownStamina then
		state.shownStamina = shown
		player:SetAttribute(Attribute.Stamina, shown)
	end
	if MatchState.isRunning(player) ~= state.running then
		player:SetAttribute(Attribute.Running, if state.running then true else nil)
	end
end

-- 이동 거리 검사를 TeleportGrace초 쉬고 새 위치부터 다시 잰다.
local function resetCheck(state: RunState): ()
	local check = state.check
	check.position = nil
	check.budget = 0
	check.graceUntil = os.clock() + MovementCheck.TeleportGrace
end

local function refill(player: Player, state: RunState): ()
	resetCheck(state)
	state.wantsToRun = false
	state.running = false
	state.stunnedUntil = 0
	state.boostUntil = 0
	state.stamina = StaminaConfig.Max
	publish(player, state)
end

local function update(player: Player, state: RunState, deltaTime: number, now: number): ()
	local humanoid = getLivingHumanoid(player)
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0

	-- 이미 달리는 중이면 바닥날 때까지 계속, 새로 시작하려면 MinToStartRun 이상 필요
	local running = state.wantsToRun
		and moving
		and canRun(player)
		and state.stamina > 0
		and (state.running or state.stamina >= StaminaConfig.MinToStartRun)

	if running then
		state.stamina = math.max(0, state.stamina - StaminaConfig.RunDrainPerSecond * deltaTime)
		state.lastRunAt = now
		local rootPart = humanoid and humanoid.RootPart
		if rootPart and now >= state.nextNoiseAt then
			state.nextNoiseAt = now + Survivor.RunNoiseInterval
			NoiseBus.emit({
				kind = "Running",
				position = rootPart.Position,
				radius = Survivor.RunNoiseRadius,
				source = player,
			})
		end
		if state.stamina <= 0 then
			running = false
		end
	elseif now - state.lastRunAt >= StaminaConfig.RegenDelay then
		state.stamina = math.min(StaminaConfig.Max, state.stamina + StaminaConfig.RegenPerSecond * deltaTime)
	end
	state.running = running
	publish(player, state)

	local stunned = now < state.stunnedUntil
	if MatchState.isStunned(player) ~= stunned then
		player:SetAttribute(Attribute.Stunned, if stunned then true else nil)
	end

	if humanoid then
		local speed = speedFor(player, state, running, now)
		-- 이동 거리 검사는 바꾸기 전 값과 새 값 중 빠른 쪽을 허용한다 (클라이언트에 늦게 닿는 동안).
		state.check.speed = math.max(state.check.speed, speed, humanoid.WalkSpeed)
		if math.abs(humanoid.WalkSpeed - speed) > SPEED_EPSILON then
			humanoid.WalkSpeed = speed
		end
	end
end

-- Interval초마다 부른다. 서버가 허용한 속도보다 훨씬 멀리 갔으면 되돌린다 (위 설명과 Config.MovementCheck).
local function checkMovement(player: Player, state: RunState, now: number): ()
	local check = state.check
	local allowedSpeed = math.max(check.speed, check.previousSpeed)
	check.previousSpeed = check.speed
	check.speed = 0
	local role = MatchState.getRole(player)
	local humanoid = getLivingHumanoid(player)
	local rootPart = humanoid and humanoid.RootPart
	local character = humanoid and humanoid.Parent
	if
		not rootPart
		or not character
		or not character:IsA("Model")
		or (role ~= "Survivor" and role ~= "Chaser")
		or now < check.graceUntil
	then
		check.position = nil
		return
	end
	local position = rootPart.Position
	local last = check.position
	if not last then
		check.position = position
		check.at = now
		check.budget = 0
		return
	end
	local elapsed = now - check.at
	check.at = now
	check.budget = math.min(check.budget + allowedSpeed * elapsed, allowedSpeed * MovementCheck.MaxBudgetTime)
	local moved = Vector3.new(position.X - last.X, 0, position.Z - last.Z).Magnitude
	local limit = check.budget * MovementCheck.CorrectMultiplier + MovementCheck.Margin
	if moved > limit then
		-- 되돌린다. 인정한 위치는 그대로 두어 다음 검사도 그 자리에서 잰다.
		warn(
			string.format(
				"[Move] %s 이동 거리 초과: %.1f스터드/%.2f초 (허용 %.1f, 속도 %.1f) → 되돌림",
				player.Name,
				moved,
				elapsed,
				limit,
				allowedSpeed
			)
		)
		character:PivotTo(CFrame.new(last) * rootPart.CFrame.Rotation)
		rootPart.AssemblyLinearVelocity = Vector3.zero
		return
	end
	if moved > check.budget * MovementCheck.LogMultiplier + MovementCheck.Margin then
		check.suspicious += 1
	end
	check.budget = math.max(0, check.budget - moved)
	check.position = position
	if check.suspicious > 0 and now - check.loggedAt >= MovementCheck.LogInterval then
		print(
			`[Move] {player.Name} 빠른 이동 {check.suspicious}회 (기록만, 최근 {MovementCheck.LogInterval}초)`
		)
		check.suspicious = 0
		check.loggedAt = now
	end
end

local function onPlayerAdded(player: Player): ()
	if states[player] then
		return
	end
	local state: RunState = {
		wantsToRun = false,
		running = false,
		stamina = StaminaConfig.Max,
		lastRunAt = 0,
		nextNoiseAt = 0,
		stunnedUntil = 0,
		boostUntil = 0,
		boostMultiplier = 1,
		shownStamina = nil,
		check = {
			position = nil,
			at = 0,
			budget = 0,
			speed = 0,
			previousSpeed = 0,
			graceUntil = 0,
			suspicious = 0,
			loggedAt = 0,
		},
	}
	states[player] = state
	publish(player, state)

	player:GetAttributeChangedSignal(Attribute.Role):Connect(function()
		refill(player, state)
	end)
	player.CharacterAdded:Connect(function()
		refill(player, state)
	end)
end

-- 서버가 캐릭터를 옮겼다 (PivotTo 등). 이동 거리 검사가 되돌리지 않게 잠깐 쉬고 새 위치부터 다시 잰다.
function MovementService.markTeleported(player: Player): ()
	local state = states[player]
	if state then
		resetCheck(state)
	end
end

-- seconds초 동안 움직이지 못하게 한다 (판자에 맞은 추격자). 추격자 공격도 막힌다 (CatchService가 isStunned를 봄).
function MovementService.stun(player: Player, seconds: number): ()
	local state = states[player]
	if state then
		state.stunnedUntil = math.max(state.stunnedUntil, os.clock() + seconds)
		player:SetAttribute(Attribute.Stunned, true)
	end
end

-- seconds초 동안 이동 속도 × multiplier (사냥꾼 돌진)
function MovementService.boost(player: Player, multiplier: number, seconds: number): ()
	local state = states[player]
	if state then
		state.boostMultiplier = multiplier
		state.boostUntil = os.clock() + seconds
	end
end

function MovementService.isStunned(player: Player): boolean
	local state = states[player]
	return state ~= nil and os.clock() < state.stunnedUntil
end

-- 스태미나를 최대치의 fraction만큼 채운다 (에너지 드링크).
function MovementService.restoreStamina(player: Player, fraction: number): ()
	local state = states[player]
	if state then
		state.stamina = math.min(StaminaConfig.Max, state.stamina + StaminaConfig.Max * fraction)
		publish(player, state)
	end
end

function MovementService.Init(): ()
	assert(
		Chasers[Match.DefaultChaser],
		`Config.Match.DefaultChaser({Match.DefaultChaser})가 Config.Chasers에 없습니다`
	)
end

function MovementService.Start(): ()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)

	RemoteHandler.connect("SetRunning", function(player: Player, wantsToRun: unknown)
		if typeof(wantsToRun) ~= "boolean" then
			return
		end
		local state = states[player]
		if state then
			state.wantsToRun = wantsToRun
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		local now = os.clock()
		for player, state in states do
			update(player, state, deltaTime, now)
		end
		if MovementCheck.Enabled and now >= nextCheckAt then
			nextCheckAt = now + MovementCheck.Interval
			for player, state in states do
				checkMovement(player, state, now)
			end
		end
	end)
end

return MovementService
