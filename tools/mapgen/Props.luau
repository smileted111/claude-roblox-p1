-- 스테이지 소품 10개씩 (2026-11-21 사용자 요청). common.luau 뒤에 붙여 Studio MCP(Edit 모드)로 실행한다.
-- 맵마다 Props 폴더(소품 Model 10개)를 새로 만든다. ONLY에 스테이지 이름을 넣으면 그 맵만.
--   학교: 칠판·교탁·학생 책상·지구본·책장·피아노·공 바구니·뜀틀·급식 카트·게시판
--   폐병원: 병원 침대·휠체어·링거 거치대·약품장·들것·칸막이·접수대·대기 의자·산소통·엑스레이 판독기
--   지하 연구소: 실험대·표본 수조·컴퓨터 단말기·서버 랙·위험물 드럼통·현미경·냉동 캡슐·철창·화이트보드·약품 선반
--   놀이공원: 풍선 수레·팝콘 수레·솜사탕 수레·아이스크림 수레·쓰레기통·발권기·곰 동상·포토존·선물 상자 더미·길 안내판
-- 규칙 (카메라 높이 제한과 함께 벽 너머를 못 보게):
--   부딪히는 부분은 바닥에서 높이 6 이하 (그 위에서 점프해도 벽 위(14)에 못 닿음). 더 높은 부분(풍선·장대·동상)은 장식.
--   벽에 거는 것(칠판·게시판·판독기·화이트보드)은 부딪히지 않는 장식.
-- 맵을 잠시 Workspace에 복제해 소품을 놓고 검사한 뒤 원본 맵에 넣는다:
--   벽에 붙는 소품은 wall 방향으로 레이캐스트해 벽면에 붙이고, 부딪히는 파트와 겹치는지,
--   숨는 곳(12)·문·판자(6)·발전기(5)·시작 위치·괴물 자리(4)·순찰 지점·아이템(3)·출구·대기실 문(8)과 떨어졌는지 본다.
--   문제는 마지막 문자열로 돌려준다 (그래도 소품은 넣음 — 위치를 고쳐 다시 실행).

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local ONLY = nil -- 예: "Stage4"
local FT = 1

local COSMETIC = { CanCollide = false, CanQuery = false, CanTouch = false }

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function merge(a, b)
	local out = table.clone(a or {})
	for k, v in b or {} do
		out[k] = v
	end
	return out
end

-- base(바닥 가운데, 앞 = -Z)에 붙이는 도우미
local function maker(model, base)
	local m = {}
	function m.box(name, size, offset, color, props, rot)
		local cf = base * CFrame.new(offset)
		if rot then
			cf *= CFrame.fromOrientation(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		end
		local p = Map.part(model, name, size, Vector3.zero, "White", merge({ Color = color }, props))
		p.CFrame = cf
		return p
	end
	function m.deco(name, size, offset, color, props, rot)
		return m.box(name, size, offset, color, merge(COSMETIC, props), rot)
	end
	function m.ball(name, d, offset, color, props)
		return m.box(name, Vector3.new(d, d, d), offset, color, merge({ Shape = Enum.PartType.Ball }, props))
	end
	-- 세운 원기둥 (높이 h, 지름 d)
	function m.cyl(name, h, d, offset, color, props)
		return m.box(name, Vector3.new(h, d, d), offset, color, merge({ Shape = Enum.PartType.Cylinder }, props), Vector3.new(0, 0, 90))
	end
	-- 눕힌 원기둥 (축이 소품의 X)
	function m.cylX(name, h, d, offset, color, props)
		return m.box(name, Vector3.new(h, d, d), offset, color, merge({ Shape = Enum.PartType.Cylinder }, props))
	end
	function m.text(part, text, color, font)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.4
		gui.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = font or Enum.Font.PermanentMarker
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
	end
	return m
end

local WOOD = rgb(160, 110, 70)
local DARK_WOOD = rgb(110, 75, 50)
local METAL = rgb(170, 175, 185)
local WHITE = rgb(240, 240, 240)

-- wall = true: 벽면(z=0)에 등을 대고 앞(-Z)으로 나온다. hang = true: 벽에 거는 장식 (겹침·숨는 곳 검사 안 함)
local PROPS = {}

--------------------------------------------------------------------------------
-- 학교

PROPS.Blackboard = {
	wall = true,
	hang = true,
	build = function(m)
		local board = m.deco("Board", Vector3.new(10, 4.6, 0.2), Vector3.new(0, 6.6, -0.2), rgb(40, 80, 60))
		m.text(board, "1 + 1 = 2   ★   ABC", rgb(240, 240, 230))
		for _, p in { { 0, 9, 10.6, 0.4 }, { 0, 4.2, 10.6, 0.4 } } do
			m.deco("Frame", Vector3.new(p[3], p[4], 0.35), Vector3.new(p[1], p[2], -0.2), DARK_WOOD)
		end
		for _, x in { -5.15, 5.15 } do
			m.deco("Frame", Vector3.new(0.4, 5, 0.35), Vector3.new(x, 6.6, -0.2), DARK_WOOD)
		end
		m.deco("ChalkTray", Vector3.new(9, 0.2, 0.6), Vector3.new(0, 4.1, -0.5), DARK_WOOD)
		m.deco("Chalk", Vector3.new(0.6, 0.15, 0.15), Vector3.new(-2, 4.3, -0.5), WHITE)
		m.deco("Eraser", Vector3.new(0.9, 0.3, 0.4), Vector3.new(2.4, 4.35, -0.5), rgb(60, 60, 70))
	end,
}

PROPS.Lectern = {
	build = function(m)
		m.box("Body", Vector3.new(3.4, 3.6, 2), Vector3.new(0, 1.8, 0), WOOD)
		m.box("Top", Vector3.new(3.8, 0.3, 2.4), Vector3.new(0, 3.75, 0), DARK_WOOD)
		m.deco("Book", Vector3.new(1.2, 0.25, 0.9), Vector3.new(-0.6, 4.02, 0.2), rgb(200, 60, 60), nil, Vector3.new(0, 15, 0))
		m.deco("Flower", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.1, 4.2, -0.4), rgb(255, 150, 180), { Shape = Enum.PartType.Ball })
	end,
}

PROPS.StudentDesk = {
	build = function(m)
		m.box("DeskTop", Vector3.new(3.2, 0.3, 2), Vector3.new(0, 2.6, 0), rgb(210, 170, 110))
		for _, p in { { -1.4, -0.8 }, { 1.4, -0.8 }, { -1.4, 0.8 }, { 1.4, 0.8 } } do
			m.box("DeskLeg", Vector3.new(0.22, 2.45, 0.22), Vector3.new(p[1], 1.22, p[2]), METAL)
		end
		m.box("Seat", Vector3.new(1.8, 0.3, 1.7), Vector3.new(0, 1.5, 2.1), rgb(210, 170, 110))
		m.box("SeatBack", Vector3.new(1.8, 1.5, 0.25), Vector3.new(0, 2.5, 2.9), rgb(210, 170, 110))
		for _, p in { { -0.75, 1.4 }, { 0.75, 1.4 }, { -0.75, 2.8 }, { 0.75, 2.8 } } do
			m.box("ChairLeg", Vector3.new(0.18, 1.4, 0.18), Vector3.new(p[1], 0.7, p[2]), METAL)
		end
		m.deco("Bag", Vector3.new(1.2, 1.4, 0.6), Vector3.new(1.4, 2, 2.1), rgb(90, 140, 230))
		m.deco("Notebook", Vector3.new(1.1, 0.12, 0.8), Vector3.new(-0.5, 2.82, 0), rgb(255, 230, 120), nil, Vector3.new(0, -10, 0))
	end,
}

PROPS.Globe = {
	build = function(m)
		m.box("Table", Vector3.new(2.2, 2.6, 2.2), Vector3.new(0, 1.3, 0), WOOD)
		m.deco("Stand", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 3.2, 0), rgb(200, 170, 60))
		m.deco("Ring", Vector3.new(0.15, 2.5, 2.5), Vector3.new(0, 4.6, 0), rgb(200, 170, 60), { Shape = Enum.PartType.Cylinder }, Vector3.new(0, 90, 0))
		m.ball("Earth", 2.2, Vector3.new(0, 4.6, 0), rgb(80, 150, 230), COSMETIC)
		for _, p in { { 0.6, 0.4, -0.75 }, { -0.7, -0.2, -0.7 }, { 0.2, -0.7, 0.8 } } do
			m.ball("Land", 1, Vector3.new(p[1], 4.6 + p[2], p[3]), rgb(110, 190, 90), COSMETIC)
		end
	end,
}

PROPS.Bookshelf = {
	wall = true,
	build = function(m)
		m.box("Shelf", Vector3.new(6, 5, 1.6), Vector3.new(0, 2.5, -0.85), WOOD)
		local colors = { rgb(220, 70, 70), rgb(70, 130, 220), rgb(240, 200, 70), rgb(90, 180, 110), rgb(170, 100, 200) }
		for row, y in { 1.4, 3.4 } do
			for i = 0, 8 do
				local h = 1.2 + ((i * 7 + row) % 3) * 0.2
				m.deco("Book", Vector3.new(0.45, h, 1.1), Vector3.new(-2.3 + i * 0.58, y + h / 2 - 0.5, -1.4), colors[(i + row) % #colors + 1])
			end
		end
	end,
}

PROPS.Piano = {
	wall = true,
	build = function(m)
		m.box("Body", Vector3.new(6, 4.6, 2.2), Vector3.new(0, 2.3, -1.15), rgb(30, 30, 35))
		m.box("KeyShelf", Vector3.new(5.6, 0.4, 1.2), Vector3.new(0, 2.6, -2.8), rgb(30, 30, 35))
		m.deco("WhiteKeys", Vector3.new(5.3, 0.15, 0.9), Vector3.new(0, 2.86, -2.85), WHITE)
		for i = 0, 9 do
			if i % 7 ~= 2 and i % 7 ~= 6 then
				m.deco("BlackKey", Vector3.new(0.22, 0.15, 0.5), Vector3.new(-2.4 + i * 0.52, 2.98, -2.65), rgb(20, 20, 20))
			end
		end
		m.box("Bench", Vector3.new(3, 1.8, 1.2), Vector3.new(0, 0.9, -4.4), rgb(30, 30, 35))
		m.deco("Music", Vector3.new(1.6, 1.2, 0.1), Vector3.new(0, 4.1, -2.3), WHITE, nil, Vector3.new(-15, 0, 0))
	end,
}

PROPS.BallBasket = {
	build = function(m)
		m.box("Cart", Vector3.new(3.2, 2, 2.2), Vector3.new(0, 1.3, 0), rgb(80, 80, 90), { Material = Enum.Material.DiamondPlate })
		for _, p in { { -1.4, -0.9 }, { 1.4, -0.9 }, { -1.4, 0.9 }, { 1.4, 0.9 } } do
			m.ball("Wheel", 0.5, Vector3.new(p[1], 0.25, p[2]), rgb(30, 30, 30))
		end
		local colors = { rgb(255, 140, 40), WHITE, rgb(240, 80, 80), rgb(80, 160, 240), rgb(255, 220, 80), rgb(120, 200, 110) }
		for i = 0, 5 do
			local x = -1 + (i % 3) * 1
			local z = if i < 3 then -0.5 else 0.5
			m.ball("Ball", 1, Vector3.new(x, 2.75 + (i % 2) * 0.2, z), colors[i + 1], COSMETIC)
		end
	end,
}

PROPS.VaultingBox = {
	build = function(m)
		local colors = { rgb(200, 150, 90), rgb(215, 165, 100) }
		for i = 0, 3 do
			m.box("Layer", Vector3.new(4.6 - i * 0.3, 0.9, 2.6 - i * 0.1), Vector3.new(0, 0.45 + i * 0.9, 0), colors[i % 2 + 1])
		end
		m.box("Cushion", Vector3.new(3.6, 0.5, 2.3), Vector3.new(0, 3.85, 0), rgb(220, 60, 60), { Material = Enum.Material.Fabric })
		m.box("Mat", Vector3.new(4, 0.3, 3), Vector3.new(0, 0.15, -3.2), rgb(70, 110, 200), { Material = Enum.Material.Fabric })
	end,
}

PROPS.LunchCart = {
	build = function(m)
		m.box("Cart", Vector3.new(4.2, 2.6, 2.2), Vector3.new(0, 1.6, 0), METAL, { Material = Enum.Material.Metal })
		for _, p in { { -1.8, -0.9 }, { 1.8, -0.9 }, { -1.8, 0.9 }, { 1.8, 0.9 } } do
			m.ball("Wheel", 0.6, Vector3.new(p[1], 0.3, p[2]), rgb(40, 40, 40))
		end
		m.box("Handle", Vector3.new(0.2, 0.2, 2), Vector3.new(2.4, 3, 0), METAL, { Material = Enum.Material.Metal })
		m.cyl("Pot", 1.3, 1.8, Vector3.new(-1, 3.55, 0), rgb(200, 205, 215), merge(COSMETIC, { Material = Enum.Material.Metal }))
		m.cyl("Soup", 0.1, 1.5, Vector3.new(-1, 4.2, 0), rgb(240, 170, 80), COSMETIC)
		m.deco("Tray", Vector3.new(1.6, 0.15, 1.2), Vector3.new(1, 2.98, 0), rgb(120, 200, 230))
		m.ball("Apple", 0.5, Vector3.new(0.8, 3.25, 0.2), rgb(220, 50, 50), COSMETIC)
	end,
}

PROPS.BulletinBoard = {
	wall = true,
	hang = true,
	build = function(m)
		m.deco("Cork", Vector3.new(6, 4, 0.2), Vector3.new(0, 6, -0.15), rgb(190, 140, 90), { Material = Enum.Material.Fabric })
		m.deco("Frame", Vector3.new(6.4, 4.4, 0.15), Vector3.new(0, 6, -0.05), DARK_WOOD)
		local papers = { { -1.8, 6.8, rgb(255, 255, 200) }, { 0.2, 7.1, rgb(200, 230, 255) }, { 2, 6.6, rgb(255, 210, 230) }, { -1, 5.1, rgb(220, 255, 210) }, { 1.4, 5, WHITE } }
		for i, p in papers do
			m.deco("Paper", Vector3.new(1.4, 1.6, 0.05), Vector3.new(p[1], p[2], -0.28), p[3], nil, Vector3.new(0, 0, (i % 3 - 1) * 6))
			m.deco("Pin", Vector3.new(0.2, 0.2, 0.1), Vector3.new(p[1], p[2] + 0.6, -0.33), rgb(230, 50, 50), { Shape = Enum.PartType.Ball })
		end
	end,
}

--------------------------------------------------------------------------------
-- 폐병원

PROPS.HospitalBed = {
	build = function(m)
		m.box("Frame", Vector3.new(3.2, 0.5, 7), Vector3.new(0, 2.15, 0), METAL, { Material = Enum.Material.Metal })
		for _, p in { { -1.4, -3.2 }, { 1.4, -3.2 }, { -1.4, 3.2 }, { 1.4, 3.2 } } do
			m.box("Leg", Vector3.new(0.25, 1.9, 0.25), Vector3.new(p[1], 0.95, p[2]), METAL)
		end
		m.box("Mattress", Vector3.new(3, 0.6, 6.6), Vector3.new(0, 2.7, 0), WHITE, { Material = Enum.Material.Fabric })
		m.deco("Pillow", Vector3.new(2.3, 0.5, 1.2), Vector3.new(0, 3.2, 2.6), WHITE, { Material = Enum.Material.Fabric })
		m.deco("Blanket", Vector3.new(3.1, 0.2, 3.8), Vector3.new(0, 3.08, -1.2), rgb(150, 200, 230), { Material = Enum.Material.Fabric })
		m.box("Headboard", Vector3.new(3.2, 2.6, 0.3), Vector3.new(0, 3.1, 3.4), METAL, { Material = Enum.Material.Metal })
		m.deco("Chart", Vector3.new(1, 1.3, 0.1), Vector3.new(0, 2.9, -3.55), WHITE)
	end,
}

PROPS.Wheelchair = {
	build = function(m)
		m.box("Seat", Vector3.new(2, 0.3, 2), Vector3.new(0, 2, 0), rgb(60, 70, 110), { Material = Enum.Material.Fabric })
		m.box("Back", Vector3.new(2, 2.1, 0.25), Vector3.new(0, 3.1, 1), rgb(60, 70, 110), { Material = Enum.Material.Fabric })
		for _, x in { -1.2, 1.2 } do
			m.cylX("Wheel", 0.2, 2.8, Vector3.new(x, 1.4, 0.3), rgb(40, 40, 45))
			m.deco("Armrest", Vector3.new(0.2, 0.2, 1.8), Vector3.new(x * 0.9, 2.9, 0.1), METAL)
			m.ball("Caster", 0.5, Vector3.new(x * 0.7, 0.25, -1.2), rgb(40, 40, 45))
		end
		m.deco("Footrest", Vector3.new(1.6, 0.15, 0.6), Vector3.new(0, 0.9, -1.5), METAL)
	end,
}

PROPS.IVStand = {
	build = function(m)
		m.box("Base", Vector3.new(2, 0.3, 0.4), Vector3.new(0, 0.3, 0), METAL)
		m.box("Base2", Vector3.new(0.4, 0.3, 2), Vector3.new(0, 0.3, 0), METAL)
		m.cyl("Pole", 6.6, 0.2, Vector3.new(0, 3.6, 0), METAL, COSMETIC)
		m.deco("Hook", Vector3.new(1.6, 0.15, 0.15), Vector3.new(0, 6.8, 0), METAL)
		m.deco("Bag", Vector3.new(0.9, 1.3, 0.35), Vector3.new(0.6, 6, 0), rgb(200, 235, 255), { Material = Enum.Material.Glass, Transparency = 0.3 })
		m.deco("Tube", Vector3.new(0.08, 3, 0.08), Vector3.new(0.6, 4, 0), rgb(220, 240, 255))
	end,
}

PROPS.MedicineCabinet = {
	wall = true,
	build = function(m)
		m.box("Body", Vector3.new(5, 5.5, 1.5), Vector3.new(0, 2.75, -0.8), WHITE, { Material = Enum.Material.Metal })
		for _, x in { -1.2, 1.2 } do
			m.deco("Glass", Vector3.new(2.2, 3, 0.1), Vector3.new(x, 3.6, -1.6), rgb(190, 225, 240), { Material = Enum.Material.Glass, Transparency = 0.35 })
		end
		local colors = { rgb(240, 120, 120), rgb(120, 180, 240), rgb(250, 220, 110), rgb(140, 210, 140) }
		for i = 0, 5 do
			m.deco("Bottle", Vector3.new(0.4, 0.8, 0.4), Vector3.new(-2 + i * 0.8, 2.9 + (i % 2) * 1.3, -1.1), colors[i % #colors + 1])
		end
		m.deco("CrossH", Vector3.new(1.2, 0.35, 0.1), Vector3.new(0, 1.2, -1.6), rgb(220, 50, 50))
		m.deco("CrossV", Vector3.new(0.35, 1.2, 0.1), Vector3.new(0, 1.2, -1.6), rgb(220, 50, 50))
	end,
}

PROPS.Stretcher = {
	build = function(m)
		m.box("Bed", Vector3.new(2.6, 0.4, 7), Vector3.new(0, 2.8, 0), METAL, { Material = Enum.Material.Metal })
		m.box("Pad", Vector3.new(2.4, 0.3, 6.6), Vector3.new(0, 3.15, 0), rgb(240, 160, 90), { Material = Enum.Material.Fabric })
		for _, z in { -2, 2 } do
			m.box("LegA", Vector3.new(0.2, 3.2, 0.2), Vector3.new(0, 1.3, z), METAL, nil, Vector3.new(30, 0, 0))
			m.box("LegB", Vector3.new(0.2, 3.2, 0.2), Vector3.new(0, 1.3, z), METAL, nil, Vector3.new(-30, 0, 0))
		end
		for _, z in { -3.2, 3.2 } do
			m.ball("Wheel", 0.5, Vector3.new(0, 0.25, z), rgb(40, 40, 40))
		end
		m.deco("Strap", Vector3.new(2.5, 0.1, 0.4), Vector3.new(0, 3.32, 0.5), rgb(40, 40, 60))
	end,
}

PROPS.PrivacyScreen = {
	build = function(m)
		for i, x in { -2.1, 0, 2.1 } do
			local angle = if i == 2 then 0 else 25 * (i - 2)
			m.deco("Panel", Vector3.new(2.1, 5, 0.15), Vector3.new(x, 3.1, (i == 2) and -0.4 or 0), rgb(190, 225, 200), { Material = Enum.Material.Fabric }, Vector3.new(0, angle, 0))
			m.box("Foot", Vector3.new(0.3, 0.6, 1), Vector3.new(x, 0.3, (i == 2) and -0.4 or 0), METAL)
		end
	end,
}

PROPS.ReceptionDesk = {
	build = function(m)
		m.box("Front", Vector3.new(8, 3.6, 1.2), Vector3.new(0, 1.8, -1.4), rgb(210, 220, 230))
		m.box("Side", Vector3.new(1.2, 3.6, 4), Vector3.new(4.6, 1.8, 0), rgb(210, 220, 230))
		m.box("Lip", Vector3.new(8.4, 0.3, 1.8), Vector3.new(0, 3.75, -1.5), rgb(120, 170, 200))
		m.box("Desk", Vector3.new(7.6, 0.3, 2.2), Vector3.new(0, 2.6, 0.3), WHITE)
		m.deco("Monitor", Vector3.new(1.6, 1.1, 0.2), Vector3.new(-1.8, 3.4, 0.6), rgb(40, 40, 45))
		m.deco("Screen", Vector3.new(1.4, 0.9, 0.05), Vector3.new(-1.8, 3.4, 0.48), rgb(120, 200, 255), { Material = Enum.Material.Neon })
		m.deco("Bell", Vector3.new(0.5, 0.4, 0.5), Vector3.new(2.2, 4.1, -1.6), rgb(230, 190, 60), { Shape = Enum.PartType.Ball })
	end,
}

PROPS.WaitingChairs = {
	build = function(m)
		m.box("Beam", Vector3.new(7.6, 0.3, 0.5), Vector3.new(0, 1.2, 0), METAL)
		for _, x in { -2.5, 0, 2.5 } do
			m.box("Seat", Vector3.new(2.2, 0.3, 2), Vector3.new(x, 1.8, 0), rgb(90, 160, 210))
			m.box("Back", Vector3.new(2.2, 2, 0.25), Vector3.new(x, 2.9, 0.9), rgb(90, 160, 210))
		end
		for _, x in { -3.5, 3.5 } do
			m.box("Leg", Vector3.new(0.3, 1.2, 1.6), Vector3.new(x, 0.6, 0), METAL)
		end
		m.deco("Magazine", Vector3.new(1, 0.1, 0.8), Vector3.new(2.5, 2, -0.2), rgb(255, 200, 120), nil, Vector3.new(0, 20, 0))
	end,
}

PROPS.OxygenTanks = {
	build = function(m)
		m.box("Rack", Vector3.new(3.8, 0.4, 1.6), Vector3.new(0, 0.2, 0), METAL)
		for _, x in { -1.25, 0, 1.25 } do
			m.cyl("Tank", 4.2, 1.1, Vector3.new(x, 2.5, 0), rgb(90, 170, 110), { Material = Enum.Material.Metal })
			m.cyl("Cap", 0.5, 0.6, Vector3.new(x, 4.85, 0), WHITE, COSMETIC)
		end
		m.deco("Chain", Vector3.new(3.8, 0.15, 1.3), Vector3.new(0, 3.2, 0), rgb(120, 120, 130), { Material = Enum.Material.Metal })
	end,
}

PROPS.XRayLightbox = {
	wall = true,
	hang = true,
	build = function(m)
		m.deco("Box", Vector3.new(4.4, 3.2, 0.4), Vector3.new(0, 6, -0.25), rgb(200, 205, 210))
		m.deco("Light", Vector3.new(4, 2.8, 0.05), Vector3.new(0, 6, -0.48), rgb(170, 210, 240), { Material = Enum.Material.Neon })
		m.deco("Spine", Vector3.new(0.2, 2.2, 0.05), Vector3.new(0, 6, -0.53), WHITE)
		for i = 0, 3 do
			m.deco("Rib", Vector3.new(1.6, 0.12, 0.05), Vector3.new(0, 6.7 - i * 0.45, -0.53), WHITE)
		end
	end,
}

--------------------------------------------------------------------------------
-- 지하 연구소

local LIQUIDS = { rgb(110, 255, 140), rgb(120, 200, 255), rgb(255, 120, 220), rgb(255, 220, 90) }

PROPS.LabBench = {
	build = function(m)
		m.box("Table", Vector3.new(8, 3, 3), Vector3.new(0, 1.5, 0), rgb(210, 215, 220), { Material = Enum.Material.Metal })
		m.box("Top", Vector3.new(8.2, 0.3, 3.2), Vector3.new(0, 3.15, 0), rgb(30, 30, 35))
		for i, x in { -3, -1.6, -0.3, 1.2, 2.8 } do
			local liquid = LIQUIDS[i % #LIQUIDS + 1]
			local h = 0.8 + (i % 3) * 0.3
			m.cyl("Beaker", h, 0.6, Vector3.new(x, 3.3 + h / 2, -0.4 + (i % 2) * 0.7), rgb(220, 240, 250), merge(COSMETIC, { Material = Enum.Material.Glass, Transparency = 0.5 }))
			m.cyl("Liquid", h * 0.6, 0.5, Vector3.new(x, 3.3 + h * 0.3, -0.4 + (i % 2) * 0.7), liquid, merge(COSMETIC, { Material = Enum.Material.Neon, Transparency = 0.2 }))
		end
		m.deco("TestTubeRack", Vector3.new(1.6, 0.5, 0.6), Vector3.new(-1, 3.55, 1), rgb(120, 120, 130))
	end,
}

PROPS.SpecimenTank = {
	build = function(m)
		m.cyl("Base", 0.8, 4, Vector3.new(0, 0.4, 0), rgb(90, 95, 105), { Material = Enum.Material.Metal })
		m.cyl("Glass", 4.4, 3.4, Vector3.new(0, 3, 0), rgb(200, 255, 230), { Material = Enum.Material.Glass, Transparency = 0.55 })
		m.cyl("Liquid", 4, 3.1, Vector3.new(0, 2.9, 0), rgb(110, 255, 150), merge(COSMETIC, { Material = Enum.Material.Neon, Transparency = 0.65 }))
		m.ball("Specimen", 1.4, Vector3.new(0, 3, 0), rgb(60, 90, 70), COSMETIC)
		m.cyl("Cap", 0.6, 4, Vector3.new(0, 5.5, 0), rgb(90, 95, 105), { Material = Enum.Material.Metal })
		m.deco("Pipe", Vector3.new(0.4, 0.4, 3), Vector3.new(0, 5.4, 2.6), rgb(90, 95, 105))
	end,
}

PROPS.ComputerTerminal = {
	build = function(m)
		m.box("Desk", Vector3.new(5, 3, 2.4), Vector3.new(0, 1.5, 0), rgb(60, 65, 75), { Material = Enum.Material.Metal })
		for _, x in { -1.2, 1.2 } do
			m.deco("Monitor", Vector3.new(2, 1.5, 0.2), Vector3.new(x, 4, 0.6), rgb(30, 30, 35))
			local screen = m.deco("Screen", Vector3.new(1.8, 1.3, 0.05), Vector3.new(x, 4, 0.48), rgb(20, 60, 40), { Material = Enum.Material.Neon })
			m.text(screen, "> SCAN... OK", rgb(120, 255, 160), Enum.Font.Code)
		end
		m.deco("Keyboard", Vector3.new(2.4, 0.15, 0.8), Vector3.new(0, 3.08, -0.4), rgb(40, 40, 45))
		m.box("Chair", Vector3.new(1.8, 1.6, 1.8), Vector3.new(0, 0.8, -2.4), rgb(40, 40, 45))
	end,
}

PROPS.ServerRack = {
	build = function(m)
		m.box("Rack", Vector3.new(3, 6, 2.4), Vector3.new(0, 3, 0), rgb(25, 25, 30), { Material = Enum.Material.Metal })
		local colors = { rgb(90, 255, 120), rgb(90, 200, 255), rgb(255, 180, 60) }
		for row = 0, 5 do
			m.deco("Slot", Vector3.new(2.6, 0.7, 0.05), Vector3.new(0, 0.9 + row * 0.85, -1.22), rgb(50, 50, 58))
			for i = 0, 2 do
				m.deco("Led", Vector3.new(0.15, 0.15, 0.05), Vector3.new(0.6 + i * 0.3, 0.9 + row * 0.85, -1.26), colors[(row + i) % #colors + 1], { Material = Enum.Material.Neon })
			end
		end
	end,
}

PROPS.HazardBarrels = {
	build = function(m)
		for _, p in { { -1.3, 0 }, { 1.1, 0.4 } } do
			m.cyl("Barrel", 3.2, 2, Vector3.new(p[1], 1.6, p[2]), rgb(240, 200, 40), { Material = Enum.Material.Metal })
			m.cyl("Stripe", 0.4, 2.05, Vector3.new(p[1], 2.4, p[2]), rgb(30, 30, 30), COSMETIC)
		end
		m.cylX("Lying", 3.2, 2, Vector3.new(0, 1, -2.4), rgb(240, 200, 40), { Material = Enum.Material.Metal })
		m.deco("Spill", Vector3.new(3, 0.05, 2), Vector3.new(1.6, 0.03, -3.4), rgb(140, 255, 120), { Material = Enum.Material.Neon, Transparency = 0.3 })
	end,
}

PROPS.Microscope = {
	build = function(m)
		m.box("Table", Vector3.new(3.2, 3, 2.2), Vector3.new(0, 1.5, 0), rgb(210, 215, 220), { Material = Enum.Material.Metal })
		m.deco("ScopeBase", Vector3.new(1, 0.3, 1.2), Vector3.new(0, 3.15, 0), rgb(240, 240, 245))
		m.deco("Arm", Vector3.new(0.3, 1.4, 0.3), Vector3.new(0, 3.9, 0.4), rgb(240, 240, 245), nil, Vector3.new(-15, 0, 0))
		m.deco("Tube", Vector3.new(0.35, 1.2, 0.35), Vector3.new(0, 4.3, -0.1), rgb(40, 40, 45), nil, Vector3.new(20, 0, 0))
		m.deco("Slide", Vector3.new(0.8, 0.05, 0.4), Vector3.new(0, 3.5, -0.2), rgb(200, 240, 255))
		m.deco("Notes", Vector3.new(1, 0.08, 0.8), Vector3.new(1, 3.04, 0.2), WHITE, nil, Vector3.new(0, 15, 0))
	end,
}

PROPS.CryoPod = {
	build = function(m)
		m.box("Base", Vector3.new(3.2, 1.2, 7.2), Vector3.new(0, 0.6, 0), rgb(150, 155, 165), { Material = Enum.Material.Metal })
		m.box("Cover", Vector3.new(2.6, 1.4, 6.4), Vector3.new(0, 1.9, 0), rgb(170, 230, 255), { Material = Enum.Material.Glass, Transparency = 0.45 })
		m.deco("Frost", Vector3.new(2.4, 1, 6), Vector3.new(0, 1.8, 0), rgb(220, 245, 255), { Transparency = 0.6 })
		for _, x in { -1.62, 1.62 } do
			m.deco("Strip", Vector3.new(0.1, 0.2, 6.8), Vector3.new(x, 1, 0), rgb(80, 200, 255), { Material = Enum.Material.Neon })
		end
		m.deco("Panel", Vector3.new(1.4, 1, 0.2), Vector3.new(0, 1.4, -3.7), rgb(40, 40, 45))
	end,
}

PROPS.Cage = {
	build = function(m)
		m.box("Floor", Vector3.new(5, 0.3, 5), Vector3.new(0, 0.15, 0), rgb(80, 80, 90), { Material = Enum.Material.DiamondPlate })
		m.box("Top", Vector3.new(5, 0.3, 5), Vector3.new(0, 5.15, 0), rgb(80, 80, 90), { Material = Enum.Material.Metal })
		for i = 0, 5 do
			local t = -2.4 + i * 0.96
			for _, p in { { t, -2.4 }, { t, 2.4 }, { -2.4, t }, { 2.4, t } } do
				m.box("Bar", Vector3.new(0.22, 4.7, 0.22), Vector3.new(p[1], 2.65, p[2]), rgb(110, 110, 120), { Material = Enum.Material.Metal })
			end
		end
		m.deco("Toy", Vector3.new(1, 1, 1), Vector3.new(0.5, 0.8, 0.3), rgb(220, 120, 60), { Shape = Enum.PartType.Ball })
	end,
}

PROPS.Whiteboard = {
	wall = true,
	hang = true,
	build = function(m)
		local board = m.deco("Board", Vector3.new(8, 4, 0.2), Vector3.new(0, 6.4, -0.2), rgb(245, 245, 250))
		m.text(board, "E = mc²  →  ???", rgb(40, 70, 160))
		m.deco("Frame", Vector3.new(8.4, 4.4, 0.12), Vector3.new(0, 6.4, -0.08), METAL)
		m.deco("Tray", Vector3.new(7, 0.15, 0.5), Vector3.new(0, 4.2, -0.4), METAL)
		m.deco("Marker", Vector3.new(0.5, 0.12, 0.12), Vector3.new(-1.5, 4.32, -0.4), rgb(220, 50, 50))
	end,
}

PROPS.ChemicalShelf = {
	wall = true,
	build = function(m)
		m.box("Shelf", Vector3.new(5, 5, 1.6), Vector3.new(0, 2.5, -0.85), rgb(120, 125, 135), { Material = Enum.Material.Metal })
		for row, y in { 1.3, 3.2 } do
			for i = 0, 4 do
				local h = 0.9 + ((i + row) % 2) * 0.4
				m.cyl("Bottle", h, 0.6, Vector3.new(-1.8 + i * 0.9, y + h / 2, -1.4), LIQUIDS[(i + row) % #LIQUIDS + 1], merge(COSMETIC, { Material = Enum.Material.Neon, Transparency = 0.25 }))
			end
		end
		m.deco("Label", Vector3.new(1.6, 0.6, 0.05), Vector3.new(0, 4.6, -1.68), rgb(255, 220, 60))
	end,
}

--------------------------------------------------------------------------------
-- 놀이공원

local function cartBase(m, color)
	m.box("Cart", Vector3.new(3.2, 2.4, 2), Vector3.new(0, 1.6, 0), color)
	for _, p in { { -1.3, -1.05 }, { 1.3, -1.05 }, { -1.3, 1.05 }, { 1.3, 1.05 } } do
		m.cylX("Wheel", 0.3, 1, Vector3.new(p[1], 0.5, p[2]), rgb(40, 40, 45))
	end
	m.box("Handle", Vector3.new(0.2, 0.2, 1.8), Vector3.new(1.9, 2.6, 0), rgb(200, 200, 210))
end

PROPS.BalloonCart = {
	build = function(m)
		cartBase(m, rgb(255, 230, 120))
		local colors = { rgb(255, 90, 110), rgb(90, 170, 255), rgb(255, 220, 70), rgb(130, 220, 120), rgb(200, 130, 255), rgb(255, 160, 80) }
		for i, p in { { 0, 7.6, 0 }, { -1.2, 7, 0.6 }, { 1.2, 7.2, -0.4 }, { -0.6, 8.4, -0.6 }, { 0.8, 8.3, 0.7 }, { 0.2, 6.6, -1 } } do
			m.ball("Balloon", 1.5, Vector3.new(p[1], p[2], p[3]), colors[i], merge(COSMETIC, { Material = Enum.Material.Glass, Transparency = 0.1 }))
			m.deco("String", Vector3.new(0.06, p[2] - 3.2, 0.06), Vector3.new(p[1] * 0.4, (p[2] + 2.8) / 2, p[3] * 0.4), WHITE)
		end
	end,
}

PROPS.PopcornCart = {
	build = function(m)
		cartBase(m, rgb(230, 60, 70))
		m.deco("Case", Vector3.new(2.6, 1.8, 1.6), Vector3.new(0, 3.7, 0), rgb(255, 250, 230), { Material = Enum.Material.Glass, Transparency = 0.4 })
		for i = 0, 5 do
			m.ball("Popcorn", 0.6, Vector3.new(-0.9 + (i % 3) * 0.9, 3.1 + math.floor(i / 3) * 0.4, -0.3 + (i % 2) * 0.5), rgb(255, 240, 170), COSMETIC)
		end
		m.cyl("Pole", 2.6, 0.2, Vector3.new(0, 5.9, 0), WHITE, COSMETIC)
		for i = 0, 3 do
			m.deco("Canopy", Vector3.new(1, 0.2, 3), Vector3.new(-1.5 + i, 7.2, 0), if i % 2 == 0 then rgb(230, 60, 70) else WHITE)
		end
	end,
}

PROPS.CottonCandyCart = {
	build = function(m)
		cartBase(m, rgb(255, 180, 220))
		for i, p in { { -0.9, 0.3, rgb(255, 170, 220) }, { 0, -0.2, rgb(170, 220, 255) }, { 0.9, 0.3, rgb(255, 210, 240) } } do
			m.deco("Stick", Vector3.new(0.1, 1.6, 0.1), Vector3.new(p[1], 3.6, p[2]), WHITE)
			m.ball("Candy", 1.3 + (i % 2) * 0.2, Vector3.new(p[1], 4.8, p[2]), p[3], COSMETIC)
		end
		m.cyl("Machine", 0.8, 1.6, Vector3.new(-0.6, 3.2, 0.5), rgb(220, 220, 230), COSMETIC)
	end,
}

PROPS.IceCreamCart = {
	build = function(m)
		cartBase(m, rgb(170, 220, 255))
		m.cyl("Pole", 4.2, 0.2, Vector3.new(-1, 4.9, 0), WHITE, COSMETIC)
		m.cyl("Umbrella", 0.4, 5, Vector3.new(-1, 7.1, 0), rgb(255, 150, 190), COSMETIC)
		m.deco("Cone", Vector3.new(0.6, 1, 0.6), Vector3.new(0.8, 3.3, 0), rgb(220, 170, 100), nil, Vector3.new(0, 45, 0))
		m.ball("Scoop", 0.9, Vector3.new(0.8, 4, 0), rgb(255, 200, 220), COSMETIC)
		m.ball("Scoop2", 0.8, Vector3.new(0.8, 4.6, 0), rgb(160, 110, 70), COSMETIC)
	end,
}

PROPS.TrashBin = {
	build = function(m)
		m.cyl("Bin", 3, 2, Vector3.new(0, 1.5, 0), rgb(90, 170, 110))
		m.cyl("Lid", 0.3, 2.2, Vector3.new(0, 3.15, 0), rgb(70, 140, 90))
		m.deco("Sign", Vector3.new(0.9, 0.9, 0.05), Vector3.new(0, 1.8, -1.02), WHITE)
	end,
}

PROPS.TicketMachine = {
	build = function(m)
		m.box("Body", Vector3.new(2.2, 4.4, 1.6), Vector3.new(0, 2.2, 0), rgb(240, 120, 150))
		local screen = m.deco("Screen", Vector3.new(1.6, 1.1, 0.05), Vector3.new(0, 3.3, -0.82), rgb(30, 40, 60), { Material = Enum.Material.Neon })
		m.text(screen, "🎟", rgb(255, 230, 120), Enum.Font.FredokaOne)
		m.deco("Slot", Vector3.new(1, 0.15, 0.1), Vector3.new(0, 2.2, -0.84), rgb(30, 30, 35))
		m.deco("Button", Vector3.new(0.4, 0.4, 0.1), Vector3.new(0.5, 2.7, -0.84), rgb(255, 220, 60), { Shape = Enum.PartType.Ball })
		m.deco("Topper", Vector3.new(2.4, 0.5, 1.8), Vector3.new(0, 4.65, 0), rgb(255, 220, 90))
	end,
}

PROPS.BearStatue = {
	build = function(m)
		m.box("Pedestal", Vector3.new(4, 1.5, 4), Vector3.new(0, 0.75, 0), rgb(235, 225, 210), { Material = Enum.Material.Marble })
		local fur = rgb(200, 150, 100)
		m.ball("Body", 3.2, Vector3.new(0, 3.1, 0), fur, COSMETIC)
		m.ball("Belly", 2.2, Vector3.new(0, 3, -0.7), rgb(240, 210, 170), COSMETIC)
		m.ball("Head", 2.6, Vector3.new(0, 5.4, 0), fur, COSMETIC)
		for _, x in { -1, 1 } do
			m.ball("Ear", 1, Vector3.new(x * 0.95, 6.5, 0), fur, COSMETIC)
			m.ball("Arm", 1.2, Vector3.new(x * 1.6, 3.6, -0.3), fur, COSMETIC)
			m.ball("Eye", 0.35, Vector3.new(x * 0.45, 5.6, -1.15), rgb(30, 25, 25), COSMETIC)
			m.ball("Cheek", 0.4, Vector3.new(x * 0.8, 5.1, -1.05), rgb(255, 150, 170), COSMETIC)
		end
		m.ball("Muzzle", 1, Vector3.new(0, 5.1, -1.05), rgb(240, 210, 170), COSMETIC)
		m.ball("Nose", 0.35, Vector3.new(0, 5.3, -1.5), rgb(40, 30, 30), COSMETIC)
		m.deco("Bow", Vector3.new(1.4, 0.5, 0.3), Vector3.new(0, 4.4, -1.2), rgb(230, 60, 90))
	end,
}

PROPS.PhotoBoard = {
	build = function(m)
		m.deco("Board", Vector3.new(6, 6, 0.4), Vector3.new(0, 4, 0), rgb(130, 200, 255))
		m.deco("Character", Vector3.new(3.6, 4.4, 0.1), Vector3.new(0, 3.6, -0.25), rgb(255, 200, 120))
		m.deco("FaceHole", Vector3.new(1.4, 1.4, 0.12), Vector3.new(0, 5.3, -0.3), rgb(40, 40, 50), { Shape = Enum.PartType.Ball })
		for _, x in { -1.6, 1.6 } do
			m.deco("Star", Vector3.new(0.8, 0.8, 0.1), Vector3.new(x * 1.4, 6.4, -0.25), rgb(255, 230, 80), nil, Vector3.new(0, 0, 45))
		end
		for _, x in { -2.6, 2.6 } do
			m.box("Foot", Vector3.new(0.5, 1, 2.4), Vector3.new(x, 0.5, 0.3), rgb(250, 250, 250))
		end
	end,
}

PROPS.GiftBoxes = {
	build = function(m)
		local boxes = { { 0, 1.2, 0, 2.4, rgb(255, 120, 140), rgb(255, 230, 120) }, { 2, 1, 0.4, 2, rgb(120, 190, 255), WHITE }, { 0.4, 3.2, 0.2, 1.6, rgb(150, 220, 130), rgb(255, 120, 140) }, { -1.8, 0.8, -0.6, 1.6, rgb(255, 210, 90), rgb(200, 120, 255) } }
		for _, b in boxes do
			m.box("Box", Vector3.new(b[4], b[4], b[4]), Vector3.new(b[1], b[2], b[3]), b[5])
			m.deco("Ribbon", Vector3.new(b[4] + 0.05, b[4] + 0.05, 0.3), Vector3.new(b[1], b[2], b[3]), b[6])
			m.deco("Ribbon", Vector3.new(0.3, b[4] + 0.05, b[4] + 0.05), Vector3.new(b[1], b[2], b[3]), b[6])
		end
	end,
}

PROPS.Signpost = {
	build = function(m)
		m.cyl("Pole", 5.6, 0.4, Vector3.new(0, 2.8, 0), rgb(130, 90, 60))
		for i, info in { { "관람차", -30 }, { "롤러코스터", 40 }, { "바이킹", 150 } } do
			local arrow = m.deco("Arrow", Vector3.new(3.6, 0.8, 0.2), Vector3.new(0, 6.5 - i * 0.95, 0), rgb(255, 245, 220), nil, Vector3.new(0, info[2], 0))
			m.text(arrow, info[1], rgb(120, 60, 40), Enum.Font.FredokaOne)
		end
		m.ball("Top", 0.7, Vector3.new(0, 6.9, 0), rgb(255, 200, 80), COSMETIC)
	end,
}

--------------------------------------------------------------------------------
-- 배치. 자유 소품: { 이름, x, z, 바라보는 각도(도) }. 벽 소품: { 이름, x, z, wall = {dx, dz} } (그 방향의 벽에 붙음)

local SPECS = {
	Stage1 = {
		{ "Blackboard", -125, 130, wall = { 0, 1 } },
		{ "Lectern", -125, 133, 0 },
		{ "StudentDesk", -122, 121, 180 }, -- 의자에 앉으면 칠판을 봄
		{ "Globe", 120, 122, 30 },
		{ "Bookshelf", 125, 135, wall = { 1, 0 } },
		{ "Piano", -130, 45, wall = { -1, 0 } },
		{ "BallBasket", 62, 78, 20 },
		{ "VaultingBox", 112, 20, 90 },
		{ "LunchCart", 108, -60, 0 },
		{ "BulletinBoard", -130, -40, wall = { -1, 0 } },
	},
	Stage2 = {
		{ "HospitalBed", -128, 118, 0 },
		{ "IVStand", -121, 110, 0 },
		{ "MedicineCabinet", 115, 90, wall = { 1, 0 } },
		{ "Wheelchair", -85, 85, 160 },
		{ "Stretcher", -110, 12, 90 },
		{ "ReceptionDesk", 98, 10, 0 },
		{ "WaitingChairs", -65, -38, 0 },
		{ "OxygenTanks", 80, -38, 0 },
		{ "PrivacyScreen", -130, -92, 0 },
		{ "XRayLightbox", -40, -92, wall = { 0, 1 } },
	},
	Stage3 = {
		{ "LabBench", -102, 104, 0 },
		{ "ChemicalShelf", -100, 55, wall = { -1, 0 } },
		{ "SpecimenTank", 104, 56, 0 },
		{ "ComputerTerminal", 24, 104, 180 },
		{ "ServerRack", -104, 24, 0 },
		{ "HazardBarrels", 104, -22, 30 },
		{ "Microscope", -24, -24, 45 },
		{ "CryoPod", -60, -58, 0 },
		{ "Cage", 24, -104, 0 },
		{ "Whiteboard", 100, -60, wall = { 0, 1 } },
	},
	Stage4 = {
		{ "BalloonCart", -22, -20, 45 },
		{ "PopcornCart", -40, -124, 0 },
		{ "CottonCandyCart", 38, 124, 180 },
		{ "IceCreamCart", -128, -70, 90 },
		{ "TrashBin", 16, -62, 0 },
		{ "TicketMachine", 24, -140, 0 },
		{ "BearStatue", -24, -128, 180 },
		{ "PhotoBoard", 60, 22, 180 },
		{ "GiftBoxes", 78, -122, 0 },
		{ "Signpost", 16, 100, 0 },
	},
}

local CLEARANCE = {
	HideSpot = 12,
	Door = 6,
	Plank = 6,
	Generator = 5,
	SurvivorSpawn = 4,
	MonsterSpawn = 4,
	ChaserSpawn = 6,
	ChaserGate = 8,
	Exit = 8,
	PatrolPoint = 3,
	ItemSpawn = 3,
}
local IGNORE_OVERLAP = { Floor = true, Road = true, Plaza = true }

local function tagParts(map)
	local list = {}
	for _, d in map:GetDescendants() do
		for _, tag in d:GetTags() do
			if CLEARANCE[tag] then
				local parts = {}
				if d:IsA("BasePart") then
					table.insert(parts, d)
				end
				for _, child in d:GetDescendants() do
					if child:IsA("BasePart") then
						table.insert(parts, child)
					end
				end
				for _, part in parts do
					table.insert(list, { tag = tag, name = d.Name, part = part })
				end
			end
		end
	end
	return list
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local report = {}
for stageName, spec in SPECS do
	if ONLY and stageName ~= ONLY then
		continue
	end
	local source = ServerStorage.Maps:FindFirstChild(stageName)
	if not source then
		table.insert(report, `{stageName}: 맵 없음`)
		continue
	end
	local copy = source:Clone()
	copy.Name = "PropsPreview_" .. stageName
	local oldProps = copy:FindFirstChild("Props")
	if oldProps then
		oldProps:Destroy()
	end
	copy.Parent = Workspace
	local props = Map.folder(copy, "Props")
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { copy }
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { copy }
	local tags = tagParts(copy)
	local problems = {}

	for index, entry in spec do
		local kind = entry[1]
		local def = PROPS[kind]
		local model = Instance.new("Model")
		model.Name = kind
		local base
		if entry.wall then
			local dir = Vector3.new(entry.wall[1], 0, entry.wall[2]).Unit
			local origin = Vector3.new(entry[2], FT + 4, entry[3])
			local hit = Workspace:Raycast(origin, dir * 60, rayParams)
			if not hit then
				table.insert(problems, `{index} {kind}: 벽을 못 찾음`)
				hit = { Position = origin + dir * 2 }
			end
			local at = Vector3.new(hit.Position.X, FT, hit.Position.Z)
			base = CFrame.lookAt(at, at - dir)
		else
			base = CFrame.new(entry[2], FT, entry[3]) * CFrame.Angles(0, math.rad(entry[4] or 0), 0)
		end
		def.build(maker(model, base))
		model.Parent = props

		local cf, size = model:GetBoundingBox()
		if not def.hang then
			local parts = Workspace:GetPartBoundsInBox(cf, size - Vector3.new(0.4, 0.4, 0.4), overlapParams)
			for _, part in parts do
				if part.CanCollide and not part:IsDescendantOf(model) and not part:IsDescendantOf(props) and not IGNORE_OVERLAP[part.Name] then
					table.insert(problems, `{index} {kind}: {part:GetFullName():gsub("^.-PropsPreview_%w+%.", "")}와 겹침`)
					break
				end
			end
		end
		local radius = math.max(size.X, size.Z) / 2
		local center = flat(cf.Position)
		local nearest = {}
		for _, t in tags do
			if not (def.hang and t.tag == "HideSpot") then
				local d = (flat(t.part.Position) - center).Magnitude - radius - math.max(t.part.Size.X, t.part.Size.Z) / 2
				if d < CLEARANCE[t.tag] and (nearest[t.name] == nil or d < nearest[t.name]) then
					nearest[t.name] = d
				end
			end
		end
		for name, d in nearest do
			table.insert(problems, string.format("%d %s: %s와 가까움 (%.1f)", index, kind, name, d))
		end
		local collidableTop = 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				-- 돌린 파트(세운 원기둥 등)도 맞게 월드 기준 세로 반높이를 구한다
				local c, half = part.CFrame, part.Size / 2
				local up = math.abs(c.RightVector.Y) * half.X + math.abs(c.UpVector.Y) * half.Y + math.abs(c.LookVector.Y) * half.Z
				collidableTop = math.max(collidableTop, part.Position.Y + up - FT)
			end
		end
		if collidableTop > 6.05 then
			table.insert(problems, string.format("%d %s: 부딪히는 높이 %.1f > 6", index, kind, collidableTop))
		end
	end

	local old = source:FindFirstChild("Props")
	if old then
		old:Destroy()
	end
	props.Parent = source
	copy:Destroy()
	table.insert(report, `{stageName}: 소품 {#props:GetChildren()}개` .. (if #problems > 0 then "\n  " .. table.concat(problems, "\n  ") else " · 문제 없음"))
end
table.sort(report)
return table.concat(report, "\n")
