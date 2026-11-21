--!strict
-- SpectateService: 관전 상태·대상 관리와 관전자 채팅 (GDD 8장, 13.2, 13.3, 질문지 Q4-6·Q4-7)
--
-- 관전자: 이번 스테이지에서 역할이 Spectator인 플레이어. 잡힌 생존자, 탈출한 생존자.
--   (매치 중에 들어온 사람은 관전하지 않고 로비에서 기다린다, MatchService)
--
-- 관전 시작
--   잡혔으면 Config.Match.CaughtEffectTime초(잡힘 연출) 뒤, 그 밖에는 바로.
--   그때 스테이지가 이미 결과 단계로 넘어갔거나 남은 생존자가 없으면 관전하지 않는다. 솔로에서 잡히면 남은 생존자가
--   없어 스테이지가 바로 결과로 가므로 관전 없이 결과를 본다 (GDD 5장).
--   첫 대상: 잡힐 때 가장 가까이 있던 생존자. 그 사람이 그새 잡혔으면 잡힌 자리에서 지금 가장 가까운 생존자,
--   위치를 모르면(중간 입장) 목록의 첫 대상.
-- 볼 수 있는 대상: 아직 잡히거나 탈출하지 않은 생존자 + 추격자. 순서는 생존자 먼저, 같은 역할 안에서는 UserId순.
-- 대상 바꾸기: SpectateCycle 리모트 (step 1 = 다음, -1 = 이전). 끝에서는 반대쪽 끝으로 돈다.
-- 대상이 잡히거나 탈출하거나 나가서 목록에서 빠지면 Config.Match.SpectateSwitchDelay초 뒤 그다음 대상으로 바꾼다.
--   그 사이 직접 바꾸면 바로 바뀐다.
-- 공개: Player Attribute Spectating·SpectateTarget (MatchState). 카메라와 화면은 클라이언트(SpectateController).
-- Player.ReplicationFocus를 대상의 HumanoidRootPart로 둔다. StreamingEnabled라 캐릭터가 없는 관전자에게도 대상 주변
--   맵이 오게 하기 위해서다. 대상 캐릭터가 다시 생기면 새 HumanoidRootPart로 옮긴다.
-- 관전 끝: 역할이 Spectator가 아니게 되면 (스테이지가 끝나 RoleService.clearAll로 역할이 지워짐) 또는 나가면.
--   스테이지 결과 단계 동안은 마지막 대상을 계속 본다 (캐릭터가 없는 관전자의 화면과 스트리밍을 유지).
--
-- 관전자 채팅 (질문지 Q4-7: 관전자가 추격자 위치를 생존자에게 알려주는 것을 막기 위해)
--   TextChatService.TextChannels 아래에 관전자 채널(SpectateState.ChatChannelName)을 만들고, 역할이 Spectator인
--   동안 그 플레이어를 채널에 넣는다 (잡힘 연출 중에도). 채널 메시지는 채널에 든 사람에게만 간다.
--   다른 채널(RBXGeneral, 귓속말 채널 등)에는 ShouldDeliverCallback을 걸어, 관전자가 보낸 메시지는 관전자에게만 전달한다.
--   입력창 대상 바꾸기는 클라이언트(SpectateController)가 한다.
--
-- 관전자의 게임 요청: 모든 클라이언트 → 서버 리모트는 server/Util/RemoteHandler가 관전자 요청을 거절한다
-- (SpectateCycle 등 Remotes.isSpectatorAllowed 목록 제외). 숨기·치료·열어보기 프롬프트는 각 서비스가
-- 생존자·추격자 역할을 검사하고, 관전자는 캐릭터도 없다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local SpectateState = require(ReplicatedStorage.Shared.SpectateState)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local RoleService = require(script.Parent.RoleService)

local TEXT_CHANNELS_WAIT = 10 -- TextChatService.TextChannels 폴더를 기다리는 최대 시간 (초)
local ROOT_PART_WAIT = 5 -- 대상의 새 캐릭터에서 HumanoidRootPart를 기다리는 최대 시간 (초)

-- 관전을 시작할 수 있는 단계: 스테이지 진행 중. 결과 단계면 스테이지가 이미 끝났다.
local SPECTATE_PHASES: { [Types.MatchPhase]: boolean } = {
	RoleReveal = true,
	Preparation = true,
	Chase = true,
}

-- 대상 목록의 정렬 키. 대상이 목록에서 빠진 뒤에도 그 자리의 다음 대상을 찾을 수 있게 고를 때 저장해 둔다.
type TargetKey = {
	group: number, -- 1 생존자, 2 추격자
	userId: number,
}

type Watcher = {
	target: Player?,
	targetKey: TargetKey?,
	switchToken: number, -- 대상이 바뀔 때마다 1씩 올라, 예약된 자동 전환을 무효로 만든다
	switchPending: boolean, -- 대상이 목록에서 빠져 자동 전환을 기다리는 중
	characterConnection: RBXScriptConnection?, -- 대상의 CharacterAdded (ReplicationFocus 옮기기)
}

local Attribute = MatchState.Attribute

local SpectateService = {}

local watchers: { [Player]: Watcher } = {}
local startTokens: { [Player]: number } = {} -- 관전 시작 예약. 값이 바뀌거나 지워지면 그 예약은 무효
local nextStartToken = 0
local spectatorChannel: TextChannel? = nil
local chatSyncing: { [Player]: boolean } = {}
local chatDirty: { [Player]: boolean } = {}

local function isSpectator(player: Player): boolean
	return player.Parent == Players and MatchState.getRole(player) == "Spectator"
end

-- 지금 볼 수 있는 대상인가: 잡히거나 탈출하지 않은 생존자, 또는 추격자
local function isCandidate(player: Player): boolean
	if player.Parent ~= Players then
		return false
	end
	local role = MatchState.getRole(player)
	if role == "Chaser" then
		return true
	end
	local state = MatchState.getSurvivorState(player)
	return role == "Survivor" and (state == "Normal" or state == "Injured")
end

local function keyOf(player: Player): TargetKey
	return { group = if MatchState.getRole(player) == "Chaser" then 2 else 1, userId = player.UserId }
end

local function keyLess(a: TargetKey, b: TargetKey): boolean
	if a.group ~= b.group then
		return a.group < b.group
	end
	return a.userId < b.userId
end

-- 볼 수 있는 대상 목록 (정렬됨)
local function getCandidates(): { Player }
	local list = RoleService.getActiveSurvivors()
	for _, chaser in RoleService.getChasers() do
		table.insert(list, chaser)
	end
	table.sort(list, function(a: Player, b: Player): boolean
		return keyLess(keyOf(a), keyOf(b))
	end)
	return list
end

-- 지금 대상의 다음(step 1)·이전(step -1) 대상. 지금 대상이 목록에서 빠졌어도 그 자리를 기준으로 찾는다.
-- 대상이 없었으면 목록의 첫 대상, 목록이 비면 nil.
local function pickRelative(watcher: Watcher, step: number): Player?
	local candidates = getCandidates()
	if #candidates == 0 then
		return nil
	end
	local currentKey = watcher.targetKey
	if not currentKey then
		return candidates[1]
	end
	if step > 0 then
		for _, candidate in candidates do
			if keyLess(currentKey, keyOf(candidate)) then
				return candidate
			end
		end
		return candidates[1]
	end
	for index = #candidates, 1, -1 do
		if keyLess(keyOf(candidates[index]), currentKey) then
			return candidates[index]
		end
	end
	return candidates[#candidates]
end

-- position에서 가장 가까운 생존자 (캐릭터가 맵에 있는 사람만)
local function closestSurvivor(position: Vector3): Player?
	local best: Player? = nil
	local bestDistance = math.huge
	for _, survivor in RoleService.getActiveSurvivors() do
		local parts = CharacterParts.get(survivor)
		local distance = parts and (parts.rootPart.Position - position).Magnitude
		if distance and distance < bestDistance then
			best = survivor
			bestDistance = distance
		end
	end
	return best
end

local function disconnectTarget(watcher: Watcher): ()
	local connection = watcher.characterConnection
	if connection then
		connection:Disconnect()
		watcher.characterConnection = nil
	end
end

local function setTarget(player: Player, watcher: Watcher, target: Player?): ()
	disconnectTarget(watcher)
	watcher.target = target
	watcher.targetKey = if target then keyOf(target) else nil
	watcher.switchToken += 1
	watcher.switchPending = false
	player:SetAttribute(Attribute.SpectateTarget, if target then target.UserId else nil)

	if not target then
		print(`[Spectate] {player.Name}: 볼 수 있는 대상 없음`)
		return
	end
	-- 대상에게 아직 캐릭터가 없으면 생길 때까지 지금 초점을 그대로 둔다.
	local parts = CharacterParts.get(target)
	if parts then
		player.ReplicationFocus = parts.rootPart
	end
	watcher.characterConnection = target.CharacterAdded:Connect(function(character: Model)
		local rootPart = character:WaitForChild("HumanoidRootPart", ROOT_PART_WAIT)
		if rootPart and rootPart:IsA("BasePart") and watchers[player] == watcher and watcher.target == target then
			player.ReplicationFocus = rootPart
		end
	end)
	print(`[Spectate] {player.Name} → {target.Name} ({MatchState.getRole(target)}) 관전`)
end

-- 대상이 목록에서 빠지면 Config.Match.SpectateSwitchDelay초 뒤 그다음 대상으로 바꾼다.
local function scheduleSwitch(player: Player, watcher: Watcher): ()
	watcher.switchPending = true
	local token = watcher.switchToken
	task.delay(Match.SpectateSwitchDelay, function()
		if watchers[player] == watcher and watcher.switchToken == token then
			setTarget(player, watcher, pickRelative(watcher, 1))
		end
	end)
end

-- 볼 수 있는 대상이 바뀌었을 때 (역할 변경·퇴장). leaving은 지금 나가는 중이라 아직 Players에 있는 플레이어.
local function refreshTargets(leaving: Player?): ()
	for player, watcher in watchers do
		local target = watcher.target
		if target == nil then
			-- 볼 대상이 없던 관전자는 볼 사람이 생기면 바로 고른다.
			local first = pickRelative(watcher, 1)
			if first and first ~= leaving then
				setTarget(player, watcher, first)
			end
		elseif (target == leaving or not isCandidate(target)) and not watcher.switchPending then
			scheduleSwitch(player, watcher)
		end
	end
end

local function start(player: Player, preferred: Player?, lastPosition: Vector3?): ()
	if not isSpectator(player) or watchers[player] then
		return
	end
	local phase = MatchState.getPhase()
	if not SPECTATE_PHASES[phase] then
		print(`[Spectate] {player.Name}: 스테이지가 끝나 관전하지 않음 ({phase})`)
		return
	end
	if #RoleService.getActiveSurvivors() == 0 then
		print(`[Spectate] {player.Name}: 남은 생존자가 없어 관전하지 않음 (스테이지 결과로)`)
		return
	end

	local watcher: Watcher = {
		target = nil,
		targetKey = nil,
		switchToken = 0,
		switchPending = false,
		characterConnection = nil,
	}
	watchers[player] = watcher
	player:SetAttribute(Attribute.Spectating, true)

	local first: Player? = nil
	if preferred and isCandidate(preferred) and MatchState.getRole(preferred) == "Survivor" then
		first = preferred
	elseif lastPosition then
		first = closestSurvivor(lastPosition)
	end
	setTarget(player, watcher, first or pickRelative(watcher, 1))
end

-- 역할이 Spectator가 되면 관전 시작을 예약한다. 잡혔으면 잡힘 연출이 끝난 뒤에.
local function scheduleStart(player: Player): ()
	nextStartToken += 1
	local token = nextStartToken
	startTokens[player] = token

	-- 잡힌 캐릭터는 잡힘 연출 중에 지워지므로 위치와 그때 가장 가까운 생존자를 지금 기록한다. 중간 입장이면 캐릭터가 없다.
	local parts = CharacterParts.get(player)
	local lastPosition = parts and parts.rootPart.Position
	local preferred = if lastPosition then closestSurvivor(lastPosition) else nil
	local waitTime = if MatchState.getSurvivorState(player) == "Caught" then Match.CaughtEffectTime else 0
	task.delay(waitTime, function()
		if startTokens[player] == token then
			startTokens[player] = nil
			start(player, preferred, lastPosition)
		end
	end)
end

local function stop(player: Player, reason: string): ()
	startTokens[player] = nil
	local watcher = watchers[player]
	if not watcher then
		return
	end
	watchers[player] = nil
	disconnectTarget(watcher)
	watcher.switchToken += 1
	player:SetAttribute(Attribute.Spectating, nil)
	player:SetAttribute(Attribute.SpectateTarget, nil)
	player.ReplicationFocus = nil
	print(`[Spectate] {player.Name} 관전 끝 ({reason})`)
end

local function onSpectateCycle(player: Player, step: unknown): ()
	if typeof(step) ~= "number" or (step ~= 1 and step ~= -1) then
		return
	end
	local watcher = watchers[player]
	if not watcher then
		return
	end
	local target = pickRelative(watcher, step)
	if target and (target ~= watcher.target or watcher.switchPending) then
		setTarget(player, watcher, target)
	end
end

-- 관전자 채팅 --------------------------------------------------------------------------------------------------

local function findTextSource(channel: TextChannel, userId: number): TextSource?
	for _, child in channel:GetChildren() do
		if child:IsA("TextSource") and child.UserId == userId then
			return child
		end
	end
	return nil
end

-- 관전자 채널 회원을 역할에 맞춘다. AddUserAsync가 멈추므로 그 사이 역할이 또 바뀌었으면 한 번 더 맞춘다.
local function syncChat(player: Player): ()
	local channel = spectatorChannel
	if not channel then
		return
	end
	if chatSyncing[player] then
		chatDirty[player] = true
		return
	end
	chatSyncing[player] = true
	repeat
		chatDirty[player] = nil
		local shouldJoin = isSpectator(player)
		local source = findTextSource(channel, player.UserId)
		if shouldJoin and not source then
			local ok, added = pcall(channel.AddUserAsync, channel, player.UserId)
			if ok and added then
				print(`[Spectate] {player.Name} 관전자 채팅 참가`)
			else
				warn(`[Spectate] {player.Name}을(를) 관전자 채팅에 넣지 못했습니다: {added}`)
			end
		elseif not shouldJoin and source then
			source:Destroy()
			print(`[Spectate] {player.Name} 관전자 채팅에서 나감`)
		end
	until not chatDirty[player]
	chatSyncing[player] = nil
end

-- 관전자 채널이 아닌 채널: 관전자가 보낸 메시지는 관전자에게만 전달한다. 시스템 메시지(보낸 사람 없음)는 모두에게.
local function shouldDeliver(message: TextChatMessage, recipient: TextSource): boolean
	local sender = message.TextSource :: TextSource?
	local senderPlayer = sender and Players:GetPlayerByUserId(sender.UserId)
	if not senderPlayer or not isSpectator(senderPlayer) then
		return true
	end
	local recipientPlayer = Players:GetPlayerByUserId(recipient.UserId)
	return recipientPlayer ~= nil and isSpectator(recipientPlayer)
end

local function guardChannel(instance: Instance): ()
	if instance:IsA("TextChannel") and instance ~= spectatorChannel then
		instance.ShouldDeliverCallback = shouldDeliver
	end
end

local function setupChat(): ()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn(
			"[Spectate] TextChatService.ChatVersion이 TextChatService가 아니라 관전자 채팅을 나누지 못했습니다"
		)
		return
	end
	local channels = TextChatService:WaitForChild("TextChannels", TEXT_CHANNELS_WAIT)
	if not channels then
		warn("[Spectate] TextChatService.TextChannels가 없어 관전자 채팅을 만들지 못했습니다")
		return
	end
	local channel = Instance.new("TextChannel")
	channel.Name = SpectateState.ChatChannelName
	channel.Parent = channels
	spectatorChannel = channel

	-- 귓속말 채널은 귓속말을 시작할 때 새로 생긴다.
	for _, child in channels:GetChildren() do
		guardChannel(child)
	end
	channels.ChildAdded:Connect(guardChannel)
	for _, player in Players:GetPlayers() do
		task.spawn(syncChat, player)
	end
	print(`[Spectate] 관전자 채팅 채널: TextChatService.TextChannels.{channel.Name}`)
end

-- --------------------------------------------------------------------------------------------------------------

local function onRoleChanged(player: Player): ()
	if isSpectator(player) then
		if not watchers[player] and not startTokens[player] then
			scheduleStart(player)
		end
	else
		stop(player, "스테이지 끝")
	end
	refreshTargets(nil)
	task.spawn(syncChat, player)
end

local function watchPlayer(player: Player): ()
	player:GetAttributeChangedSignal(Attribute.Role):Connect(function()
		onRoleChanged(player)
	end)
	-- 다른 서비스(MatchService)가 먼저 역할을 정했을 수 있으므로 지금 상태로 한 번 맞춘다.
	onRoleChanged(player)
end

function SpectateService.Init(): () end

function SpectateService.Start(): ()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(watchPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		stop(player, "나감")
		refreshTargets(player)
		local channel = spectatorChannel
		local source = channel and findTextSource(channel, player.UserId)
		if source then
			source:Destroy()
		end
		chatSyncing[player] = nil
		chatDirty[player] = nil
	end)

	RemoteHandler.connect("SpectateCycle", onSpectateCycle)
	task.spawn(setupChat)
end

return SpectateService
