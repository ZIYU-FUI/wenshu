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

    failed = PASSED.count(False)
    print(f"test_pre_review_gate: {PASSED.count(True)}/{len(PASSED)} cases passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
