# 라스트 서바이벌 — Claude 작업 규칙

Roblox 비대칭 추격 생존 게임. 기획의 기준은 `docs/GDD.md`, 확정·추천 답변은 `docs/questionnaire.md`, 작업 순서는 `docs/studio-workflow.md`다.
기획서와 다르게 구현해야 할 이유가 생기면 구현 전에 먼저 물어본다.

## 작업 환경

- Claude Code는 사용자 PC의 이 저장소 폴더에서 실행되며, Roblox Studio 내장 MCP 서버에 연결되어 있다.
- **코드**는 `src/`의 `.luau` 파일로 작성하고 Rojo로 Studio에 동기화한다. Studio 안에 스크립트를 직접 만들지 않는다.
- **맵·파트·조명·태그처럼 플레이스에 저장되는 것**은 Studio MCP로 만든다. 만든 뒤 사용자에게 Studio에서 저장(Ctrl+S)하라고 알린다.
- 도구: Rokit(도구 버전 고정), Rojo, Wally, Selene, StyLua, luau-lsp(타입 검사).

## Rojo 매핑

| 저장소 | Studio |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `Packages` (Wally) | `ReplicatedStorage.Packages` |
| `ServerPackages` (Wally 서버 전용, 예: ProfileStore) | `ServerScriptService.ServerPackages` |

- `ServerStorage`, `Workspace`, `Lighting`, `StarterGui`는 Rojo가 관리하지 않는다. Studio에서 만든 맵이 Rojo 동기화로 지워지지 않게 하기 위해서다.
- 스테이지 맵은 `ServerStorage.Maps.<StageId>` (예: `ServerStorage.Maps.Stage1`) 폴더에 둔다.
- 로비는 `Workspace.Lobby` (스폰·같이 하기·혼자 하기 발판). 스테이지 맵과 겹치지 않게 z 460~540에 있다.

## 맵 규칙 (CollectionService 태그)

| 태그 | 대상 |
|---|---|
| `SurvivorSpawn` | 생존자 시작 위치 (Part) |
| `ChaserSpawn` | 추격자 대기실 안 시작 위치 |
| `ChaserGate` | 준비 시간이 끝나면 열리는 대기실 문 |
| `MonsterSpawn` | 괴물 생성 위치 (Attribute `Monster`: 그 종류를 먼저 놓을 자리, 선택. 파트 앞면이 괴물이 보는 방향) |
| `PatrolPoint` | 괴물 순찰 지점 (Attribute `Route`: 경로 이름, `Order`: 순서) |
| `HideSpot` | 숨는 곳 (Model, PrimaryPart 필요. PrimaryPart 앞면(LookVector)이 열린 쪽 — 프롬프트가 생기고 나온 생존자가 서는 곳) |
| `Generator` | 목표 장치 |
| `Exit` | 출구 (Attribute `ExitId`) |
| `ItemSpawn` | 아이템 생성 위치 |
| `Plank` / `Door` | 환경 장치. 판자 Model = `Board`(세워 둔 판자) + `FallenPose`(넘어진 자리, 투명). 문 Model = `Panel`(닫힌 문짝) + `OpenPose`(열린 자리, 투명) |
| `DarkZone` | 어두운 구역 (투명·충돌 없음 상자. 그림자 괴물용) |
| `LobbyTogether` / `LobbySolo` | 로비(`Workspace.Lobby`)의 같이 하기 구역 발판 / 혼자 하기 발판 |

- 맵 생성 스크립트: `tools/mapgen/` (Stage2·3 블록 맵을 다시 만들 때 `common.luau` 뒤에 스테이지 파일을 붙여 Studio MCP로 실행).

## 코드 규칙

- 모든 파일 첫 줄에 `--!strict`. 타입을 명시한다.
- 서버: `src/server/Services/<Name>Service.luau`, 클라이언트: `src/client/Controllers/<Name>Controller.luau`. 각 모듈은 `Init()`과 `Start()`를 가진다. 진입점이 모든 모듈의 `Init`을 먼저 실행한 다음 `Start`를 실행한다.
- 괴물 종류별 동작은 `src/server/Monsters/<Name>.luau` (`MonsterTypes.Behavior`), 공통 부분은 MonsterService.
- 서버 권한: 피격·잡힘·아이템·목표 진행·역할은 서버만 결정한다. 클라이언트 요청은 거리·쿨다운·상태를 검사하고, 원격 호출에는 빈도 제한을 둔다.
- RemoteEvent/RemoteFunction은 `src/shared/Remotes.luau` 한 곳에서 정의한다.
- 수치(속도, 시간, 괴물 수 등)는 코드에 직접 쓰지 않고 `src/shared/Config/`의 데이터 테이블에 둔다. 값은 GDD에 적힌 초기값을 쓴다.
- 플레이어에게 보이는 문구는 `src/shared/Strings.luau`에 한국어로 모은다 (나중에 현지화 테이블로 옮김).
- 피·신체 훼손 표현을 넣지 않는다 (GDD 12장).

## 단계 완료 절차

프롬프트가 "단계 완료 절차"를 요청하면 아래 순서대로 한다.

1. `selene src`, `stylua --check src`, `python tools/typecheck.py`(luau-lsp 타입 검사)를 실행하고 문제를 고친다.
2. Studio MCP로 플레이테스트를 시작해 출력 창의 오류·경고를 확인하고, 오류가 있으면 고친 뒤 다시 테스트한다. 끝나면 플레이테스트를 멈춘다.
3. `docs/progress.md`에서 해당 단계를 체크하고 메모를 남긴다.
4. 변경 내용 요약과 **사용자가 Studio에서 직접 확인할 항목**(멀티 플레이어 테스트 등)을 짧게 알려준다.
5. 단계 이름으로 커밋한다 (예: `S1-3: 매치 루프와 역할 배정`).
