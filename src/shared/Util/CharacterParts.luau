--!strict
-- 플레이어의 살아 있는 캐릭터와 그 Humanoid·HumanoidRootPart를 찾는다. 서버와 클라이언트가 함께 쓴다.

local Workspace = game:GetService("Workspace")

export type CharacterParts = {
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
}

local CharacterParts = {}

-- 캐릭터가 Workspace에 있고, Humanoid가 살아 있고, HumanoidRootPart가 있으면 돌려준다. 아니면 nil.
function CharacterParts.get(player: Player): CharacterParts?
	local character = player.Character
	if not character or not character:IsDescendantOf(Workspace) then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end
	return { character = character, humanoid = humanoid, rootPart = rootPart }
end

return CharacterParts
