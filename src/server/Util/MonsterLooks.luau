--!strict
-- 화면 모드에 맞춰 괴물 모델을 꾸민다 (Config.MonsterLooks, 2026-11-21 사용자 요청). MonsterService.createMonster가
-- 모델을 복제해 세운 뒤, Workspace에 넣기 전에 부른다.
--   몸 색(BodyColors도 함께), 눈(EyeL·EyeR 파트를 옮기고 모양·색을 바꿔 감시자 경보의 눈 색 바꾸기가 그대로 동작),
--   머리 PointLight 밝기, 장식 파트(붙일 몸 파트에 WeldConstraint로 붙임), 발밑 안개(ParticleEmitter).
-- 장식은 부딪히지 않고 질량이 없어 괴물의 움직임·길찾기·시야·공격 판정에 영향이 없다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterLooksConfig = require(ReplicatedStorage.Shared.Config.MonsterLooks)
local Types = require(ReplicatedStorage.Shared.Types)

local EYE_NAMES = { "EyeL", "EyeR" }

local MonsterLooks = {}

local function partType(shape: MonsterLooksConfig.Shape?): Enum.PartType
	if shape == "Ball" then
		return Enum.PartType.Ball
	elseif shape == "Cylinder" then
		return Enum.PartType.Cylinder
	end
	return Enum.PartType.Block
end

local function rotation(degrees: Vector3?): CFrame
	if not degrees then
		return CFrame.identity
	end
	return CFrame.fromOrientation(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

-- 좌우(X)를 뒤집은 회전: X축 회전은 그대로, Y·Z축 회전은 반대로
local function mirrored(degrees: Vector3?): Vector3?
	return if degrees then Vector3.new(degrees.X, -degrees.Y, -degrees.Z) else nil
end

-- 장식·눈 파트가 물리와 판정에 끼어들지 않게 한다.
local function makeCosmetic(part: BasePart): ()
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

local function weld(part0: BasePart, part1: BasePart): ()
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = part0
	weldConstraint.Part1 = part1
	weldConstraint.Parent = part1
end

local function originalEyeColor(model: Model): Color3
	local eye = model:FindFirstChild("EyeL", true)
	return if eye and eye:IsA("BasePart") then eye.Color else Color3.new(1, 1, 1)
end

local function applyBodyColor(model: Model, color: Color3): ()
	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant.Name ~= "HumanoidRootPart"
			and not table.find(EYE_NAMES, descendant.Name)
		then
			descendant.Color = color
		end
	end
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = color
		bodyColors.TorsoColor3 = color
		bodyColors.LeftArmColor3 = color
		bodyColors.RightArmColor3 = color
		bodyColors.LeftLegColor3 = color
		bodyColors.RightLegColor3 = color
	end
end

local function applyEyes(model: Model, head: BasePart, look: MonsterLooksConfig.EyeLook, scale: number): ()
	for _, name in EYE_NAMES do
		local eye = model:FindFirstChild(name, true)
		if eye and eye:IsA("BasePart") then
			-- 원래 자리의 좌우로 어느 눈인지 정한다 (+X 오른쪽).
			local side = if head.CFrame:PointToObjectSpace(eye.Position).X >= 0 then 1 else -1
			for _, child in eye:GetChildren() do
				if child:IsA("WeldConstraint") then
					child:Destroy()
				end
			end
			local offset = look.Offset * scale
			local degrees = if side > 0 then look.Rotation else mirrored(look.Rotation)
			if eye:IsA("Part") then
				eye.Shape = partType(look.Shape)
			end
			eye.Size = look.Size * scale
			eye.CFrame = head.CFrame * CFrame.new(offset.X * side, offset.Y, offset.Z) * rotation(degrees)
			if look.Color then
				eye.Color = look.Color
			end
			if look.Material then
				eye.Material = look.Material
			end
			makeCosmetic(eye)
			weld(head, eye)
		end
	end
end

local function addDecoration(
	model: Model,
	decoration: MonsterLooksConfig.Decoration,
	scale: number,
	side: number,
	eyeColor: Color3
): boolean
	local attach = model:FindFirstChild(decoration.Attach, true)
	if not attach or not attach:IsA("BasePart") then
		return false
	end
	local part = Instance.new("Part")
	part.Name = `Decor{decoration.Name}`
	part.Shape = partType(decoration.Shape)
	part.Size = decoration.Size * scale
	part.Color = decoration.Color or eyeColor
	part.Material = decoration.Material or Enum.Material.SmoothPlastic
	part.Transparency = decoration.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	makeCosmetic(part)
	local offset = decoration.Offset * scale
	local degrees = if side > 0 then decoration.Rotation else mirrored(decoration.Rotation)
	part.CFrame = attach.CFrame * CFrame.new(offset.X * side, offset.Y, offset.Z) * rotation(degrees)
	weld(attach, part)
	part.Parent = attach
	return true
end

local function addMist(model: Model, scale: number): ()
	local lowerTorso = model:FindFirstChild("LowerTorso")
	if not lowerTorso or not lowerTorso:IsA("BasePart") then
		return
	end
	local mist = MonsterLooksConfig.Mist
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "NightMist"
	emitter.Texture = mist.Texture
	emitter.Color = ColorSequence.new(mist.Color)
	emitter.Rate = mist.Rate
	emitter.Lifetime = NumberRange.new(mist.Lifetime * 0.8, mist.Lifetime * 1.2)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, mist.Size * scale * 0.6),
		NumberSequenceKeypoint.new(1, mist.Size * scale),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, mist.Transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Speed = NumberRange.new(0.5, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 20)
	emitter.Acceleration = Vector3.new(0, -0.5, 0)
	emitter.LightInfluence = 1
	emitter.Parent = lowerTorso
end

-- 모델을 mode에 맞게 꾸민다. 붙인 장식 수를 돌려준다 (꾸밈이 없으면 0).
function MonsterLooks.apply(model: Model, kind: Types.MonsterId, mode: Types.VisualMode): number
	local looks = MonsterLooksConfig.Modes[mode]
	local look = looks and looks[kind]
	local head = model:FindFirstChild("Head")
	if not look or not head or not head:IsA("BasePart") then
		return 0
	end
	local scale = head.Size.Y / MonsterLooksConfig.BaseHeadSize
	local eyeColor = originalEyeColor(model)

	if look.BodyColor then
		applyBodyColor(model, look.BodyColor)
	end
	if look.Eyes then
		applyEyes(model, head, look.Eyes, scale)
	end
	if look.LightBrightness then
		local light = head:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness *= look.LightBrightness
		end
	end
	local count = 0
	for _, decoration in look.Decorations do
		if addDecoration(model, decoration, scale, 1, eyeColor) then
			count += 1
		end
		if decoration.Mirror and addDecoration(model, decoration, scale, -1, eyeColor) then
			count += 1
		end
	end
	if look.Mist then
		addMist(model, scale)
	end
	return count
end

return MonsterLooks
