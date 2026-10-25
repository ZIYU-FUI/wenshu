#!/usr/bin/env python3
"""
review_gate.py - the independent-review gate: who owes a verdict, and who gave it.

Two questions, one gate:

  CONTRACT  does this card body owe an independent review verdict, and does
            the body name a reviewer profile that is NOT the implementer?
  RECORD    does the board already hold an approving verdict for this card,
            and which profile gave it?

The contract is DERIVED from the work the body describes, never hand-set, and
it is independent of the difficulty tier: AGENTS.md 1.13 makes the tier the
cost of a card and never the quality bar, so the tier cannot decide who
reviews a card.

WHY THE GATE EXISTS (measured on board wenshu-par, 2026-10-25):

  - 113 of 114 done cards carried ZERO review events. The reviewer profile
    was named in the docs and never ran.
  - The one review that did run was the implementer reviewing ITSELF, and it
    found a card reported done with no commit on its branch and both of its
    acceptance criteria unmet. A self-review is not a verdict.
  - Two cards marked done never reached main, and the merge leak concentrates
    in the cards that write code.
  - A verdict costs one more run on the card: measured +11% (T1), +23% (T2),
    +19% (T3) of worker time. So a card that writes prose does not owe one,
    and a card that writes code does.

A card writes CODE when its body writes a file outside the documentation set
(docs/ and the root markdown files). Prose is already read against the spec
by the dual-axis audit (AGENTS.md 7.4); code is not.

Usage:
    review_gate.py --body FILE      the contract of one draft body
    review_gate.py --card ID        the record of one card on the board
    review_gate.py --check          every non-done card on the board
    review_gate.py --json           machine-readable output

Exit code 0 = the gate is satisfied, 1 = a contract error, 3 = a card owes a
verdict it does not have, 2 = the board could not be read.
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
REVIEWER_HINT = "wenshu-review"

# A body path that is prose, not code. Everything else the body writes is
# code: a script, a test, a tool, a build input.
DOC_ROOTS = ("docs/",)
DOC_FILES = (
    "AGENTS.md", "OOB.md", "README.md", "CHANGELOG.md", "CONTEXT.md",
    ".hermes.md",
)
# The build inputs a card can write that change what ships or what gates it.
CODE_FILES = ("Package.swift", "Package.resolved", ".swiftlint.yml", ".swift-format")

# The section a card body carries to name its reviewer.
HANDOFF_HEADING = "review handoff"

# reviewer="wenshu-review" or reviewer: wenshu-review
REVIEWER_RE = re.compile(r"reviewer\s*[=:]\s*[\"']?([A-Za-z0-9_.-]+)")


def is_documentation(path: str) -> bool:
    """Whether a path is prose (= the dual-axis audit already reads it)."""
    if path in DOC_FILES:
        return True
    return path.startswith(DOC_ROOTS)


def code_paths(body: str) -> list[str]:
    """The code files the body writes (= the work a reviewer must read)."""
    written, _forbidden = ticket_tier.work_scope(body)
    return sorted(p for p in written if not is_documentation(p))


def review_required(body: str) -> tuple[bool, list[str]]:
    """Whether the body owes an independent verdict, and the code it writes."""
    code = code_paths(body)
    return bool(code), code


def normalized(name: str) -> str:
    """A heading reduced to comparable words."""
    return re.sub(r"[^a-z]+", " ", (name or "").strip().lower()).strip()


def handoff_text(body: str) -> str | None:
    """The text of the card's REVIEW HANDOFF section, or None."""
    for name, text in ticket_tier.sections(body):
        if normalized(name) == HANDOFF_HEADING:
            return text
    return None


def named_reviewer(text: str | None) -> str | None:
    """The reviewer profile the handoff names, or None."""
    if not text:
        return None
    match = REVIEWER_RE.search(text)
    return match.group(1) if match else None


def contract_errors(body: str, assignee: str | None = None) -> list[str]:
    """Every way the body breaks the review contract."""
    required, code = review_required(body)
    if not required:
        return []
    errors: list[str] = []
    text = handoff_text(body)
    if text is None:
        errors.append(
            "the body writes code ("
            + ", ".join(code[:3])
            + ") but carries no REVIEW HANDOFF section"
        )
        return errors
    reviewer = named_reviewer(text)
    if reviewer is None:
        errors.append(
            "the REVIEW HANDOFF section names no reviewer profile "
            "(write reviewer=\"wenshu-review\")"
        )
    elif assignee and reviewer == assignee:
        errors.append(
            f"the REVIEW HANDOFF names the implementer profile ({reviewer}); "
            "a card cannot be reviewed by the profile that implemented it"
        )
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


def board_doc(card_id: str, board: str = BOARD) -> dict | None:
    """The board record of one card, or None when the board cannot be read."""
    binary = _hermes()
    if binary is None:
        return None
    proc = subprocess.run(
        [binary, "kanban", "--board", board, "show", card_id, "--json"],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


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


def _stamp(item: dict, *names: str) -> int:
    for name in names:
        value = item.get(name)
        if isinstance(value, (int, float)):
            return int(value)
    return 0


def verdict_from_doc(doc: dict) -> dict:
    """The verdict the board record carries for one card.

    A verdict counts only when the handoff named a reviewer, that reviewer
    profile gave it, and no rework was asked for afterwards.
    """
    events = list(doc.get("events") or [])
    runs = list(doc.get("runs") or [])
    handoffs = [e for e in events if _kind(e) == "review_requested"]
    if not handoffs:
        return {
            "status": "no_handoff",
            "reason": "the card never handed off for review (= it was completed by its implementer)",
        }
    handoff = max(handoffs, key=lambda e: _stamp(e, "created_at", "id"))
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
        approvals.append(run)
    if not approvals:
        return {
            "status": "not_approved",
            "reviewer": reviewer,
            "reason": f"no approving verdict from {reviewer} is on the record",
        }
    approval = max(approvals, key=lambda r: _stamp(r, "ended_at", "started_at", "id"))
    approval_end = _stamp(approval, "ended_at", "started_at", "id")
    for event in events:
        if _kind(event) != "changes_requested":
            continue
        if _stamp(event, "created_at", "id") > approval_end:
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
        return {"card": card_id, "status": "board_unreadable", "reason": "the board could not be read"}
    task = doc.get("task") or {}
    body = task.get("body") or ""
    verdict = verdict_from_doc(doc)
    legacy = handoff_text(body) is None
    if legacy:
        status = "legacy_no_handoff"
        reason = "the body carries no REVIEW HANDOFF section (= a pre-gate card)"
    else:
        status = verdict["status"]
        reason = verdict.get("reason")
        if status == "approved":
            reason = f"approved by {verdict.get('reviewer')}"
    return {
        "card": card_id,
        "title": task.get("title"),
        "status": task.get("status"),
        "assignee": task.get("assignee"),
        "gate": status,
        "reason": reason,
        "reviewer": verdict.get("reviewer"),
        "implementer": verdict.get("implementer"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", help="check the contract of one body file")
    parser.add_argument("--card", help="check the record of one card")
    parser.add_argument("--check", action="store_true", help="check every non-done card")
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
            "reviewer": named_reviewer(handoff_text(body)),
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
            print(f"{record['card']}  {record.get('gate')}  {record.get('reason') or ''}")
        if record["gate"] == "approved":
            return 0
        if record["gate"] == "legacy_no_handoff":
            return 0
        return 3

    if args.check:
        cards = ticket_tier.kanban_cards(args.board)
        if not cards:
            print("the board could not be read", file=sys.stderr)
            return 2
        rows = []
        for card in cards:
            if str(card.get("status") or "") == "done":
                continue
            body = card.get("body") or ""
            required, code = review_required(body)
            errors = contract_errors(body, card.get("assignee"))
            rows.append({
                "card": card.get("id"),
                "title": card.get("title"),
                "status": card.get("status"),
                "assignee": card.get("assignee"),
                "review_required": required,
                "code_paths": code,
                "reviewer": named_reviewer(handoff_text(body)),
                "errors": errors,
            })
        if args.json:
            print(json.dumps(rows, indent=2))
        else:
            failing = [r for r in rows if r["errors"]]
            print(f"=== {len(rows)} non-done card(s); {len(failing)} break the review contract")
            for row in failing:
                print(f"  {row['card']}  {row['title']}")
                for error in row["errors"]:
                    print(f"      ! {error}")
        return 1 if any(r["errors"] for r in rows) else 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
