#!/usr/bin/env python3
"""review_handoff_gate.py — THE VERDICT IS THE HAND-OFF (= the card is not).

One question, one gate:

  CONTRACT  does a card restate a verdict the board already holds, or does an
            implementer file a card for itself?

WHY THE GATE EXISTS (measured on board wenshu-par, 2026-11-26):

  - The board's dispatcher spawns the profiles in `kanban.dispatch_profiles`,
    and it records `skipped_nonspawnable` on a card whose assignee names no
    profile on the home doing the dispatching.
  - = = THAT ALLOWLIST IS READ PER HOME, NOT PER BOARD. = = Measured
    2026-11-26: the key `dispatch_profiles` is declared in ONE home's config
    (= `/Users/anbaiqiang/.hermes/config.yaml` = `[wenshu-review]`), and
    ABSENT from the other two (= `pocock`, `wenshu-review` under
    `/Volumes/ANAN/.hermes/profiles/`). An absent key leaves the allowlist
    open (= = the dispatcher claims any profile that exists on that home).
    So a card addressed to `pocock` IS spawned by the pocock home's
    dispatcher: measured on the same board, 63 RUNS on the cards the review
    lane addressed to an implementer (= = `task_runs` joined to `tasks`
    where `tasks.created_by` = `wenshu-review` and `tasks.assignee` is
    `pocock` or `wenshu-dev`, = = every run ever started up to the window
    seal 1795683213), = = split BY THE PROFILE THAT RAN THEM: `pocock` 43,
    `wenshu-dev` 20. The split is by profile on purpose: = = a split by
    outcome is not a figure to publish (= = `outcome` has seven values on
    this population, = = and `completed` only ever grows, = = so any
    outcome split moves under the reader's feet).
  - = = SO A CARD ADDRESSED TO AN IMPLEMENTER IS NOT "A CARD THAT CANNOT
    MOVE". = = The reviewer states the finding TWICE: once in the verdict,
    and once in a card that the implementer's own home picks up and runs.
    The verdict was already written when the card went out, so the second
    copy is the duplicate, = = whatever the dispatcher does with it.

  = = The verdict IS the hand-off (= = AGENTS.md 1.14), = = so a card that
  restates a verdict the board already holds is the FINDING DONE TWICE,
  = = and the duplicate is what the gate names.

  THE COUNTS, AND WHAT FORM THEY ARE IN. The 63 runs above are RUNS (= =
  one row per dispatch of an implementer-addressed card), read in ONE form
  (= = by the profile that ran them: `pocock` 43, `wenshu-dev` 20), and they
  are a different number in a different form from the CARD census (= = 56
  cards addressed to an implementer by the review lane, read at the same
  moment, split by STATUS: 35 done, 18 archived (= = 14 archived for
  `pocock`, 4 for `wenshu-dev`), 2 running, 1 ready). One number, one
  form: = = the run census is split by profile and the card census by
  status, = = and neither is split twice. A published number names its
  window AND its
  form; a run count and a card count are not interchangeable.

WHAT IT PRINTS, per card:

    <id>  <title>
        creator=<profile>  assignee=<profile>  status=<status>
        parent=<review card id>  verdict=<approved|changes_requested|none>
        skipped_nonspawnable=<n>   (= the board's own record of a dispatch that
                                      found no such profile on ITS home)

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

# The profiles that IMPLEMENT (= = the lane whose own session does the work).
IMPLEMENTER_PROFILES = ("pocock", "wenshu-dev")

# The board's own record that a dispatch found no profile with that assignee
# name (= = on the home that was dispatching). It is NOT a record that the card
# cannot move: = = the allowlist that decides it is read PER HOME, so the same
# assignee is skipped by one home and spawned by another.
SKIP_EVENT = "skipped_nonspawnable"


# The epoch the hand-off contract starts at (= when this wave landed the
# gate). The cards already on the board were created under the old flow,
# and rewriting them is not this tool's business (= the report names them
# instead).
HANDOFF_CONTRACT_FROM = 1795449600  # 2026-11-24 00:00 CST


def is_subject(created_at: int | None) -> bool:
    """Whether this card is judged by the hand-off contract.

    None (= a card that does not exist yet) is judged: a card that is
    being created must satisfy the contract now.
    """
    if created_at is None:
        return True
    return created_at >= HANDOFF_CONTRACT_FROM


def board_db_path(board: str = product_lines.DEFAULT_BOARD) -> Path:
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


def contract_errors(card: dict) -> list[str]:
    """Why does this ONE card break the hand-off contract?

    The collector answers "what does the board hold?", and this answers
    "may this card go out?", so the same rule is read on the dispatch
    path and not only in a report. A card created by a review-lane
    profile and addressed to an implementer profile is the card that
    restates a verdict the board already holds (= the verdict IS the
    hand-off, = AGENTS.md 1.14), so the finding is stated twice.

    WHY THE SECOND COPY IS THE DEFECT, AND NOT THE DISPATCHER. The
    first version of this rule rested on the dispatcher's allowlist
    (= `dispatch_profiles`): the claim was that a card addressed to an
    implementer can never be spawned, so it waits for ever. Measured
    2026-11-26: that allowlist is read PER HOME, and the homes that
    dispatch implementer cards do not declare it (= = an absent key
    leaves the allowlist open), so such a card IS picked up and run
    (= 63 runs on the cards the review lane addressed to an implementer,
    read up to the window seal 1795683213, split by the profile that ran
    them: `pocock` 43, `wenshu-dev` 20). The card does not wait for ever;
    it is run.
    What is still true = = and is what this rule rests on now = = is
    that the verdict was already written when the card went out, so the
    second copy restates it. The rule names the DUPLICATE, not the
    dispatcher's queue.

    AND THE SAME RE-MEASUREMENT DISCIPLINE GOVERNS THE NUMBERS. The
    first version of the correction re-badged the superseded card census
    (= = 41 cards, read 2026-11-24: 28 done + 9 archived + 4 archived) as a
    run count, and split it by outcome. That split was never true of this
    population: = = `outcome` has seven values on it, = = and the count of
    completed runs on it is bounded by 35 at the commit's own timestamp,
    = = so the three-way split it published could not be read off the
    population at any window. = = So the figures above are re-measured,
    each in ONE form, = = with its population and its window named.

    THE SECOND HALF OF THE SAME DEFECT (measured 2026-11-26). The
    reviewer's half is only half of the cards that come back to the
    implementer. The other half is created BY the implementer FOR
    itself: AGENTS.md 1.12 says the developer finds the code and writes
    the code in its own session and worktree, and files NO board card
    for the work (= the ONE card it files is the review card it hands to
    the review lane after the commit). So a card an implementer created
    and addressed to an implementer is a card the implementer filed for
    itself, = = so it comes back to the implementer's board and is run
    there, = = while the work was already done in the implementer's own
    session.

    Measured on board wenshu-par, 2026-11-26: 6 OPEN cards were filed by
    `pocock` for `pocock`, all of them `ready`, all of them bouncing
    back. The reviewer's half covered 3 of the 9 cards that came back;
    this half covers the other 6.

    THERE IS NO LANDING EXEMPTION, AND THAT IS MEASURED, NOT ASSUMED.
    A landing card (= the card that moves an APPROVED branch onto main)
    IS filed by an implementer and addressed to an implementer, so the
    naive reading of this rule would refuse it. Measured on the board:
    every single card carrying the landing tag (6 of 6) was created by `user`
    (= the boss), and NOT ONE was filed by `pocock`. So the landing
    card is the BOSS's card, and the implementer lands inside its own
    session (= measured 2026-11-26: the lane landed with
    `Scripts/land_card.sh` from the implementer's own worktree, with no
    board card at all). An exemption keyed on the landing tag would
    therefore be an exemption with no legitimate user, and it would
    leave a hole: an implementer could escape the rule by putting the
    tag in its title. So the rule has no exemption, and the ONE card an
    implementer may file is the review card it addresses to the review
    lane.

    The card dict carries `created_by` and `assignee` (= the live board's
    own JSON), so the rule needs no board read.
    """
    creator = str(card.get("created_by") or "").strip()
    assignee = str(card.get("assignee") or "").strip()
    errors: list[str] = []
    if creator in REVIEW_PROFILES and assignee in IMPLEMENTER_PROFILES:
        errors.append(
            f"a card created by {creator} and addressed to {assignee} restates "
            "a verdict the board already holds (= the verdict IS the hand-off, "
            "= AGENTS.md 1.14), so the finding is stated twice: state it in the "
            "verdict and in the review card's comment"
        )
    if creator in IMPLEMENTER_PROFILES and assignee in IMPLEMENTER_PROFILES:
        errors.append(
            f"a card created by {creator} and addressed to {assignee} is a card "
            "the implementer filed for itself: the developer finds the code and "
            "writes the code in its own session and worktree and files NO board "
            "card for the work (= AGENTS.md 1.12), = = the ONE card it files is "
            "the review card it hands to the review lane after the commit; and "
            "this card comes back to the implementer's board, = = where it is run "
            "as a second copy of the work the implementer's own session already "
            "did (= = the finding stated twice): "
            "do the work in your own session and file ONE review card when the "
            "commit exists (= the landing card is the boss's card: every card "
            "carrying the landing tag on the board was created by `user`, = = and the "
            "implementer lands inside its own session)"
        )
    return errors


def print_report(report: dict, db: Path) -> None:
    """The text report: one card per block, then the count."""
    print(f"review-handoff: board {db}")
    print(f"  review lane: {', '.join(report['review_profiles'])} | "
          f"implementer lane: {', '.join(report['implementer_profiles'])}")
    print(f"  cards a review lane created for an implementer (= the finding "
          f"stated twice): {report['cards']}")
    if report["cards"] == 0:
        print("  ok: every review-lane card is addressed to the review lane's "
              "verdict holder")
        return
    for row in report["rows"]:
        print(f"  {row['id']}  {row['title']}")
        print(f"      creator={row['creator']}  assignee={row['assignee']}  "
              f"status={row['status']}")
        verdict = row["verdict"] or "none (= the parent card carries no verdict)"
        print(f"      parent={row['parent'] or 'none'}  verdict={verdict}"
              + (f" (from {row['verdict_profile']})" if row["verdict_profile"] else ""))
        print(f"      skipped_nonspawnable={row['skipped_nonspawnable']} "
              f"(= the board's own record of a dispatch that found no such "
              f"profile on ITS home)")
    print(f"  these cards restate a verdict the board already holds; the verdict "
          f"is the hand-off (= = AGENTS.md 1.14), and the move is the boss's call")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--board-db", default=None,
                    help="the board's database file (default: the flow's board)")
    ap.add_argument("--board", default=product_lines.DEFAULT_BOARD,
                    help="board slug (default: the flow's own board)")
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
