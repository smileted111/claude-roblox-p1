--!strict
-- 화면 전체를 덮는 효과: 맞았을 때 잠깐 번쩍임, 잡혔을 때 암전 (GDD 8장, 12장).
-- 피·신체 훼손 표현 대신 화면 효과와 효과음으로 처리한다. 덮개는 입력을 막지 않는다.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local BLACK = Color3.new(0, 0, 0)

local ScreenEffect = {}

local overlay: Frame? = nil
local currentTween: Tween? = nil
local blackoutId = 0
local blackoutUntil = 0 -- 암전이 끝나는 시각 (os.clock). 그 전에는 번쩍임이 암전을 덮어쓰지 않는다

local function getOverlay(): Frame
	local existing = overlay
	if existing then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScreenEffect"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100 -- HUD보다 위

	local frame = Instance.new("Frame")
	frame.Name = "Overlay"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = BLACK
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	overlay = frame
	return frame
end

local function fadeTo(frame: Frame, transparency: number, duration: number): ()
	if currentTween then
		currentTween:Cancel()
	end
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = transparency }
	)
	currentTween = tween
	tween:Play()
end

-- color로 화면을 startTransparency만큼 덮었다가 duration초 동안 사라지게 한다.
function ScreenEffect.flash(color: Color3, startTransparency: number, duration: number): ()
	if os.clock() < blackoutUntil then
		return
	end
	local frame = getOverlay()
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = startTransparency
	fadeTo(frame, 1, duration)
end

-- fadeInTime초 동안 어두워지고, 시작부터 holdUntil초가 되면 fadeOutTime초 동안 다시 밝아진다.
function ScreenEffect.blackout(fadeInTime: number, holdUntil: number, fadeOutTime: number): ()
	blackoutId += 1
	local id = blackoutId
	blackoutUntil = os.clock() + holdUntil + fadeOutTime
	local frame = getOverlay()
	frame.BackgroundColor3 = BLACK
	fadeTo(frame, 0, fadeInTime)
	task.delay(holdUntil, function()
		if id == blackoutId then
			fadeTo(frame, 1, fadeOutTime)
		end
	end)
end

return ScreenEffect
