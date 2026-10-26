#!/usr/bin/env python3
"""
gate_width_gate.py - the gate-width gate: does this card ask for a narrow gate?

One question, one gate:

  CONTRACT  does the card body ask for a gate wider than its tier buys, and
            does it name the specific suite that owns the touched file?

WHY THE GATE EXISTS (measured on board wenshu-par, 2026-10-26):

  - 21 of the 36 open cards carried a gate the tool could read as WIDE:
    a whole-suite run, or a "no new failures against the baseline" demand.
  - The full suite is 224 s on this machine (3m44s, 531 test files). ONE
    filtered suite that owns the touched file is 10.5 s. That is 21x.
  - The baseline is RED (= WenshuAppTests reports failures on main), so
    "the whole suite has no new failures against the baseline" forces the
    worker to run the whole suite AND diff the result against a recorded
    baseline, which is the most expensive gate the board has.
  - Measured inside one tier: a body demanding the whole suite against a
    red baseline ran 3.44 times for 65.7 min per card; a body naming one
    filtered suite ran 2.00 times for 17.6 min per card. Same tier, same
    cap, same reviewer. The gate is the whole difference.
  - The cost of a wide gate is paid even when the card succeeds: the
    worker spends the cap running the suite, and the cap is per attempt.

WHAT THE GATE ALLOWS (the tier's gate, from ticket_tier.py):

  T1  swift build + ONE filtered suite that owns the touched file
  T2  swift build + a filtered suite per touched area; a baseline compare
      only where the baseline is red
  T3  the full gate set, incl. a red-baseline comparison and a visual proof

So a T3 card MAY ask for the whole suite. A T1 card may NOT, and the
tier tool already rejects that. What the tier tool does NOT do is
require the narrow gate to be NAMED: a card whose body says nothing
about tests gets "unstated" and passes silently. An unstated gate is
how a worker decides to run the whole suite on its own.

THE GATE IS ABOUT THE NAMED SUITE, NOT ABOUT THE WORK. A card that
writes one file needs the suite that owns that file, not the suite that
owns everything. A card that writes six files across three areas needs
one suite per area. Naming the suite is what makes the gate cheap and
complete at the same time.

THE GATE STARTS ON A DATE, NOT ON A FLAG. A card created before
GATE_CONTRACT_FROM was dispatched under the old contract: it is
reported, never blocked, because rewriting the cards already on the
board is not this tool's business.

Usage:
    gate_width_gate.py --body FILE   the contract of one draft body
    gate_width_gate.py --card ID     the contract of one card on the board
    gate_width_gate.py --check       every card on the board
    gate_width_gate.py --json        machine-readable output

Exit code 0 = the gate is satisfied, 1 = a contract error, 2 = the board
could not be read.
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

# The epoch the gate-width contract starts at (= when this gate landed on
# main). A card dispatched before it is reported, never blocked.
GATE_CONTRACT_FROM = 1793164800  # 2026-10-28 16:00 CST

# A `swift test --filter <name>` invocation. The filter names the suite
# that owns the touched file, so its presence IS the narrow gate.
FILTERED_SUITE_RE = re.compile(r"swift\s+test[^\n]*--filter\s+\S+")

# A whole-suite demand, in prose. Four spellings, all measured on this
# board:
#   "swift test" with no filter  (= the tier tool's own FULL_SUITE_RE)
#   "the whole app test suite" / "the whole suite" / "the entire suite"
#   "no new failures against the baseline" (= the suite PLUS a diff)
FULL_SUITE_PHRASE_RE = re.compile(
    r"the\s+whole\s+(?:app\s+)?(?:test\s+)?suite"
    r"|the\s+entire\s+(?:app\s+)?(?:test\s+)?suite"
    r"|the\s+full\s+(?:app\s+)?(?:test\s+)?suite"
    r"|all\s+(?:the\s+)?tests?\s+pass"
    r"|\bno\s+new\s+failures\s+against\s+the\s+baseline\b"
    r"|\bagainst\s+the\s+baseline\b"
    r"|\bversus\s+the\s+baseline\b",
    re.I,
)

# A bare `swift test` with no filter = the whole suite. The tier tool
# already reads this form (ticket_tier.FULL_SUITE_RE), so the gate-width
# gate reads the SAME form: two tools that disagree about what "wide"
# means is how a card slips through.
BARE_FULL_SUITE_RE = ticket_tier.FULL_SUITE_RE

# The word "suite" alone is not a wide gate: "the suite that owns this
# file" is the narrow form, and "a filtered suite per touched area" is
# the T2 form.
NARROW_SUITE_PHRASE_RE = re.compile(
    r"filtered\s+suite"
    r"|one\s+suite\s+per\s+touched\s+area"
    r"|suite\s+per\s+touched\s+area"
    r"|the\s+suite\s+that\s+owns"
    r"|owning\s+suite",
    re.I,
)

# A card that writes NO Swift code has no Swift suite to name: its gate is
# the command that owns what it writes (= the devtool's own test script, = a
# docs link check). A gate tool that insists on `swift test --filter` for
# those cards would block every tool card and every docs card, so the rule
# is: NAME THE GATE COMMAND, whatever owns the work.
#
# The forms accepted here are the ones this project runs as a gate:
#   python3 Tools/.../tests/test_x.py     (= the devtool's own suite)
#   pytest / python3 -m pytest             (= a python test run)
#   a markdown link check                   (= a docs gate)
NAMED_OTHER_GATE_RE = re.compile(
    r"python3\s+\S*tests?/test_\S+\.py"
    r"|python3\s+-m\s+pytest"
    r"|\bpytest\b"
    r"|markdown[- ]link[- ]check"
    r"|\bglossary\b.*\bcheck\b"
    r"|\bdictionary\b.*\bcheck\b",
    re.I,
)


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
    try:
        out = subprocess.run(
            [binary, "kanban", *args], capture_output=True, text=True, timeout=120
        )
    except (OSError, subprocess.SubprocessError) as exc:
        return 127, str(exc)
    return out.returncode, out.stdout


def is_subject(created_at: int | None) -> bool:
    """Whether a card was created under the gate-width contract."""
    if created_at is None:
        return True  # a draft body is a card that does not exist yet
    return created_at >= GATE_CONTRACT_FROM


def gate_demands(body: str) -> dict:
    """What gate the body asks for, and the sentences that ask for it."""
    demands: list[str] = []
    for line in body.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if FILTERED_SUITE_RE.search(stripped):
            continue
        if FULL_SUITE_PHRASE_RE.search(stripped):
            demands.append(stripped)
        elif BARE_FULL_SUITE_RE.search(stripped):
            # A bare `swift test` = the whole suite. The tier tool reads
            # this form, so the gate-width gate reads it too.
            demands.append(stripped)
    named = FILTERED_SUITE_RE.findall(body)
    named_other = NAMED_OTHER_GATE_RE.findall(body)
    return {
        "wide": bool(demands),
        "named_filters": named,
        "named_other": named_other,
        "demands": demands,
        "narrow_phrase": bool(NARROW_SUITE_PHRASE_RE.search(body)),
    }


def contract_errors(body: str, created_at: int | None = None) -> list[str]:
    """Every way the body breaks the gate-width contract."""
    tier, _reasons = ticket_tier.tier_of(body)
    demand = gate_demands(body)

    errors: list[str] = []

    if demand["wide"]:
        # T3 OWNS the full gate set, so a wide demand is legal there.
        if tier == "T3":
            pass
        else:
            errors.append(
                f"the body asks for a wide gate ({tier} buys a narrow one): "
                + "; ".join(d[:120] for d in demand["demands"][:3])
            )

    # A card must name the suite that owns what it writes, unless it
    # already says so in words. "unstated" is how a worker decides to
    # run the whole suite on its own. A card that writes no Swift code
    # names its own gate command instead (= the devtool's test script).
    if (
        not demand["named_filters"]
        and not demand["named_other"]
        and not demand["narrow_phrase"]
    ):
        errors.append(
            "the body names no suite: name the filtered suite that owns each "
            "touched file, so the gate is narrow and complete"
        )

    return errors


def card_body(card_id: str, board: str = BOARD) -> tuple[str, int | None]:
    """The card's body text and its creation epoch, or ("", None)."""
    rc, out = _run_hermes(["--board", board, "show", card_id])
    if rc != 0:
        return "", None
    i = out.find("\nBody:\n")
    if i < 0:
        return "", None
    body = out[i + 7 :]
    for marker in ("\nComments (", "\nEvents", "\nRun History"):
        j = body.find(marker)
        if j >= 0:
            body = body[:j]
    created = None
    m = re.search(r"created[_ ]?(?:at)?[:=]\s*(\d{9,})", out, re.I)
    if m:
        created = int(m.group(1))
    return body, created


def report_body(body: str, created_at: int | None = None) -> dict:
    """The gate verdict for one body."""
    tier, reasons = ticket_tier.tier_of(body)
    demand = gate_demands(body)
    errors = contract_errors(body, created_at)
    if created_at is not None and not is_subject(created_at):
        errors = []  # pre-contract card: reported, never blocked
    return {
        "tier": tier,
        "reasons": reasons,
        "gate_width": "wide" if demand["wide"] else (
            "narrow"
            if demand["named_filters"] or demand["named_other"] or demand["narrow_phrase"]
            else "unstated"
        ),
        "named_filters": demand["named_filters"],
        "named_other": demand["named_other"],
        "demands": demand["demands"],
        "findings": errors,
    }


def report_card(card_id: str, board: str = BOARD) -> dict:
    body, created = card_body(card_id, board)
    row = report_body(body, created)
    row["id"] = card_id
    return row


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", help="check a card body from a file")
    parser.add_argument("--card", help="check one card on the board")
    parser.add_argument("--check", action="store_true", help="every card on the board")
    parser.add_argument("--board", default=BOARD, help="board slug")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument(
        "--plan", action="store_true", help="print the gate contract table"
    )
    args = parser.parse_args()

    if args.plan:
        print("=== wenshu gate-width contract ===")
        print()
        print("T1 (trivial)")
        print("  gate       swift build + ONE filtered suite that owns the touched file")
        print("  may NOT ask for the whole suite, or a red-baseline comparison")
        print()
        print("T2 (standard)")
        print("  gate       swift build + a filtered suite per touched area")
        print("  may NOT ask for the whole suite")
        print()
        print("T3 (deep)")
        print("  gate       the full gate set, incl. a red-baseline comparison")
        print("  MAY ask for the whole suite (= T3 owns the full gate set)")
        print()
        print("Every tier must NAME its gate, as a command:")
        print()
        print("  swift build")
        print("  swift test --filter <the suite that owns the touched file>")
        print()
        print("A card that writes no Swift code names its own gate command")
        print("(= the devtool's own test script, = a docs link check).")
        print()
        print("Measured on this machine, 2026-10-26: one filtered suite is")
        print("10.5 s; the whole tree (531 test files) is 224 s. 21x, and the")
        print("baseline is red, so a whole-suite gate also pays a diff.")
        print()
        print("Say what the card DOES, not what it avoids: this gate reads")
        print("every line, so 'the whole suite is NOT this card's gate' reads")
        print("as a wide-gate DEMAND.")
        return 0

    rows: list[dict] = []

    if args.body:
        body = Path(args.body).read_text(encoding="utf-8")
        rows.append({"id": args.body, **report_body(body)})
    elif args.card:
        rows.append(report_card(args.card, args.board))
    else:
        rc, out = _run_hermes(["--board", args.board, "list", "--json"])
        if rc != 0:
            if not args.json:
                print("=== the board could not be read ===")
            return 2
        try:
            data = json.loads(out)
        except json.JSONDecodeError:
            if not args.json:
                print("=== the board could not be read ===")
            return 2
        if isinstance(data, dict):
            data = data.get("tasks", [])
        if not isinstance(data, list):
            if not args.json:
                print("=== the board could not be read ===")
            return 2
        for card in data:
            cid = card.get("id")
            if not cid:
                continue
            body = card.get("body") or ""
            if isinstance(body, bytes):
                body = body.decode("utf-8", "replace")
            rows.append({"id": cid, **report_body(body, card.get("created_at"))})

    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        errors = 0
        for row in rows:
            if row["findings"]:
                errors += 1
                print(f'  {row["id"]}  {row["tier"]}  gate={row["gate_width"]}')
                for finding in row["findings"]:
                    print(f"      ! {finding}")
        if errors:
            print(f"=== {errors} card(s) ask for a gate wider than their tier buys ===")
        else:
            print("=== every card names a gate its tier buys ===")

    return 1 if any(r["findings"] for r in rows) else 0


if __name__ == "__main__":
    sys.exit(main())
