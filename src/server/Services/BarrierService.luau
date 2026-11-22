--!strict
-- BarrierService: 환경 장치 판자·문 (GDD 6.4). GDD 13.2 목록 밖에 추가한 서비스 (아이템은 ItemService).
--
-- StageService가 준비 단계에서 맵을 불러오면 setupMap, 스테이지가 끝나면 clearMap을 부른다.
-- 맵 규칙 (CLAUDE.md, ItemState):
--   판자 (Plank 태그 Model): Board(세워 둔 판자, 충돌함) + FallenPose(넘어진 뒤 자리, 투명·충돌 없음)
--   문 (Door 태그 Model): Panel(닫힌 자리에 둔 문짝) + OpenPose(열린 자리, 투명·충돌 없음)
--
-- 판자: 생존자가 "넘어뜨리기"(추격 단계, 숨지 않음, 거리)를 누르면 Board가 FallenPose로 넘어가 길을 막는다 (1회용).
--   그 자리(+ Config.MapObjects.Plank.HitMargin)에 있던 추격자는 ChaserStunTime초 기절(MovementService.stun)하고
--   판자 반대쪽으로 밀려난다. 판자 자리에 있던 다른 캐릭터는 넘어뜨린 사람 쪽으로 밀려난다.
--   넘어진 판자는 괴물 길찾기에서도 막힌 곳이다 (거인은 S3-4에서 부숨).
-- 문: 생존자·추격자가 "열기"·"닫기"(준비·추격 단계, 거리, ToggleCooldown). 닫히면 Panel이 충돌·시야를 막아
--   괴물 길찾기에서 막힌 곳이 되고(괴물은 열지 못함), 열리면 OpenPose로 돌아가 통과·시야가 열린다.
--   닫을 자리에 누가 서 있으면 닫지 않는다. 스테이지 시작 때 열림(Config.MapObjects.Door.StartOpen).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ItemState = require(ReplicatedStorage.Shared.ItemState)
local MapObjects = require(ReplicatedStorage.Shared.Config.MapObjects)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local MonsterState = require(ReplicatedStorage.Shared.MonsterState)
local Strings = require(ReplicatedStorage.Shared.Strings)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local PromptUtil = require(ReplicatedStorage.Shared.Util.PromptUtil)
local MovementService = require(script.Parent.MovementService)

type Plank = {
	model: Model,
	board: BasePart,
	fallenCFrame: CFrame,
	prompt: ProximityPrompt?,
	fallen: boolean,
}

type Door = {
	model: Model,
	panel: BasePart,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	anchor: BasePart, -- 닫힌 자리에 둔 투명 파트. 프롬프트가 문짝과 함께 움직이지 않게 여기에 단다
	prompt: ProximityPrompt,
	open: boolean,
	nextToggleAt: number,
}

local Attribute = ItemState.Attribute
local PlankConfig = MapObjects.Plank
local DoorConfig = MapObjects.Door

local BarrierService = {}

local planks: { Plank } = {}
local doors: { Door } = {}
local created: { Instance } = {}
local connections: { RBXScriptConnection } = {}

local function isActiveSurvivor(player: Player): boolean
	local state = MatchState.getSurvivorState(player)
	return MatchState.getRole(player) == "Survivor"
		and (state == "Normal" or state == "Injured")
		and not MatchState.isHidden(player)
end

-- position이 box(CFrame·크기)를 margin만큼 넓힌 상자 안에 있는가
local function isInBox(boxCFrame: CFrame, size: Vector3, position: Vector3, margin: number): boolean
	local localPosition = boxCFrame:PointToObjectSpace(position)
	local half = size / 2 + Vector3.one * margin
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function isNear(player: Player, position: Vector3, distance: number): boolean
	local parts = CharacterParts.get(player)
	return parts ~= nil and (parts.rootPart.Position - position).Magnitude <= distance
end

local function hidePose(pose: BasePart): ()
	pose.Transparency = 1
	pose.CanCollide = false
	pose.CanQuery = false
	pose.CanTouch = false
end

local function newPrompt(parent: Instance, actionText: string, distance: number, tag: string): ProximityPrompt
	local prompt = PromptUtil.new()
	prompt.ActionText = actionText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt:AddTag(tag)
	prompt.Parent = parent
	return prompt
end

--------------------------------------------------------------------------------
-- 판자

-- 넘어진 판자 자리에 있던 캐릭터를 판자의 한쪽으로 옮긴다. side는 넘어진 판자의 두께 방향(로컬 Z) 부호 (+1 또는 -1).
local function pushOut(rootPart: BasePart, plank: Plank, side: number): ()
	local cframe = plank.fallenCFrame
	local localPosition = cframe:PointToObjectSpace(rootPart.Position)
	local target = cframe * Vector3.new(localPosition.X, localPosition.Y, side * (plank.board.Size.Z / 2 + 2.5))
	local character = rootPart.Parent
	if character and character:IsA("Model") then
		character:PivotTo(CFrame.new(target) * rootPart.CFrame.Rotation)
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			MovementService.markTeleported(player)
		end
	end
end

local function onPush(player: Player, plank: Plank): ()
	if plank.fallen or not ItemState.canUseInPhase(MatchState.getPhase()) or not isActiveSurvivor(player) then
		return
	end
	if not isNear(player, plank.board.Position, PlankConfig.PromptDistance + PlankConfig.DistanceSlack) then
		return
	end
	plank.fallen = true
	if plank.prompt then
		plank.prompt:Destroy()
		plank.prompt = nil
	end
	plank.model:SetAttribute(Attribute.Fallen, true)

	-- 넘어뜨린 사람이 넘어진 판자의 어느 쪽에 있는지. 추격자는 반대쪽, 나머지는 같은 쪽으로 밀어낸다.
	local pusherParts = CharacterParts.get(player)
	local pusherLocal = if pusherParts
		then plank.fallenCFrame:PointToObjectSpace(pusherParts.rootPart.Position)
		else Vector3.zero
	local pusherSide = if pusherLocal.Z >= 0 then 1 else -1

	local size = plank.board.Size
	local stunned: { string } = {}
	for _, other in Players:GetPlayers() do
		local parts = CharacterParts.get(other)
		if parts and other ~= player then
			local position = parts.rootPart.Position
			if
				MatchState.getRole(other) == "Chaser"
				and isInBox(plank.fallenCFrame, size, position, PlankConfig.HitMargin)
			then
				MovementService.stun(other, PlankConfig.ChaserStunTime, "Plank")
				table.insert(stunned, other.Name)
				if isInBox(plank.fallenCFrame, size, position, 0.5) then
					pushOut(parts.rootPart, plank, -pusherSide)
				end
			elseif isInBox(plank.fallenCFrame, size, position, 0.5) then
				pushOut(parts.rootPart, plank, pusherSide)
			end
		end
	end

	TweenService:Create(
		plank.board,
		TweenInfo.new(PlankConfig.FallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = plank.fallenCFrame }
	):Play()
	local stunText = if #stunned > 0 then ` → 추격자 {table.concat(stunned, ", ")} 기절` else ""
	print(`[Barrier] {player.Name} 판자 넘어뜨림: {plank.model.Name}{stunText}`)
end

local function addPlank(model: Model): ()
	local board = model:FindFirstChild(ItemState.PlankBoardName)
	local pose = model:FindFirstChild(ItemState.PlankFallenPoseName)
	if not board or not board:IsA("BasePart") or not pose or not pose:IsA("BasePart") then
		warn(
			`[Barrier] {model:GetFullName()}: {MapTags.Plank}에는 {ItemState.PlankBoardName}·{ItemState.PlankFallenPoseName} 파트가 필요합니다`
		)
		return
	end
	hidePose(pose)
	local attachment = Instance.new("Attachment")
	attachment.Name = "PlankPromptAttachment"
	attachment.Position = Vector3.new(0, -board.Size.Y / 2 + 3, 0)
	attachment.Parent = board
	table.insert(created, attachment)
	local prompt =
		newPrompt(attachment, Strings.Prompts.PushPlank, PlankConfig.PromptDistance, ItemState.PlankPromptTag)
	local plank: Plank = {
		model = model,
		board = board,
		fallenCFrame = pose.CFrame,
		prompt = prompt,
		fallen = false,
	}
	table.insert(
		connections,
		prompt.Triggered:Connect(function(player: Player)
			onPush(player, plank)
		end)
	)
	table.insert(planks, plank)
end

--------------------------------------------------------------------------------
-- 문

local function setDoorOpen(door: Door, open: boolean, instant: boolean): ()
	door.open = open
	door.model:SetAttribute(Attribute.Open, if open then true else nil)
	door.prompt.ActionText = if open then Strings.Prompts.CloseDoor else Strings.Prompts.OpenDoor
	-- 열린 문짝은 지나가거나 보는 것을 막지 않는다 (괴물 길찾기도 열린 곳으로 본다).
	door.panel.CanCollide = not open
	door.panel.CanQuery = not open
	local goal = if open then door.openCFrame else door.closedCFrame
	if instant then
		door.panel.CFrame = goal
	else
		TweenService:Create(door.panel, TweenInfo.new(DoorConfig.SwingTime), { CFrame = goal }):Play()
	end
end

-- 닫힌 문짝 자리에 캐릭터나 괴물이 서 있는가
local function isDoorwayBlocked(door: Door): boolean
	local size = door.panel.Size
	for _, player in Players:GetPlayers() do
		local parts = CharacterParts.get(player)
		if parts and isInBox(door.closedCFrame, size, parts.rootPart.Position, 1.5) then
			return true
		end
	end
	local monsters = Workspace:FindFirstChild(MonsterState.FolderName)
	if monsters then
		for _, monster in monsters:GetChildren() do
			local root = if monster:IsA("Model") then monster.PrimaryPart else nil
			if root and isInBox(door.closedCFrame, size, root.Position, 1.5) then
				return true
			end
		end
	end
	return false
end

local function onToggle(player: Player, door: Door): ()
	if not ItemState.canInteractInPhase(MatchState.getPhase()) then
		return
	end
	if not isActiveSurvivor(player) and MatchState.getRole(player) ~= "Chaser" then
		return
	end
	if MovementService.isStunned(player) then
		return
	end
	local now = os.clock()
	if now < door.nextToggleAt then
		return
	end
	if not isNear(player, door.anchor.Position, DoorConfig.PromptDistance + DoorConfig.DistanceSlack) then
		return
	end
	if door.open and isDoorwayBlocked(door) then
		return
	end
	door.nextToggleAt = now + DoorConfig.ToggleCooldown
	setDoorOpen(door, not door.open, false)
	print(`[Barrier] {player.Name} 문 {if door.open then "열기" else "닫기"}: {door.model.Name}`)
end

local function addDoor(model: Model): ()
	local panel = model:FindFirstChild(ItemState.DoorPanelName)
	local pose = model:FindFirstChild(ItemState.DoorOpenPoseName)
	if not panel or not panel:IsA("BasePart") or not pose or not pose:IsA("BasePart") then
		warn(
			`[Barrier] {model:GetFullName()}: {MapTags.Door}에는 {ItemState.DoorPanelName}·{ItemState.DoorOpenPoseName} 파트가 필요합니다`
		)
		return
	end
	hidePose(pose)
	local anchor = Instance.new("Part")
	anchor.Name = "DoorPromptAnchor"
	anchor.Anchored = true
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = panel.CFrame * CFrame.new(0, -panel.Size.Y / 2 + 3, 0)
	hidePose(anchor)
	anchor.Parent = model
	table.insert(created, anchor)
	local prompt = newPrompt(anchor, Strings.Prompts.OpenDoor, DoorConfig.PromptDistance, ItemState.DoorPromptTag)
	local door: Door = {
		model = model,
		panel = panel,
		closedCFrame = panel.CFrame,
		openCFrame = pose.CFrame,
		anchor = anchor,
		prompt = prompt,
		open = false,
		nextToggleAt = 0,
	}
	setDoorOpen(door, DoorConfig.StartOpen, true)
	table.insert(
		connections,
		prompt.Triggered:Connect(function(player: Player)
			onToggle(player, door)
		end)
	)
	table.insert(doors, door)
end

--------------------------------------------------------------------------------

-- 불러온 맵의 판자·문에 프롬프트를 만든다.
function BarrierService.setupMap(map: Instance): ()
	BarrierService.clearMap()
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("Model") then
			if descendant:HasTag(MapTags.Plank) then
				addPlank(descendant)
			elseif descendant:HasTag(MapTags.Door) then
				addDoor(descendant)
			end
		end
	end
	print(`[Barrier] 판자 {#planks}개, 문 {#doors}개 준비`)
end

-- position 반경 radius 안의 넘어진 판자와 닫힌 문을 부순다 (거인, GDD 4.1). 부순 수를 돌려준다.
-- 부순 판자는 사라지고, 부순 문은 문짝이 사라져 계속 열린 채가 된다.
function BarrierService.breakNear(position: Vector3, radius: number, source: string): number
	local broken = 0
	for _, plank in planks do
		if plank.fallen and plank.board.Parent and (plank.board.Position - position).Magnitude <= radius then
			plank.board:Destroy()
			broken += 1
			print(`[Barrier] {source}이 판자를 부숨: {plank.model.Name}`)
		end
	end
	for _, door in doors do
		if not door.open and door.panel.Parent and (door.panel.Position - position).Magnitude <= radius then
			door.prompt:Destroy()
			door.panel:Destroy()
			door.open = true
			door.model:SetAttribute(Attribute.Open, true)
			broken += 1
			print(`[Barrier] {source}이 문을 부숨: {door.model.Name}`)
		end
	end
	return broken
end

function BarrierService.clearMap(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, instance in created do
		instance:Destroy()
	end
	table.clear(created)
	table.clear(planks)
	table.clear(doors)
end

function BarrierService.Init(): () end

function BarrierService.Start(): () end

return BarrierService
