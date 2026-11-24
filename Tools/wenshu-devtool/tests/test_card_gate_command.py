#!/usr/bin/env python3
"""test_card_gate_command.py — the ONE reader of "what gate does this card ask for?".

Two gates read the same card body, and they used to answer differently:

  - `gate_width_gate.py` accepted a card that names its OWN gate command
    (= the devtool's own test script, a pytest run, a docs link check),
    because a card that writes no Swift code has no Swift suite to filter.
  - `pre_review_gate.py` read ONLY `swift test --filter` lines, so a card
    that writes no Swift code could never satisfy it: the filter list was
    empty, and the gate failed with "no suite was measured" no matter what
    the card said.

Measured on board `wenshu-par`, 2026-11-24: 819 of the board's cards name
the devtool or `Scripts/` in their body, and 433 of those carry a comment
that quotes the suite rule. So the two gates disagreed about the majority
of the board's cards.

`card_gate_command.py` is the ONE reader both gates call, and this suite
pins the properties that make the agreement hold:

  1. a `swift test --filter <suite>` line is read as a Swift filter, in
     both quote styles.
  2. a `python3 .../tests/test_x.py` line is read as the card's own gate
     command (= the gate of a card that writes no Swift).
  3. the own command is read from the GATES section for EXECUTION, and from
     the WHOLE body for RECOGNITION (= the width gate asks "does this card
     name a gate at all?", which a prose mention answers).
  4. a sentence that MENTIONS a gate is not a gate (= a WHY paragraph
     quoting `swift test --filter` is prose).
  5. the two gates AGREE: for every card body, the width gate says the card
     names a gate exactly when the pre-review gate has something to run.
  6. a card that names NO gate at all is named by neither (= the width gate
     reports "unstated", and the pre-review gate reports "no gate was
     measured").

Run:  python3 Tools/wenshu-devtool/tests/test_card_gate_command.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

DEVTOOL = Path(__file__).resolve().parent.parent
REPO = DEVTOOL.parent.parent


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


sys.path.insert(0, str(DEVTOOL))
cgc = _load("card_gate_command", DEVTOOL / "card_gate_command.py")
gwg = _load("gate_width_gate", DEVTOOL / "gate_width_gate.py")

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    if got == want:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        FAILURES.append(name)


SWIFT_CARD = """# A card

## WHAT TO BUILD

- A Swift file and its test.

## GATES TO RUN

- `swift test --filter 'MySuiteTests'`
- `swift test --filter "OtherSuiteTests"`
"""

TOOL_CARD = """# A card

## WHAT TO BUILD

- A devtool script and its suite.

## GATES TO RUN

- `python3 Tools/wenshu-devtool/tests/test_my_gate.py`
"""

NO_GATE_CARD = """# A card

## WHAT TO BUILD

- A file.

## GATES TO RUN

- the check that matters
"""

# = = = A CARD THAT NAMES ITS GATE IN PROSE ONLY. = = = = = = = = = = = = =
# = = = The width gate asks "is the gate NARROW?", and a phrase like = = = =
# = = = "the suite that owns this file" answers that. The pre-review gate = =
# = = = asks "did something MEASURE?", and a phrase cannot answer that. = = =
# = = = The difference is intentional (= = = = the house reference says the = =
# = = = remedy for a Swift card is to pass the filter on the command line, = =
# = = = = and a card with no Swift must name its OWN gate command). = = = = = = =

PROSE_CARD = """# A card

## WHY

The reader read only the EXIT CODE of each `swift test --filter`, and a
python3 Tools/wenshu-devtool/tests/test_thing.py in a sentence is a
sentence about the gate, not the gate.

## GATES TO RUN

- `python3 Tools/wenshu-devtool/tests/test_the_gate.py`
"""


def main() -> int:
    print("the two gates read the card's gate the same way")

    # ---- case 1: a Swift filter, in both quote styles -------------------
    filters = cgc.swift_filters(SWIFT_CARD)
    check("both quote styles are read as filters", sorted(filters), ["MySuiteTests", "OtherSuiteTests"])

    # ---- case 2: the card's own command --------------------------------
    own = cgc.own_commands(TOOL_CARD)
    check("a python gate command is read", own, ["python3 Tools/wenshu-devtool/tests/test_my_gate.py"])

    # ---- case 3: the two views differ in WHERE they read ---------------
    check(
        "the EXECUTION view reads only the GATES section",
        cgc.own_commands(PROSE_CARD),
        ["python3 Tools/wenshu-devtool/tests/test_the_gate.py"],
    )
    check(
        "the RECOGNITION view reads the whole body",
        len(cgc.named_own_commands(PROSE_CARD)),
        2,
    )

    # ---- case 4: a sentence that mentions a gate is not a gate ---------
    check(
        "a prose mention is not a gate line",
        [line for line in cgc.gate_lines(PROSE_CARD)],
        ["python3 Tools/wenshu-devtool/tests/test_the_gate.py"],
    )

    # ---- case 5: the two gates agree about a RUNNABLE gate --------------
    # = = = THE PROPERTY THAT MATTERS. = = = The width gate asks "is the
    # = = = card's gate NARROW?", and the pre-review gate asks "did a gate
    # = = = MEASURE?". So the shared property is: a card that names a
    # = = = RUNNABLE gate (= a Swift filter, or its own command) is a card
    # = = = the pre-review gate can run, and a card that names NO gate at
    # = = = all is a card the pre-review gate has nothing to run.
    bodies = {
        "a swift card": SWIFT_CARD,
        "a tool card": TOOL_CARD,
        "a card with no gate": NO_GATE_CARD,
        "a card with prose": PROSE_CARD,
    }
    for label, body in bodies.items():
        width = gwg.report_body(body)
        width_names_a_runnable_gate = bool(
            width["named_filters"] or width["named_other"]
        )
        pre_review_has_a_run = bool(
            cgc.swift_filters(body) or cgc.own_commands(body)
        )
        check(
            f"the gates agree about {label}",
            width_names_a_runnable_gate,
            pre_review_has_a_run,
        )

    # ---- case 6: a card that names no gate is named by neither ----------
    width = gwg.report_body(NO_GATE_CARD)
    check("a card with no gate reads as unstated", width["gate_width"], "unstated")
    check(
        "a card with no gate gives the pre-review gate nothing to run",
        bool(cgc.swift_filters(NO_GATE_CARD) or cgc.own_commands(NO_GATE_CARD)),
        False,
    )

    # ---- case 7: a prose-only gate is narrow but not yet runnable --------
    # = = = The width gate reads the prose as narrow (= it does not accuse
    # = = = the card of asking for the whole suite). The pre-review gate
    # = = = still has nothing to run, and says so. The house reference
    # = = = names that difference: a Swift card's remedy is the reviewer
    # = = = passing the filter on the command line, and a card with no
    # = = = Swift must name its OWN gate command.
    prose_only = """# A card

## GATES TO RUN

- the suite that owns this file
"""
    width = gwg.report_body(prose_only)
    check("a prose-only gate is narrow (= not wide)", width["gate_width"], "narrow")
    check(
        "a prose-only gate gives the pre-review gate nothing to run",
        bool(cgc.swift_filters(prose_only) or cgc.own_commands(prose_only)),
        False,
    )

    print()
    if FAILURES:
        print(f"{len(FAILURES)} case(s) failed: {', '.join(FAILURES)}")
        return 1
    print("the two gates read the card's gate the same way: every case passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
