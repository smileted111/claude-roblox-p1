--!strict
-- 클라이언트가 쓰는 애니메이션·효과음 에셋 ID (GDD 12장). 정식 에셋이 정해지면 여기만 바꾼다.
-- 효과음이 빈 문자열이면 아직 자리만 있는 것이다 (SoundController가 아무것도 재생하지 않음).

local Types = require(script.Parent.Parent.Types)

export type AssetsConfig = {
	Animations: { [Types.AnimationKey]: string },
	Sounds: { [Types.SoundKey]: string },
}

local Assets: AssetsConfig = {
	Animations = {
		ChaserAttack = "rbxassetid://522635514", -- 임시: Roblox 기본 R15 애니메이션의 도구 휘두르기 (toolslash)
	},
	Sounds = {
		ChaserAttack = "", -- 자리만: 추격자 휘두르기
		SurvivorHit = "", -- 자리만: 생존자가 맞아 부상
		SurvivorCaught = "", -- 자리만: 잡힘 (암전과 함께)
		SurvivorHealed = "", -- 자리만: 치료받아 정상
	},
}

return Assets
