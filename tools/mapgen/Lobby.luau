-- 로비 블록 공간 (docs/studio-workflow.md S3-2). Studio MCP execute_luau로 Edit 모드에서 실행한다 (게임 코드가 아님).
-- Workspace.Lobby를 새로 만들고 Workspace의 SpawnLocation을 로비 안으로 옮긴다.
-- 스테이지 맵(원점, ±160)과 겹치지 않게 z = 460 ~ 540에 둔다. 바닥 윗면 y = 1 (맵과 같음).
--   같이 하기 발판 (LobbyTogether 태그, 초록): 위에 서 있으면 대기열
--   혼자 하기 발판 (LobbySolo 태그, 파랑): 서버가 "혼자 하기" 프롬프트를 단다

local CollectionService = game:GetService("CollectionService")
local CENTER_Z = 500

local function part(parent, name, size, position, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.BrickColor = BrickColor.new(color)
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- 표지판: 앞면(+Z, 스폰 쪽)에 큰 글씨와 작은 설명
local function sign(parent, name, position, title, subtitle, color)
	local board = part(parent, name, Vector3.new(18, 6, 1), position, "Really black")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 0.62)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = gui
	local subLabel = Instance.new("TextLabel")
	subLabel.Position = UDim2.fromScale(0.05, 0.62)
	subLabel.Size = UDim2.fromScale(0.9, 0.3)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.GothamMedium
	subLabel.TextScaled = true
	subLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
	subLabel.Text = subtitle
	subLabel.Parent = gui
	return board
end

local old = workspace:FindFirstChild("Lobby")
if old then
	old:Destroy()
end
local lobby = Instance.new("Folder")
lobby.Name = "Lobby"

part(lobby, "Floor", Vector3.new(100, 1, 80), Vector3.new(0, 0.5, CENTER_Z), "Medium stone grey")
-- 울타리 (높이 10)
part(lobby, "Wall", Vector3.new(102, 10, 2), Vector3.new(0, 6, CENTER_Z - 41), "Dark stone grey")
part(lobby, "Wall", Vector3.new(102, 10, 2), Vector3.new(0, 6, CENTER_Z + 41), "Dark stone grey")
part(lobby, "Wall", Vector3.new(2, 10, 80), Vector3.new(-51, 6, CENTER_Z), "Dark stone grey")
part(lobby, "Wall", Vector3.new(2, 10, 80), Vector3.new(51, 6, CENTER_Z), "Dark stone grey")

-- 같이 하기
local together = part(lobby, "TogetherPad", Vector3.new(24, 0.4, 20), Vector3.new(-22, 1.2, CENTER_Z - 18), "Lime green", {
	Material = Enum.Material.Neon,
	Transparency = 0.35,
	CanCollide = false,
})
CollectionService:AddTag(together, "LobbyTogether")
sign(lobby, "TogetherSign", Vector3.new(-22, 7, CENTER_Z - 30), "같이 하기", "초록 발판 위에서 다른 플레이어를 기다려요", Color3.fromRGB(120, 255, 140))

-- 혼자 하기
local solo = part(lobby, "SoloPad", Vector3.new(20, 0.4, 16), Vector3.new(22, 1.2, CENTER_Z - 18), "Bright blue", {
	Material = Enum.Material.Neon,
	Transparency = 0.35,
	CanCollide = false,
})
CollectionService:AddTag(solo, "LobbySolo")
sign(lobby, "SoloSign", Vector3.new(22, 7, CENTER_Z - 30), "혼자 하기", "파란 발판 위에서 [혼자 하기]를 누르면 바로 시작", Color3.fromRGB(120, 180, 255))

lobby.Parent = workspace

-- 스폰을 로비 안쪽(발판 반대편)으로
local spawnLocation = workspace:FindFirstChild("SpawnLocation")
if spawnLocation then
	spawnLocation.Position = Vector3.new(0, 1.5, CENTER_Z + 25)
	spawnLocation.Parent = lobby
end
return "Lobby built"
