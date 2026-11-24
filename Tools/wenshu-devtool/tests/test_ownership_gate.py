"""The ownership gate's own cases.

The gate answers one question: may this card be dispatched, given that
another live card already writes one of its files? The cases below prove
the answer for the cases that decide it:

1. a card alone owns its files (= clean)
2. a card that collides with a live card is REFUSED (= exit 1)
3. a card that collides with a DONE card is clean (= a done card will not
   land again, so it cannot conflict)
4. a file with a WIRED merge driver is not a collision (= the driver merges
   it at the key level)
5. a file whose driver is only DECLARED IS a collision (= git has no
   driver to run there)
6. a card that the board does not carry is an ERROR (= the gate never says
   "clean" about a card it could not read)
7. a board that cannot be read is an ERROR (= an empty read is not a clean
   bill of health)
"""

from __future__ import annotations

import sqlite3
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import ownership_gate  # noqa: E402
import wave_gate  # noqa: E402

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}  {detail}")
        FAILURES.append(name)


def body_writing(path: str) -> str:
    return f"""## WHAT TO BUILD

Change {path} so the gate can see it.

## ACCEPTANCE

- {path} carries the change
"""


def make_board(directory: Path, cards: list[dict]) -> Path:
    db = directory / "kanban.db"
    conn = sqlite3.connect(db)
    conn.execute(
        "CREATE TABLE tasks (id TEXT, status TEXT, title TEXT, body TEXT)"
    )
    conn.executemany(
        "INSERT INTO tasks (id, status, title, body) VALUES (?, ?, ?, ?)",
        [
            (c["id"], c["status"], c.get("title", ""), c.get("body", ""))
            for c in cards
        ],
    )
    conn.commit()
    conn.close()
    return db


def with_board(cards: list[dict], fn) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        db = make_board(directory, cards)
        original = ownership_gate.board_db_path
        ownership_gate.board_db_path = lambda board="wenshu-par": db
        try:
            fn()
        finally:
            ownership_gate.board_db_path = original


def main() -> int:
    print("ownership gate")

    # --- case 1: a card alone owns its files --------------------------
    with_board(
        [
            {
                "id": "t_alone",
                "status": "ready",
                "body": body_writing("Tools/wenshu-devtool/only_mine.py"),
            }
        ],
        lambda: check(
            "case 1: a card that writes a file no other card writes is clean",
            ownership_gate.check("t_alone")["clean"] is True,
            str(ownership_gate.check("t_alone")),
        ),
    )

    # --- case 2: a collision with a LIVE card is refused --------------
    with_board(
        [
            {
                "id": "t_first",
                "status": "ready",
                "body": body_writing("Tools/wenshu-devtool/shared.py"),
            },
            {
                "id": "t_second",
                "status": "ready",
                "body": body_writing("Tools/wenshu-devtool/shared.py"),
            },
        ],
        lambda: check(
            "case 2: two live cards writing one file is a collision",
            ownership_gate.check("t_second")["clean"] is False
            and ownership_gate.check("t_second")["collisions"][0]["card"] == "t_first",
            str(ownership_gate.check("t_second")),
        ),
    )

    # --- case 3: a collision with a DONE card is not a collision ------
    with_board(
        [
            {
                "id": "t_done",
                "status": "done",
                "body": body_writing("Tools/wenshu-devtool/finished.py"),
            },
            {
                "id": "t_next",
                "status": "ready",
                "body": body_writing("Tools/wenshu-devtool/finished.py"),
            },
        ],
        lambda: check(
            "case 3: a done card cannot collide (= it will not land again)",
            ownership_gate.check("t_next")["clean"] is True,
            str(ownership_gate.check("t_next")),
        ),
    )

    # --- case 4 and 5: the merge driver decides -----------------------
    catalog = "Sources/WenshuApp/Resources/Localizable.xcstrings"
    with_board(
        [
            {
                "id": "t_catalog_a",
                "status": "ready",
                "body": body_writing(catalog),
            },
            {
                "id": "t_catalog_b",
                "status": "ready",
                "body": body_writing(catalog),
            },
        ],
        lambda: check(
            "case 4/5: the driver decides (= a wired driver merges, a declared one does not)",
            ownership_gate.driver_status(catalog) in ("wired", "declared")
            and (
                ownership_gate.check("t_catalog_b")["clean"]
                is (ownership_gate.driver_status(catalog) == "wired")
            ),
            f"driver status = {ownership_gate.driver_status(catalog)}",
        ),
    )

    # --- case 6: a card the board does not carry ----------------------
    with_board(
        [{"id": "t_here", "status": "ready", "body": body_writing("a.py")}],
        lambda: check(
            "case 6: a card that is not on the board is an error, never clean",
            "error" in ownership_gate.check("t_missing"),
            str(ownership_gate.check("t_missing")),
        ),
    )

    # --- case 7: a board that cannot be read --------------------------
    original = ownership_gate.board_db_path
    ownership_gate.board_db_path = lambda board="wenshu-par": None
    try:
        report = ownership_gate.check("t_any")
        check(
            "case 7: a board that cannot be read is an error, never clean",
            "error" in report and report.get("clean") is not True,
            str(report),
        )
    finally:
        ownership_gate.board_db_path = original

    # --- case 8: the reader is wave_gate's, not a second one ---------
    check(
        "case 8: the written-file set comes from wave_gate's reader (= one answer)",
        ownership_gate.wave_gate is wave_gate,
        "the gate imported a different reader",
    )

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s): {FAILURES}")
        return 1
    print("ownership gate: every case passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
