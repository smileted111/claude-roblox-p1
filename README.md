# 라스트 서바이벌 (Last Survival)

Roblox 비대칭 추격 생존 게임.

- 기획서: [docs/GDD.md](docs/GDD.md)
- 작업 순서와 단계별 프롬프트: [docs/studio-workflow.md](docs/studio-workflow.md)
- 진행 상황: [docs/progress.md](docs/progress.md)
- Claude 작업 규칙: [CLAUDE.md](CLAUDE.md)

## 준비물

- [Roblox Studio](https://create.roblox.com/)
- [Git](https://git-scm.com/)
- [Rokit](https://github.com/rojo-rbx/rokit) — Rojo, Wally, Selene, StyLua의 버전을 `rokit.toml`대로 맞춰 준다.

## 설치

저장소 폴더의 터미널에서 실행한다.

```sh
rokit install    # rokit.toml에 적힌 도구 설치
wally install    # wally.toml의 패키지를 Packages/에 받기
```

- `rokit install`이 도구를 신뢰할지 물으면 `y`를 누른다.
- 설치 후 `rojo`, `wally` 같은 명령을 찾지 못하면 터미널(또는 VS Code)을 새로 연다. Rokit이 `~/.rokit/bin`을 PATH에 추가하지만 이미 열려 있던 터미널에는 반영되지 않는다.

## 실행

1. **Rojo 서버 켜기**: 저장소 폴더에서 `rojo serve`를 실행하고 켜 둔다.
2. **Rojo 플러그인 설치** (처음 한 번): Studio의 Creator Store에서 "Rojo"를 검색해 설치하거나, 터미널에서 `rojo plugin install`을 실행한 뒤 Studio를 다시 시작한다.
   - `rojo plugin install`이 `Couldn't find registry keys` 오류를 내면, [Rojo 릴리스](https://github.com/rojo-rbx/rojo/releases)에서 `rokit.toml`과 같은 버전의 `Rojo.rbxm`을 받아 `%LOCALAPPDATA%\Roblox\Plugins` 폴더(없으면 만든다)에 넣는다.
3. **플레이스 열기**: Studio에서 "라스트 서바이벌" 플레이스를 연다.
4. **연결**: Studio **플러그인 (Plugins)** 탭 → **Rojo** → **연결 (Connect)** (기본 주소 `localhost:34872`).
5. **확인**: 탐색기에 `ServerScriptService.Server`, `ReplicatedStorage.Shared`, `StarterPlayer.StarterPlayerScripts.Client`가 생기면 성공이다. 플레이하면 출력 창에 `[Service] ... started`, `[Controller] ... started` 로그가 찍힌다.

## 폴더 구조

| 저장소 | Studio | 내용 |
|---|---|---|
| `src/shared` | `ReplicatedStorage.Shared` | 설정 데이터(`Config/`), 공용 유틸(`Util/`) |
| `src/server` | `ServerScriptService.Server` | 서버 진입점, `Services/` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | 클라이언트 진입점, `Controllers/` |
| `Packages` | `ReplicatedStorage.Packages` | Wally 패키지 (Git에 올리지 않음) |

진입점은 `Services/`(서버)·`Controllers/`(클라이언트) 폴더의 모듈을 모두 불러와 `Init()`을 전부 실행한 다음 `Start()`를 실행한다.

## 주의

- `Workspace`, `ServerStorage`, `Lighting`, `StarterGui`는 Rojo가 관리하지 않는다. 맵은 Studio에서 만들고 **Studio에서 저장(Ctrl+S)** 해야 남는다. 스테이지 맵은 `ServerStorage.Maps.<StageId>`에 둔다.
- Rojo가 관리하는 스크립트를 Studio에서 직접 고치면 다음 동기화 때 `src/`의 내용으로 덮어써진다. 코드는 항상 `src/`에서 고친다.

## 코드 검사

```sh
selene src           # 린트
stylua --check src   # 포맷 검사
stylua src           # 포맷 자동 정리
```

VS Code의 Luau LSP 확장을 쓰면 `rojo sourcemap --watch -o sourcemap.json`을 켜 두어야 Studio 경로의 자동 완성이 된다.
