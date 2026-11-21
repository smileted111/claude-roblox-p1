--!strict
-- 화면 모드별 괴물 꾸미기 (2026-11-21 사용자 요청). server/Util/MonsterLooks가 괴물을 만들 때(MonsterService) 붙인다.
--   캐주얼: 파스텔 몸 색, 큰 동그란 눈(흰자 + 검은 눈동자 + 반짝임), 볼터치, 웃는 입, 괴물마다 귀여운 장식(새싹·강아지 귀·안테나·
--           고양이 귀·곰 귀와 나비넥타이).
--   나이트: 원래 검은 실루엣에 날카롭게 기운 빛나는 눈, 더 밝은 눈빛, 공포 소품(두건·망토·가시·목줄과 쇠사슬·제3의 눈·
--           뿔·가시 어깨 갑옷), 발밑의 어두운 안개. 피·신체 훼손 표현은 넣지 않는다 (GDD 12장).
-- 모든 장식은 부딪히지 않고(CanCollide·CanQuery·CanTouch 끔) 무게가 없어(Massless) 움직임·시야·공격 판정에 영향이 없다.
-- 크기·위치는 배회자(머리 BaseHeadSize) 기준이고, 괴물마다 머리 크기 비율을 곱한다 (사냥개 0.75, 감시자 1.33, 거인 1.67).
-- 위치는 붙일 파트 기준이다: +X 오른쪽, +Y 위, -Z 앞 (얼굴 쪽).
-- 그림자는 어두운 구역에서 장식까지 함께 투명해지도록 빛·입자를 붙이지 않는다 (Monsters/Shadow).
-- 색·크기는 모두 임시다 (화면을 보고 조정).

local Types = require(script.Parent.Parent.Types)

export type Shape = "Block" | "Ball" | "Cylinder"

export type Decoration = {
	Name: string,
	Attach: string, -- 붙일 몸 파트 이름 (Head, UpperTorso, LeftUpperArm 등)
	Size: Vector3,
	Offset: Vector3,
	Rotation: Vector3?, -- 도 (X, Y, Z 순서로 돌림)
	Shape: Shape?, -- 없으면 Block
	Color: Color3?, -- 없으면 원래 눈 색 (감시자의 제3의 눈 등)
	Material: Enum.Material?, -- 없으면 SmoothPlastic
	Transparency: number?,
	Mirror: boolean?, -- true면 좌우(X)를 뒤집은 것을 하나 더 붙인다 (양쪽 귀·뿔)
}

export type EyeLook = {
	Size: Vector3,
	Offset: Vector3, -- 오른쪽 눈 기준. 왼쪽 눈은 X를 뒤집는다
	Rotation: Vector3?, -- 오른쪽 눈 기준 (왼쪽은 Y·Z를 뒤집음)
	Shape: Shape?,
	Color: Color3?, -- 없으면 원래 색 (괴물마다 다른 빛나는 눈 색, UiStyle.MonsterColors와 맞춤)
	Material: Enum.Material?,
}

export type Look = {
	BodyColor: Color3?, -- 머리·몸 전체 색. 없으면 원래 색
	Eyes: EyeLook?, -- EyeL·EyeR 파트를 옮기고 바꾼다 (감시자 경보는 이 파트 색을 바꿈)
	LightBrightness: number?, -- 머리 PointLight 밝기 배율. 없으면 그대로
	Mist: boolean?, -- 발밑 어두운 안개 (ParticleEmitter)
	Decorations: { Decoration },
}

export type MistConfig = {
	Texture: string,
	Color: Color3,
	Rate: number, -- 초당 입자 수
	Lifetime: number, -- 초
	Size: number, -- 배회자 기준 (머리 비율을 곱함)
	Transparency: number, -- 처음 투명도 (사라질 때 1)
}

export type MonsterLooksConfig = {
	BaseHeadSize: number, -- 크기 기준 머리 크기 (배회자 머리 높이)
	Mist: MistConfig,
	Modes: { [Types.VisualMode]: { [Types.MonsterId]: Look } },
}

local WHITE = Color3.fromRGB(255, 255, 255)
local PUPIL = Color3.fromRGB(35, 30, 40)
local BLUSH = Color3.fromRGB(255, 150, 180)
local MOUTH = Color3.fromRGB(70, 40, 45)
local CLOTH = Color3.fromRGB(32, 28, 38)
local IRON = Color3.fromRGB(70, 70, 76)
local BONE = Color3.fromRGB(190, 180, 155)

-- 캐주얼 공통 얼굴: 흰자·반짝임·볼터치 (+ 웃는 입)
local function cuteFace(withSmile: boolean): { Decoration }
	local face: { Decoration } = {
		{
			Name = "EyeWhite",
			Attach = "Head",
			Size = Vector3.new(0.5, 0.5, 0.5),
			Offset = Vector3.new(0.26, 0.13, -0.46),
			Shape = "Ball",
			Color = WHITE,
			Mirror = true,
		},
		{
			Name = "EyeSparkle",
			Attach = "Head",
			Size = Vector3.new(0.09, 0.09, 0.09),
			Offset = Vector3.new(0.22, 0.17, -0.74),
			Shape = "Ball",
			Color = WHITE,
			Material = Enum.Material.Neon,
			Mirror = true,
		},
		{
			Name = "Blush",
			Attach = "Head",
			Size = Vector3.new(0.26, 0.12, 0.05),
			Offset = Vector3.new(0.43, -0.15, -0.6),
			Color = BLUSH,
			Transparency = 0.15,
			Mirror = true,
		},
	}
	if withSmile then
		table.insert(face, {
			Name = "Smile",
			Attach = "Head",
			Size = Vector3.new(0.24, 0.06, 0.05),
			Offset = Vector3.new(0, -0.29, -0.61),
			Color = MOUTH,
		})
		table.insert(face, {
			Name = "SmileEnd",
			Attach = "Head",
			Size = Vector3.new(0.1, 0.05, 0.05),
			Offset = Vector3.new(0.15, -0.26, -0.61),
			Rotation = Vector3.new(0, 0, 35),
			Color = MOUTH,
			Mirror = true,
		})
	end
	return face
end

local function with(base: { Decoration }, extra: { Decoration }): { Decoration }
	local list = table.clone(base)
	for _, decoration in extra do
		table.insert(list, decoration)
	end
	return list
end

-- 캐주얼 눈동자 (EyeL·EyeR): 흰자 앞의 검은 동그라미
local CUTE_EYES: EyeLook = {
	Size = Vector3.new(0.25, 0.25, 0.25),
	Offset = Vector3.new(0.26, 0.11, -0.62),
	Shape = "Ball",
	Color = PUPIL,
	Material = Enum.Material.SmoothPlastic,
}

-- 나이트 눈: 길고 안쪽으로 기운 빛나는 눈 (색은 괴물마다 원래 색)
local SCARY_EYES: EyeLook = {
	Size = Vector3.new(0.36, 0.11, 0.1),
	Offset = Vector3.new(0.25, 0.12, -0.6),
	Rotation = Vector3.new(0, 0, 14),
	Material = Enum.Material.Neon,
}

-- 나이트 두건과 해진 망토 (배회자·그림자)
local function hoodAndCloak(color: Color3, long: boolean): { Decoration }
	local cloakHeight = if long then 2.8 else 2
	local list: { Decoration } = {
		{
			Name = "HoodTop",
			Attach = "Head",
			Size = Vector3.new(1.42, 0.22, 1.3),
			Offset = Vector3.new(0, 0.68, 0.05),
			Color = color,
			Material = Enum.Material.Fabric,
		},
		{
			Name = "HoodBack",
			Attach = "Head",
			Size = Vector3.new(1.42, 1.35, 0.22),
			Offset = Vector3.new(0, 0.02, 0.68),
			Color = color,
			Material = Enum.Material.Fabric,
		},
		{
			Name = "HoodSide",
			Attach = "Head",
			Size = Vector3.new(0.2, 1.2, 1.25),
			Offset = Vector3.new(0.71, 0.05, 0.08),
			Color = color,
			Material = Enum.Material.Fabric,
			Mirror = true,
		},
		{
			Name = "Cloak",
			Attach = "UpperTorso",
			Size = Vector3.new(1.95, cloakHeight, 0.14),
			Offset = Vector3.new(0, 0.95 - cloakHeight / 2, 0.55),
			Color = color,
			Material = Enum.Material.Fabric,
		},
	}
	-- 망토 끝의 해진 조각
	for index, x in { -0.65, 0, 0.6 } do
		table.insert(list, {
			Name = `CloakRag{index}`,
			Attach = "UpperTorso",
			Size = Vector3.new(0.42, 0.55, 0.12),
			Offset = Vector3.new(x, 0.95 - cloakHeight - 0.2, 0.57),
			Rotation = Vector3.new(0, 0, (index - 2) * 9),
			Color = color,
			Material = Enum.Material.Fabric,
		})
	end
	return list
end

local MonsterLooks: MonsterLooksConfig = {
	BaseHeadSize = 1.2,
	Mist = {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = Color3.fromRGB(40, 30, 55),
		Rate = 3,
		Lifetime = 1.6,
		Size = 2.2,
		Transparency = 0.55,
	},
	Modes = {
		Casual = {
			-- 민트색 + 머리 위 새싹
			Wanderer = {
				BodyColor = Color3.fromRGB(150, 228, 190),
				Eyes = CUTE_EYES,
				Decorations = with(cuteFace(true), {
					{
						Name = "SproutStem",
						Attach = "Head",
						Size = Vector3.new(0.08, 0.4, 0.08),
						Offset = Vector3.new(0, 0.8, 0),
						Color = Color3.fromRGB(80, 170, 80),
					},
					{
						Name = "SproutLeaf",
						Attach = "Head",
						Size = Vector3.new(0.32, 0.05, 0.18),
						Offset = Vector3.new(0.15, 1, 0),
						Rotation = Vector3.new(0, 0, 25),
						Color = Color3.fromRGB(110, 210, 100),
						Mirror = true,
					},
				}),
			},
			-- 살구색 강아지: 늘어진 귀, 코, 혀
			Hound = {
				BodyColor = Color3.fromRGB(242, 196, 150),
				Eyes = CUTE_EYES,
				Decorations = with(cuteFace(false), {
					{
						Name = "Ear",
						Attach = "Head",
						Size = Vector3.new(0.22, 0.62, 0.4),
						Offset = Vector3.new(0.62, 0.02, 0),
						Rotation = Vector3.new(0, 0, 14),
						Color = Color3.fromRGB(176, 118, 78),
						Mirror = true,
					},
					{
						Name = "Nose",
						Attach = "Head",
						Size = Vector3.new(0.2, 0.2, 0.2),
						Offset = Vector3.new(0, -0.1, -0.66),
						Shape = "Ball",
						Color = Color3.fromRGB(70, 45, 40),
					},
					{
						Name = "Tongue",
						Attach = "Head",
						Size = Vector3.new(0.16, 0.05, 0.16),
						Offset = Vector3.new(0, -0.33, -0.63),
						Rotation = Vector3.new(-20, 0, 0),
						Color = Color3.fromRGB(255, 120, 150),
					},
				}),
			},
			-- 라벤더색 + 반짝이는 안테나
			Watcher = {
				BodyColor = Color3.fromRGB(205, 186, 252),
				Eyes = CUTE_EYES,
				Decorations = with(cuteFace(true), {
					{
						Name = "AntennaStem",
						Attach = "Head",
						Size = Vector3.new(0.06, 0.5, 0.06),
						Offset = Vector3.new(0, 0.85, 0),
						Color = Color3.fromRGB(120, 110, 150),
					},
					{
						Name = "AntennaBall",
						Attach = "Head",
						Size = Vector3.new(0.26, 0.26, 0.26),
						Offset = Vector3.new(0, 1.15, 0),
						Shape = "Ball",
						Color = Color3.fromRGB(255, 228, 90),
						Material = Enum.Material.Neon,
					},
				}),
			},
			-- 연보라 고양이 귀
			Shadow = {
				BodyColor = Color3.fromRGB(172, 162, 214),
				Eyes = CUTE_EYES,
				Decorations = with(cuteFace(true), {
					{
						Name = "CatEar",
						Attach = "Head",
						Size = Vector3.new(0.32, 0.32, 0.14),
						Offset = Vector3.new(0.36, 0.64, 0),
						Rotation = Vector3.new(0, 0, 45),
						Color = Color3.fromRGB(150, 140, 200),
						Mirror = true,
					},
					{
						Name = "CatEarInner",
						Attach = "Head",
						Size = Vector3.new(0.18, 0.18, 0.06),
						Offset = Vector3.new(0.36, 0.66, -0.06),
						Rotation = Vector3.new(0, 0, 45),
						Color = BLUSH,
						Mirror = true,
					},
				}),
			},
			-- 곰 인형: 둥근 귀, 주둥이와 코, 빨간 나비넥타이
			Giant = {
				BodyColor = Color3.fromRGB(176, 126, 86),
				Eyes = CUTE_EYES,
				Decorations = with(cuteFace(false), {
					{
						Name = "BearEar",
						Attach = "Head",
						Size = Vector3.new(0.5, 0.5, 0.5),
						Offset = Vector3.new(0.5, 0.56, 0),
						Shape = "Ball",
						Color = Color3.fromRGB(150, 104, 70),
						Mirror = true,
					},
					{
						Name = "BearEarInner",
						Attach = "Head",
						Size = Vector3.new(0.28, 0.28, 0.28),
						Offset = Vector3.new(0.5, 0.56, -0.14),
						Shape = "Ball",
						Color = Color3.fromRGB(232, 200, 160),
						Mirror = true,
					},
					{
						Name = "Muzzle",
						Attach = "Head",
						Size = Vector3.new(0.5, 0.5, 0.5),
						Offset = Vector3.new(0, -0.2, -0.5),
						Shape = "Ball",
						Color = Color3.fromRGB(232, 200, 160),
					},
					{
						Name = "Nose",
						Attach = "Head",
						Size = Vector3.new(0.18, 0.18, 0.18),
						Offset = Vector3.new(0, -0.12, -0.76),
						Shape = "Ball",
						Color = Color3.fromRGB(60, 40, 35),
					},
					{
						Name = "Bow",
						Attach = "UpperTorso",
						Size = Vector3.new(0.3, 0.24, 0.08),
						Offset = Vector3.new(0.18, 0.75, -0.49),
						Rotation = Vector3.new(0, 0, 12),
						Color = Color3.fromRGB(230, 60, 80),
						Mirror = true,
					},
					{
						Name = "BowKnot",
						Attach = "UpperTorso",
						Size = Vector3.new(0.13, 0.13, 0.1),
						Offset = Vector3.new(0, 0.75, -0.51),
						Color = Color3.fromRGB(200, 40, 60),
					},
				}),
			},
		},
		Night = {
			-- 두건과 긴 해진 망토
			Wanderer = {
				Eyes = SCARY_EYES,
				LightBrightness = 1.6,
				Mist = true,
				Decorations = hoodAndCloak(CLOTH, true),
			},
			-- 등 가시, 가시 목줄과 쇠사슬
			Hound = {
				Eyes = SCARY_EYES,
				LightBrightness = 1.6,
				Mist = true,
				Decorations = {
					{
						Name = "Collar",
						Attach = "UpperTorso",
						Size = Vector3.new(0.26, 1.15, 1.15),
						Offset = Vector3.new(0, 0.95, 0),
						Rotation = Vector3.new(0, 0, 90),
						Shape = "Cylinder",
						Color = Color3.fromRGB(80, 22, 26),
						Material = Enum.Material.Leather,
					},
					{
						Name = "CollarSpike",
						Attach = "UpperTorso",
						Size = Vector3.new(0.12, 0.12, 0.28),
						Offset = Vector3.new(0.38, 0.95, -0.55),
						Color = IRON,
						Material = Enum.Material.Metal,
						Mirror = true,
					},
					{
						Name = "Chain1",
						Attach = "UpperTorso",
						Size = Vector3.new(0.12, 0.26, 0.12),
						Offset = Vector3.new(0, 0.66, -0.55),
						Color = IRON,
						Material = Enum.Material.Metal,
					},
					{
						Name = "Chain2",
						Attach = "UpperTorso",
						Size = Vector3.new(0.12, 0.26, 0.12),
						Offset = Vector3.new(0, 0.38, -0.55),
						Rotation = Vector3.new(0, 90, 0),
						Color = IRON,
						Material = Enum.Material.Metal,
					},
					{
						Name = "BackSpike1",
						Attach = "UpperTorso",
						Size = Vector3.new(0.24, 0.5, 0.24),
						Offset = Vector3.new(0, 0.55, 0.48),
						Rotation = Vector3.new(45, 0, 0),
						Color = Color3.fromRGB(55, 50, 52),
					},
					{
						Name = "BackSpike2",
						Attach = "UpperTorso",
						Size = Vector3.new(0.24, 0.5, 0.24),
						Offset = Vector3.new(0, 0.05, 0.48),
						Rotation = Vector3.new(45, 0, 0),
						Color = Color3.fromRGB(55, 50, 52),
					},
					{
						Name = "BackSpike3",
						Attach = "UpperTorso",
						Size = Vector3.new(0.22, 0.45, 0.22),
						Offset = Vector3.new(0, -0.45, 0.47),
						Rotation = Vector3.new(45, 0, 0),
						Color = Color3.fromRGB(55, 50, 52),
					},
				},
			},
			-- 이마의 제3의 눈과 마른 가지 뿔
			Watcher = {
				Eyes = SCARY_EYES,
				LightBrightness = 1.6,
				Mist = true,
				Decorations = {
					{
						Name = "ThirdEye",
						Attach = "Head",
						Size = Vector3.new(0.3, 0.3, 0.3),
						Offset = Vector3.new(0, 0.38, -0.56),
						Shape = "Ball",
						Material = Enum.Material.Neon,
					},
					{
						Name = "Antler",
						Attach = "Head",
						Size = Vector3.new(0.1, 0.75, 0.1),
						Offset = Vector3.new(0.36, 0.88, 0),
						Rotation = Vector3.new(0, 0, -25),
						Color = Color3.fromRGB(72, 60, 50),
						Mirror = true,
					},
					{
						Name = "AntlerBranch",
						Attach = "Head",
						Size = Vector3.new(0.08, 0.38, 0.08),
						Offset = Vector3.new(0.6, 1.02, 0),
						Rotation = Vector3.new(0, 0, -62),
						Color = Color3.fromRGB(72, 60, 50),
						Mirror = true,
					},
				},
			},
			-- 휘어진 뿔과 짧은 해진 망토 (빛·입자 없음)
			Shadow = {
				Eyes = SCARY_EYES,
				LightBrightness = 1.3,
				Decorations = with(hoodAndCloak(Color3.fromRGB(18, 14, 24), false), {
					{
						Name = "Horn",
						Attach = "Head",
						Size = Vector3.new(0.16, 0.48, 0.16),
						Offset = Vector3.new(0.42, 0.9, 0),
						Rotation = Vector3.new(0, 0, -20),
						Color = Color3.fromRGB(28, 22, 34),
						Mirror = true,
					},
					{
						Name = "HornTip",
						Attach = "Head",
						Size = Vector3.new(0.1, 0.36, 0.1),
						Offset = Vector3.new(0.56, 1.2, 0.04),
						Rotation = Vector3.new(0, 0, -45),
						Color = Color3.fromRGB(28, 22, 34),
						Mirror = true,
					},
				}),
			},
			-- 뼈 뿔, 가시 어깨 갑옷, 팔목 쇠사슬
			Giant = {
				Eyes = SCARY_EYES,
				LightBrightness = 1.6,
				Mist = true,
				Decorations = {
					{
						Name = "Horn",
						Attach = "Head",
						Size = Vector3.new(0.3, 0.9, 0.3),
						Offset = Vector3.new(0.55, 0.9, 0),
						Rotation = Vector3.new(0, 0, -25),
						Color = BONE,
						Mirror = true,
					},
					{
						Name = "ShoulderPadL",
						Attach = "LeftUpperArm",
						Size = Vector3.new(1.05, 0.4, 1.05),
						Offset = Vector3.new(0, 0.55, 0),
						Color = IRON,
						Material = Enum.Material.Metal,
					},
					{
						Name = "ShoulderPadR",
						Attach = "RightUpperArm",
						Size = Vector3.new(1.05, 0.4, 1.05),
						Offset = Vector3.new(0, 0.55, 0),
						Color = IRON,
						Material = Enum.Material.Metal,
					},
					{
						Name = "ShoulderSpikeL",
						Attach = "LeftUpperArm",
						Size = Vector3.new(0.16, 0.45, 0.16),
						Offset = Vector3.new(0, 0.95, 0),
						Color = BONE,
					},
					{
						Name = "ShoulderSpikeR",
						Attach = "RightUpperArm",
						Size = Vector3.new(0.16, 0.45, 0.16),
						Offset = Vector3.new(0, 0.95, 0),
						Color = BONE,
					},
					{
						Name = "CuffL",
						Attach = "LeftLowerArm",
						Size = Vector3.new(0.3, 1, 1),
						Offset = Vector3.new(0, -0.35, 0),
						Rotation = Vector3.new(0, 0, 90),
						Shape = "Cylinder",
						Color = IRON,
						Material = Enum.Material.Metal,
					},
					{
						Name = "CuffR",
						Attach = "RightLowerArm",
						Size = Vector3.new(0.3, 1, 1),
						Offset = Vector3.new(0, -0.35, 0),
						Rotation = Vector3.new(0, 0, 90),
						Shape = "Cylinder",
						Color = IRON,
						Material = Enum.Material.Metal,
					},
					{
						Name = "ChainL",
						Attach = "LeftLowerArm",
						Size = Vector3.new(0.12, 0.32, 0.12),
						Offset = Vector3.new(0, -0.8, 0),
						Color = IRON,
						Material = Enum.Material.Metal,
					},
					{
						Name = "ChainR",
						Attach = "RightLowerArm",
						Size = Vector3.new(0.12, 0.32, 0.12),
						Offset = Vector3.new(0, -0.8, 0),
						Color = IRON,
						Material = Enum.Material.Metal,
					},
				},
			},
		},
	},
}

return MonsterLooks
