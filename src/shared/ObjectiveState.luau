--!strict
-- 목표 장치(발전기)와 출구의 프롬프트 이름·태그, 공개 Attribute, 수리가 되는 단계를 정의한다 (GDD 3.2, 6.2).
-- 쓰기는 서버 ObjectiveService만 한다. 매치 전체 진행(GeneratorsDone 등)과 플레이어의 RepairProgress는 MatchState에 있다.
--
-- 발전기(Generator 태그 Part 또는 Model)의 Attribute
--   Progress   number   수리 진행 0~1 (Config.MapObjects.Generator.ProgressPublishStep 단위로 공개)
--   Repaired   boolean? 다 고침
--   Repairers  number?  지금 고치는 사람 수
-- 출구(Exit 태그 Part)의 Attribute
--   Open       boolean? 열림 (발전기를 모두 고치면 Config.MapObjects.Exit.OpenCount곳)
--
-- 수리 프롬프트: 발전기 윗면의 Attachment(PromptAttachmentName) 아래에 서버가 만들고 태그(RepairPromptTag)를 붙인다.
-- 누르고 있는 동안(Triggered ~ TriggerEnded) 고친다. 서버에서는 켜 두고, 클라이언트가 생존자일 때만 로컬에서 켠다.

local Types = require(script.Parent.Types)

local ObjectiveState = {
	RepairPromptName = "RepairPrompt",
	RepairPromptTag = "RepairPrompt",
	PromptAttachmentName = "RepairAttachment",
	ExitMarkerName = "ExitMarker",
	Attribute = table.freeze({
		Progress = "Progress",
		Repaired = "Repaired",
		Repairers = "Repairers",
		Open = "Open",
	}),
}

-- 발전기를 고칠 수 있는 단계: 추격 (준비 중에는 흩어져 숨을 곳을 찾는다)
function ObjectiveState.canRepairInPhase(phase: Types.MatchPhase): boolean
	return phase == "Chase"
end

-- 발전기 몸체 (Part면 그대로, Model이면 PrimaryPart 또는 첫 BasePart)
function ObjectiveState.getBody(generator: Instance): BasePart?
	if generator:IsA("BasePart") then
		return generator
	end
	if generator:IsA("Model") then
		return generator.PrimaryPart or generator:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function ObjectiveState.getProgress(generator: Instance): number
	local value = generator:GetAttribute(ObjectiveState.Attribute.Progress)
	return if typeof(value) == "number" then value else 0
end

function ObjectiveState.isRepaired(generator: Instance): boolean
	return generator:GetAttribute(ObjectiveState.Attribute.Repaired) == true
end

return ObjectiveState
