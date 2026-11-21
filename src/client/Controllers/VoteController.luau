--!strict
-- VoteController: 맵·화면 모드 투표 창과 실시간 투표 현황 (2026-11-21 사용자 요청, GDD 3.1.1). GDD 13.2 목록 밖에 추가한 컨트롤러.
--
-- 투표 단계(Phase Voting) 동안 서버의 모든 플레이어에게 가운데 창을 띄운다 (Config.Match.VoteTime초 동안만 뜨는 창이라
--   화면 가운데 규칙의 "잠깐 뜨는 것"에 해당하고, 투표는 로비에서 해서 시야를 가릴 위험이 없다).
--   참가자(Player Attribute Voter)는 눌러서 투표하고(CastVote 리모트, 다시 누르면 바꿈), 그 밖의 사람은 현황만 본다.
--   제목 · 남은 시간 · "투표 n/m명" / 화면 모드 칸(첫 스테이지만, VoteModeCounts가 있을 때) / 맵 칸(Config.Match.MapPool 순서) /
--   추격자 희망 줄(참가자가 Config.Match.MinPlayersForChaser명 이상일 때): 누르면 켜고 다시 누르면 끈다(CastVote "Chaser").
--   켠 사람 수·얼굴이 보이고, 켠 사람 중 한 명이 이번 스테이지 추격자가 된다 (서버 RoleService.pickChaser).
--   휴대폰(UIScale 0.8)에서도 첫 투표가 화면 높이에 들어가게 줄 높이를 줄였다.
-- 실시간 현황: 칸마다 표 수, 참가자 수 대비 채워지는 막대(트윈), 그 칸을 고른 참가자 얼굴(최대 MAX_AVATARS, 넘으면 +n),
--   가장 많은 표를 받은 칸은 금색 테두리와 ★. 내가 고른 칸은 초록 테두리. 플레이한 맵(VotePlayed)은 흐리게 "(플레이함)".
--   표 수는 서버 집계(VoteMapCounts·VoteModeCounts), 누가 골랐는지는 각 플레이어의 Attribute VoteMap·VoteMode(모두에게 복제).
-- 머리 위 표시: 투표 중인 다른 참가자 캐릭터 머리 위에 지금 고른 맵(첫 투표는 모드도)을 띄운다. 고르기 전에는 "고르는 중...".
-- 판정·집계는 서버 VoteService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local VisualModes = require(ReplicatedStorage.Shared.Config.VisualModes)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)

local Colors = UiStyle.Colors
local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local PANEL_WIDTH = 580
local OPTION_WIDTH = 266
local OPTION_HEIGHT = 58 -- MinButtonHeight(56) 이상
local GRID_GAP = 8
local CHASER_COLOR = Color3.fromRGB(235, 90, 90)
local AVATAR_SIZE = 22
local MAX_AVATARS = 5
local BAR_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GOLD = Color3.fromRGB(255, 205, 80)
local TAG_NAME = "VoteTag"

type VoteOption = {
	key: string,
	kind: Types.VoteKind,
	button: TextButton,
	stroke: UIStroke,
	fill: Frame,
	nameLabel: TextLabel,
	countLabel: TextLabel,
	avatars: Frame,
	shownRatio: number,
}

type VoteView = {
	gui: ScreenGui,
	panel: Frame,
	title: TextLabel,
	hint: TextLabel,
	modeLabel: TextLabel,
	modeRow: Frame,
	modeOptions: { VoteOption },
	mapOptions: { VoteOption },
	chaserRow: Frame,
	chaserOption: VoteOption,
}

local VoteController = {}

local view: VoteView? = nil
local thumbnails: { [number]: string } = {}
local thumbnailPending: { [number]: boolean } = {}
local tags: { [Player]: BillboardGui } = {}
local render: () -> () = function() end

--------------------------------------------------------------------------------
-- 얼굴 사진 (비동기로 받아 두고 받으면 다시 그린다)

local function thumbnailFor(userId: number): string?
	local cached = thumbnails[userId]
	if cached then
		return cached
	end
	if userId > 0 and not thumbnailPending[userId] then
		thumbnailPending[userId] = true
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			end)
			if ok and typeof(content) == "string" then
				thumbnails[userId] = content
				render()
			end
		end)
	end
	return nil
end

--------------------------------------------------------------------------------
-- 창 만들기

local function makeOption(
	parent: Instance,
	key: string,
	kind: Types.VoteKind,
	order: number,
	castVote: RemoteEvent
): VoteOption
	local button = UiStyle.button(parent, key, order, UDim2.fromOffset(OPTION_WIDTH, OPTION_HEIGHT), true)
	button.Text = ""
	button.ClipsDescendants = true
	local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Colors.Accent
	fill.BackgroundTransparency = 0.55
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 1
	UiStyle.corner(fill)
	fill.Parent = button

	local nameLabel = UiStyle.label(button, "Name", 0, 26)
	nameLabel.Position = UDim2.fromOffset(12, 4)
	nameLabel.Size = UDim2.new(1, -90, 0, 26)
	nameLabel.TextSize = 19
	nameLabel.Font = UiStyle.BoldFont
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 2

	local countLabel = UiStyle.label(button, "Count", 0, 26)
	countLabel.AnchorPoint = Vector2.new(1, 0)
	countLabel.Position = UDim2.new(1, -12, 0, 4)
	countLabel.Size = UDim2.fromOffset(80, 26)
	countLabel.TextSize = 18
	countLabel.Font = UiStyle.BoldFont
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 2

	local avatars = UiStyle.container(button, "Avatars")
	avatars.Position = UDim2.fromOffset(12, 31)
	avatars.Size = UDim2.new(1, -24, 0, AVATAR_SIZE)
	avatars.ZIndex = 2
	local layout = UiStyle.list(avatars, Enum.FillDirection.Horizontal, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	button.Activated:Connect(function()
		if MatchState.isVoter(localPlayer) then
			castVote:FireServer(kind, key)
		end
	end)
	return {
		key = key,
		kind = kind,
		button = button,
		stroke = stroke,
		fill = fill,
		nameLabel = nameLabel,
		countLabel = countLabel,
		avatars = avatars,
		shownRatio = 0,
	}
end

local function sectionLabel(parent: Instance, name: string, order: number, text: string): TextLabel
	local label = UiStyle.label(parent, name, order, 18)
	label.Font = UiStyle.BoldFont
	label.TextColor3 = Colors.Subtext
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	return label
end

local function optionGrid(parent: Instance, name: string, order: number, cellWidth: number?): Frame
	local grid = UiStyle.container(parent, name)
	grid.LayoutOrder = order
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(cellWidth or OPTION_WIDTH, OPTION_HEIGHT)
	layout.CellPadding = UDim2.fromOffset(12, GRID_GAP)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	return grid
end

local function createView(castVote: RemoteEvent): VoteView
	local gui = UiStyle.screenGui("Vote", 8)
	UiStyle.addScale(gui)
	local panel = UiStyle.panel(gui, "Panel", true)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	UiStyle.padding(panel, 12, 18)
	UiStyle.list(panel, Enum.FillDirection.Vertical, 5)

	local title = UiStyle.label(panel, "Title", 1, 30)
	title.Font = UiStyle.BoldFont
	title.TextColor3 = Colors.Accent
	title.RichText = true
	local hint = UiStyle.label(panel, "Hint", 3, 18)
	hint.TextSize = 14
	hint.TextColor3 = Colors.Subtext
	hint.TextWrapped = true
	hint.TextTruncate = Enum.TextTruncate.None
	hint.AutomaticSize = Enum.AutomaticSize.Y

	local modeLabel = sectionLabel(panel, "ModeLabel", 4, Strings.Vote.ModeSection)
	local modeRow = optionGrid(panel, "Modes", 5)
	local modeOptions: { VoteOption } = {}
	for index, mode in VisualModes.Modes do
		table.insert(modeOptions, makeOption(modeRow, mode, "Mode", index, castVote))
	end

	sectionLabel(panel, "MapLabel", 6, Strings.Vote.MapSection)
	local mapGrid = optionGrid(panel, "Maps", 7)
	local mapOptions: { VoteOption } = {}
	for index, stageId in Match.MapPool do
		table.insert(mapOptions, makeOption(mapGrid, stageId, "Map", index, castVote))
	end

	local chaserRow = optionGrid(panel, "Chaser", 8, OPTION_WIDTH * 2 + 12)
	local chaserOption = makeOption(chaserRow, "Toggle", "Chaser", 1, castVote)

	gui.Parent = UiStyle.playerGui()
	return {
		gui = gui,
		panel = panel,
		title = title,
		hint = hint,
		modeLabel = modeLabel,
		modeRow = modeRow,
		modeOptions = modeOptions,
		mapOptions = mapOptions,
		chaserRow = chaserRow,
		chaserOption = chaserOption,
	}
end

--------------------------------------------------------------------------------
-- 그리기

-- 지금 투표 참가자 (UserId순)
local function voters(): { Player }
	local list: { Player } = {}
	for _, player in Players:GetPlayers() do
		if MatchState.isVoter(player) then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId
	end)
	return list
end

local function choiceOf(player: Player, kind: Types.VoteKind): string?
	return if kind == "Map" then MatchState.getVoteMap(player) else MatchState.getVoteMode(player)
end

-- 그 칸을 고른 참가자 얼굴. 사진이 없으면(받는 중·Studio 시험 계정) 이름 첫 글자
local function drawAvatars(option: VoteOption, pickers: { Player }): ()
	for _, child in option.avatars:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, player in pickers do
		if index > MAX_AVATARS then
			local more = UiStyle.label(option.avatars, "More", index, AVATAR_SIZE)
			more.Size = UDim2.fromOffset(36, AVATAR_SIZE)
			more.TextSize = 14
			more.Text = `+{#pickers - MAX_AVATARS}`
			more.ZIndex = 3
			break
		end
		local image = Instance.new("ImageLabel")
		image.Name = player.Name
		image.LayoutOrder = index
		image.Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE)
		image.BackgroundColor3 = if player == localPlayer then Colors.Good else Colors.Track
		image.BorderSizePixel = 0
		image.ZIndex = 3
		image.Image = thumbnailFor(player.UserId) or ""
		UiStyle.corner(image, AVATAR_SIZE // 2)
		if image.Image == "" then
			local initial = UiStyle.label(image, "Initial", 0, AVATAR_SIZE)
			initial.Size = UDim2.fromScale(1, 1)
			initial.TextSize = 13
			initial.Font = UiStyle.BoldFont
			initial.Text = string.upper(string.sub(player.DisplayName, 1, 1))
			initial.ZIndex = 4
		end
		image.Parent = option.avatars
	end
end

local function drawOption(
	option: VoteOption,
	name: string,
	count: number,
	total: number,
	pickers: { Player },
	state: { enabled: boolean, chosen: boolean, leader: boolean, interactive: boolean }
): ()
	option.nameLabel.Text = if state.leader then `★ {name}` else name
	option.countLabel.Text = if state.enabled then string.format(Strings.Vote.Votes, count) else ""
	option.button.AutoButtonColor = state.enabled and state.interactive
	option.button.Active = state.enabled and state.interactive
	option.nameLabel.TextColor3 = if state.chosen
		then Colors.Good
		elseif state.leader then GOLD
		elseif state.enabled then Colors.Text
		else Colors.Disabled
	option.countLabel.TextColor3 = if state.leader then GOLD else Colors.Text
	option.stroke.Color = if state.chosen
		then Colors.Good
		elseif state.leader then GOLD
		elseif state.enabled then Colors.Accent
		else Colors.Disabled
	option.stroke.Thickness = if state.chosen or state.leader then 3 else 1.5
	local ratio = if state.enabled and total > 0 then math.clamp(count / total, 0, 1) else 0
	if ratio ~= option.shownRatio then
		option.shownRatio = ratio
		TweenService:Create(option.fill, BAR_TWEEN, { Size = UDim2.fromScale(ratio, 1) }):Play()
	end
	option.fill.BackgroundColor3 = if state.leader then GOLD else Colors.Accent
	drawAvatars(option, pickers)
end

-- 한 줄(모드 또는 맵)의 칸을 모두 그린다. available에 없는 칸은 흐리게 (played면 "(플레이함)")
local function drawGroup(
	options: { VoteOption },
	counts: { [string]: number },
	available: { string },
	played: { string },
	list: { Player },
	nameOf: (string) -> string
): ()
	local best = 0
	for _, key in available do
		best = math.max(best, counts[key] or 0)
	end
	local interactive = MatchState.isVoter(localPlayer)
	for _, option in options do
		local key = option.key
		local enabled = table.find(available, key) ~= nil
		local pickers: { Player } = {}
		for _, player in list do
			if choiceOf(player, option.kind) == key then
				table.insert(pickers, player)
			end
		end
		local count = counts[key] or 0
		local name = if enabled
			then nameOf(key)
			elseif table.find(played, key) then string.format(Strings.Vote.Played, nameOf(key))
			else nameOf(key)
		drawOption(option, name, count, #list, if enabled then pickers else {}, {
			enabled = enabled,
			chosen = enabled and choiceOf(localPlayer, option.kind) == key,
			leader = enabled and best > 0 and count == best,
			interactive = interactive,
		})
	end
end

-- 머리 위 표시: 참가자가 지금 고른 맵(첫 투표는 모드도)
local function tagText(player: Player, withMode: boolean): string
	local map = MatchState.getVoteMap(player)
	local parts: { string } = {}
	if map then
		table.insert(parts, Strings.Stages[map])
	end
	local mode = MatchState.getVoteMode(player)
	if withMode and mode then
		table.insert(parts, Strings.Modes[mode])
	end
	if MatchState.wantsChaser(player) then
		table.insert(parts, Strings.Vote.TagChaser)
	end
	return if #parts > 0 then table.concat(parts, " · ") else Strings.Vote.Choosing
end

local function removeTag(player: Player): ()
	local tag = tags[player]
	if tag then
		tag:Destroy()
		tags[player] = nil
	end
end

local function drawTags(active: boolean, list: { Player }, withMode: boolean): ()
	for player in tags do
		if not active or not table.find(list, player) then
			removeTag(player)
		end
	end
	if not active then
		return
	end
	for _, player in list do
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		-- 내 머리 위 표시는 카메라 바로 앞이라 투표 창을 가린다. 다른 참가자 것만 띄운다.
		if player == localPlayer or not head or not head:IsA("BasePart") then
			removeTag(player)
			continue
		end
		local tag = tags[player]
		if not tag or tag.Adornee ~= head then
			removeTag(player)
			local billboard = Instance.new("BillboardGui")
			billboard.Name = TAG_NAME
			billboard.Adornee = head
			billboard.Size = UDim2.fromScale(7, 1.3) -- 스터드 단위라 멀수록 작아진다
			billboard.StudsOffset = Vector3.new(0, 2.6, 0)
			billboard.MaxDistance = 80
			billboard.LightInfluence = 0
			local frame = UiStyle.panel(billboard, "Back", false)
			frame.Size = UDim2.fromScale(1, 1)
			local label = Instance.new("TextLabel")
			label.Name = "Text"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = UiStyle.BoldFont
			label.TextScaled = true
			label.TextColor3 = Colors.Text
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0.05, 0)
			padding.PaddingRight = UDim.new(0.05, 0)
			padding.PaddingTop = UDim.new(0.12, 0)
			padding.PaddingBottom = UDim.new(0.12, 0)
			padding.Parent = label
			label.Parent = frame
			billboard.Parent = UiStyle.playerGui()
			tags[player] = billboard
			tag = billboard
		end
		local label = (tag :: BillboardGui):FindFirstChild("Text", true)
		if label and label:IsA("TextLabel") then
			label.Text = tagText(player, withMode)
			label.TextColor3 = if MatchState.getVoteMap(player) then GOLD else Colors.Subtext
		end
	end
end

local function draw(): ()
	local ui = view
	if not ui then
		return
	end
	local active = MatchState.getPhase() == "Voting"
	local list = if active then voters() else {}
	local modeCounts = MatchState.getVoteModeCounts()
	drawTags(active and #list > 0, list, modeCounts ~= nil)
	ui.panel.Visible = active and #list > 0
	if not ui.panel.Visible then
		return
	end
	local isVoter = MatchState.isVoter(localPlayer)
	local votedCount = 0
	for _, player in list do
		if MatchState.getVoteMap(player) then
			votedCount += 1
		end
	end
	-- 한 줄: 투표 · n초 남음 · 투표 n/m명 (마지막은 금색)
	local timeText = string.format(Strings.Vote.TimeLeft, MatchState.getTimeLeft() or 0)
	local votedText = string.format(Strings.Vote.Voted, votedCount, #list)
	ui.title.Text = `{Strings.Vote.Title} · {timeText} · <font color="#{GOLD:ToHex()}">{votedText}</font>`
	ui.hint.Text = if isVoter then Strings.Vote.Hint else Strings.Vote.Watching

	ui.modeLabel.Visible = modeCounts ~= nil
	ui.modeRow.Visible = modeCounts ~= nil
	if modeCounts then
		drawGroup(ui.modeOptions, modeCounts, VisualModes.Modes :: { any }, {}, list, function(key: string): string
			return Strings.Modes[key :: Types.VisualMode]
		end)
	end
	drawGroup(
		ui.mapOptions,
		MatchState.getVoteMapCounts(),
		MatchState.getVoteMaps() :: { any },
		MatchState.getVotePlayed() :: { any },
		list,
		function(key: string): string
			return Strings.Stages[key :: Types.StageId]
		end
	)

	-- 추격자 희망 (추격자가 있는 인원일 때만)
	local withChaser = #list >= Match.MinPlayersForChaser
	ui.chaserRow.Visible = withChaser
	if withChaser then
		local wishers: { Player } = {}
		for _, player in list do
			if MatchState.wantsChaser(player) then
				table.insert(wishers, player)
			end
		end
		local mine = MatchState.wantsChaser(localPlayer)
		local option = ui.chaserOption
		drawOption(option, Strings.Vote.WantChaser, #wishers, #list, wishers, {
			enabled = true,
			chosen = mine,
			leader = false,
			interactive = isVoter,
		})
		local check = if mine then "✔ " else ""
		local hintColor = Colors.Subtext:ToHex()
		option.nameLabel.RichText = true
		option.nameLabel.Text =
			`{check}{Strings.Vote.WantChaser}  <font size="13" color="#{hintColor}">{Strings.Vote.WantChaserHint}</font>`
		option.countLabel.Text = string.format(Strings.Vote.Wishers, #wishers)
		option.fill.BackgroundColor3 = CHASER_COLOR
		if not mine then
			option.stroke.Color = CHASER_COLOR
		end
	end
end

--------------------------------------------------------------------------------

local function watchPlayer(player: Player): ()
	for _, name in { Attribute.Voter, Attribute.VoteMap, Attribute.VoteMode, Attribute.WantsChaser } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	player.CharacterAdded:Connect(function()
		task.defer(render)
	end)
end

function VoteController.Init(): ()
	render = draw
end

function VoteController.Start(): ()
	view = createView(Remotes.get("CastVote"))
	for _, name in
		{
			Attribute.Phase,
			Attribute.TimeLeft,
			Attribute.VoteMaps,
			Attribute.VotePlayed,
			Attribute.VoteMapCounts,
			Attribute.VoteModeCounts,
		}
	do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(render)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		watchPlayer(player)
		render()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		removeTag(player)
		task.defer(render)
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	render()
end

return VoteController
