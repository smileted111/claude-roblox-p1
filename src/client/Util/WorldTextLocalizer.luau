--!strict
-- 서버나 플레이스가 한국어 원문으로 만든 글자를 이 기기 언어로 바꾼다 (S3-7). 한국어 기기에서는 아무것도 하지 않는다.
--   ProximityPrompt의 ActionText·ObjectText: 서버가 만든 숨기·수리·치료·줍기(아이템 이름)·판자·문·혼자 하기.
--     서버가 글자를 바꾸면(문 열기 ↔ 닫기) 다시 바꾼다.
--   Workspace의 SurfaceGui·BillboardGui 글자: Studio에서 만든 로비 표지판, 서버가 만든 출구 표지.
-- 원문 → 번역은 Localization.fromSource (원문이 ko.luau에 있어야 한다). Roblox 자동 번역(AutoLocalize)도 같은 표를
-- 쓰지만, 한국어·영어가 아닌 언어(영어로 보여줌)와 Studio 시험(StudioLanguage)까지 맞추려고 직접 바꾼다.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage.Shared.Localization)

local WorldTextLocalizer = {}

local language: Localization.Language = Localization.currentLanguage()

local function translate(instance: Instance, property: string): ()
	local current = (instance :: any)[property]
	if typeof(current) ~= "string" then
		return
	end
	local translated = Localization.fromSource(current, language)
	if translated ~= current then
		(instance :: any)[property] = translated
	end
end

local function watch(instance: Instance, property: string): ()
	translate(instance, property)
	instance:GetPropertyChangedSignal(property):Connect(function()
		translate(instance, property)
	end)
end

local function isWorldGuiText(instance: Instance): boolean
	if not (instance:IsA("TextLabel") or instance:IsA("TextButton")) then
		return false
	end
	return instance:FindFirstAncestorWhichIsA("SurfaceGui") ~= nil
		or instance:FindFirstAncestorWhichIsA("BillboardGui") ~= nil
end

local function onDescendant(instance: Instance): ()
	if instance:IsA("ProximityPrompt") then
		watch(instance, "ActionText")
		watch(instance, "ObjectText")
	elseif isWorldGuiText(instance) then
		watch(instance, "Text")
	end
end

function WorldTextLocalizer.start(): ()
	if language == "ko" then
		return
	end
	Workspace.DescendantAdded:Connect(onDescendant)
	for _, instance in Workspace:GetDescendants() do
		onDescendant(instance)
	end
end

return WorldTextLocalizer
