#!/usr/bin/env python3
"""wenshu-flow-metrics — measure the board so the flow can be tuned by data.

Every tuning decision so far was made by hand: open the board DB, open two
profile session DBs, count tool calls, compare before/after. That works once
and then becomes the bottleneck — the whole point of the loop is to run the
board repeatedly and notice the next thing worth changing.

This script produces that measurement in one shot. It answers the questions
the loop actually asks:

  1. How long does a card take, and how does that split by outcome?
  2. Does a worker read outside its budget? (the evidence-budget plugin's job)
  3. How much of the session is duplicate work? (the read-fingerprint job)
  4. How many compressions does a card cause, and what do they cost?
  5. Which cards are drifting right now?

Read-only. It never writes to the board or the session DBs.

Usage:
    python3 wenshu_flow_metrics.py                 # last 24h, text report
    python3 wenshu_flow_metrics.py --hours 72
    python3 wenshu_flow_metrics.py --json           # machine-readable
    python3 wenshu_flow_metrics.py --board wenshu-mob-par
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)

HERMES = Path(os.path.expanduser("~/.hermes"))
# The boards live under the GLOBAL hermes home, declared once.
BOARDS = Path(product_lines.boards_dir())
WORKER_PROFILES = ("wenshu-dev", "wenshu-review", "pocock")

# A tool call that only LOOKS at things (no code changes).
READ_ONLY_TOOLS = {
    "read_file", "search_files", "terminal", "execute_code",
    "web_search", "web_extract", "skill_view", "kanban_show",
    "tool_search", "tool_describe", "browser_exec",
}
# A tool call that CHANGES things.
WRITE_TOOLS = {"write_file", "patch", "edit_file"}


def ro(path: Path) -> sqlite3.Connection:
    """Open a database read-only. A locked board must never block a measurement."""
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=30)
    conn.execute("PRAGMA busy_timeout=20000")
    return conn


def table_exists(conn: sqlite3.Connection, name: str) -> bool:
    row = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,)
    ).fetchone()
    return row is not None


# --- board -------------------------------------------------------------------


def board_runs(board: str, since: float) -> list[dict]:
    db = BOARDS / board / "kanban.db"
    if not db.exists():
        return []
    conn = ro(db)
    try:
        if not table_exists(conn, "task_runs"):
            return []
        cols = {r[1] for r in conn.execute("PRAGMA table_info(task_runs)")}
        want = ["id", "task_id", "started_at", "ended_at", "outcome", "error"]
        sel = [c for c in want if c in cols]
        rows = conn.execute(
            f"SELECT {', '.join(sel)} FROM task_runs WHERE started_at > ? ORDER BY started_at",
            (since,),
        ).fetchall()
    finally:
        conn.close()
    return [dict(zip(sel, r)) for r in rows]


def board_tasks(board: str) -> dict[str, dict]:
    db = BOARDS / board / "kanban.db"
    if not db.exists():
        return {}
    conn = ro(db)
    try:
        rows = conn.execute("SELECT id, title, assignee, status, body FROM tasks").fetchall()
    finally:
        conn.close()
    return {
        r[0]: {"title": r[1] or "", "assignee": r[2] or "", "status": r[3] or "", "body": r[4] or ""}
        for r in rows
    }


# --- sessions ----------------------------------------------------------------


def session_calls(conn: sqlite3.Connection, session_id: str) -> list[tuple[str, str]]:
    """(tool_name, canonical_args) for every tool call in a session."""
    out: list[tuple[str, str]] = []
    try:
        rows = conn.execute(
            "SELECT tool_calls FROM messages WHERE session_id=? AND tool_calls IS NOT NULL",
            (session_id,),
        ).fetchall()
    except sqlite3.Error:
        return out
    for (raw,) in rows:
        try:
            arr = json.loads(raw)
        except (ValueError, TypeError):
            continue
        if isinstance(arr, dict):
            arr = [arr]
        for call in arr:
            if not isinstance(call, dict):
                continue
            fn = call.get("function") or {}
            name = fn.get("name") or call.get("name") or "?"
            args = fn.get("arguments") or call.get("arguments") or {}
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except (ValueError, TypeError):
                    args = {"_raw": args[:200]}
            if not isinstance(args, dict):
                args = {}
            out.append((name, json.dumps(args, sort_keys=True)))
    return out


def session_stats(conn: sqlite3.Connection, session_id: str) -> dict:
    calls = session_calls(conn, session_id)
    total = len(calls)
    exact = Counter((n, a) for n, a in calls)
    dup_exact = sum(v - 1 for v in exact.values() if v > 1)
    # A re-read of the SAME file with a DIFFERENT window is not a duplicate.
    read_windows = Counter(
        (a and json.loads(a).get("path"), json.loads(a).get("offset"), json.loads(a).get("limit"))
        for n, a in calls
        if n == "read_file" and a
    )
    read_dup = sum(v - 1 for v in read_windows.values() if v > 1)
    read_files = {json.loads(a).get("path") for n, a in calls if n == "read_file" and a}
    read_files.discard(None)
    read_only = sum(1 for n, _ in calls if n in READ_ONLY_TOOLS)
    writes = sum(1 for n, _ in calls if n in WRITE_TOOLS)
    try:
        comps = conn.execute(
            "SELECT COUNT(*) FROM messages WHERE session_id=? AND _compressed_summary=1",
            (session_id,),
        ).fetchone()[0]
    except sqlite3.Error:
        comps = 0
    return {
        "calls": total,
        "dup_exact": dup_exact,
        "dup_exact_rate": round(dup_exact / total, 3) if total else 0.0,
        "read_dup": read_dup,
        "distinct_files": len(read_files),
        "read_only_calls": read_only,
        "write_calls": writes,
        "compressions": comps,
    }


def worker_sessions(hours: float) -> list[dict]:
    since = time.time() - hours * 3600
    out: list[dict] = []
    for prof in WORKER_PROFILES:
        db = HERMES / "profiles" / prof / "state.db"
        if not db.exists():
            continue
        try:
            conn = ro(db)
        except sqlite3.Error:
            continue
        try:
            if not table_exists(conn, "sessions"):
                continue
            rows = conn.execute(
                "SELECT id, started_at, title, tool_call_count, api_call_count, "
                "input_tokens, output_tokens, model FROM sessions "
                "WHERE started_at > ? ORDER BY started_at",
                (since,),
            ).fetchall()
        except sqlite3.Error:
            continue
        for sid, sa, title, tc, api, it, ot, model in rows:
            st = session_stats(conn, sid)
            out.append({
                "profile": prof,
                "session_id": sid,
                "started_at": sa,
                "title": (title or "")[:90],
                "model": model,
                "tool_calls": tc or 0,
                "api_calls": api or 0,
                "input_tokens": it or 0,
                "output_tokens": ot or 0,
                **st,
            })
        conn.close()
    return out


def parse_read_list(body: str) -> list[str]:
    """The card's ``read:`` entries, as paths.

    A card may wrap a path in backticks and append prose to the last entry
    (```Tests/Foo.swift` - at most 4 files.``). Strip the prose, then the
    backticks, so the entry stays a path.
    """
    i = body.find("EVIDENCE BUDGET")
    if i < 0:
        return []
    tail = body[i:]
    line = None
    for candidate in tail.splitlines():
        if candidate.strip().lower().startswith("read:"):
            line = candidate
            break
    if not line:
        return []
    entries: list[str] = []
    for chunk in line.split(":", 1)[1].split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        m = re.match(r"^`([^`]+)`", chunk)
        chunk = m.group(1).strip() if m else (chunk.split()[0] if chunk.split() else "")
        chunk = chunk.strip().strip("`").strip()
        if chunk and chunk not in entries:
            entries.append(chunk)
    return entries


def budget_violations(board_tasks_map: dict[str, dict], sessions: list[dict]) -> list[dict]:
    """Cards whose worker read files outside the card's read: list."""
    out = []
    for s in sessions:
        title = s["title"]
        # The session title carries the card title; match it back.
        best = None
        for tid, t in board_tasks_map.items():
            if t["title"] and (t["title"][:40] == title[:40] or title.startswith(t["title"][:30])):
                best = (tid, t)
                break
        if not best:
            continue
        tid, t = best
        listed = parse_read_list(t["body"])
        if not listed:
            continue
        # A file is in budget if the path ends with a listed path.
        read_files = s.get("_files") or []
        outside = [
            f for f in read_files
            if not any(f.endswith("/" + p) or f == p for p in listed)
            and os.path.basename(f) not in ("AGENTS.md", "CLAUDE.md", "MEMORY.md")
        ]
        if outside:
            out.append({
                "card": tid,
                "title": t["title"][:60],
                "outside": outside[:6],
                "outside_count": len(outside),
                "listed_count": len(listed),
            })
    return out


def attach_files(sessions: list[dict]) -> None:
    """Record the distinct files each session opened, for the budget check."""
    for prof in WORKER_PROFILES:
        db = HERMES / "profiles" / prof / "state.db"
        if not db.exists():
            continue
        conn = ro(db)
        try:
            for s in sessions:
                if s["profile"] != prof:
                    continue
                files = set()
                try:
                    rows = conn.execute(
                        "SELECT tool_calls FROM messages WHERE session_id=? AND tool_calls IS NOT NULL",
                        (s["session_id"],),
                    ).fetchall()
                except sqlite3.Error:
                    continue
                for (raw,) in rows:
                    try:
                        arr = json.loads(raw)
                    except (ValueError, TypeError):
                        continue
                    if isinstance(arr, dict):
                        arr = [arr]
                    for call in arr:
                        if not isinstance(call, dict):
                            continue
                        fn = call.get("function") or {}
                        if (fn.get("name") or call.get("name")) != "read_file":
                            continue
                        a = fn.get("arguments") or call.get("arguments") or {}
                        if isinstance(a, str):
                            try:
                                a = json.loads(a)
                            except (ValueError, TypeError):
                                continue
                        if isinstance(a, dict) and a.get("path"):
                            files.add(a["path"])
                s["_files"] = sorted(files)
        finally:
            conn.close()


# The message Hermes shows when a tool-loop guardrail stops a turn. A worker
# that hits it never reaches a board tool, so the run is recorded as a crash.
# The exact assistant-facing phrasing Hermes uses when a tool-loop guardrail
# stops a turn. Matched against ASSISTANT messages only: the same sentences
# appear in card bodies and tool results, which would produce false hits.
GUARDRAIL_HALT_MARKERS = (
    "I stopped retrying because I kept running",
    "Stop retrying the same failing tool path and choose a different approach",
)


def guardrail_halts(sessions: list[dict], hermes_root: Path | None = None,
                   profiles: tuple[str, ...] | None = None) -> list[dict]:
    """Sessions where a tool-loop guardrail stopped the turn.

    This is the expensive failure: the worker stops mid-card, the board sees a
    crash, and the card's work is lost to a re-dispatch.

    ``hermes_root`` and ``profiles`` exist so the test suite can point the
    detector at a fixture instead of the live profiles.
    """
    root = hermes_root or HERMES
    profiles = profiles or WORKER_PROFILES
    out = []
    for prof in profiles:
        db = root / "profiles" / prof / "state.db"
        if not db.exists():
            continue
        conn = ro(db)
        try:
            for s in sessions:
                if s["profile"] != prof:
                    continue
                try:
                    rows = conn.execute(
                        "SELECT content FROM messages WHERE session_id=? AND content IS NOT NULL "
                        "AND role='assistant'",
                        (s["session_id"],),
                    ).fetchall()
                except sqlite3.Error:
                    continue
                for (content,) in rows:
                    text = content or ""
                    if any(m in text for m in GUARDRAIL_HALT_MARKERS):
                        out.append({
                            "profile": prof,
                            "session_id": s["session_id"],
                            "started_at": s["started_at"],
                            "title": s["title"],
                            "marker": next(m for m in GUARDRAIL_HALT_MARKERS if m in text),
                        })
                        break
        finally:
            conn.close()
    return out


# --- report ------------------------------------------------------------------


def build(hours: float, board: str) -> dict:
    since = time.time() - hours * 3600
    tasks = board_tasks(board)
    runs = board_runs(board, since)
    sessions = worker_sessions(hours)
    attach_files(sessions)
    viol = budget_violations(tasks, sessions)
    halts = guardrail_halts(sessions)

    by_outcome: dict[str, list[float]] = defaultdict(list)
    crashed_err: Counter = Counter()
    for r in runs:
        out = r.get("outcome") or "running"
        sa, ea = r.get("started_at"), r.get("ended_at")
        dur = (ea - sa) / 60 if sa and ea else 0.0
        by_outcome[out].append(dur)
        if out == "crashed":
            err = (r.get("error") or "")
            key = "gateway/disconnect" if "disconnect" in err.lower() else (
                "quota/402" if "402" in err or "Add credits" in err else err[:60]
            )
            crashed_err[key] += 1

    def stat(xs: list[float]) -> dict:
        if not xs:
            return {"n": 0}
        xs = sorted(xs)
        return {
            "n": len(xs),
            "median_min": round(xs[len(xs) // 2], 1),
            "p90_min": round(xs[min(int(len(xs) * 0.9), len(xs) - 1)], 1),
            "total_min": round(sum(xs), 1),
        }

    now = time.time()
    running = []
    for r in runs:
        if (r.get("outcome") or "running") == "running":
            sa = r.get("started_at") or now
            running.append({
                "card": r.get("task_id"),
                "title": tasks.get(r.get("task_id"), {}).get("title", "")[:60],
                "minutes_in": round((now - sa) / 60, 1),
            })

    return {
        "hours": hours,
        "board": board,
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "runs": {
            "total": len(runs),
            "by_outcome": {k: stat(v) for k, v in by_outcome.items()},
            "crash_causes": dict(crashed_err.most_common()),
        },
        "sessions": {
            "total": len(sessions),
            "calls": sum(s["calls"] for s in sessions),
            "dup_exact_rate": round(
                sum(s["dup_exact"] for s in sessions) / max(1, sum(s["calls"] for s in sessions)), 3
            ),
            "compressions": sum(s["compressions"] for s in sessions),
            "reads": sum(s["distinct_files"] for s in sessions),
            "writes": sum(s["write_calls"] for s in sessions),
            "read_only_share": round(
                sum(s["read_only_calls"] for s in sessions) / max(1, sum(s["calls"] for s in sessions)), 3
            ),
        },
        "budget_violations": viol,
        "guardrail_halts": halts,
        "running_now": running,
        "_sessions": sessions,
    }


def report(d: dict) -> str:
    out: list[str] = []
    w = out.append
    w(f"wenshu flow metrics — board {d['board']}, last {d['hours']}h  ({d['generated_at']})")
    w("=" * 78)
    r = d["runs"]
    w(f"\nRUNS: {r['total']}")
    for outcome, s in sorted(r["by_outcome"].items(), key=lambda kv: -kv[1].get("n", 0)):
        if not s.get("n"):
            continue
        w(f"  {outcome:<12} n={s['n']:<4} median={s['median_min']:>6.1f}m  p90={s['p90_min']:>7.1f}m  total={s['total_min']:>8.1f}m")
    if r["crash_causes"]:
        w("  crash causes:")
        for cause, n in r["crash_causes"].items():
            w(f"    {n:>3}x  {cause}")
    s = d["sessions"]
    w(f"\nSESSIONS: {s['total']}  calls={s['calls']}  reads={s['reads']}  writes={s['writes']}")
    w(f"  duplicate-call rate: {s['dup_exact_rate']:.1%}   (read-only share {s['read_only_share']:.1%})")
    w(f"  compressions: {s['compressions']}")
    if d["budget_violations"]:
        w(f"\nBUDGET: {len(d['budget_violations'])} card(s) read outside their read: list")
        for v in d["budget_violations"]:
            w(f"  {v['card']}  outside={v['outside_count']} (listed {v['listed_count']})  {v['title']}")
            for f in v["outside"][:4]:
                w(f"      {f[-70:]}")
    else:
        w("\nBUDGET: no card read outside its read: list")
    if d.get("guardrail_halts"):
        w(f"\nGUARDRAIL HALT: {len(d['guardrail_halts'])} session(s) stopped by a tool-loop guardrail")
        for h in sorted(d["guardrail_halts"], key=lambda v: -v["started_at"])[:10]:
            w(f"  {time.strftime('%m-%d %H:%M', time.localtime(h['started_at']))} [{h['profile']}] {h['title'][:44]}")
        w("  (a halted worker never reaches a board tool: the run becomes a crash and the card re-dispatches)")
    if d["running_now"]:
        w("\nRUNNING NOW:")
        for x in sorted(d["running_now"], key=lambda v: -v["minutes_in"]):
            w(f"  {x['card']}  {x['minutes_in']:>6.1f}m  {x['title']}")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=float, default=24.0)
    ap.add_argument("--board", default=product_lines.DEFAULT_BOARD)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    d = build(args.hours, args.board)
    if args.json:
        d.pop("_sessions", None)
        print(json.dumps(d, indent=2, ensure_ascii=False))
    else:
        print(report(d))
    return 0


if __name__ == "__main__":
    sys.exit(main())
