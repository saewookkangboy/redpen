"""redpen-desk — 빨간펜 실습용 로컬 MCP 서버.

도구 4개: 읽기 2(weight_rubric, score_draft) · 쓰기 2(save_rubric, save_review).
계산은 전부 규칙 기반이다. 판단하지 않는다.
"""

import json
import math
import re
from pathlib import Path

# MCP SDK 2.x 에서 FastMCP 가 MCPServer 로 이름이 바뀌었다.
# 수강생 PC의 설치 버전이 제각각이므로 양쪽을 모두 받아들인다.
try:                                            # mcp >= 2
    from mcp.server.mcpserver import MCPServer as _Server
except ModuleNotFoundError:                     # mcp 1.x
    from mcp.server.fastmcp import FastMCP as _Server

ROOT = Path(__file__).resolve().parent.parent
mcp = _Server("redpen-desk")

# ─────────────────────────────────────────────────────────────
# 문항 3의 12개 보기 → 체크리스트 항목 매핑
# 보기를 늘리려면 여기와 web/intake.html 두 곳을 함께 고친다.
# ─────────────────────────────────────────────────────────────
CATALOG = {
    "이 숫자 어디서 나왔어요?":       ("R1", "숫자에 출처·기간·집계 기준", "auto",
                                       "표 아래에 '출처 / 기간 / 집계 기준' 세 가지를 적는다"),
    "결론이 뭐예요?":                 ("R2", "첫 화면의 결론", "auto",
                                       "첫 10줄 안에 결론 한 줄과 핵심 숫자를 둔다"),
    "대안은 없어요?":                 ("R3", "대안 2개 이상", "auto",
                                       "고른 안 + 검토했다가 버린 안 1개를 같이 쓴다"),
    "너무 길어요":                    ("R4", "짧은 분량", "auto",
                                       "문단은 300자 안쪽, 핵심은 3개 이내로 줄인다"),
    "이거 누가 하는 거예요?":         ("R5", "담당자 표기", "manual",
                                       "할 일마다 담당 팀이나 역할을 적는다"),
    "언제까지예요?":                  ("R6", "완료 시점", "auto",
                                       "일정표에 시작일·종료일·중간 점검을 적는다"),
    "비용은요?":                      ("R7", "비용 근거", "manual",
                                       "총액만이 아니라 어떻게 나왔는지(단가·공수)를 적는다"),
    "리스크는요?":                    ("R8", "리스크와 대응", "manual",
                                       "리스크 2개 이상, 각각에 대응 한 줄"),
    "전에 했던 거랑 뭐가 달라요?":    ("R9", "이전과의 차이", "manual",
                                       "예전에 한 것과 이번 안의 차이를 표로 대조한다"),
    "다른 팀이랑 얘기됐어요?":        ("R10", "관련 팀 협의", "manual",
                                       "팀별로 협의 완료 / 진행 중 / 아직 안 함을 적는다"),
    "그래서 나한테 뭘 해달라는 거예요?": ("R11", "분명한 요청", "auto",
                                       "문서 맨 위에 '요청: ~' 한 줄을 둔다"),
    "이거 왜 지금이에요?":            ("R12", "지금 해야 하는 이유", "manual",
                                       "외부 일정이나 숫자로 '왜 지금인지'를 적는다"),
}

FREQ_SCORE = {"4회 이상": 3, "2~3회": 2, "1회": 1, "기억 안 남": 0}
BANNED = ["꼼꼼", "민감", "성향", "성격", "완벽주의", "스타일", "예민", "까다로"]

REQUIRED_FIELDS = {"reviewer": 1, "doc_purpose": 10}


def _read_json(path: Path):
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _ok(**kw) -> str:
    return json.dumps(kw, ensure_ascii=False, indent=2)


def _err(reason: str, **kw) -> str:
    return json.dumps({"error": reason, **kw}, ensure_ascii=False, indent=2)


# ─────────────────────────────────────────────────────────────
# 읽기 1 — 신뢰등급 계산
# ─────────────────────────────────────────────────────────────
@mcp.tool()
def weight_rubric() -> str:
    """state/intake.json 을 읽어 체크리스트 항목별 점수와 신뢰등급을 규칙대로 계산한다.

    판단하지 않는다. 같은 답변에는 항상 같은 등급이 나온다.
    """
    intake = _read_json(ROOT / "state" / "intake.json")
    if intake is None:
        return _err("state/intake.json 이 없습니다. web/intake.html 에서 문진을 먼저 하세요.")

    missing = [str(num) for key, num in REQUIRED_FIELDS.items() if not intake.get(key)]
    if missing:
        return _err("필수 문항 누락", missing_questions=missing)

    free_text = " ".join(
        [
            *(intake.get("heard_free") or []),
            intake.get("diff_rejected_vs_passed") or "",
            intake.get("passed_why") or "",
            intake.get("dislikes") or "",
        ]
    )

    items, unheard = [], []

    for entry in intake.get("heard") or []:
        label = entry.get("q", "")
        if label not in CATALOG:
            continue
        rid, title, judge, action = CATALOG[label]
        freq = entry.get("freq", "기억 안 남")
        score = FREQ_SCORE.get(freq, 0)
        basis = [f"문항3에서 «{label}» 을 {freq} 들음 ({score}점)"]

        # 자유 서술에 같은 취지가 나오면 +1
        keywords = [w for w in re.split(r"[^가-힣A-Za-z]+", title) if len(w) > 1]
        if any(k in free_text for k in keywords):
            score += 1
            basis.append("문항5·6 답변에도 같은 내용이 있음 (+1)")

        # 통과할 때 이 내용이 있었으면 +1
        passed_why = intake.get("passed_why") or ""
        if passed_why and any(k in passed_why for k in keywords):
            score += 1
            basis.append(f"문항7 통과 이유에도 관련 내용이 있음: «{passed_why[:24]}» (+1)")

        if score >= 4:
            conf = "high"
        elif score >= 2:
            conf = "medium"
        elif score == 1:
            conf = "low"
        else:
            unheard.append(
                {"id": rid, "title": title, "reason": f"문항3에서 «{label}» 을 기억 안 남으로 표기"}
            )
            continue

        items.append(
            {
                "id": rid,
                "title": title,
                "score": score,
                "confidence": conf,
                "judge": judge,
                "action": action,
                "basis": basis,
            }
        )

    # 문항9만 있고 문항3 선택이 없는 경우 → 회상 부족으로 남긴다
    if intake.get("dislikes") and not items:
        unheard.append(
            {"id": "R0", "title": "문항9 서술 내용", "reason": "문항3에서 대응하는 보기를 고르지 않음"}
        )

    items.sort(key=lambda x: -x["score"])

    skipped = intake.get("skipped") or []
    answered = 12 - len(skipped)

    improve_by = []
    if 3 in skipped or not intake.get("heard"):
        improve_by.append(3)
    if any(i["confidence"] != "high" for i in items) and not intake.get("heard_free"):
        improve_by.append(5)
    for num, key in ((6, "diff_rejected_vs_passed"), (7, "passed_why"), (11, "my_worry")):
        if not intake.get(key):
            improve_by.append(num)

    return _ok(
        items=items,
        unheard=unheard,
        answered=answered,
        skipped=skipped,
        high_count=sum(1 for i in items if i["confidence"] == "high"),
        improve_by=sorted(set(improve_by)),
        mode="review" if (intake.get("draft") or "").strip() not in ("", "없음") else "guide",
    )


# ─────────────────────────────────────────────────────────────
# 읽기 2 — 초안 채점
# ─────────────────────────────────────────────────────────────
CONCLUSION_KEYS = ("결론", "제안", "권고", "요청")
SOURCE_KEYS = ("출처", "기준", "집계", "기간", "월", "분기")
HEDGES = ("검토 필요", "추후", "지속적으로", "모니터링", "향후", "면밀히")


@mcp.tool()
def score_draft(draft_path: str = "drafts/sample-report.md") -> str:
    """초안을 규칙 기반으로만 채점한다. 지표와 줄 번호만 반환하고 본문은 반환하지 않는다."""
    path = ROOT / draft_path
    if not path.exists():
        return _ok(mode="guide", note=f"{draft_path} 없음. 가이드 모드로 진행하세요.")

    lines = path.read_text(encoding="utf-8").splitlines()
    head = "\n".join(lines[:10])
    body = "\n".join(lines)

    conclusion_ok = any(k in head for k in CONCLUSION_KEYS) and bool(re.search(r"\d", head))

    num_lines, sourced_lines, unsourced = [], [], []
    for idx, line in enumerate(lines, start=1):
        if re.search(r"\d+(\.\d+)?\s*(%|건|원|명|배|시간|일|주|개월)", line):
            num_lines.append(idx)
            window = "\n".join(lines[max(0, idx - 1): idx + 2])
            if any(k in window for k in SOURCE_KEYS):
                sourced_lines.append(idx)
            else:
                unsourced.append(idx)

    option_count = len(re.findall(r"(^|\s)(대안\s*\d|안\s*\d[\.:）)]|옵션\s*\d)", body))

    hedge_lines = [i for i, l in enumerate(lines, 1) if any(h in l for h in HEDGES)]

    paras = [p for p in re.split(r"\n\s*\n", body) if p.strip() and not p.strip().startswith("#")]
    avg_para = round(sum(len(p) for p in paras) / len(paras)) if paras else 0

    request_line = next((i for i, l in enumerate(lines, 1) if l.strip().startswith("요청")), None)

    checks = {
        "R1": {
            "pass": (len(sourced_lines) / len(num_lines) >= 0.8) if num_lines else True,
            "lines": unsourced,
        },
        "R2": {"pass": conclusion_ok, "lines": [] if conclusion_ok else [1]},
        "R3": {"pass": option_count >= 2, "lines": []},
        "R4": {"pass": avg_para <= 300, "lines": []},
        "R6": {"pass": bool(re.search(r"\d{1,2}월|\d{4}-\d{2}|~까지", body)), "lines": []},
        "R11": {"pass": request_line is not None, "lines": [] if request_line else [1]},
    }

    return _ok(
        mode="review",
        draft=draft_path,
        total_lines=len(lines),
        metrics={
            "conclusion_in_first_10_lines": conclusion_ok,
            "sourced_ratio": round(len(sourced_lines) / len(num_lines), 2) if num_lines else None,
            "number_lines": len(num_lines),
            "option_count": option_count,
            "hedge_count": len(hedge_lines),
            "hedge_lines": hedge_lines,
            "avg_para_chars": avg_para,
        },
        checks=checks,
    )


# ─────────────────────────────────────────────────────────────
# 쓰기 1 — 체크리스트 저장 (게이트 대상)
# ─────────────────────────────────────────────────────────────
@mcp.tool()
def save_rubric(reviewer: str, payload: str) -> str:
    """state/rubrics/{reviewer}.md 로 저장한다. 검증에 실패하면 저장하지 않는다."""
    problems = []

    hit = [w for w in BANNED if w in payload]
    if hit:
        problems.append(f"금지 표현 발견: {', '.join(hit)} — 성격 추정은 쓰지 않습니다")

    headings = re.findall(r"^##\s+(.+)$", payload, flags=re.M)
    blocks = re.split(r"^##\s+.+$", payload, flags=re.M)[1:]
    for title, block in zip(headings, blocks):
        if title.startswith("[회상 부족]"):
            continue
        if "근거:" not in block and "근거 :" not in block:
            problems.append(f"«{title}» 에 근거 문항이 없습니다")
        if not re.search(r"\[(high|medium|low)", title + block):
            problems.append(f"«{title}» 에 신뢰등급이 없습니다")

    if not headings:
        problems.append("체크리스트 항목이 하나도 없습니다")

    if problems:
        return _err("검증 실패 — 저장하지 않았습니다", problems=problems)

    out = ROOT / "state" / "rubrics" / f"{reviewer}.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(payload, encoding="utf-8")
    return _ok(saved=str(out.relative_to(ROOT)), items=len(headings))


# ─────────────────────────────────────────────────────────────
# 쓰기 2 — 검수 결과 저장
# ─────────────────────────────────────────────────────────────
@mcp.tool()
def save_review(payload: str) -> str:
    """state/review.json 에 저장한다. 스키마와 근거 규칙을 검증한다."""
    try:
        data = json.loads(payload)
    except json.JSONDecodeError as e:
        return _err(f"JSON 파싱 실패: {e}")

    schema = _read_json(ROOT / "schemas" / "review.schema.json") or {}
    problems = [f"필수 필드 누락: {f}" for f in schema.get("required", []) if f not in data]

    if data.get("mode") not in ("review", "guide"):
        problems.append("mode 는 review 또는 guide 여야 합니다")

    for i, q in enumerate(data.get("questions") or []):
        if not q.get("basis") and not q.get("speculative"):
            problems.append(f"questions[{i}] — 근거가 없는데 speculative 가 false 입니다")
        if q.get("confidence") not in ("high", "medium", "low"):
            problems.append(f"questions[{i}] — confidence 값이 잘못됐습니다")

    for i, r in enumerate(data.get("rubric") or []):
        if not r.get("basis"):
            problems.append(f"rubric[{i}] — 근거 문항이 없습니다")

    hit = [w for w in BANNED if w in payload]
    if hit:
        problems.append(f"금지 표현 발견: {', '.join(hit)}")

    if problems:
        return _err("검증 실패 — 저장하지 않았습니다", problems=problems)

    total = sum(
        float(q.get("prep_minutes") or 0)
        for q in (data.get("questions") or [])
        if str(q.get("prep_minutes") or "").replace(".", "").isdigit()
    )
    data["total_prep_minutes"] = data.get("total_prep_minutes") or math.ceil(total)

    out = ROOT / "state" / "review.json"
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return _ok(
        saved="state/review.json",
        mode=data.get("mode"),
        questions=len(data.get("questions") or []),
        total_prep_minutes=data["total_prep_minutes"],
    )


if __name__ == "__main__":
    mcp.run()
