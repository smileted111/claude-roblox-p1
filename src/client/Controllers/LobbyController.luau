--!strict
-- LobbyController: 로비 화면 — 레벨·코인, "추격자 안 하기" 설정, "혼자 시작할까요?" 창 (GDD 2.1, 3장, 5장, 11장).
-- GDD 13.2 목록 밖에 추가한 컨트롤러. 같이 하기·혼자 하기는 로비의 발판(Workspace.Lobby)으로 한다 (LobbyService).
--
-- 로비 패널 (왼쪽 위, 매치에 참가하지 않았을 때): "Lv n · 코인 n" (DataService가 공개한 Player Attribute),
--   "추격자 안 하기: 켬/끔" 버튼 → SetChaserOptOut 리모트 (서버가 저장).
-- 추격자 선택 (GDD 7.1, 11장): 로비 패널의 "추격자 선택" 버튼 → 4종 목록(색·이름·스킬 설명·쿨다운).
--   해금한 종류는 [고르기], 잠긴 종류는 [n 코인 해금] → ChaserSelect 리모트 (판정·저장은 서버 ChaserService).
-- 혼자 하기 제안 (SoloOffer 리모트): 같이 하기 구역에 혼자 오래 있으면 뜬다. 답은 LobbyRequest AcceptSolo·DeclineSolo.
-- 상점 (S3-6): 로비 패널의 [상점] 버튼 → ShopController.toggle.
-- VIP 로비 전용 이모트 (GDD 10장): VIP(Player Attribute Vip)에게만 [이모트] 버튼이 보이고, 누르면 내 캐릭터가
--   Config.Assets.Animations.VipEmote를 춘다. 다시 누르거나 움직이면 멈춘다. 매치 중에는 쓸 수 없다.
-- 다시 하기: 결과 화면 버튼이 LobbyController.playAgain을 부르면 같이 하기 구역으로 옮겨 달라고 요청한다 (JoinQueue).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)
local ShopController = require(script.Parent.ShopController)

local Colors = UiStyle.Colors
local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

type ChaserRow = {
	chaserId: Types.ChaserId,
	button: TextButton,
}

type LobbyView = {
	gui: ScreenGui,
	panel: Frame,
	profileLabel: TextLabel,
	optOutButton: TextButton,
	selectButton: TextButton,
	shopButton: TextButton,
	emoteButton: TextButton,
	chaserPanel: Frame,
	chaserRows: { ChaserRow },
	offer: Frame,
	offerBody: TextLabel,
}

-- 목록 순서: 기본 해금 먼저, 그다음 해금 가격순
local CHASER_ORDER: { Types.ChaserId } = { "Hunter", "Tracker", "Wraith", "Puppeteer" }

local LobbyController = {}

local view: LobbyView? = nil
local lobbyRemote: RemoteEvent? = nil
local emoteAnimation: Animation? = nil
local emoteTrack: AnimationTrack? = nil
local emoteAnimator: Animator? = nil
local emoteMoveConnection: RBXScriptConnection? = nil

local function request(action: Types.LobbyAction): ()
	if lobbyRemote then
		lobbyRemote:FireServer(action)
	end
end

local function skillDescription(chaserId: Types.ChaserId): string
	local skill = Chasers[chaserId].Skill
	local template = Strings.SkillDescriptions[skill.Kind]
	local text: string
	if skill.Kind == "Dash" then
		text = string.format(template, skill.Duration or 0, math.round(((skill.SpeedMultiplier or 1) - 1) * 100))
	elseif skill.Kind == "RevealFootprints" then
		text = string.format(template, skill.Duration or 0)
	elseif skill.Kind == "Blink" then
		text = string.format(template, skill.Distance or 0)
	else
		text = string.format(template, skill.MonsterCount or 0)
	end
	return `{Strings.Skills[skill.Kind]}: {text} · {string.format(Strings.Lobby.Cooldown, skill.Cooldown)}`
end

local function createChaserPanel(gui: ScreenGui): (Frame, { ChaserRow })
	local panel = UiStyle.panel(gui, "ChaserSelect", true)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(600, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	UiStyle.padding(panel, 14, 18)
	UiStyle.list(panel, Enum.FillDirection.Vertical, 8)
	local title = UiStyle.label(panel, "Title", 0, 30)
	title.Font = UiStyle.BoldFont
	title.TextColor3 = Colors.Accent
	title.Text = Strings.Lobby.ChaserSelect

	local rows: { ChaserRow } = {}
	for index, chaserId in CHASER_ORDER do
		local row = UiStyle.container(panel, chaserId)
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, 60)
		local layout = UiStyle.list(row, Enum.FillDirection.Horizontal, 10)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local swatch = Instance.new("Frame")
		swatch.Name = "Color"
		swatch.LayoutOrder = 1
		swatch.Size = UDim2.fromOffset(14, 52)
		swatch.BackgroundColor3 = Chasers[chaserId].Color
		swatch.BorderSizePixel = 0
		UiStyle.corner(swatch, 4)
		swatch.Parent = row
		local info = UiStyle.container(row, "Info")
		info.LayoutOrder = 2
		info.Size = UDim2.fromOffset(370, 60)
		UiStyle.list(info, Enum.FillDirection.Vertical, 2)
		local name = UiStyle.label(info, "Name", 1, 26)
		name.Font = UiStyle.BoldFont
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = Strings.Chasers[chaserId]
		local desc = UiStyle.label(info, "Skill", 2, 30)
		desc.TextSize = 14
		desc.TextWrapped = true
		desc.TextTruncate = Enum.TextTruncate.None
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextColor3 = Colors.Subtext
		desc.Text = skillDescription(chaserId)
		local button = UiStyle.button(row, "Action", 3, UDim2.fromOffset(150, UiStyle.MinButtonHeight), true)
		button.TextSize = 16
		table.insert(rows, { chaserId = chaserId, button = button })
	end
	local close = UiStyle.button(panel, "Close", 10, UDim2.fromOffset(160, UiStyle.MinButtonHeight), true)
	close.Text = Strings.Lobby.Close
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	return panel, rows
end

local function createView(): LobbyView
	local gui = UiStyle.screenGui("Lobby", 6)
	UiStyle.addScale(gui)

	-- 왼쪽 위: 레벨·코인·설정
	local panel = UiStyle.panel(gui, "Profile", false)
	panel.Position = UDim2.fromOffset(12, 8)
	panel.Size = UDim2.fromOffset(240, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UiStyle.padding(panel, 8, 12)
	UiStyle.list(panel, Enum.FillDirection.Vertical, 6)
	local profileLabel = UiStyle.label(panel, "Profile", 1, 26)
	profileLabel.Font = UiStyle.BoldFont
	profileLabel.TextXAlignment = Enum.TextXAlignment.Left
	local optOutButton = UiStyle.button(panel, "ChaserOptOut", 2, UDim2.new(1, 0, 0, UiStyle.MinButtonHeight), true)
	optOutButton.TextSize = 17
	local selectButton = UiStyle.button(panel, "ChaserSelect", 3, UDim2.new(1, 0, 0, UiStyle.MinButtonHeight), true)
	selectButton.TextSize = 17
	-- 상점 · (VIP) 이모트
	local shopRow = UiStyle.container(panel, "ShopRow")
	shopRow.LayoutOrder = 4
	shopRow.Size = UDim2.new(1, 0, 0, UiStyle.MinButtonHeight)
	UiStyle.list(shopRow, Enum.FillDirection.Horizontal, 8)
	local shopButton = UiStyle.button(shopRow, "Shop", 1, UDim2.fromScale(1, 1), true)
	shopButton.TextSize = 17
	shopButton.Text = Strings.Lobby.Shop
	local emoteButton = UiStyle.button(shopRow, "Emote", 2, UDim2.new(0.5, -4, 1, 0), true)
	emoteButton.TextSize = 17
	emoteButton.Text = Strings.Lobby.Emote
	emoteButton.TextColor3 = Colors.Warning
	emoteButton.Visible = false
	local chaserPanel, chaserRows = createChaserPanel(gui)

	-- 가운데: 혼자 하기 제안
	local offer = UiStyle.panel(gui, "SoloOffer", true)
	offer.AnchorPoint = Vector2.new(0.5, 0.5)
	offer.Position = UDim2.fromScale(0.5, 0.5)
	offer.Size = UDim2.fromOffset(460, 0)
	offer.AutomaticSize = Enum.AutomaticSize.Y
	offer.Visible = false
	UiStyle.padding(offer, 16, 20)
	UiStyle.list(offer, Enum.FillDirection.Vertical, 10)
	local title = UiStyle.label(offer, "Title", 1, 32)
	title.Font = UiStyle.BoldFont
	title.TextColor3 = Colors.Accent
	title.Text = Strings.Lobby.SoloOfferTitle
	local body = UiStyle.label(offer, "Body", 2, 22)
	body.TextWrapped = true
	body.TextTruncate = Enum.TextTruncate.None
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.TextColor3 = Colors.Subtext
	local row = UiStyle.container(offer, "Buttons")
	row.LayoutOrder = 3
	row.Size = UDim2.new(1, 0, 0, UiStyle.MinButtonHeight)
	UiStyle.list(row, Enum.FillDirection.Horizontal, 14)
	local yes = UiStyle.button(row, "Yes", 1, UDim2.fromOffset(180, UiStyle.MinButtonHeight), true)
	yes.Text = Strings.Lobby.SoloYes
	local no = UiStyle.button(row, "No", 2, UDim2.fromOffset(180, UiStyle.MinButtonHeight), true)
	no.Text = Strings.Lobby.SoloNo
	yes.Activated:Connect(function()
		offer.Visible = false
		request("AcceptSolo")
	end)
	no.Activated:Connect(function()
		offer.Visible = false
		request("DeclineSolo")
	end)

	gui.Parent = UiStyle.playerGui()
	return {
		gui = gui,
		panel = panel,
		profileLabel = profileLabel,
		optOutButton = optOutButton,
		selectButton = selectButton,
		shopButton = shopButton,
		emoteButton = emoteButton,
		chaserPanel = chaserPanel,
		chaserRows = chaserRows,
		offer = offer,
		offerBody = body,
	}
end

local function render(): ()
	local ui = view
	if not ui then
		return
	end
	local inLobby = MatchState.getRole(localPlayer) == nil
	ui.panel.Visible = inLobby and localPlayer:GetAttribute(Attribute.DataLoaded) == true
	if not inLobby then
		ui.offer.Visible = false
		ui.chaserPanel.Visible = false
	end
	local level = localPlayer:GetAttribute(Attribute.Level)
	local coins = MatchState.getCoins(localPlayer) or 0
	ui.profileLabel.Text =
		`{string.format(Strings.Lobby.Level, if typeof(level) == "number" then level else 1)} · {string.format(
			Strings.Lobby.Coins,
			coins
		)}`
	local vip = MatchState.isVip(localPlayer)
	ui.emoteButton.Visible = vip
	ui.shopButton.Size = if vip then UDim2.new(0.5, -4, 1, 0) else UDim2.fromScale(1, 1)

	local optOut = MatchState.isChaserOptOut(localPlayer)
	ui.optOutButton.Text = `{Strings.Lobby.ChaserOptOut}: {if optOut then Strings.Lobby.On else Strings.Lobby.Off}`
	ui.optOutButton.TextColor3 = if optOut then Colors.Warning else Colors.Text

	local selected: Types.ChaserId = MatchState.getSelectedChaser(localPlayer) or "Hunter"
	ui.selectButton.Text = `{Strings.Lobby.ChaserSelect}: {Strings.Chasers[selected]}`
	for _, row in ui.chaserRows do
		local unlocked = MatchState.isChaserUnlocked(localPlayer, row.chaserId)
		local isSelected = row.chaserId == selected
		row.button.Text = if isSelected
			then Strings.Lobby.Selected
			elseif unlocked then Strings.Lobby.Select
			else string.format(Strings.Lobby.UnlockCost, Chasers[row.chaserId].UnlockCost)
		row.button.TextColor3 = if isSelected
			then Colors.Good
			elseif unlocked then Colors.Text
			elseif coins >= Chasers[row.chaserId].UnlockCost then Colors.Warning
			else Colors.Disabled
	end
end

local function stopEmote(): ()
	if emoteMoveConnection then
		emoteMoveConnection:Disconnect()
		emoteMoveConnection = nil
	end
	local track = emoteTrack
	if track and track.IsPlaying then
		track:Stop(0.2)
	end
end

-- VIP 로비 이모트를 추거나(다시 누르면) 멈춘다.
local function toggleEmote(): ()
	if emoteTrack and emoteTrack.IsPlaying then
		stopEmote()
		return
	end
	local animation = emoteAnimation
	if not MatchState.isVip(localPlayer) or MatchState.getRole(localPlayer) ~= nil or not animation then
		return
	end
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator then
		return
	end
	if emoteAnimator ~= animator then
		emoteAnimator = animator
		local loaded = animator:LoadAnimation(animation)
		loaded.Priority = Enum.AnimationPriority.Action
		loaded.Looped = true
		emoteTrack = loaded
	end
	local track = emoteTrack
	if track then
		track:Play(0.2)
		emoteMoveConnection = humanoid.Running:Connect(function(speed: number)
			if speed > 0.5 then
				stopEmote()
			end
		end)
	end
end

-- 결과 화면의 "다시 하기": 같이 하기 구역으로 옮겨 다음 매치를 기다린다.
function LobbyController.playAgain(): ()
	request("JoinQueue")
end

function LobbyController.Init(): ()
	local animation = Instance.new("Animation")
	animation.Name = "VipEmote"
	animation.AnimationId = Assets.Animations.VipEmote
	emoteAnimation = animation
end

function LobbyController.Start(): ()
	lobbyRemote = Remotes.get("LobbyRequest")
	local optOutRemote = Remotes.get("SetChaserOptOut")
	local ui = createView()
	view = ui
	ui.optOutButton.Activated:Connect(function()
		optOutRemote:FireServer(not MatchState.isChaserOptOut(localPlayer))
	end)
	local selectRemote = Remotes.get("ChaserSelect")
	ui.selectButton.Activated:Connect(function()
		ui.chaserPanel.Visible = not ui.chaserPanel.Visible
	end)
	ui.shopButton.Activated:Connect(ShopController.toggle)
	ui.emoteButton.Activated:Connect(toggleEmote)
	localPlayer:GetAttributeChangedSignal(Attribute.Role):Connect(stopEmote)
	for _, row in ui.chaserRows do
		row.button.Activated:Connect(function()
			local action: Types.ChaserSelectAction = if MatchState.isChaserUnlocked(localPlayer, row.chaserId)
				then "Select"
				else "Unlock"
			selectRemote:FireServer(action, row.chaserId)
		end)
	end
	Remotes.get("SoloOffer").OnClientEvent:Connect(function(waited: unknown)
		local seconds = if typeof(waited) == "number" then waited else 0
		ui.offerBody.Text = string.format(Strings.Lobby.SoloOfferBody, seconds)
		ui.offer.Visible = MatchState.getRole(localPlayer) == nil
	end)
	for _, name in
		{
			Attribute.Role,
			Attribute.Coins,
			Attribute.Level,
			Attribute.ChaserOptOut,
			Attribute.DataLoaded,
			Attribute.SelectedChaser,
			Attribute.UnlockedChasers,
			Attribute.Vip,
		}
	do
		localPlayer:GetAttributeChangedSignal(name):Connect(render)
	end
	render()
end

return LobbyController
