--!strict
-- ObjectiveService: 발전기 수리와 출구·탈출 (GDD 3.1, 3.2, 6.2). GDD 13.2에서 StageService가 맡던 목표 장치·출구를 나눈 서비스.
-- 화면에 보이는 이름은 "에너지 코어"다 (2026-11-22 사용자 요청). 코드·태그·Attribute 이름은 Generator 그대로 둔다.
--
-- StageService가 준비 단계에서 맵을 불러오면 setupMap, 스테이지가 끝나면 clearMap을 부른다.
--
-- 발전기 (Generator 태그 Part 또는 Model. 모양·Attribute는 ObjectiveState)
--   몸체 가운데에 빛나는 큰 번개 모양(Config.MapObjects.Generator.Bolt)을 붙인다. 몸체를 앞뒤로 뚫고 지나가
--   넓은 두 면에 모두 보이고, 다 고치면 RepairedColor로 바뀐다 (2026-11-22 사용자 요청). 맵과 함께 지워진다.
--   윗면에 "수리" 프롬프트(HoldDuration 0)를 만들고, 누르고 있는 동안(Triggered ~ TriggerEnded) 고친다.
--   진행은 서버가 관리하고 손을 떼도 그대로 남는다. 혼자 Config.MapObjects.Generator.RepairTimeSolo초,
--   2명 이상이면 RepairTimeGroup초에 다 고친다. 기여(진행을 고친 사람 수로 나눔)는 RecordService에 기록한다.
--   수리 코인: 기여가 Config.Rewards.RepairCoinStep(10%) 쌓일 때마다 RepairCoins(1)를 바로 계정에 더한다
--   (DataService.addCoins, 저장됨). 남은 몫은 스테이지가 끝나면 버린다.
--   TickInterval마다 고치는 사람을 다시 검사한다: 추격 단계, 숨지 않은 생존자, 거리, 고치기 시작한 뒤 상태가
--   바뀌지 않음(맞으면 끊김). 하나라도 어긋나면 그 사람은 손을 다시 눌러야 한다.
--   고치는 동안 NoiseInterval초마다 소리를 낸다: 추격자 화면에 위치 표시(ChaserMarker, NoiseMarkerDuration초)와
--   사냥개가 들을 수 있는 소리 사건(server/Util/NoiseBus).
-- 출구 (Exit 태그 Part, 바깥 벽의 틈을 막고 있음)
--   발전기를 모두 고치면 Config.MapObjects.Exit.OpenCount곳(2곳 중 1곳)을 무작위로 연다: 통과할 수 있게 하고
--   빛나게 바꾸고 "출구" 표시를 띄운 뒤 모두에게 알림(Notice ExitOpened).
--   출구 파트 상자(EscapeMargin만큼 넓힘)에 들어간 생존자는 탈출(Escaped) → 관전자가 되고 캐릭터는 맵에서 빠진다.
-- 공개: ReplicatedStorage GeneratorsDone·GeneratorsTotal·ExitOpen, Player RepairProgress (MatchState).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapObjects = require(ReplicatedStorage.Shared.Config.MapObjects)
local Rewards = require(ReplicatedStorage.Shared.Config.Rewards)
local MapTags = require(ReplicatedStorage.Shared.MapTags)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local ObjectiveState = require(ReplicatedStorage.Shared.ObjectiveState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local PromptUtil = require(ReplicatedStorage.Shared.Util.PromptUtil)
local NoiseBus = require(script.Parent.Parent.Util.NoiseBus)
local DataService = require(script.Parent.DataService)
local RecordService = require(script.Parent.RecordService)
local RoleService = require(script.Parent.RoleService)

type Repairer = {
	state: Types.SurvivorState, -- 고치기 시작할 때의 상태. 바뀌면(맞으면) 끊김
}

type Generator = {
	instance: Instance,
	body: BasePart,
	bolt: { BasePart }, -- 가운데 번개 모양
	attachment: Attachment,
	prompt: ProximityPrompt,
	progress: number,
	repaired: boolean,
	repairers: { [Player]: Repairer },
	nextNoiseAt: number, -- os.clock
	shownProgress: number,
	shownRepairers: number,
}

local Attribute = MatchState.Attribute
local GeneratorAttribute = ObjectiveState.Attribute
local GeneratorConfig = MapObjects.Generator
local ExitConfig = MapObjects.Exit

local ObjectiveService = {}

local repairCredit: { [Player]: number } = {} -- 아직 코인으로 바꾸지 않은 수리 기여 (발전기 1대 = 1)

-- 수리 기여를 쌓고, RepairCoinStep만큼 쌓일 때마다 코인을 준다.
local function addRepairCredit(player: Player, amount: number): ()
	local credit = (repairCredit[player] or 0) + amount
	local steps = math.floor(credit / Rewards.RepairCoinStep + 1e-6)
	if steps > 0 then
		credit -= steps * Rewards.RepairCoinStep
		DataService.addCoins(player, steps * Rewards.RepairCoins, "발전기 수리")
	end
	repairCredit[player] = math.max(credit, 0)
end

local random = Random.new()
local generators: { Generator } = {}
local exits: { BasePart } = {}
local openExits: { BasePart } = {}
local repairingOf: { [Player]: Generator } = {}
local connections: { RBXScriptConnection } = {}
local heartbeat: RBXScriptConnection? = nil
local elapsed = 0

local function tagged(map: Instance, tag: string): { Instance }
	local found: { Instance } = {}
	for _, descendant in map:GetDescendants() do
		if descendant:HasTag(tag) then
			table.insert(found, descendant)
		end
	end
	return found
end

local function doneCount(): number
	local done = 0
	for _, generator in generators do
		if generator.repaired then
			done += 1
		end
	end
	return done
end

local function publishCounts(): ()
	ReplicatedStorage:SetAttribute(Attribute.GeneratorsDone, doneCount())
	ReplicatedStorage:SetAttribute(Attribute.GeneratorsTotal, #generators)
end

local function publishGenerator(generator: Generator): ()
	local step = GeneratorConfig.ProgressPublishStep
	local shown = math.floor(generator.progress / step + 1e-6) * step
	if shown ~= generator.shownProgress then
		generator.shownProgress = shown
		generator.instance:SetAttribute(GeneratorAttribute.Progress, shown)
	end
	local count = 0
	for _ in generator.repairers do
		count += 1
	end
	if count ~= generator.shownRepairers then
		generator.shownRepairers = count
		generator.instance:SetAttribute(GeneratorAttribute.Repairers, if count > 0 then count else nil)
	end
end

local function stopRepair(player: Player): ()
	local generator = repairingOf[player]
	if not generator then
		return
	end
	repairingOf[player] = nil
	generator.repairers[player] = nil
	player:SetAttribute(Attribute.RepairProgress, nil)
	publishGenerator(generator)
end

-- 고칠 수 있는가: 추격 단계, 다 고치지 않음, 숨지 않은 정상·부상 생존자, 프롬프트 거리 안
local function canRepair(player: Player, generator: Generator): boolean
	if generator.repaired or not ObjectiveState.canRepairInPhase(MatchState.getPhase()) then
		return false
	end
	local state = MatchState.getSurvivorState(player)
	if MatchState.getRole(player) ~= "Survivor" or (state ~= "Normal" and state ~= "Injured") then
		return false
	end
	if MatchState.isHidden(player) then
		return false
	end
	local parts = CharacterParts.get(player)
	if not parts then
		return false
	end
	local distance = (parts.rootPart.Position - generator.attachment.WorldPosition).Magnitude
	return distance <= GeneratorConfig.PromptDistance + GeneratorConfig.DistanceSlack
end

local function startRepair(player: Player, generator: Generator): ()
	if repairingOf[player] == generator or not canRepair(player, generator) then
		return
	end
	stopRepair(player)
	local state: Types.SurvivorState = MatchState.getSurvivorState(player) or "Normal"
	generator.repairers[player] = { state = state }
	repairingOf[player] = generator
	player:SetAttribute(Attribute.RepairProgress, generator.shownProgress)
	publishGenerator(generator)
end

-- 고치는 소리: 추격자 화면 표시와 사냥개용 소리 사건
local function makeNoise(generator: Generator, source: Player): ()
	local position = generator.body.Position
	NoiseBus.emit({
		kind = "Generator",
		position = position,
		radius = GeneratorConfig.NoiseRadius,
		source = source,
	})
	local marker = Remotes.get("ChaserMarker")
	for _, chaser in RoleService.getChasers() do
		marker:FireClient(chaser, position, GeneratorConfig.NoiseMarkerDuration, "GeneratorNoise" :: Types.MarkerReason)
	end
end

local function addExitMarker(exit: BasePart): ()
	local gui = Instance.new("BillboardGui")
	gui.Name = ObjectiveState.ExitMarkerName
	gui.Size = UDim2.fromOffset(140, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, exit.Size.Y / 2 + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = ExitConfig.MarkerMaxDistance
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = ExitConfig.OpenColor
	label.TextStrokeTransparency = 0.3
	label.Text = Strings.Hud.Exit
	label.Parent = gui
	gui.Parent = exit
end

local function unlockExits(): ()
	local candidates = table.clone(exits)
	for _ = 1, math.min(ExitConfig.OpenCount, #candidates) do
		local exit = table.remove(candidates, random:NextInteger(1, #candidates)) :: BasePart
		exit.CanCollide = false
		exit.CanQuery = false
		exit.Material = Enum.Material.Neon
		exit.Color = ExitConfig.OpenColor
		exit.Transparency = ExitConfig.OpenTransparency
		exit:SetAttribute(GeneratorAttribute.Open, true)
		addExitMarker(exit)
		table.insert(openExits, exit)
		print(`[Objective] 출구 열림: {exit.Name} (ExitId {exit:GetAttribute("ExitId")})`)
	end
	ReplicatedStorage:SetAttribute(Attribute.ExitOpen, true)
	Remotes.get("Notice"):FireAllClients("ExitOpened" :: Types.NoticeKey)
end

local function completeGenerator(generator: Generator): ()
	generator.repaired = true
	generator.progress = 1
	for player in generator.repairers do
		repairingOf[player] = nil
		player:SetAttribute(Attribute.RepairProgress, nil)
	end
	table.clear(generator.repairers)
	generator.prompt.Enabled = false
	generator.body.Color = GeneratorConfig.RepairedColor
	for _, part in generator.bolt do
		part.Color = GeneratorConfig.Bolt.RepairedColor
	end
	generator.instance:SetAttribute(GeneratorAttribute.Repaired, true)
	publishGenerator(generator)
	publishCounts()
	local done = doneCount()
	print(`[Objective] 발전기 {generator.instance.Name} 작동 ({done}/{#generators})`)
	if done == #generators and #openExits == 0 then
		unlockExits()
	end
end

-- 플레이어가 출구 상자 안에 있는가
local function isInExit(exit: BasePart, position: Vector3): boolean
	local localPosition = exit.CFrame:PointToObjectSpace(position)
	local half = exit.Size / 2 + Vector3.one * ExitConfig.EscapeMargin
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y
		and math.abs(localPosition.Z) <= half.Z
end

local function escape(player: Player, parts: CharacterParts.CharacterParts, exit: BasePart): ()
	stopRepair(player)
	RoleService.setSurvivorState(player, "Escaped")
	Remotes.get("Notice"):FireAllClients("SurvivorEscaped" :: Types.NoticeKey, player.DisplayName)
	print(`[Objective] {player.Name} 탈출: {exit.Name} → 관전자`)
	local character = parts.character
	parts.rootPart.Anchored = true
	task.delay(ExitConfig.LeaveDelay, function()
		if player.Character == character then
			player.Character = nil
		end
		character:Destroy()
	end)
end

local function step(dt: number): ()
	local now = os.clock()
	for _, generator in generators do
		if not generator.repaired and next(generator.repairers) then
			-- 다시 검사해서 조건이 어긋난 사람은 뺀다.
			local dropped: { Player } = {}
			for player, repairer in generator.repairers do
				if not canRepair(player, generator) or MatchState.getSurvivorState(player) ~= repairer.state then
					table.insert(dropped, player)
				end
			end
			for _, player in dropped do
				stopRepair(player)
			end

			local count = 0
			for _ in generator.repairers do
				count += 1
			end
			if count > 0 then
				local repairTime = if count == 1
					then GeneratorConfig.RepairTimeSolo
					else GeneratorConfig.RepairTimeGroup
				local added = math.min(dt / repairTime, 1 - generator.progress)
				generator.progress += added
				local source: Player? = nil
				for player in generator.repairers do
					RecordService.addGeneratorProgress(player, added / count)
					addRepairCredit(player, added / count)
					source = source or player
				end
				if now >= generator.nextNoiseAt and source then
					generator.nextNoiseAt = now + GeneratorConfig.NoiseInterval
					makeNoise(generator, source)
				end
				if generator.progress >= 1 - 1e-6 then
					completeGenerator(generator)
				else
					publishGenerator(generator)
					for player in generator.repairers do
						player:SetAttribute(Attribute.RepairProgress, generator.shownProgress)
					end
				end
			end
		end
	end

	if #openExits > 0 then
		for _, player in RoleService.getActiveSurvivors() do
			local parts = CharacterParts.get(player)
			if parts then
				for _, exit in openExits do
					if isInExit(exit, parts.rootPart.Position) then
						escape(player, parts, exit)
						break
					end
				end
			end
		end
	end
end

-- 몸체 가운데에 번개 모양을 만든다: 왼쪽 아래로 긋고, 오른쪽으로 꺾고, 다시 왼쪽 아래로 긋는 굵은 선 3개.
-- 좌표는 높이 1 기준(Config.MapObjects.Generator.Bolt.Strokes)이고 몸체 높이 × HeightFraction을 곱한다.
-- 수평으로 더 넓은 쪽 면에 그리고, 얇은 쪽으로 몸체를 뚫고 나와(DepthMargin) 앞뒤 두 면에 모두 보이게 한다.
local function addBolt(body: BasePart): { BasePart }
	local config = GeneratorConfig.Bolt
	local size = body.Size
	-- 앞뒤가 Z축이면 그대로, X축이 더 얇으면 90도 돌려 X축을 앞뒤로 쓴다.
	local wideIsX = size.X >= size.Z
	local basis = if wideIsX then body.CFrame else body.CFrame * CFrame.Angles(0, math.rad(90), 0)
	local depth = (if wideIsX then size.Z else size.X) + config.DepthMargin * 2
	local scale = size.Y * config.HeightFraction
	local thickness = config.Thickness * scale

	local folder = Instance.new("Model")
	folder.Name = "EnergyBolt"
	local parts: { BasePart } = {}
	for index, stroke in config.Strokes do
		local from = Vector3.new(stroke[1], stroke[2], 0) * scale
		local to = Vector3.new(stroke[3], stroke[4], 0) * scale
		local offset = to - from
		-- 선 방향을 파트의 Y축으로: Z축을 중심으로 돌린다 ((-sin, cos) = 방향).
		local angle = math.atan2(-offset.X, offset.Y)
		local part = Instance.new("Part")
		part.Name = `Stroke{index}`
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Massless = true
		part.Material = Enum.Material.Neon
		part.Color = config.Color
		part.Size = Vector3.new(thickness, offset.Magnitude + thickness, depth)
		part.CFrame = basis * CFrame.new((from + to) / 2) * CFrame.Angles(0, 0, angle)
		part.Parent = folder
		table.insert(parts, part)
	end
	folder.Parent = body
	return parts
end

local function addGenerator(instance: Instance): ()
	local body = ObjectiveState.getBody(instance)
	if not body then
		warn(
			`[Objective] {instance:GetFullName()}: {MapTags.Generator}는 Part이거나 Part가 든 Model이어야 합니다`
		)
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = ObjectiveState.PromptAttachmentName
	attachment.Position = Vector3.new(0, body.Size.Y / 2 + 0.5, 0)
	attachment.Parent = body

	local prompt = PromptUtil.new()
	prompt.Name = ObjectiveState.RepairPromptName
	prompt.ActionText = Strings.Prompts.Repair
	prompt.HoldDuration = 0 -- 누르고 있는 동안 고친다. 진행은 서버가 관리
	prompt.MaxActivationDistance = GeneratorConfig.PromptDistance
	prompt.RequiresLineOfSight = false
	prompt:AddTag(ObjectiveState.RepairPromptTag)
	prompt.Parent = attachment

	local generator: Generator = {
		instance = instance,
		body = body,
		bolt = addBolt(body),
		attachment = attachment,
		prompt = prompt,
		progress = 0,
		repaired = false,
		repairers = {},
		nextNoiseAt = 0,
		shownProgress = 0,
		shownRepairers = 0,
	}
	instance:SetAttribute(GeneratorAttribute.Progress, 0)
	table.insert(
		connections,
		prompt.Triggered:Connect(function(player: Player)
			startRepair(player, generator)
		end)
	)
	table.insert(
		connections,
		prompt.TriggerEnded:Connect(function(player: Player)
			if repairingOf[player] == generator then
				stopRepair(player)
			end
		end)
	)
	table.insert(generators, generator)
end

-- 불러온 맵의 발전기에 수리 프롬프트를 만들고 출구를 준비한다.
function ObjectiveService.setupMap(map: Instance, stageId: Types.StageId): ()
	ObjectiveService.clearMap()
	for _, instance in tagged(map, MapTags.Generator) do
		addGenerator(instance)
	end
	for _, instance in tagged(map, MapTags.Exit) do
		if instance:IsA("BasePart") then
			table.insert(exits, instance)
		end
	end
	local expected = Stages[stageId].GeneratorCount
	if #generators ~= expected then
		warn(
			`[Objective] {stageId}: 발전기가 {#generators}대라 Config의 {expected}대와 다릅니다 (맵에 있는 수로 진행)`
		)
	end
	if #exits < ExitConfig.OpenCount then
		warn(`[Objective] {stageId}: {MapTags.Exit} Part가 {#exits}개뿐입니다`)
	end
	publishCounts()
	ReplicatedStorage:SetAttribute(Attribute.ExitOpen, nil)
	elapsed = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= GeneratorConfig.TickInterval then
			local stepTime = elapsed
			elapsed = 0
			step(stepTime)
		end
	end)
	print(`[Objective] 발전기 {#generators}대, 출구 {#exits}곳 준비`)
end

-- 수리를 멈추고 프롬프트를 지운다. 맵을 지우기 전에 부른다.
function ObjectiveService.clearMap(): ()
	table.clear(repairCredit)
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for player in repairingOf do
		player:SetAttribute(Attribute.RepairProgress, nil)
	end
	table.clear(repairingOf)
	for _, generator in generators do
		generator.attachment:Destroy()
	end
	table.clear(generators)
	table.clear(exits)
	table.clear(openExits)
	ReplicatedStorage:SetAttribute(Attribute.GeneratorsDone, nil)
	ReplicatedStorage:SetAttribute(Attribute.GeneratorsTotal, nil)
	ReplicatedStorage:SetAttribute(Attribute.ExitOpen, nil)
end

function ObjectiveService.Init(): () end

function ObjectiveService.Start(): ()
	Players.PlayerRemoving:Connect(function(player: Player)
		stopRepair(player)
		repairCredit[player] = nil
	end)
end

return ObjectiveService
