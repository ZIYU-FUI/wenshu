"""THE FILE-OWNERSHIP GATE: two live cards may not write one file.

WHY THIS FILE EXISTS

`wave_gate.py` already reads two cards' bodies, finds the files both of
them write, and prints the overlap. It answers the question AFTER the
wave starts: the dispatcher has already spawned both workers, both are
holding the same file in two worktrees, and the second one to land
conflicts with the first one at merge time (= a rebase, then a re-read,
then a review card that names a new sha, then a second landing).

The report existed and nobody read it in time, so the collision was
knowable at dispatch time and the cards still went out. That is the gap
this gate closes: it answers the same question with the same vocabulary,
but it answers it for ONE card at a time, so it can be called from the
moment a card is typed, and it EXITS NON-ZERO when the card collides.

THE VOCABULARY IS wave_gate.py's

The set of files a card writes, and the set it is told to leave, are
read by `wave_gate.files_of`. A second copy of that reader would be a
second answer to the same question (= exactly the failure this wave is
about), so this file imports the reader and adds no second one.

A FILE WITH A MERGE DRIVER IS NOT A COLLISION

`Scripts/merge-xcstrings.py` and `Scripts/merge-nfi-registry.py` merge
their files at the key level, so two cards that both write the string
catalog keep their own rows and the overlap is not a conflict. A file
whose driver is only DECLARED (= the repo says it has one, and the local
config has not installed it) IS a collision, because git has no driver to
run there: the two cards' texts would meet in a normal merge.

WHAT THIS GATE READS

The board's own database, read-only, so the answer does not depend on a
`hermes kanban list` whose output format the CLI may change. A card's
body is read from the `tasks` table; the card's status decides whether it
is LIVE (= it can still land and still collide).

EXIT CODES

    0   the card owns every file it writes (= no live card writes them too)
    1   the card collides with a live card (= the card must not be
        dispatched until the collision is resolved)
    2   the board could not be read (= the gate says so; it never answers
        "clean" from an empty read)
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import product_lines  # noqa: E402  (sibling module, same directory)
import wave_gate  # noqa: E402  (sibling module, same directory)

# The statuses a card can still LAND from. A card that is done, archived or
# blocked-out cannot collide with anything: it will not merge again.
LANDABLE_STATUSES = ("todo", "scheduled", "ready", "running", "review", "blocked", "triage")


def board_db_path(board: str = product_lines.DEFAULT_BOARD) -> Path | None:
    """The board's database file, or None when it cannot be found.

    The path comes from `product_lines.board_db`, so every gate that reads
    the board reads the same file: a gate with its own copy of the lookup
    is a gate that can read a different board than the gate beside it.
    """
    candidate = Path(product_lines.board_db(board))
    return candidate if candidate.is_file() else None


def _connect(path: Path) -> sqlite3.Connection:
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=30)


def read_cards(conn: sqlite3.Connection) -> list[dict]:
    """Every card on the board as {id, status, title, body}.

    The board's own column names are read, not assumed: the `tasks` table
    carries `id` (= the card id), `status`, `title` and `body`. A board
    whose `tasks` table does not carry those columns yields cards with
    empty bodies, and the gate then refuses to answer, because a card it
    could not read is a card it cannot clear.
    """
    columns = {
        str(row[1])
        for row in conn.execute("PRAGMA table_info(tasks)").fetchall()
    }
    wanted = [name for name in ("id", "status", "title", "body") if name in columns]
    sql = "SELECT " + ", ".join(wanted) + " FROM tasks"
    rows = conn.execute(sql).fetchall()
    cards = []
    for row in rows:
        values = dict(zip(wanted, row))
        cards.append(
            {
                "id": str(values.get("id") or ""),
                "status": str(values.get("status") or ""),
                "title": str(values.get("title") or ""),
                "body": str(values.get("body") or ""),
            }
        )
    return cards


def driver_status(path: str) -> str:
    """How a file's merge driver stands: "wired", "declared" or "none".

    A "declared" driver means the repo's `.gitattributes` names a driver
    the local git config has not installed, so a merge there runs as a
    normal merge and the overlap IS a conflict.
    """
    if wave_gate.driver_for(path):
        return "wired"
    if wave_gate.driver_unwired(path):
        return "declared"
    return "none"


def collisions_for(
    card: dict, others: list[dict]
) -> list[dict]:
    """The live cards that write a file this card writes.

    A file whose driver is WIRED is not a collision: the driver merges it
    at the key level, so both cards keep their row.
    """
    written, _forbidden = wave_gate.files_of(card.get("body") or "")
    if not written:
        return []
    found = []
    for other in others:
        if other["id"] == card["id"]:
            continue
        if other["status"] not in LANDABLE_STATUSES:
            continue
        other_written, _ = wave_gate.files_of(other.get("body") or "")
        shared = sorted(f for f in written & other_written if driver_status(f) == "none")
        if shared:
            found.append({"card": other["id"], "status": other["status"], "files": shared})
    return found


# The contract epoch. A card created before this date is reported, never
# blocked: the cards already on the board were typed under the old rule,
# and the collision between two of them is a fact of history rather than a
# contract this wave can rewrite (= the same shape as
# effort_budget_gate.EVIDENCE_CONTRACT_FROM).
OWNERSHIP_CONTRACT_FROM = 1795449600  # 2026-11-24 00:00 CST


def is_subject(created_at: int | None) -> bool:
    """Is this card under the ownership contract?

    A card with no creation time is treated as a subject: a card the board
    cannot date is a card the board cannot excuse.
    """
    if created_at is None:
        return True
    return int(created_at) >= OWNERSHIP_CONTRACT_FROM


def contract_errors(
    card: dict, board: str = product_lines.DEFAULT_BOARD
) -> list[str]:
    """Every live card this card's files would collide with.

    The card is read from the board, so the answer is about the board as it
    stands: two live cards writing one file is a collision at the moment
    the second one is typed, and it stays one until the first lands or is
    archived.
    """
    db = board_db_path(board)
    if db is None:
        return []
    try:
        conn = _connect(db)
    except sqlite3.Error:
        return []
    try:
        cards = read_cards(conn)
    except sqlite3.Error:
        return []
    finally:
        conn.close()

    rows = collisions_for(card, cards)
    if not rows:
        return []
    errors = []
    for row in rows:
        files = ", ".join(row["files"])
        errors.append(
            f"the card writes {files}, which the live card {row['card']} "
            f"(status {row['status']}) also writes: two live cards cannot "
            "write one file, so they cannot land in any order"
        )
    return errors


def check(card_id: str, board: str = product_lines.DEFAULT_BOARD) -> dict:
    """The verdict for one card: its collisions, and the files it owns."""
    db = board_db_path(board)
    if db is None:
        return {"error": f"the board {board} could not be read", "card": card_id}
    try:
        conn = _connect(db)
    except sqlite3.Error as exc:
        return {"error": f"the board {board} could not be opened: {exc}", "card": card_id}
    try:
        cards = read_cards(conn)
    except sqlite3.Error as exc:
        return {"error": f"the board {board} could not be read: {exc}", "card": card_id}
    finally:
        conn.close()

    card = next((c for c in cards if c["id"] == card_id), None)
    if card is None:
        return {"error": f"the card {card_id} is not on the board {board}", "card": card_id}

    written, forbidden = wave_gate.files_of(card.get("body") or "")
    collisions = collisions_for(card, cards)
    return {
        "card": card_id,
        "board": board,
        "status": card["status"],
        "written": sorted(written),
        "forbidden": sorted(forbidden),
        "collisions": collisions,
        "clean": not collisions,
    }


def print_report(report: dict) -> None:
    if report.get("error"):
        print(f"ownership: {report['error']}")
        return
    print(f"card: {report['card']}  (status {report['status']})")
    print(f"files it writes: {len(report['written'])}")
    for path in report["written"]:
        print(f"  {path}")
    if report["collisions"]:
        print(f"COLLISIONS: {len(report['collisions'])}")
        for row in report["collisions"]:
            print(f"  {report['card']} and {row['card']} both write:")
            for path in row["files"]:
                print(f"    {path}")
        return
    print("collisions: 0  (= every file this card writes is its own)")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("card", help="the card id to check")
    ap.add_argument("--board", default=product_lines.DEFAULT_BOARD)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    report = check(args.card, args.board)
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        print_report(report)
    if report.get("error"):
        return 2
    return 0 if report.get("clean") else 1


if __name__ == "__main__":
    raise SystemExit(main())
