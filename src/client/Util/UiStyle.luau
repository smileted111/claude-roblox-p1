--!strict
-- 화면 UI 공통 스타일과 만들기 함수 (GDD 11장, 질문지 Q10-4: 어두운 반투명 + 빨강 강조, 큰 글씨).
-- UIController(HUD·역할 공개·알림)와 SpectateController(관전 화면)가 같이 쓴다.
-- 크기는 Config.Ui.ReferenceSize 화면 기준의 픽셀 값으로 쓰고, bindScale이 화면 크기에 맞춰 UIScale로 줄인다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local Ui = require(ReplicatedStorage.Shared.Config.Ui)

local Colors = table.freeze({
	Panel = Color3.fromRGB(16, 16, 20),
	Accent = Color3.fromRGB(220, 50, 60),
	Text = Color3.fromRGB(240, 240, 245),
	Subtext = Color3.fromRGB(185, 185, 195),
	Disabled = Color3.fromRGB(110, 110, 120),
	Track = Color3.fromRGB(45, 45, 52), -- 진행 바의 빈 부분
	Good = Color3.fromRGB(120, 210, 150), -- 정상 상태
	Warning = Color3.fromRGB(255, 170, 60), -- 부상, 스태미나 부족
	Stamina = Color3.fromRGB(110, 200, 255),
})

-- 추격자 화면의 괴물 아이콘 색 (괴물 모델의 눈 색과 맞춤)
local MonsterColors: { [Types.MonsterId]: Color3 } = {
	Wanderer = Color3.fromRGB(60, 255, 90),
	Hound = Color3.fromRGB(255, 140, 40),
	Watcher = Color3.fromRGB(255, 230, 60),
	Shadow = Color3.fromRGB(170, 110, 255),
	Giant = Color3.fromRGB(255, 70, 70),
}

local UiStyle = {
	Colors = Colors,
	MonsterColors = MonsterColors,
	PanelTransparency = 0.25,
	Font = Enum.Font.GothamMedium,
	BoldFont = Enum.Font.GothamBold,
}

-- 화면 전체 ScreenGui. 캐릭터가 다시 생겨도 남는다.
function UiStyle.screenGui(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = displayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return gui
end

function UiStyle.corner(parent: GuiObject, radius: number?): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

function UiStyle.stroke(parent: GuiObject, color: Color3, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Thickness = 1.5
	stroke.Parent = parent
	return stroke
end

function UiStyle.padding(parent: GuiObject, vertical: number, horizontal: number): ()
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, vertical)
	padding.PaddingBottom = UDim.new(0, vertical)
	padding.PaddingLeft = UDim.new(0, horizontal)
	padding.PaddingRight = UDim.new(0, horizontal)
	padding.Parent = parent
end

-- 자식을 LayoutOrder 순서로 한 줄(가로) 또는 한 칸(세로)으로 늘어놓는다.
function UiStyle.list(parent: GuiObject, direction: Enum.FillDirection, spacing: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, spacing)
	layout.Parent = parent
	return layout
end

-- 어두운 반투명 패널. accent면 빨간 테두리를 두른다.
function UiStyle.panel(parent: Instance, name: string, accent: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Colors.Panel
	frame.BackgroundTransparency = UiStyle.PanelTransparency
	frame.BorderSizePixel = 0
	UiStyle.corner(frame)
	if accent then
		UiStyle.stroke(frame, Colors.Accent, 0.3)
	end
	frame.Parent = parent
	return frame
end

-- 투명한 틀 (배치용)
function UiStyle.container(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

-- 가로를 꽉 채우는 한 줄 글자. height는 줄 높이(픽셀)이고 글자 크기는 그보다 조금 작다.
function UiStyle.label(parent: Instance, name: string, order: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = UiStyle.Font
	label.TextSize = height - 4
	label.TextColor3 = Colors.Text
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = parent
	return label
end

function UiStyle.button(parent: Instance, name: string, order: number, size: UDim2, enabled: boolean): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.Size = size
	button.BackgroundColor3 = Colors.Panel
	button.BackgroundTransparency = UiStyle.PanelTransparency
	button.BorderSizePixel = 0
	button.AutoButtonColor = enabled
	button.Font = UiStyle.BoldFont
	button.TextSize = math.floor(size.Y.Offset * 0.4)
	button.TextColor3 = if enabled then Colors.Text else Colors.Disabled
	UiStyle.corner(button)
	UiStyle.stroke(button, if enabled then Colors.Accent else Colors.Disabled)
	button.Parent = parent
	return button
end

-- 진행 바. 돌려준 fill의 Size.X.Scale(0~1)로 채운 정도를 바꾼다.
function UiStyle.bar(parent: Instance, name: string, order: number, size: UDim2, color: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Name = name
	back.LayoutOrder = order
	back.Size = size
	back.BackgroundColor3 = Colors.Track
	back.BackgroundTransparency = 0.1
	back.BorderSizePixel = 0
	UiStyle.corner(back, 6)
	back.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	UiStyle.corner(fill, 6)
	fill.Parent = back
	return back, fill
end

-- gui에 UIScale을 달고, 화면 크기에 맞춰 Config.Ui.ReferenceSize 대비 비율(MinScale ~ MaxScale)로 바꾼다.
function UiStyle.addScale(gui: ScreenGui): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	UiStyle.bindScale(scale)
	return scale
end

function UiStyle.bindScale(scale: UIScale): ()
	local connection: RBXScriptConnection? = nil
	local function update(): ()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local size = camera.ViewportSize
		local ratio = math.min(size.X / Ui.ReferenceSize.X, size.Y / Ui.ReferenceSize.Y)
		scale.Scale = math.clamp(ratio, Ui.MinScale, Ui.MaxScale)
	end
	local function watchCamera(): ()
		if connection then
			connection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

function UiStyle.playerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

-- 초를 m:ss로
function UiStyle.clock(seconds: number): (number, number)
	local whole = math.max(0, math.floor(seconds))
	return whole // 60, whole % 60
end

return UiStyle
