--!strict
-- InputController: 조작 입력을 한 곳에서 묶는다 (GDD 11장, 13.2, 질문지 Q10-2 모바일 + PC).
--
-- 키보드·마우스·게임패드: 다른 컨트롤러가 InputController.bind(동작, 처리 함수)로 동작을 맡기면
--   Config.Input.Bindings의 키를 ContextActionService에 묶는다. 처리 함수는 누름(true)·뗌(false)을 받는다.
--   달리기·아이템(SurvivorController), 공격·스킬(ChaserController), 관전 대상 바꾸기(SpectateController).
--   UI가 먼저 받은 입력(버튼 클릭 등)은 ContextActionService가 넘기지 않는다.
-- 휴대폰 화면 버튼 (ScreenGui "TouchControls", 터치 입력일 때만): 오른쪽 아래 점프 버튼 둘레에 4개 (GDD 11장).
--   달리기·아이템·스킬은 그 동작이 묶여 있을 때만 보인다 (생존자: 달리기·아이템, 추격자: 스킬).
--   아이템 버튼은 아이템이 있는 첫 칸을 쓴다 (특정 칸은 HUD 아이템 칸을 누른다).
--   상호작용은 지금 보이는 ProximityPrompt(숨기·수리·치료·줍기·판자·문·열어보기·혼자 하기)가 있을 때만 보이고,
--   가장 가까운 프롬프트를 InputHoldBegin/InputHoldEnd로 누른다 (길게 누르는 프롬프트는 버튼을 누르고 있으면 된다).
--   추격자 공격은 화면(UI가 아닌 곳)을 탭한다 (ChaserController).
--   버튼 크기는 실제 점 단위라 UIScale로 줄이지 않는다 (Config.Input.Touch, 지름 64 ≥ 터치 영역 최소 44).
-- 플랫폼: 마지막 입력 종류로 키보드·마우스 / 게임패드 / 터치를 정한다. 바뀌면 onPlatformChanged 구독자에게 알린다.
--   hint(동작)는 지금 플랫폼의 키 이름이다 (HUD 키 안내). 터치는 화면 버튼이 있으니 nil (공격만 "화면 탭").
--   Studio에서는 LocalPlayer Attribute ForceInputPlatform("Touch"·"Gamepad"·"KeyboardMouse")으로 바꿔 화면을 시험한다.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Input = require(ReplicatedStorage.Shared.Config.Input)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)

export type Handler = (pressed: boolean) -> ()

type TouchButton = {
	button: TextButton,
	label: TextLabel,
}

local ACTION_PREFIX = "Input" -- ContextActionService 동작 이름 앞에 붙인다
local FORCE_PLATFORM_ATTRIBUTE = "ForceInputPlatform" -- Studio 시험용
local TOUCH_REFRESH_INTERVAL = 0.2 -- 상호작용 버튼 이름(가까운 프롬프트)을 다시 맞추는 간격 (초)
local TOUCH_BUTTON_ORDER: { Types.TouchButtonId } = { "Run", "Skill", "Item", "Interact" }

-- 화면 버튼이 부르는 동작. 상호작용은 동작이 아니라 프롬프트를 누른다.
local TOUCH_ACTIONS: { [Types.TouchButtonId]: Types.InputAction } = {
	Run = "Run",
	Item = "Item",
	Skill = "Skill",
}

local DEFAULT_LABELS: { [Types.TouchButtonId]: string } = {
	Run = Strings.Hud.Run,
	Item = Strings.Hud.Item,
	Skill = Strings.Hud.Skill,
	Interact = Strings.Hud.Interact,
}

local localPlayer = Players.LocalPlayer

local InputController = {}

local handlers: { [Types.InputAction]: Handler } = {}
local actionByName: { [string]: Types.InputAction } = {}
local platform: Types.InputPlatform = "KeyboardMouse"
local platformListeners: { () -> () } = {}

local touchGui: ScreenGui? = nil
local touchButtons: { [Types.TouchButtonId]: TouchButton } = {}
local touchLabels: { [Types.TouchButtonId]: string } = {}
local touchDimmed: { [Types.TouchButtonId]: boolean } = {}
local heldInputs: { [InputObject]: Types.TouchButtonId } = {}
local heldPrompt: ProximityPrompt? = nil
local shownPrompts: { [ProximityPrompt]: boolean } = {}

--------------------------------------------------------------------------------
-- 플랫폼

local function platformOf(inputType: Enum.UserInputType): Types.InputPlatform?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.sub(inputType.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Keyboard or string.sub(inputType.Name, 1, 5) == "Mouse" then
		return "KeyboardMouse"
	end
	return nil
end

local function detectPlatform(): Types.InputPlatform
	if RunService:IsStudio() then
		local forced = localPlayer:GetAttribute(FORCE_PLATFORM_ATTRIBUTE)
		if forced == "KeyboardMouse" or forced == "Gamepad" or forced == "Touch" then
			return forced
		end
	end
	local fromLast = platformOf(UserInputService:GetLastInputType())
	if fromLast then
		return fromLast
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

local function isGamepadInput(name: string): boolean
	return string.sub(name, 1, 6) == "Button" or string.sub(name, 1, 4) == "DPad"
end

local function keyName(name: string): string
	if name == "MouseButton1" then
		return Strings.Input.MouseButton1
	end
	return Input.KeyNames[name] or name
end

--------------------------------------------------------------------------------
-- 휴대폰 화면 버튼

local function promptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

-- 지금 보이는 프롬프트 중 내 캐릭터에서 가장 가까운 것
local function closestPrompt(): ProximityPrompt?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local best: ProximityPrompt? = nil
	local bestDistance = math.huge
	for prompt in shownPrompts do
		if not prompt.Parent or not prompt.Enabled then
			shownPrompts[prompt] = nil
		else
			local position = promptPosition(prompt)
			local distance = if root
					and root:IsA("BasePart")
					and position
				then (position - root.Position).Magnitude
				else 0
			if distance < bestDistance then
				best = prompt
				bestDistance = distance
			end
		end
	end
	return best
end

local function refreshTouch(): ()
	local gui = touchGui
	if not gui then
		return
	end
	gui.Enabled = platform == "Touch"
	if platform ~= "Touch" then
		return
	end
	for id, entry in touchButtons do
		local visible: boolean
		local text: string
		if id == "Interact" then
			local prompt = heldPrompt or closestPrompt()
			visible = prompt ~= nil
			text = if prompt and prompt.ActionText ~= "" then prompt.ActionText else DEFAULT_LABELS.Interact
		else
			local action: Types.InputAction? = TOUCH_ACTIONS[id]
			visible = action ~= nil and handlers[action] ~= nil
			text = touchLabels[id] or DEFAULT_LABELS[id]
		end
		entry.button.Visible = visible
		entry.label.Text = text
		entry.button.BackgroundTransparency = if touchDimmed[id]
			then Input.Touch.DimmedTransparency
			else UiStyle.PanelTransparency
	end
end

local function press(id: Types.TouchButtonId, inputObject: InputObject): ()
	if heldInputs[inputObject] then
		return
	end
	heldInputs[inputObject] = id
	touchButtons[id].button.BackgroundColor3 = UiStyle.Colors.Accent
	if id == "Interact" then
		local prompt = closestPrompt()
		if prompt then
			heldPrompt = prompt
			prompt:InputHoldBegin()
		end
	else
		local action: Types.InputAction? = TOUCH_ACTIONS[id]
		local handler = if action then handlers[action] else nil
		if handler then
			handler(true)
		end
	end
end

local function release(inputObject: InputObject): ()
	local id = heldInputs[inputObject]
	if not id then
		return
	end
	heldInputs[inputObject] = nil
	touchButtons[id].button.BackgroundColor3 = UiStyle.Colors.Panel
	if id == "Interact" then
		local prompt = heldPrompt
		heldPrompt = nil
		if prompt then
			prompt:InputHoldEnd()
		end
	else
		local action: Types.InputAction? = TOUCH_ACTIONS[id]
		local handler = if action then handlers[action] else nil
		if handler then
			handler(false)
		end
	end
	refreshTouch()
end

local function layoutTouch(): ()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local config = Input.Touch
	local large = math.min(viewport.X, viewport.Y) > config.LargeScreenMinSide
	local scale = if large then config.LargeScreenScale else 1
	local jump = if large then config.JumpCenterLarge else config.JumpCenterSmall
	local size = math.floor(config.ButtonSize * scale)
	for id, entry in touchButtons do
		-- 점프 버튼 가운데(오른쪽 아래 모서리에서 jump만큼 안쪽)에서 Offsets만큼
		local fromCorner = jump - config.Offsets[id] * scale
		entry.button.Position = UDim2.new(1, -math.floor(fromCorner.X), 1, -math.floor(fromCorner.Y))
		entry.button.Size = UDim2.fromOffset(size, size)
		entry.label.TextSize = math.floor(config.LabelSize * scale)
	end
end

local function createTouchButton(gui: ScreenGui, id: Types.TouchButtonId): TouchButton
	local button = Instance.new("TextButton")
	button.Name = id
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = UiStyle.Colors.Panel
	button.BackgroundTransparency = UiStyle.PanelTransparency
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = UiStyle.stroke(button, UiStyle.Colors.Accent, 0.2)
	stroke.Thickness = 2

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.86, 0.86)
	label.BackgroundTransparency = 1
	label.Font = UiStyle.BoldFont
	label.TextColor3 = UiStyle.Colors.Text
	label.TextWrapped = true
	label.Text = DEFAULT_LABELS[id]
	label.Parent = button

	button.InputBegan:Connect(function(inputObject: InputObject)
		local inputType = inputObject.UserInputType
		if inputType == Enum.UserInputType.Touch or inputType == Enum.UserInputType.MouseButton1 then
			press(id, inputObject)
		end
	end)
	button.Parent = gui
	return { button = button, label = label }
end

local function createTouchGui(): ScreenGui
	local gui = UiStyle.screenGui("TouchControls", 4)
	gui.Enabled = false
	for _, id in TOUCH_BUTTON_ORDER do
		touchButtons[id] = createTouchButton(gui, id)
	end
	gui.Parent = UiStyle.playerGui()
	return gui
end

--------------------------------------------------------------------------------
-- 동작 묶기

local function onAction(
	actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	local action = actionByName[actionName]
	local handler = if action then handlers[action] else nil
	if not handler then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		handler(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		handler(false)
	end
	return Enum.ContextActionResult.Sink
end

-- action을 handler에 맡긴다 (Config.Input.Bindings의 키와 휴대폰 화면 버튼). 이미 묶여 있으면 바꾼다.
-- highPriority면 Roblox 기본 조작(←/→ 카메라 회전 등)보다 먼저 받는다.
function InputController.bind(action: Types.InputAction, handler: Handler, highPriority: boolean?): ()
	InputController.unbind(action)
	handlers[action] = handler
	local inputs = Input.Bindings[action]
	if #inputs > 0 then
		local name = ACTION_PREFIX .. action
		actionByName[name] = action
		if highPriority then
			ContextActionService:BindActionAtPriority(
				name,
				onAction,
				false,
				Enum.ContextActionPriority.High.Value,
				table.unpack(inputs)
			)
		else
			ContextActionService:BindAction(name, onAction, false, table.unpack(inputs))
		end
	end
	refreshTouch()
end

function InputController.unbind(action: Types.InputAction): ()
	local handler = handlers[action]
	if not handler then
		return
	end
	handlers[action] = nil
	ContextActionService:UnbindAction(ACTION_PREFIX .. action)
	-- 화면 버튼을 누르고 있던 중이면 뗀 것으로 한다.
	for inputObject, id in heldInputs do
		if TOUCH_ACTIONS[id] == action then
			heldInputs[inputObject] = nil
			touchButtons[id].button.BackgroundColor3 = UiStyle.Colors.Panel
			handler(false)
		end
	end
	refreshTouch()
end

function InputController.isBound(action: Types.InputAction): boolean
	return handlers[action] ~= nil
end

function InputController.getPlatform(): Types.InputPlatform
	return platform
end

-- 플랫폼(키보드·마우스 / 게임패드 / 터치)이 바뀌면 callback을 부른다.
function InputController.onPlatformChanged(callback: () -> ()): ()
	table.insert(platformListeners, callback)
end

-- 지금 플랫폼에서 action을 하는 키 이름 (HUD 키 안내). 터치는 화면 버튼이 있으니 nil (공격만 "화면 탭").
function InputController.hint(action: Types.InputAction): string?
	if platform == "Touch" then
		return if action == "Attack" then Strings.Input.Tap else nil
	end
	local wantGamepad = platform == "Gamepad"
	for _, input in Input.Bindings[action] do
		if isGamepadInput(input.Name) == wantGamepad then
			return keyName(input.Name)
		end
	end
	return nil
end

-- 화면 버튼 글자 (nil이면 기본 이름). 아이템 이름, 스킬 이름·남은 쿨다운 등.
function InputController.setTouchLabel(id: Types.TouchButtonId, text: string?): ()
	if touchLabels[id] == text then
		return
	end
	touchLabels[id] = text
	refreshTouch()
end

-- 지금 쓸 수 없으면(쿨다운·스태미나 부족·아이템 없음) 화면 버튼을 흐리게 한다.
function InputController.setTouchDimmed(id: Types.TouchButtonId, dimmed: boolean): ()
	if (touchDimmed[id] == true) == dimmed then
		return
	end
	touchDimmed[id] = dimmed
	refreshTouch()
end

local function updatePlatform(): ()
	local detected = detectPlatform()
	if detected == platform then
		return
	end
	platform = detected
	refreshTouch()
	for _, listener in platformListeners do
		task.spawn(listener)
	end
end

function InputController.Init(): ()
	platform = detectPlatform()
end

function InputController.Start(): ()
	touchGui = createTouchGui()

	local function watchCamera(): ()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutTouch)
		end
		layoutTouch()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()

	UserInputService.LastInputTypeChanged:Connect(updatePlatform)
	if RunService:IsStudio() then
		localPlayer:GetAttributeChangedSignal(FORCE_PLATFORM_ATTRIBUTE):Connect(updatePlatform)
	end
	UserInputService.InputEnded:Connect(release)

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		shownPrompts[prompt] = true
		refreshTouch()
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		shownPrompts[prompt] = nil
		if heldPrompt == prompt then
			heldPrompt = nil
			prompt:InputHoldEnd()
		end
		refreshTouch()
	end)
	-- 가까운 프롬프트가 바뀌거나(걸어가며) 문 열기·닫기처럼 이름이 바뀌면 상호작용 버튼 글자를 맞춘다.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= TOUCH_REFRESH_INTERVAL and platform == "Touch" and next(shownPrompts) ~= nil then
			elapsed = 0
			refreshTouch()
		end
	end)
	refreshTouch()
end

return InputController
