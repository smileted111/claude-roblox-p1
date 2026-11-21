--!strict
-- ResultController: 스테이지 결과·최종 결과 화면 (GDD 3.1, 3.4, 11장). GDD 13.2 목록 밖에 추가한 컨트롤러.
--
-- 스테이지 결과 (StageResult 리모트, 결과 단계 동안)
--   HUD 위 가운데 세로 목록(UIController.mountCenter)에 넣어 알림과 겹치지 않게 한다.
--   제목(스테이지 n · 맵 이름) / 승패 한 줄 (추격자 승리·생존자 승리, 솔로는 살아남음·잡힘) /
--   플레이어 줄: 이름 · 결과(생존·탈출·잡힘·추격자 n명 잡음·나감) · 받은 코인
-- 최종 결과 (MatchResult 리모트, 최종 결과 단계 동안. 따로 ScreenGui)
--   라스트 서바이버 발표(이름이 튀어나오는 연출, 없으면 베스트 서바이버) / 표(이름, 스테이지별 결과, 잡은 수, 코인) /
--   "다시 하기" 버튼: 지금은 화면을 닫는다 (서버는 결과 시간이 끝나면 다음 매치 대기로 간다. S3-2에서 대기열 참가로).
-- 코인은 아직 저장되지 않는 임시 값이다 (S3-1). 단계가 바뀌면 화면을 닫는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)
local UIController = require(script.Parent.UIController)

local Colors = UiStyle.Colors
local localPlayer = Players.LocalPlayer

local ROW_HEIGHT = 28
local NAME_WIDTH = 170
local STAGE_WIDTH = 64
local CATCH_WIDTH = 70
local COIN_WIDTH = 80
local ANNOUNCE_DELAY = 0.6 -- 최종 결과 제목 뒤 이름이 튀어나오기까지 (초)

local OUTCOME_COLORS: { [Types.StageOutcome]: Color3 } = {
	Survived = Colors.Good,
	Escaped = Colors.Good,
	Caught = Colors.Accent,
	Chaser = Colors.Warning,
	Left = Colors.Disabled,
	Absent = Colors.Disabled,
}

local ResultController = {}

local stagePanel: Frame? = nil
local matchGui: ScreenGui? = nil

local function cell(parent: Instance, text: string, width: number, order: number, color: Color3?): TextLabel
	local label = UiStyle.label(parent, `Cell{order}`, order, ROW_HEIGHT)
	label.Size = UDim2.fromOffset(width, ROW_HEIGHT)
	label.TextSize = 18
	label.Text = text
	label.TextColor3 = color or Colors.Text
	return label
end

local function row(parent: Instance, order: number, highlight: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Name = `Row{order}`
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = Colors.Accent
	frame.BackgroundTransparency = if highlight then 0.8 else 1
	frame.BorderSizePixel = 0
	UiStyle.corner(frame, 4)
	UiStyle.list(frame, Enum.FillDirection.Horizontal, 0)
	frame.Parent = parent
	return frame
end

local function stageName(stageId: Types.StageId): string
	return string.format(Strings.Hud.StageTitle, Stages[stageId].Number, Strings.Stages[stageId])
end

--------------------------------------------------------------------------------
-- 스테이지 결과

local function closeStage(): ()
	if stagePanel then
		stagePanel:Destroy()
		stagePanel = nil
	end
end

local function headline(result: Types.StageResult): (string, Color3)
	if result.solo then
		local me = result.players[1]
		local success = me ~= nil and (me.outcome == "Survived" or me.outcome == "Escaped")
		return if success then Strings.Results.SoloSuccess else Strings.Results.SoloFail,
			if success then Colors.Good else Colors.Accent
	end
	if result.chaserWon then
		return Strings.Results.ChaserWins, Colors.Accent
	end
	return Strings.Results.SurvivorsWin, Colors.Good
end

local function showStage(result: Types.StageResult): ()
	closeStage()
	local panel = UiStyle.panel(nil, "StageResult", true)
	panel.Size = UDim2.fromScale(1, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UiStyle.padding(panel, 12, 18)
	local layout = UiStyle.list(panel, Enum.FillDirection.Vertical, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	local title = UiStyle.label(panel, "Title", 1, 22)
	title.Font = UiStyle.BoldFont
	title.TextColor3 = Colors.Accent
	title.Text = `{Strings.Results.StageTitle} · {stageName(result.stageId)}`
	local text, color = headline(result)
	local head = UiStyle.label(panel, "Headline", 2, 40)
	head.Font = UiStyle.BoldFont
	head.TextColor3 = color
	head.Text = text

	for index, player in result.players do
		local line = row(panel, 10 + index, player.userId == localPlayer.UserId)
		cell(line, player.name, NAME_WIDTH + STAGE_WIDTH, 1)
		local outcomeText = Strings.Outcomes[player.outcome]
		if player.outcome == "Chaser" then
			outcomeText = `{outcomeText} · {string.format(Strings.Results.ChaserCatches, player.catches)}`
		end
		cell(line, outcomeText, STAGE_WIDTH * 3, 2, OUTCOME_COLORS[player.outcome])
		cell(line, string.format(Strings.Results.Coins, player.coins), COIN_WIDTH + 30, 3, Colors.Warning)
	end
	stagePanel = panel
	UIController.mountCenter(panel, 0)
end

--------------------------------------------------------------------------------
-- 최종 결과

local function closeMatch(): ()
	if matchGui then
		matchGui:Destroy()
		matchGui = nil
	end
end

local function namesOf(result: Types.MatchResult, userIds: { number }): string
	local names: { string } = {}
	for _, userId in userIds do
		for _, record in result.players do
			if record.userId == userId then
				table.insert(names, record.name)
			end
		end
	end
	return table.concat(names, ", ")
end

-- 칭호 이름이 작게 시작해 튀어나온다.
local function popIn(label: TextLabel): ()
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	label.TextTransparency = 1
	task.delay(ANNOUNCE_DELAY, function()
		if label.Parent then
			local info = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			TweenService:Create(scale, info, { Scale = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		end
	end)
end

local function showMatch(result: Types.MatchResult): ()
	closeMatch()
	closeStage()
	local gui = UiStyle.screenGui("MatchResult", 20) -- 관전 화면(10)보다 위
	UiStyle.addScale(gui)
	local panel = UiStyle.panel(gui, "Panel", true)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(NAME_WIDTH + STAGE_WIDTH * #result.stageIds + CATCH_WIDTH + COIN_WIDTH + 48, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UiStyle.padding(panel, 14, 18)
	local layout = UiStyle.list(panel, Enum.FillDirection.Vertical, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	local title = UiStyle.label(panel, "Title", 1, 24)
	title.Font = UiStyle.BoldFont
	title.TextColor3 = Colors.Accent
	title.Text = Strings.Results.MatchTitle

	-- 라스트 서바이버 (없으면 베스트 서바이버)
	local subtitle = UiStyle.label(panel, "Subtitle", 2, 26)
	subtitle.Font = UiStyle.BoldFont
	local announce = UiStyle.label(panel, "Announce", 3, 46)
	announce.Font = UiStyle.BoldFont
	announce.TextColor3 = Colors.Warning
	if #result.lastSurvivorUserIds > 0 then
		subtitle.Text = `★ {Strings.Results.LastSurvivor} ★`
		announce.Text = namesOf(result, result.lastSurvivorUserIds)
	elseif result.bestSurvivorUserId then
		subtitle.Text = Strings.Results.BestSurvivor
		announce.Text = namesOf(result, { result.bestSurvivorUserId })
	else
		subtitle.Text = Strings.Results.NoTitle
		subtitle.TextSize = 18
		announce.Visible = false
	end
	popIn(announce)

	-- 표
	local header = row(panel, 10, false)
	cell(header, Strings.Results.ColumnName, NAME_WIDTH, 1, Colors.Subtext)
	for index = 1, #result.stageIds do
		cell(header, string.format(Strings.Results.ColumnStage, index), STAGE_WIDTH, 1 + index, Colors.Subtext)
	end
	cell(header, Strings.Results.ColumnCatches, CATCH_WIDTH, 20, Colors.Subtext)
	cell(header, Strings.Results.ColumnCoins, COIN_WIDTH, 21, Colors.Subtext)
	for index, record in result.players do
		local line = row(panel, 10 + index, record.userId == localPlayer.UserId)
		local name = if record.lastSurvivor then `★ {record.name}` else record.name
		cell(line, name, NAME_WIDTH, 1, if record.lastSurvivor then Colors.Warning else Colors.Text)
		for stageIndex, outcome in record.stages do
			cell(line, Strings.Outcomes[outcome], STAGE_WIDTH, 1 + stageIndex, OUTCOME_COLORS[outcome])
		end
		cell(line, tostring(record.catches), CATCH_WIDTH, 20)
		cell(line, tostring(record.coins), COIN_WIDTH, 21, Colors.Warning)
	end

	local note = UiStyle.label(panel, "Note", 90, 18)
	note.TextSize = 13
	note.TextColor3 = Colors.Subtext
	note.Text = Strings.Results.CoinsNote

	local again = UiStyle.button(panel, "PlayAgain", 100, UDim2.fromOffset(220, 48), true)
	again.Text = Strings.Results.PlayAgain
	again.Activated:Connect(closeMatch)

	gui.Parent = UiStyle.playerGui()
	matchGui = gui
end

--------------------------------------------------------------------------------

local function onPhaseChanged(): ()
	local phase = MatchState.getPhase()
	if phase ~= "StageResult" then
		closeStage()
	end
	if phase ~= "MatchResult" then
		closeMatch()
	end
end

function ResultController.Init(): () end

function ResultController.Start(): ()
	Remotes.get("StageResult").OnClientEvent:Connect(function(result: unknown)
		if typeof(result) == "table" then
			showStage(result :: Types.StageResult)
		end
	end)
	Remotes.get("MatchResult").OnClientEvent:Connect(function(result: unknown)
		if typeof(result) == "table" then
			showMatch(result :: Types.MatchResult)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(MatchState.Attribute.Phase):Connect(onPhaseChanged)
end

return ResultController
