--!strict
-- 잡힘 연출 카메라 (Config.Catch.CaughtEffect, 2026-11-21 사용자 요청: 잡힐 때 더 생동감 있게). SurvivorController가 부른다.
-- 잡히는 순간: 흰 번쩍임 + 카메라 흔들림(점점 줄어듦).
-- 그 뒤 CinematicTime초 동안 카메라가 지금 자리에서 잡은 괴물(추격자)의 얼굴 앞으로 비스듬히 돌아가며 시야각을 좁혀
--   당겨 보이게 한다 (괴물이 덮치며 뛰어오르고, 내 캐릭터가 뒤로 넘어지는 모습은 서버가 움직임). 끝나면 암전(ScreenEffect).
-- 카메라는 Scriptable로 바꿨다가 화면이 완전히 어두워진 뒤 원래대로 돌린다 (관전 카메라는 SpectateController).
-- 피·신체 훼손 표현은 없다 (GDD 12장).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local ScreenEffect = require(script.Parent.ScreenEffect)

local STEP_NAME = "CaughtCinematic"
local BASE_HEAD = 1.2 -- 괴물 머리 크기 기준 (Config.MonsterLooks.BaseHeadSize와 같은 값)

local localPlayer = Players.LocalPlayer
local random = Random.new()

local CaughtCinematic = {}

local playingId = 0

local function easeOutCubic(t: number): number
	local inverse = 1 - t
	return 1 - inverse * inverse * inverse
end

-- 잡은 쪽 머리 위치와 머리 크기 비율. 모델이 사라졌으면 마지막 위치
local function catcherHead(catcher: Model?, fallback: Vector3): (Vector3, number)
	if catcher and catcher.Parent then
		local head = catcher:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position, math.clamp(head.Size.Y / BASE_HEAD, 0.6, 2)
		end
		return catcher:GetPivot().Position + Vector3.new(0, 2, 0), 1
	end
	return fallback + Vector3.new(0, 2, 0), 1
end

-- 잡힘 연출을 시작한다. catcher는 잡은 괴물·추격자 모델 (없으면 position 쪽을 본다).
function CaughtCinematic.play(catcher: Model?, position: Vector3): ()
	local camera = Workspace.CurrentCamera
	local character = localPlayer.Character
	local myHead = character and character:FindFirstChild("Head")
	if not camera or not myHead or not myHead:IsA("BasePart") then
		ScreenEffect.blackout(Catch.CaughtEffect.FadeInTime, Match.CaughtEffectTime, Catch.CaughtEffect.FadeOutTime)
		return
	end
	local effect = Catch.CaughtEffect
	playingId += 1
	local id = playingId
	local startCFrame = camera.CFrame
	local startFov = camera.FieldOfView
	local startType = camera.CameraType
	local victimHead = myHead.Position
	local lastTarget, scale = catcherHead(catcher, position)
	camera.CameraType = Enum.CameraType.Scriptable
	ScreenEffect.flash(effect.ImpactFlashColor, 0.25, 0.35)
	-- 연출이 끝나면 암전하고, 완전히 어두워진 뒤 카메라를 돌려준다.
	task.delay(effect.CinematicTime, function()
		if id == playingId then
			ScreenEffect.blackout(effect.FadeInTime, Match.CaughtEffectTime - effect.CinematicTime, effect.FadeOutTime)
		end
	end)

	local startedAt = os.clock()
	local finishAt = effect.CinematicTime + effect.FadeInTime
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 2, function()
		local elapsed = os.clock() - startedAt
		if id ~= playingId or elapsed >= finishAt then
			RunService:UnbindFromRenderStep(STEP_NAME)
			if id == playingId then
				camera.CameraType = if startType == Enum.CameraType.Scriptable
					then Enum.CameraType.Custom
					else startType
				camera.FieldOfView = startFov
			end
			return
		end
		if myHead.Parent then
			victimHead = myHead.Position
		end
		lastTarget, scale = catcherHead(catcher, lastTarget - Vector3.new(0, 2, 0))
		local toCatcher = Vector3.new(lastTarget.X - victimHead.X, 0, lastTarget.Z - victimHead.Z)
		toCatcher = if toCatcher.Magnitude > 0.05 then toCatcher.Unit else startCFrame.LookVector
		local side = Vector3.new(-toCatcher.Z, 0, toCatcher.X)
		-- 잡은 쪽 얼굴을 비스듬한 앞(정면에서 CameraAngle만큼 옆)에서 본다. 내 캐릭터는 잡은 쪽 반대로 넘어져 화면 옆으로 빠진다.
		local angle = math.rad(effect.CameraAngle)
		local away = -toCatcher * math.cos(angle) + side * math.sin(angle)
		local cameraPosition = lastTarget + away * effect.CameraDistance * scale + Vector3.new(0, 0.5 * scale, 0)
		local goal = CFrame.lookAt(cameraPosition, lastTarget)
		local t = math.clamp(elapsed / effect.CinematicTime, 0, 1)
		local eased = easeOutCubic(t)
		local shake = effect.ShakeStrength * math.max(0, 1 - t * 1.6)
		local jitter = CFrame.new(random:NextNumber(-1, 1) * shake, random:NextNumber(-1, 1) * shake, 0)
			* CFrame.Angles(0, 0, math.rad(random:NextNumber(-1, 1) * shake * 6))
		camera.CFrame = startCFrame:Lerp(goal, eased) * jitter
		camera.FieldOfView = startFov + (effect.ZoomFieldOfView - startFov) * eased
	end)
end

return CaughtCinematic
