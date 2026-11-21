--!strict
-- 게임에 처음 들어올 때의 로딩 화면 (ReplicatedFirst.Loading, 2026-11-21 사용자 요청).
-- Roblox 기본 로딩 화면을 지우고 LoadingScreen을 바로 띄운 뒤, 게임을 다 받고(game.Loaded) 내 캐릭터·HUD(클라이언트
-- 컨트롤러가 만듦)·저장 데이터(DataLoaded)가 준비되면 닫는다 (JOIN_TIMEOUT초가 지나면 그냥 닫음).
-- 글자는 공용 모듈(ReplicatedStorage.Shared)이 오면 Localization의 Loading에서 채운다 (그 전에는 애니메이션만).
-- ReplicatedFirst는 공용 Config보다 먼저 돌아서 시간 값은 이 파일 상수로 둔다.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

script:WaitForChild("LoadingScreen")
local LoadingScreen = require(script.LoadingScreen)

local JOIN_TIMEOUT = 25 -- 준비를 기다리는 최대 시간 (초)
local MIN_VISIBLE = 1 -- 최소로 보여주는 시간 (초)

ReplicatedFirst:RemoveDefaultLoadingScreen()
LoadingScreen.show("", true)

task.spawn(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", JOIN_TIMEOUT)
	local stringsModule = shared and shared:WaitForChild("Strings", JOIN_TIMEOUT)
	if stringsModule and stringsModule:IsA("ModuleScript") then
		local Strings: any = (require :: any)(stringsModule)
		LoadingScreen.setTexts(Strings.Loading.Title, Strings.Loading.Tips)
		LoadingScreen.setStatus(Strings.Loading.Joining)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local player = Players.LocalPlayer
local deadline = os.clock() + JOIN_TIMEOUT
local function ready(): boolean
	local playerGui = player:FindFirstChild("PlayerGui")
	return player.Character ~= nil
		and player:GetAttribute("DataLoaded") == true
		and playerGui ~= nil
		and playerGui:FindFirstChild("Hud") ~= nil
end
while not ready() and os.clock() < deadline do
	task.wait(0.2)
end
LoadingScreen.hide(MIN_VISIBLE)
