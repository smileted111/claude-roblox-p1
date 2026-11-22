--!strict
-- 추격자 스킬 공용 타입 (GDD 7.1). ChaserService(검사·쿨다운)와 종류별 스킬 모듈(Chasers/<Name>)이 함께 쓴다.
-- 스킬 모듈은 다른 서비스를 require하지 않고 ChaserService가 넘기는 SkillApi만 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chasers = require(ReplicatedStorage.Shared.Config.Chasers)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)

export type SkillContext = {
	player: Player,
	parts: CharacterParts.CharacterParts,
	def: Chasers.SkillDef,
	lookDirection: Vector3, -- 바라보는 수평 방향 (단위 벡터, 서버가 검사함)
}

export type SkillApi = {
	-- seconds초 동안 이동 속도 × multiplier (MovementService)
	boost: (player: Player, multiplier: number, seconds: number) -> (),
	-- 숨지 않은(연막 밖) 생존자의 지금 위치를 추격자 한 명의 화면에 seconds초 동안 표시한다. 표시한 수를 돌려준다
	revealSurvivors: (player: Player, seconds: number) -> number,
	-- 지금 숨지 않은 생존자들의 발 위치
	survivorFootPositions: () -> { Vector3 },
	-- 추격자 한 명에게 발자국을 보낸다 (Footprints 리모트)
	sendFootprints: (player: Player, positions: { Vector3 }, lifetime: number) -> (),
	-- 캐릭터·괴물을 빼고 충돌하는 파트에 막히는지 (벽 검사)
	raycastWalls: (origin: Vector3, direction: Vector3) -> RaycastResult?,
	-- 추격 단계가 계속되는 동안 true (지속 스킬이 도중에 멈출 때)
	isActive: (player: Player) -> boolean,
}

-- 쓰면 true를 돌려준다. false면 효과가 없어 쿨다운을 돌리지 않는다 (예: 앞이 바로 벽).
export type Skill = {
	use: (context: SkillContext, api: SkillApi) -> boolean,
}

return {}
