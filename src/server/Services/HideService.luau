--!strict
-- HideService: 숨는 곳 (GDD 6.1)
--
-- StageService가 맵을 불러오면 setupMap, 스테이지가 끝나면 clearMap을 부른다.
-- 맵의 HideSpot(PrimaryPart가 있는 Model)마다 PrimaryPart 앞면 바로 앞에 ProximityPrompt 3개를 만든다 (HideSpotState).
-- 누구에게 보일지는 클라이언트가 정하고, 눌렀을 때 서버가 역할·단계·거리·상태·쿨다운을 다시 검사한다.
--   숨기      생존자. 비어 있는 곳만 (한 곳에 한 명). 준비·추격 단계
--   나오기    그곳에 숨은 생존자
--   열어보기  추격자. 추격 단계. Config.MapObjects.HideSpot.ChaserOpenTime초 누르고 있어야 함.
--             숨은 생존자가 있으면 밖으로 나오고, FoundHideCooldown초 동안 다시 숨을 수 없다
--
-- 숨으면 캐릭터를 숨는 곳 안 바닥에 세워 고정(HumanoidRootPart Anchored)하고 보이지 않게 한다 (이름표 포함).
-- 이동 속도 0은 MovementService가 Hidden Attribute를 보고 정한다.
-- 나올 때는 PrimaryPart 앞(LookVector 방향, CLAUDE.md 맵 규칙)에 세운다.
-- 쓰러지거나, 캐릭터·숨는 곳이 없어지거나, 생존자가 아니게 되면 숨은 상태를 푼다.
--
-- 숨소리: 한 곳에 BreathAfter초 이상 숨어 있으면 숨는 곳 Attribute Breathing이 켜지고,
-- 그때 추격자가 BreathRevealRadius 안에 오면 숨는 곳이 강조 표시된다 (Highlight, 모두에게 보임. Attribute Revealed).
--
-- 다른 서비스용: HideService.isHidden(player) — 괴물 감지·피격 판정에서 숨은 생존자를 뺄 때 (S1-5, S1-6)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HideSpotState = require(ReplicatedStorage.Shared.HideSpotState)
local MapObjects = require(ReplicatedStorage.Shared.Config.MapObjects)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Strings = require(ReplicatedStorage.Shared.Strings)
local RoleService = require(script.Parent.RoleService)

type Spot = {
	model: Model,
	body: BasePart, -- PrimaryPart
	promptAttachment: Attachment,
	highlight: Highlight,
	created: { Instance }, -- clearMap에서 지울 것 (프롬프트·Attachment·Highlight)
	occupant: Player?,
}

type CharacterParts = {
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
}

type HiddenEntry = {
	player: Player,
	spot: Spot,
	parts: CharacterParts,
	hiddenAt: number, -- os.clock
	breathing: boolean,
	revealed: boolean,
	savedTransparency: { [Instance]: number },
	savedDisplayDistance: Enum.HumanoidDisplayDistanceType,
	connections: { RBXScriptConnection },
}

-- 추격자가 열어보기 프롬프트를 누르기 시작한 기록. 서버에서 누른 시간을 확인한다.
type OpenHold = {
	spot: Spot,
	beganAt: number,
	endedAt: number?,
}

local Attribute = MatchState.Attribute
local SpotAttribute = HideSpotState.Attribute
local Config = MapObjects.HideSpot

local HideService = {}

local spots: { Spot } = {}
local mapConnections: { RBXScriptConnection } = {}
local hiddenByPlayer: { [Player]: HiddenEntry } = {}
local openHolds: { [Player]: OpenHold } = {}
local nextHideAllowedAt: { [Player]: number } = {}

local function getCharacterParts(player: Player): CharacterParts?
	local character = player.Character
	if not character or not character:IsDescendantOf(Workspace) then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end
	return { character = character, humanoid = humanoid, rootPart = rootPart }
end

-- PrimaryPart 앞쪽(LookVector)을 수평으로 편 방향
local function frontDirection(body: BasePart): Vector3
	local look = body.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

-- 숨는 곳 바닥 높이에 앞을 보고 서는 CFrame. forward는 PrimaryPart 중심에서 앞쪽으로 떨어진 거리.
local function standCFrame(spot: Spot, parts: CharacterParts, forward: number): CFrame
	local body = spot.body
	local front = frontDirection(body)
	local floorY = body.Position.Y - body.Size.Y / 2
	local standHeight = parts.humanoid.HipHeight + parts.rootPart.Size.Y / 2
	local position = Vector3.new(body.Position.X, floorY + standHeight, body.Position.Z) + front * forward
	return CFrame.lookAt(position, position + front)
end

local function isNear(parts: CharacterParts, spot: Spot): boolean
	local distance = (parts.rootPart.Position - spot.promptAttachment.WorldPosition).Magnitude
	return distance <= Config.PromptDistance + Config.DistanceSlack
end

-- 파트·얼굴(Decal)의 투명도를 바꾸고 원래 값을 돌려준다. 투명도가 없는 인스턴스면 nil.
local function swapTransparency(instance: Instance, transparency: number): number?
	if instance:IsA("BasePart") or instance:IsA("Decal") then
		local previous = instance.Transparency
		instance.Transparency = transparency
		return previous
	end
	return nil
end

local function setCharacterVisible(entry: HiddenEntry, visible: boolean): ()
	local humanoid = entry.parts.humanoid
	if not visible then
		for _, descendant in entry.parts.character:GetDescendants() do
			entry.savedTransparency[descendant] = swapTransparency(descendant, 1)
		end
		entry.savedDisplayDistance = humanoid.DisplayDistanceType
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		return
	end
	for instance, transparency in entry.savedTransparency do
		swapTransparency(instance, transparency)
	end
	table.clear(entry.savedTransparency)
	humanoid.DisplayDistanceType = entry.savedDisplayDistance
end

local function setRevealed(entry: HiddenEntry, revealed: boolean): ()
	if entry.revealed == revealed then
		return
	end
	entry.revealed = revealed
	entry.spot.highlight.Enabled = revealed
	entry.spot.model:SetAttribute(SpotAttribute.Revealed, if revealed then true else nil)
	print(
		`[Hide] {entry.spot.model.Name} 강조 표시 {if revealed then "켬" else "끔"} ({entry.player.Name}의 숨소리)`
	)
end

-- 숨은 상태를 푼다. 캐릭터가 살아 있고 숨는 곳이 맵에 있으면 앞에 세운다. 이미 풀렸으면 아무것도 하지 않는다.
local function release(player: Player, reason: string): ()
	local entry = hiddenByPlayer[player]
	if not entry then
		return
	end
	hiddenByPlayer[player] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end

	local spot = entry.spot
	setRevealed(entry, false)
	if spot.occupant == player then
		spot.occupant = nil
	end
	spot.model:SetAttribute(SpotAttribute.OccupantUserId, nil)
	spot.model:SetAttribute(SpotAttribute.Breathing, nil)

	local parts = entry.parts
	setCharacterVisible(entry, true)
	local canPlace = parts.humanoid.Health > 0
		and parts.character:IsDescendantOf(Workspace)
		and spot.model:IsDescendantOf(Workspace)
	if canPlace then
		parts.character:PivotTo(standCFrame(spot, parts, spot.body.Size.Z / 2 + Config.ExitDistance))
	end
	parts.rootPart.Anchored = false
	-- 고정을 풀면 서버가 물리를 잠깐 맡으므로 바로 플레이어에게 돌려줘 끊김 없이 움직이게 한다.
	if
		player.Parent == Players
		and parts.rootPart:IsDescendantOf(Workspace)
		and parts.rootPart:CanSetNetworkOwnership()
	then
		parts.rootPart:SetNetworkOwner(player)
	end

	player:SetAttribute(Attribute.Hidden, nil)
	nextHideAllowedAt[player] = os.clock() + Config.HideCooldown
	print(`[Hide] {player.Name} 나옴: {spot.model.Name} ({reason})`)
end

local function hide(player: Player, spot: Spot, parts: CharacterParts): ()
	local entry: HiddenEntry = {
		player = player,
		spot = spot,
		parts = parts,
		hiddenAt = os.clock(),
		breathing = false,
		revealed = false,
		savedTransparency = {},
		savedDisplayDistance = parts.humanoid.DisplayDistanceType,
		connections = {},
	}
	hiddenByPlayer[player] = entry
	spot.occupant = player

	setCharacterVisible(entry, false)
	parts.rootPart.Anchored = true
	parts.character:PivotTo(standCFrame(spot, parts, 0))
	player:SetAttribute(Attribute.Hidden, true)
	spot.model:SetAttribute(SpotAttribute.OccupantUserId, player.UserId)

	local connections = entry.connections
	table.insert(
		connections,
		parts.humanoid.Died:Connect(function()
			release(player, "쓰러짐")
		end)
	)
	table.insert(
		connections,
		parts.character.AncestryChanged:Connect(function()
			if not parts.character:IsDescendantOf(Workspace) then
				release(player, "캐릭터 없어짐")
			end
		end)
	)
	table.insert(
		connections,
		spot.model.AncestryChanged:Connect(function()
			if not spot.model:IsDescendantOf(Workspace) then
				release(player, "숨는 곳 없어짐")
			end
		end)
	)
	table.insert(
		connections,
		player:GetAttributeChangedSignal(Attribute.Role):Connect(function()
			if MatchState.getRole(player) ~= "Survivor" then
				release(player, "생존자 아님")
			end
		end)
	)
	print(`[Hide] {player.Name} 숨음: {spot.model.Name}`)
end

local function onHideTriggered(player: Player, spot: Spot): ()
	if hiddenByPlayer[player] or spot.occupant then
		return
	end
	if MatchState.getRole(player) ~= "Survivor" or not HideSpotState.canHideInPhase(MatchState.getPhase()) then
		return
	end
	if os.clock() < (nextHideAllowedAt[player] or 0) then
		return
	end
	local parts = getCharacterParts(player)
	if not parts or not isNear(parts, spot) then
		return
	end
	hide(player, spot, parts)
end

local function onUnhideTriggered(player: Player, spot: Spot): ()
	local entry = hiddenByPlayer[player]
	if not entry or entry.spot ~= spot then
		return
	end
	if os.clock() < entry.hiddenAt + Config.HideCooldown then
		return
	end
	release(player, "스스로")
end

-- 열어보기를 ChaserOpenTime초(여유 OpenHoldSlack) 이상 눌렀는가. 확인한 기록은 지운다.
-- 누르기 끝(PromptButtonHoldEnded)과 Triggered 중 어느 쪽이 먼저 와도 맞게 계산한다.
local function takeHeldLongEnough(player: Player, spot: Spot): boolean
	local hold = openHolds[player]
	openHolds[player] = nil
	if not hold or hold.spot ~= spot then
		return false
	end
	local heldFor = (hold.endedAt or os.clock()) - hold.beganAt
	return heldFor >= Config.ChaserOpenTime - Config.OpenHoldSlack
end

local function onOpenTriggered(chaser: Player, spot: Spot): ()
	if not takeHeldLongEnough(chaser, spot) then
		return
	end
	if MatchState.getRole(chaser) ~= "Chaser" or not HideSpotState.canOpenInPhase(MatchState.getPhase()) then
		return
	end
	local parts = getCharacterParts(chaser)
	if not parts or not isNear(parts, spot) then
		return
	end
	local occupant = spot.occupant
	if not occupant then
		print(`[Hide] 추격자 {chaser.Name}: {spot.model.Name} 열어봄 → 비어 있음`)
		return
	end
	print(`[Hide] 추격자 {chaser.Name}: {spot.model.Name} 열어봄 → {occupant.Name} 발견`)
	release(occupant, "추격자에게 들킴")
	nextHideAllowedAt[occupant] = os.clock() + Config.FoundHideCooldown
end

local function createPrompt(
	parent: Attachment,
	name: string,
	actionText: string,
	holdDuration: number,
	requiresLineOfSight: boolean
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.HoldDuration = holdDuration
	prompt.MaxActivationDistance = Config.PromptDistance
	prompt.RequiresLineOfSight = requiresLineOfSight
	prompt.Parent = parent
	return prompt
end

local function addSpot(model: Model, body: BasePart): ()
	-- 프롬프트를 PrimaryPart 앞면 바로 앞에 둔다. 문짝 같은 장식 파트에 시야가 가리지 않고, 벽 너머에서는 보이지 않게 한다.
	local attachment = Instance.new("Attachment")
	attachment.Name = HideSpotState.PromptAttachmentName
	attachment.Position = Vector3.new(0, 0, -(body.Size.Z / 2 + Config.PromptFrontOffset))
	attachment.Parent = body

	local highlight = Instance.new("Highlight")
	highlight.Name = "RevealHighlight"
	highlight.Adornee = model
	highlight.Enabled = false
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Config.RevealColor
	highlight.OutlineColor = Config.RevealColor
	highlight.FillTransparency = Config.RevealFillTransparency
	highlight.Parent = model

	local spot: Spot = {
		model = model,
		body = body,
		promptAttachment = attachment,
		highlight = highlight,
		created = { attachment, highlight },
		occupant = nil,
	}

	local hidePrompt = createPrompt(attachment, HideSpotState.Prompt.Hide, Strings.Prompts.Hide, 0, true)
	-- 숨은 사람은 숨는 곳 안에 있어서 시야 검사를 하지 않는다.
	local unhidePrompt = createPrompt(attachment, HideSpotState.Prompt.Unhide, Strings.Prompts.Unhide, 0, false)
	local openPrompt =
		createPrompt(attachment, HideSpotState.Prompt.Open, Strings.Prompts.OpenHideSpot, Config.ChaserOpenTime, true)

	table.insert(
		mapConnections,
		hidePrompt.Triggered:Connect(function(player: Player)
			onHideTriggered(player, spot)
		end)
	)
	table.insert(
		mapConnections,
		unhidePrompt.Triggered:Connect(function(player: Player)
			onUnhideTriggered(player, spot)
		end)
	)
	table.insert(
		mapConnections,
		openPrompt.PromptButtonHoldBegan:Connect(function(player: Player)
			openHolds[player] = { spot = spot, beganAt = os.clock(), endedAt = nil }
		end)
	)
	table.insert(
		mapConnections,
		openPrompt.PromptButtonHoldEnded:Connect(function(player: Player)
			local hold = openHolds[player]
			if hold and hold.spot == spot and hold.endedAt == nil then
				hold.endedAt = os.clock()
			end
		end)
	)
	table.insert(
		mapConnections,
		openPrompt.Triggered:Connect(function(player: Player)
			onOpenTriggered(player, spot)
		end)
	)
	table.insert(spots, spot)
end

local function updateBreathing(): ()
	if next(hiddenByPlayer) == nil then
		return
	end
	local chaserPositions: { Vector3 } = {}
	for _, chaser in RoleService.getChasers() do
		local parts = getCharacterParts(chaser)
		if parts then
			table.insert(chaserPositions, parts.rootPart.Position)
		end
	end

	local now = os.clock()
	for player, entry in hiddenByPlayer do
		if not entry.breathing and now - entry.hiddenAt >= Config.BreathAfter then
			entry.breathing = true
			entry.spot.model:SetAttribute(SpotAttribute.Breathing, true)
			print(`[Hide] {player.Name} 숨소리 시작: {entry.spot.model.Name}`)
		end
		local revealed = false
		if entry.breathing then
			local spotPosition = entry.spot.body.Position
			for _, position in chaserPositions do
				if (position - spotPosition).Magnitude <= Config.BreathRevealRadius then
					revealed = true
					break
				end
			end
		end
		setRevealed(entry, revealed)
	end
end

function HideService.isHidden(player: Player): boolean
	return hiddenByPlayer[player] ~= nil
end

-- 숨은 곳에서 밖으로 내보낸다 (숨는 곳을 부수는 거인 등, S3-4). 숨어 있지 않으면 아무것도 하지 않는다.
function HideService.forceOut(player: Player, reason: string): ()
	release(player, reason)
end

-- 불러온 맵의 숨는 곳에 프롬프트와 강조 표시를 만든다.
function HideService.setupMap(map: Instance): ()
	HideService.clearMap()
	for _, descendant in map:GetDescendants() do
		if descendant:HasTag(MapTags.HideSpot) then
			local body = if descendant:IsA("Model") then descendant.PrimaryPart else nil
			if descendant:IsA("Model") and body then
				addSpot(descendant, body)
			else
				warn(
					`[Hide] {descendant:GetFullName()}: {MapTags.HideSpot}은 PrimaryPart가 있는 Model이어야 합니다`
				)
			end
		end
	end
	print(`[Hide] 숨는 곳 {#spots}개 준비`)
end

-- 숨은 사람을 모두 꺼내고 만든 프롬프트·강조 표시를 지운다. 맵을 지우기 전에 부른다.
function HideService.clearMap(): ()
	local hiddenPlayers: { Player } = {}
	for player in hiddenByPlayer do
		table.insert(hiddenPlayers, player)
	end
	for _, player in hiddenPlayers do
		release(player, "스테이지 끝")
	end
	for _, connection in mapConnections do
		connection:Disconnect()
	end
	table.clear(mapConnections)
	for _, spot in spots do
		for _, instance in spot.created do
			instance:Destroy()
		end
	end
	table.clear(spots)
	table.clear(openHolds)
end

function HideService.Init(): () end

function HideService.Start(): ()
	Players.PlayerRemoving:Connect(function(player: Player)
		release(player, "나감")
		openHolds[player] = nil
		nextHideAllowedAt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.CheckInterval)
			updateBreathing()
		end
	end)
end

return HideService
