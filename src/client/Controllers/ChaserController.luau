--!strict
-- ChaserController: 추격자 조작 (공격·스킬) (GDD 6.1, 7장, 13.2). 공격은 S1-5, 스킬은 S3-3에서.
--
-- 숨는 곳의 "열어보기" 프롬프트를 추격자에게만, 추격 단계에서만 켠다. 누르는 시간(ChaserOpenTime)과 판정은 서버(HideService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideSpotState = require(ReplicatedStorage.Shared.HideSpotState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local HideSpotWatcher = require(script.Parent.Parent.Util.HideSpotWatcher)

local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local ChaserController = {}

local function refreshOpenPrompts(): ()
	local canOpen = MatchState.getRole(localPlayer) == "Chaser" and HideSpotState.canOpenInPhase(MatchState.getPhase())
	for _, spot in HideSpotWatcher.getSpots() do
		local openPrompt = HideSpotWatcher.findPrompt(spot, HideSpotState.Prompt.Open)
		if openPrompt then
			openPrompt.Enabled = canOpen
		end
	end
end

function ChaserController.Init(): () end

function ChaserController.Start(): ()
	localPlayer:GetAttributeChangedSignal(Attribute.Role):Connect(refreshOpenPrompts)
	ReplicatedStorage:GetAttributeChangedSignal(Attribute.Phase):Connect(refreshOpenPrompts)
	HideSpotWatcher.subscribe(refreshOpenPrompts)
end

return ChaserController
