#!/usr/bin/env bash
# 강사용. main(완성본)에서 step-0 ~ step-7 태그를 역으로 만든다.
#
#   ./scripts/build-tags.sh
#   git push origin --tags && git push origin main
#
# 각 태그는 "그 장을 시작하는 상태"다. step-4 는 3장까지 완료된 상태.
set -e
cd "$(dirname "$0")/.." || exit 1

git rev-parse --git-dir >/dev/null 2>&1 || { echo "git 리포가 아닙니다. git init 부터 하세요."; exit 1; }
[ -n "$(git status --porcelain)" ] && { echo "커밋 안 된 변경이 있습니다. 먼저 커밋하세요."; exit 1; }

BASE=$(git rev-parse --abbrev-ref HEAD)

# 각 단계에서 아직 없어야 할 파일들.
# step-N 은 "N장을 시작하는 상태" = N-1장까지 완료된 상태다.
#   1장 산출물 web/intake.html          2장 CLAUDE.md, schemas/
#   3장 mcp_server/server.py, .mcp.json 4장 agents/intaker.md
#   5장 gate.sh, settings.json          6장 agents/{marker,interrogator,responder}.md
#   7장 web/index.html
ALL7="web/index.html"
ALL6="$ALL7 .claude/agents/marker.md .claude/agents/interrogator.md .claude/agents/responder.md"
ALL5="$ALL6 .claude/gate.sh .claude/settings.json"
ALL4="$ALL5 .claude/agents/intaker.md"
ALL3="$ALL4 mcp_server/server.py .mcp.json"
ALL2="$ALL3 CLAUDE.md schemas/review.schema.json"
ALL1="$ALL2 web/intake.html"

drop_0="$ALL1"
drop_1="$ALL1"
drop_2="$ALL2"
drop_3="$ALL3"
drop_4="$ALL4"
drop_5="$ALL5"
drop_6="$ALL6"
drop_7="$ALL7"

for n in 0 1 2 3 4 5 6 7; do
  var="drop_$n"; files="${!var}"
  git checkout -q -B "build-step-$n" "$BASE"
  for f in $files; do git rm -rq --ignore-unmatch "$f" 2>/dev/null || true; done
  # 학습 산출물은 어느 단계에서도 들어 있으면 안 된다
  git rm -rq --ignore-unmatch state/intake.json state/review.json logs/trace.jsonl 2>/dev/null || true
  git commit -qm "step-$n 시작 상태" --allow-empty
  git tag -f "step-$n" >/dev/null
  echo "  step-$n  생성"
done

git checkout -q "$BASE"
for n in 0 1 2 3 4 5 6 7; do git branch -qD "build-step-$n" >/dev/null 2>&1 || true; done

echo
echo "태그 8개를 만들었습니다."
git tag | sed 's/^/  /'
echo
echo "다음: git push origin main && git push origin --tags"
