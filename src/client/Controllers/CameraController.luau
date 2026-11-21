--!strict
-- CameraController: 카메라 거리 (GDD 11장, 13.2). 생존자·추격자 모두 Roblox 기본 3인칭 카메라를 쓴다.
-- 추격자(Player Attribute Role = Chaser)는 최대 카메라 거리를 Config.Camera.ChaserMaxZoom으로 줄여 멀리서 내려다보며
--   생존자를 찾지 못하게 한다. 지금 거리가 더 멀면 Roblox 카메라가 그 거리로 당긴다.
--   역할이 바뀌면 원래 값(StarterPlayer.CameraMaxZoomDistance)으로 되돌린다.
-- 관전 카메라 대상은 SpectateController가 맡는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camera = require(ReplicatedStorage.Shared.Config.Camera)
local MatchState = require(ReplicatedStorage.Shared.MatchState)

local localPlayer = Players.LocalPlayer

local CameraController = {}

local defaultMaxZoom = 128 -- Init에서 StarterPlayer 값으로 바꾼다

local function apply(): ()
	local maxZoom = if MatchState.getRole(localPlayer) == "Chaser" then Camera.ChaserMaxZoom else defaultMaxZoom
	if localPlayer.CameraMaxZoomDistance ~= maxZoom then
		localPlayer.CameraMaxZoomDistance = maxZoom
	end
end

function CameraController.Init(): ()
	defaultMaxZoom = localPlayer.CameraMaxZoomDistance
end

function CameraController.Start(): ()
	localPlayer:GetAttributeChangedSignal(MatchState.Attribute.Role):Connect(apply)
	apply()
end

return CameraController
