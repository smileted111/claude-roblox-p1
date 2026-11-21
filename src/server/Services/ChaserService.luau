--!strict
-- ChaserService: 추격자 종류·고유 스킬·전용 외형과 로비의 추격자 선택·해금 (GDD 7.1, 9장, 질문지 Q2-5·Q7-2).
-- GDD 13.2 목록 밖에 추가한 서비스. 종류별 스킬은 server/Chasers/<Name>.luau (ChaserTypes.Skill).
--
-- 종류: 로비에서 고른 추격자(DataService SelectedChaser, 해금한 것만)가 스테이지에서 추격자가 되면 쓰인다.
--   추격자 역할이 정해지면 Player Attribute ChaserType에 넣는다. 속도(MovementService)·공격 값(CatchService)도 이 종류를 따른다.
-- 외형: ServerStorage.ChaserModels.<ChaserId> 리그의 HumanoidDescription으로 캐릭터를 불러온다 (loadCharacter,
--   StageService가 추격자를 대기실에 놓을 때). 기본 애니메이션은 그대로 쓴다. 모델이 없으면 플레이어 아바타.
-- 스킬 (UseSkill 리모트, 인자: 바라보는 방향): 빈도 제한·관전자 거절은 RemoteHandler. 추격자, 추격 단계, 기절 아님,
--   쿨다운이 지남, 방향이 올바른 수평 벡터 → 스킬 모듈의 use. 쓰였으면 쿨다운 시작 (Player Attribute SkillReadyAt).
-- 선택·해금 (ChaserSelect 리모트): 매치 밖(역할 없음)에서만. Select는 해금한 종류만, Unlock은 코인으로 (Chasers.UnlockCost).
--   추격자 확률을 높이는 상품·기능은 없다 (GDD 10장).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CatchState = require(ReplicatedStorage.Shared.CatchState)
local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local Match = require(ReplicatedStorage.Shared.Config.Match)
local MatchState = require(ReplicatedStorage.Shared.MatchState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Strings = require(ReplicatedStorage.Shared.Strings)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local ChaserTypes = require(script.Parent.Parent.Chasers.ChaserTypes)
local Hunter = require(script.Parent.Parent.Chasers.Hunter)
local Puppeteer = require(script.Parent.Parent.Chasers.Puppeteer)
local Tracker = require(script.Parent.Parent.Chasers.Tracker)
local Wraith = require(script.Parent.Parent.Chasers.Wraith)
local RemoteHandler = require(script.Parent.Parent.Util.RemoteHandler)
local DataService = require(script.Parent.DataService)
local LanguageService = require(script.Parent.LanguageService)
local HideService = require(script.Parent.HideService)
local MonsterService = require(script.Parent.MonsterService)
local MovementService = require(script.Parent.MovementService)
local RoleService = require(script.Parent.RoleService)

local MODELS_FOLDER = "ChaserModels" -- ServerStorage.ChaserModels

local SKILLS: { [Types.ChaserId]: ChaserTypes.Skill } = {
	Hunter = Hunter,
	Tracker = Tracker,
	Wraith = Wraith,
	Puppeteer = Puppeteer,
}

local Attribute = MatchState.Attribute

local ChaserService = {}

local readyAt: { [Player]: number } = {} -- 스킬을 다시 쓸 수 있는 os.clock

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.RespectCanCollide = true

local function isChaserId(value: unknown): boolean
	return typeof(value) == "string" and Chasers[value :: Types.ChaserId] ~= nil
end

-- 이 플레이어가 고른 추격자 (해금하지 않았으면 기본)
local function selectedChaser(player: Player): Types.ChaserId
	local data = DataService.getData(player)
	local selected = data and data.SelectedChaser
	if selected and isChaserId(selected) and data and data.UnlockedChasers[selected] then
		return selected :: Types.ChaserId
	end
	return Match.DefaultChaser
end

--------------------------------------------------------------------------------
-- 스킬

local function refreshWallFilter(): ()
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
	wallParams.FilterDescendantsInstances = ignore
end

local api: ChaserTypes.SkillApi = {
	boost = function(player: Player, multiplier: number, seconds: number): ()
		MovementService.boost(player, multiplier, seconds)
	end,
	summonMonsters = function(position: Vector3, count: number, seconds: number, source: string): number
		return MonsterService.summon(position, count, seconds, source)
	end,
	survivorFootPositions = function(): { Vector3 }
		local positions: { Vector3 } = {}
		for _, survivor in RoleService.getActiveSurvivors() do
			local parts = if HideService.isHidden(survivor) then nil else CharacterParts.get(survivor)
			if parts then
				local footY = parts.rootPart.Position.Y - parts.rootPart.Size.Y / 2 - parts.humanoid.HipHeight
				table.insert(positions, Vector3.new(parts.rootPart.Position.X, footY, parts.rootPart.Position.Z))
			end
		end
		return positions
	end,
	sendFootprints = function(player: Player, positions: { Vector3 }, lifetime: number): ()
		Remotes.get("Footprints"):FireClient(player, positions, lifetime)
	end,
	raycastWalls = function(origin: Vector3, direction: Vector3): RaycastResult?
		refreshWallFilter()
		return Workspace:Raycast(origin, direction, wallParams)
	end,
	isActive = function(player: Player): boolean
		return player.Parent == Players
			and MatchState.getRole(player) == "Chaser"
			and CatchState.canHitInPhase(MatchState.getPhase())
	end,
}

local function onUseSkill(player: Player, lookDirection: unknown): ()
	if typeof(lookDirection) ~= "Vector3" then
		return
	end
	local flat = Vector3.new(lookDirection.X, 0, lookDirection.Z)
	if flat.Magnitude < 1e-3 or flat.Magnitude ~= flat.Magnitude then
		return
	end
	if not api.isActive(player) or MovementService.isStunned(player) then
		return
	end
	local now = os.clock()
	if now < (readyAt[player] or 0) then
		return
	end
	local parts = CharacterParts.get(player)
	if not parts then
		return
	end
	local chaserType = MatchState.getChaserType(player) or Match.DefaultChaser
	local def = Chasers[chaserType].Skill
	local used = SKILLS[chaserType].use({
		player = player,
		parts = parts,
		def = def,
		lookDirection = flat.Unit,
	}, api)
	if not used then
		print(`[Chaser] {player.Name} {Strings.Skills[def.Kind]}: 효과 없음 (쿨다운 없음)`)
		return
	end
	readyAt[player] = now + def.Cooldown
	player:SetAttribute(Attribute.SkillReadyAt, Workspace:GetServerTimeNow() + def.Cooldown)
	print(`[Chaser] {player.Name} {Strings.Skills[def.Kind]} 사용 (쿨다운 {def.Cooldown}초)`)
end

--------------------------------------------------------------------------------
-- 역할과 외형

local function onRoleChanged(player: Player): ()
	if MatchState.getRole(player) == "Chaser" then
		local chaserType = selectedChaser(player)
		player:SetAttribute(Attribute.ChaserType, chaserType)
		readyAt[player] = 0
		player:SetAttribute(Attribute.SkillReadyAt, nil)
		print(`[Chaser] {player.Name} 추격자 종류: {chaserType}`)
	else
		player:SetAttribute(Attribute.ChaserType, nil)
		player:SetAttribute(Attribute.SkillReadyAt, nil)
		readyAt[player] = nil
	end
end

-- 추격자 전용 외형으로 캐릭터를 새로 불러온다 (멈춤). 모델이 없으면 평소 아바타로 불러온다.
function ChaserService.loadCharacter(player: Player): Model?
	local chaserType = MatchState.getChaserType(player) or selectedChaser(player)
	local models = ServerStorage:FindFirstChild(MODELS_FOLDER)
	local template = models and models:FindFirstChild(chaserType)
	local humanoid = template and template:FindFirstChildOfClass("Humanoid")
	local description = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
	if description then
		player:LoadCharacterWithHumanoidDescriptionAsync(description:Clone())
	else
		warn(
			`[Chaser] ServerStorage.{MODELS_FOLDER}.{chaserType}의 HumanoidDescription이 없어 아바타로 불러옵니다`
		)
		player:LoadCharacterAsync()
	end
	return player.Character
end

--------------------------------------------------------------------------------
-- 로비의 선택·해금

local function onChaserSelect(player: Player, action: unknown, chaserId: unknown): ()
	if not isChaserId(chaserId) or MatchState.getRole(player) ~= nil then
		return
	end
	local id = chaserId :: Types.ChaserId
	local data = DataService.getData(player)
	if not data then
		return
	end
	local notice = Remotes.get("Notice")
	if action == "Select" then
		if data.UnlockedChasers[id] then
			DataService.setSelectedChaser(player, id)
			print(`[Chaser] {player.Name} 추격자 선택: {id}`)
		end
	elseif action == "Unlock" then
		local def = Chasers[id]
		if data.UnlockedChasers[id] or def.Unlock ~= "Coins" then
			return
		end
		if DataService.spendCoins(player, def.UnlockCost, `추격자 해금 {id}`) then
			DataService.unlockChaser(player, id)
			DataService.setSelectedChaser(player, id)
			notice:FireClient(
				player,
				"ChaserUnlocked" :: Types.NoticeKey,
				LanguageService.stringsFor(player).Chasers[id]
			)
			DataService.save(player)
		else
			notice:FireClient(player, "NotEnoughCoins" :: Types.NoticeKey)
		end
	end
end

function ChaserService.Init(): () end

function ChaserService.Start(): ()
	local function watch(player: Player): ()
		player:GetAttributeChangedSignal(Attribute.Role):Connect(function()
			onRoleChanged(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		readyAt[player] = nil
	end)
	RemoteHandler.connect("UseSkill", onUseSkill)
	RemoteHandler.connect("ChaserSelect", onChaserSelect)
end

return ChaserService
