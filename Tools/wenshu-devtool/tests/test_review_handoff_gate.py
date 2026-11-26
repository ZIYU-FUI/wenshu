#!/usr/bin/env python3
"""test_review_handoff_gate.py — the review hand-off gate's own test suite.

Every case runs on a FIXTURE: a temporary board with a temporary kanban.db
holding the two kinds of card (= = a review-lane card addressed to an
implementer, and a review-lane card addressed to itself). Proving the gate
detects the defect never touches the real board, and the suite stays valid
when the real board's contents change.

The cases are the ways the gate can be wrong:

  1. a review-lane card addressed to an implementer IS the defect (= = it is
     found, and the run exits 1).
  2. a review-lane card addressed to ITSELF is not the defect (= = the
     review lane's own card is spawnable, and it is not counted).
  3. a card an implementer created for an implementer is not the defect
     (= = the creator is what makes the card a review-lane card).
  4. the verdict printed is the PARENT card's verdict (= = the review card
     the implementer card answered), read from the run metadata.
  5. a card with no parent prints no parent and no verdict, and does not
     crash.
  6. the newest verdict wins (= = a re-review supersedes the verdict before
     it).
  7. the count is printed whether the gate finds cards or not, and the exit
     code follows it (= = 1 with cards, 0 without).
  8. --json carries the same numbers the text report prints.
  9. the gate NEVER writes to the board (= = the database file is byte-for-
     byte the same after a run, and the connection is opened read-only).
 10. the card's own status and title are carried into the report.

Run:  python3 Tools/wenshu-devtool/tests/test_review_handoff_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import json
import sqlite3
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "review_handoff_gate.py"

spec = importlib.util.spec_from_file_location("review_handoff_gate", TOOL)
assert spec is not None and spec.loader is not None
rhg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rhg)

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    if got == want:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        FAILURES.append(name)


SCHEMA = """
CREATE TABLE tasks (
    id TEXT PRIMARY KEY, title TEXT, body TEXT, assignee TEXT,
    status TEXT, created_by TEXT, created_at INTEGER);
CREATE TABLE task_runs (
    id INTEGER PRIMARY KEY, task_id TEXT, profile TEXT, status TEXT,
    outcome TEXT, metadata TEXT, started_at INTEGER, ended_at INTEGER);
CREATE TABLE task_links (parent_id TEXT, child_id TEXT);
CREATE TABLE task_events (
    id INTEGER PRIMARY KEY, task_id TEXT, kind TEXT, payload TEXT,
    created_at INTEGER);
"""


def make_board(path: Path) -> None:
    """A board whose tables match the real board's shape."""
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA)
    conn.commit()
    conn.close()


def add_card(conn, cid, title, creator, assignee, status="done", created_at=1):
    conn.execute(
        "INSERT INTO tasks VALUES (?,?,?,?,?,?,?)",
        (cid, title, "body", assignee, status, creator, created_at),
    )


def add_run(conn, task_id, profile, outcome, metadata, ended_at, run_id=1):
    conn.execute(
        "INSERT INTO task_runs VALUES (?,?,?,?,?,?,?,?)",
        (run_id, task_id, profile, "done", outcome,
         json.dumps(metadata) if metadata is not None else None, ended_at, ended_at),
    )


def add_link(conn, parent_id, child_id):
    conn.execute("INSERT INTO task_links VALUES (?,?)", (parent_id, child_id))


def add_event(conn, task_id, kind, payload=None):
    conn.execute(
        "INSERT INTO task_events (task_id, kind, payload, created_at) VALUES (?,?,?,?)",
        (task_id, kind, json.dumps(payload or {}), 1),
    )


def read_report(db: Path) -> dict:
    """The gate's own report over a fixture board."""
    conn = rhg._read_only(db)
    try:
        return rhg.collect(conn)
    finally:
        conn.close()


def run_tool(db: Path, extra: list[str] | None = None) -> tuple[int, str]:
    import subprocess
    cmd = [sys.executable, str(TOOL), "--board-db", str(db), *(extra or [])]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return r.returncode, r.stdout + r.stderr


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        db = Path(td) / "kanban.db"
        make_board(db)
        conn = sqlite3.connect(db)
        # the review lane's OWN card (= = addressed to itself, spawnable)
        add_card(conn, "t_self", "review the tip", "wenshu-review", "wenshu-review")
        # the review lane's card addressed to an implementer (= = the defect)
        add_card(conn, "t_defect", "fix the finding", "wenshu-review", "pocock")
        # an implementer's card for an implementer (= = not a review card)
        add_card(conn, "t_impl", "do the work", "pocock", "wenshu-dev")
        # the parent review card the defect card answered
        add_card(conn, "t_parent", "the review", "pocock", "wenshu-review")
        add_link(conn, "t_parent", "t_defect")
        add_run(conn, "t_parent", "wenshu-review", "completed",
                {"review_outcome": "changes_requested"}, 100)
        add_event(conn, "t_defect", "skipped_nonspawnable", {"assignee": "pocock"})
        add_event(conn, "t_defect", "skipped_nonspawnable", {"assignee": "pocock"})
        conn.commit()
        conn.close()

        report = read_report(db)

        # ---- case 1: the defect is found --------------------------------
        check("the review-lane card for an implementer is found",
              report["cards"], 1)
        row = report["rows"][0]
        check("the found card is the defect card", row["id"], "t_defect")
        check("the creator is read from the board", row["creator"], "wenshu-review")
        check("the assignee is read from the board", row["assignee"], "pocock")
        check("the status is read from the board", row["status"], "done")
        check("the title is read from the board", row["title"], "fix the finding")

        # ---- case 2 and 3: the shapes that are NOT the defect -----------
        check("a review-lane card addressed to itself is not the defect",
              [r["id"] for r in report["rows"]], ["t_defect"])
        check("a card an implementer created is not the defect",
              "t_impl" in [r["id"] for r in report["rows"]], False)

        # ---- case 4: the parent's verdict -------------------------------
        check("the parent's verdict is read", row["verdict"], "changes_requested")
        check("the parent card is named", row["parent"], "t_parent")
        check("the verdict's profile is read", row["verdict_profile"], "wenshu-review")
        check("the board's own skip record is counted",
              row["skipped_nonspawnable"], 2)

        # ---- case 7: the count and the exit code ------------------------
        code, out = run_tool(db)
        check("a board with the defect exits 1", code, 1)
        check("the count is printed", "cards a review lane created for an implementer "
              "(= the finding stated twice): 1" in out, True)
        check("the verdict is printed", "verdict=changes_requested" in out, True)
        check("the card is named", "t_defect" in out, True)

        # ---- case 8: --json carries the same numbers --------------------
        code, out = run_tool(db, ["--json"])
        check("the json run exits 1", code, 1)
        payload = json.loads(out)
        check("the json count matches", payload["cards"], 1)
        check("the json verdict matches", payload["rows"][0]["verdict"],
              "changes_requested")
        check("the json row carries the assignee",
              payload["rows"][0]["assignee"], "pocock")

        # ---- case 9: the gate never writes ------------------------------
        before = db.read_bytes()
        run_tool(db)
        check("the board file is untouched", db.read_bytes(), before)

    # ---- case 5: a card with no parent ---------------------------------
    with tempfile.TemporaryDirectory() as td:
        db = Path(td) / "kanban.db"
        make_board(db)
        conn = sqlite3.connect(db)
        add_card(conn, "t_orphan", "no parent", "wenshu-review", "pocock")
        conn.commit()
        conn.close()
        report = read_report(db)
        row = report["rows"][0]
        check("a card with no parent is still found", report["cards"], 1)
        check("a card with no parent names no parent", row["parent"], None)
        check("a card with no parent has no verdict", row["verdict"], None)
        code, out = run_tool(db)
        check("a parentless card does not crash the run", code, 1)
        check("a parentless card says so", "parent=none" in out, True)

    # ---- case 6: the newest verdict wins -------------------------------
    with tempfile.TemporaryDirectory() as td:
        db = Path(td) / "kanban.db"
        make_board(db)
        conn = sqlite3.connect(db)
        add_card(conn, "t_defect", "fix it", "wenshu-review", "pocock")
        add_card(conn, "t_parent", "the review", "pocock", "wenshu-review")
        add_link(conn, "t_parent", "t_defect")
        add_run(conn, "t_parent", "wenshu-review", "completed",
                {"review_outcome": "changes_requested"}, 100, run_id=1)
        add_run(conn, "t_parent", "wenshu-review", "completed",
                {"review_outcome": "approved"}, 200, run_id=2)
        conn.commit()
        conn.close()
        report = read_report(db)
        check("the newest verdict wins", report["rows"][0]["verdict"], "approved")

    # ---- case 7b: a clean board exits 0 and prints its count -----------
    with tempfile.TemporaryDirectory() as td:
        db = Path(td) / "kanban.db"
        make_board(db)
        conn = sqlite3.connect(db)
        add_card(conn, "t_self", "review the tip", "wenshu-review", "wenshu-review")
        conn.commit()
        conn.close()
        code, out = run_tool(db)
        check("a board without the defect exits 0", code, 0)
        check("the zero count is printed",
              "cards a review lane created for an implementer (= the finding "
              "stated twice): 0" in out, True)

    # ---- a missing board is exit 2, not a crash -----------------------
    code, out = run_tool(Path("/nonexistent/kanban.db"))
    check("a missing board exits 2", code, 2)
    check("a missing board says so", "no board database" in out, True)

    print()
    if FAILURES:
        print(f"{len(FAILURES)} case(s) failed: {', '.join(FAILURES)}")
        return 1
    print("all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
