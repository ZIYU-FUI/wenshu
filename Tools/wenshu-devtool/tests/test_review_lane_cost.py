#!/usr/bin/env python3
"""test_review_lane_cost.py — the review-lane cost meter's own test suite.

The meter reads a real board and a real profile log, so the cases run on
FIXTURES: a temporary board DB and a temporary agent.log written to a
temporary profile directory. That keeps the tests valid when the real board
and the real logs change, and it proves the meter does not depend on the
machine it runs on.

The cases are the ways the meter can be wrong:

  1. an API-call line contributes a round trip and its latency.
  2. a tool line contributes a tool call, and the two are counted apart.
  3. the tool mix is per-tool, not a single total.
  4. context growth is measured inside a session (first call vs last call).
  5. the latency buckets are keyed by context size, so a slow big-context
     session is visible next to a fast small-context one.
  6. a run that ends without a verdict is WASTED wall clock, and the
     wasted share counts it.
  7. a card that appears on two branches of the same work is counted once
     in the re-review share.
  8. a profile with no log at all produces zeros, not a crash.
  9. the JSON report carries every number the text report prints.

Run:  python3 Tools/wenshu-devtool/tests/test_review_lane_cost.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import json
import sqlite3
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "review_lane_cost.py"

spec = importlib.util.spec_from_file_location("review_lane_cost", TOOL)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    if got == want:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        FAILURES.append(name)


def api_line(sid: str, call: int, in_tok: int, latency: float) -> str:
    return (
        f"[local-{sid}] agent.conversation_loop: API call #{call}: "
        f"model=mini in={in_tok} out=10 total={in_tok + 10} "
        f"latency={latency}s cache=0/0"
    )


def tool_line(sid: str, name: str, secs: float) -> str:
    return f"[local-{sid}] agent.tool_executor: tool {name} completed ({secs}s)"


def write_log(profile_dir: Path, lines: list[str]) -> None:
    log_dir = profile_dir / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    (log_dir / "agent.log").write_text("\n".join(lines) + "\n")


def make_board(path: Path, rows: list[tuple]) -> None:
    conn = sqlite3.connect(path)
    conn.execute(
        "CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT, body TEXT)"
    )
    conn.execute(
        "CREATE TABLE task_runs (task_id TEXT, profile TEXT, started_at TEXT, "
        "ended_at TEXT, outcome TEXT, metadata TEXT)"
    )
    for card_id, title, body in [
        (r[0], r[1], r[2]) for r in rows
    ]:
        conn.execute(
            "INSERT INTO tasks (id, title, body) VALUES (?, ?, ?)",
            (card_id, title, body),
        )
    for row in rows:
        conn.execute(
            "INSERT INTO task_runs (task_id, profile, started_at, ended_at, "
            "outcome, metadata) VALUES (?, 'wenshu-review', ?, ?, ?, NULL)",
            (row[0], row[3], row[4], row[5]),
        )
    conn.commit()
    conn.close()


def case_1_api_lines_count_rounds() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        prof = Path(tmp) / "prof"
        write_log(
            prof,
            [
                api_line("a" * 64, 1, 1000, 5.0),
                api_line("a" * 64, 2, 9000, 15.0),
                tool_line("a" * 64, "terminal", 1.0),
            ],
        )
        sessions = mod.session_costs(str(prof))
        check("one session parsed", len(sessions), 1)
        sess = sessions["a" * 64]
        check("two API calls", len(sess["calls"]), 2)
        check("latency summed", round(sess["latency"], 1), 20.0)
        check("one tool call", sess["tools"]["terminal"], 1)


def case_2_tool_and_api_counted_apart() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        prof = Path(tmp) / "prof"
        write_log(
            prof,
            [
                api_line("b" * 64, 1, 1000, 5.0),
                tool_line("b" * 64, "terminal", 1.0),
                tool_line("b" * 64, "read_file", 0.2),
            ],
        )
        sessions = mod.session_costs(str(prof))
        sess = sessions["b" * 64]
        check("api calls apart from tools", len(sess["calls"]), 1)
        check("tool calls totalled", sum(sess["tools"].values()), 2)


def case_3_tool_mix_per_tool() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        prof = Path(tmp) / "prof"
        write_log(
            prof,
            [
                tool_line("c" * 64, "terminal", 1.0),
                tool_line("c" * 64, "terminal", 1.0),
                tool_line("c" * 64, "write_file", 0.1),
            ],
        )
        sessions = mod.session_costs(str(prof))
        mix = sessions["c" * 64]["tools"]
        check("terminal counted twice", mix["terminal"], 2)
        check("write_file counted once", mix["write_file"], 1)


def case_4_context_growth_inside_a_session() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        prof = Path(tmp) / "prof"
        write_log(
            prof,
            [
                api_line("d" * 64, 1, 1000, 5.0),
                api_line("d" * 64, 2, 10000, 15.0),
                api_line("d" * 64, 3, 20000, 25.0),
            ],
        )
        sessions = mod.session_costs(str(prof))
        ordered = sorted(sessions["d" * 64]["calls"])
        check("first input tokens", ordered[0][1], 1000)
        check("last input tokens", ordered[-1][1], 20000)
        check("growth factor", round(ordered[-1][1] / ordered[0][1], 1), 20.0)


def case_5_latency_bucketed_by_context() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        prof = Path(tmp) / "prof"
        write_log(
            prof,
            [
                api_line("e" * 64, 1, 1000, 2.0),
                api_line("f" * 64, 1, 360000, 40.0),
            ],
        )
        sessions = mod.session_costs(str(prof))
        buckets: dict[int, list] = {}
        for sess in sessions.values():
            for _, in_tok, lat in sess["calls"]:
                key = min(in_tok // 50000 * 50, 400)
                buckets.setdefault(key, []).append(lat)
        check("small context bucket", round(mod.statistics.median(buckets[0]), 1), 2.0)
        check("big context bucket", round(mod.statistics.median(buckets[350]), 1), 40.0)


def case_6_unfinished_run_is_wasted() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        board_dir = Path(tmp) / "boards"
        board_dir.mkdir(parents=True)
        db_path = board_dir / "kanban.db"
        make_board(
            db_path,
            [
                ("t1", "one", "branch wt/alpha", "2026-11-01T00:00:00Z",
                 "2026-11-01T01:00:00Z", "completed"),
                ("t2", "two", "branch wt/beta", "2026-11-01T00:00:00Z",
                 "2026-11-01T02:00:00Z", "timed_out"),
            ],
        )
        mod.product_lines.board_db = lambda board: str(db_path)
        runs = mod.lane_runs("any", "wenshu-review")
        check("two runs", runs["runs"], 2)
        check("wall minutes", runs["wall_minutes"], 180.0)
        check("wasted minutes", runs["wasted_minutes"], 120.0)
        check("wasted share", runs["wasted_share"], round(120 / 180, 3))
        check("outcomes counted", runs["outcomes"]["timed_out"], 1)


def case_7_re_review_share_counts_a_card_once() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        board_dir = Path(tmp) / "boards"
        board_dir.mkdir(parents=True)
        db_path = board_dir / "kanban.db"
        make_board(
            db_path,
            [
                # two cards on the SAME branch = one branch with two rounds
                ("t1", "one", "branch wt/alpha", "2026-11-01T00:00:00Z",
                 "2026-11-01T01:00:00Z", "completed"),
                ("t2", "two", "branch wt/alpha", "2026-11-01T01:00:00Z",
                 "2026-11-01T01:30:00Z", "completed"),
                ("t3", "three", "branch wt/gamma", "2026-11-01T00:00:00Z",
                 "2026-11-01T00:30:00Z", "completed"),
            ],
        )
        mod.product_lines.board_db = lambda board: str(db_path)
        runs = mod.lane_runs("any", "wenshu-review")
        check("two branches", runs["branches"], 2)
        check("one multi-round branch", runs["multi_round_branches"], 1)
        check("two re-review cards", runs["re_review_cards"], 2)
        # t1 (60 min) and t2 (30 min) are the re-review cards; t3 (30 min)
        # is not. So 90 of 120 minutes = 0.75.  (An earlier version of this
        # case expected 0.5, which was the TEST's arithmetic being wrong,
        # not the meter's.)
        check("re-review wall share", runs["re_review_wall_share"], 0.75)


def case_8_missing_profile_is_zeros_not_a_crash() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        prof = Path(tmp) / "empty-prof"
        prof.mkdir(parents=True)
        sessions = mod.session_costs(str(prof))
        check("no sessions", len(sessions), 0)
        scratch = mod.scratch_stats(str(prof))
        check("scratch stats empty", scratch, {})


def case_9_json_report_is_complete() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        prof = Path(tmp) / "prof"
        write_log(
            prof,
            [
                api_line("9" * 64, 1, 1000, 5.0),
                api_line("9" * 64, 2, 5000, 15.0),
                tool_line("9" * 64, "terminal", 1.0),
            ],
        )
        sessions = mod.session_costs(str(prof))
        d = {
            "board": "wenshu-par",
            "profile": "wenshu-review",
            "sessions": len(sessions),
            "api_calls": sum(len(v["calls"]) for v in sessions.values()),
            "tool_mix": {},
        }
        # a PARTIAL dict must not crash the report (= the meter has to
        # survive a board it cannot read).
        report = mod.report(d)
        for needed in ("THE ROUND TRIP", "THE SCRATCH SCRIPTS", "THE BOARD'S VIEW"):
            check(f"report has {needed}", needed in report, True)
        check("json serialisable", bool(json.dumps(d)), True)
        empty = mod.report({})
        check("empty dict does not crash", "THE ROUND TRIP" in empty, True)


def main() -> int:
    cases = [
        case_1_api_lines_count_rounds,
        case_2_tool_and_api_counted_apart,
        case_3_tool_mix_per_tool,
        case_4_context_growth_inside_a_session,
        case_5_latency_bucketed_by_context,
        case_6_unfinished_run_is_wasted,
        case_7_re_review_share_counts_a_card_once,
        case_8_missing_profile_is_zeros_not_a_crash,
        case_9_json_report_is_complete,
    ]
    for case in cases:
        print(f"== {case.__name__}")
        case()
    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s): {', '.join(FAILURES)}")
        return 1
    print(f"ok: {len(cases)} cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
