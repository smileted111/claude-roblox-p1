--!strict
-- ItemService: 아이템 배치·줍기·사용 (GDD 6.3, 13.2). 아이템 5종: 붕대·연막탄·에너지 드링크·손전등·알람시계.
--
-- StageService가 준비 단계에서 맵을 불러오면 setupMap, 스테이지가 끝나면 clearMap을 부른다.
-- 배치: 맵의 ItemSpawn 중 Config.MapObjects.ItemPickup.SpawnFraction만큼(반올림)을 무작위로 골라, 각 자리에
--   Config.Items의 SpawnWeight 가중치로 뽑은 아이템 상자를 놓는다. 상자에는 "줍기" 프롬프트 (ItemState).
-- 줍기: 준비·추격 단계, 숨지 않은 생존자, 거리, 빈칸이 있어야 한다. 칸은 Config.Survivor.InventorySlots(2)개,
--   Player Attribute Item1·Item2 (MatchState). 스테이지가 끝나면 비운다.
-- 사용: UseItem 리모트 (slot). 빈도 제한·관전자 거절은 RemoteHandler. 추격 단계, 숨지 않은 생존자, 그 칸에 아이템.
--   효과는 서버가 적용하고, 효과가 없으면(부상이 아닌데 붕대 등) 아이템을 남긴다.
--   붕대         부상 → 정상
--   에너지 드링크 스태미나를 StaminaRestoreFraction만큼 (MovementService.restoreStamina)
--   연막탄       쓴 자리에 Duration초 동안 반경 Radius의 연막 구역. 그 안의 생존자는 괴물이 보지 못하고
--                (MonsterService가 ItemService.isConcealed로 뺌) 추격자 화면에서도 가려진다 (ChaserController).
--                감시자 경보도 보이는 생존자에게만 가므로 연막 안에서는 나지 않는다.
--   손전등       쓰면 켜고 다시 쓰면 끈다 (아이템은 남음). 켜면 머리에 SpotLight, 배터리(Battery초)가 닳고 다 닳으면 사라진다.
--                켜져 있는 동안 0.1초마다 바라보는 쪽 Range·Angle 원뿔 안의 그림자를 멈춘다
--                (MonsterService가 setBeamHandler로 넘긴 함수). Player Attribute FlashlightOn·FlashlightBattery
--   알람시계     카메라가 보는 곳(UseItem의 aimPosition, Range 안으로 줄이고 벽 앞에서 멈춤)에 던진다.
--                Duration초 동안 1초마다 소리(NoiseBus Alarm, 반경 Radius): 사냥개는 돌진하고 다른 괴물도 찾아온다

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Items = require(ReplicatedStorage.Shared.Config.Items)
local ItemState = require(ReplicatedStorage.Shared.ItemState)
local MapObjects = require(ReplicatedStorage.Shared.Config.MapObjects)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Survivor = require(ReplicatedStorage.Shared.Config.Survivor)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local PromptUtil = require(ReplicatedStorage.Shared.Util.PromptUtil)
local NoiseBus = require(script.Parent.Parent.Util.NoiseBus)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local MovementService = require(script.Parent.MovementService)
local RoleService = require(script.Parent.RoleService)

type SmokeZone = {
	part: BasePart,
	position: Vector3,
	radius: number,
	endsAt: number, -- os.clock
}

local Config = MapObjects.ItemPickup
local Attribute = ItemState.Attribute

local ItemService = {}

local random = Random.new()
local pickups: { BasePart } = {}
local smokeZones: { SmokeZone } = {}
local connections: { RBXScriptConnection } = {}

-- 손전등: 플레이어마다 남은 배터리(초)와 켠 상태. 새 손전등을 주우면 배터리가 다시 찬다.
type Flashlight = {
	battery: number,
	light: SpotLight?, -- 켜져 있으면 머리에 단 빛
}

-- 아이템을 쓴 결과. Used는 칸에서 없앰, Kept는 남김(손전등 켜고 끄기), Failed는 효과 없음
type UseResult = "Used" | "Kept" | "Failed"
type BeamHandler = (origin: Vector3, direction: Vector3, range: number, angle: number) -> number

local FLASHLIGHT_TICK = 0.1 -- 손전등 배터리·빛을 확인하는 간격 (초)
local ALARM_RING_INTERVAL = 1 -- 알람시계 소리 간격 (초)

local flashlights: { [Player]: Flashlight } = {}
local beamHandler: BeamHandler? = nil
local flashlightElapsed = 0

local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
worldParams.RespectCanCollide = true

-- 캐릭터·괴물을 빼고 충돌하는 파트만 (던진 알람시계가 닿는 곳)
local function raycastWorld(origin: Vector3, direction: Vector3): RaycastResult?
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(ignore, monsters)
	end
	worldParams.FilterDescendantsInstances = ignore
	return Workspace:Raycast(origin, direction, worldParams)
end

local function isActiveSurvivor(player: Player): boolean
	local state = MatchState.getSurvivorState(player)
	return MatchState.getRole(player) == "Survivor" and (state == "Normal" or state == "Injured")
end

local function freeSlot(player: Player): number?
	for slot = 1, Survivor.InventorySlots do
		if MatchState.getItem(player, slot) == nil then
			return slot
		end
	end
	return nil
end

local function setSlot(player: Player, slot: number, itemId: Types.ItemId?): ()
	local name = MatchState.getItemSlotAttribute(slot)
	if name then
		player:SetAttribute(name, itemId)
	end
end

local function setFlashlightOn(player: Player, on: boolean): ()
	local state = flashlights[player]
	if not state then
		return
	end
	if state.light then
		state.light:Destroy()
		state.light = nil
	end
	if on then
		local parts = CharacterParts.get(player)
		local head = parts and parts.character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local def = Items.Flashlight
			local light = Instance.new("SpotLight")
			light.Name = "Flashlight"
			light.Face = Enum.NormalId.Front
			light.Range = math.min(def.Range or 40, 60)
			light.Angle = math.min((def.Angle or 30) * 1.5, 180)
			light.Brightness = 5
			light.Color = def.Color
			light.Shadows = false
			light.Parent = head
			state.light = light
		end
	end
	player:SetAttribute(MatchState.Attribute.FlashlightOn, if state.light then true else nil)
end

local function dropFlashlight(player: Player): ()
	if flashlights[player] then
		setFlashlightOn(player, false)
		flashlights[player] = nil
	end
	player:SetAttribute(MatchState.Attribute.FlashlightOn, nil)
	player:SetAttribute(MatchState.Attribute.FlashlightBattery, nil)
end

local function clearInventory(player: Player): ()
	for slot = 1, Survivor.InventorySlots do
		setSlot(player, slot, nil)
	end
	dropFlashlight(player)
end

-- SpawnWeight 가중치로 아이템 하나를 뽑는다. 뽑을 수 있는 아이템이 없으면 nil.
local function rollItem(): Types.ItemId?
	local total = 0
	for _, def in Items do
		total += def.SpawnWeight
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	for itemId, def in Items do
		roll -= def.SpawnWeight
		if def.SpawnWeight > 0 and roll <= 0 then
			return itemId
		end
	end
	return nil
end

local function onPickUp(player: Player, pickup: BasePart): ()
	if not pickup.Parent or not ItemState.canInteractInPhase(MatchState.getPhase()) then
		return
	end
	if not isActiveSurvivor(player) or MatchState.isHidden(player) then
		return
	end
	local parts = CharacterParts.get(player)
	if
		not parts
		or (parts.rootPart.Position - pickup.Position).Magnitude > Config.PromptDistance + Config.DistanceSlack
	then
		return
	end
	local slot = freeSlot(player)
	local itemId = pickup:GetAttribute(Attribute.ItemId)
	if not slot or typeof(itemId) ~= "string" then
		return
	end
	local index = table.find(pickups, pickup)
	if index then
		table.remove(pickups, index)
	end
	pickup:Destroy()
	setSlot(player, slot, itemId :: Types.ItemId)
	if itemId == "Flashlight" then
		local battery = Items.Flashlight.Battery or 0
		local state = flashlights[player]
		if state then
			state.battery = battery
		else
			flashlights[player] = { battery = battery, light = nil }
		end
		player:SetAttribute(MatchState.Attribute.FlashlightBattery, 1)
	end
	print(`[Item] {player.Name} 주움: {itemId} → {slot}번 칸`)
end

local function placePickup(spawnPart: BasePart, itemId: Types.ItemId, parent: Instance): ()
	local def = Items[itemId]
	local size = Config.Size
	local pickup = Instance.new("Part")
	pickup.Name = `Item_{itemId}`
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.CanTouch = false
	pickup.Size = Vector3.one * size
	pickup.Color = def.Color
	pickup.Material = Enum.Material.Neon
	pickup.CFrame = CFrame.new(spawnPart.Position + Vector3.new(0, Config.Height, 0))
		* CFrame.Angles(0, math.rad(45), 0)
	pickup:SetAttribute(Attribute.ItemId, itemId)

	local prompt = PromptUtil.new()
	prompt.Name = "PickupPrompt"
	prompt.ActionText = Strings.Prompts.PickUp
	prompt.ObjectText = Strings.Items[itemId]
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt:AddTag(ItemState.PickupPromptTag)
	prompt.Parent = pickup
	table.insert(
		connections,
		prompt.Triggered:Connect(function(player: Player)
			onPickUp(player, pickup)
		end)
	)
	pickup.Parent = parent
	table.insert(pickups, pickup)
end

local function createSmoke(position: Vector3, def: Items.ItemDef): ()
	local radius = def.Radius or 0
	local duration = def.Duration or 0
	local part = Instance.new("Part")
	part.Name = "SmokeZone"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part:SetAttribute(Attribute.Radius, radius)
	part:AddTag(ItemState.SmokeZoneTag)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 150, 160))
	emitter.LightInfluence = 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.6),
		NumberSequenceKeypoint.new(1, radius * 1.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Rate = 30
	emitter.Speed = NumberRange.new(radius * 0.3, radius * 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.Parent = part
	part.Parent = Workspace:FindFirstChild("CurrentMap") or Workspace

	local zone: SmokeZone = {
		part = part,
		position = position,
		radius = radius,
		endsAt = os.clock() + duration,
	}
	table.insert(smokeZones, zone)
	task.delay(duration, function()
		emitter.Enabled = false
		local index = table.find(smokeZones, zone)
		if index then
			table.remove(smokeZones, index)
		end
		task.wait(3) -- 남은 연기가 사라질 때까지
		part:Destroy()
	end)
end

-- 알람시계를 던진다: aim 쪽으로 Range 안, 벽에 닿으면 그 앞, 바닥에 놓고 Duration초 동안 울린다.
local function throwAlarm(player: Player, parts: CharacterParts.CharacterParts, def: Items.ItemDef, aim: Vector3?): ()
	local range = def.Range or 40
	local head = parts.character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else parts.rootPart.Position
	local target = aim or (origin + parts.rootPart.CFrame.LookVector * range)
	local offset = target - origin
	if offset.Magnitude < 1e-3 then
		offset = parts.rootPart.CFrame.LookVector
	end
	if offset.Magnitude > range then
		offset = offset.Unit * range
	end
	local hit = raycastWorld(origin, offset)
	local landing = if hit then hit.Position - offset.Unit * 1 else origin + offset
	local ground = raycastWorld(landing + Vector3.new(0, 1, 0), Vector3.new(0, -40, 0))
	if ground then
		landing = ground.Position + Vector3.new(0, 0.6, 0)
	end

	local clock = Instance.new("Part")
	clock.Name = "AlarmClock"
	clock.Anchored = true
	clock.CanCollide = false
	clock.CanQuery = false
	clock.CanTouch = false
	clock.Size = Vector3.new(1.2, 1.2, 1.2)
	clock.Material = Enum.Material.Neon
	clock.Color = def.Color
	clock.Position = landing
	clock.Parent = Workspace:FindFirstChild("CurrentMap") or Workspace
	print(`[Item] {player.Name} 알람시계 던짐 → ({math.round(landing.X)}, {math.round(landing.Z)})`)

	local duration = def.Duration or 5
	task.spawn(function()
		local endsAt = os.clock() + duration
		while os.clock() < endsAt and clock.Parent do
			NoiseBus.emit({ kind = "Alarm", position = landing, radius = def.Radius or 60, source = player })
			task.wait(ALARM_RING_INTERVAL)
		end
		clock:Destroy()
	end)
end

-- 아이템 효과 (UseResult)
local function applyItem(
	player: Player,
	itemId: Types.ItemId,
	parts: CharacterParts.CharacterParts,
	aim: Vector3?
): UseResult
	local def = Items[itemId]
	if itemId == "Bandage" then
		if MatchState.getSurvivorState(player) ~= "Injured" then
			return "Failed"
		end
		RoleService.setSurvivorState(player, "Normal")
		return "Used"
	elseif itemId == "EnergyDrink" then
		MovementService.restoreStamina(player, def.StaminaRestoreFraction or 1)
		return "Used"
	elseif itemId == "SmokeBomb" then
		createSmoke(parts.rootPart.Position, def)
		return "Used"
	elseif itemId == "Flashlight" then
		local state = flashlights[player]
		if not state or state.battery <= 0 then
			return "Failed"
		end
		setFlashlightOn(player, state.light == nil)
		return "Kept"
	elseif itemId == "AlarmClock" then
		throwAlarm(player, parts, def, aim)
		return "Used"
	end
	return "Failed"
end

-- 켜진 손전등: 배터리를 줄이고, 다 닳으면 없애고, 빛 원뿔 안의 그림자를 멈춘다.
local function updateFlashlights(dt: number): ()
	local def = Items.Flashlight
	local fullBattery = def.Battery or 1
	local handler = beamHandler
	for player, state in flashlights do
		local light = state.light
		if light then
			local parts = CharacterParts.get(player)
			local canUse = parts ~= nil
				and isActiveSurvivor(player)
				and not MatchState.isHidden(player)
				and ItemState.canUseInPhase(MatchState.getPhase())
				and light.Parent ~= nil
			state.battery = math.max(0, state.battery - dt)
			player:SetAttribute(
				MatchState.Attribute.FlashlightBattery,
				math.floor(state.battery / fullBattery * 100) / 100
			)
			if not canUse then
				setFlashlightOn(player, false)
			elseif state.battery <= 0 then
				-- 배터리가 다 닳으면 손전등이 사라진다.
				for slot = 1, Survivor.InventorySlots do
					if MatchState.getItem(player, slot) == "Flashlight" then
						setSlot(player, slot, nil)
					end
				end
				dropFlashlight(player)
				print(`[Item] {player.Name} 손전등 배터리 다 씀`)
			elseif parts and handler then
				local head = parts.character:FindFirstChild("Head")
				local origin = if head and head:IsA("BasePart") then head.Position else parts.rootPart.Position
				handler(origin, parts.rootPart.CFrame.LookVector, def.Range or 40, def.Angle or 30)
			end
		end
	end
end

-- 손전등 빛이 닿는 곳을 처리할 함수 (MonsterService.freezeInBeam). MonsterService가 Start에서 넘긴다.
function ItemService.setBeamHandler(handler: BeamHandler): ()
	beamHandler = handler
end

local function onUseItem(player: Player, slot: unknown, aim: unknown): ()
	if typeof(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > Survivor.InventorySlots then
		return
	end
	if not ItemState.canUseInPhase(MatchState.getPhase()) or not isActiveSurvivor(player) then
		return
	end
	if MatchState.isHidden(player) then
		return
	end
	local itemId = MatchState.getItem(player, slot)
	local parts = CharacterParts.get(player)
	if not itemId or not Items[itemId] or not parts then
		return
	end
	local aimPosition: Vector3? = if typeof(aim) == "Vector3" and aim == aim then aim else nil
	local result = applyItem(player, itemId, parts, aimPosition)
	if result == "Used" then
		setSlot(player, slot, nil)
		print(`[Item] {player.Name} 사용: {itemId} ({slot}번 칸)`)
	elseif result == "Kept" then
		local on = player:GetAttribute(MatchState.Attribute.FlashlightOn) == true
		print(`[Item] {player.Name} 손전등 {if on then "켬" else "끔"}`)
	else
		print(`[Item] {player.Name}: {itemId} 쓸 수 없음 (효과 없음)`)
	end
end

-- 연막 안에 있어 괴물·추격자에게 보이지 않는가 (GDD 6.3)
function ItemService.isConcealed(player: Player): boolean
	if #smokeZones == 0 then
		return false
	end
	local parts = CharacterParts.get(player)
	if not parts then
		return false
	end
	local position = parts.rootPart.Position
	for _, zone in smokeZones do
		if (position - zone.position).Magnitude <= zone.radius then
			return true
		end
	end
	return false
end

-- 불러온 맵의 ItemSpawn 중 일부에 아이템을 놓고, 모두의 아이템 칸을 비운다.
function ItemService.setupMap(map: Instance): ()
	ItemService.clearMap()
	local spawns: { BasePart } = {}
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:HasTag(MapTags.ItemSpawn) then
			table.insert(spawns, descendant)
		end
	end
	local count = math.round(#spawns * Config.SpawnFraction)
	local summary: { [string]: number } = {}
	for _ = 1, count do
		local spawnPart = table.remove(spawns, random:NextInteger(1, #spawns)) :: BasePart
		local itemId = rollItem()
		if itemId then
			placePickup(spawnPart, itemId, map)
			summary[itemId] = (summary[itemId] or 0) + 1
		end
	end
	local lines: { string } = {}
	for itemId, n in summary do
		table.insert(lines, `{itemId} {n}`)
	end
	table.sort(lines)
	print(`[Item] 아이템 {#pickups}개 배치 ({table.concat(lines, ", ")})`)
end

-- 남은 아이템·연막과 모두의 아이템 칸을 지운다. 맵을 지우기 전에 부른다.
function ItemService.clearMap(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, pickup in pickups do
		pickup:Destroy()
	end
	table.clear(pickups)
	for _, zone in smokeZones do
		zone.part:Destroy()
	end
	table.clear(smokeZones)
	for _, player in Players:GetPlayers() do
		clearInventory(player)
	end
end

function ItemService.Init(): () end

function ItemService.Start(): ()
	RemoteHandler.connect("UseItem", onUseItem)
	RunService.Heartbeat:Connect(function(dt: number)
		flashlightElapsed += dt
		if flashlightElapsed >= FLASHLIGHT_TICK then
			local step = flashlightElapsed
			flashlightElapsed = 0
			updateFlashlights(step)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		flashlights[player] = nil
	end)
	-- 잡히거나 탈출하면 아이템을 잃는다.
	local function watch(player: Player): ()
		player:GetAttributeChangedSignal(MatchState.Attribute.Role):Connect(function()
			if MatchState.getRole(player) ~= "Survivor" then
				clearInventory(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return ItemService
