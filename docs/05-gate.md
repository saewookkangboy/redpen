# 5장 · 게이트와 관측 · 20분

## 이 장이 끝나면

- 승인 없이는 저장이 **실제로 막힌다**
- 위원들이 언제 일했는지 로그에 남는다

---

## 실습 1 · 쓰기 도구 2개

```
mcp_server/server.py 에 쓰기 도구 2개를 추가해줘. 읽기 도구는 그대로 둔다.

3) save_rubric(reviewer, payload) -> str
   state/rubrics/{reviewer}.md 로 저장. 저장 전 검증하고, 실패하면 저장하지 않는다.
   - 모든 항목([회상 부족] 제외)에 "근거:" 가 있는가
   - 모든 항목 제목이나 본문에 신뢰등급(high|medium|low)이 있는가
   - 금지 표현(꼼꼼|민감|성향|성격|완벽주의|스타일|예민|까다로)이 본문에 없는가
   - 항목이 하나도 없으면 거부
   실패 시 어떤 항목이 왜 걸렸는지 목록으로 반환한다.

4) save_review(payload) -> str
   payload 를 schemas/review.schema.json 의 required 로 검증한 뒤 state/review.json 에 저장.
   추가 검증:
   - basis 가 빈 배열인데 speculative 가 false 인 질문이 있으면 저장 거부
   - confidence 가 high|medium|low 가 아니면 거부
   - rubric 항목에 basis 가 없으면 거부
   - 금지 표현이 있으면 거부
   total_prep_minutes 가 비어 있으면 questions 의 prep_minutes 합으로 채운다.
```

---

## 실습 2 · 게이트

```bash
cat > .claude/gate.sh <<'EOF'
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
EOF
chmod +x .claude/gate.sh
echo '{ "rubric_approved": false, "mode": "HITL" }' > state/approvals.json
```

관측은 `scripts/trace-log.sh` 가 훅 stdin 을 정규화해 `logs/trace.jsonl` 에 씁니다.
`.claude/settings.json` 을 만듭니다.

```json
{
  "hooks": {
    "SubagentStart": [
      { "hooks": [ { "type": "command", "async": true,
        "command": "bash scripts/trace-log.sh start || true" } ] }
    ],
    "SubagentStop": [
      { "hooks": [ { "type": "command", "async": true,
        "command": "bash scripts/trace-log.sh stop || true" } ] }
    ],
    "PreToolUse": [
      { "matcher": "mcp__redpen-desk__save_rubric",
        "hooks": [ { "type": "command", "command": "bash .claude/gate.sh" } ] },
      { "matcher": "mcp__redpen-desk__.*",
        "hooks": [ { "type": "command", "async": true,
          "command": "bash scripts/trace-log.sh tool || true" } ] }
    ],
    "PostToolUse": [
      { "matcher": "mcp__redpen-desk__.*",
        "hooks": [ { "type": "command", "async": true,
          "command": "bash scripts/trace-log.sh tool_done || true" } ] }
    ]
  }
}
```

---

## 반드시 이 순서로 하세요

**① 승인하지 않은 채로 저장을 시켜 봅니다.**

```
아까 만든 체크리스트를 save_rubric 으로 저장해줘.
```

막힙니다. AI 가 "승인이 없어서 저장하지 못했다" 고 보고합니다.

**② 근거를 직접 읽습니다.**

항목마다 어느 문항의 어떤 답변에서 나왔는지 확인하세요. 이게 게이트의 목적입니다.

**③ 한 글자를 고칩니다.**

```bash
# state/approvals.json 의 false 를 true 로
```

**④ 다시 시킵니다.** 저장됩니다.

---

## 질문 세 개

**AI 에게 "승인받고 저장해" 라고 부탁한 게 아닙니다. 코드가 막았습니다. 뭐가 다를까요?**

부탁은 확률이고, 훅은 결정입니다.
프롬프트에 아무리 강하게 써도 안 지켜지는 날이 있습니다. `exit 2` 는 매번 막습니다.

**왜 체크리스트 저장에는 결재가 필요하고, 검수 결과 저장에는 없을까요?**

체크리스트는 한 번 틀리면 **그 뒤 모든 검수가 같은 방향으로 틀립니다.**
검수 결과는 틀려도 그 문서 하나로 끝납니다.

> 게이트는 아무 데나 거는 게 아닙니다. **되돌리기 비용이 큰 지점**에 겁니다.

**금지 표현을 규칙(CLAUDE.md)에도 쓰고 도구(save_rubric)에서도 막습니다. 왜 두 번일까요?**

같은 이유입니다. 규칙은 확률이고 검증은 결정입니다.
정말 나가면 안 되는 것은 두 겹으로 막습니다.

---

## 확인

```bash
./scripts/check.sh 5
```

**다음** → [6장 · 위원 3인 병렬](06-parallel.md)
