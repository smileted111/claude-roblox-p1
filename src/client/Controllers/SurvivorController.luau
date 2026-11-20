--!strict
-- SurvivorController: 생존자 조작 — 달리기·숨기·아군 치료와 피격 효과 (GDD 2.2, 4.1, 6.1, 13.2). 아이템은 S2-4에서.
--
-- 달리기: 누르고 있는 동안 달리기 의사를 서버에 보낸다 (SetRunning). 속도와 스태미나는 서버(MovementService)가 정한다.
--   PC Shift, 게임패드 L3, 모바일은 ContextActionService가 만드는 화면 버튼 (임시. S3-5에서 정식 버튼으로).
--   Shift가 Roblox 기본 시프트 락과 겹쳐서 default.project.json에서 StarterPlayer.EnableMouseLockOption을 껐다.
-- 스태미나 바 (임시): Player Attribute Stamina를 화면 아래에 보여준다. S1-8 HUD에서 UIController로 옮긴다.
-- 숨기: 숨는 곳의 "숨기"·"나오기" 프롬프트 중 내 상태에 맞는 것만 켠다. 판정은 서버(HideService).
-- 치료: 부상당한 다른 생존자의 "치료" 프롬프트를 내가 치료할 수 있을 때만 켠다 (CatchState). 판정은 서버(CatchService).
-- 내 생존자 상태가 바뀌면 효과를 낸다 (GDD 8장, 12장). 피 표현 없이 화면 효과와 효과음(자리만)으로.
--   정상 → 부상: 화면이 잠깐 번쩍임 (Config.Catch.HitFlash)
--   잡힘: 화면 암전 Config.Match.CaughtEffectTime초 (Config.Catch.CaughtEffect). 관전 화면은 S1-7

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local CatchState = require(ReplicatedStorage.Shared.CatchState)
local HideSpotState = require(ReplicatedStorage.Shared.HideSpotState)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survivor = require(ReplicatedStorage.Shared.Config.Survivor)
local Types = require(ReplicatedStorage.Shared.Types)
local HideSpotWatcher = require(script.Parent.Parent.Util.HideSpotWatcher)
local ScreenEffect = require(script.Parent.Parent.Util.ScreenEffect)
local SoundController = require(script.Parent.SoundController)

local RUN_ACTION = "SurvivorRun"
local STAMINA_COLOR = Color3.fromRGB(110, 200, 255)
local STAMINA_LOW_COLOR = Color3.fromRGB(255, 170, 60) -- MinToStartRun 미만: 새로 달리기 시작할 수 없음

type StaminaBar = {
	gui: ScreenGui,
	fill: Frame,
}

local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local SurvivorController = {}

local runRemote: RemoteEvent? = nil
local runBound = false
local wantsToRun = false
local staminaBar: StaminaBar? = nil
local lastSurvivorState: Types.SurvivorState? = nil

local function isSurvivor(): boolean
	return MatchState.getRole(localPlayer) == "Survivor"
end

local function setWantsToRun(value: boolean): ()
	if wantsToRun == value then
		return
	end
	wantsToRun = value
	if runRemote then
		runRemote:FireServer(value)
	end
end

local function onRunAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		setWantsToRun(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setWantsToRun(false)
	end
	return Enum.ContextActionResult.Sink
end

-- 생존자일 때만 달리기 입력(과 모바일 화면 버튼)을 묶는다.
local function updateRunBinding(): ()
	local shouldBind = isSurvivor()
	if shouldBind == runBound then
		return
	end
	runBound = shouldBind
	if shouldBind then
		ContextActionService:BindAction(
			RUN_ACTION,
			onRunAction,
			true,
			Enum.KeyCode.LeftShift,
			Enum.KeyCode.RightShift,
			Enum.KeyCode.ButtonL3
		)
		ContextActionService:SetTitle(RUN_ACTION, Strings.Hud.Run)
	else
		ContextActionService:UnbindAction(RUN_ACTION)
		setWantsToRun(false)
	end
end

local function createStaminaBar(): StaminaBar
	local gui = Instance.new("ScreenGui")
	gui.Name = "StaminaBar"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -28)
	back.Size = UDim2.fromOffset(240, 12)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner").Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = STAMINA_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner").Parent = fill

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -2)
	label.Size = UDim2.new(1, 0, 0, 16)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(230, 230, 235)
	label.Text = Strings.Hud.Stamina
	label.Parent = back

	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	return { gui = gui, fill = fill }
end

local function updateStaminaBar(): ()
	local bar = staminaBar
	if not bar then
		return
	end
	bar.gui.Enabled = isSurvivor()
	local config = Survivor.Stamina
	local stamina = MatchState.getStamina(localPlayer) or config.Max
	bar.fill.Size = UDim2.fromScale(math.clamp(stamina / config.Max, 0, 1), 1)
	bar.fill.BackgroundColor3 = if stamina < config.MinToStartRun then STAMINA_LOW_COLOR else STAMINA_COLOR
end

-- 숨기: 생존자이고, 숨어 있지 않고, 숨을 수 있는 단계이고, 비어 있는 곳. 나오기: 내가 숨은 곳.
local function refreshHidePrompts(): ()
	local survivor = isSurvivor()
	local canHide = survivor
		and not MatchState.isHidden(localPlayer)
		and HideSpotState.canHideInPhase(MatchState.getPhase())
	for _, spot in HideSpotWatcher.getSpots() do
		local occupantUserId = HideSpotState.getOccupantUserId(spot)
		local hidePrompt = HideSpotWatcher.findPrompt(spot, HideSpotState.Prompt.Hide)
		if hidePrompt then
			hidePrompt.Enabled = canHide and occupantUserId == nil
		end
		local unhidePrompt = HideSpotWatcher.findPrompt(spot, HideSpotState.Prompt.Unhide)
		if unhidePrompt then
			unhidePrompt.Enabled = survivor and occupantUserId == localPlayer.UserId
		end
	end
end

-- 치료: 내가 숨지 않은 생존자이고 치료할 수 있는 단계일 때, 내 캐릭터가 아닌 사람의 프롬프트만 켠다.
-- 대상이 숨거나 부상이 아니게 되면 서버가 프롬프트를 지운다.
local function refreshHealPrompts(): ()
	local character = localPlayer.Character
	local canHeal = isSurvivor()
		and not MatchState.isHidden(localPlayer)
		and CatchState.canHealInPhase(MatchState.getPhase())
	for _, instance in CollectionService:GetTagged(CatchState.HealPromptTag) do
		if instance:IsA("ProximityPrompt") then
			local isMine = character ~= nil and instance:IsDescendantOf(character)
			instance.Enabled = canHeal and not isMine
		end
	end
end

local function onSurvivorStateChanged(): ()
	local state = MatchState.getSurvivorState(localPlayer)
	local previous = lastSurvivorState
	lastSurvivorState = state
	if state == "Caught" and previous ~= "Caught" then
		local effect = Catch.CaughtEffect
		ScreenEffect.blackout(effect.FadeInTime, Match.CaughtEffectTime, effect.FadeOutTime)
		SoundController.play("SurvivorCaught")
	elseif state == "Injured" and previous == "Normal" then
		local flash = Catch.HitFlash
		ScreenEffect.flash(flash.Color, flash.StartTransparency, flash.Duration)
		SoundController.play("SurvivorHit")
	elseif state == "Normal" and previous == "Injured" then
		SoundController.play("SurvivorHealed")
	end
end

function SurvivorController.Init(): () end

function SurvivorController.Start(): ()
	runRemote = Remotes.get("SetRunning")
	staminaBar = createStaminaBar()
	lastSurvivorState = MatchState.getSurvivorState(localPlayer)

	local function refreshPrompts(): ()
		refreshHidePrompts()
		refreshHealPrompts()
	end

	localPlayer:GetAttributeChangedSignal(Attribute.Role):Connect(function()
		updateRunBinding()
		updateStaminaBar()
		refreshPrompts()
	end)
	localPlayer:GetAttributeChangedSignal(Attribute.Stamina):Connect(updateStaminaBar)
	localPlayer:GetAttributeChangedSignal(Attribute.Hidden):Connect(refreshPrompts)
	localPlayer:GetAttributeChangedSignal(Attribute.SurvivorState):Connect(onSurvivorStateChanged)
	localPlayer.CharacterAdded:Connect(refreshHealPrompts)
	ReplicatedStorage:GetAttributeChangedSignal(Attribute.Phase):Connect(refreshPrompts)
	HideSpotWatcher.subscribe(refreshHidePrompts)
	CollectionService:GetInstanceAddedSignal(CatchState.HealPromptTag):Connect(refreshHealPrompts)

	updateRunBinding()
	updateStaminaBar()
	refreshHealPrompts()
end

return SurvivorController
