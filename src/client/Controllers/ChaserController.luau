--!strict
-- ChaserController: 추격자 조작 — 근접 공격·열어보기 (GDD 6.1, 7장, 13.2). 스킬은 S3-3에서.
--
-- 공격: PC 마우스 왼쪽 클릭, 모바일 화면 탭(UI가 아닌 곳), 게임패드 R2. 추격 단계의 추격자만.
--   이 컨트롤러는 쿨다운(Config.Chasers.AttackCooldown) 동안 다시 보내지 않고, 휘두르는 애니메이션과 효과음,
--   HUD 쿨다운 바(UIController)만 맡는다.
--   맞았는지, 쿨다운이 지났는지는 서버(CatchService)가 다시 판정한다 (ChaserAttack 리모트).
-- 숨는 곳의 "열어보기" 프롬프트를 추격자에게만, 추격 단계에서만 켠다. 누르는 시간(ChaserOpenTime)과 판정은 서버(HideService).
-- 위치 표시: ChaserMarker 리모트(발전기 소리, 감시자 경보)를 받으면 그 위치에 duration초 동안 표시 (Util/WorldMarker).
-- 괴물 위치 (GDD 7장, 질문지 Q2-8): 추격자일 때 Workspace.Monsters의 괴물마다 벽 너머에서도 보이는 아이콘(색 점 + 이름).
--   서버가 괴물 모델을 추격자에게 항상 스트리밍하므로(MonsterService) 맵 어디서든 보인다.
-- 연막 (GDD 6.3): 추격자 화면에서는 연막 구역(ItemState.SmokeZoneTag, 반경 Attribute Radius) 안의 생존자 캐릭터와
--   이름표를 가린다 (LocalTransparencyModifier). 괴물의 시야에서 빼는 것은 서버(ItemService.isConcealed).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local ItemState = require(ReplicatedStorage.Shared.ItemState)
local CatchState = require(ReplicatedStorage.Shared.CatchState)
local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local HideSpotState = require(ReplicatedStorage.Shared.HideSpotState)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MonsterState = require(ReplicatedStorage.Shared.MonsterState)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local HideSpotWatcher = require(script.Parent.Parent.Util.HideSpotWatcher)
local UiStyle = require(script.Parent.Parent.Util.UiStyle)
local WorldMarker = require(script.Parent.Parent.Util.WorldMarker)
local SoundController = require(script.Parent.SoundController)
local UIController = require(script.Parent.UIController)

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
	local cooldown = Chasers[Match.DefaultChaser].AttackCooldown
	nextAttackAt = now + cooldown
	if attackRemote then
		attackRemote:FireServer()
	end
	UIController.startAttackCooldown(cooldown)
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

local MARKER_COLORS: { [Types.MarkerReason]: Color3 } = {
	GeneratorNoise = UiStyle.Colors.Warning,
	WatcherAlert = UiStyle.Colors.Accent,
}

local function onChaserMarker(position: unknown, duration: unknown, reason: unknown): ()
	if typeof(position) ~= "Vector3" or typeof(duration) ~= "number" or typeof(reason) ~= "string" then
		return
	end
	local markerReason = reason :: Types.MarkerReason
	local text = Strings.Markers[markerReason]
	if not text or MatchState.getRole(localPlayer) ~= "Chaser" then
		return
	end
	WorldMarker.show(position, duration, text, MARKER_COLORS[markerReason])
end

-- 괴물 위치 아이콘 -------------------------------------------------------------------------------------------

local MONSTER_ICON_NAME = "ChaserMonsterIcon"
local monsterIcons: { [Model]: BillboardGui } = {}
local monsterFolderConnections: { RBXScriptConnection } = {}

local function removeMonsterIcon(model: Model): ()
	local icon = monsterIcons[model]
	if icon then
		monsterIcons[model] = nil
		icon:Destroy()
	end
end

local function addMonsterIcon(model: Model): ()
	if monsterIcons[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local kind = model:GetAttribute(MonsterState.Attribute.MonsterId)
	if not root or not root:IsA("BasePart") or typeof(kind) ~= "string" then
		return
	end
	local monsterId = kind :: Types.MonsterId
	local color = UiStyle.MonsterColors[monsterId] or UiStyle.Colors.Text
	local icon = Instance.new("BillboardGui")
	icon.Name = MONSTER_ICON_NAME
	icon.AlwaysOnTop = true
	icon.LightInfluence = 0
	icon.Size = UDim2.fromOffset(80, 38)
	icon.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0)
	dot.Position = UDim2.fromScale(0.5, 0)
	dot.Size = UDim2.fromOffset(16, 16)
	dot.BackgroundColor3 = color
	UiStyle.corner(dot, 8)
	UiStyle.stroke(dot, UiStyle.Colors.Panel)
	dot.Parent = icon
	local label = UiStyle.label(icon, "Name", 0, 18)
	label.Position = UDim2.fromOffset(0, 18)
	label.Font = UiStyle.BoldFont
	label.TextSize = 14
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = Strings.Monsters[monsterId] or kind
	icon.Parent = root
	monsterIcons[model] = icon
end

local function refreshMonsterIcons(): ()
	local show = MatchState.getRole(localPlayer) == "Chaser"
	local folder = Workspace:FindFirstChild(MonsterState.FolderName)
	for model in monsterIcons do
		if not show or not folder or model.Parent ~= folder then
			removeMonsterIcon(model)
		end
	end
	if show and folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				addMonsterIcon(child)
			end
		end
	end
end

local function watchMonsterFolder(folder: Instance): ()
	for _, connection in monsterFolderConnections do
		connection:Disconnect()
	end
	table.clear(monsterFolderConnections)
	table.insert(monsterFolderConnections, folder.ChildAdded:Connect(refreshMonsterIcons))
	table.insert(monsterFolderConnections, folder.ChildRemoved:Connect(refreshMonsterIcons))
	-- 모델이 통째로 들어오기 전에 ChildAdded가 오면 몸통이 생길 때 다시 맞춘다.
	table.insert(
		monsterFolderConnections,
		folder.DescendantAdded:Connect(function(descendant: Instance)
			if descendant.Name == "HumanoidRootPart" then
				refreshMonsterIcons()
			end
		end)
	)
	refreshMonsterIcons()
end

-- 연막 속 생존자 가리기 ------------------------------------------------------------------------------------------

type Concealed = {
	character: Model,
	displayDistance: Enum.HumanoidDisplayDistanceType?,
}

local concealed: { [Player]: Concealed } = {}

local function setCharacterHidden(character: Model, hidden: boolean): ()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function reveal(player: Player): ()
	local entry = concealed[player]
	if not entry then
		return
	end
	concealed[player] = nil
	setCharacterHidden(entry.character, false)
	local humanoid = entry.character:FindFirstChildOfClass("Humanoid")
	if humanoid and entry.displayDistance then
		humanoid.DisplayDistanceType = entry.displayDistance
	end
end

local function conceal(player: Player, character: Model): ()
	local entry = concealed[player]
	if entry and entry.character == character then
		return
	end
	reveal(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	concealed[player] = {
		character = character,
		displayDistance = if humanoid then humanoid.DisplayDistanceType else nil,
	}
	setCharacterHidden(character, true)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function updateSmoke(): ()
	local zones = CollectionService:GetTagged(ItemState.SmokeZoneTag)
	local active = MatchState.getRole(localPlayer) == "Chaser" and #zones > 0
	if not active then
		if next(concealed) then
			for player in concealed do
				reveal(player)
			end
		end
		return
	end
	for _, player in Players:GetPlayers() do
		local inSmoke = false
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if player ~= localPlayer and MatchState.getRole(player) == "Survivor" and root and root:IsA("BasePart") then
			for _, zone in zones do
				local radius = zone:GetAttribute(ItemState.Attribute.Radius)
				if zone:IsA("BasePart") and typeof(radius) == "number" then
					if (root.Position - zone.Position).Magnitude <= radius then
						inSmoke = true
						break
					end
				end
			end
		end
		if inSmoke and character then
			conceal(player, character)
		else
			reveal(player)
		end
	end
end

-- -------------------------------------------------------------------------------------------------------------

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
	Remotes.get("ChaserMarker").OnClientEvent:Connect(onChaserMarker)

	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == MonsterState.FolderName then
			watchMonsterFolder(child)
		end
	end)
	local existing = Workspace:FindFirstChild(MonsterState.FolderName)
	if existing then
		watchMonsterFolder(existing)
	end
	localPlayer:GetAttributeChangedSignal(Attribute.Role):Connect(refreshMonsterIcons)

	RunService.Heartbeat:Connect(updateSmoke)
	Players.PlayerRemoving:Connect(function(player: Player)
		concealed[player] = nil
	end)

	localPlayer:GetAttributeChangedSignal(Attribute.Role):Connect(refreshOpenPrompts)
	ReplicatedStorage:GetAttributeChangedSignal(Attribute.Phase):Connect(refreshOpenPrompts)
	HideSpotWatcher.subscribe(refreshOpenPrompts)
end

return ChaserController
