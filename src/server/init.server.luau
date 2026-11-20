--!strict
-- 서버 진입점: 리모트를 만든 뒤 Services 폴더의 모든 서비스를 Init → Start 순서로 실행한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleLoader = require(ReplicatedStorage.Shared.Util.ModuleLoader)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- 클라이언트 컨트롤러가 기다리는 RemoteEvent를 서비스보다 먼저 만든다.
Remotes.setupServer()

ModuleLoader.run(script.Services, "Service")
