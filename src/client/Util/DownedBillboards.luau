--!strict
-- 쓰러진 동료 머리 위에 "쓰러짐 n초"와 "붕대로 살리기"를 띄운다 (2026-11-22 사용자 요청). 내가 생존자일 때만 보이고,
-- 쓰러진 동료를 찾아갈 수 있게 벽 너머에서도 보인다 (AlwaysOnTop). 추격자·관전자 화면에는 띄우지 않는다.
-- 남은 초는 서버가 공개한 Player Attribute DownedUntil과 서버 시각으로 계산한다.
-- 캐릭터가 스트리밍으로 늦게 들어와도 붙도록 UPDATE_INTERVAL초마다 모든 플레이어를 다시 본다 (최대 8명).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catch = require(ReplicatedStorage.Shared.Config.Catch)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Strings = require(ReplicatedStorage.Shared.Strings)
local UiStyle = require(script.Parent.UiStyle)

local UPDATE_INTERVAL = 0.2 -- 초

type Marker = {
	gui: BillboardGui,
	label: TextLabel,
	shownSeconds: number?,
}

local DownedBillboards = {}

local localPlayer = Players.LocalPlayer
local markers: { [Player]: Marker } = {}
local started = false

local function remove(player: Player): ()
	local marker = markers[player]
	if marker then
		markers[player] = nil
		marker.gui:Destroy()
	end
end

local function create(player: Player): Marker
	local gui = Instance.new("BillboardGui")
	gui.Name = "DownedMarker"
	gui.Size = UDim2.fromOffset(170, 48)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Catch.Revive.MarkerHeight, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local label = UiStyle.label(gui, "Timer", 0, 26)
	label.Font = UiStyle.BoldFont
	label.TextColor3 = UiStyle.Colors.Accent
	label.TextStrokeTransparency = 0.3
	local hint = UiStyle.label(gui, "Hint", 0, 20)
	hint.Position = UDim2.fromOffset(0, 26)
	hint.TextStrokeTransparency = 0.4
	hint.Text = Strings.Hud.DownedMarkerHint
	gui.Parent = localPlayer:FindFirstChildOfClass("PlayerGui")
	local marker: Marker = { gui = gui, label = label, shownSeconds = nil }
	markers[player] = marker
	return marker
end

local function update(): ()
	local iAmSurvivor = MatchState.getRole(localPlayer) == "Survivor"
	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local downedUntil = MatchState.getDownedUntil(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local show = iAmSurvivor
			and player ~= localPlayer
			and downedUntil ~= nil
			and MatchState.getSurvivorState(player) == "Downed"
			and root ~= nil
			and root:IsA("BasePart")
		if show and downedUntil and root and root:IsA("BasePart") then
			local marker = markers[player] or create(player)
			if marker.gui.Adornee ~= root then
				marker.gui.Adornee = root
			end
			local seconds = math.max(0, math.ceil(downedUntil - now))
			if seconds ~= marker.shownSeconds then
				marker.shownSeconds = seconds
				marker.label.Text = string.format(Strings.Hud.DownedMarker, seconds)
			end
		else
			remove(player)
		end
	end
end

function DownedBillboards.start(): ()
	if started then
		return
	end
	started = true
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= UPDATE_INTERVAL then
			elapsed = 0
			update()
		end
	end)
	Players.PlayerRemoving:Connect(remove)
end

return DownedBillboards
