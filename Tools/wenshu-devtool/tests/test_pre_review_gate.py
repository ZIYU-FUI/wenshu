#!/usr/bin/env python3
"""test_pre_review_gate.py — the pre-review gate's own test suite.

Every case runs on FIXTURE text, = so the tests stay valid when the real
test output changes. = The cases are the ways this gate can be wrong, =
and each one is measured against the gate's own claims:

  1. a run that reported a test is a run that MEASURED something.
  2. a run that matched NO test case measured nothing (= the hole this
     gate exists to close: = `swift test --filter` on a renamed suite
     exits 0, = prints no summary, = and prints a warning, = and a
     reader that reads only the exit code calls that a PASS).
  3. a run that reported no test at all measured nothing.
  4. a card's filter line is read in BOTH quote styles (= a card
     written with double quotes names the same suite as one written with
     single quotes).
  5. a card's filter line the reader CANNOT parse is named (= the card
     asked for a gate that did not run, = and the reader must say so).
  6. THE COMMENT RULES HAVE ONE IMPLEMENTATION. = The reader that decides
     what a comment is, = the CJK pattern, = and the audit of the comment
     rules live in the judge (= `comment_lineage.py`), = and this gate
     carries none of them: = a rule with two arms is a rule with two
     answers, = and the author who satisfies one is bounced by the other
     (= measured 2026-11-24 on every live branch).
  7. the gate CALLS that one implementation (= the judge is on the path
     a branch takes to the review lane).

Run:  python3 Tools/wenshu-devtool/tests/test_pre_review_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "pre_review_gate.py"

spec = importlib.util.spec_from_file_location("pre_review_gate", TOOL)
assert spec is not None and spec.loader is not None
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

PASSED: list[bool] = []


def case(name: str, ok: bool, detail: str = "") -> bool:
    print(("  PASS  " if ok else "  FAIL  ") + name + (f"  [{detail}]" if detail else ""))
    PASSED.append(bool(ok))
    return bool(ok)


SWIFT_TESTING_SUMMARY = "Test run with 23 tests in 1 suite passed after 0.004 seconds."
XCTEST_SUMMARY = "Executed 24 tests, with 0 failures (0 unexpected) in 0.026 (0.027) seconds"
NO_MATCH_OUTPUT = "warning: No matching test cases were run"

CARD_SINGLE = """## GATES

- `swift test --filter 'BookStyleSheetTests|EngineStyleSheetBridgeTests'`
"""

CARD_DOUBLE = """## GATES

- `swift test --filter "BookStyleSheetTests|EngineStyleSheetBridgeTests"`
"""

CARD_UNPARSED = """## GATES

- swift test --filter BookStyleSheetTests
"""

# A card whose WHY merely MENTIONS the phrase, = and whose GATES
# section is clean. = The old reader lifted the prose mention as a
# filter and ran it, = and named the prose line as unreadable, = so the
# card failed for its own explanation.
CARD_PROSE_ONLY = """## WHY

= = `pre_review_gate.py` read only the EXIT CODE of each
`swift test --filter`.

## GATES

- `swift build --build-tests`
- `swift test --filter 'BookStyleSheetTests'`
"""

# A card that quotes a filter in its prose (= as the shape of a broken
# card), = and names its real suite in GATES. = The old reader lifted
# BOTH, = so it ran a suite the card never asked for.
CARD_PROSE_QUOTES = """## WHY

= = the broken card named `swift test --filter 'RenamedSuitesV2'`.

## GATES

- `swift test --filter 'BookStyleSheetTests'`
"""

# The same shape, = on a card with NO GATES heading (= so the reader
# falls back to the whole body). = = This is the case that pins the
# command-line check on its own: = the scope cannot help here, = so the
# prose line must be recognised as prose (= = not as a command to run).
CARD_NO_GATES = """## GOAL

= = the broken card named the suite as `swift test --filter 'RenamedSuitesV2'`, = and the working one as `swift test --filter 'BookStyleSheetTests'`.

## THE COMMANDS

- `swift build --build-tests`
- `swift test --filter 'BookStyleSheetTests'`
"""

# A card that names its suite in a MARKDOWN TABLE ROW. = A table row is
# a DECLARATION (= not prose), = so the reader must lift the filter out
# of it. = The shape is the one that reopened the vacuous green: = the
# suite in the table matches nothing, = and a reader that drops the row
# measures the other suite and declares every gate green.
CARD_TABLE_ROW = """## GOAL

A verdict on a card whose suite is named in a table.

## GATES

| the gate | what it proves |
|---|---|
| `swift test --filter 'RenamedSuitesV2'` | the suite that matches nothing |
| `swift test --filter 'StyleSheetWiringTests'` | the suite that passes |
"""

def main() -> int:
    print("test_pre_review_gate: the pre-review gate's own cases")

    # 1. a run that reported a test measured something.
    measured, matched_nothing = gate.measure_tests(SWIFT_TESTING_SUMMARY + "\n" + XCTEST_SUMMARY)
    case(
        "a run that reported a test is a run that MEASURED something",
        measured > 0 and not matched_nothing,
        f"measured={measured} matched_nothing={matched_nothing}",
    )

    # 2. the hole: a filter that matched nothing exits 0 and measures nothing.
    measured, matched_nothing = gate.measure_tests(NO_MATCH_OUTPUT)
    case(
        "a run that matched NO test case measured NOTHING (= and said so)",
        measured == 0 and matched_nothing,
        f"measured={measured} matched_nothing={matched_nothing}",
    )

    # 3. a run that reported no test at all measured nothing.
    measured, matched_nothing = gate.measure_tests("Build complete!\n")
    case(
        "a run that reported no test at all measured NOTHING",
        measured == 0 and not matched_nothing,
        f"measured={measured} matched_nothing={matched_nothing}",
    )

    # 4. both quote styles are read.
    single, unparsed = gate.filters_from_card(CARD_SINGLE)
    double, unparsed_double = gate.filters_from_card(CARD_DOUBLE)
    case(
        "a card's filter line is read in BOTH quote styles",
        single == ["BookStyleSheetTests|EngineStyleSheetBridgeTests"]
        and double == ["BookStyleSheetTests|EngineStyleSheetBridgeTests"]
        and not unparsed
        and not unparsed_double,
        f"single={single} double={double}",
    )

    # 5. an unreadable filter line is named.
    _, unparsed = gate.filters_from_card(CARD_UNPARSED)
    case(
        "a card's filter line the reader CANNOT parse is named",
        len(unparsed) == 1 and "BookStyleSheetTests" in unparsed[0],
        f"unparsed={unparsed}",
    )

    # 12. a PROSE mention is not a gate line (= and is not named).
    filters, unparsed = gate.filters_from_card(CARD_PROSE_ONLY)
    case(
        "a PROSE mention of the phrase is not a gate line (= and is not named)",
        filters == ["BookStyleSheetTests"] and not unparsed,
        f"filters={filters} unparsed={unparsed}",
    )

    # 13. a filter QUOTED in prose is not lifted (= the card never asked for it).
    filters, unparsed = gate.filters_from_card(CARD_PROSE_QUOTES)
    case(
        "a filter QUOTED in prose is NOT lifted (= the card never asked for that suite)",
        filters == ["BookStyleSheetTests"] and not unparsed,
        f"filters={filters} unparsed={unparsed}",
    )

    # 13b. a prose mention on a card with NO GATES heading (= the scope
    #      cannot help, = so the command-line check is what stops it).
    filters, unparsed = gate.filters_from_card(CARD_NO_GATES)
    case(
        "a PROSE mention is not a gate line (= even with no GATES section)",
        filters == ["BookStyleSheetTests"] and not unparsed,
        f"filters={filters} unparsed={unparsed}",
    )

    # 19. THE COMMENT RULES HAVE ONE IMPLEMENTATION, = and this file is the
    #     proof: = the gate that runs BEFORE the review lane must not carry a
    #     second reader of comments, = a second CJK pattern, = or a second
    #     audit of the same rule. = = A rule with two arms is a rule with two
    #     answers, = and the author who satisfies one is bounced by the other
    #     (= measured 2026-11-24: = the two arms disagreed on EVERY live
    #     branch, = and one arm charged a row the repo's own arms table
    #     declares CLEAN).
    own_source = TOOL.read_text(encoding="utf-8")
    judge_source = (TOOL.parent / "comment_lineage.py").read_text(encoding="utf-8")
    case(
        "the pre-review gate carries NO second comment-rule implementation",
        "cjk_audit" not in own_source
        and "CJK = re.compile" not in own_source
        and "def comment_parts" not in own_source
        and "def comment_lines" not in own_source,
        "the gate still carries its own reader or pattern",
    )
    case(
        "and the ONE implementation is the judge (= the gate calls it)",
        "comment_lineage.py" in own_source
        and "CJK = re.compile" in judge_source
        and "def comment_text" in judge_source,
        "the judge does not carry the pattern or the reader",
    )

    # 20. a suite named in a MARKDOWN TABLE ROW is lifted (= a table row
    #     is a declaration, = and dropping it would measure nothing).
    filters, unparsed = gate.filters_from_card(CARD_TABLE_ROW)
    case(
        "a suite named in a TABLE ROW is lifted (= the row is a declaration)",
        "RenamedSuitesV2" in filters and "StyleSheetWiringTests" in filters and not unparsed,
        f"filters={filters} unparsed={unparsed}",
    )

    failed = PASSED.count(False)
    print(f"test_pre_review_gate: {PASSED.count(True)}/{len(PASSED)} cases passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
