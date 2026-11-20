--!strict
-- 클라이언트에 복제된 숨는 곳(HideSpot 태그 Model)을 지켜보다가, 숨는 곳이 생기거나 없어지거나
-- Attribute(HideSpotState)가 바뀌거나 ProximityPrompt가 새로 들어오면(StreamingEnabled로 다시 받을 때 포함) 등록한 함수를 부른다.
--
-- 서버(HideService)는 프롬프트를 모두 켠 채로 만든다. 각 컨트롤러가 이 신호를 받아 자기 프롬프트만 로컬에서 켜고 끈다.
--   SurvivorController: 숨기·나오기 / ChaserController: 열어보기

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapTags = require(ReplicatedStorage.Shared.MapTags)

local HideSpotWatcher = {}

local listeners: { () -> () } = {}
local tracked: { [Model]: { RBXScriptConnection } } = {}
local started = false

local function notify(): ()
	for _, listener in listeners do
		listener()
	end
end

local function track(instance: Instance): ()
	if not instance:IsA("Model") or tracked[instance] or not instance:IsDescendantOf(Workspace) then
		return
	end
	tracked[instance] = {
		instance.AttributeChanged:Connect(notify),
		instance.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("ProximityPrompt") then
				notify()
			end
		end),
	}
	notify()
end

local function untrack(instance: Instance): ()
	if not instance:IsA("Model") then
		return
	end
	local connections = tracked[instance]
	if not connections then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	tracked[instance] = nil
	notify()
end

-- 숨는 곳에 변화가 있을 때마다 listener를 부른다. 등록하자마자 한 번 부른다.
function HideSpotWatcher.subscribe(listener: () -> ()): ()
	table.insert(listeners, listener)
	if not started then
		started = true
		CollectionService:GetInstanceAddedSignal(MapTags.HideSpot):Connect(track)
		CollectionService:GetInstanceRemovedSignal(MapTags.HideSpot):Connect(untrack)
		for _, instance in CollectionService:GetTagged(MapTags.HideSpot) do
			track(instance)
		end
	end
	listener()
end

-- 지금 클라이언트에 있는 숨는 곳
function HideSpotWatcher.getSpots(): { Model }
	local spots: { Model } = {}
	for spot in tracked do
		table.insert(spots, spot)
	end
	return spots
end

-- 숨는 곳의 프롬프트 (HideSpotState.Prompt의 이름). 아직 복제되지 않았으면 nil.
function HideSpotWatcher.findPrompt(spot: Model, name: string): ProximityPrompt?
	local prompt = spot:FindFirstChild(name, true)
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt
	end
	return nil
end

return HideSpotWatcher
