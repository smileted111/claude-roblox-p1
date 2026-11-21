--!strict
-- VoteService: 스테이지마다 맵 투표, 첫 스테이지는 화면 모드 투표도 (2026-11-21 사용자 요청). GDD 3.1, 12장. GDD 13.2 목록 밖에 추가.
--
-- MatchService가 참가자가 정해진 뒤(같이 하기·혼자 하기) 스테이지마다 VoteService.run을 부른다.
--   투표 단계(Phase Voting)를 Config.Match.VoteTime초 동안 연다. 참가자(Player Attribute Voter)만 CastVote 리모트로
--   맵(이번 매치에서 아직 플레이하지 않은 맵만)과 화면 모드(withMode일 때)를 고른다. 다시 보내면 표를 바꾼다.
--   참가자가 모두 나가면 일찍 끝낸다.
-- 결과: 가장 많이 투표된 맵, 같으면 그중 무작위 (아무도 투표하지 않으면 고를 수 있는 맵 중 무작위).
--   화면 모드는 가장 많이 투표된 모드. 같거나 아무도 투표하지 않으면 로비에서 고른 모드 다수결(LobbyService.decideMode),
--   그것도 같으면 Config.VisualModes.Default.
-- 공개: ReplicatedStorage VoteMaps·VotePlayed·VoteMapCounts·VoteModeCounts, Player Voter·VoteMap·VoteMode (MatchState).
--   투표가 끝나면 모두 지운다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local VisualModes = require(ReplicatedStorage.Shared.Config.VisualModes)
local PhaseTimer = require(script.Parent.Parent.Util.PhaseTimer)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local LobbyService = require(script.Parent.LobbyService)

local Attribute = MatchState.Attribute

type Ballot = {
	voters: { [Player]: boolean },
	maps: { Types.StageId }, -- 고를 수 있는 맵
	withMode: boolean,
	mapVotes: { [Player]: Types.StageId },
	modeVotes: { [Player]: Types.VisualMode },
}

local VoteService = {}

local random = Random.new()
local current: Ballot? = nil

local function countVotes<T>(votes: { [Player]: T }): { [string]: number }
	local counts: { [string]: number } = {}
	for player, value in votes do
		if player.Parent == Players then
			local key = value :: any
			counts[key] = (counts[key] or 0) + 1
		end
	end
	return counts
end

-- 가장 많은 표를 받은 키들 (표가 없으면 빈 배열)
local function leaders(keys: { string }, counts: { [string]: number }): { string }
	local best = 0
	local result: { string } = {}
	for _, key in keys do
		local count = counts[key] or 0
		if count > best then
			best = count
			result = { key }
		elseif count == best and count > 0 then
			table.insert(result, key)
		end
	end
	return result
end

local function publish(ballot: Ballot): ()
	ReplicatedStorage:SetAttribute(
		Attribute.VoteMapCounts,
		MatchState.encodeCounts(ballot.maps :: { any }, countVotes(ballot.mapVotes))
	)
	if ballot.withMode then
		ReplicatedStorage:SetAttribute(
			Attribute.VoteModeCounts,
			MatchState.encodeCounts(VisualModes.Modes :: { any }, countVotes(ballot.modeVotes))
		)
	end
end

local function onCastVote(player: Player, kind: unknown, value: unknown): ()
	local ballot = current
	if not ballot or not ballot.voters[player] or typeof(value) ~= "string" then
		return
	end
	if kind == "Map" then
		local stageId = value :: Types.StageId
		if not table.find(ballot.maps, stageId) or ballot.mapVotes[player] == stageId then
			return
		end
		ballot.mapVotes[player] = stageId
		player:SetAttribute(Attribute.VoteMap, stageId)
	elseif kind == "Mode" then
		local mode = value :: Types.VisualMode
		if not ballot.withMode or not table.find(VisualModes.Modes, mode) or ballot.modeVotes[player] == mode then
			return
		end
		ballot.modeVotes[player] = mode
		player:SetAttribute(Attribute.VoteMode, mode)
	else
		return
	end
	publish(ballot)
end

local function clear(ballot: Ballot): ()
	for player in ballot.voters do
		player:SetAttribute(Attribute.Voter, nil)
		player:SetAttribute(Attribute.VoteMap, nil)
		player:SetAttribute(Attribute.VoteMode, nil)
	end
	for _, name in { Attribute.VoteMaps, Attribute.VotePlayed, Attribute.VoteMapCounts, Attribute.VoteModeCounts } do
		ReplicatedStorage:SetAttribute(name, nil)
	end
	current = nil
end

local function describe(keys: { string }, counts: { [string]: number }): string
	local parts: { string } = {}
	for _, key in keys do
		table.insert(parts, `{key} {counts[key] or 0}`)
	end
	return table.concat(parts, " · ")
end

-- 투표를 열고 끝날 때까지 기다린다. 고른 맵과 (withMode면) 화면 모드를 돌려준다.
-- maps: 고를 수 있는 맵 (1개 이상), played: 이번 매치에서 이미 플레이한 맵 (화면에 흐리게 보여줌).
function VoteService.run(
	voters: { Player },
	maps: { Types.StageId },
	played: { Types.StageId },
	withMode: boolean
): (Types.StageId, Types.VisualMode?)
	assert(#maps > 0, "투표할 맵이 없습니다")
	if current then
		clear(current)
	end
	local ballot: Ballot = {
		voters = {},
		maps = table.clone(maps),
		withMode = withMode,
		mapVotes = {},
		modeVotes = {},
	}
	current = ballot
	for _, player in voters do
		ballot.voters[player] = true
		player:SetAttribute(Attribute.Voter, true)
	end
	-- 클라이언트가 Phase를 받았을 때 투표 내용이 이미 있도록 단계보다 먼저 쓴다.
	ReplicatedStorage:SetAttribute(Attribute.VoteMaps, MatchState.encodeList(maps :: { any }))
	ReplicatedStorage:SetAttribute(Attribute.VotePlayed, MatchState.encodeList(played :: { any }))
	publish(ballot)

	PhaseTimer.run("Voting", Match.VoteTime, function(): boolean
		for player in ballot.voters do
			if player.Parent == Players then
				return false
			end
		end
		return true
	end)

	local mapCounts = countVotes(ballot.mapVotes)
	local topMaps = leaders(maps :: { any }, mapCounts)
	local pool = if #topMaps > 0 then topMaps else maps :: { any }
	local stageId = pool[random:NextInteger(1, #pool)] :: Types.StageId

	local mode: Types.VisualMode? = nil
	local modeLog = ""
	if withMode then
		local modeCounts = countVotes(ballot.modeVotes)
		local topModes = leaders(VisualModes.Modes :: { any }, modeCounts)
		if #topModes == 1 then
			mode = topModes[1] :: Types.VisualMode
		else
			local active: { Player } = {}
			for player in ballot.voters do
				if player.Parent == Players then
					table.insert(active, player)
				end
			end
			mode = LobbyService.decideMode(active)
		end
		modeLog = ` · 화면 모드 {mode} ({describe(VisualModes.Modes :: { any }, modeCounts)})`
	end
	print(
		`[Vote] 맵 {stageId} ({Strings.Stages[stageId]}) · 표 {describe(maps :: { any }, mapCounts)}{modeLog}`
			.. (if #played > 0 then ` · 플레이한 맵 {table.concat(played :: { any }, ", ")}` else "")
	)
	clear(ballot)
	return stageId, mode
end

function VoteService.Init(): () end

function VoteService.Start(): ()
	RemoteHandler.connect("CastVote", onCastVote)
	Players.PlayerRemoving:Connect(function(player: Player)
		local ballot = current
		if ballot and ballot.voters[player] then
			ballot.mapVotes[player] = nil
			ballot.modeVotes[player] = nil
			publish(ballot)
		end
	end)
end

return VoteService
