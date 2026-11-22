--!strict
-- FreezeService: 얼음땡 모드의 얼음·땡 (2026-11-22 사용자 요청, Config.GameModes.FreezeTag). GDD 13.2 목록 밖에 추가한 서비스.
--
-- 얼음 (Freeze 리모트, 인자 없음): 빈도 제한·관전자 거절은 RemoteHandler. 얼음땡 모드(ReplicatedStorage GameMode)의 추격 단계,
--   숨지 않은 정상·부상 생존자, 다시 얼 수 있는 때(땡으로 풀린 뒤 RefreezeCooldown초, Player Attribute FreezeReadyAt)만.
--   얼기 전 상태(정상·부상)를 기억하고 SurvivorState Frozen으로 바꾼다. 캐릭터는 그 자리에 고정하고 반투명 얼음 덩어리를 씌운다.
--   언 사람은 움직이지 못하고(MovementService) 숨기·수리·아이템·판자·문이 막히며(각 서비스가 정상·부상만 받음)
--   술래에게 맞지 않는다 (CatchService.canBeHit). 스스로는 풀 수 없다.
-- 땡 (Thaw 리모트, 인자 없음): 같은 단계·모드에서 숨지 않은 정상·부상 생존자가 보낸다. 서버가 ThawDistance(+DistanceSlack) 안,
--   사이에 벽이 없는 가장 가까운 언 동료(자기 자신 제외)를 골라 얼기 전 상태로 되돌리고 고정을 푼다. 풀린 사람은
--   RefreezeCooldown초 동안 다시 얼 수 없다 (술래가 잡을 수 있게). 땡 해 준 사람은 치료 1회로 기록. 모두에게 알림 ThawedBy.
-- 서 있는 생존자가 모두 없어지면(모두 얼거나 잡힘) StageService가 스테이지를 끝낸다. 언 사람은 시간 종료면 생존, 아니면 잡힘.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CatchState = require(ReplicatedStorage.Shared.CatchState)
local GameModes = require(ReplicatedStorage.Shared.Config.GameModes)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local MovementService = require(script.Parent.MovementService)
local RecordService = require(script.Parent.RecordService)
local RoleService = require(script.Parent.RoleService)

type Frozen = {
	previous: Types.SurvivorState, -- 얼기 전 상태 (정상·부상)
	ice: BasePart?,
}

local Config = GameModes.FreezeTag
local Attribute = MatchState.Attribute
local ICE_NAME = "IceBlock"

local FreezeService = {}

local frozen: { [Player]: Frozen } = {}
local readyAt: { [Player]: number } = {} -- 다시 얼 수 있는 os.clock

-- 벽 검사: 캐릭터는 빼고, 충돌하는 파트만 막는 것으로 본다.
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.RespectCanCollide = true

local function isFreezeTag(): boolean
	return MatchState.getGameMode() == "FreezeTag" and CatchState.canHitInPhase(MatchState.getPhase())
end

-- 숨지 않은 정상·부상 생존자
local function canAct(player: Player): boolean
	local state = MatchState.getSurvivorState(player)
	return MatchState.getRole(player) == "Survivor"
		and (state == "Normal" or state == "Injured")
		and not MatchState.isHidden(player)
end

local function isPathClear(from: BasePart, to: BasePart): boolean
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	wallParams.FilterDescendantsInstances = characters
	return Workspace:Raycast(from.Position, to.Position - from.Position, wallParams) == nil
end

-- 캐릭터를 감싸는 얼음 덩어리. 캐릭터 안에 두어 캐릭터와 함께 지워진다.
local function makeIce(parts: CharacterParts.CharacterParts): BasePart
	local _, size = parts.character:GetBoundingBox()
	local ice = Instance.new("Part")
	ice.Name = ICE_NAME
	ice.Anchored = true
	ice.CanCollide = false
	ice.CanQuery = false
	ice.CanTouch = false
	ice.CastShadow = false
	ice.Massless = true
	ice.Material = Enum.Material.Glass
	ice.Color = Config.IceColor
	ice.Transparency = Config.IceTransparency
	ice.Size = size + Vector3.one * Config.IcePadding
	ice.CFrame = parts.character:GetBoundingBox()
	ice.Parent = parts.character
	return ice
end

local function lockCharacter(player: Player, entry: Frozen): ()
	local parts = CharacterParts.get(player)
	if not parts then
		return
	end
	parts.rootPart.AssemblyLinearVelocity = Vector3.zero
	parts.rootPart.Anchored = true
	MovementService.markTeleported(player)
	if entry.ice then
		entry.ice:Destroy()
	end
	entry.ice = makeIce(parts)
end

local function onFreeze(player: Player): ()
	if not isFreezeTag() or not canAct(player) or frozen[player] then
		return
	end
	if os.clock() < (readyAt[player] or 0) then
		return
	end
	local state = MatchState.getSurvivorState(player) or "Normal"
	local entry: Frozen = { previous = state, ice = nil }
	frozen[player] = entry
	RoleService.setSurvivorState(player, "Frozen")
	lockCharacter(player, entry)
	print(`[Freeze] {player.Name} 얼음 (얼기 전 {state})`)
end

-- 언 사람을 얼기 전 상태로 되돌리고 고정을 푼다. cooldown이면 다시 얼 수 있기까지 기다리게 한다.
local function unfreeze(player: Player, cooldown: boolean): ()
	local entry = frozen[player]
	frozen[player] = nil
	if not entry then
		return
	end
	if entry.ice then
		entry.ice:Destroy()
	end
	if MatchState.getSurvivorState(player) == "Frozen" then
		RoleService.setSurvivorState(player, entry.previous)
	end
	local parts = CharacterParts.get(player)
	if parts then
		parts.rootPart.Anchored = false
		MovementService.markTeleported(player)
	end
	if cooldown then
		readyAt[player] = os.clock() + Config.RefreezeCooldown
		player:SetAttribute(Attribute.FreezeReadyAt, Workspace:GetServerTimeNow() + Config.RefreezeCooldown)
	end
end

local function onThaw(thawer: Player): ()
	if not isFreezeTag() or not canAct(thawer) then
		return
	end
	local thawerParts = CharacterParts.get(thawer)
	if not thawerParts then
		return
	end
	local best: Player? = nil
	local bestDistance = Config.ThawDistance + Config.DistanceSlack
	for player in frozen do
		local parts = if player ~= thawer and player.Parent == Players then CharacterParts.get(player) else nil
		if parts then
			local distance = (parts.rootPart.Position - thawerParts.rootPart.Position).Magnitude
			if distance <= bestDistance and isPathClear(thawerParts.rootPart, parts.rootPart) then
				best = player
				bestDistance = distance
			end
		end
	end
	if not best then
		return
	end
	unfreeze(best, true)
	RecordService.addHeal(thawer)
	Remotes.get("Notice"):FireAllClients("ThawedBy" :: Types.NoticeKey, thawer.DisplayName, best.DisplayName)
	print(`[Freeze] {thawer.Name} → {best.Name} 땡`)
end

-- 언 사람의 새 캐릭터를 그 자리에서 다시 고정한다 (StageService.respawn). 얼어 있지 않으면 false.
function FreezeService.relock(player: Player): boolean
	local entry = frozen[player]
	if not entry or MatchState.getSurvivorState(player) ~= "Frozen" then
		return false
	end
	entry.ice = nil
	lockCharacter(player, entry)
	return true
end

-- 스테이지가 끝나면 얼음 기록을 지운다 (StageService.finish). 캐릭터는 MatchService가 로비에 새로 만든다.
function FreezeService.clearStage(): ()
	for player, entry in frozen do
		if entry.ice then
			entry.ice:Destroy()
		end
		if player.Parent == Players then
			player:SetAttribute(Attribute.FreezeReadyAt, nil)
		end
	end
	table.clear(frozen)
	for player in readyAt do
		if player.Parent == Players then
			player:SetAttribute(Attribute.FreezeReadyAt, nil)
		end
	end
	table.clear(readyAt)
end

function FreezeService.Init(): () end

function FreezeService.Start(): ()
	RemoteHandler.connect("Freeze", function(player: Player)
		onFreeze(player)
	end)
	RemoteHandler.connect("Thaw", function(player: Player)
		onThaw(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		frozen[player] = nil
		readyAt[player] = nil
	end)
end

return FreezeService
