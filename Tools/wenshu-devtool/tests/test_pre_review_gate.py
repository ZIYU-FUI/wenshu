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
  6. a whole-line comment is a comment.
  7. a TRAILING comment is a comment (= the style the repository uses in
     543 lines across 184 files, = and the shape the old reader missed).
  8. a line inside a block comment is a comment.
  9. a `//` inside a string literal is NOT a comment.
 10. a CJK string literal is NOT a comment (= the literals stay: = a
     model's displayName, = a test fixture's prose).
 11. a CJK literal in a comment IS caught (= the CJK audit's whole job).

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

# A CJK literal on a line that ALSO carries a trailing comment. = The
# literal is not a comment, = so the audit must not report it.
#
# = The literal is a URL, = so it carries a `//` of its OWN, = and the
# CJK sits AFTER that `//`. = That is what pins the blanking: = without
# it, = the reader would take the URL's `//` as the comment's start, =
# and the CJK would land inside the "comment part" (= and be reported).
CJK_LITERAL_WITH_TRAILING_COMMENT = 'let u = "https://example.com/唐朝"  // the link'
CJK_IN_TRAILING_COMMENT = 'let size = 11  // the body is 通用'
CJK_IN_BLOCK_COMMENT = "/* the body is 通用 */"
# A BLOCK comment that opens BEFORE a `//` on the same line. = The
# comment part must start at the comment's OWN marker (= the `/*`), = so
# the CJK inside the block is read; = reading from the `//` instead
# slices the part from the wrong marker and misses the CJK.
#
# = The first line carries a URL inside the block (= the repository's own
# idiom: = 58 tracked Swift lines carry both `/*` and `//`), = so it is
# the shape that hides the CJK twice over.
CJK_IN_BLOCK_COMMENT_WITH_URL = "let x = 1  /* the body is 通用 = see http://example.com */"
# The same shape, = with a trailing note after the block.
CJK_IN_BLOCK_COMMENT_WITH_TRAILING_NOTE = "let x = 1  /* the body is 通用 */  // a trailing note"
# The same shape, = with the CJK after the URL (= so the `//` inside the
# block is the FIRST `//` on the line).
CJK_IN_BLOCK_COMMENT_AFTER_URL = "let x = 1  /* see http://example.com = the body is 通用 */"
# A MULTILINE literal (= = three double quotes) = whose own text holds a
# `//`. = The scanner that toggles on the quote one at a time leaves its
# state wrong after the triple, = so the `//` inside the literal would be
# read as a comment's start.
#
# = The literal SPANS the lines (= = that is what a multiline literal
# is), = so the state must be carried across them: = the line that
# OPENS it is followed by a line whose `//` is still inside the literal.
# = The CJK sits AFTER that `//` (= = inside the URL), = so the case
# tells the two behaviours apart: = with the state carried the line is
# blanked (= no comment at all), = and without it the `//` starts a
# "comment" that holds the CJK.
CJK_IN_MULTILINE_LITERAL = 'let doc = """\n[链接](https://example.com/通用)\n"""  // the note'


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

    # 6. a whole-line comment is a comment.
    comments = gate.comment_lines(["// the sheet's own face", "let x = 1"])
    case(
        "a whole-line comment is a comment",
        comments == ["// the sheet's own face"],
        f"comments={comments}",
    )

    # 7. a trailing comment is a comment (= the shape the old reader missed).
    comments = gate.comment_lines(["let x = 1  // the body's own size"])
    case(
        "a TRAILING comment is a comment",
        comments == ["let x = 1  // the body's own size"],
        f"comments={comments}",
    )

    # 8. a line inside a block comment is a comment.
    comments = gate.comment_lines(["/* the sheet's own", "   face */", "let x = 1"])
    case(
        "a line inside a block comment is a comment",
        comments == ["/* the sheet's own", "   face */"],
        f"comments={comments}",
    )

    # 9. a `//` inside a string literal is not a comment.
    comments = gate.comment_lines(['let url = "https://example.com/a"  // the link'])
    case(
        "a `//` inside a string literal is NOT a comment (= the trailing comment still is)",
        comments == ['let url = "https://example.com/a"  // the link'],
        f"comments={comments}",
    )

    # 10. a CJK string literal is not a comment (= the literals stay).
    comments = gate.comment_lines(['case .general: return "通用"'])
    case(
        "a CJK string literal is NOT a comment (= the literals stay)",
        comments == [],
        f"comments={comments}",
    )

    # 11. a CJK literal in a comment IS caught.
    comments = gate.comment_lines(["// the body's own size (= 行距 1.55)"])
    case(
        "a CJK literal in a comment IS caught (= the CJK audit's whole job)",
        len(comments) == 1,
        f"comments={comments}",
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

    # 14. a CJK literal on a line that carries a trailing comment (= the
    #     literal is NOT reported: = the comment part is what is read).
    audited = [line for line, part in gate.comment_parts([CJK_LITERAL_WITH_TRAILING_COMMENT]) if gate.CJK.search(part)]
    case(
        "a CJK literal beside a trailing comment is NOT reported (= the literals stay)",
        audited == [],
        f"audited={audited}",
    )

    # 15. a CJK in a TRAILING comment IS reported (= the other half).
    audited = [line for line, part in gate.comment_parts([CJK_IN_TRAILING_COMMENT]) if gate.CJK.search(part)]
    case(
        "a CJK in a TRAILING comment IS reported (= the comment part is what is read)",
        len(audited) == 1,
        f"audited={audited}",
    )

    # 16. a CJK in a BLOCK comment IS reported (= the other half).
    audited = [line for line, part in gate.comment_parts([CJK_IN_BLOCK_COMMENT]) if gate.CJK.search(part)]
    case(
        "a CJK in a BLOCK comment IS reported (= the comment part is what is read)",
        len(audited) == 1,
        f"audited={audited}",
    )

    # 17. a `//` inside a MULTILINE literal is NOT a comment (= the
    #     triple quote must be matched as a unit).
    audited = [
        line for line, part in gate.comment_parts(CJK_IN_MULTILINE_LITERAL.split("\n")) if gate.CJK.search(part)
    ]
    case(
        "a `//` inside a MULTILINE literal is NOT a comment (= the triple is matched as one)",
        audited == [],
        f"audited={audited}",
    )

    # 18. a CJK in a BLOCK comment that opens BEFORE a `//` on the same
    #     line IS reported (= the comment part starts at the comment's
    #     OWN marker, = not at the first `//` on the line).
    for fixture, label in (
        (CJK_IN_BLOCK_COMMENT_WITH_URL, "= the block holds a URL"),
        (CJK_IN_BLOCK_COMMENT_WITH_TRAILING_NOTE, "= a trailing note follows the block"),
        (CJK_IN_BLOCK_COMMENT_AFTER_URL, "= the CJK sits after the URL"),
    ):
        audited = [line for line, part in gate.comment_parts([fixture]) if gate.CJK.search(part)]
        case(
            f"a CJK in a BLOCK comment beside a `//` IS reported ({label})",
            len(audited) == 1,
            f"audited={audited}",
        )

    # 19. a suite named in a MARKDOWN TABLE ROW is lifted (= a table row
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
