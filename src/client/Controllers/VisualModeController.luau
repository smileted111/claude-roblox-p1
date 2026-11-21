--!strict
-- VisualModeController: 화면 모드(나이트·캐주얼)의 조명과 로비 미리보기 (Config.VisualModes, GDD 12장 조명).
-- GDD 13.2 목록 밖에 추가한 컨트롤러.
--
-- 조명은 클라이언트가 정한다 (서버는 Lighting을 바꾸지 않는다). 조명은 화면에만 영향이 있어 사람마다 달라도 된다.
--   스테이지 안 (역할이 있고 스테이지가 있으며 역할 공개가 끝남): 이번 매치 모드(ReplicatedStorage MatchMode)
--     나이트 = Config.Stages[스테이지].Lighting, 캐주얼 = Config.VisualModes.Casual.StageLighting.
--     같은 매치 참가자는 모두 같은 모드라 밝기로 생기는 유불리가 없다.
--   로비 (그 밖, 매치 중 로비에서 기다리는 사람 포함): 내가 고른 모드(Player Attribute VisualMode)의 로비 조명.
--     고르면 바로 미리 보인다. 나이트 = Config.Lighting.Lobby, 캐주얼 = Config.VisualModes.Casual.LobbyLighting.
--     캐주얼이면 로비(Workspace.Lobby) 파트 색도 이 화면에서만 파스텔로 바꾼다 (Util/MapStyler).
--     스테이지 맵 색은 서버(StageService)가 바꾼다.
-- 색 보정은 Lighting에 ColorCorrectionEffect "ModeColorCorrection"을 만들어 쓰고, 값이 없는 조명이면 끈다.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LightingConfig = require(ReplicatedStorage.Shared.Config.Lighting)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Types = require(ReplicatedStorage.Shared.Types)
local VisualModes = require(ReplicatedStorage.Shared.Config.VisualModes)
local MapStyler = require(ReplicatedStorage.Shared.Util.MapStyler)

local CORRECTION_NAME = "ModeColorCorrection"
local LOBBY_FOLDER = "Lobby" -- Workspace.Lobby

local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local VisualModeController = {}

local appliedKey: string? = nil
local lobbySaved: MapStyler.Saved = {}
local lobbyStyled = false
local lobbyConnection: RBXScriptConnection? = nil

local function preferredMode(): Types.VisualMode
	local mode = MatchState.getVisualMode(localPlayer)
	return if mode and table.find(VisualModes.Modes, mode) then mode else VisualModes.Default
end

local function isInStage(): boolean
	local phase = MatchState.getPhase()
	return MatchState.getRole(localPlayer) ~= nil
		and MatchState.getStageId() ~= nil
		and phase ~= "Waiting"
		and phase ~= "RoleReveal"
end

local function applyPreset(preset: LightingConfig.LightingPreset): ()
	Lighting.ClockTime = preset.ClockTime
	Lighting.Brightness = preset.Brightness
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	Lighting.ExposureCompensation = preset.ExposureCompensation

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = preset.Atmosphere.Density
	atmosphere.Haze = preset.Atmosphere.Haze
	atmosphere.Color = preset.Atmosphere.Color
	atmosphere.Decay = preset.Atmosphere.Decay
	atmosphere.Parent = Lighting

	local found = Lighting:FindFirstChild(CORRECTION_NAME)
	local correction = if found and found:IsA("ColorCorrectionEffect") then found else nil
	local values = preset.ColorCorrection
	if values then
		local effect = correction or Instance.new("ColorCorrectionEffect")
		effect.Name = CORRECTION_NAME
		effect.Brightness = values.Brightness
		effect.Contrast = values.Contrast
		effect.Saturation = values.Saturation
		effect.TintColor = values.TintColor
		effect.Enabled = true
		effect.Parent = Lighting
	elseif correction then
		correction.Enabled = false
	end
end

-- 로비 파트 색 미리보기 (이 화면에서만)
local function setLobbyStyle(casual: boolean): ()
	if casual == lobbyStyled then
		return
	end
	lobbyStyled = casual
	if lobbyConnection then
		lobbyConnection:Disconnect()
		lobbyConnection = nil
	end
	local lobby = Workspace:FindFirstChild(LOBBY_FOLDER)
	if casual and lobby then
		local palette = VisualModes.Casual.Palette
		MapStyler.apply(lobby, palette, lobbySaved)
		-- 스트리밍으로 나중에 들어오는 파트도 칠한다.
		lobbyConnection = lobby.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("BasePart") then
				MapStyler.applyPart(descendant, palette, lobbySaved)
			end
		end)
	else
		MapStyler.restore(lobbySaved)
	end
end

local function refresh(): ()
	local key: string
	local preset: LightingConfig.LightingPreset
	local stageId = MatchState.getStageId()
	if isInStage() and stageId then
		local mode = MatchState.getMatchMode() or VisualModes.Default
		key = `{stageId}/{mode}`
		preset = if mode == "Casual" then VisualModes.Casual.StageLighting else Stages[stageId].Lighting
	else
		local mode = preferredMode()
		key = `Lobby/{mode}`
		preset = if mode == "Casual" then VisualModes.Casual.LobbyLighting else LightingConfig.Lobby
	end
	setLobbyStyle(preferredMode() == "Casual")
	if key ~= appliedKey then
		appliedKey = key
		applyPreset(preset)
		print(`[Mode] 조명: {key}`)
	end
end

function VisualModeController.Init(): () end

function VisualModeController.Start(): ()
	for _, name in { Attribute.Phase, Attribute.StageId, Attribute.MatchMode } do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(refresh)
	end
	for _, name in { Attribute.Role, Attribute.VisualMode } do
		localPlayer:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return VisualModeController
