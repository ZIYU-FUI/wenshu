"""The two new gates, seen from the card contract's own path.

`ticket_tier.find_contract_errors` is what a card passes before it goes
out. This suite proves that the two gates this wave adds are ON that path,
and that each one fires for its own reason:

1. the plan-of-record gate: a card that names a scope whose plan is
   incomplete is a contract error (= the card promises a plan and the plan
   is not there)
2. the plan-of-record gate stays quiet for a card that names NO scope (= a
   bug fix and a review card are not a plan's business)
3. the file-ownership gate: a card that writes a file a live card also
   writes is a contract error (= two live cards cannot land in any order)
4. the file-ownership gate stays quiet when the other card is done (= a
   done card will not land again)
5. both gates are off for a card created before the contract epoch (= the
   cards already on the board are not this wave's business)
6. the hand-off gate refuses a card a review lane created for an implementer
   (= the finding restated in a card the board cannot spawn), and it is
   wired into the same card contract

The gates' OWN suites prove their answers; this suite proves the wiring.
"""

from __future__ import annotations

import sqlite3
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import ownership_gate  # noqa: E402
import plan_gate  # noqa: E402
import review_handoff_gate  # noqa: E402
import ticket_tier  # noqa: E402

FAILURES: list[str] = []

# The epoch's one second before, and one second after, so the two cases
# are the SAME card with a different creation time.
BEFORE = plan_gate.PLAN_CONTRACT_FROM - 1
AFTER = plan_gate.PLAN_CONTRACT_FROM + 1


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}  {detail}")
        FAILURES.append(name)


def card(body: str, created_at: int = AFTER, card_id: str = "t_new") -> dict:
    return {
        "id": card_id,
        "title": "[T1][build] a card",
        "status": "ready",
        "body": body,
        "created_at": created_at,
        "max_runtime_seconds": 900,
    }


def make_board(directory: Path, cards: list[dict]) -> Path:
    db = directory / "kanban.db"
    conn = sqlite3.connect(db)
    conn.execute("CREATE TABLE tasks (id TEXT, status TEXT, title TEXT, body TEXT)")
    conn.executemany(
        "INSERT INTO tasks (id, status, title, body) VALUES (?, ?, ?, ?)",
        [
            (
                c["id"],
                c["status"],
                c.get("title", ""),
                c.get("body", ""),
            )
            for c in cards
        ],
    )
    conn.commit()
    conn.close()
    return db


def body_writing(path: str) -> str:
    return f"""## WHAT TO BUILD

Change {path} so the gate can see it.

## ACCEPTANCE

- {path} carries the change
"""


def with_board(cards: list[dict], fn) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        db = make_board(Path(tmp), cards)
        original = ownership_gate.board_db_path
        ownership_gate.board_db_path = lambda board="wenshu-par": db
        try:
            fn()
        finally:
            ownership_gate.board_db_path = original


def main() -> int:
    print("the two gates on the card contract's path")

    # --- case 1: a card naming an INCOMPLETE plan ---------------------
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        scope_dir = repo / ".scratch" / "a-scope"
        (scope_dir / "issues").mkdir(parents=True)
        (scope_dir / "spec.md").write_text("# only a title\n", encoding="utf-8")
        (scope_dir / "issues" / "001-one.md").write_text("x\n", encoding="utf-8")
        # no _index.md, and the spec has none of the four sections
        body = "## WHAT TO BUILD\n\nSee .scratch/a-scope/spec.md\n"
        errors = plan_gate.contract_errors(body, repo=repo)
        check(
            "case 1: a card naming an incomplete plan is a contract error",
            any("incomplete" in e for e in errors),
            str(errors),
        )

    # --- case 2: a card naming NO scope is quiet ----------------------
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        errors = plan_gate.contract_errors(
            "## WHAT TO BUILD\n\nFix the thing.\n", repo=repo
        )
        check(
            "case 2: a card naming no scope is not a plan's business",
            errors == [],
            str(errors),
        )

    # --- case 3: a COMPLETE plan is quiet -----------------------------
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        scope_dir = repo / ".scratch" / "b-scope"
        (scope_dir / "issues").mkdir(parents=True)
        (scope_dir / "spec.md").write_text(
            "## Business\n\nx\n\n## Current state\n\nx\n\n"
            "## Apple canonical\n\nx\n\n## After fix\n\nx\n",
            encoding="utf-8",
        )
        (scope_dir / "issues" / "001-one.md").write_text("x\n", encoding="utf-8")
        (scope_dir / "issues" / "_index.md").write_text(
            "| Issue | State | Blocked by |\n| --- | --- | --- |\n"
            "| 001-one | new | - |\n",
            encoding="utf-8",
        )
        errors = plan_gate.contract_errors(
            "## WHAT TO BUILD\n\nSee .scratch/b-scope/spec.md\n", repo=repo
        )
        check(
            "case 3: a card naming a complete plan is clean",
            errors == [],
            str(errors),
        )

    # --- case 4: two live cards writing one file ----------------------
    with_board(
        [
            {
                "id": "t_other",
                "status": "ready",
                "body": body_writing("Tools/wenshu-devtool/shared.py"),
            }
        ],
        lambda: check(
            "case 4: a card writing a file a live card also writes is an error",
            any("also writes" in e for e in ownership_gate.contract_errors(
                card(body_writing("Tools/wenshu-devtool/shared.py"))
            )),
            str(ownership_gate.contract_errors(
                card(body_writing("Tools/wenshu-devtool/shared.py"))
            )),
        ),
    )

    # --- case 5: the other card is DONE -------------------------------
    with_board(
        [
            {
                "id": "t_other",
                "status": "done",
                "body": body_writing("Tools/wenshu-devtool/finished.py"),
            }
        ],
        lambda: check(
            "case 5: a done card cannot collide",
            ownership_gate.contract_errors(
                card(body_writing("Tools/wenshu-devtool/finished.py"))
            )
            == [],
            str(ownership_gate.contract_errors(
                card(body_writing("Tools/wenshu-devtool/finished.py"))
            )),
        ),
    )

    # --- case 6: both gates are OFF before the epoch ------------------
    with_board(
        [
            {
                "id": "t_other",
                "status": "ready",
                "body": body_writing("Tools/wenshu-devtool/shared.py"),
            }
        ],
        lambda: check(
            "case 6: a pre-epoch card is reported, never blocked",
            ownership_gate.is_subject(BEFORE) is False
            and plan_gate.is_subject(BEFORE) is False
            and ownership_gate.is_subject(AFTER) is True
            and plan_gate.is_subject(AFTER) is True,
            "the epoch gate does not separate the two sides",
        ),
    )

    # --- case 7: ticket_tier CALLS the two gates ----------------------
    with_board(
        [
            {
                "id": "t_other",
                "status": "ready",
                "body": body_writing("Tools/wenshu-devtool/shared.py"),
            }
        ],
        lambda: check(
            "case 7: ticket_tier's contract path reaches the ownership gate",
            any(
                "also writes" in e
                for e in ticket_tier.find_contract_errors(
                    card(body_writing("Tools/wenshu-devtool/shared.py"))
                )
            ),
            str(
                ticket_tier.find_contract_errors(
                    card(body_writing("Tools/wenshu-devtool/shared.py"))
                )
            ),
        ),
    )

    # --- case 6: the hand-off contract -------------------------------
    # = = = A card the review lane created for an implementer is the = = =
    # = = = finding done twice: once in the verdict, and once in a card = = =
    # = = = the board cannot spawn (= the dispatcher spawns only the = = =
    # = = = review profile). = = =
    handoff_card = card("## WHAT TO BUILD\n\nA rework of the review's finding.\n")
    handoff_card["created_by"] = "wenshu-review"
    handoff_card["assignee"] = "pocock"
    errors = review_handoff_gate.contract_errors(handoff_card)
    check(
        "case 6: a review-lane card for an implementer is a contract error",
        any("restates a verdict" in e for e in errors),
        str(errors),
    )
    wired = ticket_tier.find_contract_errors(handoff_card)
    check(
        "case 6: the hand-off gate is wired into the card contract",
        any("restates a verdict" in e for e in wired),
        str(wired),
    )
    own_card = card("## WHAT TO BUILD\n\nA rework of the review's finding.\n")
    own_card["created_by"] = "wenshu-review"
    own_card["assignee"] = "wenshu-review"
    check(
        "case 6: a review card for the review lane is quiet",
        review_handoff_gate.contract_errors(own_card) == [],
        str(review_handoff_gate.contract_errors(own_card)),
    )
    check(
        "case 6: the hand-off gate is off for a card created before the epoch",
        not review_handoff_gate.is_subject(
            review_handoff_gate.HANDOFF_CONTRACT_FROM - 1
        ),
        True,
    )
    check(
        "case 6: the hand-off gate is on for a card created after the epoch",
        review_handoff_gate.is_subject(
            review_handoff_gate.HANDOFF_CONTRACT_FROM + 1
        ),
        True,
    )

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s): {FAILURES}")
        return 1
    print("the two gates on the card contract's path: every case passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
