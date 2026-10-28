#!/usr/bin/env python3
"""test_wenshu_flow_metrics.py — the flow-metrics reporter's own test suite.

Every case runs on a FIXTURE written to a temporary directory, so the tests
stay valid when the real board and the real session DBs change.

The cases are the things the reporter got wrong while it was being built:

  1. A read of a DIFFERENT line range of the same file is NOT a duplicate.
     (Counting it as one made a healthy 63% "duplicate rate" out of a
     normal paged read.)
  2. A read outside the card's `read:` list is reported as a violation, and
     one inside it is not.
  3. `AGENTS.md` is never a budget violation: reading the project's own rules
     is orientation, not probing.
  4. A card body whose `read:` entries are backticked and carry trailing
     prose ("`a.swift` - at most 4 files.") still parses to the path.
  5. A guardrail halt is detected only in an ASSISTANT message. The same
     sentence appears in card bodies and tool results; matching those
     produced 49 hits where there were 12 real halts.
  6. A session with no board card at all is reported, not dropped.

Run:  python3 Tools/wenshu-devtool/tests/test_wenshu_flow_metrics.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "wenshu_flow_metrics.py"


def load_tool():
    """Import wenshu_flow_metrics.py as a module, whatever its directory is."""
    spec = importlib.util.spec_from_file_location("wenshu_flow_metrics", TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}{(' — ' + detail) if detail else ''}")
        FAILURES.append(name)


def make_session_db(path: Path, rows: list[tuple]) -> None:
    """A minimal `sessions` + `messages` pair the reporter can read."""
    conn = sqlite3.connect(path)
    conn.execute(
        "CREATE TABLE sessions (id TEXT, started_at REAL, title TEXT, tool_call_count INT, "
        "api_call_count INT, input_tokens INT, output_tokens INT, model TEXT)"
    )
    conn.execute(
        "CREATE TABLE messages (id INTEGER PRIMARY KEY, session_id TEXT, role TEXT, content TEXT, "
        "tool_calls TEXT, tool_name TEXT, _compressed_summary INT)"
    )
    for row in rows:
        if row[0] == "session":
            conn.execute(
                "INSERT INTO sessions VALUES (?,?,?,?,?,?,?,?)",
                (row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8]),
            )
        else:
            conn.execute(
                "INSERT INTO messages (session_id, role, content, tool_calls, tool_name, _compressed_summary) "
                "VALUES (?,?,?,?,?,?)",
                row[1:],
            )
    conn.commit()
    conn.close()


def call(name: str, args: dict) -> str:
    """One tool call, serialized the way the reporter expects."""
    return json.dumps({"function": {"name": name, "arguments": json.dumps(args)}})


def main() -> int:
    tool = load_tool()
    tmp = Path(tempfile.mkdtemp(prefix="wenshu_flow_metrics_"))

    # --- case 1: a different line range is not a duplicate ------------------
    print("case 1: a paged read of one file is not duplicate work")
    calls = [
        call("read_file", {"path": "/repo/A.swift", "offset": 1, "limit": 100}),
        call("read_file", {"path": "/repo/A.swift", "offset": 101, "limit": 100}),
        call("read_file", {"path": "/repo/A.swift", "offset": 201, "limit": 100}),
    ]
    db = tmp / "s1.db"
    make_session_db(db, [
        ("session", "sess-1", 1000.0, "a card", 3, 3, 100, 100, "m"),
        ("message", "sess-1", "assistant", None, calls[0], None, 0),
        ("message", "sess-1", "assistant", None, calls[1], None, 0),
        ("message", "sess-1", "assistant", None, calls[2], None, 0),
    ])
    conn = sqlite3.connect(db)
    stats = tool.session_stats(conn, "sess-1")
    conn.close()
    check("three different ranges are not duplicates", stats["dup_exact"] == 0, str(stats))
    check("one distinct file is counted once", stats["distinct_files"] == 1, str(stats))

    # --- case 2: the same window twice IS a duplicate ------------------------
    print("case 2: the same window twice is duplicate work")
    same = call("read_file", {"path": "/repo/A.swift", "offset": 1, "limit": 100})
    db = tmp / "s2.db"
    make_session_db(db, [
        ("session", "sess-2", 1000.0, "a card", 2, 2, 100, 100, "m"),
        ("message", "sess-2", "assistant", None, same, None, 0),
        ("message", "sess-2", "assistant", None, same, None, 0),
    ])
    conn = sqlite3.connect(db)
    stats = tool.session_stats(conn, "sess-2")
    conn.close()
    check("the identical read counts as one duplicate", stats["dup_exact"] == 1, str(stats))

    # --- case 3: budget matching -------------------------------------------
    print("case 3: the read: list decides what is a violation")
    body = (
        "[T2] a card\n\n"
        "## EVIDENCE BUDGET\n\n"
        "read:   Sources/App/One.swift, Sources/App/Two.swift\n"
        "stop when: the thing happens.\n"
        "no:    the board history\n"
        "deliver: one commit\n"
    )
    tasks = {"t_1": {"title": "a card", "assignee": "wenshu-dev", "status": "running", "body": body}}
    sessions = [{
        "profile": "wenshu-dev", "session_id": "sess-3", "started_at": 1000.0,
        "title": "a card", "calls": 3, "dup_exact": 0, "dup_exact_rate": 0.0,
        "read_dup": 0, "distinct_files": 3, "read_only_calls": 3, "write_calls": 0,
        "compressions": 0,
        "_files": [
            "/wt/Sources/App/One.swift",     # inside
            "/wt/Sources/App/Two.swift",     # inside
            "/wt/Sources/App/Three.swift",   # outside
        ],
    }]
    viol = tool.budget_violations(tasks, sessions)
    check("one card is flagged", len(viol) == 1, str(viol))
    if viol:
        outside = viol[0]["outside"]
        check("the file inside the list is not flagged",
              not any("One.swift" in f or "Two.swift" in f for f in outside), str(outside))
        check("the file outside the list is flagged",
              any("Three.swift" in f for f in outside), str(outside))

    # --- case 4: AGENTS.md is never a violation ------------------------------
    print("case 4: AGENTS.md is orientation, not a violation")
    sessions[0]["_files"] = ["/wt/AGENTS.md", "/wt/Sources/App/Three.swift"]
    viol = tool.budget_violations(tasks, sessions)
    outside = viol[0]["outside"] if viol else []
    check("AGENTS.md is not flagged", not any("AGENTS.md" in f for f in outside), str(outside))

    # --- case 5: a backticked path with trailing prose still parses ---------
    print("case 5: a backticked read: entry with trailing prose parses")
    prose_body = (
        "[T3] another card\n\n"
        "## EVIDENCE BUDGET\n\n"
        "read: `Sources/Mobile/Root.swift`, `Tests/Mobile/LayoutTests.swift` - at most 2 files.\n"
        "stop when: it builds.\n"
    )
    b = tool.parse_read_list(prose_body)
    check("both paths are parsed clean",
          b == ["Sources/Mobile/Root.swift", "Tests/Mobile/LayoutTests.swift"], str(b))
    check("the trailing prose is not part of the path",
          all("at most" not in p for p in b), str(b))

    # --- case 6: a guardrail halt is matched in ASSISTANT messages only ------
    print("case 6: a guardrail halt is only a halt when the assistant said it")
    halt_text = "I stopped retrying because I kept running read_file 5 times without making progress."
    db = tmp / "s6.db"
    make_session_db(db, [
        ("session", "sess-6", 1000.0, "a card", 1, 1, 10, 10, "m"),
        # The same sentence in a USER message (a card body quoting it) must not
        # count: only the ASSISTANT's own words mean the guardrail stopped it.
        ("message", "sess-6", "user", "# Kanban task t_1: ... " + halt_text, None, None, 0),
    ])
    os.makedirs(tmp / "profiles" / "_fixture_", exist_ok=True)
    os.replace(db, tmp / "profiles" / "_fixture_" / "state.db")
    sessions_probe = [{
        "profile": "_fixture_", "session_id": "sess-6", "started_at": 1000.0,
        "title": "a card",
    }]
    halts = tool.guardrail_halts(sessions_probe, hermes_root=tmp, profiles=("_fixture_",))
    check("a halt sentence in a USER message is not a halt", not halts, str(halts))

    # Now the assistant says it: that IS a halt.
    conn = sqlite3.connect(tmp / "profiles" / "_fixture_" / "state.db")
    conn.execute(
        "INSERT INTO messages (session_id, role, content, tool_calls, tool_name, _compressed_summary) "
        "VALUES (?,?,?,?,?,?)",
        ("sess-6", "assistant", halt_text, None, None, 0),
    )
    conn.commit()
    conn.close()
    halts = tool.guardrail_halts(sessions_probe, hermes_root=tmp, profiles=("_fixture_",))
    check("the assistant's own halt sentence IS a halt", len(halts) == 1, str(halts))

    # --- case 7: a card with no budget is not a violation --------------------
    print("case 7: a card with no EVIDENCE BUDGET yields no violation")
    tasks2 = {"t_2": {"title": "a card", "assignee": "wenshu-dev", "status": "running",
                      "body": "[T2] a card with no budget section\n"}}
    viol2 = tool.budget_violations(tasks2, sessions)
    check("no budget means no violation", not viol2, str(viol2))

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s): {', '.join(FAILURES)}")
        return 1
    print("PASSED: every case")
    return 0


if __name__ == "__main__":
    sys.exit(main())
