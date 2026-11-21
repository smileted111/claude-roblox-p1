--!strict
-- DataService: 플레이어 데이터 저장 (GDD 9장, 13.3, 질문지 Q7-1). ProfileStore(Wally lm-loleris/profilestore)를 쓴다.
--
-- 세션: 들어오면 ProfileStore:StartSessionAsync로 세션 잠금을 걸고 불러온다 (다른 서버가 쓰는 중이면 넘겨받음).
--   빠진 값은 템플릿으로 채우고(Reconcile) Version이 낮으면 옮긴다(migrate). 자동 저장(ProfileStore 기본 300초),
--   나가면 EndSession으로 저장하고 잠금을 푼다. 서버가 닫힐 때도 ProfileStore가 저장한다.
--   다른 서버가 세션을 가져가면(OnSessionEnd) 그 플레이어를 내보낸다.
-- 저장소 이름: 게시된 게임은 Config.Data.StoreName, Studio는 StudioStoreName (테스트 데이터가 섞이지 않게).
--   Studio에서 API 접근이 꺼져 있으면 ProfileStore가 저장하지 않는 임시 저장소로 동작한다 (출력 창에 경고).
-- 저장 항목: 코인, 레벨·경험치, 해금한 추격자·고른 추격자, 꾸미기(가진 것·착용), 퀘스트 진행(자리), 통계
--   (생존 스테이지·잡은 수·탈출 수·라스트 서바이버 횟수·매치·스테이지 수), 설정(추격자 안 하기), 처리한 영수증(S3-6), Version.
--   매치 진행 상황은 저장하지 않는다 (GDD 13.3).
-- 보상 지급: 스테이지가 끝나면 grantStage(코인·경험치·통계), 매치가 끝나면 grantMatch(칭호 보너스·라스트 서바이버 횟수).
--   중간에 나가도 그때까지 받은 것은 남는다 (GDD 8장).
-- 공개: Player Attribute Coins·Level·Xp·DataLoaded (MatchState), 추격자 안 하기는 ChaserOptOut.
-- 개발자 상품 (S3-6, processPurchaseAsync): 처음 보는 영수증 PurchaseId면 지급하고 Receipts에 적는다. 그 기록이
--   DataStore에 실제로 저장된 것(Profile.LastSavedData)을 확인한 뒤에만 PurchaseGranted를 돌려준다. 저장 전에
--   서버가 꺼지면 NotProcessedYet → Roblox가 나중에 다시 보내고, 이미 적힌 영수증이면 다시 지급하지 않는다.
-- 리더보드(누적 생존 스테이지·잡은 수, OrderedDataStore)는 자리만 있다 (Config.Data.Leaderboards.Enabled = false).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local Data = require(ReplicatedStorage.Shared.Config.Data)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Score = require(ReplicatedStorage.Shared.Config.Score)
local Types = require(ReplicatedStorage.Shared.Types)
local VisualModes = require(ReplicatedStorage.Shared.Config.VisualModes)
local LanguageService = require(script.Parent.LanguageService)
-- Wally 래퍼 모듈이 ProfileStore의 타입을 다시 내보내지 않아 여기서 쓰는 부분만 타입으로 적는다.
local ProfileStore: any = require(ServerScriptService.ServerPackages.ProfileStore)

export type Stats = {
	SurvivedStages: number, -- 생존 + 탈출한 스테이지 (리더보드)
	Escapes: number,
	Catches: number, -- 추격자로 잡은 수 (리더보드)
	LastSurvivors: number, -- 라스트 서바이버가 된 횟수
	StagesPlayed: number,
	MatchesPlayed: number,
}

export type PlayerData = {
	Version: number,
	Coins: number,
	Level: number,
	Xp: number,
	UnlockedChasers: { [string]: boolean }, -- ChaserId → true
	SelectedChaser: string, -- ChaserId
	Cosmetics: { Owned: { [string]: boolean }, Equipped: { [string]: string } }, -- 자리 (GDD 10장 꾸미기)
	Quests: { Daily: { [string]: number }, Weekly: { [string]: number }, DailyResetAt: number, WeeklyResetAt: number }, -- 자리
	Stats: Stats,
	Settings: { ChaserOptOut: boolean, VisualMode: string }, -- VisualMode: Types.VisualMode (로비에서 고른 화면 모드)
	Receipts: { string }, -- 처리한 개발자 상품 영수증 PurchaseId (S3-6, 최근 MaxReceipts개)
}

type Signal = { Connect: (self: any, listener: (...any) -> ()) -> any }

type Profile = {
	Data: any,
	LastSavedData: any, -- DataStore에 마지막으로 저장된 Data (결제 확인용)
	OnSessionEnd: Signal,
	IsActive: (self: Profile) -> boolean,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	Save: (self: Profile) -> (),
}

local Attribute = MatchState.Attribute

local DataService = {}

local function defaultUnlocked(): { [string]: boolean }
	local unlocked: { [string]: boolean } = {}
	for chaserId, def in Chasers do
		if def.Unlock == "Default" then
			unlocked[chaserId] = true
		end
	end
	return unlocked
end

local TEMPLATE: PlayerData = {
	Version = Data.Version,
	Coins = 0,
	Level = 1,
	Xp = 0,
	UnlockedChasers = defaultUnlocked(),
	SelectedChaser = Match.DefaultChaser,
	Cosmetics = { Owned = {}, Equipped = {} },
	Quests = { Daily = {}, Weekly = {}, DailyResetAt = 0, WeeklyResetAt = 0 },
	Stats = {
		SurvivedStages = 0,
		Escapes = 0,
		Catches = 0,
		LastSurvivors = 0,
		StagesPlayed = 0,
		MatchesPlayed = 0,
	},
	Settings = { ChaserOptOut = false, VisualMode = VisualModes.Default },
	Receipts = {},
}

local storeName = if RunService:IsStudio() then Data.StudioStoreName else Data.StoreName
local store = ProfileStore.New(storeName, TEMPLATE :: any)
local profiles: { [Player]: Profile } = {}
local loadedEvent = Instance.new("BindableEvent")

local function xpForNextLevel(level: number): number
	return Data.LevelBaseXp + (level - 1) * Data.LevelXpStep
end

local function publish(player: Player, data: PlayerData): ()
	player:SetAttribute(Attribute.Coins, data.Coins)
	player:SetAttribute(Attribute.Level, data.Level)
	player:SetAttribute(Attribute.Xp, data.Xp)
	local unlocked: { string } = {}
	for chaserId in data.UnlockedChasers do
		table.insert(unlocked, chaserId)
	end
	table.sort(unlocked)
	player:SetAttribute(Attribute.UnlockedChasers, table.concat(unlocked, ","))
	player:SetAttribute(Attribute.SelectedChaser, data.SelectedChaser)
end

-- 저장 형식이 바뀌면 여기서 옮긴다. 지금은 버전 1뿐이다.
local function migrate(data: PlayerData): ()
	if data.Version < Data.Version then
		data.Version = Data.Version
	end
	-- 기본 해금 추격자가 늘었으면 채워 주고, 고른 추격자가 없어졌거나 잠겨 있으면 기본으로 되돌린다.
	for chaserId in defaultUnlocked() do
		data.UnlockedChasers[chaserId] = true
	end
	if not Chasers[data.SelectedChaser :: any] or not data.UnlockedChasers[data.SelectedChaser] then
		data.SelectedChaser = Match.DefaultChaser
	end
	-- 화면 모드는 S3 이후에 생겼다 (Reconcile이 채움). 모르는 값이면 기본으로.
	if not table.find(VisualModes.Modes, data.Settings.VisualMode :: any) then
		data.Settings.VisualMode = VisualModes.Default
	end
end

local function loadProfile(player: Player): ()
	local key = `{Data.KeyPrefix}{player.UserId}`
	local params: any = {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	}
	local profile: Profile? = store:StartSessionAsync(key, params)
	if not profile then
		-- 나갔거나 서버가 닫히는 중이거나 불러오지 못함
		if player.Parent == Players then
			warn(`[Data] {player.Name}: 데이터를 불러오지 못했습니다`)
			player:Kick(LanguageService.stringsFor(player).System.DataLoadFailed)
		end
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick(LanguageService.stringsFor(player).System.DataSessionTaken)
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	local data = profile.Data :: PlayerData
	migrate(data)
	profiles[player] = profile
	publish(player, data)
	player:SetAttribute(Attribute.ChaserOptOut, if data.Settings.ChaserOptOut then true else nil)
	player:SetAttribute(Attribute.VisualMode, data.Settings.VisualMode)
	player:SetAttribute(Attribute.DataLoaded, true)
	print(
		`[Data] {player.Name} 불러옴 ({storeName}, {ProfileStore.DataStoreState}): 코인 {data.Coins}, 레벨 {data.Level}`
	)
	loadedEvent:Fire(player)
end

local function addXp(data: PlayerData, amount: number): ()
	data.Xp += math.max(0, math.floor(amount))
	while data.Xp >= xpForNextLevel(data.Level) do
		data.Xp -= xpForNextLevel(data.Level)
		data.Level += 1
	end
end

local function updateLeaderboards(player: Player, data: PlayerData): ()
	local config = Data.Leaderboards
	if not config.Enabled or ProfileStore.DataStoreState ~= "Access" then
		return
	end
	task.spawn(function()
		for name, value in
			{ [config.SurvivedStages] = data.Stats.SurvivedStages, [config.Catches] = data.Stats.Catches }
		do
			local ok, err = pcall(function()
				DataStoreService:GetOrderedDataStore(name):SetAsync(tostring(player.UserId), value)
			end)
			if not ok then
				warn(`[Data] 리더보드 {name} 저장 실패: {err}`)
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- 다른 서비스용

-- 불러온 데이터 (읽기용). 아직 불러오지 않았으면 nil. 바꿀 때는 아래 함수를 쓴다.
function DataService.getData(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data :: PlayerData else nil
end

-- 데이터를 불러올 때까지 기다린다 (최대 timeout초). 불러오지 못하면 nil.
function DataService.waitForData(player: Player, timeout: number): PlayerData?
	local deadline = os.clock() + timeout
	while not profiles[player] and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.getData(player)
end

function DataService.addCoins(player: Player, amount: number, reason: string): boolean
	local data = DataService.getData(player)
	if not data or amount <= 0 then
		return false
	end
	data.Coins += math.floor(amount)
	publish(player, data)
	print(`[Data] {player.Name} 코인 +{math.floor(amount)} ({reason}) → {data.Coins}`)
	return true
end

-- 코인이 충분하면 쓰고 true
function DataService.spendCoins(player: Player, amount: number, reason: string): boolean
	local data = DataService.getData(player)
	if not data or amount < 0 or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	publish(player, data)
	print(`[Data] {player.Name} 코인 -{amount} ({reason}) → {data.Coins}`)
	return true
end

-- 추격자 종류를 해금한다 (코인은 부르는 쪽이 먼저 쓴다).
function DataService.unlockChaser(player: Player, chaserId: string): ()
	local data = DataService.getData(player)
	if data then
		data.UnlockedChasers[chaserId] = true
		publish(player, data)
	end
end

function DataService.setSelectedChaser(player: Player, chaserId: string): ()
	local data = DataService.getData(player)
	if data then
		data.SelectedChaser = chaserId
		publish(player, data)
	end
end

function DataService.setVisualMode(player: Player, mode: Types.VisualMode): ()
	local data = DataService.getData(player)
	if data then
		data.Settings.VisualMode = mode
	end
end

function DataService.setChaserOptOut(player: Player, optOut: boolean): ()
	local data = DataService.getData(player)
	if data then
		data.Settings.ChaserOptOut = optOut
	end
end

-- 스테이지 결과의 코인·경험치·통계를 준다 (RecordService가 만든 결과).
function DataService.grantStage(result: Types.StageResult): ()
	for _, entry in result.players do
		local player = Players:GetPlayerByUserId(entry.userId)
		local data = player and DataService.getData(player)
		if player and data and entry.outcome ~= "Left" and entry.outcome ~= "Absent" then
			data.Coins += entry.coins
			addXp(data, entry.score * Data.XpPerScore)
			local stats = data.Stats
			stats.StagesPlayed += 1
			stats.Catches += entry.catches
			if entry.outcome == "Survived" or entry.outcome == "Escaped" then
				stats.SurvivedStages += 1
			end
			if entry.outcome == "Escaped" then
				stats.Escapes += 1
			end
			publish(player, data)
		elseif player and not data and entry.coins > 0 then
			warn(
				`[Data] {player.Name}: 데이터가 없어 스테이지 코인 {entry.coins}을 주지 못했습니다`
			)
		end
	end
	print(`[Data] 스테이지 {result.stageIndex} 보상 지급`)
end

-- 매치 결과의 칭호 보너스와 매치 통계를 준다. 스테이지 코인은 grantStage에서 이미 줬다.
function DataService.grantMatch(result: Types.MatchResult): ()
	for _, record in result.players do
		local player = Players:GetPlayerByUserId(record.userId)
		local data = player and DataService.getData(player)
		if player and data then
			data.Coins += record.bonusCoins
			data.Stats.MatchesPlayed += 1
			if record.lastSurvivor then
				data.Stats.LastSurvivors += 1
				addXp(data, Score.Survived * Data.XpPerScore)
			end
			publish(player, data)
			updateLeaderboards(player, data)
		end
	end
	print("[Data] 매치 보상 지급")
end

-- 개발자 상품 영수증을 처리한다 (ShopService의 ProcessReceipt에서, 멈춤). 처음 보는 purchaseId면 grant(data)로
-- 지급하고 영수증을 적는다. 그 기록이 저장된 것을 saveTimeout초 안에 확인하면 PurchaseGranted, 아니면 NotProcessedYet.
-- 두 번째 값은 이번에 지급했는가 (알림·로그용).
function DataService.processPurchaseAsync(
	player: Player,
	purchaseId: string,
	grant: (data: PlayerData) -> (),
	saveTimeout: number
): (Enum.ProductPurchaseDecision, boolean)
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet, false
	end
	local data = profile.Data :: PlayerData
	local granted = false
	if not table.find(data.Receipts, purchaseId) then
		grant(data)
		table.insert(data.Receipts, purchaseId)
		while #data.Receipts > Data.MaxReceipts do
			table.remove(data.Receipts, 1)
		end
		publish(player, data)
		granted = true
	end

	local function isSaved(): boolean
		local saved = profile.LastSavedData
		local receipts = if typeof(saved) == "table" then saved.Receipts else nil
		return typeof(receipts) == "table" and table.find(receipts, purchaseId) ~= nil
	end
	if not isSaved() then
		profile:Save()
		local deadline = os.clock() + saveTimeout
		while not isSaved() and profile:IsActive() and os.clock() < deadline do
			task.wait(0.2)
		end
	end
	if isSaved() then
		return Enum.ProductPurchaseDecision.PurchaseGranted, granted
	end
	warn(`[Data] {player.Name}: 영수증 {purchaseId} 저장을 확인하지 못해 나중에 다시 처리합니다`)
	return Enum.ProductPurchaseDecision.NotProcessedYet, granted
end

-- 바로 저장을 요청한다 (결제 처리 등). 저장은 비동기로 이뤄진다.
function DataService.save(player: Player): ()
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

-- 데이터를 불러왔을 때 (다른 서비스가 연결)
DataService.Loaded = loadedEvent.Event

function DataService.Init(): () end

function DataService.Start(): ()
	ProfileStore.OnError:Connect(function(message: string, name: string, key: string)
		warn(`[Data] ProfileStore 오류 ({name}/{key}): {message}`)
	end)
	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = profiles[player]
		profiles[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
