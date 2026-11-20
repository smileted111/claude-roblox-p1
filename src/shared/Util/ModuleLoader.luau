--!strict
-- 폴더 안의 ModuleScript를 모두 불러와 Init을 전부 실행한 뒤 Start를 실행한다.
-- 서버 진입점(Services)과 클라이언트 진입점(Controllers)이 함께 쓴다.
--
-- 모듈 규칙
--   Init(): 자기 상태만 준비한다. 멈추지(yield) 않고, 다른 모듈을 호출하지 않는다.
--   Start(): 다른 모듈을 써도 된다. 계속 도는 루프는 task.spawn으로 따로 띄운다.

export type Lifecycle = {
	Init: () -> (),
	Start: () -> (),
}

type Entry = {
	name: string,
	module: Lifecycle,
}

local ModuleLoader = {}

local function collect(folder: Instance, kind: string): { Entry }
	local moduleScripts: { ModuleScript } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(moduleScripts, child)
		end
	end
	-- 실행 순서를 매번 같게 하기 위해 이름순으로 정렬한다.
	table.sort(moduleScripts, function(a: ModuleScript, b: ModuleScript): boolean
		return a.Name < b.Name
	end)

	local entries: { Entry } = {}
	for _, moduleScript in moduleScripts do
		-- 경로가 실행 중에 정해지는 require라 타입 검사기가 추적하지 못하므로 any로 받는다.
		local loaded: any = (require :: any)(moduleScript)
		if typeof(loaded) ~= "table" or typeof(loaded.Init) ~= "function" or typeof(loaded.Start) ~= "function" then
			error(`[{kind}] {moduleScript.Name}: Init()과 Start() 함수가 필요합니다`)
		end
		table.insert(entries, { name = moduleScript.Name, module = loaded :: Lifecycle })
	end
	return entries
end

-- kind는 로그 머리말이다 ("Service" 또는 "Controller").
function ModuleLoader.run(folder: Instance, kind: string): ()
	local entries = collect(folder, kind)

	for _, entry in entries do
		entry.module.Init()
	end

	for _, entry in entries do
		-- 한 모듈의 Start가 멈추거나 실패해도 다른 모듈의 Start는 진행되도록 따로 실행한다.
		task.spawn(function()
			entry.module.Start()
			print(`[{kind}] {entry.name} started`)
		end)
	end
end

return ModuleLoader
