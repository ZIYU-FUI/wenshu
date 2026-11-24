#!/usr/bin/env python3
"""review_handoff_gate.py — THE VERDICT IS THE HAND-OFF (= the card is not).

One question, one gate:

  CONTRACT  does a review-lane card hand its verdict to a profile the board
            can actually spawn?

WHY THE GATE EXISTS (measured on board wenshu-par, 2026-11-24):

  - The board's dispatcher spawns ONLY the profiles in `kanban.dispatch_profiles`
    (= `[wenshu-review]`), and it records `skipped_nonspawnable` on every
    card addressed to anyone else.
  - The review lane nevertheless creates cards addressed to the implementer
    profile (= `pocock`, `wenshu-dev`): 41 of them, 28 done + 9 archived for
    `pocock` and 4 archived for `wenshu-dev`.
  - So the reviewer states the finding TWICE: once in the verdict, and once
    in a card that can never move. The person who could act on it was waiting
    for the verdict, and the verdict was already written.

  = = The verdict IS the hand-off (= = AGENTS.md 1.14), = = so a card that
  cannot be spawned is the FINDING DONE TWICE, = = and the duplicate is what
  the gate names.

WHAT IT PRINTS, per card:

    <id>  <title>
        creator=<profile>  assignee=<profile>  status=<status>
        parent=<review card id>  verdict=<approved|changes_requested|none>
        skipped_nonspawnable=<n>   (= the board's own record that it cannot move)

  The verdict is read from the PARENT card's run metadata
  (`review_outcome`), = = because the parent is the review card the
  implementer card answered. = = A card with no parent, or a parent with no
  verdict, says so instead of guessing.

WHAT IT DOES NOT DO (= = the two things this wave is not allowed to do):

  - it does NOT change `kanban.dispatch_profiles` (= = the boss's config), and
  - it does NOT delete a card (= = the card is the record of what the
    reviewer did).

  It REPORTS. = = Read-only: the board is opened with `mode=ro` and
  `query_only`, so the tool cannot write a board row even by accident.

Usage:
    python3 Tools/wenshu-devtool/review_handoff_gate.py
    python3 Tools/wenshu-devtool/review_handoff_gate.py --board-db PATH
    python3 Tools/wenshu-devtool/review_handoff_gate.py --json

Exit code 0 = no card a review lane created for an implementer, 1 = at least
one such card, 2 = the board could not be read.
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)

# The profiles that CREATE a review card (= = the review lane).
REVIEW_PROFILES = ("wenshu-review",)

# The profiles that IMPLEMENT (= = the lane that never gets spawned here).
IMPLEMENTER_PROFILES = ("pocock", "wenshu-dev")

# The board's own record that a card cannot be moved.
SKIP_EVENT = "skipped_nonspawnable"


def board_db_path(board: str = "wenshu-par") -> Path:
    """The board's database file (= = the one the flow writes)."""
    return Path(product_lines.board_db(board))


def _read_only(path: Path) -> sqlite3.Connection:
    """The board, opened read-only.

    `mode=ro` is the wall (= = the file is opened without write permission),
    and `query_only` is the belt (= = every statement is refused, so a
    stray INSERT cannot land even if the URI were rewritten).
    """
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=1")
    return conn


def _table_names(conn: sqlite3.Connection) -> set[str]:
    rows = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
    return {str(r[0]) for r in rows}


def _run_metadata(raw) -> dict:
    """A run's metadata, whatever shape the column holds it in.

    The board stores `task_runs.metadata` as JSON TEXT (= = the CLI decodes
    it, the sqlite reader does not), and a few rows hold bytes. A verdict
    read out of a string would be no verdict at all.
    """
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, (bytes, bytearray)):
        raw = raw.decode("utf-8", "replace")
    if isinstance(raw, str) and raw.strip():
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            return {}
        return parsed if isinstance(parsed, dict) else {}
    return {}


def _verdicts_by_task(conn: sqlite3.Connection, task_ids: list[str]) -> dict[str, dict]:
    """The latest verdict of each task, read from its runs' metadata.

    A verdict is a completed run whose metadata carries `review_outcome`.
    The LATEST one wins (= = a re-review supersedes the verdict before it).
    """
    if not task_ids:
        return {}
    out: dict[str, dict] = {}
    marks = ",".join("?" for _ in task_ids)
    rows = conn.execute(
        "SELECT task_id, profile, metadata, ended_at, started_at FROM task_runs "
        f"WHERE outcome = 'completed' AND task_id IN ({marks})",
        task_ids,
    ).fetchall()
    for row in rows:
        metadata = _run_metadata(row["metadata"])
        outcome = metadata.get("review_outcome")
        if outcome not in ("approved", "changes_requested"):
            continue
        when = row["ended_at"] or row["started_at"] or 0
        prior = out.get(row["task_id"])
        if prior is None or when >= prior["when"]:
            out[row["task_id"]] = {
                "verdict": outcome,
                "profile": row["profile"],
                "when": when,
            }
    return out


def collect(conn: sqlite3.Connection) -> dict:
    """The report: every card a review lane created for an implementer."""
    tables = _table_names(conn)
    reviews = ",".join("?" for _ in REVIEW_PROFILES)
    implementers = ",".join("?" for _ in IMPLEMENTER_PROFILES)
    cards = conn.execute(
        "SELECT id, title, created_by, assignee, status, created_at FROM tasks "
        f"WHERE created_by IN ({reviews}) AND assignee IN ({implementers}) "
        "ORDER BY created_at, id",
        (*REVIEW_PROFILES, *IMPLEMENTER_PROFILES),
    ).fetchall()

    ids = [str(r["id"]) for r in cards]
    parents: dict[str, list[str]] = {}
    if "task_links" in tables and ids:
        marks = ",".join("?" for _ in ids)
        for row in conn.execute(
            f"SELECT child_id, parent_id FROM task_links WHERE child_id IN ({marks})",
            ids,
        ).fetchall():
            parents.setdefault(str(row["child_id"]), []).append(str(row["parent_id"]))

    parent_ids = sorted({p for ps in parents.values() for p in ps})
    verdicts = _verdicts_by_task(conn, parent_ids)

    skips: dict[str, int] = {}
    if "task_events" in tables and ids:
        marks = ",".join("?" for _ in ids)
        for row in conn.execute(
            f"SELECT task_id, COUNT(*) AS n FROM task_events "
            f"WHERE kind = ? AND task_id IN ({marks}) GROUP BY task_id",
            (SKIP_EVENT, *ids),
        ).fetchall():
            skips[str(row["task_id"])] = int(row["n"])

    rows = []
    for card in cards:
        card_id = str(card["id"])
        card_parents = parents.get(card_id, [])
        verdict = None
        verdict_profile = None
        for parent in card_parents:
            rec = verdicts.get(parent)
            if rec is None:
                continue
            if verdict is None or rec["when"] >= verdict[0]:
                verdict = (rec["when"], rec["verdict"])
                verdict_profile = rec["profile"]
        rows.append({
            "id": card_id,
            "title": card["title"],
            "creator": card["created_by"],
            "assignee": card["assignee"],
            "status": card["status"],
            "created_at": card["created_at"],
            "parents": card_parents,
            "parent": card_parents[0] if card_parents else None,
            "verdict": verdict[1] if verdict else None,
            "verdict_profile": verdict_profile,
            "skipped_nonspawnable": skips.get(card_id, 0),
        })

    return {
        "review_profiles": list(REVIEW_PROFILES),
        "implementer_profiles": list(IMPLEMENTER_PROFILES),
        "cards": len(rows),
        "rows": rows,
    }


def print_report(report: dict, db: Path) -> None:
    """The text report: one card per block, then the count."""
    print(f"review-handoff: board {db}")
    print(f"  review lane: {', '.join(report['review_profiles'])} | "
          f"implementer lane: {', '.join(report['implementer_profiles'])}")
    print(f"  cards a review lane created for an implementer (= the board cannot "
          f"spawn them): {report['cards']}")
    if report["cards"] == 0:
        print("  ok: every review-lane card is addressed to a spawnable profile")
        return
    for row in report["rows"]:
        print(f"  {row['id']}  {row['title']}")
        print(f"      creator={row['creator']}  assignee={row['assignee']}  "
              f"status={row['status']}")
        verdict = row["verdict"] or "none (= the parent card carries no verdict)"
        print(f"      parent={row['parent'] or 'none'}  verdict={verdict}"
              + (f" (from {row['verdict_profile']})" if row["verdict_profile"] else ""))
        print(f"      skipped_nonspawnable={row['skipped_nonspawnable']} "
              f"(= the board's own record that this card cannot move)")
    print(f"  these cards restate a verdict the board already holds; the verdict "
          f"is the hand-off (= = AGENTS.md 1.14), and the move is the boss's call")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board-db", default=None,
                    help="the board's database file (default: the flow's board)")
    ap.add_argument("--board", default="wenshu-par", help="board slug (default: wenshu-par)")
    ap.add_argument("--json", action="store_true", help="print the report as JSON")
    args = ap.parse_args(argv)

    db = Path(args.board_db) if args.board_db else board_db_path(args.board)
    if not db.exists():
        print(f"no board database at {db}", file=sys.stderr)
        return 2
    try:
        conn = _read_only(db)
    except sqlite3.Error as exc:
        print(f"could not open the board: {exc}", file=sys.stderr)
        return 2
    try:
        report = collect(conn)
    except sqlite3.Error as exc:
        print(f"could not read the board: {exc}", file=sys.stderr)
        return 2
    finally:
        conn.close()

    report["board_db"] = str(db)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=1))
    else:
        print_report(report, db)
    return 1 if report["cards"] else 0


if __name__ == "__main__":
    sys.exit(main())
