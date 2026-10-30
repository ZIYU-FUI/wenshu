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
import sqlite3
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)
import ticket_tier  # noqa: E402  (sibling module, same directory)
from ticket_tier import normalized, sections  # noqa: E402  (sibling module, same directory)

# The board this tool reads when the caller names none. Declared in one
# place (= product_lines), so a tool that sweeps boards reads the same
# board list the rest of the devtool does.
BOARD = product_lines.DEFAULT_BOARD

# The epoch the review contract starts at (= when this gate landed on main).
# A card created before it was dispatched under the old contract, so it is
# reported and never blocked.
REVIEW_CONTRACT_FROM = 1792953600  # 2026-10-26 02:40 CST

# The CONTRACT half of the gate (what the card owes) is a contract on the
# card body, so it lives with the body parser in ticket_tier.py. The RECORD
# half (who actually gave the verdict) needs the board, so it lives here.
code_paths = ticket_tier.code_paths
review_required = ticket_tier.review_required
review_required_for_kind = ticket_tier.review_required_for_kind
card_type = ticket_tier.card_type
handoff_text = ticket_tier.handoff_text
named_reviewer = ticket_tier.named_reviewer


def is_subject(created_at: int | None) -> bool:
    """Whether a card was created under the review contract."""
    if created_at is None:
        return True  # a draft body is a card that does not exist yet
    return created_at >= REVIEW_CONTRACT_FROM


def is_review_card(doc: dict) -> bool:
    """Whether this card has NO implementation phase (= it IS a review).

    A card that reviews a commit somebody else already wrote has no
    implementation phase: every run on it carries the SAME profile, because
    the only profile that ever touched it is the reviewer. Measured
    2026-10-29 on board wenshu-mob-par: card t_809184d0 carried exactly ONE
    run, by wenshu-review, and named wenshu-review as its reviewer. The
    contract check called that a self-review, which is a false positive that
    blocks the merge of code the reviewer already approved.

    The shape alone is wide (= 155 of the 206 cards on wenshu-par are
    single-profile), so it is only ever used together with the card's
    declared kind: the kind says the card is a review, and the shape says it
    has no implementation phase to be reviewed against.
    """
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    runs = [r for r in runs if r.get("profile")]
    if not runs:
        return False
    return len({str(r.get("profile")) for r in runs}) == 1


def card_kind(doc: dict) -> str:
    """The kind of work this card is, derived from its body and its runs."""
    task = doc.get("task") or {}
    body = task.get("body") or ""
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    return ticket_tier.card_type(body, runs, str(task.get("title") or ""))


def contract_errors(
    body: str,
    assignee: str | None = None,
    created_at: int | None = None,
    kind: str | None = None,
    is_review: bool = False,
) -> list[str]:
    """Every way the body breaks the review contract."""
    errors = ticket_tier.review_contract_errors(
        body, assignee, kind=kind, is_review_card=is_review
    )
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



def review_cards_for(board: str = BOARD) -> list[dict]:
    """Every card on the board, with its runs, read cheaply (= one query).

    A card body is not always TEXT: the board stores some of them as a
    BLOB, and a NULL for the cards created without one. Both are decoded
    here, so the caller never has to know the storage type.
    """
    path = _board_db_path(board)
    if path is None:
        return []
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error:
        return []
    try:
        conn.row_factory = sqlite3.Row
        cards = [dict(r) for r in conn.execute("SELECT * FROM tasks")]
        runs: dict[str, list[dict]] = {}
        for r in conn.execute("SELECT * FROM task_runs ORDER BY started_at ASC"):
            runs.setdefault(r["task_id"], []).append(dict(r))
    except sqlite3.Error:
        return []
    finally:
        conn.close()
    for c in cards:
        c["runs"] = runs.get(c.get("id") or "", [])
        # A card body is not always TEXT: the board stores some of them as
        # a BLOB, and a NULL for the cards created without one. The gate
        # reads every card on the board, so it must not die on one card's
        # storage type.
        body = c.get("body")
        if isinstance(body, (bytes, bytearray)):
            c["body"] = body.decode("utf-8", errors="replace")
        elif body is None:
            c["body"] = ""
        title = c.get("title")
        if isinstance(title, (bytes, bytearray)):
            c["title"] = title.decode("utf-8", errors="replace")
    return cards


def _git_tip(ref: str) -> str | None:
    """The sha a branch or ref points at, or None when it cannot be read.

    The review card that covers a branch is the one whose body names the
    sha the branch points at, so the branch's own tip is the lookup key.
    A ref that does not resolve must NOT match anything: a lookup that
    falls back to "any review card" would let an unrelated card satisfy
    the gate for a branch nobody reviewed.
    """
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--verify", "-q", f"{ref}^{{commit}}"],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    sha = out.stdout.strip()
    return sha or None


def reviewed_sha(body: str) -> str | None:
    """The sha a review card names, read from its WHAT TO BUILD claim."""
    for name, text in sections(body):
        if normalized(name) != "what to build":
            continue
        lines = text.splitlines()
        if lines and lines[0].lstrip().startswith("#"):
            lines = lines[1:]
        for para in "\n\n".join(lines).split("\n\n"):
            claim = para.strip()
            if not claim:
                continue
            match = re.search(r"[0-9a-f]{7,40}", claim)
            return match.group(0) if match else None
    return None


def branch_of(doc: dict) -> str | None:
    """The branch a card carries, if the board knows one."""
    return (doc.get("branch_name") or None)


def _profiles_of(card_id: str, board: str = BOARD) -> set[str]:
    """The profiles that ran this card, read from the board's run table.

    A REVIEW card has no implementation phase, so the only profile that
    touched it is the reviewer, and it is not reviewing itself.
    """
    path = _board_db_path(board)
    if path is None:
        return set()
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error:
        return set()
    try:
        rows = conn.execute(
            "SELECT DISTINCT profile FROM task_runs "
            "WHERE task_id = ? AND profile IS NOT NULL AND profile != ''",
            (card_id,),
        ).fetchall()
    except sqlite3.Error:
        return set()
    finally:
        conn.close()
    return {str(row[0]) for row in rows}


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
    if card_kind(doc) == "review":
        created_by = str((doc.get("task") or {}).get("created_by") or "").strip()
        if created_by and created_by not in ("user", "system"):
            return created_by
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    runs = [r for r in runs if r.get("profile")]
    if runs:
        first = min(runs, key=lambda r: _at(r, "started_at"))
        return str(first.get("profile"))
    return None


def implementers_from_board(board: str = BOARD) -> dict[str, str | None]:
    """Every card's implementer, read from the board's own run history.

    A handoff reassigns the card to the reviewer, so the card's CURRENT
    assignee is the reviewer for the whole review, and reading it as the
    implementer reports every finished card as reviewing itself.

    Measured 2026-10-30: 27 of 166 cards on wenshu-par were reported as
    self-reviews for that reason, and all 27 are BUILD cards whose
    implementer was wenshu-dev.

    The board's LIST view does not carry the run history, so the run table
    is read directly. That is what makes a sweep of the whole board cheap:
    one query instead of one CLI call per card.
    """
    out: dict[str, str | None] = {}
    path = _board_db_path(board)
    if path is None:
        return out
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error:
        return out
    try:
        rows = conn.execute(
            "SELECT task_id, profile FROM task_runs "
            "WHERE profile IS NOT NULL AND profile != '' "
            "ORDER BY started_at ASC"
        ).fetchall()
    except sqlite3.Error:
        return out
    finally:
        conn.close()
    for task_id, profile in rows:
        if task_id not in out:
            out[task_id] = profile
    return out


def _board_db_path(board: str) -> Path | None:
    """The board's database file, or None when it cannot be found.

    ``HERMES_HOME`` points at the PROFILE's directory, not at the home
    that holds the boards, so the profile's own copy is tried first and
    the shared home second. Getting this wrong is not a slow path, it is
    a WRONG path: the sweep then finds no implementers at all and
    reports every finished card as reviewing itself.
    """
    candidates = []
    env = os.environ.get("HERMES_HOME")
    if env:
        candidates.append(Path(env))
    candidates.append(Path.home() / ".hermes")
    for home in candidates:
        candidate = home / "kanban" / "boards" / board / "kanban.db"
        if candidate.is_file():
            return candidate
    return None


def _implementer_of_card(card_id: str, board: str = BOARD) -> str | None:
    """The profile that implemented this card, read from the board.

    The board's LIST view does not carry the run history, so the card's
    own record is read instead (= the same record ``implementer_of`` reads).
    """
    doc = board_doc(card_id, board)
    if doc is None:
        return None
    return implementer_of(doc)


def _approving_runs(runs: list[dict], reviewer: str | None) -> list[dict]:
    """The completed runs that carry an approving verdict from the reviewer."""
    out = []
    for run in runs:
        if str(run.get("outcome") or "") != "completed":
            continue
        metadata = _run_metadata(run)
        if metadata.get("review_outcome") != "approved":
            continue
        if reviewer and str(run.get("profile") or "") != str(reviewer):
            continue
        out.append(run)
    return out


def _run_metadata(run: dict) -> dict:
    """The run's metadata, whatever shape the reader found it in.

    The board stores ``task_runs.metadata`` as JSON TEXT: the CLI decodes
    it, and the sqlite reader does not. A run read straight out of the
    database therefore carries a string, and a test for
    ``isinstance(metadata, dict)`` drops the verdict on the floor: the
    ``--branch`` path read the approval as no approval, while the
    ``--card`` path (through the CLI) read the same run as approved.
    """
    metadata = run.get("metadata")
    if isinstance(metadata, dict):
        return metadata
    if isinstance(metadata, (bytes, bytearray)):
        metadata = metadata.decode("utf-8", errors="replace")
    if isinstance(metadata, str) and metadata.strip():
        try:
            parsed = json.loads(metadata)
        except json.JSONDecodeError:
            return {}
        return parsed if isinstance(parsed, dict) else {}
    return {}


def _verdict_runs(runs: list[dict], reviewer: str | None) -> list[dict]:
    """The completed runs that carry a verdict from the reviewer.

    A verdict is either an approval or a request for changes. The board
    stores the run's metadata as JSON TEXT, so both shapes are read
    through ``_run_metadata``.
    """
    out = []
    for run in runs:
        if str(run.get("outcome") or "") != "completed":
            continue
        metadata = _run_metadata(run)
        if metadata.get("review_outcome") not in ("approved", "changes_requested"):
            continue
        if reviewer and str(run.get("profile") or "") != str(reviewer):
            continue
        out.append(run)
    return out


def verdict_from_doc(doc: dict) -> dict:
    """The verdict the board record carries for one card.

    A verdict counts only when the handoff named a reviewer, that reviewer
    profile gave it, and no rework was asked for afterwards.

    A REVIEW card is the other shape (boss ruling 2026-10-30): it was
    created FOR the reviewer and never handed off, so its verdict is the
    reviewer's own completion, and the implementer is the profile that
    created it (the one that wrote the code).

    Its verdict is read from the run's metadata field, which carries
    either ``approved`` or ``changes_requested``. The board's own
    ``request_changes`` transition is NOT the route here: it requires a
    ``review_requested`` handoff event and a run claimed out of the
    ``review`` status, and this flow never creates either.
    """
    events = [e for e in (doc.get("events") or []) if isinstance(e, dict)]
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    handoffs = [e for e in events if _kind(e) == "review_requested"]
    if not handoffs:
        if card_kind(doc) == "review":
            task = doc.get("task") or {}
            reviewer = str(task.get("assignee") or "") or None
            implementer = str(task.get("created_by") or "") or None
            verdicts = _verdict_runs(runs, reviewer)
            if verdicts:
                verdict = max(verdicts, key=lambda r: _at(r, "ended_at", "started_at"))
                outcome = _run_metadata(verdict).get("review_outcome")
                if outcome == "changes_requested":
                    return {
                        "status": "changes_requested",
                        "reviewer": reviewer,
                        "run_id": verdict.get("id"),
                    }
                if implementer and implementer != reviewer:
                    return {
                        "status": "approved",
                        "reviewer": reviewer,
                        "implementer": implementer,
                        "run_id": verdict.get("id"),
                    }
                return {
                    "status": "self_review",
                    "reviewer": reviewer,
                    "reason": "the reviewer profile is the implementer profile",
                }
            return {
                "status": "not_approved",
                "reviewer": reviewer,
                "reason": f"no approving verdict from {reviewer or 'the reviewer'} is on the record",
            }
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
        metadata = _run_metadata(run)
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
    kind = card_kind(doc)
    is_review = kind == "review" and is_review_card(doc)
    errors = contract_errors(body, implementer, created_at, kind=kind, is_review=is_review)
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
        "review_required": review_required_for_kind(body, kind)[0],
        "kind": kind,
        "reviewer": named_reviewer(body),
        "errors": errors,
        "gate": gate,
        "reason": reason,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", help="check the contract of one body file")
    parser.add_argument("--card", help="check the record of one card")
    parser.add_argument("--branch", help="the branch under review")
    parser.add_argument("--sha", help="the sha the branch points at")
    parser.add_argument("--check", action="store_true", help="check every card")
    parser.add_argument("--assignee", help="the implementer profile, for the body check")
    parser.add_argument("--board", default=BOARD, help="board slug")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()

    if args.body:
        body = Path(args.body).read_text(encoding="utf-8")
        kind = card_type(body, None, "")
        required, code = review_required_for_kind(body, kind)
        errors = contract_errors(body, args.assignee, kind=kind)
        result = {
            "card": args.body,
            "kind": kind,
            "review_required": required,
            "code_paths": code,
            "reviewer": named_reviewer(body),
            "errors": errors,
        }
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"kind: {kind}")
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

    if args.branch:
        # The review card that covers a branch, read by the sha the branch
        # points at (= the sha the card's body names under review).
        #
        # Without --sha the branch's OWN tip is the key. A lookup that
        # matched any review card would let an unrelated card satisfy the
        # gate for a branch nobody reviewed, which is the exact defect this
        # gate exists to prevent.
        sha_filter = args.sha
        if not sha_filter:
            resolved = _git_tip(args.branch)
            if resolved is None:
                print(f"NO REVIEW CARD: branch {args.branch} has no resolvable tip")
                return 3
            sha_filter = resolved
        cards = review_cards_for(args.board)
        found = []
        for card in cards:
            # ``review_cards_for`` returns RAW task rows (= no ``task``
            # key). ``card_kind`` reads the body and the title out of
            # ``doc["task"]``, so it must be handed the WRAPPED doc. A raw
            # row makes it judge the card on an empty body and an empty
            # title, and a card whose runs carry two profiles then reads as
            # a research card and is skipped here: the review card of a
            # card that was reworked would vanish from the lookup.
            doc = {"task": card, "runs": card.get("runs") or [], "events": []}
            if card_kind(doc) != "review":
                continue
            body = card.get("body") or ""
            sha = reviewed_sha(body)
            if not sha:
                continue
            if not (sha.startswith(sha_filter) or sha_filter.startswith(sha)):
                continue
            verdict = verdict_from_doc(doc)
            found.append((card.get("id"), verdict.get("status"), verdict.get("reviewer")))
        for card_id, status, reviewer in found:
            print(f"CARD {card_id}")
            print(f"  verdict: {status} by {reviewer}")
        if not found:
            print(f"NO REVIEW CARD names the sha {args.sha or '?'} on branch {args.branch}")
        return 0 if found else 3

    if args.check:
        cards = board_cards(args.board)
        if cards is None:
            print("the board could not be read", file=sys.stderr)
            return 2
        implementers = implementers_from_board(args.board)
        rows = []
        for card in cards:
            body = card.get("body") or ""
            created_at = card.get("created_at")
            created_at = int(created_at) if isinstance(created_at, (int, float)) else None
            kind = card_type(body, None, str(card.get("title") or ""))
            required, code = review_required_for_kind(body, kind)
            # The implementer is NOT the card's current assignee: a handoff
            # reassigns the card to the reviewer, so the assignee is the
            # reviewer for the whole review. Reading the assignee as the
            # implementer reported every finished card as reviewing itself.
            # Measured 2026-10-30: 27 of 166 cards on wenshu-par were
            # reported as self-reviews for that reason, and all 27 are
            # BUILD cards whose implementer was wenshu-dev.
            implementer = implementers.get(card.get("id") or "")
            # A REVIEW card has no implementation phase, so it is not
            # reviewing itself (= the only profile that touched it is the
            # reviewer). The sweep reads the runs directly, because the
            # board's list view does not carry them.
            profiles = _profiles_of(card.get("id"), args.board)
            is_review = kind == "review" and len(profiles) == 1
            errors = contract_errors(
                body, implementer, created_at, kind=kind, is_review=is_review
            )
            rows.append({
                "card": card.get("id"),
                "title": card.get("title"),
                "status": card.get("status"),
                "assignee": card.get("assignee"),
                "created_at": created_at,
                "pre_contract": not is_subject(created_at),
                "kind": kind,
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
