--!strict
-- UIController: 기본 HUD·역할 공개·알림 (GDD 1.3, 2.1, 11장, 13.2). StarterGui 없이 여기서 ScreenGui를 만든다.
--
-- 화면 (ScreenGui "Hud", 크기는 UiStyle.addScale이 화면에 맞춰 줄인다)
-- 시야를 가리지 않게 화면 가운데(위 가운데 포함)에는 계속 떠 있는 UI를 두지 않는다 (CLAUDE.md). 잠깐 뜨는 것만 위 가운데.
--   오른쪽 위    작은 상태 패널: 스테이지 이름 / 단계(대기·역할 공개·준비·추격·결과) / 남은 시간 / 남은 생존자 수 /
--               목표 진행(발전기 n/전체, 다 고치면 "출구 열림!"). 로비에서는 같이 하기 대기 인원.
--               스테이지 이름은 "스테이지 (매치 안 순서) · 맵 이름" (맵은 투표로 정함, StageIndex).
--               투표 단계에는 단계(투표)와 남은 시간만. 투표 창은 VoteController.
--               관전 중(SpectateController가 같은 자리에 관전 패널)과 최종 결과 단계(ResultController)에는 숨긴다.
--               추격 단계 남은 시간이 Config.Ui.TimerWarningTime 이하면 시계를 강조색으로.
--               Roblox 기본 플레이어 목록(같은 자리)은 끈다. 플레이어 목록은 Roblox 메뉴(Esc)의 사람 탭에서 볼 수 있다.
--   위 가운데    잠깐 뜨는 것만: 역할 공개 카드와 알림(Notice 리모트, Strings.Notices)을 세로로 쌓는다.
--               알림은 Config.Ui.NoticeDuration초 뒤 사라진다
--   아래 가운데  생존자: 상태(정상/부상), 스태미나 바, 아이템 2칸(이름·색. 누르면 사용, 숫자키 1·2는 SurvivorController).
--               발전기를 고치는 동안 그 위에 수리 진행 바 (Player Attribute RepairProgress).
--               스테이지 중 코인이 늘면(수리 10%마다 1코인 등, Player Attribute Coins) 그 위로 금색 "+n 코인"이 떠오른다
--               추격자: 공격 쿨다운 바 (ChaserController가 공격할 때 UIController.startAttackCooldown을 부름).
--               판자에 맞아 기절하면 "기절!" (Player Attribute Stunned). 그 아래 고유 스킬 이름과 쿨다운 (SkillReadyAt)
--               휴대폰에서 왼쪽 아래 이동 스틱, 오른쪽 아래 점프·화면 버튼(InputController)과 겹치지 않게 가운데에 좁게 둔다.
--   키 안내 (S3-5): 지금 플랫폼(InputController.getPlatform)에 맞는 키를 붙인다. 아이템 칸 왼쪽 위(1·2 / LB·RB),
--               생존자 상태 줄 오른쪽([Shift] 달리기 / [L3] 달리기), 추격자 공격·스킬 줄 끝([클릭]·[E] / [R2]·[Y]).
--               휴대폰은 화면 버튼에 이름이 있어 키 안내를 숨기고, 공격만 [화면 탭]. 화면 버튼의 흐림(스태미나 부족,
--               스킬 쿨다운)과 스킬 버튼의 남은 초도 여기서 맞춘다.
--   가운데       역할 공개: RoleReveal 리모트를 받으면 후보 이름이 돌다가(Config.Ui.RoleReveal.SpinTime)
--               추격자 이름에서 멈추고, 내 역할과 목표 한 줄(Strings.RoleGoals)을 ResultHoldTime초 보여준다.
--               솔로는 룰렛이 없으므로 준비 단계가 시작될 때 솔로 안내와 역할·목표를 보여준다.
-- 발전기 위 진행 바는 Util/GeneratorBillboards가 만든다.
-- 값은 모두 서버가 정한 Attribute(MatchState)를 읽어 보여주기만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survivor = require(ReplicatedStorage.Shared.Config.Survivor)
local Types = require(ReplicatedStorage.Shared.Types)
local Ui = require(ReplicatedStorage.Shared.Config.Ui)
local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local GeneratorBillboards = require(script.Parent.Parent.Util.GeneratorBillboards)
local WorldTextLocalizer = require(script.Parent.Parent.Util.WorldTextLocalizer)
local InputController = require(script.Parent.InputController)
local SurvivorController = require(script.Parent.SurvivorController)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)

local Colors = UiStyle.Colors
local ATTACK_READY_SLACK = 0.05 -- 트윈이 끝난 시각과 쿨다운 끝 시각의 차이를 봐줌 (초)
local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

-- 스테이지가 진행 중인 단계 (남은 생존자 수를 보여줌)
local STAGE_PHASES: { [Types.MatchPhase]: boolean } = {
	RoleReveal = true,
	Preparation = true,
	Chase = true,
	StageResult = true,
}

type TopView = {
	frame: Frame,
	stageLabel: TextLabel,
	phaseLabel: TextLabel,
	timerLabel: TextLabel,
	infoLabel: TextLabel,
	objectiveLabel: TextLabel,
}

type SurvivorView = {
	frame: Frame,
	statusLabel: TextLabel,
	statusStroke: UIStroke,
	staminaFill: Frame,
	runHint: TextLabel,
	slots: { TextButton },
	keyLabels: { TextLabel },
}

type RepairView = {
	frame: Frame,
	label: TextLabel,
	fill: Frame,
}

type ChaserView = {
	frame: Frame,
	attackLabel: TextLabel,
	attackFill: Frame,
	skillLabel: TextLabel,
	skillFill: Frame,
}

type RevealView = {
	frame: Frame,
	titleLabel: TextLabel,
	nameLabel: TextLabel,
	roleLabel: TextLabel,
	goalLabel: TextLabel,
}

type Hud = {
	gui: ScreenGui,
	center: Frame,
	top: TopView,
	notices: Frame,
	survivor: SurvivorView,
	repair: RepairView,
	chaser: ChaserView,
	reveal: RevealView,
}

local UIController = {}

local hud: Hud? = nil
local revealToken = 0 -- 올릴 때마다 진행 중인 역할 공개 연출을 멈춘다
local noticeSerial = 0
local attackTween: Tween? = nil
local attackReadyAt = 0 -- os.clock
local lastCoins: number? = nil
local COIN_POPUP_TIME = 0.9 -- "+n 코인"이 떠올라 사라지는 시간 (초)
local COIN_COLOR = Color3.fromRGB(255, 205, 80)

--------------------------------------------------------------------------------
-- 화면 만들기

-- 줄이 넘치면 잘라내지 않고 아래로 늘린다 (영어 스테이지 이름, 로비 대기 안내).
local function wrap(label: TextLabel): ()
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
	label.AutomaticSize = Enum.AutomaticSize.Y
end

local function createTop(gui: ScreenGui): TopView
	local frame = UiStyle.panel(gui, "Top", true)
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -12, 0, 8)
	frame.Size = UDim2.fromOffset(210, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	UiStyle.padding(frame, 6, 10)
	UiStyle.list(frame, Enum.FillDirection.Vertical, 0)

	local stageLabel = UiStyle.label(frame, "Stage", 1, 18)
	stageLabel.TextColor3 = Colors.Subtext
	wrap(stageLabel)
	local phaseLabel = UiStyle.label(frame, "Phase", 2, 20)
	phaseLabel.Font = UiStyle.BoldFont
	phaseLabel.TextColor3 = Colors.Accent
	local timerLabel = UiStyle.label(frame, "Timer", 3, 32)
	timerLabel.Font = UiStyle.BoldFont
	timerLabel.TextSize = 30
	local infoLabel = UiStyle.label(frame, "Info", 4, 20)
	wrap(infoLabel)
	local objectiveLabel = UiStyle.label(frame, "Objective", 5, 20)
	objectiveLabel.Font = UiStyle.BoldFont
	return {
		frame = frame,
		stageLabel = stageLabel,
		phaseLabel = phaseLabel,
		timerLabel = timerLabel,
		infoLabel = infoLabel,
		objectiveLabel = objectiveLabel,
	}
end

-- 위 가운데의 세로 목록 (잠깐 뜨는 것만): 역할 공개 카드, 그 아래 알림. 둘이 함께 떠도 겹치지 않는다.
local function createCenter(gui: ScreenGui): Frame
	local frame = UiStyle.container(gui, "Center")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 8)
	frame.Size = UDim2.fromOffset(560, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local layout = UiStyle.list(frame, Enum.FillDirection.Vertical, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	return frame
end

local function createNotices(center: Frame): Frame
	local frame = UiStyle.container(center, "Notices")
	frame.LayoutOrder = 2
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local layout = UiStyle.list(frame, Enum.FillDirection.Vertical, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	return frame
end

local function createSurvivor(gui: ScreenGui): SurvivorView
	local frame = UiStyle.container(gui, "Survivor")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -14)
	frame.Size = UDim2.fromOffset(0, 64)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Visible = false
	UiStyle.list(frame, Enum.FillDirection.Horizontal, 10)

	-- 상태와 스태미나
	local info = UiStyle.panel(frame, "Status", false)
	info.LayoutOrder = 1
	info.Size = UDim2.fromOffset(300, 64)
	UiStyle.padding(info, 6, 12)
	UiStyle.list(info, Enum.FillDirection.Vertical, 4)
	local statusLabel = UiStyle.label(info, "State", 1, 26)
	statusLabel.Font = UiStyle.BoldFont
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	local statusStroke = UiStyle.stroke(info, Colors.Good, 0.2)
	-- 상태 줄 오른쪽: 달리기 키 안내
	local runHint = UiStyle.label(statusLabel, "RunHint", 0, 26)
	runHint.Size = UDim2.fromScale(1, 1)
	runHint.TextSize = 15
	runHint.TextXAlignment = Enum.TextXAlignment.Right
	runHint.TextColor3 = Colors.Subtext
	local _, staminaFill = UiStyle.bar(info, "Stamina", 2, UDim2.new(1, 0, 0, 14), Colors.Stamina)

	-- 아이템 2칸
	local slots: { TextButton } = {}
	local keyLabels: { TextLabel } = {}
	for index = 1, Survivor.InventorySlots do
		local slot = UiStyle.button(frame, `Item{index}`, 1 + index, UDim2.fromOffset(64, 64), true)
		slot.TextSize = 16
		slot.TextWrapped = true
		slot.Text = "" -- 빈칸. 아이템 이름은 S2-4에서
		local key = UiStyle.label(slot, "Key", 0, 18)
		key.Size = UDim2.fromOffset(30, 18)
		key.Position = UDim2.fromOffset(4, 2)
		key.TextSize = 15
		key.TextXAlignment = Enum.TextXAlignment.Left
		key.Font = UiStyle.BoldFont
		key.TextColor3 = Colors.Accent
		table.insert(slots, slot)
		table.insert(keyLabels, key)
	end
	return {
		frame = frame,
		statusLabel = statusLabel,
		statusStroke = statusStroke,
		staminaFill = staminaFill,
		runHint = runHint,
		slots = slots,
		keyLabels = keyLabels,
	}
end

-- 생존자 HUD 바로 위: 발전기 수리 진행
local function createRepair(gui: ScreenGui): RepairView
	local frame = UiStyle.panel(gui, "Repair", true)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -88)
	frame.Size = UDim2.fromOffset(250, 52)
	frame.Visible = false
	UiStyle.padding(frame, 5, 12)
	UiStyle.list(frame, Enum.FillDirection.Vertical, 4)
	local label = UiStyle.label(frame, "Text", 1, 22)
	label.Font = UiStyle.BoldFont
	local _, fill = UiStyle.bar(frame, "Bar", 2, UDim2.new(1, 0, 0, 12), Colors.Accent)
	return { frame = frame, label = label, fill = fill }
end

local function createChaser(gui: ScreenGui): ChaserView
	local frame = UiStyle.panel(gui, "Chaser", true)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -14)
	frame.Size = UDim2.fromOffset(250, 112)
	frame.Visible = false
	UiStyle.padding(frame, 6, 12)
	UiStyle.list(frame, Enum.FillDirection.Vertical, 4)
	local attackLabel = UiStyle.label(frame, "Attack", 1, 26)
	attackLabel.Font = UiStyle.BoldFont
	attackLabel.TextXAlignment = Enum.TextXAlignment.Left
	attackLabel.Text = Strings.Hud.AttackReady
	local _, attackFill = UiStyle.bar(frame, "Cooldown", 2, UDim2.new(1, 0, 0, 14), Colors.Accent)
	local skillLabel = UiStyle.label(frame, "Skill", 3, 26)
	skillLabel.Font = UiStyle.BoldFont
	skillLabel.TextXAlignment = Enum.TextXAlignment.Left
	local _, skillFill = UiStyle.bar(frame, "SkillCooldown", 4, UDim2.new(1, 0, 0, 14), Colors.Warning)
	return {
		frame = frame,
		attackLabel = attackLabel,
		attackFill = attackFill,
		skillLabel = skillLabel,
		skillFill = skillFill,
	}
end

local function createReveal(center: Frame): RevealView
	local frame = UiStyle.panel(center, "RoleReveal", true)
	frame.LayoutOrder = 1
	frame.Size = UDim2.fromScale(1, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Visible = false
	UiStyle.padding(frame, 16, 20)
	UiStyle.list(frame, Enum.FillDirection.Vertical, 6)

	local titleLabel = UiStyle.label(frame, "Title", 1, 26)
	titleLabel.Font = UiStyle.BoldFont
	titleLabel.TextColor3 = Colors.Accent
	local nameLabel = UiStyle.label(frame, "Name", 2, 52)
	nameLabel.Font = UiStyle.BoldFont
	local roleLabel = UiStyle.label(frame, "Role", 3, 40)
	roleLabel.Font = UiStyle.BoldFont
	local goalLabel = UiStyle.label(frame, "Goal", 4, 24)
	goalLabel.TextColor3 = Colors.Subtext
	goalLabel.TextWrapped = true
	goalLabel.TextTruncate = Enum.TextTruncate.None
	goalLabel.AutomaticSize = Enum.AutomaticSize.Y
	return {
		frame = frame,
		titleLabel = titleLabel,
		nameLabel = nameLabel,
		roleLabel = roleLabel,
		goalLabel = goalLabel,
	}
end

local function createHud(): Hud
	local gui = UiStyle.screenGui("Hud", 5)
	UiStyle.addScale(gui)
	local center = createCenter(gui)
	local view: Hud = {
		gui = gui,
		center = center,
		top = createTop(gui),
		notices = createNotices(center),
		survivor = createSurvivor(gui),
		repair = createRepair(gui),
		chaser = createChaser(gui),
		reveal = createReveal(center),
	}
	gui.Parent = UiStyle.playerGui()
	return view
end

--------------------------------------------------------------------------------
-- 오른쪽 위: 단계·시간·남은 생존자

local function renderTop(): ()
	local view = hud
	if not view then
		return
	end
	local top = view.top
	local phase = MatchState.getPhase()
	local stageId = MatchState.getStageId()
	local timeLeft = MatchState.getTimeLeft()
	-- 관전 중에는 관전 화면이, 최종 결과 단계에는 결과 화면(ResultController)이 같은 정보를 보여준다.
	top.frame.Visible = not MatchState.isSpectating(localPlayer) and phase ~= "MatchResult"

	if stageId then
		local index = MatchState.getStageIndex() or Stages[stageId].Number
		top.stageLabel.Text = string.format(Strings.Hud.StageTitle, index, Strings.Stages[stageId])
	end
	top.stageLabel.Visible = stageId ~= nil
	top.phaseLabel.Text = Strings.Phases[phase]

	local done, total = MatchState.getGenerators()
	local showObjective = total ~= nil and STAGE_PHASES[phase] == true
	top.objectiveLabel.Visible = showObjective
	if showObjective then
		local exitOpen = MatchState.isExitOpen()
		top.objectiveLabel.Text = if exitOpen
			then Strings.Hud.ExitOpen
			else string.format(Strings.Hud.Objective, done, total or 0)
		top.objectiveLabel.TextColor3 = if exitOpen then Colors.Good else Colors.Text
	end

	if phase == "Waiting" then
		-- 로비: 같이 하기 대기 인원과 시작까지 남은 시간 (혼자 하기 서버는 서버 이름)
		top.timerLabel.Visible = false
		top.infoLabel.Visible = true
		local queueCount = MatchState.getQueueCount()
		local lines: { string } = {}
		if MatchState.isSoloServer() then
			table.insert(lines, Strings.Lobby.SoloServer)
		elseif queueCount > 0 then
			table.insert(lines, string.format(Strings.Lobby.QueueCount, queueCount))
		end
		if timeLeft then
			table.insert(lines, string.format(Strings.Hud.StartsIn, timeLeft))
		elseif queueCount == 1 then
			table.insert(lines, Strings.Lobby.NeedMore)
		end
		top.infoLabel.Text = if #lines > 0 then table.concat(lines, "\n") else Strings.Hud.WaitingForPlayers
		return
	end
	top.timerLabel.Visible = timeLeft ~= nil
	if timeLeft then
		local minutes, seconds = UiStyle.clock(timeLeft)
		top.timerLabel.Text = string.format(Strings.Hud.Clock, minutes, seconds)
		local warning = phase == "Chase" and timeLeft <= Ui.TimerWarningTime
		top.timerLabel.TextColor3 = if warning then Colors.Accent else Colors.Text
	end
	top.infoLabel.Text = if STAGE_PHASES[phase]
		then string.format(Strings.Hud.SurvivorsLeft, MatchState.getSurvivorsLeft())
		else ""
	top.infoLabel.Visible = top.infoLabel.Text ~= ""
end

--------------------------------------------------------------------------------
-- 아래 가운데: 생존자·추격자

local function renderSurvivor(): ()
	local view = hud
	if not view then
		return
	end
	local survivorView = view.survivor
	local role = MatchState.getRole(localPlayer)
	survivorView.frame.Visible = role == "Survivor"
	view.chaser.frame.Visible = role == "Chaser"
	if role ~= "Survivor" then
		return
	end
	local state: Types.SurvivorState = MatchState.getSurvivorState(localPlayer) or "Normal"
	local injured = state == "Injured"
	survivorView.statusLabel.Text = `{Strings.Roles.Survivor} · {Strings.SurvivorStates[state]}`
	survivorView.statusLabel.TextColor3 = if injured then Colors.Warning else Colors.Text
	survivorView.statusStroke.Color = if injured then Colors.Warning else Colors.Good

	local config = Survivor.Stamina
	local stamina = MatchState.getStamina(localPlayer) or config.Max
	survivorView.staminaFill.Size = UDim2.fromScale(math.clamp(stamina / config.Max, 0, 1), 1)
	survivorView.staminaFill.BackgroundColor3 = if stamina < config.MinToStartRun
		then Colors.Warning
		else Colors.Stamina
	InputController.setTouchDimmed("Run", stamina < config.MinToStartRun)

	local runKey = InputController.hint("Run")
	survivorView.runHint.Text = if runKey then string.format(Strings.Input.KeyAction, runKey, Strings.Hud.Run) else ""
	for slot, keyLabel in survivorView.keyLabels do
		local key = InputController.hint(if slot == 1 then "Item1" else "Item2")
		keyLabel.Text = key or ""
		keyLabel.Visible = key ~= nil
	end

	local battery = localPlayer:GetAttribute(Attribute.FlashlightBattery)
	local flashlightOn = localPlayer:GetAttribute(Attribute.FlashlightOn) == true
	for slot, button in survivorView.slots do
		local itemId = MatchState.getItem(localPlayer, slot)
		local text = if itemId then Strings.Items[itemId] else ""
		if itemId == "Flashlight" and typeof(battery) == "number" then
			text = string.format(Strings.Hud.Battery, text, math.floor(battery * 100))
		end
		button.Text = text
		button.BackgroundTransparency = if itemId == "Flashlight" and flashlightOn then 0 else UiStyle.PanelTransparency
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if itemId then Items[itemId].Color else Colors.Accent
		end
	end
end

local function renderChaser(): ()
	local view = hud
	if not view then
		return
	end
	local chaserView = view.chaser
	local text: string
	if MatchState.isStunned(localPlayer) then
		text = Strings.Hud.Stunned
		chaserView.attackLabel.TextColor3 = Colors.Warning
	elseif os.clock() >= attackReadyAt - ATTACK_READY_SLACK then
		text = Strings.Hud.AttackReady
		chaserView.attackLabel.TextColor3 = Colors.Text
	else
		text = Strings.Hud.Attack
		chaserView.attackLabel.TextColor3 = Colors.Subtext
	end
	local key = InputController.hint("Attack")
	chaserView.attackLabel.Text = if key then string.format(Strings.Input.WithKey, text, key) else text
	-- 휴대폰 공격 버튼: 기절·쿨다운 중이면 흐리게
	InputController.setTouchDimmed("Attack", text ~= Strings.Hud.AttackReady)
end

-- 스테이지 중 코인이 늘면 수리 바 위로 "+n 코인"을 띄운다.
local function onCoinsChanged(): ()
	local coins = MatchState.getCoins(localPlayer)
	local previous = lastCoins
	lastCoins = coins
	local view = hud
	if not view or not coins or not previous or coins <= previous or MatchState.getRole(localPlayer) == nil then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "CoinPopup"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -146)
	label.Size = UDim2.fromOffset(160, 30)
	label.BackgroundTransparency = 1
	label.Font = UiStyle.BoldFont
	label.TextSize = 26
	label.TextColor3 = COIN_COLOR
	label.TextStrokeTransparency = 0.4
	label.Text = string.format(Strings.Hud.CoinGain, coins - previous)
	label.Parent = view.gui
	local tween =
		TweenService:Create(label, TweenInfo.new(COIN_POPUP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, -186),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
	tween.Completed:Once(function()
		label:Destroy()
	end)
	tween:Play()
end

local function renderRepair(): ()
	local view = hud
	if not view then
		return
	end
	local progress = MatchState.getRepairProgress(localPlayer)
	view.repair.frame.Visible = progress ~= nil
	if progress then
		view.repair.label.Text = string.format(Strings.Hud.Repairing, math.floor(progress * 100))
		view.repair.fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	end
end

-- 추격자 스킬 쿨다운 (서버가 공개한 SkillReadyAt과 서버 시각으로 계산). 매 프레임 부른다.
local function renderSkill(): ()
	local view = hud
	if not view or MatchState.getRole(localPlayer) ~= "Chaser" then
		return
	end
	local chaserView = view.chaser
	local chaserType = MatchState.getChaserType(localPlayer) or Match.DefaultChaser
	local def = Chasers[chaserType].Skill
	local name = Strings.Skills[def.Kind]
	local readyAt = MatchState.getSkillReadyAt(localPlayer)
	local remaining = if readyAt then readyAt - Workspace:GetServerTimeNow() else 0
	local text: string
	if remaining > 0 then
		text = string.format(Strings.Hud.SkillCooldown, name, math.ceil(remaining))
		chaserView.skillLabel.TextColor3 = Colors.Subtext
		chaserView.skillFill.Size = UDim2.fromScale(math.clamp(1 - remaining / def.Cooldown, 0, 1), 1)
		chaserView.skillFill.BackgroundColor3 = Colors.Disabled
	else
		text = string.format(Strings.Hud.SkillReady, name)
		chaserView.skillLabel.TextColor3 = Colors.Text
		chaserView.skillFill.Size = UDim2.fromScale(1, 1)
		chaserView.skillFill.BackgroundColor3 = Colors.Warning
	end
	local key = InputController.hint("Skill")
	chaserView.skillLabel.Text = if key then string.format(Strings.Input.WithKey, text, key) else text
	-- 휴대폰 스킬 버튼: 쓸 수 있으면 스킬 이름, 쿨다운 중이면 남은 초와 흐림
	InputController.setTouchLabel("Skill", if remaining > 0 then tostring(math.ceil(remaining)) else name)
	InputController.setTouchDimmed("Skill", remaining > 0)
end

-- 다른 컨트롤러의 화면 조각(스테이지 결과 등)을 위 가운데 세로 목록에 넣는다. 역할 공개 카드는 1, 알림은 2라
-- order가 그보다 작으면 위에 놓인다. 목록에 함께 있으면 알림과 겹치지 않는다. Start 이후에 부른다.
function UIController.mountCenter(frame: GuiObject, order: number): ()
	local view = hud
	if view then
		frame.LayoutOrder = order
		frame.Parent = view.center
	end
end

-- 추격자가 공격하면 쿨다운 동안 바가 다시 차오른다.
function UIController.startAttackCooldown(duration: number): ()
	local view = hud
	if not view then
		return
	end
	local chaserView = view.chaser
	attackReadyAt = os.clock() + duration
	if attackTween then
		attackTween:Cancel()
	end
	chaserView.attackFill.Size = UDim2.fromScale(0, 1)
	chaserView.attackFill.BackgroundColor3 = Colors.Disabled
	local tween = TweenService:Create(
		chaserView.attackFill,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	)
	attackTween = tween
	tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
		if playbackState == Enum.PlaybackState.Completed and os.clock() >= attackReadyAt - ATTACK_READY_SLACK then
			chaserView.attackFill.BackgroundColor3 = Colors.Accent
			renderChaser()
		end
	end)
	renderChaser()
	tween:Play()
end

--------------------------------------------------------------------------------
-- 알림

local function fadeOut(instance: GuiObject, label: TextLabel, time: number): ()
	local info = TweenInfo.new(time)
	TweenService:Create(instance, info, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
end

local function showNotice(text: string): ()
	local view = hud
	if not view then
		return
	end
	noticeSerial += 1
	local toast = UiStyle.panel(view.notices, `Notice{noticeSerial}`, false)
	toast.LayoutOrder = noticeSerial
	toast.Size = UDim2.fromOffset(0, 0)
	toast.AutomaticSize = Enum.AutomaticSize.XY
	UiStyle.padding(toast, 6, 16)
	local label = UiStyle.label(toast, "Text", 1, 28)
	label.Size = UDim2.fromOffset(0, 28)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Font = UiStyle.BoldFont
	label.TextTruncate = Enum.TextTruncate.None
	label.Text = text

	-- 오래된 것부터 지워 MaxNotices개까지만 둔다.
	local toasts: { Frame } = {}
	for _, child in view.notices:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a: Frame, b: Frame): boolean
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #toasts - Ui.MaxNotices do
		toasts[index]:Destroy()
	end

	task.delay(Ui.NoticeDuration, function()
		if toast.Parent then
			fadeOut(toast, label, Ui.NoticeFadeTime)
			task.wait(Ui.NoticeFadeTime)
			toast:Destroy()
		end
	end)
end

local function onNotice(key: unknown, ...: unknown): ()
	if typeof(key) ~= "string" then
		return
	end
	local template = Strings.Notices[key :: Types.NoticeKey]
	if not template then
		return
	end
	local args: { string | number } = {}
	for _, value in { ... } do
		if typeof(value) == "string" or typeof(value) == "number" then
			table.insert(args, value)
		end
	end
	local ok, text = pcall(string.format, template, table.unpack(args))
	showNotice(if ok then text else template)
end

--------------------------------------------------------------------------------
-- 역할 공개

local function hideReveal(token: number): ()
	local view = hud
	if not view or token ~= revealToken then
		return
	end
	view.reveal.frame.Visible = false
end

-- 내 역할과 목표 한 줄을 보여주고 ResultHoldTime초 뒤 숨긴다.
local function showRoleResult(title: string, name: string?, role: Types.Role, token: number): ()
	local view = hud
	if not view or token ~= revealToken then
		return
	end
	local reveal = view.reveal
	reveal.frame.Visible = true
	reveal.titleLabel.Text = title
	reveal.nameLabel.Visible = name ~= nil
	reveal.nameLabel.Text = name or ""
	reveal.nameLabel.TextColor3 = Colors.Accent
	reveal.roleLabel.Visible = true
	reveal.roleLabel.Text = if role == "Chaser"
		then Strings.RoleReveal.YouAreChaser
		else Strings.RoleReveal.YouAreSurvivor
	reveal.goalLabel.Visible = true
	reveal.goalLabel.Text = Strings.RoleGoals[role]
	task.delay(Ui.RoleReveal.ResultHoldTime, hideReveal, token)
end

-- 후보 이름이 점점 느리게 돌다가 추격자 이름에서 멈춘다 (GDD 2.1).
local function playRoulette(chaserUserId: number, candidateUserIds: { number }): ()
	local view = hud
	if not view then
		return
	end
	revealToken += 1
	local token = revealToken
	local chaser = Players:GetPlayerByUserId(chaserUserId)
	local chaserName = if chaser then chaser.DisplayName else "?"
	local names: { string } = {}
	for _, userId in candidateUserIds do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(names, player.DisplayName)
		end
	end
	if #names == 0 then
		table.insert(names, chaserName)
	end

	local reveal = view.reveal
	reveal.frame.Visible = true
	reveal.titleLabel.Text = Strings.RoleReveal.Choosing
	reveal.nameLabel.Visible = true
	reveal.nameLabel.TextColor3 = Colors.Text
	reveal.roleLabel.Visible = false
	reveal.goalLabel.Visible = false

	local config = Ui.RoleReveal
	local index = math.random(1, #names)
	local elapsed = 0
	while elapsed < config.SpinTime do
		if token ~= revealToken then
			return
		end
		index = index % #names + 1
		reveal.nameLabel.Text = names[index]
		local progress = elapsed / config.SpinTime
		local interval = config.SpinStartInterval
			+ (config.SpinEndInterval - config.SpinStartInterval) * progress * progress
		task.wait(interval)
		elapsed += interval
	end
	local isMe = chaserUserId == localPlayer.UserId
	showRoleResult(Strings.RoleReveal.ChaserTitle, chaserName, if isMe then "Chaser" else "Survivor", token)
end

local function onPhaseChanged(): ()
	renderTop()
	local phase = MatchState.getPhase()
	if phase == "Preparation" and not MatchState.hasChaser() and MatchState.getRole(localPlayer) == "Survivor" then
		-- 솔로: 룰렛 없이 역할과 목표만 (GDD 3.1)
		revealToken += 1
		showRoleResult(Strings.RoleReveal.Solo, nil, "Survivor", revealToken)
	elseif phase == "Waiting" then
		revealToken += 1
		hideReveal(revealToken)
	end
end

--------------------------------------------------------------------------------

function UIController.Init(): () end

function UIController.Start(): ()
	-- 오른쪽 위 상태 패널과 겹치는 Roblox 기본 플레이어 목록을 끈다 (Esc 메뉴의 사람 탭에는 그대로 있다).
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	hud = createHud()

	for _, name in
		{
			Attribute.TimeLeft,
			Attribute.StageId,
			Attribute.SurvivorsLeft,
			Attribute.HasChaser,
			Attribute.GeneratorsDone,
			Attribute.GeneratorsTotal,
			Attribute.ExitOpen,
			Attribute.QueueCount,
			Attribute.StageIndex,
			Attribute.SoloServer,
		}
	do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(renderTop)
	end
	localPlayer:GetAttributeChangedSignal(Attribute.RepairProgress):Connect(renderRepair)
	lastCoins = MatchState.getCoins(localPlayer)
	localPlayer:GetAttributeChangedSignal(Attribute.Coins):Connect(onCoinsChanged)
	GeneratorBillboards.start()
	WorldTextLocalizer.start()
	ReplicatedStorage:GetAttributeChangedSignal(Attribute.Phase):Connect(onPhaseChanged)
	localPlayer:GetAttributeChangedSignal(Attribute.Spectating):Connect(renderTop)
	for _, name in
		{
			Attribute.Role,
			Attribute.SurvivorState,
			Attribute.Stamina,
			Attribute.Item1,
			Attribute.Item2,
			Attribute.FlashlightOn,
			Attribute.FlashlightBattery,
		}
	do
		localPlayer:GetAttributeChangedSignal(name):Connect(renderSurvivor)
	end
	localPlayer:GetAttributeChangedSignal(Attribute.Stunned):Connect(renderChaser)
	InputController.onPlatformChanged(function()
		renderSurvivor()
		renderChaser()
	end)
	RunService.Heartbeat:Connect(renderSkill)
	local view = hud
	if view then
		for slot, button in view.survivor.slots do
			button.Activated:Connect(function()
				SurvivorController.useItem(slot)
			end)
		end
	end

	Remotes.get("Notice").OnClientEvent:Connect(onNotice)
	Remotes.get("RoleReveal").OnClientEvent:Connect(function(chaserUserId: unknown, candidateUserIds: unknown)
		if typeof(chaserUserId) ~= "number" or typeof(candidateUserIds) ~= "table" then
			return
		end
		local ids: { number } = {}
		for _, userId in candidateUserIds :: { unknown } do
			if typeof(userId) == "number" then
				table.insert(ids, userId)
			end
		end
		task.spawn(playRoulette, chaserUserId, ids)
	end)

	renderTop()
	renderSurvivor()
	renderChaser()
end

return UIController
