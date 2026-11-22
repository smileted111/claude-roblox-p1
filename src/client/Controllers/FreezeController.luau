--!strict
-- FreezeController: 얼음땡 모드의 "얼음"·"땡" 버튼 (2026-11-22 사용자 요청, Config.GameModes.FreezeTag). GDD 13.2 목록 밖에 추가.
--
-- 얼음땡 모드(ReplicatedStorage GameMode)의 추격 단계에 생존자에게 화면 오른쪽 아래 버튼 두 개를 띄운다 (모든 플랫폼).
--   휴대폰은 InputController의 화면 버튼(점프 둘레) 위에 놓아 겹치지 않게 한다. 버튼은 실제 점 단위(높이 56, UIScale 없음).
--   키: Config.Input.Bindings의 Freeze(F·Y)·Thaw(G·B)를 InputController.bind로 묶는다. 버튼에 키 안내를 붙인다 (터치 제외).
-- 얼음: 내가 숨지 않은 정상·부상이고 다시 얼 수 있을 때(Player Attribute FreezeReadyAt) 누를 수 있다. 얼어 있으면 "얼음 중",
--   쿨다운이면 "얼음 n"으로 흐리게. 땡: 언 동료가 Config.GameModes.FreezeTag.ThawDistance 안에 있을 때만 밝게 (나 자신은 풀 수 없음).
-- 판정은 서버(FreezeService). 여기서는 요청(Freeze·Thaw 리모트)과 버튼 표시만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameModes = require(ReplicatedStorage.Shared.Config.GameModes)
local Input = require(ReplicatedStorage.Shared.Config.Input)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)
local InputController = require(script.Parent.InputController)

local BUTTON_WIDTH = 108
local BUTTON_HEIGHT = UiStyle.MinButtonHeight
local GAP = 8
local EDGE_MARGIN = 16 -- 화면 가장자리에서 (점)
local TOUCH_MARGIN = 12 -- 휴대폰 화면 버튼 위로 띄우는 간격 (점)
local REFRESH_INTERVAL = 0.1 -- 땡 가능 여부·쿨다운 글자를 다시 맞추는 간격 (초)
local ICE_COLOR = GameModes.FreezeTag.IceColor

type View = {
	gui: ScreenGui,
	frame: Frame,
	freeze: TextButton,
	thaw: TextButton,
}

local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local FreezeController = {}

local view: View? = nil
local bound = false
local freezeRemote: RemoteEvent? = nil
local thawRemote: RemoteEvent? = nil

local function isActive(): boolean
	return MatchState.getGameMode() == "FreezeTag"
		and MatchState.getPhase() == "Chase"
		and MatchState.getRole(localPlayer) == "Survivor"
end

-- 숨지 않은 정상·부상 (얼거나 땡 할 수 있는 상태)
local function canAct(): boolean
	local state = MatchState.getSurvivorState(localPlayer)
	return (state == "Normal" or state == "Injured") and not MatchState.isHidden(localPlayer)
end

local function freezeCooldown(): number
	local readyAt = MatchState.getFreezeReadyAt(localPlayer)
	return if readyAt then math.max(0, readyAt - Workspace:GetServerTimeNow()) else 0
end

-- 땡이 닿는 언 동료가 있는가 (서버가 다시 검사한다)
local function hasFrozenNearby(): boolean
	local mine = CharacterParts.get(localPlayer)
	if not mine then
		return false
	end
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer and MatchState.getSurvivorState(player) == "Frozen" then
			local parts = CharacterParts.get(player)
			if
				parts
				and (parts.rootPart.Position - mine.rootPart.Position).Magnitude <= GameModes.FreezeTag.ThawDistance
			then
				return true
			end
		end
	end
	return false
end

local function requestFreeze(): ()
	if isActive() and canAct() and freezeCooldown() <= 0 and freezeRemote then
		freezeRemote:FireServer()
	end
end

local function requestThaw(): ()
	if isActive() and canAct() and thawRemote then
		thawRemote:FireServer()
	end
end

-- 휴대폰 화면 버튼 묶음(점프 버튼 둘레)의 위쪽 끝 (화면 아래에서, 점). Config.Input.Touch와 같은 계산
local function touchClusterTop(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(800, 600)
	local config = Input.Touch
	local large = math.min(viewport.X, viewport.Y) > config.LargeScreenMinSide
	local jump = if large then config.JumpCenterLarge else config.JumpCenterSmall
	local scale = if large then config.LargeScreenScale else 1
	local top = jump.Y
	for _, offset in config.Offsets do
		top = math.max(top, jump.Y - offset.Y * scale)
	end
	return top + config.ButtonSize * scale / 2
end

local function place(ui: View): ()
	local bottom = if InputController.getPlatform() == "Touch" then touchClusterTop() + TOUCH_MARGIN else EDGE_MARGIN
	ui.frame.Position = UDim2.new(1, -EDGE_MARGIN, 1, -bottom)
end

local function makeButton(parent: Instance, name: string, order: number): TextButton
	local button = UiStyle.button(parent, name, order, UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT), true)
	button.RichText = true
	button.TextSize = 22
	return button
end

local function createView(): View
	local gui = UiStyle.screenGui("FreezeTag", 6)
	local frame = UiStyle.container(gui, "Buttons")
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Size = UDim2.fromOffset(BUTTON_WIDTH * 2 + GAP, BUTTON_HEIGHT)
	frame.Visible = false
	local layout = UiStyle.list(frame, Enum.FillDirection.Horizontal, GAP)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local freeze = makeButton(frame, "Freeze", 1)
	local thaw = makeButton(frame, "Thaw", 2)
	freeze.Activated:Connect(requestFreeze)
	thaw.Activated:Connect(requestThaw)
	gui.Parent = UiStyle.playerGui()
	return { gui = gui, frame = frame, freeze = freeze, thaw = thaw }
end

local function setButton(button: TextButton, text: string, action: Types.InputAction, enabled: boolean): ()
	local key = InputController.hint(action)
	button.Text = if key then `{text} <font size="13">[{key}]</font>` else text
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.TextColor3 = if enabled then UiStyle.Colors.Text else UiStyle.Colors.Disabled
	button.BackgroundTransparency = if enabled then UiStyle.PanelTransparency else Input.Touch.DimmedTransparency
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if enabled then ICE_COLOR else UiStyle.Colors.Disabled
	end
end

local function updateBinding(active: boolean): ()
	if active == bound then
		return
	end
	bound = active
	if active then
		InputController.bind("Freeze", function(pressed: boolean)
			if pressed then
				requestFreeze()
			end
		end)
		InputController.bind("Thaw", function(pressed: boolean)
			if pressed then
				requestThaw()
			end
		end)
	else
		InputController.unbind("Freeze")
		InputController.unbind("Thaw")
	end
end

local function render(): ()
	local ui = view
	if not ui then
		return
	end
	local active = isActive()
	updateBinding(active)
	ui.frame.Visible = active
	if not active then
		return
	end
	place(ui)
	local frozen = MatchState.getSurvivorState(localPlayer) == "Frozen"
	local cooldown = freezeCooldown()
	if frozen then
		setButton(ui.freeze, Strings.Hud.Frozen, "Freeze", false)
	elseif cooldown > 0 then
		setButton(ui.freeze, string.format(Strings.Hud.FreezeCooldown, math.ceil(cooldown)), "Freeze", false)
	else
		setButton(ui.freeze, Strings.Hud.Freeze, "Freeze", canAct())
	end
	setButton(ui.thaw, Strings.Hud.Thaw, "Thaw", canAct() and hasFrozenNearby())
end

function FreezeController.Init(): () end

function FreezeController.Start(): ()
	freezeRemote = Remotes.get("Freeze")
	thawRemote = Remotes.get("Thaw")
	view = createView()
	for _, name in { Attribute.Phase, Attribute.GameMode } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(render)
	end
	for _, name in { Attribute.Role, Attribute.SurvivorState, Attribute.Hidden, Attribute.FreezeReadyAt } do
		localPlayer:GetAttributeChangedSignal(name):Connect(render)
	end
	InputController.onPlatformChanged(render)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			if isActive() then
				render()
			end
		end
	end)
	render()
end

return FreezeController
