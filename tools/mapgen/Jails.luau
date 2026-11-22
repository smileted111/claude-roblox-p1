-- 감옥 배치 (경찰과 도둑 모드, 2026-11-22 사용자 요청). common.luau 뒤에 붙여 Studio MCP(Edit 모드)로 실행한다.
-- Stage1~4 맵에 Jail 폴더를 새로 만든다. ONLY에 스테이지 이름을 넣으면 그 맵만 다시 만든다.
-- 감옥 (Jail 태그 Model, 이름·Attribute는 src/shared/JailState.luau):
--   막힌 우리: 부딪히는 투명 벽 4개 + 투명 지붕(CellWall·CellRoof, 이름이 Wall이 아니라 캐주얼 모드 색칠에서 빠짐) +
--   부딪히지 않는 쇠창살 장식. 안쪽 높이 10이라 안에서 점프해도 지붕에 닿고, 밖에서는 지붕(높이 약 11)에 닿지 못한다
--   (둘레 16스터드 안에 밟을 수 있는 소품이 없는지 검사해 경고).
--   Inside(갇힌 사람을 세우는 곳) · ReleasePoint(풀려난 사람이 서는 곳, 우리 밖 빈자리) · RescueZone(구출 구역 상자,
--   우리 둘레 약 3스터드)은 모두 투명. 구출 구역 테두리는 바닥에 노란 띠로 보인다. 앞(풀려나는 쪽)에 "감옥" 표지판.
-- 자리는 맵마다 18×18 빈 바닥을 찾아 정했다 (2026-11-22, 시작 위치·에너지 코어·출구·숨는 곳과 떨어지고 길을 막지 않는 곳).
-- 표지판 글자는 Localization Signs.Jail의 한국어 원문과 같아야 번역된다.

local CollectionService = game:GetService("CollectionService")
local ONLY = nil -- 예: "Stage4"
local INNER = 10 -- 우리 안쪽 한 변
local HEIGHT = 10 -- 우리 안쪽 높이
local WALL_T = 0.6
local ZONE = 18 -- 구출 구역 한 변
local RELEASE_DISTANCE = INNER / 2 + WALL_T + 3 -- 가운데에서 풀려나는 자리까지
local BAR_STEP = 1.25
local BAR_COLOR = Color3.fromRGB(70, 72, 82)
local ZONE_COLOR = Color3.fromRGB(255, 210, 60)

local SPOTS = {
	Stage1 = { -30, 22 }, -- 학교: 왼쪽 아래 교실, 가운데 복도 가까이
	Stage2 = { -18, -14 }, -- 폐병원: 가운데 병동 왼쪽 위
	Stage3 = { 80, 0 }, -- 지하 연구소: 오른쪽 가운데 방 (시작 위치·에너지 코어 없음)
	Stage4 = { -55, -30 }, -- 놀이공원: 회전목마 옆 잔디 (길 밖)
}

local function cosmetic(part)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function invisible(part)
	part.Transparency = 1
	cosmetic(part)
end

local function buildJail(map, folder, cx, cz)
	local center = Vector3.new(cx, 1, cz)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.RespectCanCollide = true
	local warnings = {}

	-- 빈자리 검사 (바닥 위 18x9x18)
	local blockers = workspace:GetPartBoundsInBox(CFrame.new(cx, 1.2 + 4.5, cz), Vector3.new(ZONE, 9, ZONE), params)
	if #blockers > 0 then
		table.insert(warnings, `자리에 부딪히는 파트 {#blockers}개 ({blockers[1]:GetFullName()})`)
	end

	-- 풀려나는 쪽: 맵 가운데를 향하는 축부터, 그 자리(5x6x5)가 비어 있는 첫 방향
	local toCenter = Vector3.new(-cx, 0, -cz)
	local main = if math.abs(toCenter.X) >= math.abs(toCenter.Z)
		then Vector3.new(math.sign(toCenter.X), 0, 0)
		else Vector3.new(0, 0, math.sign(toCenter.Z))
	if main.Magnitude < 0.5 then
		main = Vector3.new(1, 0, 0)
	end
	local candidates = { main, -main, Vector3.new(main.Z, 0, -main.X), Vector3.new(-main.Z, 0, main.X) }
	local front = nil
	for _, dir in candidates do
		local spot = center + dir * RELEASE_DISTANCE
		local hits = workspace:GetPartBoundsInBox(CFrame.new(spot + Vector3.new(0, 3.2, 0)), Vector3.new(5, 6, 5), params)
		if #hits == 0 then
			front = dir
			break
		end
	end
	if not front then
		front = main
		table.insert(warnings, "풀려나는 자리가 모두 막힘")
	end

	-- 지붕에 올라갈 수 있는 소품 검사: 둘레 16스터드 안 부딪히는 파트 중 윗면이 3.2~9 높이
	local near = workspace:GetPartBoundsInRadius(center + Vector3.new(0, 5, 0), 16, params)
	for _, part in near do
		local top = part.Position.Y + part.Size.Y / 2
		if top > 3.2 and top < 9 and part.Size.Y < 12 then
			table.insert(warnings, `밟고 지붕에 오를 수 있는 파트: {part:GetFullName()} (윗면 {math.floor(top * 10) / 10})`)
		end
	end

	local frame = CFrame.lookAt(center, center + front) -- 앞(LookVector) = 풀려나는 쪽
	local model = Instance.new("Model")
	model.Name = "Jail1"

	local function at(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	local function part(name, size, cf, color, props)
		local p = Map.part(model, name, size, Vector3.zero, "Dark stone grey", props)
		p.CFrame = cf
		if color then
			p.Color = color
		end
		return p
	end

	local outer = INNER + WALL_T * 2
	local base = part("JailBase", Vector3.new(outer + 0.4, 0.2, outer + 0.4), at(0, 0.1, 0), Color3.fromRGB(60, 60, 66))
	base.Material = Enum.Material.Concrete
	model.PrimaryPart = base

	-- 부딪히는 투명 벽과 지붕
	local wallY = 0.2 + (HEIGHT + 0.6) / 2
	local half = INNER / 2 + WALL_T / 2
	for _, s in { { half, 0, WALL_T, outer }, { -half, 0, WALL_T, outer }, { 0, half, outer, WALL_T }, { 0, -half, outer, WALL_T } } do
		local wall = part("CellWall", Vector3.new(s[3], HEIGHT + 0.6, s[4]), at(s[1], wallY, s[2]))
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
	end
	local roof = part("CellRoof", Vector3.new(outer, 0.6, outer), at(0, 0.2 + HEIGHT + 0.3, 0))
	roof.Transparency = 1
	roof.CanQuery = false
	roof.CanTouch = false
	roof.CastShadow = false

	-- 쇠창살 장식
	local barY = 0.2 + HEIGHT / 2
	local steps = math.floor(INNER / BAR_STEP + 0.5)
	for i = 0, steps do
		local t = -INNER / 2 + i * (INNER / steps)
		for _, p in { { t, half }, { t, -half }, { half, t }, { -half, t } } do
			local bar = part("Bar", Vector3.new(0.3, HEIGHT, 0.3), at(p[1], barY, p[2]), BAR_COLOR)
			bar.Material = Enum.Material.Metal
			cosmetic(bar)
		end
	end
	for _, y in { 0.45, 0.2 + HEIGHT, 0.2 + HEIGHT / 2 } do
		for _, s in { { 0, half, outer, 0.4 }, { 0, -half, outer, 0.4 }, { half, 0, 0.4, outer }, { -half, 0, 0.4, outer } } do
			local rail = part("Rail", Vector3.new(s[3], 0.4, s[4]), at(s[1], y, s[2]), BAR_COLOR)
			rail.Material = Enum.Material.Metal
			cosmetic(rail)
		end
	end
	for x = -INNER / 2 + 1, INNER / 2 - 1, 2 do
		local roofBar = part("RoofBar", Vector3.new(0.3, 0.3, outer), at(x, 0.2 + HEIGHT + 0.15, 0), BAR_COLOR)
		roofBar.Material = Enum.Material.Metal
		cosmetic(roofBar)
	end

	-- 투명 표시 파트 (JailState)
	local inside = part("Inside", Vector3.new(INNER - 2, 1, INNER - 2), at(0, 0.2 + 0.5, 0))
	invisible(inside)
	local release = part("ReleasePoint", Vector3.new(4, 1, 4), at(0, 0.5, -RELEASE_DISTANCE))
	invisible(release)
	local zone = part("RescueZone", Vector3.new(ZONE, 8, ZONE), at(0, 4, 0))
	invisible(zone)

	-- 구출 구역 테두리 (바닥의 노란 띠)
	for _, s in { { 0, ZONE / 2, ZONE, 0.35 }, { 0, -ZONE / 2, ZONE, 0.35 }, { ZONE / 2, 0, 0.35, ZONE }, { -ZONE / 2, 0, 0.35, ZONE } } do
		local strip = part("ZoneEdge", Vector3.new(s[3], 0.06, s[4]), at(s[1], 0.03, s[2]), ZONE_COLOR)
		strip.Material = Enum.Material.Neon
		cosmetic(strip)
	end

	-- 앞쪽 위 표지판
	local sign = part("Sign", Vector3.new(5, 1.6, 0.3), at(0, 0.2 + HEIGHT + 1.3, -(half + 0.2)), Color3.fromRGB(45, 45, 55))
	cosmetic(sign)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = ZONE_COLOR
	label.Text = "감옥"
	label.Parent = gui

	CollectionService:AddTag(model, "Jail")
	model.Parent = folder
	return warnings, front
end

local results = {}
for stageName, spot in SPOTS do
	if ONLY and stageName ~= ONLY then
		continue
	end
	local map = game:GetService("ServerStorage").Maps[stageName]
	local old = map:FindFirstChild("Jail")
	if old then
		old:Destroy()
	end
	-- 겹침 검사는 Workspace에서만 되므로 잠깐 복제해 검사하고, 만든 감옥은 원본 맵에 옮긴다.
	local preview = map:Clone()
	preview.Name = "JailPreview"
	preview.Parent = workspace
	local folder = Map.folder(preview, "Jail")
	local warnings, front = buildJail(preview, folder, spot[1], spot[2])
	folder.Parent = map
	preview:Destroy()
	table.insert(
		results,
		`{stageName}: 감옥 ({spot[1]}, {spot[2]}) 앞 ({front.X}, {front.Z})`
			.. (if #warnings > 0 then " · 경고: " .. table.concat(warnings, " / ") else " · 문제 없음")
	)
end
table.sort(results)
return table.concat(results, "\n")
