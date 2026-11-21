--!strict
-- 로딩 화면 (2026-11-21 사용자 요청): 게임에 처음 들어올 때(같은 폴더의 init.client), 로비 ↔ 스테이지를 오갈 때와
-- 혼자 하기 서버로 이동할 때(client/Controllers/LoadingController) 띄우는 애니메이션 화면.
-- ReplicatedFirst에 있어 공용 모듈(ReplicatedStorage.Shared)이 오기 전에도 쓸 수 있도록 다른 모듈을 require하지 않는다.
--   그래서 화면 모양 값은 Config 대신 이 파일 위쪽 상수로 둔다. 글자는 부르는 쪽이 Localization의 Loading으로 채운다.
-- 화면: 따뜻한 어두운 나무색 그라데이션 배경, 가운데 게임 이름, 차례로 밝아지며 도는 점 8개, 상태 글자와 움직이는 점(...),
--   좌우로 흐르는 빛 막대, 아래 팁(TIP_INTERVAL초마다 바뀜). 나타나고 사라질 때 CanvasGroup 투명도를 트윈한다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FADE_TIME = 0.35 -- 나타나고 사라지는 시간 (초)
local DOT_COUNT = 8
local DOT_RADIUS = 34 -- 도는 점의 원 반지름 (픽셀)
local SPIN_SPEED = 1.2 -- 초당 바퀴
local TIP_INTERVAL = 4 -- 팁이 바뀌는 간격 (초)
local BAR_PERIOD = 1.6 -- 빛 막대가 한 번 왕복하는 시간 (초)
local REFERENCE_SIZE = Vector2.new(1100, 620) -- 이 화면 크기에서 배율 1 (Config.Ui.ReferenceSize와 같은 값)

local WOOD_TOP = Color3.fromRGB(58, 36, 24)
local WOOD_BOTTOM = Color3.fromRGB(18, 11, 8)
local GLOW = Color3.fromRGB(255, 205, 130)
local CREAM = Color3.fromRGB(245, 230, 205)

type View = {
	gui: ScreenGui,
	canvas: CanvasGroup,
	scale: UIScale,
	title: TextLabel,
	status: TextLabel,
	tip: TextLabel,
	dots: { Frame },
	shine: Frame,
}

local LoadingScreen = {}

local view: View? = nil
local visible = false
local statusText = ""
local tips: { string } = {}
local shownAt = 0
local hideToken = 0
local renderConnection: RBXScriptConnection? = nil
local fadeTween: Tween? = nil

local function label(parent: Instance, name: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextSize = size
	text.TextColor3 = color
	text.Text = ""
	text.Parent = parent
	return text
end

local function corner(parent: GuiObject, radius: UDim): ()
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function create(): View
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000 -- 모든 화면 위
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundColor3 = Color3.new(1, 1, 1)
	canvas.BorderSizePixel = 0
	canvas.GroupTransparency = 1
	canvas.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(WOOD_TOP, WOOD_BOTTOM)
	gradient.Rotation = 90
	gradient.Parent = canvas

	local center = Instance.new("Frame")
	center.Name = "Center"
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.46)
	center.Size = UDim2.fromOffset(640, 300)
	center.BackgroundTransparency = 1
	center.Parent = canvas
	local scale = Instance.new("UIScale")
	scale.Parent = center

	local title = label(center, "Title", Enum.Font.FredokaOne, 54, GLOW)
	title.Size = UDim2.new(1, 0, 0, 64)
	title.TextStrokeColor3 = Color3.fromRGB(90, 40, 20)
	title.TextStrokeTransparency = 0.4

	local spinner = Instance.new("Frame")
	spinner.Name = "Spinner"
	spinner.AnchorPoint = Vector2.new(0.5, 0)
	spinner.Position = UDim2.new(0.5, 0, 0, 92)
	spinner.Size = UDim2.fromOffset(DOT_RADIUS * 2 + 20, DOT_RADIUS * 2 + 20)
	spinner.BackgroundTransparency = 1
	spinner.Parent = center
	local dots: { Frame } = {}
	for i = 1, DOT_COUNT do
		local angle = (i - 1) / DOT_COUNT * math.pi * 2 - math.pi / 2
		local dot = Instance.new("Frame")
		dot.Name = `Dot{i}`
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0.5, math.cos(angle) * DOT_RADIUS, 0.5, math.sin(angle) * DOT_RADIUS)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.BackgroundColor3 = GLOW
		dot.BorderSizePixel = 0
		corner(dot, UDim.new(1, 0))
		dot.Parent = spinner
		table.insert(dots, dot)
	end

	local status = label(center, "Status", Enum.Font.GothamMedium, 22, CREAM)
	status.Position = UDim2.fromOffset(0, 196)
	status.Size = UDim2.new(1, 0, 0, 30)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 240)
	track.Size = UDim2.fromOffset(260, 6)
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BackgroundTransparency = 0.85
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	corner(track, UDim.new(1, 0))
	track.Parent = center
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.AnchorPoint = Vector2.new(0.5, 0)
	shine.Size = UDim2.fromScale(0.3, 1)
	shine.BackgroundColor3 = GLOW
	shine.BorderSizePixel = 0
	corner(shine, UDim.new(1, 0))
	shine.Parent = track

	local tip = label(canvas, "Tip", Enum.Font.GothamMedium, 18, Color3.fromRGB(215, 195, 165))
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Position = UDim2.new(0.5, 0, 1, -36)
	tip.Size = UDim2.new(0.9, 0, 0, 48)
	tip.TextWrapped = true

	return {
		gui = gui,
		canvas = canvas,
		scale = scale,
		title = title,
		status = status,
		tip = tip,
		dots = dots,
		shine = shine,
	}
end

local function getView(): View
	local existing = view
	if existing then
		return existing
	end
	local created = create()
	created.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	view = created
	return created
end

-- 매 프레임: 점이 차례로 밝아지며 돌고, 상태 글자 뒤 점이 늘고, 빛 막대가 흐르고, 팁이 바뀐다.
local function animate(): ()
	local ui = view
	if not ui then
		return
	end
	local now = os.clock()
	for i, dot in ui.dots do
		local phase = (now * SPIN_SPEED - (i - 1) / DOT_COUNT) % 1
		local strength = (1 - phase) ^ 2
		dot.BackgroundTransparency = 0.8 - 0.8 * strength
		local size = 8 + 8 * strength
		dot.Size = UDim2.fromOffset(size, size)
	end
	ui.status.Text = statusText .. string.rep(".", math.floor(now * 2.5) % 4)
	local wave = (math.sin(now / BAR_PERIOD * math.pi * 2) + 1) / 2
	ui.shine.Position = UDim2.fromScale(0.15 + wave * 0.7, 0)
	if #tips > 0 then
		ui.tip.Text = tips[math.floor(now / TIP_INTERVAL) % #tips + 1]
	end
	local camera = Workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		ui.scale.Scale = math.clamp(math.min(viewport.X / REFERENCE_SIZE.X, viewport.Y / REFERENCE_SIZE.Y), 0.6, 1)
	end
end

local function fadeTo(transparency: number, onDone: (() -> ())?): ()
	local ui = getView()
	if fadeTween then
		fadeTween:Cancel()
	end
	local tween = TweenService:Create(
		ui.canvas,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = transparency }
	)
	fadeTween = tween
	if onDone then
		tween.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed then
				onDone()
			end
		end)
	end
	tween:Play()
end

-- 게임 이름과 팁 목록을 정한다 (Localization이 오면 부름).
function LoadingScreen.setTexts(title: string, tipList: { string }): ()
	local ui = getView()
	ui.title.Text = title
	tips = table.clone(tipList)
end

function LoadingScreen.setStatus(status: string): ()
	statusText = status
end

-- 화면을 띄운다. instant면 트윈 없이 바로 (처음 들어올 때 기본 로딩 화면 대신).
function LoadingScreen.show(status: string, instant: boolean?): ()
	local ui = getView()
	statusText = status
	hideToken += 1
	if not visible then
		visible = true
		shownAt = os.clock()
	end
	ui.gui.Enabled = true
	if not renderConnection then
		renderConnection = RunService.RenderStepped:Connect(animate)
	end
	animate()
	if instant then
		if fadeTween then
			fadeTween:Cancel()
		end
		ui.canvas.GroupTransparency = 0
	else
		fadeTo(0)
	end
end

-- 띄운 지 minVisible초가 지났으면 사라지게 한다 (그 전이면 그때까지 기다림). 그 사이 다시 show하면 취소된다.
function LoadingScreen.hide(minVisible: number?): ()
	if not visible then
		return
	end
	hideToken += 1
	local token = hideToken
	local waitTime = math.max(0, (minVisible or 0) - (os.clock() - shownAt))
	task.delay(waitTime, function()
		if token ~= hideToken then
			return
		end
		fadeTo(1, function()
			if token ~= hideToken then
				return
			end
			visible = false
			local ui = getView()
			ui.gui.Enabled = false
			if renderConnection then
				renderConnection:Disconnect()
				renderConnection = nil
			end
		end)
	end)
end

function LoadingScreen.isVisible(): boolean
	return visible
end

-- 화면 전체 (TeleportService:SetTeleportGui용)
function LoadingScreen.getTeleportGui(): GuiObject
	return getView().canvas
end

return LoadingScreen
