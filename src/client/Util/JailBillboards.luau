--!strict
-- 감옥(경찰과 도둑 모드) 위에 "감옥 · n명"과 구출 진행 바를 띄운다 (2026-11-22 사용자 요청). 모두에게 보이고 벽에 가려진다.
-- 갇힌 사람 수와 진행은 서버(JailService)가 감옥 Model Attribute로 공개한다 (JailState).
-- 진행이 0이면 바를 숨기고, 갇힌 사람이 없으면 이름만 보인다. StreamingEnabled로 감옥이 다시 들어오면 다시 만든다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameModes = require(ReplicatedStorage.Shared.Config.GameModes)
local JailState = require(ReplicatedStorage.Shared.JailState)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local Strings = require(ReplicatedStorage.Shared.Strings)
local UiStyle = require(script.Parent.UiStyle)

local HEIGHT_ABOVE = 3 -- 감옥 꼭대기 위로 띄우는 높이 (스터드)

type Billboard = {
	gui: BillboardGui,
	label: TextLabel,
	bar: Frame,
	fill: Frame,
	connections: { RBXScriptConnection },
}

local JailBillboards = {}

local tracked: { [Instance]: Billboard } = {}

local function render(jail: Instance, billboard: Billboard): ()
	local progress = JailState.getProgress(jail)
	local prisoners = JailState.getPrisoners(jail)
	local rescuing = progress > 0 and prisoners > 0
	billboard.label.Text = if rescuing
		then string.format(Strings.Hud.JailRescue, math.floor(progress * 100))
		else string.format(Strings.Hud.JailLabel, prisoners)
	billboard.label.TextColor3 = if rescuing then UiStyle.Colors.Good else UiStyle.Colors.Text
	billboard.bar.Visible = rescuing
	billboard.fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
end

local function untrack(jail: Instance): ()
	local billboard = tracked[jail]
	if not billboard then
		return
	end
	tracked[jail] = nil
	for _, connection in billboard.connections do
		connection:Disconnect()
	end
	billboard.gui:Destroy()
end

local function track(jail: Instance): ()
	if tracked[jail] or not jail:IsA("Model") or not jail:IsDescendantOf(Workspace) then
		return
	end
	local inside = jail:FindFirstChild(JailState.Inside, true)
	if not inside or not inside:IsA("BasePart") then
		return
	end
	local _, size = jail:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "JailBillboard"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y + HEIGHT_ABOVE, 0)
	gui.MaxDistance = GameModes.Jail.BillboardMaxDistance
	gui.LightInfluence = 0
	local label = UiStyle.label(gui, "Text", 0, 22)
	label.Font = UiStyle.BoldFont
	label.TextStrokeTransparency = 0.4
	local bar, fill = UiStyle.bar(gui, "Bar", 0, UDim2.new(1, 0, 0, 12), UiStyle.Colors.Good)
	bar.Position = UDim2.fromOffset(0, 26)
	gui.Adornee = inside
	gui.Parent = inside

	local billboard: Billboard = { gui = gui, label = label, bar = bar, fill = fill, connections = {} }
	tracked[jail] = billboard
	table.insert(
		billboard.connections,
		jail.AttributeChanged:Connect(function()
			render(jail, billboard)
		end)
	)
	table.insert(
		billboard.connections,
		gui.AncestryChanged:Connect(function()
			if not gui:IsDescendantOf(Workspace) then
				untrack(jail)
			end
		end)
	)
	render(jail, billboard)
end

function JailBillboards.start(): ()
	CollectionService:GetInstanceAddedSignal(MapTags.Jail):Connect(function(jail: Instance)
		-- 감옥 Model은 자식 파트보다 먼저 들어올 수 있어 한 프레임 뒤에 찾는다.
		task.defer(track, jail)
	end)
	CollectionService:GetInstanceRemovedSignal(MapTags.Jail):Connect(untrack)
	for _, jail in CollectionService:GetTagged(MapTags.Jail) do
		track(jail)
	end
end

return JailBillboards
