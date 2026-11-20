--!strict
-- UIController: 기본 HUD·역할 공개·알림 (GDD 1.3, 2.1, 11장, 13.2). StarterGui 없이 여기서 ScreenGui를 만든다.
--
-- 화면 (ScreenGui "Hud", 크기는 UiStyle.addScale이 화면에 맞춰 줄인다)
--   위 가운데    스테이지 이름 / 단계(대기·역할 공개·준비·추격·결과) / 남은 시간(크게) / 남은 생존자 수.
--               관전 중에는 관전 화면(SpectateController)이 같은 정보를 보여주므로 숨긴다.
--               추격 단계 남은 시간이 Config.Ui.TimerWarningTime 이하면 시계를 강조색으로.
--   그 아래      역할 공개 카드와 알림(Notice 리모트, Strings.Notices)을 세로로 쌓는다.
--               알림은 Config.Ui.NoticeDuration초 뒤 사라진다
--   아래 가운데  생존자: 상태(정상/부상), 스태미나 바, 아이템 2칸(빈칸. S2-4에서 채움)
--               추격자: 공격 쿨다운 바 (ChaserController가 공격할 때 UIController.startAttackCooldown을 부름)
--               휴대폰에서 왼쪽 아래 이동 스틱, 오른쪽 아래 점프·달리기 버튼과 겹치지 않게 가운데에 좁게 둔다.
--   가운데       역할 공개: RoleReveal 리모트를 받으면 후보 이름이 돌다가(Config.Ui.RoleReveal.SpinTime)
--               추격자 이름에서 멈추고, 내 역할과 목표 한 줄(Strings.RoleGoals)을 ResultHoldTime초 보여준다.
--               솔로는 룰렛이 없으므로 준비 단계가 시작될 때 솔로 안내와 역할·목표를 보여준다.
-- 값은 모두 서버가 정한 Attribute(MatchState)를 읽어 보여주기만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survivor = require(ReplicatedStorage.Shared.Config.Survivor)
local Types = require(ReplicatedStorage.Shared.Types)
local Ui = require(ReplicatedStorage.Shared.Config.Ui)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)

local Colors = UiStyle.Colors
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
}

type SurvivorView = {
	frame: Frame,
	statusLabel: TextLabel,
	statusStroke: UIStroke,
	staminaFill: Frame,
	slots: { TextButton },
}

type ChaserView = {
	frame: Frame,
	attackLabel: TextLabel,
	attackFill: Frame,
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
	top: TopView,
	notices: Frame,
	survivor: SurvivorView,
	chaser: ChaserView,
	reveal: RevealView,
}

local UIController = {}

local hud: Hud? = nil
local revealToken = 0 -- 올릴 때마다 진행 중인 역할 공개 연출을 멈춘다
local noticeSerial = 0
local attackTween: Tween? = nil
local attackReadyAt = 0 -- os.clock

--------------------------------------------------------------------------------
-- 화면 만들기

local function createTop(gui: ScreenGui): TopView
	local frame = UiStyle.panel(gui, "Top", true)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 8)
	frame.Size = UDim2.fromOffset(300, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	UiStyle.padding(frame, 8, 14)
	UiStyle.list(frame, Enum.FillDirection.Vertical, 0)

	local stageLabel = UiStyle.label(frame, "Stage", 1, 20)
	stageLabel.TextColor3 = Colors.Subtext
	local phaseLabel = UiStyle.label(frame, "Phase", 2, 22)
	phaseLabel.Font = UiStyle.BoldFont
	phaseLabel.TextColor3 = Colors.Accent
	local timerLabel = UiStyle.label(frame, "Timer", 3, 46)
	timerLabel.Font = UiStyle.BoldFont
	timerLabel.TextSize = 44
	local infoLabel = UiStyle.label(frame, "Info", 4, 22)
	return {
		frame = frame,
		stageLabel = stageLabel,
		phaseLabel = phaseLabel,
		timerLabel = timerLabel,
		infoLabel = infoLabel,
	}
end

-- 위 패널 아래의 세로 목록: 역할 공개 카드, 그 아래 알림. 둘이 함께 떠도 겹치지 않는다.
local function createCenter(gui: ScreenGui): Frame
	local frame = UiStyle.container(gui, "Center")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 158)
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
	info.Size = UDim2.fromOffset(250, 64)
	UiStyle.padding(info, 6, 12)
	UiStyle.list(info, Enum.FillDirection.Vertical, 4)
	local statusLabel = UiStyle.label(info, "State", 1, 26)
	statusLabel.Font = UiStyle.BoldFont
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	local statusStroke = UiStyle.stroke(info, Colors.Good, 0.2)
	local _, staminaFill = UiStyle.bar(info, "Stamina", 2, UDim2.new(1, 0, 0, 14), Colors.Stamina)

	-- 아이템 2칸
	local slots: { TextButton } = {}
	for index = 1, Survivor.InventorySlots do
		local slot = UiStyle.button(frame, `Item{index}`, 1 + index, UDim2.fromOffset(64, 64), true)
		slot.TextSize = 16
		slot.TextWrapped = true
		slot.Text = "" -- 빈칸. 아이템 이름은 S2-4에서
		local number = UiStyle.label(slot, "Key", 0, 18)
		number.Size = UDim2.fromOffset(18, 18)
		number.Position = UDim2.fromOffset(4, 2)
		number.TextSize = 16
		number.Font = UiStyle.BoldFont
		number.TextColor3 = Colors.Accent
		number.Text = tostring(index)
		table.insert(slots, slot)
	end
	return {
		frame = frame,
		statusLabel = statusLabel,
		statusStroke = statusStroke,
		staminaFill = staminaFill,
		slots = slots,
	}
end

local function createChaser(gui: ScreenGui): ChaserView
	local frame = UiStyle.panel(gui, "Chaser", true)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -14)
	frame.Size = UDim2.fromOffset(250, 64)
	frame.Visible = false
	UiStyle.padding(frame, 6, 12)
	UiStyle.list(frame, Enum.FillDirection.Vertical, 4)
	local attackLabel = UiStyle.label(frame, "Attack", 1, 26)
	attackLabel.Font = UiStyle.BoldFont
	attackLabel.TextXAlignment = Enum.TextXAlignment.Left
	attackLabel.Text = Strings.Hud.AttackReady
	local _, attackFill = UiStyle.bar(frame, "Cooldown", 2, UDim2.new(1, 0, 0, 14), Colors.Accent)
	return { frame = frame, attackLabel = attackLabel, attackFill = attackFill }
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
		top = createTop(gui),
		notices = createNotices(center),
		survivor = createSurvivor(gui),
		chaser = createChaser(gui),
		reveal = createReveal(center),
	}
	gui.Parent = UiStyle.playerGui()
	return view
end

--------------------------------------------------------------------------------
-- 위 가운데: 단계·시간·남은 생존자

local function renderTop(): ()
	local view = hud
	if not view then
		return
	end
	local top = view.top
	local phase = MatchState.getPhase()
	local stageId = MatchState.getStageId()
	local timeLeft = MatchState.getTimeLeft()
	top.frame.Visible = not MatchState.isSpectating(localPlayer)

	if stageId then
		top.stageLabel.Text = string.format(Strings.Hud.StageTitle, Stages[stageId].Number, Strings.Stages[stageId])
	end
	top.stageLabel.Visible = stageId ~= nil
	top.phaseLabel.Text = Strings.Phases[phase]

	if phase == "Waiting" then
		top.timerLabel.Visible = false
		top.infoLabel.Visible = true
		top.infoLabel.Text = if timeLeft
			then string.format(Strings.Hud.StartsIn, timeLeft)
			else Strings.Hud.WaitingForPlayers
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
	chaserView.attackLabel.Text = Strings.Hud.Attack
	chaserView.attackLabel.TextColor3 = Colors.Subtext
	local tween = TweenService:Create(
		chaserView.attackFill,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	)
	attackTween = tween
	tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
		if playbackState == Enum.PlaybackState.Completed and os.clock() >= attackReadyAt - 0.05 then
			chaserView.attackFill.BackgroundColor3 = Colors.Accent
			chaserView.attackLabel.Text = Strings.Hud.AttackReady
			chaserView.attackLabel.TextColor3 = Colors.Text
		end
	end)
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
	hud = createHud()

	for _, name in { Attribute.TimeLeft, Attribute.StageId, Attribute.SurvivorsLeft, Attribute.HasChaser } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(renderTop)
	end
	ReplicatedStorage:GetAttributeChangedSignal(Attribute.Phase):Connect(onPhaseChanged)
	localPlayer:GetAttributeChangedSignal(Attribute.Spectating):Connect(renderTop)
	for _, name in { Attribute.Role, Attribute.SurvivorState, Attribute.Stamina } do
		localPlayer:GetAttributeChangedSignal(name):Connect(renderSurvivor)
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
end

return UIController
