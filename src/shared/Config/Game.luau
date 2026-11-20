--!strict
-- 게임 식별 정보 (GDD 13.1). Creator Hub에 표시된 값과 같아야 한다.

export type GameConfig = {
	UniverseId: number,
	PlaceId: number,
}

local Game: GameConfig = {
	UniverseId = 10778008056,
	PlaceId = 131560237546176,
}

return Game
