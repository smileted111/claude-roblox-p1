--!strict
-- 매치 단계를 ReplicatedStorage Attribute(MatchState)로 공개하고, 그 단계의 시간이 끝날 때까지 기다린다.
-- MatchService(대기)와 StageService(역할 공개 ~ 결과)가 함께 쓴다. 단계가 바뀔 때마다 출력 창에 로그를 남긴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Types = require(ReplicatedStorage.Shared.Types)

-- TimeUp: 시간이 다 됨. EndedEarly: shouldEnd가 true를 돌려줘 일찍 끝남
export type Outcome = "TimeUp" | "EndedEarly"

local Attribute = MatchState.Attribute

local PhaseTimer = {}

local currentPhase: Types.MatchPhase? = nil

local function enter(phase: Types.MatchPhase, detail: string): ()
	local previous: string = currentPhase or "(시작)"
	currentPhase = phase
	ReplicatedStorage:SetAttribute(Attribute.Phase, phase)
	print(`[Phase] {previous} → {phase} ({detail})`)
end

-- 끝나는 시각 없이 단계만 바꾼다. 예: 인원이 모자라 기다리는 대기.
function PhaseTimer.set(phase: Types.MatchPhase, detail: string): ()
	ReplicatedStorage:SetAttribute(Attribute.PhaseEndsAt, nil)
	ReplicatedStorage:SetAttribute(Attribute.TimeLeft, nil)
	enter(phase, detail)
end

-- 단계를 바꾸고 duration초 동안 기다린다. 남은 시간은 Config.Match.PhaseTickInterval마다 갱신한다.
-- shouldEnd를 주면 같은 간격으로 불러서 true를 돌려주면 바로 끝낸다.
function PhaseTimer.run(phase: Types.MatchPhase, duration: number, shouldEnd: (() -> boolean)?): Outcome
	local endsAt = Workspace:GetServerTimeNow() + duration
	local shownTimeLeft = math.ceil(duration)
	-- 클라이언트가 Phase 변경을 받았을 때 시간 값이 이미 새 단계의 것이도록 시간을 먼저 쓴다.
	ReplicatedStorage:SetAttribute(Attribute.PhaseEndsAt, endsAt)
	ReplicatedStorage:SetAttribute(Attribute.TimeLeft, shownTimeLeft)
	enter(phase, `{duration}초`)

	while true do
		local remaining = endsAt - Workspace:GetServerTimeNow()
		local timeLeft = math.max(0, math.ceil(remaining))
		if timeLeft ~= shownTimeLeft then
			shownTimeLeft = timeLeft
			ReplicatedStorage:SetAttribute(Attribute.TimeLeft, timeLeft)
		end
		if remaining <= 0 then
			return "TimeUp"
		end
		if shouldEnd and shouldEnd() then
			return "EndedEarly"
		end
		task.wait(Match.PhaseTickInterval)
	end
end

return PhaseTimer
