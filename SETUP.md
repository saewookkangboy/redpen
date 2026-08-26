# 환경 준비

수업 시작 전 10분이면 됩니다. 다 끝나면 `./scripts/check.sh 0` 이 전부 초록이어야 합니다.

## 필요한 것 4가지

| | 왜 필요한가 | 확인 |
|---|---|---|
| Claude Code | 이 실습의 본체 | `claude --version` |
| Python 3.10+ | MCP 서버가 파이썬 | `python3 --version` |
| uv | MCP 서버 실행 시 의존성 자동 처리 | `uv --version` |
| jq | 관측 훅이 로그를 남길 때 | `jq --version` |

## macOS

```bash
brew install python jq
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Windows (WSL2 권장)

```bash
sudo apt update && sudo apt install -y python3 python3-pip jq
curl -LsSf https://astral.sh/uv/install.sh | sh
```

PowerShell 에서 직접 하려면 `winget install jqlang.jq` 와 `winget install astral-sh.uv` 를 쓰세요.
다만 5장의 게이트 스크립트가 bash 기반이라 **WSL2 를 권장합니다.**

## 설치 후

```bash
source ~/.bashrc          # 또는 ~/.zshrc. uv 를 PATH 에 올린다
./scripts/check.sh 0
```

## 자주 나는 문제

**`uv: command not found`**
설치 후 셸을 다시 열지 않아서입니다. 새 터미널을 열거나 `source ~/.bashrc` 하세요.

**`jq: command not found` 인데 설치했다고 나옴**
`which jq` 로 경로를 확인하세요. Homebrew 를 Apple Silicon 에 처음 깔면 `/opt/homebrew/bin` 이 PATH 에 없는 경우가 있습니다.

**`./scripts/check.sh: Permission denied`**
```bash
chmod +x scripts/*.sh .claude/gate.sh
```

**MCP 서버가 안 뜬다 (3장에서)**
`/mcp` 를 Claude Code 에서 입력해 목록을 봅니다. 없으면 Claude Code 에 이렇게 말하세요.

> MCP 연결이 안 된다. .mcp.json 을 확인하고 고쳐줘. 서버를 직접 실행해서 오류를 보여줘.

**mcp 패키지 버전 문제**
SDK 2.x 에서 `FastMCP` 가 `MCPServer` 로 이름이 바뀌었습니다.
이 리포의 `mcp_server/server.py` 는 두 버전을 모두 받아들이도록 되어 있습니다.
직접 만든 서버가 `ModuleNotFoundError: No module named 'mcp.server.fastmcp'` 로 죽으면
Claude Code 에 "mcp 2.x 에서는 MCPServer 를 쓴다. 양쪽 버전 호환되게 고쳐줘" 라고 하세요.

**결과 화면이 빈 화면**
`file://` 로 열면 브라우저가 파일 읽기를 막습니다. 반드시 이걸 쓰세요.
```bash
./scripts/serve.sh
```
