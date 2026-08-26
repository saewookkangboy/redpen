#!/usr/bin/env bash
# 챕터 완료 여부를 스스로 확인한다.
#   ./scripts/check.sh        전체
#   ./scripts/check.sh 3      3장만
#
# jq 에 의존하지 않는다. jq 는 관측 훅에서만 쓰므로,
# 아직 설치 전인 수강생에게 오탐이 뜨면 안 된다.
cd "$(dirname "$0")/.." || exit 1

PASS=0; FAIL=0
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
no() { printf '  \033[31m✗\033[0m %s\n' "$1"; [ -n "$2" ] && printf '      → %s\n' "$2"; FAIL=$((FAIL+1)); }
sec() { printf '\n\033[1m%s\033[0m\n' "$1"; }
has() { [ -e "$1" ]; }

# jpath <파일> <점표기 경로>  — 값이 있으면 0
jpath() {
  python3 -c 'import json,sys
try: d=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: sys.exit(1)
for k in [x for x in sys.argv[2].split(".") if x]:
    if isinstance(d,dict) and k in d: d=d[k]
    else: sys.exit(1)
sys.exit(0 if (d or d==0 or d is False) else 1)' "$1" "$2" 2>/dev/null
}

# jis <파일> <경로> <기대값>  — 값이 기대값과 같으면 0
jis() {
  python3 -c 'import json,sys
try: d=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: sys.exit(1)
for k in [x for x in sys.argv[2].split(".") if x]:
    if isinstance(d,dict) and k in d: d=d[k]
    else: sys.exit(1)
sys.exit(0 if str(d).lower()==sys.argv[3].lower() else 1)' "$1" "$2" "$3" 2>/dev/null
}

# jcount <파일> <이름>  — 숫자 하나를 찍는다
jcount() {
  python3 -c 'import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8")); w=sys.argv[2]
if w=="unbacked":
    print(len([q for q in d.get("questions",[]) if not q.get("basis") and not q.get("speculative")]))
elif w=="high":
    print(d.get("evidence",{}).get("high_count",0))
elif w=="marks":
    print(len(d.get("marks",[])))' "$1" "$2" 2>/dev/null
}

WANT="${1:-all}"
run() { [ "$WANT" = "all" ] || [ "$WANT" = "$1" ]; }

# ── 0장 · 환경 ────────────────────────────────────────────
if run 0; then
sec "0장 · 환경"
  command -v python3 >/dev/null && ok "python3" || no "python3 없음" "SETUP.md 참고"
  command -v uv      >/dev/null && ok "uv"      || no "uv 없음" "curl -LsSf https://astral.sh/uv/install.sh | sh"
  command -v jq      >/dev/null && ok "jq"      || no "jq 없음" "관측 훅에 필요합니다. brew install jq"
  has drafts/sample-report.md && ok "가상 초안" || no "drafts/sample-report.md 없음"
fi

# ── 1장 · 문진 폼 ─────────────────────────────────────────
if run 1; then
sec "1장 · 문진 폼"
  if has web/intake.html; then
    ok "web/intake.html 존재"
    grep -q "skipped" web/intake.html \
      && ok "skipped 배열 분리" \
      || no "skipped 를 안 만든다" "빈 문자열로 넘기면 improve_by 계산이 안 됩니다"
    n=$(grep -o '요[?]"' web/intake.html | wc -l | tr -d ' ')
    [ "$n" -ge 5 ] && ok "문항3 보기 목록 있음" || no "문항3 보기가 부족" "12개 보기를 모두 넣으세요"
  else no "web/intake.html 없음" "docs/01-intake-form.md 참고"; fi
fi

# ── 2장 · 하네스 ──────────────────────────────────────────
if run 2; then
sec "2장 · 하네스"
  has CLAUDE.md && ok "CLAUDE.md" || no "CLAUDE.md 없음"
  grep -q "성격" CLAUDE.md 2>/dev/null \
    && ok "프로파일링 금지 절 있음" \
    || no "금지 절이 없다" "무엇을 만들지 않는지 먼저 적으세요"
  jpath schemas/review.schema.json required \
    && ok "review.schema.json 유효" || no "스키마가 없거나 깨짐"
fi

# ── 3장 · MCP 읽기 도구 ───────────────────────────────────
if run 3; then
sec "3장 · MCP 읽기 도구"
  if has mcp_server/server.py; then
    ok "server.py 존재"
    python3 -c "import ast;ast.parse(open('mcp_server/server.py',encoding='utf-8').read())" 2>/dev/null \
      && ok "문법 통과" || no "문법 오류" "Claude Code 에 '고쳐줘' 라고 하세요"
    for t in weight_rubric score_draft; do
      grep -q "def $t" mcp_server/server.py && ok "도구 $t" || no "도구 $t 없음"
    done
    jpath .mcp.json mcpServers.redpen-desk \
      && ok "redpen-desk 등록" || no ".mcp.json 등록 안 됨" "Claude Code 에서 /mcp 로 확인"
  else no "mcp_server/server.py 없음" "docs/03-mcp-read.md 참고"; fi
fi

# ── 4장 · 문진관 ──────────────────────────────────────────
if run 4; then
sec "4장 · 문진관"
  has .claude/agents/intaker.md && ok "intaker.md" || no "intaker.md 없음"
  grep -q "weight_rubric" .claude/agents/intaker.md 2>/dev/null \
    && ok "계산을 도구에 위임" || no "도구 위임 누락" "등급을 AI가 매기면 매번 달라집니다"
  if jpath state/intake.json reviewer && jpath state/intake.json doc_purpose; then
    ok "문진 답변 있음 (필수 2문항)"
  else no "state/intake.json 없거나 필수 누락" "intake.html 에서 복사해 붙여넣으세요"; fi
fi

# ── 5장 · 게이트와 관측 ───────────────────────────────────
if run 5; then
sec "5장 · 게이트와 관측"
  if has .claude/gate.sh; then
    ok "gate.sh 존재"
    [ -x .claude/gate.sh ] && ok "실행 권한" || no "실행 권한 없음" "chmod +x .claude/gate.sh"
    if jis state/approvals.json rubric_approved false; then
      bash .claude/gate.sh >/dev/null 2>&1
      [ $? -eq 2 ] && ok "미승인 시 exit 2 로 차단" || no "차단이 안 된다" "exit 2 여야 훅이 막습니다"
    else ok "승인 상태 — 차단 검사 생략"; fi
  else no ".claude/gate.sh 없음"; fi
  jpath .claude/settings.json hooks.PreToolUse    && ok "PreToolUse 훅 등록" || no "게이트 훅 등록 안 됨"
  jpath .claude/settings.json hooks.SubagentStart && ok "관측 훅 등록"       || no "SubagentStart 훅 없음"
  if has scripts/trace-log.sh && [ -x scripts/trace-log.sh ]; then
    ok "trace-log.sh 존재"
  else no "scripts/trace-log.sh 없음" "관측 훅이 정규화 스크립트를 부릅니다"; fi
  grep -q "trace-log.sh" .claude/settings.json 2>/dev/null \
    && ok "관측 훅이 trace-log.sh 를 사용" \
    || no "settings.json 에 trace-log.sh 없음" "jq 직결보다 정규화 스크립트를 쓰세요"
  for t in save_rubric save_review; do
    grep -q "def $t" mcp_server/server.py 2>/dev/null && ok "도구 $t" || no "도구 $t 없음"
  done
fi

# ── 6장 · 병렬 ────────────────────────────────────────────
if run 6; then
sec "6장 · 위원 3인 병렬"
  for a in marker interrogator responder; do
    has ".claude/agents/$a.md" && ok "$a.md" || no "$a.md 없음"
  done
  grep -qE '^tools:[[:space:]]*Read[[:space:]]*$' .claude/agents/responder.md 2>/dev/null \
    && ok "답변관에 검색 도구 없음" \
    || no "답변관 도구 권한 확인" "검색이 붙으면 missing 이 비어버립니다"
  if has logs/trace.jsonl && [ -s logs/trace.jsonl ]; then
    ok "trace.jsonl 기록 있음 ($(wc -l < logs/trace.jsonl | tr -d ' ')줄)"
  else no "trace.jsonl 이 비었다" "jq 설치와 훅 설정을 확인하세요"; fi
fi

# ── 7장 · 결과 화면 ───────────────────────────────────────
if run 7; then
sec "7장 · 결과 화면"
  has web/index.html && ok "web/index.html" || no "web/index.html 없음"
  if jpath state/review.json mode && jpath state/review.json questions; then
    ok "review.json 유효 (지적 $(jcount state/review.json marks)건)"
    bad=$(jcount state/review.json unbacked)
    [ "$bad" = "0" ] && ok "근거 없는 질문이 speculative 로 표시됨" \
                     || no "$bad 건이 근거 없이 단정됨" "save_review 검증을 확인하세요"
    hi=$(jcount state/review.json high)
    if [ "${hi:-0}" -gt 0 ] 2>/dev/null; then ok "high 등급 항목 ${hi}개"
    else no "high 등급 0개" "정상일 수 있습니다. improve_by 문항에 답해보세요"; fi
  else no "state/review.json 없음" "/redpen 을 끝까지 실행하세요"; fi
fi

printf '\n\033[1m통과 %d · 실패 %d\033[0m\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then printf '다음 장으로 넘어가세요.\n'
else printf '막히면 ./scripts/reset.sh <다음단계> 로 그 단계 완성본을 받으세요.\n'; fi
exit 0
