# 출시 전 점검 (S3-9)

점검일: 2026-11-21. 기준 커밋: S3-8 이후 (`src/` 전체, Studio 플레이스).
**표의 문제는 아직 고치지 않았다.** 고칠 항목 번호를 알려주면 그것만 고친다 (docs/studio-workflow.md S3-9).

## 1. 배지 (구현함)

`src/server/Services/AchievementService.luau` + `src/shared/Config/Badges.luau`. 배지 ID를 받지 않아 모두 0(미설정, 주지 않음)이다.

| 배지 | 조건 (GDD 9장) | 확인 시점 |
|---|---|---|
| FirstEscape 첫 탈출 | 스테이지 결과가 Escaped | 스테이지 결과 |
| CatchAll 모두 잡기 | 추격자로 그 스테이지의 생존자를 모두 잡음 (chaserWon) | 스테이지 결과 |
| FirstLastSurvivor 첫 라스트 서바이버 | 같이 하기 매치의 라스트 서바이버 | 최종 결과 |
| SoloClear 솔로 클리어 | 혼자 하기 매치의 모든 스테이지에서 살아남음 | 최종 결과 |

지급은 `UserHasBadgeAsync`로 확인 뒤 `AwardBadgeAsync` (둘 다 pcall, 결과 처리를 멈추지 않게 task.spawn).

## 2. 코드 점검 (심각도 순)

| # | 심각도 | 분류 | 위치 | 내용 | 제안 |
|---|---|---|---|---|---|
| 1 | 보통 | 클라이언트 신뢰 | MovementService, CatchService | 캐릭터 이동은 Roblox 구조상 클라이언트가 한다. 서버는 속도(WalkSpeed)를 정하지만 실제 이동 거리를 검사하지 않아 속도 조작·순간이동 핵을 막지 못한다. 공격·프롬프트 거리 검사는 서버가 보는 위치로 하지만 그 위치가 조작된 것일 수 있다. | MovementService에서 0.5초마다 이동 거리를 (허용 속도 × 시간 × 1.5 + 여유)와 비교해 넘으면 직전 위치로 되돌리고 로그를 남긴다 (망령 순간이동·스테이지 배치처럼 서버가 옮긴 것은 예외). |
| 2 | 낮음 | 입력 검증 | ItemService.onUseItem, ChaserService.onUseSkill | 조준 위치·방향의 NaN은 거르지만 무한대(inf)는 통과한다 → 알람시계가 NaN 위치에 생기거나 망령이 NaN 위치로 순간이동. 보낸 사람 자신에게만 영향. | 각 성분이 유한한지(`math.abs(x) < 1e6`) 검사. |
| 3 | 낮음 | pcall | MatchService.spawnInLobby, StageService.ensureCharacter·respawn, ChaserService.loadCharacter | `LoadCharacterAsync`·`LoadCharacterWithHumanoidDescriptionAsync`에 pcall이 없다. 모두 별도 스레드(task.spawn·이벤트)라 매치 진행은 멈추지 않지만, 그 순간 나간 플레이어 등으로 실패하면 출력 창에 오류가 남고 그 사람이 배치되지 않는다. | pcall로 감싸고 실패하면 경고만. |
| 4 | 낮음 | 서버 검증 | LobbyService 혼자 하기 프롬프트 | Triggered에 서버 거리 검사가 없다 (로비 어디서나 혼자 하기 시작 가능, 해는 없음). 다른 프롬프트(숨기·수리·치료·줍기·판자·문)는 서버가 거리를 검사한다. | 발판 거리 검사 추가. |
| 5 | 정보 | 빈도 제한 | Remotes, RemoteHandler | 클라이언트 → 서버 리모트 9개 모두 `RemoteHandler.connect`(빈도 제한 Config.RateLimits + 관전자 거절)를 거친다. 직접 연결한 OnServerEvent 없음. RemoteFunction 없음. | 없음 |
| 6 | 정보 | pcall | DataService, LobbyService, ShopService, AchievementService, MonsterService | ProfileStore(세션·저장은 라이브러리가 재시도), 리더보드 SetAsync, ReserveServer·TeleportAsync, UserOwnsGamePassAsync, ProcessReceipt(저장 확인 후 Granted), 배지, Pathfinding ComputeAsync 모두 pcall 또는 라이브러리 처리. 클라이언트 GetProductInfoAsync도 pcall. | 없음 |
| 7 | 정보 | 메모리 | 서버 서비스 전체 | 플레이어별 표 25개는 PlayerRemoving에서 지우거나 스테이지·괴물과 함께 사라진다 (StageRun.left, 감시자 alertedAt). 맵마다 만든 연결은 clearMap에서 끊는다. 클라이언트의 프롬프트·표지판 연결은 인스턴스와 함께 사라진다. | 없음 |

## 3. 서버 성능 추정 (생존자·추격자 8명 + 괴물 20마리)

| 항목 | 지금 구현 | 추정 비용 | 비고 |
|---|---|---|---|
| 괴물 AI 갱신 | Heartbeat 하나, 괴물마다 0.2초 간격으로 나눠 갱신 (GDD 4.4) | 100회/초 | 가벼움 |
| 시야 판정 | 갱신마다 대상(최대 7명)을 거리·각도로 거른 뒤 레이캐스트 | 최대 700 레이캐스트/초, 실제는 훨씬 적음 | 프레임당 0.1ms 수준 |
| 길찾기 | 추격 중 0.5초마다(목표가 2스터드 넘게 움직였을 때) ComputeAsync, 계산 중엔 다시 안 함 | 최악 40회/초. 300×300 블록 맵에서 회당 수 ms면 초당 수십~200ms CPU | **가장 큰 비용** |
| Humanoid 물리 | 괴물 20 + 플레이어 8, 괴물은 서버 소유 | 보통 | 문제 수준 아님 |
| 기타 루프 | 손전등 0.1초, 숨는 곳 0.2초, 스태미나·발전기 Heartbeat | 작음 | |

개선 제안 (승인하면 적용):

| # | 효과 | 내용 |
|---|---|---|
| P1 | 높음 | **GDD 4.4 "멀리 있는 괴물은 단순 이동만" 미구현.** 모든 플레이어에서 일정 거리(예: 120스터드) 밖의 괴물은 1초마다만 갱신하고 시야 판정을 건너뛴다. |
| P2 | 중간 | 동시에 계산하는 길찾기 수 상한(예: 4개). 넘으면 다음 갱신으로 미룬다. |
| P3 | 중간 | 대상이 보이고 가까우면 경로 없이 곧장 추격하는 거리(DirectChaseDistance 15)를 25 정도로 늘려 재계산을 줄인다. |
| P4 | 확인 | 실제 비용은 Studio 마이크로프로파일러(Ctrl+F6)로 8명 테스트 서버에서 재 보는 것이 정확하다. |

## 4. GDD·progress와 다른 점

| # | 분류 | 내용 |
|---|---|---|
| D1 | 미구현 | GDD 4.4 원거리 괴물 단순화 (위 P1). |
| D2 | 미구현 | GDD 11 "추격자는 카메라 거리를 짧게" — CameraController가 비어 있다. |
| D3 | 자리만 | GDD 9 퀘스트(일일·주간 3개)와 로비 퀘스트 화면, 레벨 보상(칭호·꾸미기), 리더보드 표시(Config.Data.Leaderboards.Enabled = false). |
| D4 | 자리만 | GDD 10 꾸미기(스킨·잡을 때 연출), 상점 "준비 중". 비공개 서버 무료는 Creator Hub 설정. |
| D5 | 자리만 | GDD 12 사운드: 추격자·괴물이 가까워지면 커지는 심장 박동, 괴물 고유 소리, 효과음 4종(Config.Assets 빈 값), 알람시계 소리. "Future 조명"은 Studio에서 확인 필요 (MCP로 읽을 수 없음). |
| D6 | 결정 대기 | 상호작용 키 E → F (스킬 E와 겹침, S3-3). VIP 코인 +20%를 산 코인에는 안 붙임 (S3-6). |
| D7 | 사용자 입력 대기 | 게임패스·코인 상품·배지 ID (Config.Shop, Config.Badges), 가격(Q7-5), 3D 에셋 방식(Q11-1), 로고·썸네일 담당(Q11-4). |
| D8 | 보류 | progress.md: S1-9·S2-6 사용자 플레이테스트, S3-8 정식 맵 꾸미기. |
| D9 | 구조 | GDD 13.2 목록 밖 모듈: Record·Objective·Barrier·Lobby·Chaser·Language·Achievement Service, Lobby·Result·Shop Controller (각 파일 머리에 이유를 적음). GDD 13.2 표를 갱신할지 결정 필요. |
| D10 | 일치 | 스테이지 1~3 괴물·발전기·제한 시간(GDD 4.2), 인원 보정(4.3), 괴물 5종·추격자 4종, 아이템 5종, 관전, 솔로 70% 보상, 결과·라스트 서바이버, 저장·상점·현지화는 GDD대로. |
