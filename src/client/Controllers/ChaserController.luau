--!strict
-- ChaserController: 추격자 조작 — 근접 공격·열어보기 (GDD 6.1, 7장, 13.2). 스킬은 S3-3에서.
--
-- 공격: PC 마우스 왼쪽 클릭, 모바일 화면 탭(UI가 아닌 곳), 게임패드 R2. 추격 단계의 추격자만.
--   이 컨트롤러는 쿨다운(Config.Chasers.AttackCooldown) 동안 다시 보내지 않고, 휘두르는 애니메이션과 효과음만 낸다.
--   맞았는지, 쿨다운이 지났는지는 서버(CatchService)가 다시 판정한다 (ChaserAttack 리모트).
-- 숨는 곳의 "열어보기" 프롬프트를 추격자에게만, 추격 단계에서만 켠다. 누르는 시간(ChaserOpenTime)과 판정은 서버(HideService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local CatchState = require(ReplicatedStorage.Shared.CatchState)
local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local HideSpotState = require(ReplicatedStorage.Shared.HideSpotState)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local HideSpotWatcher = require(script.Parent.Parent.Util.HideSpotWatcher)
local SoundController = require(script.Parent.SoundController)

local Attribute = MatchState.Attribute
local localPlayer = Players.LocalPlayer

local ChaserController = {}

local attackRemote: RemoteEvent? = nil
local attackAnimation: Animation? = nil
local nextAttackAt = 0 -- os.clock
-- 캐릭터가 바뀌면 애니메이션을 새 Animator에 다시 불러온다.
local loadedFor: Humanoid? = nil
local attackTrack: AnimationTrack? = nil

local function refreshOpenPrompts(): ()
	local canOpen = MatchState.getRole(localPlayer) == "Chaser" and HideSpotState.canOpenInPhase(MatchState.getPhase())
	for _, spot in HideSpotWatcher.getSpots() do
		local openPrompt = HideSpotWatcher.findPrompt(spot, HideSpotState.Prompt.Open)
		if openPrompt then
			openPrompt.Enabled = canOpen
		end
	end
end

local function playAttackAnimation(humanoid: Humanoid): ()
	if loadedFor ~= humanoid then
		loadedFor = humanoid
		attackTrack = nil
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator and attackAnimation then
			local track = animator:LoadAnimation(attackAnimation)
			track.Priority = Enum.AnimationPriority.Action
			attackTrack = track
		end
	end
	if attackTrack then
		attackTrack:Play()
	end
end

local function tryAttack(): ()
	if MatchState.getRole(localPlayer) ~= "Chaser" or not CatchState.canHitInPhase(MatchState.getPhase()) then
		return
	end
	local now = os.clock()
	if now < nextAttackAt then
		return
	end
	local parts = CharacterParts.get(localPlayer)
	if not parts then
		return
	end
	nextAttackAt = now + Chasers[Match.DefaultChaser].AttackCooldown
	if attackRemote then
		attackRemote:FireServer()
	end
	playAttackAnimation(parts.humanoid)
	SoundController.play("ChaserAttack")
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean): ()
	if gameProcessedEvent then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		tryAttack()
	end
end

local function onTouchTapInWorld(_position: Vector2, processedByUI: boolean): ()
	if not processedByUI then
		tryAttack()
	end
end

function ChaserController.Init(): ()
	local animation = Instance.new("Animation")
	animation.Name = "ChaserAttack"
	animation.AnimationId = Assets.Animations.ChaserAttack
	attackAnimation = animation
end

function ChaserController.Start(): ()
	attackRemote = Remotes.get("ChaserAttack")
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.TouchTapInWorld:Connect(onTouchTapInWorld)

	localPlayer:GetAttributeChangedSignal(Attribute.Role):Connect(refreshOpenPrompts)
	ReplicatedStorage:GetAttributeChangedSignal(Attribute.Phase):Connect(refreshOpenPrompts)
	HideSpotWatcher.subscribe(refreshOpenPrompts)
end

return ChaserController
