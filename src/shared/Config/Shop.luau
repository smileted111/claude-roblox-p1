--!strict
-- 상점·게임패스·개발자 상품 (GDD 10장, 질문지 Q7-3~Q7-5). 처리는 server ShopService, 화면은 client ShopController.
-- 상품 ID는 Creator Hub → 이 게임 → 수익화(Monetization)에서 만든 뒤 여기에 넣는다. 0이면 아직 만들지 않은 것이라
-- 상점에 "준비 중"으로 보이고 구매 창을 띄우지 않는다. 가격(Robux)은 Creator Hub에서 정한다 (Q7-5: 출시 직전 결정).
-- 추격자 확률을 높이는 상품은 만들지 않는다 (GDD 10장, Q7-4).

export type CoinProduct = {
	ProductId: number, -- 개발자 상품 ID. 0이면 아직 없음
	Coins: number, -- 지급하는 코인
}

export type ShopConfig = {
	VipPassId: number, -- 게임패스 VIP ID. 0이면 아직 없음
	VipCoinBonus: number, -- VIP가 스테이지·매치에서 버는 코인에 더하는 비율 (0.2 = +20%). 산 코인에는 붙지 않는다
	VipNameColor: Color3, -- 채팅 이름 색 (GDD 10장 "이름 색상")
	CoinProducts: { CoinProduct }, -- 상점에 이 순서로 보인다
	DataWaitTimeout: number, -- 결제 처리 때 데이터를 불러올 때까지 기다리는 시간 (초). 넘으면 NotProcessedYet
	ReceiptSaveTimeout: number, -- 영수증 기록이 DataStore에 저장될 때까지 기다리는 시간 (초). 넘으면 NotProcessedYet
}

local Shop: ShopConfig = {
	VipPassId = 0, -- 사용자 입력 필요
	VipCoinBonus = 0.2,
	VipNameColor = Color3.fromRGB(255, 205, 60), -- 임시
	CoinProducts = {
		{ ProductId = 0, Coins = 100 }, -- 사용자 입력 필요. 코인 수는 임시
		{ ProductId = 0, Coins = 550 }, -- 사용자 입력 필요. 코인 수는 임시
		{ ProductId = 0, Coins = 1200 }, -- 사용자 입력 필요. 코인 수는 임시
	},
	DataWaitTimeout = 15, -- 임시
	ReceiptSaveTimeout = 30, -- 임시
}

return Shop
