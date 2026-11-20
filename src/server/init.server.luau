--!strict
-- 서버 진입점: Services 폴더의 모든 서비스를 Init → Start 순서로 실행한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleLoader = require(ReplicatedStorage.Shared.Util.ModuleLoader)

ModuleLoader.run(script.Services, "Service")
