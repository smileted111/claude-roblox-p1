--!strict
-- 월드의 한 위치에 잠깐 떠 있는 표시 (GDD 4.1 감시자 경보, 6.2 발전기 소리, 7장). 이 플레이어 화면에만 보인다.
-- 벽 너머에서도 보이고(AlwaysOnTop), duration초 뒤 사라진다. 추격자 화면의 ChaserMarker 리모트에 쓴다.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UiStyle = require(script.Parent.UiStyle)

local FADE_TIME = 0.3

local WorldMarker = {}

function WorldMarker.show(position: Vector3, duration: number, text: string, color: Color3): ()
	-- Terrain은 원점에 있어서 Attachment.Position이 곧 월드 위치다. 클라이언트에서 만들어 이 화면에만 있다.
	local attachment = Instance.new("Attachment")
	attachment.Name = "WorldMarker"
	attachment.Position = position
	attachment.Parent = Workspace.Terrain

	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldMarker"
	gui.Adornee = attachment
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(120, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(36, 36)
	icon.BackgroundColor3 = UiStyle.Colors.Panel
	icon.BackgroundTransparency = 0.2
	icon.Font = UiStyle.BoldFont
	icon.TextSize = 28
	icon.TextColor3 = color
	icon.Text = "!"
	UiStyle.corner(icon, 18)
	UiStyle.stroke(icon, color)
	icon.Parent = gui

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Position = UDim2.fromOffset(0, 40)
	label.Size = UDim2.new(1, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = UiStyle.BoldFont
	label.TextSize = 16
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui

	gui.Parent = UiStyle.playerGui()

	task.delay(math.max(0, duration - FADE_TIME), function()
		local info = TweenInfo.new(FADE_TIME)
		TweenService:Create(icon, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(FADE_TIME)
		gui:Destroy()
		attachment:Destroy()
	end)
end

return WorldMarker
