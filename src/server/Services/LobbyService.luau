--!strict
-- LobbyService: 로비 — 같이 하기 대기열, 혼자 하기, 혼자 하기 서버 판별 (GDD 3장, 5장, 13.1). GDD 13.2 목록 밖에 추가.
--
-- 로비는 Workspace.Lobby (Studio에서 만든 블록, Rojo가 관리하지 않음). 스폰(SpawnLocation)과 발판 두 개가 있다.
--   같이 하기 (LobbyTogether 태그 발판): 발판 위(Config.Match.QueueZoneHeight)에 서 있는 사람이 대기열이다.
--     MatchService가 대기열 인원으로 매치를 시작한다. 혼자 Config.Match.SoloOfferWaitTime초 있으면
--     "혼자 시작할까요?"를 묻는다 (SoloOffer 리모트, 답은 LobbyRequest AcceptSolo·DeclineSolo).
--   혼자 하기 (LobbySolo 태그 발판): "혼자 하기" 프롬프트(서버가 발판 거리를 다시 검사) → TeleportService:ReserveServer로 이 플레이스의 예약 서버를 만들어
--     TeleportData {Solo = true}와 함께 보낸다. 그 서버는 혼자 하기 서버다 (중간 합류 불가: 두 번째 사람은 내보냄).
--   Studio에서는 다른 서버로 보낼 수 없어서, 이 서버에서 그 사람 혼자 매치를 시작한다 (takeStudioSoloRequest).
-- 혼자 하기 서버에서 "로비로 돌아가기"를 누르면 일반 서버로 보낸다 (teleportToPublic).
-- 공개: ReplicatedStorage Attribute QueueCount(같이 하기 대기 인원), SoloServer(혼자 하기 서버인가).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local MapTags = require(ReplicatedStorage.Shared.MapTags)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local PromptUtil = require(ReplicatedStorage.Shared.Util.PromptUtil)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local LanguageService = require(script.Parent.LanguageService)

local LOBBY_FOLDER = "Lobby" -- Workspace.Lobby

local LobbyService = {}

local soloServer = false
local soloOwner: Player? = nil
local studioSoloRequest: Player? = nil
local teleporting: { [Player]: boolean } = {}
local offerPending: { [Player]: boolean } = {}

local function lobbyParts(tag: string): { BasePart }
	local parts: { BasePart } = {}
	local lobby = Workspace:FindFirstChild(LOBBY_FOLDER)
	if not lobby then
		return parts
	end
	for _, descendant in lobby:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:HasTag(tag) then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- position이 발판 위(발판 윗면부터 QueueZoneHeight)에 있는가
local function isOnPad(pad: BasePart, position: Vector3): boolean
	local localPosition = pad.CFrame:PointToObjectSpace(position)
	local half = pad.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Z) <= half.Z
		and localPosition.Y >= -half.Y
		and localPosition.Y <= half.Y + Match.QueueZoneHeight
end

local function notice(player: Player, key: Types.NoticeKey): ()
	Remotes.get("Notice"):FireClient(player, key)
end

--------------------------------------------------------------------------------
-- 혼자 하기

local function teleportSolo(player: Player): ()
	if teleporting[player] or soloServer then
		return
	end
	if RunService:IsStudio() then
		studioSoloRequest = player
		notice(player, "SoloStudio")
		print(`[Lobby] {player.Name} 혼자 하기 (Studio라 이 서버에서 시작)`)
		return
	end
	teleporting[player] = true
	notice(player, "SoloTeleporting")
	task.spawn(function()
		local ok, err = pcall(function()
			local code = TeleportService:ReserveServer(game.PlaceId)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = code
			options:SetTeleportData({ Solo = true })
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if not ok then
			teleporting[player] = nil
			warn(`[Lobby] {player.Name} 혼자 하기 서버로 보내지 못함: {err}`)
			notice(player, "SoloTeleportFailed")
		else
			print(`[Lobby] {player.Name} → 혼자 하기 서버로 이동`)
		end
	end)
end

-- 혼자 하기를 요청한 사람이 로비에 있으면 (매치 참가 중이 아니면) 혼자 하기로 보낸다.
function LobbyService.requestSolo(player: Player): ()
	if MatchState.getRole(player) ~= nil then
		return
	end
	teleportSolo(player)
end

-- Studio에서 혼자 하기를 누른 사람 (한 번 꺼내면 지운다). MatchService가 그 사람 혼자 매치를 시작한다.
function LobbyService.takeStudioSoloRequest(): Player?
	local player = studioSoloRequest
	studioSoloRequest = nil
	if player and player.Parent == Players then
		return player
	end
	return nil
end

-- 일반 서버로 보낸다 (혼자 하기 서버의 "로비로 돌아가기").
function LobbyService.teleportToPublic(player: Player): ()
	if RunService:IsStudio() or teleporting[player] then
		return
	end
	teleporting[player] = true
	task.spawn(function()
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player })
		end)
		if not ok then
			teleporting[player] = nil
			warn(`[Lobby] {player.Name} 일반 서버로 보내지 못함: {err}`)
			notice(player, "SoloTeleportFailed")
		end
	end)
end

--------------------------------------------------------------------------------
-- 같이 하기 대기열

function LobbyService.isSoloServer(): boolean
	return soloServer
end

-- 같이 하기 대기열: 매치에 참가하지 않았고 같이 하기 발판 위에 서 있는 사람. 혼자 하기 서버는 그 사람 하나.
function LobbyService.getQueue(): { Player }
	local queue: { Player } = {}
	if soloServer then
		if soloOwner and soloOwner.Parent == Players then
			table.insert(queue, soloOwner)
		end
		return queue
	end
	local pads = lobbyParts(MapTags.LobbyTogether)
	for _, player in Players:GetPlayers() do
		local parts = if MatchState.getRole(player) == nil and not teleporting[player]
			then CharacterParts.get(player)
			else nil
		if parts then
			for _, pad in pads do
				if isOnPad(pad, parts.rootPart.Position) then
					table.insert(queue, player)
					break
				end
			end
		end
	end
	table.sort(queue, function(a: Player, b: Player): boolean
		return a.UserId < b.UserId
	end)
	return queue
end

function LobbyService.publishQueueCount(count: number): ()
	if MatchState.getQueueCount() ~= count then
		ReplicatedStorage:SetAttribute(MatchState.Attribute.QueueCount, count)
	end
end

-- 같이 하기 구역에 혼자 오래 있는 사람에게 혼자 하기를 제안한다 (GDD 5장).
function LobbyService.offerSolo(player: Player, waitedSeconds: number): ()
	if offerPending[player] then
		return
	end
	offerPending[player] = true
	Remotes.get("SoloOffer"):FireClient(player, waitedSeconds)
	print(`[Lobby] {player.Name}에게 혼자 하기 제안 ({waitedSeconds}초 혼자 대기)`)
end

-- 캐릭터를 같이 하기 발판 위로 옮긴다 (결과 화면의 "다시 하기").
local function moveToQueue(player: Player): ()
	local pad = lobbyParts(MapTags.LobbyTogether)[1]
	local parts = CharacterParts.get(player)
	if not pad or not parts or MatchState.getRole(player) ~= nil then
		return
	end
	local offset = Vector3.new((math.random() - 0.5) * pad.Size.X * 0.6, 0, (math.random() - 0.5) * pad.Size.Z * 0.6)
	local standHeight = pad.Size.Y / 2 + parts.humanoid.HipHeight + parts.rootPart.Size.Y / 2
	parts.character:PivotTo(CFrame.new(pad.Position + offset + Vector3.new(0, standHeight, 0)))
end

local function onLobbyRequest(player: Player, action: unknown): ()
	if action == "JoinQueue" then
		moveToQueue(player)
	elseif action == "AcceptSolo" then
		if offerPending[player] then
			offerPending[player] = nil
			LobbyService.requestSolo(player)
		end
	elseif action == "DeclineSolo" then
		offerPending[player] = nil
	end
end

-- 제안에 답하기 전에 대기열을 떠났으면 제안을 지운다 (MatchService가 대기 중에 부름).
function LobbyService.clearOffer(player: Player): ()
	offerPending[player] = nil
end

--------------------------------------------------------------------------------

local function setupSoloPads(): ()
	for _, pad in lobbyParts(MapTags.LobbySolo) do
		local prompt = PromptUtil.new()
		prompt.Name = "SoloPrompt"
		prompt.ActionText = Strings.Lobby.Solo
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = Match.SoloPromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Enabled = not soloServer
		prompt.Triggered:Connect(function(player: Player)
			-- 다른 프롬프트처럼 서버가 보는 위치로 거리를 다시 잰다 (docs/release-review.md 코드 #4).
			local parts = CharacterParts.get(player)
			local reach = Match.SoloPromptDistance + Match.SoloPromptDistanceSlack
			if not parts or (parts.rootPart.Position - pad.Position).Magnitude > reach then
				print(`[Lobby] {player.Name} 혼자 하기 거절: 발판에서 멂`)
				return
			end
			LobbyService.requestSolo(player)
		end)
		prompt.Parent = pad
	end
end

-- 혼자 하기 서버인가: 예약 서버이고 첫 사람이 TeleportData {Solo = true}로 들어옴.
local function checkSoloServer(player: Player): ()
	if soloOwner then
		if soloServer and player ~= soloOwner then
			player:Kick(LanguageService.stringsFor(player).System.SoloServerFull)
		end
		return
	end
	soloOwner = player
	local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	soloServer = isReserved and typeof(teleportData) == "table" and (teleportData :: any).Solo == true
	ReplicatedStorage:SetAttribute(MatchState.Attribute.SoloServer, if soloServer then true else nil)
	if soloServer then
		print(`[Lobby] 혼자 하기 서버 · {player.Name}`)
		for _, pad in lobbyParts(MapTags.LobbySolo) do
			local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = false
			end
		end
	end
end

function LobbyService.Init(): () end

function LobbyService.Start(): ()
	if not Workspace:FindFirstChild(LOBBY_FOLDER) then
		warn(`[Lobby] Workspace.{LOBBY_FOLDER}가 없어 같이 하기·혼자 하기 구역이 없습니다`)
	end
	setupSoloPads()
	Players.PlayerAdded:Connect(checkSoloServer)
	for _, player in Players:GetPlayers() do
		checkSoloServer(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		teleporting[player] = nil
		offerPending[player] = nil
		if studioSoloRequest == player then
			studioSoloRequest = nil
		end
	end)
	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		teleporting[player] = nil
		warn(`[Lobby] {player.Name} 이동 실패 ({result.Name}): {message}`)
		notice(player, "SoloTeleportFailed")
	end)
	RemoteHandler.connect("LobbyRequest", onLobbyRequest)
end

return LobbyService
