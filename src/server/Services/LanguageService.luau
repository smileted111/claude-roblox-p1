--!strict
-- LanguageService: 현지화 표를 LocalizationTable로 올리고, 서버 글자를 플레이어 언어로 고른다 (GDD 11장, S3-7).
-- GDD 13.2 목록 밖에 추가한 서비스. 문구 원본과 언어 규칙은 ReplicatedStorage.Shared.Localization.
--
-- Init: Localization 표(ko·en)로 LocalizationService.GameText(LocalizationTable, Key = 경로, Source = 한국어)를
--   코드에서 만든다. 클라이언트에 복제되어 Roblox 자동 번역(AutoLocalize)이 플레이스·서버가 만든 글자에도 쓰인다.
--   Studio에서는 번역의 서식 지정자(%d·%s)가 원문과 다르면 경고한다.
-- stringsFor(player): 서버가 그 플레이어에게 직접 보여줄 글자(Kick 메시지, 알림의 인자)를 고를 때 쓴다.
--   프롬프트·표지판처럼 서버가 한국어 원문으로 만든 글자는 클라이언트(Util/WorldTextLocalizer)가 바꾼다.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Localization = require(ReplicatedStorage.Shared.Localization)

local TABLE_NAME = "GameText"

local LanguageService = {}

-- 이 플레이어의 언어로 된 문구 표
function LanguageService.stringsFor(player: Player): Localization.Text
	return Localization.text(Localization.languageFor(player))
end

function LanguageService.Init(): ()
	local existing = LocalizationService:FindFirstChild(TABLE_NAME)
	if existing then
		existing:Destroy()
	end
	Localization.buildTable(TABLE_NAME).Parent = LocalizationService
	if RunService:IsStudio() then
		for _, problem in Localization.formatMismatches() do
			warn(`[Language] 번역의 서식 지정자가 원문과 다릅니다: {problem}`)
		end
	end
end

function LanguageService.Start(): ()
	print(`[Language] {TABLE_NAME} 현지화 표 준비 ({#Localization.keys()}개 키, ko·en)`)
end

return LanguageService
