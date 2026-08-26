#!/usr/bin/env bash
# Claude Code 훅 → logs/trace.jsonl (정규화)
#   echo '{...}' | bash scripts/trace-log.sh start|stop|tool|gate [tool_name]
# stdin 이 비어 있어도 동작한다.
cd "$(dirname "$0")/.." || exit 0
mkdir -p logs
EV="${1:-event}"
EXTRA="${2:-}"
HOOK_JSON="$(cat 2>/dev/null || true)"
export HOOK_JSON EV EXTRA

python3 <<'PY' >> logs/trace.jsonl
import json, os, datetime

ev = os.environ.get("EV", "event")
extra = os.environ.get("EXTRA") or None
raw = os.environ.get("HOOK_JSON") or "{}"
try:
    d = json.loads(raw) if raw.strip() else {}
except Exception:
    d = {}

def pick(*keys):
    for k in keys:
        v = d.get(k)
        if v not in (None, ""):
            return v
    return None

agent = pick("agent_type", "agent", "subagent_type", "name")
tool = pick("tool_name", "tool", "toolName") or extra
out = {
    "ts": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "ev": ev,
}
if agent:
    out["agent"] = agent
if tool:
    out["tool"] = tool
print(json.dumps(out, ensure_ascii=False))
PY
exit 0
