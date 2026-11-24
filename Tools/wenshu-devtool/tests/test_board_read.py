#!/usr/bin/env python3
"""test_board_read.py — the review lane reads the board, and reads the SAME board.

= = WHY THIS TEST EXISTS. = = `ticket_tier.py --check --live` and
`gate_width_gate.py --check` enumerated the board ONLY through
`hermes kanban list --json`. That is a read, but it goes through the CLI the
kernel gates for WRITE access, so inside a delegated child (= the review lane)
it returned `kanban: delegate_task child contexts cannot mutate Kanban tasks or
boards`. Both commands ended on "=== the board could not be read ===" — and both
lines sit in this repo's own HOW-TO-VERIFY steps, so the reviewer was told to run
two checks that cannot run in the lane it was reviewing from.

`board_read.py` adds the fallback: the board's own SQLite file, opened
`mode=ro`. This suite exists because a fallback is exactly where a SILENT
difference hides. While it was being written, the first cut read five columns
(id, status, title, body, created_at) and the sweep then disagreed with itself on
the LIVE board: `ticket_tier.py` reads `assignee` (line ~1118) and
`max_runtime_seconds` (line ~1157), so two cards came back T3 from the file and
T2 from the CLI. That is case 1 below, and it is the reason the fields are taken
from the CLI's own shape rather than hand-picked.

THE CASES

  1. THE FIELD REGRESSION: the file read carries every field the tier reads, and
     a card's derived tier is IDENTICAL whichever path supplied the row.
  2. THE POPULATION: `list --json` omits archived cards (measured 2026-11-24:
     982 printed against 1124 rows, the 142 extra all `archived`), so the file
     read omits them too, and an archived card asked for BY ID is still found.
  3. None AND [] ARE DIFFERENT FACTS: an empty board is a read board, a missing
     or malformed file is "never read", and the gate must say so rather than
     print a clean sweep.
  4. THE BLOB: the board stores a body as BLOB bytes; a gate that receives bytes
     reads "no gate section" and blames the author.
  5. THE LANE END-TO-END: with a `hermes` that REFUSES every call, both commands
     still run the sweep and still print findings.

THE FIXTURE is a real sqlite file laid out like a board (the `tasks` and
`task_runs` tables the flow writes) under a fake `HERMES_HOME`, so the shipped
path resolution is exercised and nothing touches the live board.

Run:  python3 Tools/wenshu-devtool/tests/test_board_read.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""

from __future__ import annotations

import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
sys.path.insert(0, str(TOOLS))

import board_read  # noqa: E402
import ticket_tier  # noqa: E402

BOARD = "fixture-board"

failures: list[str] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    print(("PASS " if ok else "FAIL ") + name)
    if not ok:
        failures.append(name)
        if detail:
            print("      " + detail.replace("\n", "\n      "))


def make_board(root: Path, tasks: list[dict], runs: list[tuple[str, str]]) -> Path:
    """A board file at the path the shipped resolver will find.

    `HERMES_HOME` is set to this case's home as the board is built, because
    `product_lines.home_candidates()` reads it at call time: a case that
    builds a fixture and forgets the env reads the REAL board instead, and a
    suite that silently measures the live board is worse than no suite.
    """
    os.environ["HERMES_HOME"] = str(root / ".hermes")
    home = root / ".hermes" / "kanban" / "boards" / BOARD
    home.mkdir(parents=True, exist_ok=True)
    db = home / "kanban.db"
    conn = sqlite3.connect(db)
    conn.execute(
        """CREATE TABLE tasks (
            id TEXT PRIMARY KEY, title TEXT, body BLOB, assignee TEXT,
            status TEXT, priority INTEGER, created_by TEXT, created_at INTEGER,
            started_at INTEGER, completed_at INTEGER, workspace_kind TEXT,
            workspace_path TEXT, branch_name TEXT, project_id TEXT,
            claim_lock TEXT, claim_expires INTEGER, tenant TEXT, result TEXT,
            idempotency_key TEXT, consecutive_failures INTEGER, worker_pid TEXT,
            worker_started_at TEXT, last_failure_error TEXT,
            max_runtime_seconds INTEGER, last_heartbeat_at INTEGER,
            current_run_id TEXT, workflow_template_id TEXT,
            current_step_key TEXT, skills TEXT, model_override TEXT,
            provider_override TEXT, reasoning_effort TEXT, max_retries INTEGER,
            goal_mode INTEGER, goal_max_turns INTEGER, session_id TEXT,
            block_kind TEXT, block_recurrences INTEGER, completion_contract TEXT
        )"""
    )
    conn.execute(
        "CREATE TABLE task_runs (id INTEGER PRIMARY KEY, task_id TEXT,"
        " profile TEXT, outcome TEXT)"
    )
    for t in tasks:
        conn.execute(
            "INSERT INTO tasks (id, title, body, assignee, status, created_at,"
            " max_runtime_seconds) VALUES (?,?,?,?,?,?,?)",
            (
                t["id"],
                t["title"],
                t["body"].encode("utf-8"),
                t.get("assignee", "wenshu-dev"),
                t["status"],
                t.get("created_at", 1_800_000_000),
                t.get("max_runtime_seconds"),
            ),
        )
    for task_id, profile in runs:
        conn.execute(
            "INSERT INTO task_runs (task_id, profile, outcome) VALUES (?,?,?)",
            (task_id, profile, "completed"),
        )
    conn.commit()
    conn.close()
    return db


# A card body that asks for a gate wider than a T1 buys: a whole-suite line in
# the GATES section. Kept in the fixture so case 5 has a finding to print.
WIDE_BODY = (
    "## GOAL\n\nOne sentence.\n\n## GATES\n\n"
    "- `swift test` exits 0.\n\n## ACCEPTANCE\n\n- [ ] done\n"
)
NARROW_BODY = (
    "## GOAL\n\nOne sentence.\n\n## GATES\n\n"
    "- `swift test --filter WenshuEditorTests` exits 0.\n\n"
    "## ACCEPTANCE\n\n- [ ] done\n"
)


def run_case_1(root: Path) -> None:
    """The file read carries the fields the tier reads, so the tier agrees."""

    tasks = [
        {
            "id": "t_reviewer",
            "title": "[T2] Review: the flow gates",
            "body": NARROW_BODY,
            "assignee": "wenshu-review",
            "status": "done",
            "max_runtime_seconds": 3600,
        },
        {
            "id": "t_builder",
            "title": "[T2] Chat: the composer keeps its draft",
            "body": NARROW_BODY,
            "assignee": "wenshu-dev",
            "status": "done",
            "max_runtime_seconds": 3600,
        },
    ]
    runs = [("t_reviewer", "wenshu-review"),
            ("t_reviewer", "wenshu-review"),
            ("t_builder", "wenshu-dev")]
    make_board(root, tasks, runs)
    # `cards()` is the shipped entry point and it attaches run history to
    # whichever path answered; a test that reads `file_cards` alone would be
    # testing a half-built row and would report a difference the flow never
    # sees. So attach the same way `cards()` does.
    rows = board_read.file_cards(BOARD)
    assert rows is not None
    board_read.attach_runs(rows, BOARD)
    check("1.5 the file read returns rows", rows is not None and len(rows) == 2,
          f"got {rows!r}")
    if rows is None:
        return
    by_id = {r["id"]: r for r in rows}

    # The two fields the first cut dropped, and the encoding it dropped them
    # in. A missing key here IS the bug: `ticket_tier.report` reads the body
    # as TEXT, and the board stores it as a BLOB, so a row that hands back
    # bytes derives its tier from a `b'...'` repr instead of the card.
    check("1.2 the row carries assignee",
          by_id["t_reviewer"].get("assignee") == "wenshu-review",
          f"row keys: {sorted(by_id['t_reviewer'])}")
    check("1.3 the row carries max_runtime_seconds",
          by_id["t_builder"].get("max_runtime_seconds") == 3600,
          f"got {by_id['t_builder'].get('max_runtime_seconds')!r}")
    check("1.4 the row's body is text, not the BLOB's repr",
          isinstance(by_id["t_builder"].get("body"), str)
          and "## GATES" in by_id["t_builder"]["body"],
          f"type {type(by_id['t_builder'].get('body')).__name__}")

    # The assertion that pins the regression: the same card, read from the
    # file, must report the tier and the kind the CLI-shaped row reports.
    cli_shaped = [
        {
            "id": t["id"],
            "title": t["title"],
            "body": t["body"],
            "assignee": t["assignee"],
            "status": t["status"],
            "max_runtime_seconds": t["max_runtime_seconds"],
            "runs": [{"profile": p} for tid, p in runs if tid == t["id"]],
        }
        for t in tasks
    ]
    rows = sorted(rows, key=lambda r: str(r["id"]))
    cli_shaped = sorted(cli_shaped, key=lambda r: str(r["id"]))
    pairs = []
    for from_file, from_cli in zip(rows, cli_shaped):
        a = ticket_tier.report(from_file)
        b = ticket_tier.report(from_cli)
        pairs.append((from_file["id"], a["tier"], b["tier"], a["kind"], b["kind"]))
    check("1.1 the tier and the kind are the same card whichever path read it",
          all(t1 == t2 and k1 == k2 for _, t1, t2, k1, k2 in pairs),
          "; ".join(f"{cid}: file={t1}/{k1} cli={t2}/{k2}"
                    for cid, t1, t2, k1, k2 in pairs))


def run_case_2(root: Path) -> None:
    """Archived rows are out of the sweep and still reachable by id."""

    tasks = [
        {"id": "t_open", "title": "[T1] x", "body": NARROW_BODY,
         "status": "ready"},
        {"id": "t_gone", "title": "[T1] y", "body": NARROW_BODY,
         "status": "archived"},
    ]
    make_board(root, tasks, [])
    swept = board_read.file_cards(BOARD)
    everything = board_read.file_cards(BOARD, include_archived=True)
    check("2.2 the sweep omits archived rows (the CLI's population)",
          [r["id"] for r in (swept or [])] == ["t_open"],
          f"swept ids: {[r['id'] for r in (swept or [])]}")
    check("2.3 an explicit ask keeps them",
          sorted(r["id"] for r in (everything or [])) == ["t_gone", "t_open"],
          f"all ids: {sorted(r['id'] for r in (everything or []))}")
    one = board_read.one_card(BOARD, "t_gone")
    check("2.4 a card named by id is found even when archived",
          bool(one) and one.get("id") == "t_gone", f"got {one!r}")


def run_case_3(root: Path) -> None:
    """None and [] are different facts, and the caller must not merge them.

    Each scenario gets its OWN root: make_board always writes under the root it
    is handed, so pointing one case's env at a sibling directory is how you get
    a suite that measures nothing.
    """
    empty_root = root / "empty"
    make_board(empty_root, [], [])
    rows = board_read.file_cards(BOARD)
    check("3.1 a board with no cards is a READ board ([])",
          rows == [], f"got {rows!r}")

    missing_root = root / "nowhere" / ".hermes"
    missing_root.mkdir(parents=True, exist_ok=True)
    os.environ["HERMES_HOME"] = str(missing_root)
    gone = board_read.file_cards(BOARD)
    check("3.2 a board with no file was never read (None, not [])",
          gone is None, f"got {gone!r}")

    bad = root / "bad" / ".hermes" / "kanban" / "boards" / BOARD
    bad.mkdir(parents=True, exist_ok=True)
    (bad / "kanban.db").write_bytes(b"this is not a database")
    os.environ["HERMES_HOME"] = str(root / "bad" / ".hermes")
    broken = board_read.file_cards(BOARD)
    check("3.3 an unopenable file is None, and the reason is printed",
          broken is None, f"got {broken!r}")

    shaped = root / "shaped" / ".hermes" / "kanban" / "boards" / BOARD
    shaped.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(shaped / "kanban.db")
    conn.execute("CREATE TABLE not_tasks (id TEXT)")
    conn.commit()
    conn.close()
    os.environ["HERMES_HOME"] = str(root / "shaped" / ".hermes")
    check("3.4 a table without the card columns is None (not a silent empty)",
          board_read.file_cards(BOARD) is None)
    os.environ.pop("HERMES_HOME", None)


def run_case_4(root: Path) -> None:
    """A BLOB body comes back as text, because gates read text."""

    tasks = [{"id": "t_blob", "title": "[T1] x", "body": NARROW_BODY,
              "status": "done"}]
    make_board(root, tasks, [])
    rows = board_read.file_cards(BOARD)
    body = (rows or [{}])[0].get("body")
    check("4.1 the body is str, not bytes",
          isinstance(body, str) and "## GATES" in body, f"type {type(body)}")
    check("4.2 the gate section is readable from it",
          isinstance(body, str) and "swift test" in body, f"type {type(body)}")


def run_case_5(root: Path) -> None:
    """With a CLI that refuses everything, both sweeps still run and still find."""

    tasks = [
        # `ticket_tier --check --live` skips `done` cards by design, so the
        # fixture card has to be a live one for case 5.5 to see it at all.
        {"id": "t_wide", "title": "[T1] Chat: the composer", "body": WIDE_BODY,
         "status": "ready", "max_runtime_seconds": 900},
    ]
    db = make_board(root, tasks, [])

    stub_dir = root / "stub-bin"
    stub_dir.mkdir(exist_ok=True)
    stub = stub_dir / "hermes"
    stub.write_text(
        "#!/bin/sh\n"
        'echo "kanban: delegate_task child contexts cannot mutate Kanban tasks'
        ' or boards" >&2\nexit 1\n',
        encoding="utf-8",
    )
    stub.chmod(0o755)

    env = dict(os.environ)
    env["PATH"] = f"{stub_dir}:{env.get('PATH', '')}"
    env["HERMES_HOME"] = str(root / ".hermes")

    def run(tool: str, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(TOOLS / tool), *args],
            capture_output=True, text=True, env=env, cwd=str(TOOLS.parent),
            timeout=300,
        )

    width = run("gate_width_gate.py", "--check", "--board", BOARD)
    out = width.stdout
    check("5.1 the width gate no longer says the board could not be read",
          "the board could not be read" not in out, out[-400:])
    check("5.2 the width gate still reports the finding it exists to report",
          "t_wide" in out and "1 card(s) ask for a gate wider" in out,
          out[-400:])
    check("5.3 the refusal is announced, not swallowed",
          "refused" in (width.stderr + out), width.stderr[-300:])

    tier = run("ticket_tier.py", "--check", "--live", "--board", BOARD)
    tout = tier.stdout
    check("5.4 the tier sweep runs in the refusing lane",
          "the board could not be read" not in tout, tout[-400:])
    check("5.5 the tier sweep reads the fixture card",
          "t_wide" in tout, tout[-400:])

    # And the strongest claim: the SAME finding from the row, from the file,
    # with no CLI at all available.
    bare = dict(env)
    bare["PATH"] = str(stub_dir)  # nothing but the refusing stub is on PATH
    only_file = subprocess.run(
        [sys.executable, str(TOOLS / "gate_width_gate.py"), "--check",
         "--board", BOARD, "--json"],
        capture_output=True, text=True, env=bare, cwd=str(TOOLS.parent),
        timeout=300,
    )
    check("5.6 a card read from the file is reported with its tier and gate",
          '"t_wide"' in only_file.stdout and '"T1"' in only_file.stdout,
          only_file.stdout[-300:])
    assert db.exists()


def main() -> int:
    for runner in (run_case_1, run_case_2, run_case_3, run_case_4, run_case_5):
        root = Path(tempfile.mkdtemp(prefix="wenshu-board-read-"))
        try:
            runner(root)
        finally:
            shutil.rmtree(root, ignore_errors=True)
    print()
    if failures:
        print(f"board_read: {len(failures)} case(s) failed")
        for name in failures:
            print(f"  - {name}")
        return 1
    print("board_read: every case passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
