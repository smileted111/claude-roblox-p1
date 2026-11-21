--!strict
-- 캐릭터를 새로 불러오는 공통 함수 (docs/release-review.md 코드 #3).
-- LoadCharacterAsync·LoadCharacterWithHumanoidDescriptionAsync는 멈추고, 그 사이 플레이어가 나가는 등으로 실패할 수 있다.
-- pcall로 감싸 실패하면 경고만 남기고 nil을 돌려준다. 부르는 쪽은 별도 스레드(task.spawn·이벤트)에서 부른다.

local Players = game:GetService("Players")

local CharacterLoader = {}

-- 캐릭터를 불러온다. description이 있으면 그 외형으로. label은 실패 로그에 남길 상황 이름.
-- 새 캐릭터를 돌려준다. 게임에 없거나 실패하면 nil.
function CharacterLoader.load(player: Player, description: HumanoidDescription?, label: string): Model?
	if player.Parent ~= Players then
		return nil
	end
	local ok, err = pcall(function()
		if description then
			player:LoadCharacterWithHumanoidDescriptionAsync(description)
		else
			player:LoadCharacterAsync()
		end
	end)
	if not ok then
		if player.Parent == Players then
			warn(`[Character] {player.Name} 캐릭터를 불러오지 못함 ({label}): {err}`)
		end
		return nil
	end
	return player.Character
end

return CharacterLoader
