--!strict
-- 망령 — 순간이동 (GDD 7.1): 바라보는 수평 방향으로 Distance스터드(20) 순간이동한다.
-- 벽을 통과하지 않게 몸통 높이에서 레이캐스트해 벽(충돌하는 파트)에 닿으면 WallMargin 앞에서 멈춘다.
-- 도착 자리 아래에 바닥이 없거나 1스터드도 못 가면 쓰지 않은 것으로 본다 (쿨다운 없음).

local ChaserTypes = require(script.Parent.ChaserTypes)

local MIN_DISTANCE = 1
local FLOOR_CHECK_DEPTH = 12

local Wraith: ChaserTypes.Skill = {
	use = function(context: ChaserTypes.SkillContext, api: ChaserTypes.SkillApi): boolean
		local def = context.def
		local root = context.parts.rootPart
		local origin = root.Position
		local look = context.lookDirection
		local distance = def.Distance or 0
		local hit = api.raycastWalls(origin, look * distance)
		if hit then
			distance = hit.Distance - (def.WallMargin or 2)
		end
		if distance < MIN_DISTANCE then
			return false
		end
		local target = origin + look * distance
		if not api.raycastWalls(target, Vector3.new(0, -FLOOR_CHECK_DEPTH, 0)) then
			return false
		end
		context.parts.character:PivotTo(CFrame.lookAt(target, target + look))
		return true
	end,
}

return Wraith
