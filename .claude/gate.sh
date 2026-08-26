#!/usr/bin/env bash
# HITL 게이트 — 승인 없이는 체크리스트를 저장할 수 없다.
# exit 2 가 PreToolUse 훅에서 도구 호출 자체를 차단한다.
cd "$(dirname "$0")/.." || exit 2

log_gate() {
  local status="$1"
  bash scripts/trace-log.sh gate "$status" </dev/null 2>/dev/null || true
}

APPROVED=$(jq -r '.rubric_approved // false' state/approvals.json 2>/dev/null)
if [ "$APPROVED" = "true" ]; then
  log_gate "pass"
  exit 0
fi

log_gate "blocked"
cat >&2 <<'MSG'
[게이트] 체크리스트는 사람이 확인해야 저장됩니다.
항목별 근거 문항과 신뢰등급을 직접 읽어보고,
state/approvals.json 의 rubric_approved 를 true 로 바꾼 뒤 다시 시도하세요.
MSG
exit 2
