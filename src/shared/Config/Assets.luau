--!strict
-- 애니메이션·효과음·배경음악 에셋 ID (GDD 12장). 정식 에셋이 정해지면 여기만 바꾼다.
-- Animations·Sounds는 클라이언트가, MonsterAnimations는 서버(MonsterService)가 괴물 Animator로 재생한다.
-- 효과음이 빈 문자열이면 아직 자리만 있는 것이다 (SoundController가 아무것도 재생하지 않음).

local Types = require(script.Parent.Parent.Types)

-- 괴물 애니메이션. 지금은 모든 괴물이 같이 쓴다 (R15 리그 모델)
export type MonsterAnimations = {
	Idle: string,
	Walk: string,
	Attack: string,
}

-- 스테이지 배경음악 (SoundController). 스테이지 안에 있는 동안(준비 단계부터 결과까지, 관전 중 포함) 반복 재생한다.
-- 화면 모드(나이트·캐주얼)와 상관없이 같은 곡. 없는 맵은 음악 없음.
export type MusicDef = {
	SoundId: string,
	Volume: number, -- 0~1. 효과음이 묻히지 않게 낮게
}

export type AssetsConfig = {
	Animations: { [Types.AnimationKey]: string },
	MonsterAnimations: MonsterAnimations,
	Sounds: { [Types.SoundKey]: string },
	StageMusic: { [Types.StageId]: MusicDef },
	MusicFadeTime: number, -- 배경음악이 켜지고 꺼지는 데 걸리는 시간 (초)
}

local Assets: AssetsConfig = {
	Animations = {
		ChaserAttack = "rbxassetid://522635514", -- 임시: Roblox 기본 R15 애니메이션의 도구 휘두르기 (toolslash)
		VipEmote = "rbxassetid://507771019", -- 임시: Roblox 기본 R15 춤 (/e dance). VIP 로비 전용 이모트 (GDD 10장)
	},
	MonsterAnimations = {
		Idle = "rbxassetid://507766388", -- 임시: Roblox 기본 R15 서 있기
		Walk = "rbxassetid://507777826", -- 임시: Roblox 기본 R15 걷기
		Attack = "rbxassetid://522635514", -- 임시: Roblox 기본 R15 도구 휘두르기 (toolslash)
	},
	Sounds = {
		ChaserAttack = "", -- 자리만: 추격자 휘두르기
		SurvivorHit = "", -- 자리만: 생존자가 맞아 부상
		SurvivorCaught = "", -- 자리만: 잡힘 (암전과 함께)
		SurvivorHealed = "", -- 자리만: 치료받아 정상
	},
	-- 모두 APM Music의 Roblox 라이선스 음원 (Creator Store 무료). 음량은 임시. 곡 설명은 APM 원문을 옮긴 것
	StageMusic = {
		-- 학교: 재미있는 곡 (2026-11-22 사용자 요청). "The Cactus Kid" (135초, "Happy, mischievous" 경쾌한 장난기).
		-- 다른 후보: Funny Bone 1842285060 (cheerful bounce), Jolly Pranks 1842283117 (cheeky novelty)
		Stage1 = { SoundId = "rbxassetid://1842285773", Volume = 0.35 },
		-- 폐병원: 으스스한 곡 (2026-11-22 사용자 요청). "Nursery Crime" (100초, 동요를 비튼 불안한 오르골 편곡).
		-- 다른 후보: Sixth Sense 1839909248 (sustained edgy atmosphere), Frantic 1839908637 (ghostly, unnerving)
		Stage2 = { SoundId = "rbxassetid://1839909393", Volume = 0.4 },
		-- 지하 연구소: 궁금한 곡 (2026-11-22 사용자 요청). "Something Odd" (104초, "Curious and stealthy" 살금살금 호기심).
		-- 다른 후보: Open Question (a) 1839853328 (repetitive electronic motif), Tickling Tango (a) 9046170160 (sleuth-like)
		Stage3 = { SoundId = "rbxassetid://1839909042", Volume = 0.4 },
		-- 놀이공원: 즐겁고 통통 튀는 곡 (2026-11-22 사용자 요청). APM Music "Clown Parade (a)" (126초, Roblox 라이선스 음원):
		-- 클라리넷·서커스 오르간·트롬본의 유원지 곡. 다른 후보: Carousel Waltz (a) 9046170527, Circus And Clowns (a) 9046169780
		Stage4 = { SoundId = "rbxassetid://9046169357", Volume = 0.35 }, -- 음량은 임시
	},
	MusicFadeTime = 1.5, -- 임시
}

return Assets
