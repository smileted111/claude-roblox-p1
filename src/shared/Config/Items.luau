--!strict
-- 생존자 아이템 5종 (GDD 6.3). 아이템 칸 수는 Survivor.InventorySlots.
-- 아이템마다 쓰는 필드만 채운다. "임시"라고 적은 값은 GDD에 수치가 없어 정한 초기값이다.

local Types = require(script.Parent.Parent.Types)

export type ItemDef = {
	Duration: number?, -- 효과 지속 시간 (초)
	Radius: number?, -- 효과 반경 (스터드)
	Range: number?, -- 빛이 닿거나 던질 수 있는 거리 (스터드)
	Battery: number?, -- 켜 둘 수 있는 총 시간 (초)
	StaminaRestoreFraction: number?, -- 회복하는 스태미나 비율 (1이면 가득)
}

local Items: { [Types.ItemId]: ItemDef } = {
	-- 손전등: 그림자를 멈춤 (멈추는 시간은 Monsters.Shadow.FlashlightFreezeTime)
	Flashlight = {
		Range = 40, -- 임시
		Battery = 30, -- 임시
	},
	-- 붕대: 부상 → 정상. 수치 없음
	Bandage = {},
	-- 연막탄: 5초간 주변 시야 차단 (추격자·괴물 모두)
	SmokeBomb = {
		Duration = 5,
		Radius = 12, -- 임시
	},
	-- 알람시계: 던진 곳에 소리를 내서 괴물을 유인
	AlarmClock = {
		Range = 40, -- 임시: 던지는 거리
		Radius = 60, -- 임시: 소리가 들리는 거리
		Duration = 5, -- 임시: 울리는 시간
	},
	-- 에너지 드링크: 스태미나 즉시 회복
	EnergyDrink = {
		StaminaRestoreFraction = 1,
	},
}

return Items
