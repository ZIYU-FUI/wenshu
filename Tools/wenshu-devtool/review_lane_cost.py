#!/usr/bin/env python3
"""
review_lane_cost.py - measure what a REVIEW LANE run costs, so the flow can
be tuned by data instead of by impression.

WHY THIS TOOL EXISTS
  Every tuning decision so far was made by hand: open the board DB, open the
  reviewer profile's agent.log, count things, compare before/after. That
  works once and then becomes the bottleneck = the whole point of the loop is
  to run the board repeatedly and notice the next thing worth changing.

WHAT IT MEASURES, and WHY EACH NUMBER IS HERE

  The lane's cost is the ROUND TRIP, not the gate's runtime. Every tool
  call is one API call, and every API call re-sends the whole history, so
  the price of a run grows with the SQUARE of its round count. Measured on
  board wenshu-par, 2026-11-03, over the wenshu-review profile's own log
  (74 sessions, 6221 API calls):

    - 88% of the wall clock is API latency (52.8 h of 60 h); the terminal
      work is the rest. So a gate that runs the whole suite is NOT the
      thing that makes a review slow, and a card-side "cost gate" cannot
      fix it either (= the card's shape correlates |r| < 0.3 with the call
      count, and once the card size is held constant every other card
      feature falls to |r| < 0.1).
    - a completed review makes 90 shell calls and WRITES its own scripts
      to do it (8.7 scratch writes + 8.7 scratch runs per session). The
      ad-hoc shell call correlates +0.510 with the wall clock, a
      scratch-script run +0.361, and a repo gate call only +0.287.
    - the median latency is 16 s below 50k input tokens and 34 s above
      350k, and the last third of a session's calls eats 35% of its API
      time.

  So this tool reports the four numbers that decide the next change:
  the ROUNDS, the CONTEXT GROWTH, the SCRATCH SCRIPTS, and the WASTED
  runs (the ones that hit the cap and were re-dispatched from zero).

Read-only. It never writes to the board or to the profile logs.

Usage:
    python3 review_lane_cost.py                  # the review lane, text report
    python3 review_lane_cost.py --json           # machine-readable
    python3 review_lane_cost.py --board wenshu-par
    python3 review_lane_cost.py --profile wenshu-review
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)

HERMES = Path(os.path.expanduser("~/.hermes"))

# The profile whose log holds the review lane's runs.
DEFAULT_PROFILE = "wenshu-review"

# The agent.log lines this tool reads.
API_CALL_RE = re.compile(
    r"\[(?:local-)?([0-9a-f]{64})\] agent\.conversation_loop: API call #(\d+): "
    r".*?in=(\d+) out=(\d+) total=(\d+) latency=([\d.]+)s cache=(\d+)/(\d+)"
)
TOOL_RE = re.compile(
    r"\[(?:local-)?([0-9a-f]{64})\] agent\.tool_executor: tool (\w+) completed "
    r"\(([\d.]+)s"
)
SHA_RE = re.compile(r"\b[0-9a-f]{40}\b")


def as_text(value) -> str:
    """A board column as text. sqlite hands back BYTES for a BLOB column.

    A task body is TEXT for most cards and BLOB for a few, and `value or ""`
    does not fix it (= a non-empty bytes object is truthy, so it survives the
    `or`), so the bytes have to be decoded explicitly. A BLOB body that
    reaches a regex as bytes raises "cannot use a string pattern on a
    bytes-like object".
    """
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return str(value)


def ts(value) -> float:
    """A task_run timestamp as epoch seconds. The board stores ISO text."""
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace("Z", "+00:00")
    try:
        from datetime import datetime

        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            from datetime import timezone

            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.timestamp()
    except ValueError:
        return 0.0
BRANCH_RE = re.compile(r"wt/[a-z0-9\-]+")


def ro(path: Path) -> sqlite3.Connection | None:
    """Open a database read-only. A locked file must never block a measurement."""
    if not path.exists():
        return None
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=30)
        conn.execute("PRAGMA busy_timeout=20000")
        return conn
    except sqlite3.Error:
        return None


def board_db(board: str) -> Path:
    """The board's database path."""
    return Path(product_lines.board_db(board))


def agent_logs(profile: str) -> list[Path]:
    """Every agent.log of the profile, newest first (= the whole history)."""
    log_dir = HERMES / "profiles" / profile / "logs"
    if not log_dir.exists():
        return []
    out = [p for p in log_dir.glob("agent.log*") if p.is_file()]
    return sorted(out, key=lambda p: p.name, reverse=True)


def session_costs(profile: str) -> dict:
    """Per-session rounds, latency, context growth, tool mix, from the log."""
    sessions: dict[str, dict] = defaultdict(
        lambda: {"calls": [], "latency": 0.0, "tools": Counter()}
    )
    for log in agent_logs(profile):
        try:
            text = log.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for line in text.splitlines():
            m = API_CALL_RE.search(line)
            if m:
                s = sessions[m.group(1)]
                s["calls"].append(
                    (int(m.group(2)), int(m.group(3)), float(m.group(6)))
                )
                s["latency"] += float(m.group(6))
                continue
            m = TOOL_RE.search(line)
            if m:
                sessions[m.group(1)]["tools"][m.group(2)] += 1
    return sessions


def scratch_stats(profile: str) -> dict:
    """How many scratch files the profile wrote, and how many distinct."""
    db = ro(HERMES / "profiles" / profile / "state.db")
    if db is None:
        return {}
    try:
        rows = db.execute(
            "SELECT tool_calls FROM messages WHERE tool_calls IS NOT NULL"
        ).fetchall()
    except sqlite3.Error:
        return {}
    finally:
        db.close()
    files: set[str] = set()
    writes = 0
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
            if name != "write_file":
                continue
            args = fn.get("arguments") or call.get("arguments") or {}
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except (ValueError, TypeError):
                    args = {}
            if not isinstance(args, dict):
                continue
            path = args.get("path") or ""
            if "/cache/scratch/" in path:
                writes += 1
                files.add(path)
    return {"scratch_writes": writes, "distinct_scratch_files": len(files)}


def lane_runs(board: str, profile: str) -> dict:
    """The board's view of the lane: runs, outcomes, wasted wall, re-review share."""
    conn = ro(board_db(board))
    if conn is None:
        return {}
    try:
        rows = conn.execute(
            "SELECT r.task_id, r.started_at, r.ended_at, r.outcome, "
            "t.title, t.body FROM task_runs r JOIN tasks t ON t.id = r.task_id "
            "WHERE r.profile = ? AND r.ended_at IS NOT NULL",
            (profile,),
        ).fetchall()
    except sqlite3.Error:
        return {}
    finally:
        conn.close()

    outcomes: Counter = Counter()
    wall = 0.0
    wasted = 0.0
    card_wall: dict[str, float] = defaultdict(float)
    branch_cards: dict[str, set] = defaultdict(set)
    for task_id, started, ended, outcome, title, body in rows:
        mins = max(0.0, (ts(ended) - ts(started)) / 60.0)
        outcomes[outcome or "none"] += 1
        wall += mins
        card_wall[task_id] += mins
        if outcome != "completed":
            wasted += mins
        for br in set(BRANCH_RE.findall(as_text(body))):
            branch_cards[br].add(task_id)

    multi = {b: c for b, c in branch_cards.items() if len(c) > 1}
    rework_ids = set().union(*multi.values()) if multi else set()
    rework_wall = sum(card_wall.get(t, 0.0) for t in rework_ids)

    return {
        "runs": sum(outcomes.values()),
        "outcomes": dict(outcomes),
        "wall_minutes": round(wall, 1),
        "wasted_minutes": round(wasted, 1),
        "wasted_share": round(wasted / wall, 3) if wall else 0.0,
        "branches": len(branch_cards),
        "multi_round_branches": len(multi),
        "re_review_cards": len(rework_ids),
        "re_review_wall_share": round(rework_wall / wall, 3) if wall else 0.0,
    }


def build(board: str, profile: str) -> dict:
    """Every number this tool reports."""
    sessions = session_costs(profile)
    live = {s: v for s, v in sessions.items() if v["calls"]}
    calls = [c for v in live.values() for c in v["calls"]]
    latencies = [c[2] for c in calls]
    api_wall = sum(latencies)
    tool_calls = sum(sum(v["tools"].values()) for v in live.values())

    # The context growth inside a session, and the latency that follows it.
    growth = []
    for v in live.values():
        ordered = sorted(v["calls"])
        if len(ordered) < 2:
            continue
        first, last = ordered[0][1], ordered[-1][1]
        if first:
            growth.append(last / first)
    # The latency by context size, bucketed.
    by_size: dict[int, list] = defaultdict(list)
    for _, in_tokens, latency in calls:
        by_size[min(in_tokens // 50000 * 50, 400)].append(latency)

    tool_mix: Counter = Counter()
    for v in live.values():
        tool_mix.update(v["tools"])

    scratch = scratch_stats(profile)
    runs = lane_runs(board, profile)

    return {
        "board": board,
        "profile": profile,
        "sessions": len(live),
        "api_calls": len(calls),
        "api_wall_hours": round(api_wall / 3600, 2),
        "tool_calls": tool_calls,
        "tool_calls_per_session": round(tool_calls / len(live), 1) if live else 0,
        "median_latency_s": round(statistics.median(latencies), 1) if latencies else 0,
        "mean_latency_s": round(statistics.mean(latencies), 1) if latencies else 0,
        "median_calls_per_session": (
            round(statistics.median([len(v["calls"]) for v in live.values()]), 0)
            if live
            else 0
        ),
        "median_context_growth_x": (
            round(statistics.median(growth), 1) if growth else 0
        ),
        "latency_by_context_k": {
            str(k): round(statistics.median(v), 1)
            for k, v in sorted(by_size.items())
            if v
        },
        "tool_mix": dict(tool_mix.most_common()),
        **scratch,
        **runs,
    }


def report(d: dict) -> str:
    """The text report."""
    out: list[str] = []
    out.append(f"=== review lane cost: {d.get('board')} / {d.get('profile')} ===")
    out.append("")
    out.append("THE ROUND TRIP (the lane's actual cost)")
    out.append(
        f"  sessions={d.get('sessions')}  api_calls={d.get('api_calls')}  "
        f"median {d.get('median_calls_per_session', 0):.0f} calls/session"
    )
    out.append(
        f"  api wall={d.get('api_wall_hours')}h  median latency={d.get('median_latency_s')}s  "
        f"mean={d.get('mean_latency_s')}s"
    )
    out.append(
        f"  tool calls={d.get('tool_calls')} ({d.get('tool_calls_per_session')}/session)"
    )
    out.append(
        f"  context growth={d.get('median_context_growth_x')}x median "
        f"(the price of a call rises with it)"
    )
    out.append("  latency by context size:")
    for k, v in d.get("latency_by_context_k", {}).items():
        out.append(f"    {k:>4}k tokens -> {v:>6}s median")
    out.append("")
    out.append("THE SCRATCH SCRIPTS (the reviewer reinventing what it was given)")
    out.append(
        f"  scratch files written={d.get('scratch_writes', 0)}  "
        f"distinct={d.get('distinct_scratch_files', 0)}"
    )
    out.append("  tool mix:")
    for k, v in list(d.get("tool_mix", {}).items())[:8]:
        out.append(f"    {k:16s} {v}")
    out.append("")
    out.append("THE BOARD'S VIEW")
    if not d.get("runs"):
        out.append("  (the board could not be read)")
    else:
        out.append(
            f"  runs={d['runs']}  wall={d.get('wall_minutes', 0) / 60:.1f}h  "
            f"wasted={d.get('wasted_minutes', 0) / 60:.1f}h ({d.get('wasted_share', 0) * 100:.0f}%)"
        )
        out.append(
            f"  branches={d.get('branches', 0)}  multi-round={d.get('multi_round_branches', 0)}  "
            f"re-review cards={d.get('re_review_cards', 0)} "
            f"({d.get('re_review_wall_share', 0) * 100:.0f}% of the wall)"
        )
        out.append("  outcomes:")
        for k, v in sorted(d["outcomes"].items(), key=lambda kv: -kv[1]):
            out.append(f"    {k:16s} {v}")
    out.append("")
    out.append("WHAT TO READ NEXT")
    out.append(
        "  rounds and context growth are the price; the scratch scripts are"
    )
    out.append(
        "  the buyer of it; the wasted share is the bill for the runs that"
    )
    out.append(
        "  hit the cap and were re-dispatched from zero. A change moves the"
    )
    out.append("  wall clock only if it moves one of these three.")
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--board", default=product_lines.DEFAULT_BOARD)
    ap.add_argument("--profile", default=DEFAULT_PROFILE)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    d = build(args.board, args.profile)
    if args.json:
        print(json.dumps(d, indent=2))
    else:
        print(report(d))
    return 0


if __name__ == "__main__":
    sys.exit(main())

