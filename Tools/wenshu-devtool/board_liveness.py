#!/usr/bin/env python3
"""Is a card's worker actually WORKING, or is it just holding a host slot?

WHY THIS EXISTS
---------------
A kanban card's `status='running'` means a CLAIM exists, not that an agent is
doing work. Measured 2026-10-28 on `wenshu-mob-par`: card `t_8a0fc144` sat
`running` for 32 minutes (run 7) with heartbeats flowing the whole time, and
another session read that as "the claim is holding a host slot but no agent is
attached" and reclaimed it. The diagnosis was WRONG: that session made 18 API
calls between 22:13:27 and 22:44:45. The work was fine; the reclaim threw it
away and the card started from scratch.

The signal that separates the two is the agent's own API traffic: a worker
that is working logs `API call #N` continuously; a worker that holds a claim
without an agent logs heartbeats and NOTHING else.

WHAT IT PRINTS
--------------
One line per running card:

    <task-id>  <assignee>  <board>  <api-calls>  <last-api>  <age>  VERDICT

VERDICT is one of:
    working   - an API call within --fresh seconds
    stale     - the worker HAS made API calls, but the last one is older than
                --fresh seconds (= it may be mid-turn; NOT idle)
    starting  - the run began within --grace seconds (default 180) and has
                NOT made its first API call yet (= the worker is booting; NOT
                idle). A fresh worker needs time to come up, and calling it
                'slot-only' would invite a reclaim of a healthy worker.
    slot-only - the worker never made an API call AT ALL, and the run has been
                alive longer than --grace: the claim is holding a host slot
                and NOBODY is working on it
    no-agent  - no agent session could be resolved for the card at all

USAGE
-----
    python3 Tools/wenshu-devtool/board_liveness.py
    python3 Tools/wenshu-devtool/board_liveness.py --board wenshu-mob-par --fresh 180

READ-ONLY: it opens every database with mode=ro and writes nothing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

HERMES_HOME = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
# The BOARDS live under the GLOBAL hermes home (the default profile's), not
# under the profile that happens to be running this script. A worker profile's
# HERMES_HOME points at .../profiles/<name>, and .../profiles/<name>/kanban
# does not exist. Resolve the global home by walking up out of a profile dir.
def _global_home() -> Path:
    home = HERMES_HOME
    if home.parent.name == "profiles":
        home = home.parent.parent
    return home


BOARDS_DIR = Path(os.environ.get("HERMES_KANBAN_BOARDS", _global_home() / "kanban" / "boards"))
PROFILES = ("wenshu-dev", "wenshu-review", "pocock", "default")

# "2026-10-28 22:49:11" -> epoch, in LOCAL time (the logs are local).
_TS_RE = re.compile(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)")
# The session id is normally hex, but do not assume it: match the id as the
# opaque token it is. (A too-narrow class silently reports every card as
# idle = the failure mode this whole tool exists to prevent.)
_API_RE = re.compile(r"\[(local-[0-9A-Za-z_-]+)\].*API call #")
_PID_RE = re.compile(r"\[(local-[0-9a-f]+)\]")


def _parse_ts(stamp: str) -> float | None:
    m = _TS_RE.match(stamp.strip())
    if not m:
        return None
    return time.mktime(time.strptime(m.group(1), "%Y-%m-%d %H:%M:%S"))


def _scan_profile_logs() -> dict[str, dict]:
    """session_id -> {last_api_epoch, api_calls} over the WHOLE log.

    The scan deliberately does NOT filter by the `--fresh` threshold. That
    threshold is a CLASSIFICATION input, not a scan input: if the scan
    dropped the calls older than `--fresh`, then a worker that was busy an
    hour ago and has been quiet since would look exactly like a worker that
    never started (= "slot-only"). That is the false-idle reading this tool
    exists to prevent, so it must not manufacture it.

    `slot-only` therefore means what it says: this session made NO api call
    AT ALL.
    """
    out: dict[str, dict] = {}
    for profile in PROFILES:
        log = _global_home() / "profiles" / profile / "logs" / "agent.log"
        if not log.exists():
            continue
        try:
            with log.open("rb") as fh:
                fh.seek(0, os.SEEK_END)
                size = fh.tell()
                fh.seek(max(0, size - 16_000_000))
                tail = fh.read().decode("utf-8", "replace")
        except OSError:
            continue
        for line in tail.splitlines():
            if "API call #" not in line:
                continue
            m = _API_RE.search(line)
            if not m:
                continue
            ts = _parse_ts(line[:19])
            if ts is None:
                continue
            sid = m.group(1)
            rec = out.setdefault(sid, {"last_api": 0.0, "calls": 0})
            rec["calls"] += 1
            rec["last_api"] = max(rec["last_api"], ts)
    return out


def _card_session(conn: sqlite3.Connection, task_id: str) -> str | None:
    row = conn.execute(
        "SELECT payload FROM task_events "
        "WHERE task_id = ? AND kind = 'owner_admitted' ORDER BY id DESC LIMIT 1",
        (task_id,),
    ).fetchone()
    if not row:
        return None
    try:
        return json.loads(row[0]).get("session_id")
    except (ValueError, TypeError):
        return None


def _read_only(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=20)
    conn.execute("PRAGMA busy_timeout=15000")
    return conn


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board", default=None, help="board slug (default: every board)")
    ap.add_argument("--fresh", type=int, default=300,
                    help="seconds without an API call that still counts as 'working'")
    ap.add_argument("--grace", type=int, default=180,
                    help="seconds after a run starts during which ZERO api calls means "
                         "'starting', not 'slot-only' (a fresh worker needs time to boot)")
    args = ap.parse_args()

    if not BOARDS_DIR.is_dir():
        print(f"no boards dir at {BOARDS_DIR}", file=sys.stderr)
        return 1

    boards = [args.board] if args.board else sorted(
        p.name for p in BOARDS_DIR.iterdir() if (p / "kanban.db").exists()
    )

    api = _scan_profile_logs()
    now = time.time()
    any_slot_only = False

    for board in boards:
        db_path = BOARDS_DIR / board / "kanban.db"
        if not db_path.exists():
            continue
        conn = _read_only(db_path)
        try:
            rows = conn.execute(
                "SELECT t.id, t.assignee, t.title, r.started_at "
                "FROM tasks t JOIN task_runs r ON r.id = t.current_run_id "
                "WHERE t.status = 'running' ORDER BY t.id"
            ).fetchall()
        except sqlite3.Error:
            conn.close()
            continue
        if not rows:
            conn.close()
            continue
        print(f"\n=== {board} ===")
        for task_id, assignee, title, started_at in rows:
            sid = _card_session(conn, task_id)
            rec = api.get(sid) if sid else None
            run_age_s = now - (started_at or now)
            # A worker that was dispatched seconds ago has not made its first
            # api call yet: it is booting, not idling. Measured 2026-10-29: a
            # card 1 minute old read 'slot-only' and 25 s later read
            # 'working' with 5 calls. Calling that 'slot-only' would invite a
            # reclaim of a perfectly good worker -- the exact damage this
            # tool exists to prevent.
            starting = run_age_s <= args.grace
            if rec is None:
                # The session resolved but the agent made NO api call in the
                # window: the claim holds a host slot and nobody is working.
                # (A card whose session cannot be resolved at all is a
                # different problem = no-agent.)
                if starting:
                    verdict = "starting"
                else:
                    verdict = "slot-only" if sid else "no-agent"
                age = "?"
                calls = 0
                last = "(none)"
            else:
                calls = rec["calls"]
                age = f"{now - rec['last_api']:.0f}s"
                last = time.strftime("%H:%M:%S", time.localtime(rec["last_api"]))
                if calls == 0:
                    verdict = "starting" if starting else "slot-only"
                elif now - rec["last_api"] <= args.fresh:
                    verdict = "working"
                else:
                    verdict = "stale"
            if verdict in ("slot-only", "no-agent"):
                any_slot_only = True
            run_age = f"{run_age_s / 60:.0f}m"
            print(
                f"  {task_id:<14} {str(assignee):<13} calls={calls:<4} "
                f"last_api={last:<10} age={age:<7} run_age={run_age:<6} {verdict:<9} {str(title)[:34]}"
            )
        conn.close()

    if any_slot_only:
        print(
            "\nA 'slot-only' or 'no-agent' card is holding a host slot with no work.\n"
            "Do NOT reclaim it on that basis alone: reclaiming RESTARTS the card from\n"
            "scratch (the session's context is lost; only the worktree survives).\n"
            "Check the worker's own log first -- a worker that IS working makes API\n"
            "calls continuously and only the CLAIM looks idle from the board.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
