#!/usr/bin/env bash
# 막혔을 때 해당 단계의 완성 상태를 받아온다.
#   ./scripts/reset.sh step-4
# 내 작업은 지워지지 않는다. stash 로 백업한 뒤 태그 상태로 맞춘다.
set -e
cd "$(dirname "$0")/.." || exit 1
TAG="$1"
[ -z "$TAG" ] && { echo "사용법: ./scripts/reset.sh step-4"; git tag | sed 's/^/  /'; exit 1; }
git rev-parse "$TAG" >/dev/null 2>&1 || { echo "그런 태그가 없습니다: $TAG"; exit 1; }

STAMP=$(date +%m%d-%H%M)
git stash push -u -m "backup-$STAMP" >/dev/null 2>&1 && echo "현재 작업을 stash 에 백업했습니다 (backup-$STAMP)"

# git checkout <태그> -- . 은 없는 파일을 지우지 않는다.
# 이 태그 이후에 생긴 파일(다음 장 산출물)을 먼저 지워야 진짜로 그 단계로 돌아간다.
git diff --name-only --diff-filter=A "$TAG" HEAD -- . | while IFS= read -r f; do
  rm -f -- "$f"
done
git checkout "$TAG" -- .
echo "$TAG 상태로 맞췄습니다. 이어서 진행하세요."
echo "되돌리려면: git stash pop"
