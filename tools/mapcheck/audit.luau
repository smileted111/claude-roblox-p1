--!nocheck
-- 맵 점검 (docs/studio-workflow.md S3-8). Studio MCP execute_luau(편집 모드)로 실행한다. 아무것도 고치지 않는다.
-- 맵을 다듬은 뒤 다시 돌려 문제 목록(마지막 return 문자열)을 본다.
--
-- 점검: 태그별 개수와 구조(CLAUDE.md 맵 규칙, GDD 4.2), 괴물 길찾기(각 MonsterSpawn → 모든 SurvivorSpawn·Generator,
--   PathfindingService, 일반 괴물과 거인 크기), 파트·메시·텍스처 수, 보이지 않는데 충돌하는 파트, 앵커 안 된 파트,
--   조명(그림자 켠 조명 수, 빛이 먼 발전기·숨는 곳), 모바일 성능 기준.
-- 길찾기는 맵을 잠시 Workspace에 복제해(문은 열림, 판자는 세워 둠, 대기실 문 열림 — 추격 단계 상태) 계산하고 지운다.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ServerStorage = game:GetService("ServerStorage")

local STAGES = { "Stage1", "Stage2", "Stage3" }
local GENERATORS = { Stage1 = 3, Stage2 = 4, Stage3 = 5 } -- Config.Stages GeneratorCount (GDD 4.2)
local MAX_SURVIVORS = 7 -- MaxPlayers 8 - 추격자 1
local AGENTS = {
	{ name = "괴물", radius = 2, height = 6 }, -- Config.MonsterAI.Agent
	{ name = "거인", radius = 2.5, height = 9.5 }, -- Config.Monsters.Giant.AgentRadius·AgentHeight
}
local LIGHT_NEAR = 40 -- 이 거리 안에 조명이 없는 발전기·출구는 "어두울 수 있음"
local MOBILE_PART_WARN = 5000 -- 맵 하나의 파트 수 (모바일 기준, 임시)
local MOBILE_SHADOW_LIGHT_WARN = 8 -- 그림자를 켠 조명 수 (모바일 기준, 임시)

local rows = {} -- { stage, severity, item, detail }
local function report(stage, severity, item, detail)
	table.insert(rows, string.format("| %s | %s | %s | %s |", stage, severity, item, detail))
end

local function tagged(map, tag)
	local list = {}
	for _, d in map:GetDescendants() do
		if d:HasTag(tag) then
			table.insert(list, d)
		end
	end
	if map:HasTag(tag) then
		table.insert(list, map)
	end
	return list
end

local function positionOf(inst)
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function auditTags(stageId, map)
	local counts = {}
	for _, tag in
		{
			"SurvivorSpawn",
			"ChaserSpawn",
			"ChaserGate",
			"MonsterSpawn",
			"PatrolPoint",
			"HideSpot",
			"Generator",
			"Exit",
			"ItemSpawn",
			"Plank",
			"Door",
			"DarkZone",
		}
	do
		counts[tag] = #tagged(map, tag)
	end
	local summary = {}
	for _, tag in { "SurvivorSpawn", "MonsterSpawn", "PatrolPoint", "HideSpot", "Generator", "Exit", "ItemSpawn", "Plank", "Door", "DarkZone" } do
		table.insert(summary, `{tag} {counts[tag]}`)
	end
	report(stageId, "정보", "태그 수", table.concat(summary, ", "))

	if counts.Generator < GENERATORS[stageId] then
		report(stageId, "높음", "발전기 부족", `Generator {counts.Generator}대 < 필요 {GENERATORS[stageId]}대 (GDD 4.2)`)
	elseif counts.Generator > GENERATORS[stageId] then
		report(stageId, "정보", "발전기 여유", `Generator {counts.Generator}대 (필요 {GENERATORS[stageId]}대, 남는 것은 안 씀)`)
	end
	if counts.SurvivorSpawn < MAX_SURVIVORS then
		report(stageId, "보통", "생존자 시작 위치 부족", `SurvivorSpawn {counts.SurvivorSpawn}곳 < 최대 생존자 {MAX_SURVIVORS}명 (겹쳐서 나옴)`)
	end
	if counts.ChaserSpawn == 0 then
		report(stageId, "높음", "추격자 시작 위치 없음", "ChaserSpawn 0")
	end
	if counts.ChaserGate == 0 then
		report(stageId, "높음", "대기실 문 없음", "ChaserGate 0")
	end
	if counts.MonsterSpawn == 0 then
		report(stageId, "높음", "괴물 생성 위치 없음", "MonsterSpawn 0")
	end
	if counts.Exit == 0 then
		report(stageId, "높음", "출구 없음", "Exit 0")
	end
	if counts.HideSpot < 4 then
		report(stageId, "보통", "숨는 곳 적음", `HideSpot {counts.HideSpot}곳`)
	end

	-- 구조
	local exitIds = {}
	for _, exit in tagged(map, "Exit") do
		local id = exit:GetAttribute("ExitId")
		if id == nil then
			report(stageId, "높음", "출구 ExitId 없음", exit:GetFullName())
		elseif exitIds[id] then
			report(stageId, "보통", "출구 ExitId 중복", `{id}: {exit:GetFullName()}`)
		end
		if id ~= nil then
			exitIds[id] = true
		end
	end
	for _, spot in tagged(map, "HideSpot") do
		if not spot:IsA("Model") or not spot.PrimaryPart then
			report(stageId, "높음", "숨는 곳 PrimaryPart 없음", spot:GetFullName())
		end
	end
	for _, plank in tagged(map, "Plank") do
		if not plank:FindFirstChild("Board") or not plank:FindFirstChild("FallenPose") then
			report(stageId, "높음", "판자 구조", `{plank:GetFullName()}: Board·FallenPose 필요`)
		end
	end
	for _, door in tagged(map, "Door") do
		if not door:FindFirstChild("Panel") or not door:FindFirstChild("OpenPose") then
			report(stageId, "높음", "문 구조", `{door:GetFullName()}: Panel·OpenPose 필요`)
		end
	end
	local routes = {}
	for _, point in tagged(map, "PatrolPoint") do
		local route, order = point:GetAttribute("Route"), point:GetAttribute("Order")
		if route == nil or order == nil then
			report(stageId, "보통", "순찰 지점 속성 없음", `{point:GetFullName()} (Route·Order 필요)`)
		else
			routes[route] = (routes[route] or 0) + 1
		end
	end
	local routeText = {}
	for route, n in routes do
		table.insert(routeText, `{route} {n}곳`)
		if n < 2 then
			report(stageId, "보통", "순찰 경로 짧음", `Route {route}: {n}곳`)
		end
	end
	table.sort(routeText)
	report(stageId, "정보", "순찰 경로", table.concat(routeText, ", "))
end

local function auditParts(stageId, map)
	local parts, meshes, unions, textures, unanchored, invisibleSolid = 0, 0, 0, 0, {}, {}
	local lights, shadowLights = {}, 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("MeshPart") then
				meshes += 1
			elseif d:IsA("UnionOperation") then
				unions += 1
			end
			if not d.Anchored then
				table.insert(unanchored, d:GetFullName())
			end
			local isZone = d:HasTag("DarkZone")
			local isPose = d.Name == "FallenPose" or d.Name == "OpenPose"
			local isMarker = d:HasTag("SurvivorSpawn")
				or d:HasTag("ChaserSpawn")
				or d:HasTag("MonsterSpawn")
				or d:HasTag("PatrolPoint")
				or d:HasTag("ItemSpawn")
			if d.Transparency >= 0.9 and d.CanCollide and not isZone and not isPose and not isMarker then
				table.insert(invisibleSolid, d:GetFullName())
			end
		elseif d:IsA("Texture") or d:IsA("Decal") or d:IsA("SurfaceAppearance") then
			textures += 1
		elseif d:IsA("Light") then
			table.insert(lights, d)
			if d.Shadows then
				shadowLights += 1
			end
		end
	end
	-- 표시용 마커(시작 위치 등)가 충돌하는지
	for _, tag in { "SurvivorSpawn", "ChaserSpawn", "MonsterSpawn", "PatrolPoint", "ItemSpawn" } do
		for _, marker in tagged(map, tag) do
			if marker:IsA("BasePart") and marker.CanCollide and marker.Transparency >= 0.9 then
				table.insert(invisibleSolid, `{marker:GetFullName()} ({tag} 마커)`)
			end
		end
	end
	report(
		stageId,
		if parts > MOBILE_PART_WARN then "보통" else "정보",
		"파트 수",
		`BasePart {parts} (MeshPart {meshes}, Union {unions}), 텍스처·데칼 {textures}, 조명 {#lights} (그림자 켠 것 {shadowLights})`
	)
	if shadowLights > MOBILE_SHADOW_LIGHT_WARN then
		report(stageId, "보통", "그림자 켠 조명 많음", `{shadowLights}개 > {MOBILE_SHADOW_LIGHT_WARN} (모바일 부담)`)
	end
	if #unanchored > 0 then
		report(stageId, "높음", "앵커 안 된 파트", `{#unanchored}개: {table.concat(unanchored, ", ", 1, math.min(5, #unanchored))}`)
	end
	if #invisibleSolid > 0 then
		report(
			stageId,
			"보통",
			"안 보이는데 충돌하는 파트",
			`{#invisibleSolid}개: {table.concat(invisibleSolid, ", ", 1, math.min(6, #invisibleSolid))}`
		)
	end
	-- 조명에서 먼 발전기·출구 (DarkZone은 일부러 어두운 곳)
	local dark = {}
	for _, tag in { "Generator", "Exit" } do
		for _, target in tagged(map, tag) do
			local pos = positionOf(target)
			local near = false
			for _, light in lights do
				local holder = light.Parent
				local lpos = if holder and holder:IsA("BasePart")
					then holder.Position
					elseif holder and holder:IsA("Attachment") then holder.WorldPosition
					else nil
				if pos and lpos and (lpos - pos).Magnitude <= math.max(LIGHT_NEAR, light.Range) then
					near = true
					break
				end
			end
			if pos and not near then
				table.insert(dark, `{tag} {target.Name}`)
			end
		end
	end
	if #dark > 0 then
		report(stageId, "낮음", "조명에서 먼 목표", `{#dark}곳 ({LIGHT_NEAR}스터드 안에 조명 없음, 주변광만): {table.concat(dark, ", ")}`)
	end
end

local function prepareForPathing(clone)
	-- 추격 단계 상태: 문은 열림(문짝을 열린 자리로), 판자는 세워 둠, 자리 표시 파트는 충돌 없음, 대기실 문은 열림
	for _, door in tagged(clone, "Door") do
		local panel, pose = door:FindFirstChild("Panel"), door:FindFirstChild("OpenPose")
		if panel and pose then
			panel.CFrame = pose.CFrame
			panel.CanCollide = false
			pose.CanCollide = false
		end
	end
	for _, plank in tagged(clone, "Plank") do
		local pose = plank:FindFirstChild("FallenPose")
		if pose then
			pose.CanCollide = false
		end
	end
	for _, gate in tagged(clone, "ChaserGate") do
		for _, part in (if gate:IsA("BasePart") then { gate } else gate:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end
end

local function auditPaths(stageId, map)
	local clone = map:Clone()
	clone.Name = "MapCheck_" .. stageId
	prepareForPathing(clone)
	clone.Parent = workspace
	task.wait(1) -- 길찾기 격자가 갱신되도록
	local spawns = tagged(clone, "MonsterSpawn")
	local targets = {}
	for _, t in tagged(clone, "SurvivorSpawn") do
		table.insert(targets, { name = `SurvivorSpawn {t.Name}`, points = { positionOf(t) } })
	end
	-- 발전기는 본체가 장애물이라 둘레 4방향(본체 가장자리에서 3스터드, 바닥 높이) 중 한 곳에 닿으면 된다
	for _, generator in tagged(clone, "Generator") do
		local cf, size = if generator:IsA("Model") then generator:GetBoundingBox() else generator.CFrame, generator.Size
		local floorY = cf.Position.Y - size.Y / 2 + 1
		local points = {}
		for _, dir in { cf.LookVector, -cf.LookVector, cf.RightVector, -cf.RightVector } do
			local flat = Vector3.new(dir.X, 0, dir.Z).Unit
			local reach = math.max(size.X, size.Z) / 2 + 3
			local p = cf.Position + flat * reach
			table.insert(points, Vector3.new(p.X, floorY, p.Z))
		end
		table.insert(targets, { name = `Generator {generator.Name}`, points = points })
	end
	for _, agent in AGENTS do
		local failed, total = {}, 0
		for _, spawnPart in spawns do
			local from = positionOf(spawnPart)
			for _, target in targets do
				total += 1
				local reached, status = false, "NoPath"
				for _, point in target.points do
					local path = PathfindingService:CreatePath({
						AgentRadius = agent.radius,
						AgentHeight = agent.height,
						AgentCanJump = false,
					})
					local ok = pcall(function()
						path:ComputeAsync(from, point)
					end)
					status = if ok then path.Status.Name else "오류"
					if ok and path.Status == Enum.PathStatus.Success then
						reached = true
						break
					end
				end
				if not reached then
					table.insert(failed, `{spawnPart.Name}→{target.name} ({status})`)
				end
			end
			task.wait()
		end
		if #failed > 0 then
			report(
				stageId,
				if agent.name == "괴물" then "높음" else "보통",
				`길찾기 실패 ({agent.name})`,
				`{#failed}/{total}: {table.concat(failed, ", ", 1, math.min(6, #failed))}`
			)
		else
			report(stageId, "정보", `길찾기 ({agent.name})`, `{total}개 경로 모두 성공`)
		end
	end
	clone:Destroy()
end

local maps = ServerStorage:FindFirstChild("Maps")
for _, stageId in STAGES do
	local map = maps and maps:FindFirstChild(stageId)
	if not map then
		report(stageId, "높음", "맵 없음", `ServerStorage.Maps.{stageId}`)
	else
		auditTags(stageId, map)
		auditParts(stageId, map)
		auditPaths(stageId, map)
	end
end
return "| 스테이지 | 심각도 | 항목 | 내용 |\n|---|---|---|---|\n" .. table.concat(rows, "\n")
