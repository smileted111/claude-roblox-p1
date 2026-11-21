--!strict
-- 현지화: 키 기반 문구 표와 언어 고르기 (GDD 11장 "한국어 + 영어", S3-7).
--
-- 문구 원본: ko.luau (한국어, 키와 타입을 정함), en.luau (영어, ko와 같은 타입이라 빠지거나 남는 키는 타입 검사가 잡는다).
--   키 = 표 안의 경로 (예: "Hud.Run", "Notices.ExitOpened"). 코드는 Strings 모듈로 지금 언어의 표를 쓴다.
-- LocalizationTable: 서버 LanguageService가 이 표로 LocalizationService.GameText를 만든다
--   (Key = 경로, Source = 한국어, 열 ko·en). Roblox 자동 번역(AutoLocalize)과 Translator가 이 표를 쓰고,
--   Studio의 현지화 도구로 내보낼 수 있다. 문구를 고칠 때는 ko.luau·en.luau만 고친다.
-- 언어: 클라이언트는 LocalizationService.RobloxLocaleId (Roblox 언어 설정, Studio 플레이어 에뮬레이터의 로캘),
--   서버는 원본(한국어, 로그용)이고 플레이어에게 보낼 글자는 Player.LocaleId(languageFor)로 고른다.
--   한국어(ko-*)가 아니면 영어. Studio에서는 ReplicatedStorage 속성 StudioLanguage("ko"/"en")가 우선한다 (시험용).
-- 원문 → 번역 (fromSource): 서버가 한국어 원문으로 만든 프롬프트·표지판 글자를 클라이언트가 바꿀 때 쓴다.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local En = require(script.en)
local Ko = require(script.ko)

export type Language = "ko" | "en"
export type Text = Ko.Text
type Flat = { [string]: string }

local TABLES: { [Language]: Text } = { ko = Ko, en = En }
local LANGUAGES: { Language } = { "ko", "en" }
local SOURCE_LANGUAGE: Language = "ko"
local STUDIO_OVERRIDE_ATTRIBUTE = "StudioLanguage"
-- 같은 한국어가 여러 키에 있으면 원문 → 번역에서 이 묶음을 먼저 쓴다 (서버가 만드는 프롬프트·표지판 글자)
local SOURCE_PRIORITY: { string } = { "Prompts", "Items", "Lobby", "Hud" }
local FORMAT_PATTERN = "%%[%-%+ #0]*%d*%.?%d*[%a%%]" -- string.format 서식 지정자

local Localization = {}

local flatCache: { [Language]: Flat } = {}
local sourceIndex: { [string]: string }? = nil -- 한국어 원문 → 키

local function studioOverride(): Language?
	if RunService:IsStudio() then
		local forced = ReplicatedStorage:GetAttribute(STUDIO_OVERRIDE_ATTRIBUTE)
		if forced == "ko" or forced == "en" then
			return forced
		end
	end
	return nil
end

-- 로캘 ID(예: "ko-kr", "en-us") → 보여줄 언어. 한국어가 아니면 영어.
function Localization.languageOf(localeId: string): Language
	local prefix = string.lower(string.match(localeId, "^%a+") or "")
	return if prefix == "ko" then "ko" else "en"
end

-- 이 기기에서 보여줄 언어. 서버는 원본 한국어 (서버가 만드는 프롬프트·표지판은 원문이고 클라이언트가 바꾼다)
function Localization.currentLanguage(): Language
	if RunService:IsClient() then
		return studioOverride() or Localization.languageOf(LocalizationService.RobloxLocaleId)
	end
	return SOURCE_LANGUAGE
end

-- 서버가 이 플레이어에게 보낼 글자의 언어
function Localization.languageFor(player: Player): Language
	return studioOverride() or Localization.languageOf(player.LocaleId)
end

function Localization.text(language: Language): Text
	return TABLES[language]
end

local function flatten(node: { [any]: any }, prefix: string, out: Flat): ()
	for key, value in node do
		local path = if prefix == "" then tostring(key) else `{prefix}.{key}`
		if typeof(value) == "table" then
			flatten(value, path, out)
		elseif typeof(value) == "string" then
			out[path] = value
		end
	end
end

-- 키(경로) → 문구
function Localization.flat(language: Language): Flat
	local cached = flatCache[language]
	if not cached then
		local flat: Flat = {}
		flatten(TABLES[language] :: any, "", flat)
		flatCache[language] = flat
		cached = flat
	end
	return cached
end

local function sortedKeys(): { string }
	local keys: { string } = {}
	for key in Localization.flat(SOURCE_LANGUAGE) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- 모든 키 (이름순)
function Localization.keys(): { string }
	return sortedKeys()
end

local function priorityOf(key: string): number
	local group = string.match(key, "^[^%.]+") or ""
	return table.find(SOURCE_PRIORITY, group) or #SOURCE_PRIORITY + 1
end

-- 한국어 원문 → 키 (처음 쓸 때 만든다)
local function getSourceIndex(): { [string]: string }
	local existing = sourceIndex
	if existing then
		return existing
	end
	local built: { [string]: string } = {}
	local keys = sortedKeys()
	table.sort(keys, function(a: string, b: string): boolean
		local pa, pb = priorityOf(a), priorityOf(b)
		if pa ~= pb then
			return pa < pb
		end
		return a < b
	end)
	local source = Localization.flat(SOURCE_LANGUAGE)
	for _, key in keys do
		local original = source[key]
		if built[original] == nil then
			built[original] = key
		end
	end
	sourceIndex = built
	return built
end

-- 한국어 원문을 language 문구로 바꾼다. 표에 없는 글자는 그대로 돌려준다.
function Localization.fromSource(text: string, language: Language): string
	if language == SOURCE_LANGUAGE or text == "" then
		return text
	end
	local key = getSourceIndex()[text]
	return if key then Localization.flat(language)[key] or text else text
end

-- 이 표로 LocalizationTable을 만든다 (Key = 경로, Source = 한국어, 언어별 열).
function Localization.buildTable(name: string): LocalizationTable
	local localizationTable = Instance.new("LocalizationTable")
	localizationTable.Name = name
	localizationTable.SourceLocaleId = SOURCE_LANGUAGE
	local source = Localization.flat(SOURCE_LANGUAGE)
	local entries = {}
	for _, key in sortedKeys() do
		local values: { [string]: string } = {}
		for _, language in LANGUAGES do
			values[language] = Localization.flat(language)[key]
		end
		table.insert(entries, { Key = key, Source = source[key], Context = "", Example = "", Values = values })
	end
	localizationTable:SetEntries(entries)
	return localizationTable
end

local function formatsOf(text: string): string
	local found: { string } = {}
	for specifier in string.gmatch(text, FORMAT_PATTERN) do
		table.insert(found, specifier)
	end
	return table.concat(found, " ")
end

-- 서식 지정자(%d·%s·%% 등)가 한국어 원문과 다른 번역 ("en Hud.Run: ..." 목록). 비어 있으면 문제 없음.
function Localization.formatMismatches(): { string }
	local problems: { string } = {}
	local source = Localization.flat(SOURCE_LANGUAGE)
	for _, language in LANGUAGES do
		if language ~= SOURCE_LANGUAGE then
			local translated = Localization.flat(language)
			for _, key in sortedKeys() do
				local expected = formatsOf(source[key])
				local actual = formatsOf(translated[key] or "")
				if expected ~= actual then
					table.insert(problems, `{language} {key}: "{actual}" (원문 "{expected}")`)
				end
			end
		end
	end
	return problems
end

return Localization
