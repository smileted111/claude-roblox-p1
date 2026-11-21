--!strict
-- 괴물 AI 공용 타입 (GDD 4.4). MonsterService(공통 부분)와 종류별 동작 모듈(Monsters/<Name>)이 함께 쓴다.
--
-- 종류별 동작 모듈은 Behavior를 돌려준다. MonsterService가 추격 단계에서 괴물마다 Config.MonsterAI.TickInterval 간격으로
-- tick을 부르고, 소리 사건(server/Util/NoiseBus)이 들리는 거리 안이면 onNoise를 부른다.
-- 동작 모듈은 MonsterService를 require하지 않고, 인자로 받는 Api(공통 이동·감지·상태 함수)만 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monsters = require(ReplicatedStorage.Shared.Config.Monsters)
local Types = require(ReplicatedStorage.Shared.Types)
local NoiseBus = require(script.Parent.Parent.Util.NoiseBus)

-- 순찰 경로: 같은 Route의 PatrolPoint 위치를 Order 순서로
export type Route = {
	name: string,
	points: { Vector3 },
}

-- 괴물이 볼 수 있는 생존자 (숨지 않은 정상·부상). 갱신이 있는 프레임마다 한 번 모은다.
export type Target = {
	player: Player,
	rootPart: BasePart,
	head: BasePart?,
}

export type Animations = {
	idle: AnimationTrack,
	walk: AnimationTrack,
	attack: AnimationTrack,
}

export type Monster = {
	name: string, -- 로그용 (예: 배회자#1)
	kind: Types.MonsterId,
	def: Monsters.MonsterDef,
	behavior: Behavior,
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	eye: BasePart, -- Head. 시야 레이캐스트의 시작점
	path: Path,
	animations: Animations,
	connections: { RBXScriptConnection },
	alive: boolean,

	state: Types.MonsterAIState,
	stateSince: number, -- os.clock
	nextTickAt: number,
	lastTickAt: number,

	route: Route?,
	routeIndex: number,

	target: Player?,
	lastSeenPosition: Vector3?,
	lastSeenAt: number,
	suspicion: number, -- 의심 중 대상을 본 시간의 합 (초)
	nextAttackAt: number,
	attackHitAt: number,

	pathRequest: number, -- 올릴 때마다 그 전에 시작한 경로 계산 결과를 버린다
	computing: boolean,
	lastPathAt: number,
	pathGoal: Vector3?, -- 지금 waypoints가 향하는 목표. 곧장 다가가는 중이거나 멈췄으면 nil
	waypoints: { PathWaypoint },
	waypointIndex: number,
	forceRepath: boolean,
	pathOnlyUntil: number, -- 곧장 다가가다 막혔으면 이때까지 길찾기만 쓴다

	stuckCheckPosition: Vector3,
	stuckCheckAt: number,

	-- 소리로 돌진 (사냥개)
	noiseGoal: Vector3?,
	dashUntil: number,
	-- 경보 (감시자): 생존자별 마지막 경보 시각
	alertedAt: { [Player]: number },
	-- 손전등에 멈춤 (그림자): 이때까지 움직이지 않는다
	frozenUntil: number,
	-- 생존자를 잡은 뒤 덮친 자리에 서 있는 시간 (잡힘 연출, Config.Catch.CaughtEffect.MonsterPause)
	catchPauseUntil: number,
}

-- 동작 모듈이 쓰는 공통 함수 (MonsterService가 채움)
export type Api = {
	setState: (monster: Monster, state: Types.MonsterAIState, detail: string?) -> (),
	-- 배회자식 상태 처리: 순찰 → 의심 → 추격 → 공격 → 포기
	tickPatrol: (monster: Monster, now: number, targets: { Target }) -> (),
	tickSuspicious: (monster: Monster, now: number, dt: number, targets: { Target }) -> (),
	tickChase: (monster: Monster, now: number, targets: { Target }) -> (),
	tickAttack: (monster: Monster, now: number, targets: { Target }) -> (),
	tickGiveUp: (monster: Monster, now: number, targets: { Target }) -> (),
	resumePatrol: (monster: Monster) -> (),
	giveUp: (monster: Monster, reason: string) -> (),
	remember: (monster: Monster, target: Target, now: number) -> (),
	-- 이동
	travelTo: (monster: Monster, goal: Vector3, now: number, directWhileNoPath: boolean) -> (),
	moveDirect: (monster: Monster, position: Vector3) -> (),
	stopMoving: (monster: Monster) -> (),
	checkStuck: (monster: Monster, now: number, wantsToMove: boolean) -> boolean,
	-- 감지
	findVisibleTarget: (monster: Monster, targets: { Target }, checkAngle: boolean, preferred: Player?) -> Target?,
	findVisibleTargets: (monster: Monster, targets: { Target }) -> { Target },
	findNearbyTarget: (monster: Monster, targets: { Target }, range: number) -> Target?,
	-- 공격 사거리·쿨다운이 되면 공격을 시작하고 true
	tryStartAttack: (monster: Monster, target: Target, now: number) -> boolean,
	-- 추격자 화면에 위치 표시 (ChaserMarker)
	markForChasers: (position: Vector3, duration: number, reason: Types.MarkerReason) -> (),
	-- 어두운 구역(DarkZone) 안인가 (그림자)
	isInDarkZone: (position: Vector3) -> boolean,
	-- 숨어 있는 생존자와 그 숨는 곳 위치·부수기 (거인)
	isHidden: (player: Player) -> boolean,
	hiddenSpotPosition: (player: Player) -> Vector3?,
	breakHideSpot: (player: Player, source: string) -> boolean,
	-- position 반경 안의 넘어진 판자·닫힌 문을 부숨 (거인). 부순 수
	breakBarriers: (position: Vector3, radius: number, source: string) -> number,
}

export type Behavior = {
	-- 추격 단계에서 TickInterval마다. 멈추지(yield) 않는다. 처음에는 state가 Idle이다.
	tick: (monster: Monster, now: number, dt: number, targets: { Target }, api: Api) -> (),
	-- 들리는 거리 안의 소리 (Senses에 Sound가 있는 괴물만)
	onNoise: ((monster: Monster, noise: NoiseBus.Noise, now: number, api: Api) -> ())?,
	-- 추격 단계가 끝나 대기(Idle)로 돌아갔을 때 (경보 표시 되돌리기 등)
	onIdle: ((monster: Monster) -> ())?,
	-- 조종자가 불렀을 때 seconds초 동안 position으로 온다. 없으면 공통 처리(의심 상태로 그 자리를 찾아감)
	onSummon: ((monster: Monster, position: Vector3, now: number, seconds: number, api: Api) -> ())?,
	usesPatrolRoute: boolean, -- false면 순찰 경로를 배정하지 않음 (움직이지 않는 감시자)
}

return {}
