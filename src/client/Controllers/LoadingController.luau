--!strict
-- LoadingController: 게임 중 로딩 화면 (2026-11-21 사용자 요청). GDD 13.2 목록 밖에 추가한 컨트롤러.
-- 화면은 처음 들어올 때와 같은 ReplicatedFirst.Loading.LoadingScreen (같은 클라이언트라 같은 모듈 인스턴스).
--   로비 → 스테이지: 서버가 ReplicatedStorage Attribute Loading = "Stage"를 켜면(맵을 불러와 참가자를 옮기는 중)
--     매치 참가자(InMatch) 화면에 "○○ 불러오는 중"을 띄운다.
--   스테이지 → 로비: Loading = "Lobby"(맵을 지우고 로비에 다시 만드는 중)면 "로비로 돌아가는 중".
--   서버가 Loading을 끈 뒤 내 캐릭터가 그 장소의 바닥 위에 서면(StreamingEnabled라 바닥이 들어올 때까지) 닫는다.
--     캐릭터가 없는 관전자는 바로 닫는다. Config.Loading.ReadyTimeout초가 지나면 그냥 닫고, 최소 MinVisibleTime초는 보여준다.
--   혼자 하기 서버로 이동(Notice SoloTeleporting): 띄우고 TeleportService:SetTeleportGui로 이동 중 화면으로 넘긴다.
--     실패하면(SoloTeleportFailed) 닫는다.
-- 글자는 Strings.Loading.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Loading = require(ReplicatedStorage.Shared.Config.Loading)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)

type Screen = {
	setTexts: (title: string, tips: { string }) -> (),
	setStatus: (status: string) -> (),
	show: (status: string, instant: boolean?) -> (),
	hide: (minVisible: number?) -> (),
	isVisible: () -> boolean,
	getTeleportGui: () -> GuiObject,
}

local CHECK_INTERVAL = 0.1 -- 바닥 확인 간격 (초)
local CURRENT_MAP = "CurrentMap" -- Workspace.CurrentMap (StageService)
local LOBBY = "Lobby" -- Workspace.Lobby

local localPlayer = Players.LocalPlayer

local LoadingController = {}

local screen: Screen? = nil
local showing: Types.LoadingKind? = nil -- 지금 띄운 로딩 단계
local releasedAt: number? = nil -- 서버 Loading이 꺼진 시각 (os.clock)
local nextCheckAt = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function statusFor(kind: Types.LoadingKind): string
	if kind == "Stage" then
		local stageId = MatchState.getStageId()
		local name = if stageId then Strings.Stages[stageId] else ""
		return string.format(Strings.Loading.Stage, name)
	end
	return Strings.Loading.Lobby
end

-- 내 캐릭터가 그 장소(스테이지 맵 또는 로비)의 바닥 위에 서 있나. 캐릭터가 없는 관전자는 기다릴 것이 없다.
local function isReady(kind: Types.LoadingKind): boolean
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return kind == "Stage" and MatchState.getRole(localPlayer) == "Spectator"
	end
	local place = Workspace:FindFirstChild(if kind == "Stage" then CURRENT_MAP else LOBBY)
	if not place then
		return false
	end
	rayParams.FilterDescendantsInstances = { place }
	return Workspace:Raycast(root.Position, Vector3.new(0, -Loading.GroundCheckDistance, 0), rayParams) ~= nil
end

local function onLoadingChanged(): ()
	local ui = screen
	local kind = MatchState.getLoading()
	if not ui or not kind or not MatchState.isInMatch(localPlayer) then
		return
	end
	showing = kind
	releasedAt = nil
	ui.show(statusFor(kind))
end

local function step(): ()
	local ui = screen
	local kind = showing
	if not ui or not kind then
		return
	end
	local now = os.clock()
	if now < nextCheckAt then
		return
	end
	nextCheckAt = now + CHECK_INTERVAL
	if MatchState.getLoading() == kind then
		return -- 서버가 아직 불러오는 중
	end
	releasedAt = releasedAt or now
	if isReady(kind) or now - (releasedAt :: number) >= Loading.ReadyTimeout then
		showing = nil
		releasedAt = nil
		ui.hide(Loading.MinVisibleTime)
	end
end

local function onNotice(key: unknown): ()
	local ui = screen
	if not ui then
		return
	end
	if key == "SoloTeleporting" then
		ui.show(Strings.Loading.Teleport)
		pcall(function()
			TeleportService:SetTeleportGui(ui.getTeleportGui())
		end)
	elseif key == "SoloTeleportFailed" and not showing then
		ui.hide(0)
	end
end

function LoadingController.Init(): () end

function LoadingController.Start(): ()
	local folder = ReplicatedFirst:WaitForChild("Loading", 10)
	local module = folder and folder:WaitForChild("LoadingScreen", 10)
	if not module or not module:IsA("ModuleScript") then
		warn("[Loading] ReplicatedFirst.Loading.LoadingScreen이 없어 로딩 화면을 띄우지 않습니다")
		return
	end
	local ui: Screen = (require :: any)(module)
	screen = ui
	ui.setTexts(Strings.Loading.Title, Strings.Loading.Tips)
	ReplicatedStorage:GetAttributeChangedSignal(MatchState.Attribute.Loading):Connect(onLoadingChanged)
	Remotes.get("Notice").OnClientEvent:Connect(onNotice)
	RunService.Heartbeat:Connect(step)
	onLoadingChanged()
end

return LoadingController
