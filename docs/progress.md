# 진행 상황

`docs/studio-workflow.md` 2장의 단계 목록이다. 단계를 끝내면 체크하고, 줄 끝에 메모를 남긴다.

## S0 준비

- [x] S0-1 프로그램 설치
- [x] S0-2 새 게임 만들고 게시 — Universe ID `10778008056`, Place ID `131560237546176`
- [x] S0-3 Studio MCP 연결
- [x] S0-4 프로젝트 골격 — Rokit으로 rojo 7.7.1, wally 0.3.2, selene 0.32.0, stylua 2.6.0 고정. 서비스 9개·컨트롤러 7개 빈 모듈, 공용 로더 `src/shared/Util/ModuleLoader.luau`. selene·stylua 통과, `rojo build` 확인. 플레이테스트는 S0-5에서.
- [x] S0-5 Rojo 연결 — `rojo plugin install`이 레지스트리 오류로 실패해 릴리스의 `Rojo.rbxm`(7.7.1)을 `%LOCALAPPDATA%\Roblox\Plugins`에 직접 설치. 플레이테스트에서 started 로그 16개(서비스 9·컨트롤러 7), 스크립트 오류 없음. `rbxassetid://203785492`(Pop Close Sound) 형식 불일치 메시지 6건은 플레이스에 없는 에셋이라 무시.

## S1 프로토타입 (M0)

- [x] S1-1 공용 데이터·리모트 — `Config/` 10개(Stages, Monsters, MonsterScaling, MonsterAI, Survivor, Chasers, Items, Match, MapObjects, RateLimits), `Types`, `Remotes`(서버→클라 6, 클라→서버 7), `Strings`, `server/Util/RateLimit`(토큰 버킷). GDD에 수치가 없는 값(스태미나, 시야 거리, 아이템 반경 등)은 `-- 임시`로 표시. 지속 상태(단계·남은 시간·역할·생존자 상태)는 Attribute로, 리모트는 한 번 일어나는 사건에만. 플레이테스트에서 서버·클라이언트 require, 데이터 일관성, 빈도 제한 동작 확인, 오류 없음. `Remotes.setupServer`가 다른 실행 환경에서 다시 불리면 리모트를 중복 생성하던 문제를 테스트 중 발견해 수정.
- [x] S1-2 테스트 맵 (블록) — `ServerStorage.Maps.Stage1`: 바닥 340×340, 벽 49개. 태그 SurvivorSpawn 8, ChaserSpawn 1·ChaserGate 1(대기실 `ChaserRoom`), MonsterSpawn 4, PatrolPoint 14(Route A 8, B 6), HideSpot 8(옷장 Model, PrimaryPart 있음), Generator 3, Exit 2, ItemSpawn 10. Lighting ClockTime 0, 약한 Ambient. 백업 `maps/Stage1.rbxm`. 같은 시기에 luau-lsp 타입 검사(`tools/typecheck.py`)를 단계 완료 절차에 추가.
- [x] S1-3 매치 루프·역할 배정 — MatchService(대기 ↔ 스테이지 반복, `CharacterAutoLoads=false`로 입장·사망·복귀 시 서버가 캐릭터 생성), StageService(역할 공개 → 준비 → 추격 → 결과, `Workspace.CurrentMap` 복제·제거, 시작 위치 배치, 대기실 문), RoleService(덜 해본 사람 우선·"추격자 안 하기", Role/SurvivorState Attribute). 공용 `MatchState`(Attribute 이름·읽기 함수), `MapTags`(태그 이름), 서버 `Util/PhaseTimer`. 매치 상태는 ReplicatedStorage Attribute(Phase, PhaseEndsAt, TimeLeft, StageId, HasChaser, SurvivorsLeft). 솔로는 역할 공개 생략(GDD 3.1). 스테이지 중 들어온 사람은 다음 스테이지까지 관전자(캐릭터 없음). 추격자 횟수는 서버에 있는 동안 유지 — S2-1에서 매치 시작 때 `resetChaserCounts()`. 1인 플레이테스트: 시간 종료·전원 잡힘(Attribute로 흉내) 두 경로, 추격 중 사망 후 SurvivorSpawn 재생성, 문 열림, 클라이언트에서 Attribute 읽기 확인, 오류 없음. 추격자 선정 규칙은 Edit 모드에서 가짜 플레이어로 검증. 3인 테스트는 사용자 확인 대기.
- [x] S1-4 생존자 이동·달리기·숨기 — 서버 서비스 2개 추가(GDD 13.2 목록 밖): MovementService(속도·스태미나. 생존자 걷기 16/달리기 24, 부상 ×0.9, 숨으면 0, 추격자는 `Config.Match.DefaultChaser`(임시 Hunter)의 20. 달리기 의사 + `MoveDirection`일 때만 소모, Player Attribute `Stamina`·`Running`), HideService(숨는 곳마다 PrimaryPart 앞 Attachment에 프롬프트 3개 숨기/나오기/열어보기. 숨으면 안쪽 바닥에 Anchored·투명·이름표 끔, 나오면 앞(LookVector)에 섬. `Hidden`(Player)·`OccupantUserId`/`Breathing`/`Revealed`(숨는 곳) Attribute, 강조 표시는 Highlight). 공용 `HideSpotState`, 클라이언트 `Util/HideSpotWatcher`. 프롬프트는 서버에서 모두 켜 두고 SurvivorController·ChaserController가 역할에 맞는 것만 로컬에서 켬. 달리기는 ContextActionService(Shift·L3·모바일 화면 버튼, 임시), Shift와 겹치는 시프트 락은 `default.project.json`에서 `EnableMouseLockOption=false`. 스태미나 바는 임시(S1-8에서 UIController로). 열어보기 1초는 서버가 `PromptButtonHoldBegan`~`Triggered` 시간으로 다시 검사(서버에서 두 이벤트가 오는 것을 플레이테스트로 확인). 임시값: 프롬프트 거리 8, 들킨 뒤 재숨기 3초 등 `Config.MapObjects.HideSpot`. 1인 플레이테스트: 달리기 24·소모 20/초·바닥나면 16·1초 뒤 회복 10/초, 부상 14.4/21.6, E로 숨기·나오기, 20초 숨소리, 결과 단계에서 숨기 거절, 숨은 채 잡힘 처리 시 풀려남, 맵 정리, 오류 없음. 추격자 열어보기·강조 표시는 3인 테스트로 사용자 확인 대기.
- [x] S1-5 추격자 공격·잡힘 판정 — CatchService: 추격자 공격(`ChaserAttack`)은 빈도 제한 → 역할 → 단계(추격) → 쿨다운 1.5초(여유 0.1초) 검사 후, 바라보는 쪽 120°·거리 6(+여유 2) 안에서 벽(레이캐스트, CanCollide 파트만) 너머가 아닌 가장 가까운 생존자 1명을 맞힘. `CatchService.hit(survivor, source, instantCatch?)`는 괴물(S1-6)·거인(S3-4)도 씀. 정상 → 부상 → 잡힘, 맞은 뒤 1초 무적, 숨은 생존자·추격 단계 밖은 맞지 않음. 잡히면 Role=Spectator, `Notice SurvivorCaught`, 캐릭터를 고정했다가 0.3초(암전되는 시간) 뒤 제거. 치료: 부상 생존자의 HumanoidRootPart에 "치료" 프롬프트(4초 유지, 태그 `HealPrompt`, 숨으면 지움). 서버가 누른 시간·거리·벽·단계·역할을 다시 검사하고, 누르는 동안 둘 중 누가 맞으면 무효. 클라이언트: ChaserController(클릭·화면 탭·R2, 로컬 쿨다운, Roblox 기본 R15 toolslash 애니메이션 임시), SurvivorController(남의 치료 프롬프트만 켬, 부상 시 흰 번쩍임, 잡힘 시 암전 2초), `Util/ScreenEffect`, SoundController.play(효과음 ID는 빈 자리). 새 파일: `CatchState`, `Config/Catch`(임시값 모음), `Config/Assets`, `Util/CharacterParts`(HideService의 캐릭터 찾기를 옮겨 함께 씀). `Config.Chasers`에 `AttackAngle` 추가. 1인 플레이테스트: 서버에서 hit 호출로 부상(속도 14.4)·무적 중 거절·치료 프롬프트 생성(자기 화면에선 꺼짐)·숨으면 제거·잡힘 후 캐릭터 제거·암전·스테이지 조기 종료, 추격자 강제 설정으로 클릭 → 애니메이션 재생·서버 "빗나감"·서버 쿨다운 거절 확인, 오류 없음. 실제 명중·치료는 3인 테스트로 사용자 확인 대기.
- [x] (추가) 스테이지별 조명 — `docs/studio-workflow.md` 단계 목록에 없는 작업. 게시한 게임이 거의 검게만 보이던 문제: S1-2에서 정한 Lighting(ClockTime 0, 약한 Ambient)이 대기 장소에도 적용되고 맵에 광원이 0개. `Config/Lighting`(형식 `LightingPreset`, 대기 장소 값 `Lobby`: 늦은 오후 ClockTime 16.5), `Config.Stages[id].Lighting`(ClockTime·Brightness·Ambient·OutdoorAmbient·ExposureCompensation·Atmosphere). StageService가 서버 시작·스테이지 종료(`finish`) 때 대기 장소 조명, 맵을 불러올 때 스테이지 조명을 적용. 값은 모두 임시: Stage1만 플레이테스트 화면을 보고 맞춤(Ambient 70,70,85 / OutdoorAmbient 90,95,115), Stage2~5는 S2-1에서 맵을 만들 때 다시 맞춤. 플레이스에 저장된 Lighting(ClockTime 0)은 Studio 편집 화면용으로 그대로 둠. 비상등 등 광원 배치는 S3-8, 손전등은 S3-4. 1인 플레이테스트: 대기 장소 → Stage1 → (전원 잡힘) 대기 장소 → Stage1 전환과 두 화면 확인, 오류 없음.
- [ ] S1-6 괴물 AI (배회자)
- [ ] S1-7 관전 모드
- [ ] S1-8 기본 HUD
- [ ] S1-9 M0 플레이테스트

## S2 한 매치 완성 (M1)

- [ ] S2-1 스테이지 3개 연속·추격자 교체
- [ ] S2-2 발전기·출구
- [ ] S2-3 괴물 사냥개·감시자
- [ ] S2-4 아이템 3종·판자·문
- [ ] S2-5 결과 화면
- [ ] S2-6 M1 플레이테스트

## S3 출시 준비 (M2)

- [ ] S3-1 데이터 저장
- [ ] S3-2 로비 (같이 하기·혼자 하기)
- [ ] S3-3 추격자 4종 스킬
- [ ] S3-4 괴물 그림자·거인
- [ ] S3-5 모바일·콘솔 조작
- [ ] S3-6 상점·게임패스
- [ ] S3-7 한국어·영어 현지화
- [ ] S3-8 정식 맵
- [ ] S3-9 출시 체크리스트
