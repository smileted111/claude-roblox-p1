--!strict
-- ShopService: 게임패스·개발자 상품 (GDD 10장, 13.2, 질문지 Q7-3·Q7-4). 상품 ID·코인 수는 Config.Shop.
--
-- VIP 게임패스: 들어올 때 UserOwnsGamePassAsync로 확인하고, 게임 안에서 사면 PromptGamePassPurchaseFinished로
--   바로 켠다. 가진 사람은 Player Attribute Vip (MatchState). 효과는 승패와 상관없는 것만:
--   채팅 이름 색(client Util/ChatStyle), 로비 전용 이모트(LobbyController), 버는 코인 +20%(RecordService).
-- 코인 묶음 (개발자 상품): ProcessReceipt → DataService.processPurchaseAsync가 영수증 PurchaseId로 중복 지급을 막고,
--   영수증 기록이 저장된 것을 확인한 뒤에만 PurchaseGranted. 플레이어가 없거나 데이터를 불러오지 못했거나
--   모르는 상품이거나 저장을 확인하지 못하면 NotProcessedYet (Roblox가 나중에 다시 보낸다).
-- 구매 창은 클라이언트(ShopController)가 MarketplaceService로 직접 띄운다. 추격자 해금은 코인으로만 (ChaserService).
-- 추격자 확률을 높이는 상품은 없다 (GDD 10장).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Types = require(ReplicatedStorage.Shared.Types)
local DataService = require(script.Parent.DataService)

local Attribute = MatchState.Attribute

local ShopService = {}

local function setVip(player: Player, reason: string): ()
	if MatchState.isVip(player) then
		return
	end
	player:SetAttribute(Attribute.Vip, true)
	print(`[Shop] {player.Name} VIP ({reason})`)
end

local function checkVip(player: Player): ()
	if Shop.VipPassId == 0 then
		return
	end
	local ok, owns = pcall(function(): boolean
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Shop.VipPassId)
	end)
	if not ok then
		warn(`[Shop] {player.Name}: VIP 확인 실패: {owns}`)
	elseif owns and player.Parent == Players then
		setVip(player, "보유")
	end
end

local function findProduct(productId: number): Shop.CoinProduct?
	if productId == 0 then
		return nil
	end
	for _, product in Shop.CoinProducts do
		if product.ProductId == productId then
			return product
		end
	end
	return nil
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId
	local purchaseId = receiptInfo.PurchaseId
	if typeof(userId) ~= "number" or typeof(productId) ~= "number" or typeof(purchaseId) ~= "string" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = findProduct(productId)
	if not product then
		warn(`[Shop] 모르는 개발자 상품 {productId} (Config.Shop.CoinProducts에 없음)`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not DataService.waitForData(player, Shop.DataWaitTimeout) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local coins = product.Coins
	local decision, granted = DataService.processPurchaseAsync(player, purchaseId, function(data)
		data.Coins += coins
	end, Shop.ReceiptSaveTimeout)
	if granted then
		print(`[Shop] {player.Name} 코인 묶음 {productId}: 코인 +{coins} (영수증 {purchaseId})`)
		if player.Parent == Players then
			Remotes.get("Notice"):FireClient(player, "CoinsPurchased" :: Types.NoticeKey, coins)
		end
	end
	return decision
end

function ShopService.Init(): () end

function ShopService.Start(): ()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, gamePassId: number, wasPurchased: boolean)
			if wasPurchased and gamePassId == Shop.VipPassId and Shop.VipPassId ~= 0 then
				setVip(player, "구매")
				Remotes.get("Notice"):FireClient(player, "VipActivated" :: Types.NoticeKey)
			end
		end
	)
	Players.PlayerAdded:Connect(checkVip)
	for _, player in Players:GetPlayers() do
		task.spawn(checkVip, player)
	end
end

return ShopService
