--!strict
-- 서버 안에서 "소리가 났다"는 사건을 전하는 통로 (GDD 4.1 사냥개, 6.2 발전기 소리, 6.3 알람시계).
-- 소리를 내는 쪽: ObjectiveService(발전기 수리), MovementService(달리기), ItemService(알람시계, S3-4).
-- 듣는 쪽: MonsterService(사냥개 등 소리를 감지하는 괴물). 클라이언트에는 보내지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

export type Noise = {
	kind: Types.NoiseKind,
	position: Vector3,
	radius: number, -- 이 거리 안에서 들림 (괴물의 HearingRange와 둘 중 작은 값까지)
	source: Player?, -- 소리를 낸 생존자 (알람시계는 던진 사람)
}

export type Listener = (noise: Noise) -> ()

local NoiseBus = {}

local listeners: { Listener } = {}

-- 소리를 알린다. 듣는 쪽은 멈추지(yield) 않아야 한다.
function NoiseBus.emit(noise: Noise): ()
	for _, listener in listeners do
		listener(noise)
	end
end

-- 소리를 들을 함수를 등록한다. 돌려준 함수를 부르면 등록을 푼다.
function NoiseBus.subscribe(listener: Listener): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

return NoiseBus
