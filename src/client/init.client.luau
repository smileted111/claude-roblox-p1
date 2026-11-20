--!strict
-- 클라이언트 진입점: Controllers 폴더의 모든 컨트롤러를 Init → Start 순서로 실행한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleLoader = require(ReplicatedStorage.Shared.Util.ModuleLoader)

ModuleLoader.run(script.Controllers, "Controller")
