--!strict
-- SoundController: 효과음·배경음악 (GDD 12장, 13.2). 심장 박동은 나중 단계에서.
--
-- 효과음 ID는 Config.Assets.Sounds에 있다. 빈 문자열이면 아직 자리만 있는 것이라 아무것도 재생하지 않는다.
-- 다른 컨트롤러는 Start 이후에 SoundController.play(키)를 부른다.
--
-- 배경음악 (Config.Assets.StageMusic, 2026-11-22 사용자 요청: 학교·폐병원·지하 연구소·놀이공원): 내가 스테이지 안에 있는 동안 그 맵의 곡을
--   반복 재생한다. 스테이지 안 = 역할이 있고(관전 중 포함) 스테이지가 있으며 투표·역할 공개 단계가 아니고, 로비로 돌아가는
--   로딩(Loading "Lobby")이 아님. 켜고 끌 때 Config.Assets.MusicFadeTime초 동안 음량을 올리고 내린다.
--   클라이언트에서 만든 Sound라 이 플레이어에게만 들리고 게임 판정(괴물이 듣는 소리)과는 상관없다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Types = require(ReplicatedStorage.Shared.Types)

local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local SoundController = {}

local sounds: { [Types.SoundKey]: Sound } = {}
local musicStage: Types.StageId? = nil -- 지금 틀고 있는 곡의 맵
local music: Sound? = nil

local function getSound(key: Types.SoundKey, soundId: string): Sound
	local existing = sounds[key]
	if existing then
		return existing
	end
	-- 클라이언트에서 만든 Sound라 이 플레이어에게만 들린다.
	local sound = Instance.new("Sound")
	sound.Name = key
	sound.SoundId = soundId
	sound.Parent = SoundService
	sounds[key] = sound
	return sound
end

-- 이 플레이어 화면에서만 들리는 효과음을 한 번 재생한다.
function SoundController.play(key: Types.SoundKey): ()
	local soundId = Assets.Sounds[key]
	if soundId == "" then
		return
	end
	getSound(key, soundId):Play()
end

--------------------------------------------------------------------------------
-- 배경음악

-- 지금 들어야 할 곡의 맵 (스테이지 밖이거나 곡이 없는 맵이면 nil)
local function wantedMusicStage(): Types.StageId?
	local stageId = MatchState.getStageId()
	local phase = MatchState.getPhase()
	if
		not stageId
		or MatchState.getRole(localPlayer) == nil
		or phase == "Waiting"
		or phase == "Voting"
		or phase == "RoleReveal"
		or MatchState.getLoading() == "Lobby"
	then
		return nil
	end
	return if Assets.StageMusic[stageId] then stageId else nil
end

local function fadeOut(sound: Sound): ()
	local tween = TweenService:Create(sound, TweenInfo.new(Assets.MusicFadeTime), { Volume = 0 })
	tween.Completed:Once(function()
		sound:Destroy()
	end)
	tween:Play()
end

local function refreshMusic(): ()
	local wanted = wantedMusicStage()
	if wanted == musicStage then
		return
	end
	local previous = music
	if previous then
		fadeOut(previous)
	end
	music = nil
	musicStage = wanted
	local def = if wanted then Assets.StageMusic[wanted] else nil
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = `StageMusic_{wanted}`
	sound.SoundId = def.SoundId
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(Assets.MusicFadeTime), { Volume = def.Volume }):Play()
	music = sound
end

function SoundController.Init(): () end

function SoundController.Start(): ()
	for _, name in { Attribute.Phase, Attribute.StageId, Attribute.Loading } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refreshMusic)
	end
	localPlayer:GetAttributeChangedSignal(Attribute.Role):Connect(refreshMusic)
	refreshMusic()
end

return SoundController
