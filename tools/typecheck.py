"""src/의 Luau 코드를 luau-lsp로 타입 검사한다 (--!strict 포함).

사용: python tools/typecheck.py [luau-lsp analyze에 넘길 추가 인자...]

1. rokit.toml에 고정된 luau-lsp 버전에 맞는 Roblox API 타입 정의를 .luau-lsp/에 받는다 (처음 한 번).
2. rojo sourcemap으로 sourcemap.json을 만든다 (script.Parent 같은 경로를 이해시키기 위해).
3. luau-lsp analyze로 src/를 검사한다. 오류가 있으면 0이 아닌 값으로 끝난다.
"""

import os
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE_DIR = ROOT / ".luau-lsp"
# 게임 스크립트(서버·클라이언트)의 권한 수준. 플러그인 전용 API를 쓰면 오류로 잡힌다.
SECURITY_LEVEL = "None"
DEFS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{version}/scripts/globalTypes.{level}.d.luau"


def find_tool(name: str) -> str:
    found = shutil.which(name)
    if found:
        return found
    rokit_bin = Path.home() / ".rokit" / "bin" / (name + (".exe" if os.name == "nt" else ""))
    if rokit_bin.exists():
        return str(rokit_bin)
    sys.exit(f"{name}을 찾을 수 없습니다. 저장소 폴더에서 'rokit install'을 실행하세요.")


def luau_lsp_version() -> str:
    text = (ROOT / "rokit.toml").read_text(encoding="utf-8")
    match = re.search(r'luau-lsp\s*=\s*"[^"@]+@([^"]+)"', text)
    if not match:
        sys.exit("rokit.toml에 luau-lsp가 없습니다.")
    return match.group(1)


def ensure_definitions(version: str) -> Path:
    path = CACHE_DIR / f"globalTypes.{SECURITY_LEVEL}.{version}.d.luau"
    if path.exists():
        return path
    CACHE_DIR.mkdir(exist_ok=True)
    url = DEFS_URL.format(version=version, level=SECURITY_LEVEL)
    print(f"Roblox 타입 정의를 받는 중: {url}", flush=True)
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read()
    tmp = path.with_suffix(".tmp")
    tmp.write_bytes(data)
    tmp.replace(path)
    return path


def main() -> int:
    # Git Bash 같은 파이프 출력에서도 한글이 깨지지 않게 한다.
    sys.stdout.reconfigure(encoding="utf-8")
    definitions = ensure_definitions(luau_lsp_version())

    subprocess.run(
        [find_tool("rojo"), "sourcemap", "default.project.json", "--output", "sourcemap.json"],
        cwd=ROOT,
        check=True,
    )

    command = [
        find_tool("luau-lsp"),
        "analyze",
        "--platform=roblox",
        "--sourcemap=sourcemap.json",
        f"--definitions=@roblox={definitions.relative_to(ROOT).as_posix()}",
        # Luau 새 타입 솔버로 검사한다. 구 솔버는 Config처럼 ID 유니온을 키로 쓴 테이블
        # ({ [Types.StageId]: StageDef })을 Stages.Stage1처럼 점으로 접근하면 오류로 보고, 키 오타도 못 잡는다.
        "--flag:LuauSolverV2=true",
        *sys.argv[1:],
        "src",
    ]
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode == 0:
        print("타입 검사 통과")
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
