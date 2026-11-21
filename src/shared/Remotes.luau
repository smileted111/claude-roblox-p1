--!strict
-- 모든 RemoteEvent를 이 파일 한 곳에서 정의한다 (CLAUDE.md). 실제 인스턴스는 ReplicatedStorage.Remotes 폴더에 있다.
--
-- 생성: 서버 진입점이 서비스보다 먼저 Remotes.setupServer()를 불러 모두 만든다.
-- 조회: Remotes.get(이름). 클라이언트에서는 서버가 만들 때까지 기다리므로 Init이 아니라 Start에서 부른다.
--
-- 리모트는 한 번 일어나는 사건에만 쓴다. 계속 유지되는 상태(매치 단계, 남은 시간, 역할, 생존자 상태,
-- 출구 개방 등)는 Attribute로 공개해 늦게 들어온 클라이언트도 바로 읽을 수 있게 한다.
-- 클라이언트 → 서버 리모트는 서버에서 server/Util/RemoteHandler로 연결한다. 거기서 빈도 제한(Config.RateLimits)을 걸고
-- 관전자 요청을 거절한 뒤(Remotes.isSpectatorAllowed), 각 서비스가 인자·역할·거리·상태를 검사한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

-- 서버 → 클라이언트
export type ServerEventName =
	"RoleReveal"
	| "Notice"
	| "ChaserMarker"
	| "StageResult"
	| "MatchResult"
	| "SoloOffer"
	| "Footprints"

-- 클라이언트 → 서버
export type ClientEventName =
	"SetRunning"
	| "ChaserAttack"
	| "UseSkill"
	| "UseItem"
	| "SpectateCycle"
	| "SetChaserOptOut"
	| "ReturnToLobby"
	| "LobbyRequest"
	| "ChaserSelect"

export type EventName = ServerEventName | ClientEventName

-- 각 줄: 이름 -- 받는 사람 (인자). 설명
local SERVER_EVENTS: { ServerEventName } = {
	"RoleReveal", -- 모두 (chaserUserId: number, candidateUserIds: {number}). 역할 공개 룰렛 시작. 솔로는 보내지 않음
	"Notice", -- 한 명 또는 모두 (key: Types.NoticeKey, ...: string | number). Strings.Notices 문구를 잠깐 띄움
	"ChaserMarker", -- 추격자 (position: Vector3, duration: number, reason: Types.MarkerReason). 생존자 위치 잠깐 표시
	"StageResult", -- 참가자 (result: Types.StageResult). 스테이지 결과
	"MatchResult", -- 참가자 (result: Types.MatchResult). 최종 결과
	"SoloOffer", -- 한 명 (waitedSeconds: number). 같이 하기 구역에 혼자 오래 있음 → "혼자 시작할까요?" (GDD 5장)
	"Footprints", -- 추격자 (positions: {Vector3}, lifetime: number). 흔적 보기 스킬: 생존자 발자국 위치 (GDD 7.1)
}

local CLIENT_EVENTS: { ClientEventName } = {
	"SetRunning", -- 생존자 (isRunning: boolean). 달리기 의사만 보냄. 속도는 서버가 정함
	"ChaserAttack", -- 추격자 (). 근접 공격. 판정은 서버
	"UseSkill", -- 추격자 (lookDirection: Vector3). 고유 스킬. 망령 순간이동은 이 방향으로
	"UseItem", -- 생존자 (slot: number, aimPosition: Vector3?). 아이템 사용. 알람시계는 던질 위치를 함께 보냄
	"SpectateCycle", -- 관전자 (step: number). 1이면 다음, -1이면 이전 대상. 관전 대상 자체는 Player Attribute(MatchState)
	"SetChaserOptOut", -- 모두 (optOut: boolean). "추격자 안 하기" 설정
	"ReturnToLobby", -- 참가자 (). 매치에서 빠져 로비로 (관전 화면 버튼). 혼자 하기 서버에서는 일반 서버로 이동
	"LobbyRequest", -- 로비에 있는 사람 (action: Types.LobbyAction). 같이 하기 구역으로 가기·솔로 제안 답
	"ChaserSelect", -- 로비에 있는 사람 (action: "Select" | "Unlock", chaserId: Types.ChaserId). 추격자 종류 고르기·코인 해금
}

-- 관전자(역할 Spectator)도 보낼 수 있는 클라이언트 → 서버 리모트. 나머지는 관전자가 보내면 서버가 모두 거절한다 (GDD 8장).
local SPECTATOR_ALLOWED: { [ClientEventName]: boolean } = {
	SpectateCycle = true,
	SetChaserOptOut = true, -- 다음 스테이지부터 적용되는 설정
	ReturnToLobby = true,
}

local Remotes = {}

local cache: { [string]: RemoteEvent } = {}

local function getOrCreateFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

-- 폴더에 이미 있으면 그것을 쓴다. 이 모듈이 다른 실행 환경(플러그인·명령 모음 등)에서 따로
-- require되어 cache가 비어 있어도 같은 이름의 리모트를 두 번 만들지 않기 위해서다.
local function ensure(folder: Folder, name: string): ()
	if cache[name] then
		return
	end
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		cache[name] = existing
		return
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	cache[name] = remote
end

-- 서버에서 리모트를 모두 만든다. 여러 번 불러도 한 번만 만든다.
function Remotes.setupServer(): ()
	assert(RunService:IsServer(), "Remotes.setupServer는 서버에서만 부를 수 있습니다")
	local folder = getOrCreateFolder()
	for _, name in SERVER_EVENTS do
		ensure(folder, name)
	end
	for _, name in CLIENT_EVENTS do
		ensure(folder, name)
	end
end

-- 관전자가 보내도 받아 주는 리모트인가
function Remotes.isSpectatorAllowed(name: ClientEventName): boolean
	return SPECTATOR_ALLOWED[name] == true
end

-- 이름으로 RemoteEvent를 찾는다. 클라이언트에서는 서버가 만들 때까지 멈춰서 기다린다.
function Remotes.get(name: EventName): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end

	if RunService:IsServer() then
		Remotes.setupServer()
		local remote = cache[name]
		assert(remote, `알 수 없는 리모트: {name}`)
		return remote
	end

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local remote = folder:WaitForChild(name) :: RemoteEvent
	cache[name] = remote
	return remote
end

return Remotes
