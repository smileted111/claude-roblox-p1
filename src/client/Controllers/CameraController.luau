--!strict
-- CameraController: 카메라 거리와 높이 제한 (GDD 11장, 13.2). 생존자·추격자 모두 Roblox 기본 3인칭 카메라를 쓴다.
-- 추격자(Player Attribute Role = Chaser)는 최대 카메라 거리를 Config.Camera.ChaserMaxZoom으로 줄여 멀리서 내려다보며
--   생존자를 찾지 못하게 한다. 지금 거리가 더 멀면 Roblox 카메라가 그 거리로 당긴다.
--   역할이 바뀌면 원래 값(StarterPlayer.CameraMaxZoomDistance)으로 되돌린다.
-- 높이 제한 (GDD R6): 스테이지 안(역할이 있고 맵이 불러와져 CameraCeiling이 있음)에서는 Roblox 카메라가 자리를 정한
--   직후(RenderPriority.Camera + 1) 카메라가 CameraCeiling(월드 Y)보다 높으면 초점과의 거리는 그대로 두고 그 높이까지 내려
--   비스듬히 보게 한다 (초점 쪽으로 당기면 점프할 때 카메라가 머리에 붙었다 떨어져 끊겨 보였다). 내린 자리가 벽 뒤면
--   초점에서 레이캐스트로 벽 앞까지 당겨 벽을 뚫고 보지 않게 한다. 벽(높이 14) 위로 올라가 벽 너머를 내려다볼 수 없다.
--   관전 카메라도 같다. 잡힘 연출 카메라(Util/CaughtCinematic)는 이보다 뒤에 돌아 그대로 둔다.
-- 관전 카메라 대상은 SpectateController가 맡는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Camera = require(ReplicatedStorage.Shared.Config.Camera)
local MatchState = require(ReplicatedStorage.Shared.MatchState)

local CEILING_STEP_NAME = "StageCameraCeiling"
local WALL_MARGIN = 0.6 -- 벽에 막힐 때 벽 앞에 남기는 거리 (스터드)

local localPlayer = Players.LocalPlayer

local CameraController = {}

local defaultMaxZoom = 128 -- Init에서 StarterPlayer 값으로 바꾼다
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function apply(): ()
	local maxZoom = if MatchState.getRole(localPlayer) == "Chaser" then Camera.ChaserMaxZoom else defaultMaxZoom
	if localPlayer.CameraMaxZoomDistance ~= maxZoom then
		localPlayer.CameraMaxZoomDistance = maxZoom
	end
end

-- 카메라가 높이 제한보다 높으면 같은 거리에서 제한 높이로 내리고 초점을 보게 한다.
local function clampHeight(): ()
	local ceiling = MatchState.getCameraCeiling()
	local camera = Workspace.CurrentCamera
	if not ceiling or not camera or camera.CameraType == Enum.CameraType.Scriptable then
		return
	end
	if MatchState.getRole(localPlayer) == nil then
		return
	end
	local position = camera.CFrame.Position
	if position.Y <= ceiling then
		return
	end
	local focus = camera.Focus.Position
	local offset = position - focus
	local rise = ceiling - focus.Y -- 초점 위로 올라갈 수 있는 높이
	local horizontal = Vector3.new(offset.X, 0, offset.Z)
	local direction = if horizontal.Magnitude > 1e-3
		then horizontal.Unit
		else -Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
	local newPosition: Vector3
	if rise > 0 then
		local distance = offset.Magnitude
		local flat = math.sqrt(math.max(distance * distance - rise * rise, 0))
		newPosition = focus + direction * flat + Vector3.new(0, rise, 0)
	else
		newPosition = Vector3.new(position.X, ceiling, position.Z)
	end
	-- 옮긴 자리가 벽 뒤면 벽 앞으로 당긴다 (자기 캐릭터·괴물은 무시).
	local character = localPlayer.Character
	local monsters = Workspace:FindFirstChild("Monsters")
	local exclude: { Instance } = {}
	if character then
		table.insert(exclude, character)
	end
	if monsters then
		table.insert(exclude, monsters)
	end
	rayParams.FilterDescendantsInstances = exclude
	local toCamera = newPosition - focus
	if toCamera.Magnitude > 0.05 then
		local hit = Workspace:Raycast(focus, toCamera, rayParams)
		if hit then
			newPosition = focus + toCamera.Unit * math.max(hit.Distance - WALL_MARGIN, 0.5)
		end
	end
	camera.CFrame = CFrame.lookAt(newPosition, focus)
end

function CameraController.Init(): ()
	defaultMaxZoom = localPlayer.CameraMaxZoomDistance
end

function CameraController.Start(): ()
	localPlayer:GetAttributeChangedSignal(MatchState.Attribute.Role):Connect(apply)
	apply()
	RunService:BindToRenderStep(CEILING_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, clampHeight)
end

return CameraController
