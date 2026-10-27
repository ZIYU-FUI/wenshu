#!/usr/bin/env python3
"""
effort_budget_gate.py - the evidence-budget gate: does this card bound its own research?

One question, one gate:

  CONTRACT  does a card that asks for research (a design, an investigation, a
            proposal) name the evidence it will read, cap it, and say what it
            stops on?

WHY THE GATE EXISTS (measured on board wenshu-par, 2026-10-27):

  - The board's ten gates (AGENTS.md §7) all run AFTER the code exists. They
    are 7.1 swift build, 7.2 swift test, 7.3 the 9-grep sweep, 7.4 dual-axis
    audit, 7.5 the CJK audit, 7.6 dead code, 7.7 visual proof, 7.8 commit
    hygiene, 7.9 the independent verdict, 7.10 the named narrow suite. Every
    one of them is a gate on a DIFF. None of them can see a session that
    reads 624 tool calls and writes nothing.
  - 161 of the open cards carry a GATES section. ZERO of them carry a bound
    on how much the worker may look at, because nothing asks for one.
  - The right-column session (local-c548e894) is what that costs. Measured
    over 4h42m: 361 API calls, 2,861,026 input tokens, 1,470,842 output
    tokens, 61,162,861 cache-read tokens, 0 file writes, 0 cards created. Its
    own transcript says the whole job needed SEVEN FILES. It read 53 files
    with read_file, ran 387 execute_code calls, and 97 of those execute_code
    calls queried its own history (state.db, kanban.db, agent.log,
    session_search) rather than the code.
  - One of those execute_code outputs was written into the transcript 14
    times over 1h17m. Tool messages are not compressed, so every repeat is
    re-read on every later turn and re-paid.
  - The median wenshu-dev worker session costs 244,012 input tokens. The
    right-column session cost 12x that and produced nothing. Its own 14:59
    note says it: "my evidence-gathering loop has no gate".

WHAT THE GATE ALLOWS:

  A card carries:

    ## EVIDENCE BUDGET

    read:   <the files, at most N of them>
    stop when: <the condition that ends the research>
    no:    <what the worker must not go looking for>
    deliver: <the artifact this card produces>

  The four lines are the contract. `read` is a list with a count, `stop
  when` is a condition, `no` is a refusal, `deliver` is an artifact. A card
  that lists twenty files to read has not budgeted anything, so the cap is
  enforced by the tool rather than trusted to the writer.

  WHO OWES A BUDGET. Every card that is still open owes one: todo, ready,
  running, blocked. A card that is done, in review, or archived does not,
  because its evidence is already spent.

  A GATES section and an evidence budget are ORTHOGONAL, and this is the
  rule that matters most. GATES says how the work is verified AFTER it
  lands; the budget says what the worker may look at BEFORE it starts. A
  card with a GATES section still reads files, runs gates, and may go
  looking for its own past, so it still owes a budget. The only
  difference is how generous the read line may be: a card with a GATES
  section may name the files it will CHANGE, because the diff is its
  evidence list. A card without one must name the files it will READ.

  The first draft of this tool said the opposite ("a card with a GATES
  section is out of scope"). That was wrong, and the right-column card
  found it: the card was "Add a task, todo and subagent section to the
  right column", it carried a GATES section, and it therefore passed a
  gate that would have told it to read seven files instead of 521.

THE GATE STARTS ON A DATE, NOT ON A FLAG. Cards created before
EVIDENCE_CONTRACT_FROM are reported, never blocked: rewriting the cards
already on the board is not this tool's business, and the cards already in
flight were priced under the old contract.

Usage:
    effort_budget_gate.py --body FILE   the contract of one draft body
    effort_budget_gate.py --card ID     the contract of one card on the board
    effort_budget_gate.py --check       every card on the board
    effort_budget_gate.py --json        machine-readable output

Exit code 0 = the gate is satisfied, 1 = a contract error, 2 = the board
could not be read.
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
import time
from pathlib import Path

REPO = Path("/Volumes/ANAN/Engineering/wenshu")
BOARD_DB = Path.home() / ".hermes/kanban/boards/wenshu-par/kanban.db"

# The gate starts here. Cards created before this are reported, never
# blocked: the 161 cards already open were dispatched under the old
# contract, and rewriting them is not this tool's business. The same rule
# the review gate uses (review_gate.REVIEW_CONTRACT_FROM).
EVIDENCE_CONTRACT_FROM = 1793059200  # 2026-10-27 08:00 CST

# The heading a card carries its evidence budget under.
BUDGET_HEADING = "evidence budget"
# The heading, as a heading. A card that quotes the contract in its own
# body writes the words inside a fenced example, and a substring search
# finds that first.
BUDGET_HEADING_RE = re.compile(r"(?im)^#{1,6}\s*evidence\s+budget\b.*$")

# The four lines, and what each one must contain.
BUDGET_LINES = ("read", "stop when", "no", "deliver")

# How many files a card may name. A card that names more has not budgeted
# anything; the right-column session read 521 distinct Swift files.
MAX_READ_FILES = 12

# What makes a card a research card. A card that matches is in scope.
RESEARCH_RE = re.compile(
    r"(?i)\b(design|research|investigat|proposal|explore|survey|audit)\b"
    r"|调研|方案|设计|审计"
)
# A card that names a source file is doing work on code, so it is in scope
# whether or not it says the word "design".
CODE_PATH_RE = re.compile(r"(?:Sources|Tests)/[A-Za-z0-9_./-]+\.swift")
# A file the card names. Not just .swift: a card that reads a tool script
# reads a .py, a card that reads a shell gate reads a .sh, and a card that
# reads the rulebook reads a .md. The first draft matched only .swift and
# reported the governance card as naming zero files, because every path in
# its budget was a .py.
FILE_PATH_RE = re.compile(
    r"[A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:swift|py|sh|md|json|yaml|yml|txt|plist|xcstrings)"
)

# A card that already names the files it will change has bound its evidence
# by its own output: the diff is the list. So a card with a GATES section is
# OUT of scope, and a card without one is IN scope, because that is the card
# that is still looking and has not said where it will stop.
GATES_MARKER = re.compile(r"(?im)^#{1,4}\s*gates\b|\bGATES\b")

# A line of the budget, e.g. "read: Foo.swift, Bar.swift".
BUDGET_LINE_RE = re.compile(
    r"^\s*[-*]?\s*(read|stop when|no|deliver)\s*:\s*(.+?)\s*$", re.I | re.M
)

# What the worker must not go looking for. Naming one of these in a card's
# research is the pattern that produced 97 history queries in one session.
FORBIDDEN_SOURCES = (
    "state.db",
    "session_search",
    "kanban.db",
    "agent.log",
    "errors.log",
)


def _board_cards(board: str | None = None) -> list[dict] | None:
    """Read the board's cards, or None if the board cannot be read.

    An unreadable board is not an empty board: the sweep refuses instead of
    reporting an agreement over cards it never read.
    """
    db = BOARD_DB
    if board:
        candidate = Path.home() / ".hermes/kanban/boards" / board / "kanban.db"
        if candidate.exists():
            db = candidate
    if not db.exists():
        print(f"no board database at {db}", file=sys.stderr)
        return None
    try:
        conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT id, title, body, status, assignee, created_at FROM tasks"
        ).fetchall()
        conn.close()
    except sqlite3.Error as exc:
        print(f"could not read the board: {exc}", file=sys.stderr)
        return None
    return [dict(r) for r in rows]


def _card_from_file(path: str) -> dict:
    text = Path(path).read_text(encoding="utf-8")
    # A draft body file may carry a title line; the title is the first
    # non-empty line that is not a markdown heading.
    title = ""
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("# "):
            # The card's own H1 is its title. A draft body that opens with
            # "# [T2] The window ..." carries the tier tag there.
            title = stripped[2:].strip()
            break
        if stripped.startswith("#"):
            continue
        title = stripped
        break
    return {
        "id": f"file:{path}",
        "title": title,
        "body": text,
        "status": "draft",
        "assignee": None,
        "created_at": int(time.time()),
    }


def _strip_fenced_blocks(body: str) -> str:
    """Blank out every fenced code block, keeping the line count.

    A card that documents the contract carries an EXAMPLE of the contract,
    and that example contains the heading "## EVIDENCE BUDGET" with the
    four lines under it. A heading search that does not skip fenced blocks
    finds the example first and reads the example's lines as the card's own
    budget, so the governance card would pass by quoting itself.

    The lines are replaced with empty strings rather than removed, so every
    offset in the original body still points at the same line.
    """
    out: list[str] = []
    fence: str | None = None
    for line in body.splitlines():
        stripped = line.lstrip()
        if fence is None:
            if stripped.startswith("```") or stripped.startswith("~~~"):
                fence = stripped[:3]
                out.append("")
                continue
            out.append(line)
        else:
            out.append("")
            if stripped.startswith(fence):
                fence = None
    return "\n".join(out)


def budget_section(body: str) -> str | None:
    """Return the text of the card's evidence budget section, or None.

    The heading is found as a HEADING, not as a word. A card that explains
    the contract in its own body writes the words "evidence budget" inside a
    fenced example, and a substring search finds THAT first: the
    governance card itself opens with an example block, and the search
    landed inside the example, read the example's four lines as the card's
    budget, and reported the card as unreadable.

    Fenced blocks are skipped for the same reason, one level deeper: the
    example's heading is a real heading inside the example. The scan works
    on LINES, not on characters: the blanked scan has the same line count
    as the body, so a line number found in the scan points at the same
    line in the body. A character offset would not, because blanking a
    fenced line shortens it.
    """
    if not body:
        return None
    body_lines = body.splitlines()
    scan_lines = _strip_fenced_blocks(body).splitlines()
    scan = "\n".join(scan_lines)
    match = BUDGET_HEADING_RE.search(scan)
    if match is None:
        return None
    start_line = scan.count("\n", 0, match.start())
    # The section runs until the next heading of the same or higher level.
    section = [body_lines[start_line]]
    for line in body_lines[start_line + 1:]:
        if line.lstrip().startswith("#"):
            break
        section.append(line)
    return "\n".join(section)


def budget_lines(body: str) -> dict[str, str]:
    """Return the four budget lines, lowercased key -> value."""
    section = budget_section(body)
    if section is None:
        return {}
    found: dict[str, str] = {}
    for match in BUDGET_LINE_RE.finditer(section):
        key = match.group(1).lower()
        value = match.group(2).strip()
        # First occurrence wins; a later duplicate does not overwrite a
        # contract that was already stated.
        found.setdefault(key, value)
    return found


def read_files(line: str) -> list[str]:
    """Return the file names the read line names."""
    return FILE_PATH_RE.findall(line or "")


def in_scope(card: dict) -> tuple[bool, str]:
    """Does this card need an evidence budget? Return (in_scope, why).

    The rule is deliberately mechanical, because a title cannot be read:
    the board's titles start with "cover" 24 times and "the" 5 times, so
    a verb heuristic misses most cards and the right-column card among them
    ("Add a todo section, a sub-agent section and a task section to the
    right column") reads as neither research nor code.

    So the rule reads the card's own output instead:

      a card that is still open owes a budget. Done, review and archived
      cards do not: their evidence is spent, and rewriting the cards
      already on the board is not this tool's business.

      a card with a GATES section is in scope, but on the relaxed rule:
      its read line may name the files it will change, because the diff IS
      its evidence list.

    A GATES section and an evidence budget are ORTHOGONAL, and this is the
    rule that matters most. GATES says how the work is verified AFTER it
    lands; the budget says what the worker may look at BEFORE it starts.
    The first draft of this tool said "a card with a GATES section is out
    of scope", and the right-column card found it: the card was "Add a
    task, todo and subagent section to the right column", it carried a
    GATES section, and it therefore passed a gate that would have told it
    to read seven files instead of 521.
    """
    body = card.get("body") or ""
    title = card.get("title") or ""
    if card.get("status") in ("done", "review", "archived"):
        return False, f"the card is {card.get('status')}, its evidence is spent"
    if GATES_MARKER.search(body):
        # A GATES section and an evidence budget are ORTHOGONAL. GATES says
        # how the work is verified AFTER it lands; the budget says what the
        # worker may look at BEFORE it starts. A card with a GATES section
        # still reads files, runs gates and may go looking for its own past,
        # so it still owes a budget.
        #
        # A card with a GATES section gets the relaxed rule: its read line
        # may name the files it will change, because the diff IS its
        # evidence list. A card without one must name what it will read.
        return True, "the card writes code, so it reads before it writes"
    if RESEARCH_RE.search(title):
        return True, "the title asks for research"
    if RESEARCH_RE.search(body[:4000]):
        return True, "the body asks for research"
    if CODE_PATH_RE.search(body):
        return True, "the body names a source file"
    return True, "the card states no evidence budget"


def is_subject(created_at: int | None) -> bool:
    """Is this card under the evidence contract?

    A card created before EVIDENCE_CONTRACT_FROM was dispatched under the
    old contract. It is reported, never blocked: the cards already on the
    board are not this tool's business to rewrite, and the ones in flight
    were priced under the old contract.

    A card with no creation time is treated as a subject. A card the board
    cannot date is a card the board cannot excuse.
    """
    if created_at is None:
        return True
    return int(created_at) >= EVIDENCE_CONTRACT_FROM


def contract_errors(card: dict) -> list[str]:
    """Return the contract errors of one card."""
    errors: list[str] = []
    scoped, why = in_scope(card)
    if not scoped:
        return errors

    body = card.get("body") or ""
    if not budget_section(body):
        return [
            "the card does research but carries no '## EVIDENCE BUDGET' section"
        ]

    lines = budget_lines(body)

    for key in BUDGET_LINES:
        if key not in lines:
            errors.append(f"the evidence budget has no '{key}:' line")

    if "read" in lines:
        files = read_files(lines["read"])
        if not files:
            errors.append(
                "the 'read:' line names no file, so the research is unbounded"
            )
        elif len(files) > MAX_READ_FILES:
            errors.append(
                f"the 'read:' line names {len(files)} files, over the cap of "
                f"{MAX_READ_FILES}: a card that lists {len(files)} files has "
                "not budgeted its evidence"
            )
        # A card that says it will read the board's own history is asking for
        # the loop that produced 97 history queries in one session.
        for source in FORBIDDEN_SOURCES:
            if source in lines["read"]:
                errors.append(
                    f"the 'read:' line names '{source}', which is the worker's "
                    "own history: research reads the code, not the transcript"
                )

    if "stop when" in lines and len(lines["stop when"]) < 8:
        errors.append("the 'stop when:' line states no condition")

    if "no" in lines and len(lines["no"]) < 3:
        errors.append("the 'no:' line refuses nothing")

    if "deliver" in lines and len(lines["deliver"]) < 8:
        errors.append("the 'deliver:' line names no artifact")

    return errors


def report(card: dict) -> dict:
    """Return the report row of one card."""
    errors = contract_errors(card)
    scoped, why = in_scope(card)
    created = card.get("created_at") or 0
    try:
        created = int(created)
    except (TypeError, ValueError):
        created = 0
    legacy = bool(created) and created < EVIDENCE_CONTRACT_FROM
    lines = budget_lines(card.get("body") or "")
    return {
        "id": card.get("id"),
        "title": card.get("title"),
        "status": card.get("status"),
        "in_scope": scoped,
        "why": why,
        "read_count": len(read_files(lines.get("read", ""))),
        "deliver": lines.get("deliver", ""),
        "legacy": legacy,
        "findings": errors,
    }


def print_card(row: dict) -> None:
    print(f"=== {row['id']}  {row['title']}")
    print(f"    scope: {'in scope' if row['in_scope'] else 'out of scope'} ({row['why']})")
    if row["in_scope"]:
        print(f"    read: {row['read_count']} file(s)   deliver: {row['deliver'] or '(none)'}")
    if row["legacy"]:
        print("    legacy: created before the evidence contract; reported, never blocked")
    if row["findings"]:
        for finding in row["findings"]:
            print(f"    ! {finding}")
    else:
        print("    ok: the card states its evidence budget")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cards", nargs="*", help="card ids; default = every card")
    parser.add_argument("--body", help="check a card body from a file")
    parser.add_argument("--live", action="store_true", help="only cards that are not done")
    parser.add_argument("--check", action="store_true", help="report contract errors")
    parser.add_argument("--board", help="board slug; default = the current board")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args(argv)

    if args.body:
        cards = [_card_from_file(args.body)]
    else:
        cards = _board_cards(args.board)
        if cards is None:
            if not args.json:
                print("=== the board could not be read ===")
            return 2
        if args.live:
            # "Live" means the card can still gather evidence. A card in
            # review has already spent its evidence, and a card in done or
            # archived has spent it and been judged.
            cards = [
                c for c in cards
                if c.get("status") not in ("done", "review", "archived")
            ]
        if args.cards:
            wanted = set(args.cards)
            cards = [c for c in cards if c.get("id") in wanted]

    rows = [report(card) for card in cards]

    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        for row in rows:
            print_card(row)
            print()

    if args.check or args.body:
        errors = [r for r in rows if r["findings"] and not r["legacy"]]
        if errors and not args.json:
            print(f"=== {len(errors)} card(s) do not state an evidence budget ===")
            for row in errors:
                print(f"  {row['id']}  {row['title']}")
                for finding in row["findings"]:
                    print(f"      ! {finding}")
            return 1
        if args.check and not args.json:
            print("=== every card states its evidence budget ===")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
