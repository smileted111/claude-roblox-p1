--!strict
-- JailService: 경찰과 도둑 모드의 감옥 (2026-11-22 사용자 요청, Config.GameModes, GDD 2.2). GDD 13.2 목록 밖에 추가한 서비스.
--
-- 감옥: 맵의 MapTags.Jail 태그 Model. 막힌 우리(부딪히는 투명 벽·지붕)와 JailState의 투명 파트 Inside·ReleasePoint·RescueZone.
--   만드는 스크립트는 tools/mapgen/Jails.luau. StageService가 준비 단계에 setupMap(map, enabled)를 부르고,
--   경찰과 도둑이 아니면(서바이벌·솔로) 맵에서 감옥을 지운다.
-- 가두기 (CatchService.hit이 부름): 부상 상태로 맞은 도둑을 SurvivorState Jailed로 바꾸고 가장 가까운 감옥 Inside 위로 옮긴다.
--   경찰의 잡은 수를 올리고 알림(모두에게 SurvivorJailed, 본인에게 YouAreJailed). 갇힌 사람은 우리 안을 걸을 수만 있고
--   (MovementService) 숨기·수리·아이템·판자·문·출구가 막히며(각 서비스가 정상·부상만 받음) 맞지도 않는다.
-- 구출: Config.GameModes.Jail.TickInterval마다 감옥마다 RescueZone 상자 안에 서 있는 도둑(정상·부상, 숨지 않음)이 있으면
--   진행 += 시간, 아무도 없으면 0으로 (계속 서 있어야 함). RescueTime초가 차면 그 감옥에 갇힌 사람을 모두 정상으로 풀어
--   ReleasePoint 둘레에 세우고 ReleaseProtectTime초 동안 맞지 않게 한다 (CatchService.canBeHit이 isProtected를 봄).
-- 서 있는 도둑이 모두 없어지면 StageService가 스테이지를 끝낸다 (갇힌 사람은 잡힘으로 기록).
-- 공개: 감옥 Model Attribute RescueProgress·Prisoners (JailState) → client Util/JailBillboards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameModes = require(ReplicatedStorage.Shared.Config.GameModes)
local JailState = require(ReplicatedStorage.Shared.JailState)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local MovementService = require(script.Parent.MovementService)
local RecordService = require(script.Parent.RecordService)
local RoleService = require(script.Parent.RoleService)

type Jail = {
	model: Model,
	inside: BasePart,
	release: BasePart,
	zone: BasePart,
	progress: number, -- 구출 진행 (초)
	shownProgress: number, -- 마지막으로 공개한 값 (0~1)
}

local Config = GameModes.Jail
local Attribute = JailState.Attribute

local JailService = {}

local random = Random.new()
local jails: { Jail } = {}
local jailOf: { [Player]: Jail } = {} -- 갇힌 사람 → 감옥
local protectedUntil: { [Player]: number } = {} -- os.clock
local heartbeat: RBXScriptConnection? = nil
local elapsed = 0

local function isFreeRobber(player: Player): boolean
	local state = MatchState.getSurvivorState(player)
	return MatchState.getRole(player) == "Survivor"
		and (state == "Normal" or state == "Injured")
		and not MatchState.isHidden(player)
end

local function isInZone(zone: BasePart, position: Vector3): boolean
	local localPosition = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function prisonersOf(jail: Jail): { Player }
	local list: { Player } = {}
	for player, at in jailOf do
		if at == jail and player.Parent == Players then
			table.insert(list, player)
		end
	end
	return list
end

local function publish(jail: Jail): ()
	local ratio = math.clamp(jail.progress / Config.RescueTime, 0, 1)
	local shown = math.floor(ratio / Config.ProgressPublishStep) * Config.ProgressPublishStep
	if shown ~= jail.shownProgress then
		jail.shownProgress = shown
		jail.model:SetAttribute(Attribute.RescueProgress, shown)
	end
	local count = #prisonersOf(jail)
	if JailState.getPrisoners(jail.model) ~= count then
		jail.model:SetAttribute(Attribute.Prisoners, count)
	end
end

-- 캐릭터를 base 파트 윗면 위(가운데에서 spread 안의 무작위 자리)에 세운다.
local function standOn(player: Player, base: BasePart, spread: number): ()
	local parts = CharacterParts.get(player)
	if not parts then
		return
	end
	local offset = Vector3.new(random:NextNumber(-spread, spread), 0, random:NextNumber(-spread, spread))
	local floorY = base.Position.Y - base.Size.Y / 2
	local standHeight = parts.humanoid.HipHeight + parts.rootPart.Size.Y / 2
	local position = Vector3.new(base.Position.X + offset.X, floorY + standHeight, base.Position.Z + offset.Z)
	local look = base.CFrame.LookVector
	parts.rootPart.AssemblyLinearVelocity = Vector3.zero
	parts.character:PivotTo(CFrame.lookAt(position, position + Vector3.new(look.X, 0, look.Z)))
	MovementService.markTeleported(player)
end

local function nearestJail(player: Player): Jail?
	local parts = CharacterParts.get(player)
	local best: Jail? = nil
	local bestDistance = math.huge
	for _, jail in jails do
		local distance = if parts then (jail.inside.Position - parts.rootPart.Position).Magnitude else 0
		if distance < bestDistance then
			best = jail
			bestDistance = distance
		end
	end
	return best
end

local function release(jail: Jail, rescuer: Player): ()
	local freed = prisonersOf(jail)
	for _, player in freed do
		jailOf[player] = nil
		if MatchState.getSurvivorState(player) == "Jailed" then
			RoleService.setSurvivorState(player, "Normal")
			protectedUntil[player] = os.clock() + Config.ReleaseProtectTime
			standOn(player, jail.release, Config.ReleaseSpread)
		end
	end
	jail.progress = 0
	publish(jail)
	if #freed > 0 then
		Remotes.get("Notice"):FireAllClients("JailRescued" :: Types.NoticeKey, rescuer.DisplayName, #freed)
		print(`[Jail] {rescuer.Name} 구출 → {#freed}명 풀려남 ({jail.model:GetFullName()})`)
	end
end

local function step(dt: number): ()
	local chase = MatchState.getPhase() == "Chase"
	for _, jail in jails do
		local prisoners = prisonersOf(jail)
		local rescuer: Player? = nil
		if #prisoners > 0 and chase then
			for _, player in RoleService.getActiveSurvivors() do
				local parts = if isFreeRobber(player) then CharacterParts.get(player) else nil
				if parts and isInZone(jail.zone, parts.rootPart.Position) then
					rescuer = player
					break
				end
			end
		end
		if rescuer then
			jail.progress += dt
			if jail.progress >= Config.RescueTime then
				release(jail, rescuer)
			end
		else
			jail.progress = 0
		end
		publish(jail)
	end
end

-- 이번 스테이지에 감옥을 쓰는가 (경찰과 도둑이고 맵에 감옥이 있음)
function JailService.isEnabled(): boolean
	return #jails > 0
end

-- 풀려난 직후라 맞지 않는가
function JailService.isProtected(player: Player): boolean
	return os.clock() < (protectedUntil[player] or 0)
end

-- 도둑을 가장 가까운 감옥에 가둔다. 가둘 감옥이 없으면 false.
function JailService.imprison(survivor: Player, source: string, attacker: Player?): boolean
	local jail = nearestJail(survivor)
	if not jail then
		return false
	end
	jailOf[survivor] = jail
	RoleService.setSurvivorState(survivor, "Jailed")
	standOn(survivor, jail.inside, jail.inside.Size.X * 0.3)
	if attacker then
		RecordService.addCatch(attacker)
	end
	publish(jail)
	local notice = Remotes.get("Notice")
	for _, player in Players:GetPlayers() do
		if player ~= survivor then
			notice:FireClient(player, "SurvivorJailed" :: Types.NoticeKey, survivor.DisplayName)
		end
	end
	notice:FireClient(survivor, "YouAreJailed" :: Types.NoticeKey, Config.RescueTime)
	print(`[Jail] {source} → {survivor.Name} 감옥에 갇힘`)
	return true
end

-- 갇힌 사람의 캐릭터를 다시 감옥 안에 세운다 (새로 생긴 캐릭터, StageService.respawn). 갇혀 있지 않으면 false.
function JailService.placeInJail(player: Player): boolean
	local jail = jailOf[player]
	if not jail or MatchState.getSurvivorState(player) ~= "Jailed" then
		return false
	end
	standOn(player, jail.inside, jail.inside.Size.X * 0.3)
	return true
end

-- 갇힌 사람을 모두 정상으로 풀어 감옥 앞에 세운다 (경찰이 모두 나가 스테이지를 끝낼 때, StageService).
function JailService.releaseAll(): ()
	for player, jail in table.clone(jailOf) do
		jailOf[player] = nil
		if player.Parent == Players and MatchState.getSurvivorState(player) == "Jailed" then
			RoleService.setSurvivorState(player, "Normal")
			standOn(player, jail.release, Config.ReleaseSpread)
		end
	end
	for _, jail in jails do
		jail.progress = 0
		publish(jail)
	end
end

local function findPart(model: Instance, name: string): BasePart?
	local part = model:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part else nil
end

-- 불러온 맵의 감옥을 준비한다. enabled가 아니면 (경찰과 도둑이 아님) 맵에서 감옥을 지운다.
function JailService.setupMap(map: Instance, enabled: boolean): ()
	JailService.clearMap()
	local found: { Model } = {}
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("Model") and descendant:HasTag(MapTags.Jail) then
			table.insert(found, descendant)
		end
	end
	if not enabled then
		for _, model in found do
			model:Destroy()
		end
		return
	end
	for _, model in found do
		local inside = findPart(model, JailState.Inside)
		local releasePart = findPart(model, JailState.ReleasePoint)
		local zone = findPart(model, JailState.RescueZone)
		if inside and releasePart and zone then
			table.insert(jails, {
				model = model,
				inside = inside,
				release = releasePart,
				zone = zone,
				progress = 0,
				shownProgress = -1,
			})
		else
			warn(
				`[Jail] {model:GetFullName()}: {JailState.Inside}·{JailState.ReleasePoint}·{JailState.RescueZone} 파트가 모두 있어야 합니다`
			)
		end
	end
	for _, jail in jails do
		publish(jail)
	end
	if #jails == 0 then
		warn(
			"[Jail] 경찰과 도둑인데 맵에 감옥이 없어 서바이벌 규칙(쓰러짐)으로 진행합니다"
		)
		return
	end
	elapsed = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= Config.TickInterval then
			local stepTime = elapsed
			elapsed = 0
			step(stepTime)
		end
	end)
	print(`[Jail] 감옥 {#jails}곳 준비`)
end

-- 스테이지가 끝나면 감옥 기록을 지운다 (StageService.finish).
function JailService.clearMap(): ()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	table.clear(jails)
	table.clear(jailOf)
	table.clear(protectedUntil)
end

function JailService.Init(): () end

function JailService.Start(): ()
	Players.PlayerRemoving:Connect(function(player: Player)
		jailOf[player] = nil
		protectedUntil[player] = nil
	end)
end

return JailService
