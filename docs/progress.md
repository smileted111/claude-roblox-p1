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
- [ ] S1-2 테스트 맵 (블록)
- [ ] S1-3 매치 루프·역할 배정
- [ ] S1-4 생존자 이동·달리기·숨기
- [ ] S1-5 추격자 공격·잡힘 판정
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
