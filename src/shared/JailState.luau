--!strict
-- 감옥(경찰과 도둑 모드)의 파트 이름과 Attribute를 서버(JailService)·클라이언트(Util/JailBillboards)·맵 생성
-- 스크립트(tools/mapgen/Jails.luau)가 같이 쓰게 정의한다. 감옥은 MapTags.Jail 태그가 붙은 Model이다.

local JailState = {
	-- 감옥 Model 안의 파트 (모두 투명, 부딪히지 않음)
	Inside = "Inside", -- 갇힌 사람을 이 파트 윗면 위에 세운다
	ReleasePoint = "ReleasePoint", -- 풀려난 사람을 이 파트 둘레에 세운다 (우리 밖)
	RescueZone = "RescueZone", -- 이 상자 안에 서 있는 도둑이 구출을 진행한다
	-- 감옥 Model의 Attribute (서버가 씀)
	Attribute = table.freeze({
		RescueProgress = "RescueProgress", -- 구출 진행 0~1 (Config.GameModes.Jail.ProgressPublishStep 단위)
		Prisoners = "Prisoners", -- 갇힌 사람 수
	}),
}

-- 감옥의 구출 진행 (0~1)
function JailState.getProgress(jail: Instance): number
	local value = jail:GetAttribute(JailState.Attribute.RescueProgress)
	return if typeof(value) == "number" then value else 0
end

-- 감옥에 갇힌 사람 수
function JailState.getPrisoners(jail: Instance): number
	local value = jail:GetAttribute(JailState.Attribute.Prisoners)
	return if typeof(value) == "number" then value else 0
end

return JailState
