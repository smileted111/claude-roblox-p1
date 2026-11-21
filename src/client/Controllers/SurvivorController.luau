--!strict
-- SurvivorController: 생존자 조작 — 달리기·숨기·아군 치료·수리·아이템·판자·문과 피격 효과 (GDD 2.2, 4.1, 6장, 13.2).
--
-- 달리기: 누르고 있는 동안 달리기 의사를 서버에 보낸다 (SetRunning). 속도와 스태미나는 서버(MovementService)가 정한다.
--   PC Shift, 게임패드 L3, 휴대폰은 화면 버튼 (InputController가 묶음, 키는 Config.Input.Bindings).
--   Shift가 Roblox 기본 시프트 락과 겹쳐서 default.project.json에서 StarterPlayer.EnableMouseLockOption을 껐다.
-- 스태미나 바·상태 표시는 UIController(HUD)가 한다.
-- 숨기: 숨는 곳의 "숨기"·"나오기" 프롬프트 중 내 상태에 맞는 것만 켠다. 판정은 서버(HideService).
-- 치료: 부상당한 다른 생존자의 "치료" 프롬프트를 내가 치료할 수 있을 때만 켠다 (CatchState). 판정은 서버(CatchService).
-- 수리: 발전기 "수리" 프롬프트를 숨지 않은 생존자에게 추격 단계에서만 켠다 (ObjectiveState). 진행은 서버(ObjectiveService).
-- 아이템: 숫자키 1·2, 게임패드 LB·RB(관전 중 대상 바꾸기와 같은 버튼이지만 관전자는 아이템이 없음), 휴대폰은 화면의
--   아이템 버튼(아이템이 있는 첫 칸) 또는 HUD 아이템 칸(UIController가 SurvivorController.useItem을 부름).
--   UseItem 리모트로 칸 번호와 던질 곳(카메라가 보는 곳)을 보내고 효과는 서버(ItemService).
--   "줍기" 프롬프트는 숨지 않은 생존자에게 빈칸이 있을 때만 켠다.
-- 판자 "넘어뜨리기"는 숨지 않은 생존자에게 추격 단계에서, 문 "열기·닫기"는 숨지 않은 생존자와 추격자에게 켠다 (BarrierService).
-- 내 생존자 상태가 바뀌면 효과를 낸다 (GDD 8장, 12장). 피 표현 없이 화면 효과와 효과음(자리만)으로.
--   정상 → 부상: 화면이 잠깐 번쩍임 (Config.Catch.HitFlash)
--   잡힘: 서버가 CaughtBy 리모트(잡은 괴물·추격자)를 보내면 잡힘 연출(Util/CaughtCinematic: 번쩍임·흔들림·잡은 쪽 얼굴
--         클로즈업 뒤 암전). 리모트가 오지 않으면 바로 화면 암전. 합쳐 Config.Match.CaughtEffectTime초 (Config.Catch.CaughtEffect).
--         그 뒤 관전은 SpectateController

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local CatchState = require(ReplicatedStorage.Shared.CatchState)
local HideSpotState = require(ReplicatedStorage.Shared.HideSpotState)
local ItemState = require(ReplicatedStorage.Shared.ItemState)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local ObjectiveState = require(ReplicatedStorage.Shared.ObjectiveState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survivor = require(ReplicatedStorage.Shared.Config.Survivor)
local Types = require(ReplicatedStorage.Shared.Types)
local CaughtCinematic = require(script.Parent.Parent.Util.CaughtCinematic)
local HideSpotWatcher = require(script.Parent.Parent.Util.HideSpotWatcher)
local ScreenEffect = require(script.Parent.Parent.Util.ScreenEffect)
local InputController = require(script.Parent.InputController)
local SoundController = require(script.Parent.SoundController)

local AIM_DISTANCE = 100 -- 알람시계 조준 레이캐스트 거리 (서버가 Config.Items의 Range로 다시 줄임)
-- 아이템 칸별 입력 동작 (칸 번호 = 목록 순서)
local ITEM_ACTIONS: { Types.InputAction } = { "Item1", "Item2" }

local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local SurvivorController = {}

local runRemote: RemoteEvent? = nil
local itemRemote: RemoteEvent? = nil
local runBound = false
local wantsToRun = false
local lastSurvivorState: Types.SurvivorState? = nil
local cinematicAt = -math.huge -- 마지막 잡힘 연출을 시작한 시각 (os.clock)
local CINEMATIC_WAIT = 0.3 -- 잡힘 상태를 받은 뒤 연출 리모트를 기다리는 시간 (초). 넘으면 기본 암전

local function isSurvivor(): boolean
	return MatchState.getRole(localPlayer) == "Survivor"
end

local function setWantsToRun(value: boolean): ()
	if wantsToRun == value then
		return
	end
	wantsToRun = value
	if runRemote then
		runRemote:FireServer(value)
	end
end

-- 카메라가 보는 곳 (알람시계를 던질 곳). 내 캐릭터는 빼고 100스터드까지 레이캐스트한다.
local function aimPosition(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if localPlayer.Character then { localPlayer.Character } else {}
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * AIM_DISTANCE
	local hit = Workspace:Raycast(origin, direction, params)
	return if hit then hit.Position else origin + direction
end

-- 아이템 칸 slot의 아이템을 쓴다 (숫자키·게임패드·HUD 칸 버튼). 판정과 효과는 서버. 던질 곳(카메라가 보는 곳)도 보낸다.
function SurvivorController.useItem(slot: number): ()
	if isSurvivor() and MatchState.getItem(localPlayer, slot) and itemRemote then
		itemRemote:FireServer(slot, aimPosition())
	end
end

-- 아이템이 있는 첫 칸 (휴대폰 아이템 버튼이 쓴다)
local function firstItemSlot(): number?
	for slot = 1, Survivor.InventorySlots do
		if MatchState.getItem(localPlayer, slot) then
			return slot
		end
	end
	return nil
end

-- 휴대폰 아이템 버튼에 쓸 아이템 이름을 붙이고, 아이템이 없으면 흐리게 한다.
local function refreshItemButton(): ()
	local slot = firstItemSlot()
	local itemId = if slot then MatchState.getItem(localPlayer, slot) else nil
	InputController.setTouchLabel("Item", if itemId then Strings.Items[itemId] else nil)
	InputController.setTouchDimmed("Item", itemId == nil)
end

-- 생존자일 때만 달리기·아이템 입력(과 휴대폰 화면 버튼)을 묶는다.
local function updateRunBinding(): ()
	local shouldBind = isSurvivor()
	if shouldBind == runBound then
		return
	end
	runBound = shouldBind
	if shouldBind then
		InputController.bind("Run", setWantsToRun)
		for slot = 1, Survivor.InventorySlots do
			InputController.bind(ITEM_ACTIONS[slot], function(pressed: boolean)
				if pressed then
					SurvivorController.useItem(slot)
				end
			end)
		end
		InputController.bind("Item", function(pressed: boolean)
			local slot = firstItemSlot()
			if pressed and slot then
				SurvivorController.useItem(slot)
			end
		end)
		refreshItemButton()
	else
		InputController.unbind("Run")
		for _, action in ITEM_ACTIONS do
			InputController.unbind(action)
		end
		InputController.unbind("Item")
		setWantsToRun(false)
	end
end

local function hasFreeSlot(): boolean
	for slot = 1, Survivor.InventorySlots do
		if MatchState.getItem(localPlayer, slot) == nil then
			return true
		end
	end
	return false
end

local function setTaggedPrompts(tag: string, enabled: boolean): ()
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("ProximityPrompt") then
			instance.Enabled = enabled
		end
	end
end

-- 줍기·판자·문 프롬프트
local function refreshItemPrompts(): ()
	local phase = MatchState.getPhase()
	local canAct = isSurvivor() and not MatchState.isHidden(localPlayer)
	setTaggedPrompts(ItemState.PickupPromptTag, canAct and ItemState.canInteractInPhase(phase) and hasFreeSlot())
	setTaggedPrompts(ItemState.PlankPromptTag, canAct and ItemState.canUseInPhase(phase))
	local isChaser = MatchState.getRole(localPlayer) == "Chaser"
	setTaggedPrompts(ItemState.DoorPromptTag, (canAct or isChaser) and ItemState.canInteractInPhase(phase))
end

-- 숨기: 생존자이고, 숨어 있지 않고, 숨을 수 있는 단계이고, 비어 있는 곳. 나오기: 내가 숨은 곳.
local function refreshHidePrompts(): ()
	local survivor = isSurvivor()
	local canHide = survivor
		and not MatchState.isHidden(localPlayer)
		and HideSpotState.canHideInPhase(MatchState.getPhase())
	for _, spot in HideSpotWatcher.getSpots() do
		local occupantUserId = HideSpotState.getOccupantUserId(spot)
		local hidePrompt = HideSpotWatcher.findPrompt(spot, HideSpotState.Prompt.Hide)
		if hidePrompt then
			hidePrompt.Enabled = canHide and occupantUserId == nil
		end
		local unhidePrompt = HideSpotWatcher.findPrompt(spot, HideSpotState.Prompt.Unhide)
		if unhidePrompt then
			unhidePrompt.Enabled = survivor and occupantUserId == localPlayer.UserId
		end
	end
end

-- 치료: 내가 숨지 않은 생존자이고 치료할 수 있는 단계일 때, 내 캐릭터가 아닌 사람의 프롬프트만 켠다.
-- 대상이 숨거나 부상이 아니게 되면 서버가 프롬프트를 지운다.
local function refreshHealPrompts(): ()
	local character = localPlayer.Character
	local canHeal = isSurvivor()
		and not MatchState.isHidden(localPlayer)
		and CatchState.canHealInPhase(MatchState.getPhase())
	for _, instance in CollectionService:GetTagged(CatchState.HealPromptTag) do
		if instance:IsA("ProximityPrompt") then
			local isMine = character ~= nil and instance:IsDescendantOf(character)
			instance.Enabled = canHeal and not isMine
		end
	end
end

-- 프롬프트가 달린 발전기 (Generator 태그가 붙은 조상)
local function generatorOf(prompt: Instance): Instance?
	local node = prompt.Parent
	while node and not node:HasTag(MapTags.Generator) do
		node = node.Parent
	end
	return node
end

local function refreshRepairPrompts(): ()
	local canRepair = isSurvivor()
		and not MatchState.isHidden(localPlayer)
		and ObjectiveState.canRepairInPhase(MatchState.getPhase())
	for _, instance in CollectionService:GetTagged(ObjectiveState.RepairPromptTag) do
		if instance:IsA("ProximityPrompt") then
			local generator = generatorOf(instance)
			instance.Enabled = canRepair and generator ~= nil and not ObjectiveState.isRepaired(generator)
		end
	end
end

local function onSurvivorStateChanged(): ()
	local state = MatchState.getSurvivorState(localPlayer)
	local previous = lastSurvivorState
	lastSurvivorState = state
	if state == "Caught" and previous ~= "Caught" then
		SoundController.play("SurvivorCaught")
		local caughtAt = os.clock()
		task.delay(CINEMATIC_WAIT, function()
			-- 서버가 연출 리모트를 보내지 못한 경우 (캐릭터가 없는 등)
			if cinematicAt < caughtAt - 1 then
				local effect = Catch.CaughtEffect
				ScreenEffect.blackout(effect.FadeInTime, Match.CaughtEffectTime, effect.FadeOutTime)
			end
		end)
	elseif state == "Injured" and previous == "Normal" then
		local flash = Catch.HitFlash
		ScreenEffect.flash(flash.Color, flash.StartTransparency, flash.Duration)
		SoundController.play("SurvivorHit")
	elseif state == "Normal" and previous == "Injured" then
		SoundController.play("SurvivorHealed")
	end
end

function SurvivorController.Init(): () end

function SurvivorController.Start(): ()
	runRemote = Remotes.get("SetRunning")
	lastSurvivorState = MatchState.getSurvivorState(localPlayer)

	local function refreshPrompts(): ()
		refreshHidePrompts()
		refreshHealPrompts()
		refreshRepairPrompts()
		refreshItemPrompts()
	end

	itemRemote = Remotes.get("UseItem")
	for _, name in { Attribute.Item1, Attribute.Item2 } do
		localPlayer:GetAttributeChangedSignal(name):Connect(function()
			refreshItemPrompts()
			refreshItemButton()
		end)
	end
	for _, tag in { ItemState.PickupPromptTag, ItemState.PlankPromptTag, ItemState.DoorPromptTag } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(refreshItemPrompts)
	end

	localPlayer:GetAttributeChangedSignal(Attribute.Role):Connect(function()
		updateRunBinding()
		refreshPrompts()
	end)
	localPlayer:GetAttributeChangedSignal(Attribute.Hidden):Connect(refreshPrompts)
	localPlayer:GetAttributeChangedSignal(Attribute.SurvivorState):Connect(onSurvivorStateChanged)
	Remotes.get("CaughtBy").OnClientEvent:Connect(function(catcher: unknown, position: unknown)
		cinematicAt = os.clock()
		local model = if typeof(catcher) == "Instance" and catcher:IsA("Model") then catcher else nil
		local from = if typeof(position) == "Vector3" then position else Vector3.zero
		CaughtCinematic.play(model, from)
	end)
	localPlayer.CharacterAdded:Connect(refreshHealPrompts)
	ReplicatedStorage:GetAttributeChangedSignal(Attribute.Phase):Connect(refreshPrompts)
	HideSpotWatcher.subscribe(refreshHidePrompts)
	CollectionService:GetInstanceAddedSignal(CatchState.HealPromptTag):Connect(refreshHealPrompts)
	CollectionService:GetInstanceAddedSignal(ObjectiveState.RepairPromptTag):Connect(refreshRepairPrompts)
	ReplicatedStorage:GetAttributeChangedSignal(MatchState.Attribute.GeneratorsDone):Connect(refreshRepairPrompts)

	updateRunBinding()
	refreshHealPrompts()
	refreshRepairPrompts()
	refreshItemPrompts()
end

return SurvivorController
