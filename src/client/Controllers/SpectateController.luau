--!strict
-- SpectateController: 관전 화면·카메라·대상 바꾸기와 관전자 채팅 입력 (GDD 8장, 13.2)
--
-- 서버(SpectateService)가 Player Attribute Spectating·SpectateTarget(MatchState)으로 관전 상태와 대상을 알려준다.
-- 카메라: 관전 중에는 CameraSubject를 대상 Humanoid로 둔다. CameraType Custom이라 대상을 따라가는 3인칭이고
--   대상 주변으로 돌리거나 확대할 수 있다. StreamingEnabled라 대상 캐릭터가 늦게 오거나 다시 생길 수 있어서
--   관전 중에는 매 프레임 확인한다. 관전이 끝나면 내 캐릭터가 있으면 내 Humanoid로 되돌린다
--   (없으면 캐릭터가 새로 생길 때 Roblox가 맞춘다).
-- 대상 바꾸기: 이전 Q·←·LB, 다음 E·→·RB, 화면 버튼(모바일·마우스). SpectateCycle 리모트로 요청하고 서버가 정한다.
--   ←/→는 Roblox 기본 카메라 회전 키라 더 높은 우선순위로 묶어 가로챈다.
-- 화면: 관전 중 / 대상 이름 / 역할·상태(숨음) / 남은 생존자 수·단계와 남은 시간 / 이전·다음 /
--   목표 진행(발전기 n/전체 또는 출구 열림) / 로비로 돌아가기(자리만. S3-2에서 연결).
-- 관전자 채팅: 서버가 관전자 채널(SpectateState.ChatChannelName)에 나를 넣으면 입력창 대상을 그 채널로 바꾸고
--   안내 문구를 띄운다. 빠지면 RBXGeneral로 되돌린다. 관전자 채널 메시지 앞에는 [관전]을 붙인다.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SpectateState = require(ReplicatedStorage.Shared.SpectateState)
local Strings = require(ReplicatedStorage.Shared.Strings)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)

local PREVIOUS_ACTION = "SpectatePrevious"
local NEXT_ACTION = "SpectateNext"
local GENERAL_CHANNEL_NAME = "RBXGeneral" -- TextChatService 기본 채널

type SpectateGui = {
	gui: ScreenGui,
	nameLabel: TextLabel,
	statusLabel: TextLabel,
	infoLabel: TextLabel,
	hintLabel: TextLabel,
	previousButton: TextButton,
	nextButton: TextButton,
}

local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local SpectateController = {}

local cycleRemote: RemoteEvent? = nil
local view: SpectateGui? = nil
local spectating = false
local target: Player? = nil
local targetConnections: { RBXScriptConnection } = {}
local followConnection: RBXScriptConnection? = nil

-- 화면 만들기 ----------------------------------------------------------------------------------------------------

local function createGui(): SpectateGui
	local gui = UiStyle.screenGui("Spectate", 10) -- HUD(5)보다 위, ScreenEffect(암전, 100)보다 아래
	gui.Enabled = false
	UiStyle.addScale(gui)

	-- 위: 대상 정보
	local panel = UiStyle.panel(gui, "Info", true)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 10)
	panel.Size = UDim2.fromOffset(380, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UiStyle.padding(panel, 9, 14)
	UiStyle.list(panel, Enum.FillDirection.Vertical, 2)

	local title = UiStyle.label(panel, "Title", 1, 18)
	title.Font = UiStyle.BoldFont
	title.TextColor3 = UiStyle.Colors.Accent
	title.Text = Strings.Spectate.Title
	local nameLabel = UiStyle.label(panel, "TargetName", 2, 32)
	nameLabel.Font = UiStyle.BoldFont
	local statusLabel = UiStyle.label(panel, "TargetStatus", 3, 22)
	statusLabel.TextColor3 = UiStyle.Colors.Subtext
	local infoLabel = UiStyle.label(panel, "MatchInfo", 4, 20)

	-- 아래: 대상 바꾸기, 로비로 돌아가기
	local bottom = UiStyle.container(gui, "Controls")
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -16)
	bottom.Size = UDim2.fromOffset(340, 0)
	bottom.AutomaticSize = Enum.AutomaticSize.Y
	UiStyle.list(bottom, Enum.FillDirection.Vertical, 8)

	local hintLabel = UiStyle.label(bottom, "KeyHint", 1, 18)
	hintLabel.TextColor3 = UiStyle.Colors.Subtext

	local row = UiStyle.container(bottom, "Cycle")
	row.LayoutOrder = 2
	row.Size = UDim2.new(1, 0, 0, 52)
	UiStyle.list(row, Enum.FillDirection.Horizontal, 12)
	local previousButton = UiStyle.button(row, "Previous", 1, UDim2.fromOffset(150, 52), true)
	previousButton.Text = `◀  {Strings.Spectate.Previous}`
	local nextButton = UiStyle.button(row, "Next", 2, UDim2.fromOffset(150, 52), true)
	nextButton.Text = `{Strings.Spectate.Next}  ▶`

	-- 자리만 (S3-2에서 연결). 눌러도 아무 일도 없어 흐리게 보인다.
	local lobbyButton = UiStyle.button(bottom, "ReturnToLobby", 3, UDim2.fromOffset(220, 40), false)
	lobbyButton.Text = Strings.Spectate.ReturnToLobby

	gui.Parent = UiStyle.playerGui()
	return {
		gui = gui,
		nameLabel = nameLabel,
		statusLabel = statusLabel,
		infoLabel = infoLabel,
		hintLabel = hintLabel,
		previousButton = previousButton,
		nextButton = nextButton,
	}
end

-- 화면 갱신 ------------------------------------------------------------------------------------------------------

local function joined(items: { string }): string
	local text = items[1] or ""
	for index = 2, #items do
		text = string.format(Strings.Spectate.Joined, text, items[index])
	end
	return text
end

local function renderTarget(): ()
	local ui = view
	if not ui then
		return
	end
	local player = target
	if not player then
		ui.nameLabel.Text = "-"
		ui.statusLabel.Text = Strings.Spectate.NoTarget
		return
	end
	ui.nameLabel.Text = player.DisplayName
	local items: { string } = {}
	local state = MatchState.getSurvivorState(player)
	if state then
		-- 생존자였던 사람은 잡히거나 탈출해도(역할 Spectator, 다음 대상으로 넘어가기 직전) 생존자로 보여준다.
		table.insert(items, Strings.Roles.Survivor)
		table.insert(items, Strings.SurvivorStates[state])
		if MatchState.isHidden(player) then
			table.insert(items, Strings.Spectate.Hidden)
		end
	else
		local role = MatchState.getRole(player)
		if role then
			table.insert(items, Strings.Roles[role])
		end
	end
	ui.statusLabel.Text = joined(items)
end

local function renderMatchInfo(): ()
	local ui = view
	if not ui then
		return
	end
	local items = { string.format(Strings.Hud.SurvivorsLeft, MatchState.getSurvivorsLeft()) }
	local done, total = MatchState.getGenerators()
	if MatchState.isExitOpen() then
		table.insert(items, Strings.Hud.ExitOpen)
	elseif total then
		table.insert(items, string.format(Strings.Hud.Objective, done, total))
	end
	local timeLeft = MatchState.getTimeLeft()
	if timeLeft then
		local seconds = math.max(0, math.floor(timeLeft))
		local phaseName = Strings.Phases[MatchState.getPhase()]
		table.insert(items, string.format(Strings.Hud.PhaseClock, phaseName, seconds // 60, seconds % 60))
	end
	ui.infoLabel.Text = joined(items)
end

local function renderHint(): ()
	local ui = view
	if not ui then
		return
	end
	local inputType = UserInputService:GetLastInputType()
	local hint: string? = nil
	if inputType.Name:match("^Gamepad") then
		hint = Strings.Spectate.GamepadHint
	elseif inputType ~= Enum.UserInputType.Touch then
		hint = Strings.Spectate.KeyHint
	end
	ui.hintLabel.Text = hint or ""
	ui.hintLabel.Visible = hint ~= nil
end

-- 카메라와 입력 --------------------------------------------------------------------------------------------------

local function followTarget(): ()
	local camera = Workspace.CurrentCamera
	local character = target and target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid and camera.CameraSubject ~= humanoid then
		camera.CameraSubject = humanoid
	end
end

local function requestCycle(step: number): ()
	if spectating and cycleRemote then
		cycleRemote:FireServer(step)
	end
end

local function onCycleAction(
	actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		requestCycle(if actionName == PREVIOUS_ACTION then -1 else 1)
	end
	return Enum.ContextActionResult.Sink
end

local function enterSpectate(): ()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
	-- 기본 카메라(←/→ 회전)보다 먼저 받도록 높은 우선순위로 묶는다.
	local priority = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority(
		PREVIOUS_ACTION,
		onCycleAction,
		false,
		priority,
		Enum.KeyCode.Q,
		Enum.KeyCode.Left,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindActionAtPriority(
		NEXT_ACTION,
		onCycleAction,
		false,
		priority,
		Enum.KeyCode.E,
		Enum.KeyCode.Right,
		Enum.KeyCode.ButtonR1
	)
	if not followConnection then
		followConnection = RunService.Heartbeat:Connect(followTarget)
	end
	followTarget()
	renderMatchInfo()
	renderHint()
	if view then
		view.gui.Enabled = true
	end
end

local function exitSpectate(): ()
	ContextActionService:UnbindAction(PREVIOUS_ACTION)
	ContextActionService:UnbindAction(NEXT_ACTION)
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
	if view then
		view.gui.Enabled = false
	end
	local camera = Workspace.CurrentCamera
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then
		camera.CameraSubject = humanoid
	end
end

local function setTargetPlayer(player: Player?): ()
	for _, connection in targetConnections do
		connection:Disconnect()
	end
	table.clear(targetConnections)
	target = player
	if player then
		for _, name in { Attribute.Role, Attribute.SurvivorState, Attribute.Hidden } do
			table.insert(targetConnections, player:GetAttributeChangedSignal(name):Connect(renderTarget))
		end
	end
	followTarget()
	renderTarget()
end

local function refresh(): ()
	local isSpectating = MatchState.isSpectating(localPlayer)
	local userId = if isSpectating then MatchState.getSpectateTargetUserId(localPlayer) else nil
	local player = if userId then Players:GetPlayerByUserId(userId) else nil
	if player ~= target then
		setTargetPlayer(player)
	end
	if isSpectating ~= spectating then
		spectating = isSpectating
		if isSpectating then
			enterSpectate()
		else
			exitSpectate()
		end
	end
end

-- 관전자 채팅 ----------------------------------------------------------------------------------------------------

-- parent 아래에 name이 생길 때까지 기다린다 (WaitForChild의 무한 대기 경고 없이).
local function waitForChild(parent: Instance, name: string): Instance
	while true do
		local child = parent:FindFirstChild(name)
		if child then
			return child
		end
		parent.ChildAdded:Wait()
	end
end

local function hasMySource(channel: TextChannel): boolean
	for _, child in channel:GetChildren() do
		if child:IsA("TextSource") and child.UserId == localPlayer.UserId then
			return true
		end
	end
	return false
end

local function setupChat(): ()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	local channels = waitForChild(TextChatService, "TextChannels")
	local channel = waitForChild(channels, SpectateState.ChatChannelName)
	if not channel:IsA("TextChannel") then
		return
	end
	local spectatorChannel: TextChannel = channel

	spectatorChannel.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties
		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText = `{Strings.Spectate.ChatPrefix} {message.PrefixText}`
		return properties
	end

	local inChannel = false
	local function refreshInputTarget(): ()
		local nowInChannel = hasMySource(spectatorChannel)
		if nowInChannel == inChannel then
			return
		end
		inChannel = nowInChannel
		local inputBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
		local general = channels:FindFirstChild(GENERAL_CHANNEL_NAME)
		if inputBar then
			if nowInChannel then
				inputBar.TargetTextChannel = spectatorChannel
			elseif general and general:IsA("TextChannel") then
				inputBar.TargetTextChannel = general
			end
		end
		if nowInChannel then
			spectatorChannel:DisplaySystemMessage(Strings.Spectate.ChatNotice)
		end
	end
	spectatorChannel.ChildAdded:Connect(refreshInputTarget)
	spectatorChannel.ChildRemoved:Connect(refreshInputTarget)
	refreshInputTarget()
end

-- -------------------------------------------------------------------------------------------------------------

function SpectateController.Init(): () end

function SpectateController.Start(): ()
	cycleRemote = Remotes.get("SpectateCycle")
	local ui = createGui()
	view = ui
	ui.previousButton.Activated:Connect(function()
		requestCycle(-1)
	end)
	ui.nextButton.Activated:Connect(function()
		requestCycle(1)
	end)

	localPlayer:GetAttributeChangedSignal(Attribute.Spectating):Connect(refresh)
	localPlayer:GetAttributeChangedSignal(Attribute.SpectateTarget):Connect(refresh)
	for _, name in
		{ Attribute.SurvivorsLeft, Attribute.TimeLeft, Attribute.Phase, Attribute.GeneratorsDone, Attribute.ExitOpen }
	do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(renderMatchInfo)
	end
	UserInputService.LastInputTypeChanged:Connect(renderHint)
	-- 관전 대상이 나보다 늦게 들어온 사람이면 Player 객체가 늦게 올 수 있다.
	Players.PlayerAdded:Connect(refresh)

	refresh()
	task.spawn(setupChat)
end

return SpectateController
