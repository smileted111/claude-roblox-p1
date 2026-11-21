--!strict
-- 발전기 위에 수리 진행 바를 띄운다 (GDD 6.2 "작동 중 진행 바가 보이고"). 모두에게 보이고 벽에 가려진다.
-- 진행은 서버(ObjectiveService)가 발전기 Attribute(ObjectiveState)로 공개한다. 고친 적이 없으면 숨기고,
-- 다 고치면 "작동 중"을 보여준다. StreamingEnabled로 발전기가 다시 들어오면 다시 만든다.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapObjects = require(ReplicatedStorage.Shared.Config.MapObjects)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local ObjectiveState = require(ReplicatedStorage.Shared.ObjectiveState)
local Strings = require(ReplicatedStorage.Shared.Strings)
local UiStyle = require(script.Parent.UiStyle)

local MAX_DISTANCE = 70 -- 이 거리 안에서만 보임 (스터드)

type Billboard = {
	gui: BillboardGui,
	fill: Frame,
	label: TextLabel,
	connections: { RBXScriptConnection },
}

local GeneratorBillboards = {}

local tracked: { [Instance]: Billboard } = {}

local function render(generator: Instance, billboard: Billboard): ()
	local repaired = ObjectiveState.isRepaired(generator)
	local progress = ObjectiveState.getProgress(generator)
	billboard.gui.Enabled = repaired or progress > 0
	billboard.fill.Size = UDim2.fromScale(if repaired then 1 else progress, 1)
	billboard.fill.BackgroundColor3 = if repaired then MapObjects.Generator.RepairedColor else UiStyle.Colors.Accent
	billboard.label.Text = if repaired then Strings.Hud.Repaired else `{math.floor(progress * 100)}%`
end

local function untrack(generator: Instance): ()
	local billboard = tracked[generator]
	if not billboard then
		return
	end
	tracked[generator] = nil
	for _, connection in billboard.connections do
		connection:Disconnect()
	end
	billboard.gui:Destroy()
end

local function track(generator: Instance): ()
	if tracked[generator] or not generator:IsDescendantOf(Workspace) then
		return
	end
	local body = ObjectiveState.getBody(generator)
	if not body then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RepairBillboard"
	gui.Size = UDim2.fromOffset(120, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 2.5, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.Enabled = false
	local label = UiStyle.label(gui, "Text", 0, 18)
	label.Font = UiStyle.BoldFont
	label.TextStrokeTransparency = 0.4
	local back, fill = UiStyle.bar(gui, "Bar", 0, UDim2.new(1, 0, 0, 12), UiStyle.Colors.Accent)
	back.Position = UDim2.fromOffset(0, 20)
	gui.Parent = body

	local billboard: Billboard = { gui = gui, fill = fill, label = label, connections = {} }
	tracked[generator] = billboard
	table.insert(
		billboard.connections,
		generator.AttributeChanged:Connect(function()
			render(generator, billboard)
		end)
	)
	table.insert(
		billboard.connections,
		gui.AncestryChanged:Connect(function()
			if not gui:IsDescendantOf(Workspace) then
				untrack(generator)
			end
		end)
	)
	render(generator, billboard)
end

function GeneratorBillboards.start(): ()
	CollectionService:GetInstanceAddedSignal(MapTags.Generator):Connect(track)
	CollectionService:GetInstanceRemovedSignal(MapTags.Generator):Connect(untrack)
	for _, generator in CollectionService:GetTagged(MapTags.Generator) do
		track(generator)
	end
end

return GeneratorBillboards
