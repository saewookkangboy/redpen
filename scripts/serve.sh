#!/usr/bin/env bash
# 문진 폼과 편집국(결과·파이프라인) 화면을 띄운다.
# file:// 로 열면 CORS 로 막히므로 반드시 이걸 쓴다.
cd "$(dirname "$0")/.." || exit 1
PORT="${1:-8080}"
echo "빨간펜 편집국  (localhost:$PORT)"
echo "  라이브 보드  http://localhost:$PORT/web/"
echo "  문진        http://localhost:$PORT/web/intake.html"
echo "  1) 문진 작성 → 복사"
echo "  2) Claude Code 에서 /intake 또는 /redpen"
echo "  3) 보드에서 문진관 → 게이트 → 위원 3인 확인"
echo "  (종료: Ctrl+C)"
exec python3 -m http.server "$PORT"
