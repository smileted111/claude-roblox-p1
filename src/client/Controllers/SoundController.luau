--!strict
-- SoundController: 효과음·배경음 (GDD 12장, 13.2). 배경음과 심장 박동은 나중 단계에서.
--
-- 효과음 ID는 Config.Assets.Sounds에 있다. 빈 문자열이면 아직 자리만 있는 것이라 아무것도 재생하지 않는다.
-- 다른 컨트롤러는 Start 이후에 SoundController.play(키)를 부른다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Types = require(ReplicatedStorage.Shared.Types)

local SoundController = {}

local sounds: { [Types.SoundKey]: Sound } = {}

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

function SoundController.Init(): () end

function SoundController.Start(): () end

return SoundController
