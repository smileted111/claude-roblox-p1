--!strict
-- LobbyController: 로비 화면 — 레벨·코인, "추격자 안 하기" 설정, "혼자 시작할까요?" 창 (GDD 2.1, 3장, 5장, 11장).
-- GDD 13.2 목록 밖에 추가한 컨트롤러. 같이 하기·혼자 하기는 로비의 발판(Workspace.Lobby)으로 한다 (LobbyService).
--
-- 로비 패널 (왼쪽 위, 매치에 참가하지 않았을 때): "Lv n · 코인 n" (DataService가 공개한 Player Attribute),
--   "추격자 안 하기: 켬/끔" 버튼 → SetChaserOptOut 리모트 (서버가 저장).
-- 혼자 하기 제안 (SoloOffer 리모트): 같이 하기 구역에 혼자 오래 있으면 뜬다. 답은 LobbyRequest AcceptSolo·DeclineSolo.
-- 다시 하기: 결과 화면 버튼이 LobbyController.playAgain을 부르면 같이 하기 구역으로 옮겨 달라고 요청한다 (JoinQueue).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)

local Colors = UiStyle.Colors
local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

type LobbyView = {
	gui: ScreenGui,
	panel: Frame,
	profileLabel: TextLabel,
	optOutButton: TextButton,
	offer: Frame,
	offerBody: TextLabel,
}

local LobbyController = {}

local view: LobbyView? = nil
local lobbyRemote: RemoteEvent? = nil

local function request(action: Types.LobbyAction): ()
	if lobbyRemote then
		lobbyRemote:FireServer(action)
	end
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
	local optOutButton = UiStyle.button(panel, "ChaserOptOut", 2, UDim2.new(1, 0, 0, 44), true)
	optOutButton.TextSize = 17

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
	row.Size = UDim2.new(1, 0, 0, 52)
	UiStyle.list(row, Enum.FillDirection.Horizontal, 14)
	local yes = UiStyle.button(row, "Yes", 1, UDim2.fromOffset(180, 52), true)
	yes.Text = Strings.Lobby.SoloYes
	local no = UiStyle.button(row, "No", 2, UDim2.fromOffset(180, 52), true)
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
	end
	local level = localPlayer:GetAttribute(Attribute.Level)
	local coins = MatchState.getCoins(localPlayer) or 0
	ui.profileLabel.Text =
		`{string.format(Strings.Lobby.Level, if typeof(level) == "number" then level else 1)} · {string.format(
			Strings.Lobby.Coins,
			coins
		)}`
	local optOut = MatchState.isChaserOptOut(localPlayer)
	ui.optOutButton.Text = `{Strings.Lobby.ChaserOptOut}: {if optOut then Strings.Lobby.On else Strings.Lobby.Off}`
	ui.optOutButton.TextColor3 = if optOut then Colors.Warning else Colors.Text
end

-- 결과 화면의 "다시 하기": 같이 하기 구역으로 옮겨 다음 매치를 기다린다.
function LobbyController.playAgain(): ()
	request("JoinQueue")
end

function LobbyController.Init(): () end

function LobbyController.Start(): ()
	lobbyRemote = Remotes.get("LobbyRequest")
	local optOutRemote = Remotes.get("SetChaserOptOut")
	local ui = createView()
	view = ui
	ui.optOutButton.Activated:Connect(function()
		optOutRemote:FireServer(not MatchState.isChaserOptOut(localPlayer))
	end)
	Remotes.get("SoloOffer").OnClientEvent:Connect(function(waited: unknown)
		local seconds = if typeof(waited) == "number" then waited else 0
		ui.offerBody.Text = string.format(Strings.Lobby.SoloOfferBody, seconds)
		ui.offer.Visible = MatchState.getRole(localPlayer) == nil
	end)
	for _, name in { Attribute.Role, Attribute.Coins, Attribute.Level, Attribute.ChaserOptOut, Attribute.DataLoaded } do
		localPlayer:GetAttributeChangedSignal(name):Connect(render)
	end
	render()
end

return LobbyController
