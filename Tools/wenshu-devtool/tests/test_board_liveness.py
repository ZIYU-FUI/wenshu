#!/usr/bin/env python3
"""test_board_liveness.py — the board liveness checker's own test suite.

Every case runs on a FIXTURE: a temporary board directory with a temporary
kanban.db, plus a temporary profile log tree. Proving the checker fails never
touches the real board.

The cases are the two things the checker got wrong:

  1. A card whose worker IS working must NOT be reported as idle. The
     measured 2026-10-28 failure was the reverse (a working card was
     reclaimed as "no agent attached"), so the false-idle direction is the
     dangerous one: it costs a restart.
  2. A card whose claim heartbeats but whose worker never made an API call
     IS idle (= it holds a host slot with nobody on it). The checker must
     say so, and must exit non-zero.

Plus the mechanics around them:

  3. a card with a FRESH api call is `working`, one with an OLD api call is
     `stale`, and `calls=1` is not by itself a death signal;
  4. a card whose agent session cannot be resolved is `no-agent`;
  5. a card whose run began seconds ago and has NOT made its first api call
     is `starting`, NOT `slot-only` (= the worker is booting; calling it idle
     would invite a reclaim of a healthy worker);
  6. the tool never writes to the board (read-only);
  7. the tool works when HERMES_HOME points at a PROFILE (the boards live
     under the global home, not under the profile) — this is the bug the
     first run of the tool hit.

Run:  python3 Tools/wenshu-devtool/tests/test_board_liveness.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "board_liveness.py"

FAILURES: list[str] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    if ok:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}  {detail}")
        FAILURES.append(name)


def make_board(root: Path, board: str = "wenshu-par", started_at: float | None = None) -> Path:
    """A board dir with a kanban.db holding one running card."""
    bdir = root / "kanban" / "boards" / board
    bdir.mkdir(parents=True, exist_ok=True)
    db = bdir / "kanban.db"
    conn = sqlite3.connect(db)
    conn.executescript(
        """
        CREATE TABLE tasks (
            id TEXT PRIMARY KEY, status TEXT, assignee TEXT,
            title TEXT, body TEXT, created_at REAL, current_run_id INTEGER);
        CREATE TABLE task_runs (
            id INTEGER PRIMARY KEY, task_id TEXT, started_at REAL,
            ended_at REAL, outcome TEXT, error TEXT);
        CREATE TABLE task_events (
            id INTEGER PRIMARY KEY, task_id TEXT, kind TEXT, payload TEXT);
        """
    )
    conn.execute(
        "INSERT INTO tasks VALUES ('t_ok','running','wenshu-dev','a card','body',0,9001)")
    conn.execute(
        "INSERT INTO task_runs VALUES (9001,'t_ok',?,NULL,NULL,NULL)",
        (started_at if started_at is not None else __import__("time").time() - 600.0,),
    )
    conn.execute(
        "INSERT INTO task_events VALUES (1,'t_ok','owner_admitted',?)",
        (json.dumps({"session_id": "local-sess-live"}),),
    )
    conn.commit()
    conn.close()
    return db


def write_log(root: Path, session: str, when: float, calls: int) -> None:
    """A profile agent.log with `calls` API-call lines for `session`."""
    log = root / "profiles" / "wenshu-dev" / "logs" / "agent.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    import time as _t
    stamp = _t.strftime("%Y-%m-%d %H:%M:%S", _t.localtime(when))
    with log.open("a") as fh:
        for n in range(1, calls + 1):
            fh.write(
                f"{stamp} [{session}] API call #{n}: model=MiniMax-M3.1-Flash in=10 out=10\n"
            )


def run_tool(root: Path, extra: list[str] | None = None) -> tuple[int, str]:
    env = dict(os.environ)
    env["HERMES_HOME"] = str(root)
    env.pop("HERMES_KANBAN_BOARDS", None)
    cmd = [sys.executable, str(TOOL), *(extra or [])]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=120)
    return r.returncode, r.stdout + r.stderr


def main() -> int:
    import time as _t
    now = _t.time()

    # ---- case 1 & 2: working vs slot-only -----------------------------
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root)
        # the worker IS working: an api call 10 seconds ago
        write_log(root, "local-sess-live", now - 10, calls=3)
        code, out = run_tool(root)
        check("a working card is not reported idle", code == 0, f"exit={code}\n{out}")
        check("a working card says 'working'", "working" in out, out)
        check("a working card is not called slot-only", "slot-only" not in out, out)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root)
        # the worker made NO api call: heartbeats only
        log = root / "profiles" / "wenshu-dev" / "logs" / "agent.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        stamp = _t.strftime("%Y-%m-%d %H:%M:%S", _t.localtime(now))
        log.write_text(f"{stamp} [local-sess-live] heartbeat ok\n")
        code, out = run_tool(root)
        check("a slot-only card is reported idle", "slot-only" in out, out)
        check("a slot-only card exits non-zero", code == 2, f"exit={code}\n{out}")

    # ---- case 2b: a FRESH worker is 'starting', not 'slot-only' -------
    # Measured 2026-10-29: a card dispatched 1 minute earlier read
    # 'slot-only' (0 api calls) and 25 s later read 'working' with 5 calls.
    # Calling a booting worker 'slot-only' invites a reclaim of a healthy
    # worker = the exact damage this tool exists to prevent.
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root, started_at=now - 30.0)
        log = root / "profiles" / "wenshu-dev" / "logs" / "agent.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        stamp = _t.strftime("%Y-%m-%d %H:%M:%S", _t.localtime(now))
        log.write_text(f"{stamp} [local-sess-live] heartbeat ok\n")
        code, out = run_tool(root)
        check("a booting worker says 'starting'", "starting" in out, out)
        check("a booting worker is NOT called slot-only", "slot-only" not in out, out)
        check("a booting card exits zero", code == 0, f"exit={code}\n{out}")

    # the same card, PAST the grace window, IS slot-only
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root, started_at=now - 3600.0)
        log = root / "profiles" / "wenshu-dev" / "logs" / "agent.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        stamp = _t.strftime("%Y-%m-%d %H:%M:%S", _t.localtime(now))
        log.write_text(f"{stamp} [local-sess-live] heartbeat ok\n")
        code, out = run_tool(root)
        check("past the grace window it is slot-only again", "slot-only" in out, out)
        check("past the grace window it exits non-zero", code == 2, f"exit={code}\n{out}")

    # an explicit --grace of 0 makes a booting worker count as slot-only
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root, started_at=now - 30.0)
        log = root / "profiles" / "wenshu-dev" / "logs" / "agent.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        stamp = _t.strftime("%Y-%m-%d %H:%M:%S", _t.localtime(now))
        log.write_text(f"{stamp} [local-sess-live] heartbeat ok\n")
        code, out = run_tool(root, ["--grace", "0"])
        check("--grace 0 disables the booting window", "slot-only" in out, out)

    # ---- case 3: fresh vs stale ---------------------------------------
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root)
        write_log(root, "local-sess-live", now - 3600, calls=1)
        code, out = run_tool(root, ["--fresh", "300"])
        check("an old api call is 'stale', not 'working'", "stale" in out, out)
        check("a stale card is not called slot-only", "slot-only" not in out, out)

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root)
        write_log(root, "local-sess-live", now - 3600, calls=1)
        code, out = run_tool(root, ["--fresh", "7200"])
        check("a wide --fresh window makes it working again", "working" in out, out)

    # ---- case 4: no resolvable session --------------------------------
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root)
        code, out = run_tool(root)
        check("a card with no api traffic at all is no-agent/slot-only",
              ("no-agent" in out) or ("slot-only" in out), out)

    # ---- case 5: read-only ---------------------------------------------
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        db = make_board(root)
        before = db.read_bytes()
        run_tool(root)
        check("the board file is untouched", db.read_bytes() == before)

    # ---- case 6: HERMES_HOME pointing at a profile ---------------------
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        make_board(root)
        write_log(root, "local-sess-live", now - 10, calls=2)
        profhome = root / "profiles" / "pocock"
        profhome.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ)
        env["HERMES_HOME"] = str(profhome)
        env.pop("HERMES_KANBAN_BOARDS", None)
        r = subprocess.run([sys.executable, str(TOOL)], capture_output=True,
                           text=True, env=env, timeout=120)
        out = r.stdout + r.stderr
        check("a profile HERMES_HOME still finds the boards",
              "working" in out and "no boards dir" not in out, out)

    print()
    if FAILURES:
        print(f"{len(FAILURES)} case(s) failed: {', '.join(FAILURES)}")
        return 1
    print("all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
