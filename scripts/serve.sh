#!/usr/bin/env bash
# 문진 폼과 결과 화면을 띄운다. file:// 로 열면 CORS 로 막히므로 반드시 이걸 쓴다.
cd "$(dirname "$0")/.." || exit 1
PORT="${1:-8080}"
echo "문진:  http://localhost:$PORT/web/intake.html"
echo "결과:  http://localhost:$PORT/web/"
echo "(종료: Ctrl+C)"
python3 -m http.server "$PORT" >/dev/null 2>&1
