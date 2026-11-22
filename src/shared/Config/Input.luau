--!strict
-- 입력 키와 휴대폰 화면 버튼 (GDD 11장, 질문지 Q10-2 모바일 + PC). 입력은 client/Controllers/InputController가
-- ContextActionService로 묶는다.
-- 상호작용(ProximityPrompt)은 Roblox 기본과 같은 E, 추격자 스킬은 Q (docs/release-review.md D6. S3-3에서는 스킬 E·상호작용 F였다).
--   Q는 관전 중(이전 대상)에도 쓰지만 추격자와 관전자는 동시에 될 수 없어 겹치지 않는다.
-- 게임패드 (S3-5): 달리기 L3, 공격 R2, 아이템 LB/RB, 스킬 Y, 관전 대상 LB/RB, 상호작용 X.
-- 얼음땡 모드의 얼음 F·Y, 땡 G·B (2026-11-22). Y는 추격자 스킬과 같지만 얼음은 생존자만 써서 겹치지 않는다.
--   얼음·땡은 모든 플랫폼에서 화면 오른쪽 아래 버튼으로도 누른다 (FreezeController).

local Types = require(script.Parent.Parent.Types)

export type TouchLayout = {
	ButtonSize: number, -- 화면 버튼 지름 (점). 터치 영역 최소 44 이상
	Offsets: { [Types.TouchButtonId]: Vector2 }, -- 점프 버튼 가운데에서 이 버튼 가운데까지 (점, 오른쪽·아래가 +)
	LargeScreenMinSide: number, -- 화면의 짧은 변이 이보다 크면 태블릿 (Roblox가 큰 점프 버튼을 쓰는 기준과 같음)
	LargeScreenScale: number, -- 태블릿에서 버튼 크기와 Offsets를 키우는 배율
	JumpCenterSmall: Vector2, -- Roblox 기본 점프 버튼 가운데 (화면 오른쪽 아래 모서리에서, 작은 화면). 바꾸지 않는다
	JumpCenterLarge: Vector2, -- 같은 값 (태블릿). 바꾸지 않는다
	LabelSize: number, -- 버튼 글자 크기
	DimmedTransparency: number, -- 쓸 수 없을 때(쿨다운·스태미나 부족·아이템 없음) 버튼 배경 투명도
}

export type InputConfig = {
	InteractKey: Enum.KeyCode, -- 모든 ProximityPrompt의 키보드 키 (숨기·수리·치료·줍기·판자·문·혼자 하기)
	InteractGamepad: Enum.KeyCode, -- 모든 ProximityPrompt의 게임패드 버튼
	-- 동작별 키·버튼. 키보드·마우스와 게임패드를 함께 적는다. 없는 동작(Item)은 휴대폰 화면 버튼으로만 쓴다
	Bindings: { [Types.InputAction]: { Enum.KeyCode | Enum.UserInputType } },
	KeyNames: { [string]: string }, -- 화면 키 안내에 쓰는 이름 (KeyCode·UserInputType의 Name → 표시). 없으면 Name 그대로
	Touch: TouchLayout,
}

local Input: InputConfig = {
	InteractKey = Enum.KeyCode.E,
	InteractGamepad = Enum.KeyCode.ButtonX,
	Bindings = {
		Run = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3 },
		Item = {},
		Item1 = { Enum.KeyCode.One, Enum.KeyCode.ButtonL1 },
		Item2 = { Enum.KeyCode.Two, Enum.KeyCode.ButtonR1 },
		Attack = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
		Skill = { Enum.KeyCode.Q, Enum.KeyCode.ButtonY },
		-- ←/→는 Roblox 기본 카메라 회전 키라 관전 중에는 높은 우선순위로 가로챈다 (SpectateController)
		SpectatePrevious = { Enum.KeyCode.Q, Enum.KeyCode.Left, Enum.KeyCode.ButtonL1 },
		SpectateNext = { Enum.KeyCode.E, Enum.KeyCode.Right, Enum.KeyCode.ButtonR1 },
		Freeze = { Enum.KeyCode.F, Enum.KeyCode.ButtonY },
		Thaw = { Enum.KeyCode.G, Enum.KeyCode.ButtonB },
	},
	KeyNames = {
		LeftShift = "Shift",
		RightShift = "Shift",
		One = "1",
		Two = "2",
		Left = "←",
		Right = "→",
		ButtonL1 = "LB",
		ButtonR1 = "RB",
		ButtonL2 = "LT",
		ButtonR2 = "R2",
		ButtonL3 = "L3",
		ButtonR3 = "R3",
		ButtonX = "X",
		ButtonY = "Y",
		ButtonA = "A",
		ButtonB = "B",
	},
	-- 휴대폰: Roblox 점프 버튼(작은 화면 지름 70, 태블릿 120) 둘레에 놓아 오른손 엄지로 닿게 한다.
	-- 달리기와 스킬, 아이템과 공격은 같은 자리 (생존자만 달리고 아이템을 쓰고, 추격자만 스킬과 공격을 쓴다).
	Touch = {
		ButtonSize = 64, -- 임시
		Offsets = {
			Run = Vector2.new(-90, 0), -- 임시: 점프 버튼 왼쪽
			Skill = Vector2.new(-90, 0), -- 임시: 점프 버튼 왼쪽
			Item = Vector2.new(-78, -73), -- 임시: 왼쪽 위
			Attack = Vector2.new(-78, -73), -- 임시: 왼쪽 위
			Interact = Vector2.new(0, -95), -- 임시: 점프 버튼 위
		},
		LargeScreenMinSide = 500,
		LargeScreenScale = 1.5, -- 임시
		-- Roblox TouchJump: 작은 화면 Position (1, -95, 1, -90)·Size 70, 큰 화면 (1, -170, 1, -210)·Size 120
		JumpCenterSmall = Vector2.new(60, 55),
		JumpCenterLarge = Vector2.new(110, 150),
		LabelSize = 15, -- 임시
		DimmedTransparency = 0.65, -- 임시
	},
}

return Input
