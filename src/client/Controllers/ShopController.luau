--!strict
-- ShopController: 로비 상점 화면과 VIP 채팅 이름 색 (GDD 10장, 11장). GDD 13.2 목록 밖에 추가한 컨트롤러.
--
-- 상점 (LobbyController의 [상점] 버튼, 매치에 참가하지 않았을 때만):
--   왼쪽  VIP 게임패스(효과 설명, 구매 / 보유 중), 코인 묶음 (Config.Shop.CoinProducts)
--   오른쪽 추격자 해금 (코인으로 여는 종류, ChaserSelect 리모트 Unlock → 서버 ChaserService), 꾸미기 (자리만)
--   가격은 MarketplaceService:GetProductInfo로 받아 보여주고, 누르면 PromptGamePassPurchase·PromptProductPurchase로
--   Roblox 구매 창을 띄운다. 지급과 확인은 서버(ShopService)가 하고, 코인·VIP는 Player Attribute로 돌아온다.
--   상품 ID가 0(Config.Shop, 아직 만들지 않음)이면 "준비 중"으로 누를 수 없다.
-- VIP 채팅 이름 색: Util/ChatStyle에 꾸밈 함수를 더한다 (Player Attribute Vip인 사람 이름 앞에 [VIP], 색).
-- 추격자 확률을 높이는 상품은 없다 (GDD 10장).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local ChatStyle = require(script.Parent.Parent.Util.ChatStyle)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)

local Colors = UiStyle.Colors
local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local COLUMN_WIDTH = 350
local SECTION_TITLE_HEIGHT = 28

type ChaserRow = {
	chaserId: Types.ChaserId,
	button: TextButton,
}

type ShopView = {
	gui: ScreenGui,
	panel: Frame,
	coinsLabel: TextLabel,
	vipButton: TextButton,
	coinButtons: { TextButton },
	chaserRows: { ChaserRow },
}

local ShopController = {}

local view: ShopView? = nil
local prices: { [string]: number } = {} -- "Pass:<id>" / "Product:<id>" → Robux
local pricesRequested = false

-- 코인으로 해금하는 추격자 (해금 가격순)
local function coinChasers(): { Types.ChaserId }
	local list: { Types.ChaserId } = {}
	for chaserId, def in Chasers do
		if def.Unlock == "Coins" then
			table.insert(list, chaserId)
		end
	end
	table.sort(list, function(a: Types.ChaserId, b: Types.ChaserId): boolean
		return Chasers[a].UnlockCost < Chasers[b].UnlockCost
	end)
	return list
end

local function setEnabled(button: TextButton, enabled: boolean, color: Color3?): ()
	button.AutoButtonColor = enabled
	button.TextColor3 = color or (if enabled then Colors.Text else Colors.Disabled)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if enabled then Colors.Accent else Colors.Disabled
	end
end

local function sectionTitle(parent: Instance, text: string, order: number): TextLabel
	local label = UiStyle.label(parent, "Title", order, SECTION_TITLE_HEIGHT)
	label.Font = UiStyle.BoldFont
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Colors.Accent
	label.Text = text
	return label
end

local function column(parent: Instance, name: string, order: number): Frame
	local frame = UiStyle.container(parent, name)
	frame.LayoutOrder = order
	frame.Size = UDim2.fromOffset(COLUMN_WIDTH, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	local layout = UiStyle.list(frame, Enum.FillDirection.Vertical, 6)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	return frame
end

local function createView(): ShopView
	local gui = UiStyle.screenGui("Shop", 7)
	UiStyle.addScale(gui)

	local panel = UiStyle.panel(gui, "Shop", true)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(COLUMN_WIDTH * 2 + 24 + 36, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	UiStyle.padding(panel, 14, 18)
	UiStyle.list(panel, Enum.FillDirection.Vertical, 10)

	-- 제목과 가진 코인
	local header = UiStyle.container(panel, "Header")
	header.LayoutOrder = 1
	header.Size = UDim2.new(1, 0, 0, 34)
	local title = UiStyle.label(header, "Title", 0, 34)
	title.Font = UiStyle.BoldFont
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Colors.Accent
	title.Text = Strings.Shop.Title
	local coinsLabel = UiStyle.label(header, "Coins", 0, 34)
	coinsLabel.Font = UiStyle.BoldFont
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.TextColor3 = Colors.Warning

	local body = UiStyle.container(panel, "Body")
	body.LayoutOrder = 2
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	local bodyLayout = UiStyle.list(body, Enum.FillDirection.Horizontal, 24)
	bodyLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	-- 왼쪽: VIP, 코인 묶음
	local left = column(body, "Left", 1)
	sectionTitle(left, Strings.Shop.Vip, 1)
	local perks = UiStyle.label(left, "Perks", 2, 22)
	perks.TextSize = 16
	perks.TextWrapped = true
	perks.TextTruncate = Enum.TextTruncate.None
	perks.AutomaticSize = Enum.AutomaticSize.Y
	perks.TextXAlignment = Enum.TextXAlignment.Left
	perks.TextColor3 = Colors.Subtext
	perks.Text = Strings.Shop.VipPerks
	local vipButton = UiStyle.button(left, "Vip", 3, UDim2.new(1, 0, 0, UiStyle.MinButtonHeight), true)
	vipButton.TextSize = 18

	sectionTitle(left, Strings.Shop.CoinsSection, 4)
	local coinRow = UiStyle.container(left, "CoinProducts")
	coinRow.LayoutOrder = 5
	coinRow.Size = UDim2.new(1, 0, 0, UiStyle.MinButtonHeight + 8)
	UiStyle.list(coinRow, Enum.FillDirection.Horizontal, 8)
	local coinButtons: { TextButton } = {}
	local count = #Shop.CoinProducts
	for index = 1, count do
		local width = math.floor((COLUMN_WIDTH - 8 * (count - 1)) / count)
		local button =
			UiStyle.button(coinRow, `Coins{index}`, index, UDim2.fromOffset(width, UiStyle.MinButtonHeight + 8), true)
		button.TextSize = 15
		button.TextWrapped = true
		table.insert(coinButtons, button)
	end

	-- 오른쪽: 추격자 해금, 꾸미기
	local right = column(body, "Right", 2)
	sectionTitle(right, Strings.Shop.ChasersSection, 1)
	local chaserRows: { ChaserRow } = {}
	for index, chaserId in coinChasers() do
		local row = UiStyle.container(right, chaserId)
		row.LayoutOrder = 1 + index
		row.Size = UDim2.new(1, 0, 0, UiStyle.MinButtonHeight)
		local layout = UiStyle.list(row, Enum.FillDirection.Horizontal, 8)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local swatch = Instance.new("Frame")
		swatch.Name = "Color"
		swatch.LayoutOrder = 1
		swatch.Size = UDim2.fromOffset(10, 40)
		swatch.BackgroundColor3 = Chasers[chaserId].Color
		swatch.BorderSizePixel = 0
		UiStyle.corner(swatch, 3)
		swatch.Parent = row
		local name = UiStyle.label(row, "Name", 2, 26)
		name.Size = UDim2.fromOffset(COLUMN_WIDTH - 10 - 150 - 16, 26)
		name.Font = UiStyle.BoldFont
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = Strings.Chasers[chaserId]
		local button = UiStyle.button(row, "Unlock", 3, UDim2.fromOffset(150, UiStyle.MinButtonHeight), true)
		button.TextSize = 16
		table.insert(chaserRows, { chaserId = chaserId, button = button })
	end
	sectionTitle(right, Strings.Shop.CosmeticsSection, 20)
	local cosmetics = UiStyle.label(right, "CosmeticsSoon", 21, 22)
	cosmetics.TextSize = 16
	cosmetics.TextWrapped = true
	cosmetics.TextTruncate = Enum.TextTruncate.None
	cosmetics.AutomaticSize = Enum.AutomaticSize.Y
	cosmetics.TextXAlignment = Enum.TextXAlignment.Left
	cosmetics.TextColor3 = Colors.Subtext
	cosmetics.Text = Strings.Shop.CosmeticsSoon

	local close = UiStyle.button(panel, "Close", 3, UDim2.fromOffset(160, UiStyle.MinButtonHeight), true)
	close.Text = Strings.Lobby.Close
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	gui.Parent = UiStyle.playerGui()
	return {
		gui = gui,
		panel = panel,
		coinsLabel = coinsLabel,
		vipButton = vipButton,
		coinButtons = coinButtons,
		chaserRows = chaserRows,
	}
end

local function priceText(key: string): string
	local price = prices[key]
	return if price then string.format(Strings.Shop.Robux, price) else Strings.Shop.Buy
end

local function render(): ()
	local ui = view
	if not ui then
		return
	end
	if MatchState.getRole(localPlayer) ~= nil then
		ui.panel.Visible = false
	end
	local coins = MatchState.getCoins(localPlayer) or 0
	ui.coinsLabel.Text = string.format(Strings.Lobby.Coins, coins)

	if MatchState.isVip(localPlayer) then
		ui.vipButton.Text = Strings.Shop.Owned
		setEnabled(ui.vipButton, false, Colors.Good)
	elseif Shop.VipPassId == 0 then
		ui.vipButton.Text = Strings.Shop.NotReady
		setEnabled(ui.vipButton, false)
	else
		ui.vipButton.Text = `{Strings.Shop.Vip} {priceText(`Pass:{Shop.VipPassId}`)}`
		setEnabled(ui.vipButton, true)
	end

	for index, button in ui.coinButtons do
		local product = Shop.CoinProducts[index]
		local name = string.format(Strings.Shop.CoinPack, product.Coins)
		if product.ProductId == 0 then
			button.Text = `{name}\n{Strings.Shop.NotReady}`
			setEnabled(button, false)
		else
			button.Text = `{name}\n{priceText(`Product:{product.ProductId}`)}`
			setEnabled(button, true)
		end
	end

	for _, row in ui.chaserRows do
		local cost = Chasers[row.chaserId].UnlockCost
		if MatchState.isChaserUnlocked(localPlayer, row.chaserId) then
			row.button.Text = Strings.Shop.Owned
			setEnabled(row.button, false, Colors.Good)
		else
			row.button.Text = string.format(Strings.Shop.Unlock, cost)
			setEnabled(row.button, true, if coins >= cost then Colors.Warning else Colors.Disabled)
		end
	end
end

-- 상품 가격을 한 번만 받아 온다 (실패하면 "구매"로 둔다).
local function requestPrices(): ()
	if pricesRequested then
		return
	end
	pricesRequested = true
	local requests: { { key: string, id: number, infoType: Enum.InfoType } } = {}
	if Shop.VipPassId ~= 0 then
		table.insert(
			requests,
			{ key = `Pass:{Shop.VipPassId}`, id = Shop.VipPassId, infoType = Enum.InfoType.GamePass }
		)
	end
	for _, product in Shop.CoinProducts do
		if product.ProductId ~= 0 then
			table.insert(
				requests,
				{ key = `Product:{product.ProductId}`, id = product.ProductId, infoType = Enum.InfoType.Product }
			)
		end
	end
	for _, request in requests do
		task.spawn(function()
			local ok, info = pcall(function(): any
				return MarketplaceService:GetProductInfoAsync(request.id, request.infoType)
			end)
			if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
				prices[request.key] = info.PriceInRobux
				render()
			elseif not ok then
				warn(`[Shop] 가격을 받지 못함 ({request.key}): {info}`)
			end
		end)
	end
end

-- 상점을 열거나 닫는다 (LobbyController의 [상점] 버튼). 매치 중에는 열지 않는다.
function ShopController.toggle(): ()
	local ui = view
	if not ui then
		return
	end
	if ui.panel.Visible or MatchState.getRole(localPlayer) ~= nil then
		ui.panel.Visible = false
		return
	end
	requestPrices()
	render()
	ui.panel.Visible = true
end

function ShopController.Init(): () end

function ShopController.Start(): ()
	local ui = createView()
	view = ui

	ui.vipButton.Activated:Connect(function()
		if Shop.VipPassId ~= 0 and not MatchState.isVip(localPlayer) then
			MarketplaceService:PromptGamePassPurchase(localPlayer, Shop.VipPassId)
		end
	end)
	for index, button in ui.coinButtons do
		button.Activated:Connect(function()
			local productId = Shop.CoinProducts[index].ProductId
			if productId ~= 0 then
				MarketplaceService:PromptProductPurchase(localPlayer, productId)
			end
		end)
	end
	local selectRemote = Remotes.get("ChaserSelect")
	for _, row in ui.chaserRows do
		row.button.Activated:Connect(function()
			if not MatchState.isChaserUnlocked(localPlayer, row.chaserId) then
				selectRemote:FireServer("Unlock" :: Types.ChaserSelectAction, row.chaserId)
			end
		end)
	end

	for _, name in { Attribute.Role, Attribute.Coins, Attribute.Vip, Attribute.UnlockedChasers } do
		localPlayer:GetAttributeChangedSignal(name):Connect(render)
	end

	-- VIP 채팅 이름: [VIP] 이름 (색)
	local color = Shop.VipNameColor:ToHex()
	ChatStyle.addPrefixer(function(message: TextChatMessage, prefix: string): string
		local source = message.TextSource
		local sender = if source then Players:GetPlayerByUserId(source.UserId) else nil
		if sender and MatchState.isVip(sender) and prefix ~= "" then
			return `<font color="#{color}">[{Strings.Shop.VipTag}] {prefix}</font>`
		end
		return prefix
	end)
	render()
end

return ShopController
