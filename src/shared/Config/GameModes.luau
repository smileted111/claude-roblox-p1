--!strict
-- 게임 모드 (2026-11-22 사용자 요청, GDD 2.2·3.1.1). 같이 하기(추격자가 있는 스테이지)에서 스테이지마다 맵과 같은 방식으로
-- 투표한다 (VoteService: 표 수·얼굴 실시간, 같은 표면 그중 무작위). 참가자 수가 MinPlayers보다 적은 모드는 투표에 나오지 않고,
-- 투표 뒤 인원이 줄어 모자라면 그 스테이지는 Default로 한다 (StageService). 혼자 하기에는 투표 칸이 없고 서바이벌 규칙(괴물만)이다.
--   Survival        서바이벌: 부상 상태로 맞으면 쓰러지고 동료가 붕대로 살린다 (Config.Catch.Revive)
--   CopsAndRobbers  경찰과 도둑: 추격자 = 경찰, 생존자 = 도둑. 부상 상태로 맞으면 맵의 감옥(Jail 태그 Model)에 갇힌다.
--                   다른 도둑이 감옥 둘레 구출 구역(RescueZone)에 RescueTime초 동안 계속 서 있으면 갇힌 도둑이 모두 풀려난다
--                   (server JailService).
--   FreezeTag       얼음땡: 생존자가 "얼음" 버튼으로 스스로 얼면 움직이지 못하고 술래도 잡지 못한다. 다른 생존자가 가까이에서 "땡"
--                   버튼을 누르면 풀려 얼기 전 상태로 돌아가고 다시 잡힐 수 있다. 혼자서는 풀 수 없다. 서 있는 생존자가 모두 없어지면
--                   (모두 얼거나 잡힘) 술래 승리. 부상 상태로 맞으면 바로 잡힘 (쓰러짐·감옥 없음). (server FreezeService)

local Types = require(script.Parent.Parent.Types)

export type JailConfig = {
	RescueTime: number, -- 구출 구역에 계속 서 있어야 하는 시간 (초). 아무도 없으면 처음부터
	ReleaseProtectTime: number, -- 풀려난 직후 다시 맞지 않는 시간 (초)
	TickInterval: number, -- 구출 진행을 확인하는 간격 (초)
	ProgressPublishStep: number, -- 구출 진행 Attribute를 이 단위로 반올림해 공개 (0~1)
	ReleaseSpread: number, -- 풀려난 사람을 ReleasePoint 둘레로 흩어 세우는 거리 (스터드)
	BillboardMaxDistance: number, -- 감옥 위 표시가 보이는 거리 (스터드)
}

export type FreezeTagConfig = {
	ThawDistance: number, -- 땡이 닿는 거리 (스터드, 두 사람 HumanoidRootPart 사이)
	DistanceSlack: number, -- 서버 거리 검사의 여유 (스터드)
	RefreezeCooldown: number, -- 땡으로 풀린 뒤 다시 얼 수 있기까지 (초). 그동안 술래가 잡을 수 있다
	IceColor: Color3, -- 언 사람을 감싸는 얼음 덩어리 색
	IceTransparency: number, -- 0~1
	IcePadding: number, -- 얼음 덩어리가 캐릭터보다 큰 정도 (스터드)
}

export type GameModesConfig = {
	Modes: { Types.GameMode }, -- 투표 칸 순서
	Default: Types.GameMode, -- 투표가 없거나 고른 모드를 할 수 없을 때
	MinPlayers: { [Types.GameMode]: number }, -- 이 모드를 투표에 내고 플레이하는 최소 참가자 수
	Jail: JailConfig,
	FreezeTag: FreezeTagConfig,
}

local GameModes: GameModesConfig = {
	Modes = { "Survival", "CopsAndRobbers", "FreezeTag" },
	Default = "Survival",
	MinPlayers = {
		Survival = 2,
		CopsAndRobbers = 2,
		FreezeTag = 3, -- 2026-11-22 사용자 요청: 2명(술래 1 + 1명)이면 땡해 줄 사람이 없어 투표에도 안 나옴
	},
	Jail = {
		RescueTime = 5, -- 2026-11-22 사용자 요청
		ReleaseProtectTime = 2, -- 임시
		TickInterval = 0.1, -- 임시
		ProgressPublishStep = 0.05, -- 임시
		ReleaseSpread = 1.5, -- 임시: 풀려나는 자리(4x4) 안에 들어가게
		BillboardMaxDistance = 120, -- 임시
	},
	FreezeTag = {
		ThawDistance = 8, -- 임시: 치료 프롬프트 거리와 같게
		DistanceSlack = 4, -- 임시
		RefreezeCooldown = 5, -- 임시
		IceColor = Color3.fromRGB(150, 220, 255), -- 임시
		IceTransparency = 0.45, -- 임시
		IcePadding = 1, -- 임시
	},
}

return GameModes
