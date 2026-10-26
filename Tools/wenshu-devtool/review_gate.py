#!/usr/bin/env python3
"""
review_gate.py - the independent-review gate: who owes a verdict, and who gave it.

Two questions, one gate:

  CONTRACT  does this card owe an independent review verdict, and does the body
            name a reviewer profile that is NOT the implementer?
  RECORD    does the board already hold an approving verdict for this card, and
            which profile gave it?

The contract is DERIVED from the work the body describes, never hand-set, and it
is independent of the difficulty tier: AGENTS.md 1.13 makes the tier the cost
of a card and never the quality bar, so the tier cannot decide who reviews a
card.

WHY THE GATE EXISTS (measured on board wenshu-par, 2026-10-26):

  - 113 of 114 done cards carried ZERO review events. The reviewer profile was
    named in the docs and never ran.
  - The one review that did run was the implementer reviewing ITSELF, and it
    found a card reported done with no commit on its branch and both of its
    acceptance criteria unmet. A self-review is not a verdict.
  - The cause was concrete: no card body named a reviewer, so
    ``kanban_request_review`` fell back to the assignee, and the assignee was
    the implementer.
  - 5 done cards promised files in their body that their branch does not
    contain (= a false done), and all 5 write code. 0 prose-only card was
    false done. So a card that writes CODE owes a verdict, and a card that
    writes prose does not.

A card writes CODE when its body writes a file outside the documentation set
(docs/ and the root markdown files). Prose is already read against the spec by
the dual-axis audit (AGENTS.md 7.4); code is not.

THE GATE STARTS ON A DATE, NOT ON A FLAG. A card created before
REVIEW_CONTRACT_FROM is a pre-contract card: it is reported, never blocked,
because the cards already on the board were dispatched under the old contract
and rewriting them is not this tool's business. A card created on or after
that epoch owes a verdict when it writes code, and a body that writes code
without naming a reviewer is a contract error.

Usage:
    review_gate.py --body FILE      the contract of one draft body
    review_gate.py --card ID        the record of one card on the board
    review_gate.py --check          every card on the board
    review_gate.py --json           machine-readable output

Exit code 0 = the gate is satisfied, 1 = a contract error, 2 = the board could
not be read, 3 = a card owes a verdict it does not have.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ticket_tier  # noqa: E402  (sibling module, same directory)

BOARD = "wenshu-par"

# The epoch the review contract starts at (= when this gate landed on main).
# A card created before it was dispatched under the old contract, so it is
# reported and never blocked.
REVIEW_CONTRACT_FROM = 1792953600  # 2026-10-26 02:40 CST

# The CONTRACT half of the gate (what the card owes) is a contract on the
# card body, so it lives with the body parser in ticket_tier.py. The RECORD
# half (who actually gave the verdict) needs the board, so it lives here.
code_paths = ticket_tier.code_paths
review_required = ticket_tier.review_required
handoff_text = ticket_tier.handoff_text
named_reviewer = ticket_tier.named_reviewer


def is_subject(created_at: int | None) -> bool:
    """Whether a card was created under the review contract."""
    if created_at is None:
        return True  # a draft body is a card that does not exist yet
    return created_at >= REVIEW_CONTRACT_FROM


def contract_errors(
    body: str,
    assignee: str | None = None,
    created_at: int | None = None,
) -> list[str]:
    """Every way the body breaks the review contract."""
    errors = ticket_tier.review_contract_errors(body, assignee)
    if created_at is not None and not is_subject(created_at):
        # A card dispatched under the old contract is reported, never blocked.
        return []
    return errors


def _hermes() -> str | None:
    """The hermes executable, resolved so a missing PATH is not a silent pass."""
    found = shutil.which("hermes")
    if found:
        return found
    for candidate in (
        os.environ.get("HERMES_BIN"),
        str(Path.home() / ".local" / "bin" / "hermes"),
    ):
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return candidate
    return None


def _run_hermes(args: list[str]) -> tuple[int, str]:
    """Run the hermes CLI, returning (returncode, stdout)."""
    binary = _hermes()
    if binary is None:
        return 127, ""
    proc = subprocess.run([binary, *args], capture_output=True, text=True)
    return proc.returncode, proc.stdout


def board_doc(card_id: str, board: str = BOARD) -> dict | None:
    """The board record of one card, or None when the board cannot be read."""
    code, out = _run_hermes(
        ["kanban", "--board", board, "show", card_id, "--json"]
    )
    if code != 0:
        return None
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def board_cards(board: str = BOARD) -> list[dict] | None:
    """Every card on the board, or None when the board cannot be read."""
    code, out = _run_hermes(["kanban", "--board", board, "list", "--json"])
    if code != 0:
        return None
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    if isinstance(data, dict):
        data = data.get("tasks", [])
    return list(data) if isinstance(data, list) else None


def _kind(event: dict) -> str:
    return str(event.get("kind") or "")


def _payload(event: dict) -> dict:
    raw = event.get("payload")
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {}
    return {}


def _at(item: dict, *names: str) -> int:
    """A timestamp in seconds, or 0 when the item carries none."""
    for name in names:
        value = item.get(name)
        if isinstance(value, (int, float)) and value > 0:
            return int(value)
    return 0


def implementer_of(doc: dict) -> str | None:
    """The profile that IMPLEMENTED the card.

    Not the card's current assignee: a handoff reassigns the card to the
    reviewer, so the assignee is the reviewer for the whole review, and the
    rework after a change request. The implementer is the profile the
    handoff recorded, or the profile of the first run that touched the card.
    """
    events = [e for e in (doc.get("events") or []) if isinstance(e, dict)]
    handoffs = [e for e in events if _kind(e) == "review_requested"]
    if handoffs:
        handoff = max(handoffs, key=lambda e: _at(e, "created_at"))
        recorded = _payload(handoff).get("implementer")
        if recorded:
            return str(recorded)
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    runs = [r for r in runs if r.get("profile")]
    if runs:
        first = min(runs, key=lambda r: _at(r, "started_at"))
        return str(first.get("profile"))
    return None


def verdict_from_doc(doc: dict) -> dict:
    """The verdict the board record carries for one card.

    A verdict counts only when the handoff named a reviewer, that reviewer
    profile gave it, and no rework was asked for afterwards.
    """
    events = [e for e in (doc.get("events") or []) if isinstance(e, dict)]
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    handoffs = [e for e in events if _kind(e) == "review_requested"]
    if not handoffs:
        return {
            "status": "no_handoff",
            "reason": "the card never handed off for review (= it was completed by its implementer)",
        }
    handoff = max(handoffs, key=lambda e: _at(e, "created_at"))
    handoff_at = _at(handoff, "created_at")
    payload = _payload(handoff)
    reviewer = payload.get("reviewer")
    implementer = payload.get("implementer")
    if not reviewer:
        return {
            "status": "no_reviewer_named",
            "reason": (
                "the handoff named no reviewer, so the board fell back to the "
                f"implementer ({implementer or 'unknown'})"
            ),
        }
    if reviewer == implementer:
        return {
            "status": "self_review",
            "reviewer": reviewer,
            "reason": "the reviewer profile is the implementer profile",
        }
    approvals = []
    for run in runs:
        if str(run.get("outcome") or "") != "completed":
            continue
        metadata = run.get("metadata")
        metadata = metadata if isinstance(metadata, dict) else {}
        if metadata.get("review_outcome") != "approved":
            continue
        if str(run.get("profile") or "") != str(reviewer):
            continue
        if _at(run, "ended_at", "started_at") < handoff_at:
            continue
        approvals.append(run)
    if not approvals:
        return {
            "status": "not_approved",
            "reviewer": reviewer,
            "reason": f"no approving verdict from {reviewer} is on the record",
        }
    approval = max(approvals, key=lambda r: _at(r, "ended_at", "started_at"))
    approved_at = _at(approval, "ended_at", "started_at")
    for event in events:
        if _kind(event) != "changes_requested":
            continue
        if _at(event, "created_at") > approved_at:
            return {
                "status": "changes_requested",
                "reviewer": reviewer,
                "reason": "changes were requested after the last approving verdict",
            }
    return {
        "status": "approved",
        "reviewer": reviewer,
        "implementer": implementer,
        "run_id": approval.get("id"),
    }


def card_record(card_id: str, board: str = BOARD) -> dict:
    """The gate state of one card on the board."""
    doc = board_doc(card_id, board)
    if doc is None:
        return {
            "card": card_id,
            "gate": "board_unreadable",
            "reason": "the board could not be read",
        }
    task = doc.get("task") or {}
    body = task.get("body") or ""
    created_at = task.get("created_at")
    created_at = int(created_at) if isinstance(created_at, (int, float)) else None
    verdict = verdict_from_doc(doc)
    implementer = implementer_of(doc)
    errors = contract_errors(body, implementer, created_at)
    if not is_subject(created_at):
        gate = "pre_contract"
        reason = (
            "the card was created before the review contract started "
            "(= reported, never blocked)"
        )
    elif errors:
        gate = "contract_error"
        reason = errors[0]
    else:
        gate = verdict["status"]
        reason = verdict.get("reason")
        if gate == "approved":
            reason = f"approved by {verdict.get('reviewer')}"
    return {
        "card": card_id,
        "title": task.get("title"),
        "status": task.get("status"),
        "assignee": task.get("assignee"),
        "implementer": implementer,
        "created_at": created_at,
        "pre_contract": not is_subject(created_at),
        "review_required": review_required(body)[0],
        "reviewer": named_reviewer(body),
        "errors": errors,
        "gate": gate,
        "reason": reason,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", help="check the contract of one body file")
    parser.add_argument("--card", help="check the record of one card")
    parser.add_argument("--check", action="store_true", help="check every card")
    parser.add_argument("--assignee", help="the implementer profile, for the body check")
    parser.add_argument("--board", default=BOARD, help="board slug")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()

    if args.body:
        body = Path(args.body).read_text(encoding="utf-8")
        required, code = review_required(body)
        errors = contract_errors(body, args.assignee)
        result = {
            "card": args.body,
            "review_required": required,
            "code_paths": code,
            "reviewer": named_reviewer(body),
            "errors": errors,
        }
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"review required: {'yes' if required else 'no'}")
            if code:
                print("  code: " + ", ".join(code))
            print(f"  reviewer: {result['reviewer'] or '-'}")
            for error in errors:
                print(f"  ! {error}")
        return 1 if errors else 0

    if args.card:
        record = card_record(args.card, args.board)
        if args.json:
            print(json.dumps(record, indent=2))
        else:
            print(f"{record['card']}  {record['gate']}  {record['reason'] or ''}")
            for error in record.get("errors") or []:
                print(f"  ! {error}")
        if record["gate"] == "board_unreadable":
            return 2
        if record["gate"] == "contract_error":
            return 1
        if record["gate"] in (
            "not_approved",
            "no_handoff",
            "no_reviewer_named",
            "self_review",
            "changes_requested",
        ):
            return 3
        return 0

    if args.check:
        cards = board_cards(args.board)
        if cards is None:
            print("the board could not be read", file=sys.stderr)
            return 2
        rows = []
        for card in cards:
            body = card.get("body") or ""
            created_at = card.get("created_at")
            created_at = int(created_at) if isinstance(created_at, (int, float)) else None
            required, code = review_required(body)
            errors = contract_errors(body, card.get("assignee"), created_at)
            rows.append({
                "card": card.get("id"),
                "title": card.get("title"),
                "status": card.get("status"),
                "assignee": card.get("assignee"),
                "created_at": created_at,
                "pre_contract": not is_subject(created_at),
                "review_required": required,
                "code_paths": code,
                "reviewer": named_reviewer(body),
                "errors": errors,
            })
        if args.json:
            print(json.dumps(rows, indent=2))
            return 1 if any(r["errors"] for r in rows) else 0

        subject = [r for r in rows if not r["pre_contract"]]
        failing = [r for r in subject if r["errors"]]
        owed = [r for r in subject if r["review_required"] and not r["errors"]]
        print(
            f"=== {len(rows)} card(s): {len(subject)} under the review contract, "
            f"{len(failing)} break it, {len(owed)} owe a verdict"
        )
        for row in failing:
            print(f"  {row['card']}  {row['title']}")
            for error in row["errors"]:
                print(f"      ! {error}")
        for row in owed:
            print(f"  {row['card']}  {row['title']}  (owes a verdict)")
        return 1 if failing else 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
