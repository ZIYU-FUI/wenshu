#!/usr/bin/env python3
"""test_session_effort_audit.py — the session audit tool's own test suite.

The cases are the ways a session burns tokens without producing anything,
each one measured on board wenshu-par, 2026-10-27:

  1. a call is a write by its TOOL identity, not by its text.
  2. a terminal call counts only when it commits.
  3. an execute_code call never counts as a write on its source text.
  4. a history call is a call against the worker's own past, not a
     `git worktree list`.
  5. a session with writes is "producing".
  6. a session with no writes and many history calls is "looking".
  7. a session with no writes and many repeats is "stuck".
  8. a session with no calls at all is "idle".
  9. a goal's area is the third segment of a Sources path.
 10. a goal naming a single file is not an area.
 11. a fan-out with 2x overlap and a cold-cache child is "duplicated".
 12. a fan-out with no overlap and no cold child is "clean".

Run:  python3 Tools/wenshu-devtool/tests/test_session_effort_audit.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "session_effort_audit.py"

spec = importlib.util.spec_from_file_location("session_effort_audit", TOOL)
assert spec is not None and spec.loader is not None
sea = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sea)


def case(name: str, ok: bool, detail: str = "") -> bool:
    print(f"{'PASS' if ok else 'FAIL'}  {name}")
    if not ok and detail:
        print(f"      {detail}")
    return ok


def report(**kwargs) -> dict:
    """A report dict shaped like the one the auditor returns."""
    base = {
        "calls": 10,
        "reads": 5,
        "history": 0,
        "writes": 0,
        "restarts": 0,
        "repeats": 0,
    }
    base.update(kwargs)
    return base


def fanout(**kwargs) -> dict:
    """A fan-out report dict shaped like the one the auditor returns."""
    base = {
        "children": 2,
        "parent_model": "M",
        "waste_factor": 1.0,
        "total_reads": 10,
        "distinct_files": 10,
        "duplicate_goals": 0,
        "delegated_goals": 4,
        "repeated_scopes": [],
        "cold_cache_children": 0,
    }
    base.update(kwargs)
    return base


def main() -> int:
    results: list[bool] = []

    # 1. a write is a write by its tool identity
    results.append(
        case(
            "write_file is a write",
            sea._is_write_call("write_file", '{"path": "a.swift"}') is True,
        )
    )
    results.append(
        case(
            "patch is a write",
            sea._is_write_call("patch", '{"path": "a.swift"}') is True,
        )
    )

    # 2. a terminal call counts only when it commits
    results.append(
        case(
            "a terminal call that commits is a write",
            sea._is_write_call("terminal", "git commit -m 'x'") is True,
        )
    )
    results.append(
        case(
            "a terminal call that only reads is not a write",
            sea._is_write_call("terminal", "git status && git log") is False,
        )
    )

    # 3. the text of a query is not a write
    results.append(
        case(
            "an execute_code call that mentions write_file is not a write",
            sea._is_write_call("execute_code", "print('write_file')") is False,
        )
    )
    results.append(
        case(
            "a read_file call is not a write",
            sea._is_write_call("read_file", '{"path": "a.swift"}') is False,
        )
    )

    # 4. a history call is a call against the worker's own past
    results.append(
        case(
            "a session_search call is a history call",
            sea._is_history_call("session_search", '{"query": "x"}') is True,
        )
    )
    results.append(
        case(
            "a query against state.db is a history call",
            sea._is_history_call("execute_code", "sqlite3 state.db select") is True,
        )
    )
    results.append(
        case(
            "git worktree list is not a history call",
            sea._is_history_call("terminal", "git worktree list") is False,
        )
    )
    results.append(
        case(
            "reading a source file is not a history call",
            sea._is_history_call("read_file", '{"path": "a.swift"}') is False,
        )
    )

    # 5-8. the verdict order
    verdict, _ = sea._verdict(report(calls=0))
    results.append(case("a session with no calls is idle", verdict == "idle", verdict))

    verdict, _ = sea._verdict(report(writes=3))
    results.append(case("a session with writes is producing", verdict == "producing", verdict))

    verdict, _ = sea._verdict(report(writes=0, history=86))
    results.append(case("a session with no writes and many history calls is looking", verdict == "looking", verdict))

    verdict, _ = sea._verdict(report(writes=0, history=0, repeats=113, restarts=4))
    results.append(case("a session with no writes and many repeats is stuck", verdict == "stuck", verdict))

    # a session with writes AND many history calls is still producing
    verdict, _ = sea._verdict(report(writes=1, history=86))
    results.append(
        case("writes outrank history in the verdict", verdict == "producing", verdict)
    )

    # 9-10. the area a goal names
    area = sea._goal_scope("Read every file in Sources/WenshuApp/Features/Editor/ and report")
    results.append(
        case(
            "a goal's area is the third segment of a Sources path",
            area == "Sources/WenshuApp/Features/Editor",
            area,
        )
    )
    area = sea._goal_scope("Read Sources/WenshuApp/Features/Library/, Backup/, Outline/")
    results.append(
        case(
            "a goal naming sibling features lands on one area",
            area == "Sources/WenshuApp/Features/Library",
            area,
        )
    )
    area = sea._goal_scope("Fix Sources/WenshuApp/Features/Editor/EditorView.swift")
    results.append(
        case(
            "a goal naming a single file is not an area",
            area != "Sources/WenshuApp/Features/Editor/EditorView.swift",
            area,
        )
    )

    # 11-12. the fan-out verdict
    verdict, why = sea._fanout_verdict(
        fanout(waste_factor=3.42, duplicate_goals=11, repeated_scopes=["a", "b"], cold_cache_children=11)
    )
    results.append(
        case(
            "a fan-out with overlap and a cold cache is duplicated",
            verdict == "duplicated" and "3.42x" in why and "11 of 2 children" in why,
            f"{verdict}: {why}",
        )
    )
    verdict, _ = sea._fanout_verdict(fanout())
    results.append(case("a fan-out with no overlap is clean", verdict == "clean", verdict))

    failed = results.count(False)
    print()
    print(f"{len(results) - failed}/{len(results)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
