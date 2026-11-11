#!/usr/bin/env python3
"""test_swift_test_compare.py — the log comparison tool's own test suite.

The tool compares two `swift test` logs for their failure sets. = The
failure it has to catch is the one a comparison built on the WRONG shape
makes: = a `swift test` log reports failures in TWO shapes, = and a
comparison that reads only one of them silently misses half of them.

The two shapes:

  - **Swift Testing** prints `Test run with N tests in M suites
    passed/failed` and, for a failed expectation, `... recorded an issue
    at FILE:LINE:COL`.
  - **The XCTest bundles** print NO `Test run with` line at all. = They
    report through `Test Case '-[Suite testName]' failed` and
    `Executed N tests, with M failures`.

So the cases are:

  1. a Swift Testing failure is found (= the tool's baseline case);
  2. an XCTest failure is ALSO found (= the case a one-shape comparison
     misses, = and the reason the tool exists);
  3. a tip that adds a failure exits 1 (= the tool's verdict);
  4. a tip that adds NO failure exits 0 (= and the base's failures that
     the tip does not have are NOT a regression);
  5. one XCTest failure is counted ONCE (= the case line names it, = and
     the tally is the fallback, = so a double count would be a
     miscount);
  6. a non-zero XCTest tally with no case line is still reported (= so
     an unfamiliar case line's shape is never silently dropped);
  7. an unreadable log exits 2 (= and says so).

Run:  python3 Tools/wenshu-devtool/tests/test_swift_test_compare.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "swift_test_compare.py"

FAILURES: list[str] = []
PASSES = 0


def check(name: str, condition: bool, detail: str = "") -> None:
    global PASSES
    if condition:
        PASSES += 1
        print(f"  PASS  {name}")
    else:
        FAILURES.append(name)
        print(f"  FAIL  {name}" + (f" — {detail}" if detail else ""))


SWIFT_TESTING_LOG = """Test run with 3557 tests in 550 suites failed after 152.292 seconds with 1 issue.
\U0001f6d4  Test "the chat's @-mention path registers" recorded an issue at AsyncDelegationRegistryTests.swift:104:9: Expectation failed: mentionsReported
"""

XCTEST_LOG = """Test run with 3557 tests in 550 suites failed after 152.292 seconds with 1 issue.
Test Case '-[WenshuAppTests.ImportAgentRefusalLadderTests testRefusesTheImport]' failed (0.30 seconds).
Test Case '-[WenshuAppTests.SomeOtherTests testSomething]' passed (0.10 seconds).
\t Executed 1 test, with 1 failure (0 unexpected) in 0.300 (0.301) seconds
\t Executed 18 tests, with 0 failures (0.011) seconds
"""

# The REAL shape a `swift test` run prints: = ONE failing test tallied at
# THREE levels (= the suite, = the `.xctest` bundle, = and `All tests`),
# = each line carrying the SAME count. = ⇒ The lines are AGGREGATES at
# different levels, = not independent counts.
XCTEST_REAL_LOG = """Test run with 2 tests in 1 suite failed after 0.055 seconds with 1 issue.
Test Case '-[XctlogTests.XctlogTests testFails]' failed (0.055 seconds).
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.055 (0.055) seconds
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.055 (0.055) seconds
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.055 (0.056) seconds
"""


# TWO failing bundles: = the run has three `.xctest` bundles, = and each
# is a SIBLING scope with its own nested aggregate levels. = Bundle A's
# case line has a shape the parser does NOT recognise (= the fallback
# exists for exactly that), = and bundle B's case line parses.
#
# ⇒ ⇒ AND EACH BUNDLE CARRIES THREE TALLY LINES (= the real shape: = the
# suite's own tally, = the `Selected tests` chain's, = and the bundle's
# total) = because that is what makes the two scopes DIFFER: = within one
# bundle the maximum is 1 (= one failure), = and across two bundles the sum
# is 2 (= two failures) = while a single maximum over the whole log is 1.
#
# ⇒ ⇒ ⇒ AND BUNDLE A'S CASE LINE MUST BE UNPARSEABLE, = because the
# fallback only fires when the tallied count OUTNUMBERS the named cases.
# ⇒ ⇒ With two PARSEABLE case lines the two implementations agree (= the
# count equals the named count, = so the fallback never fires, = so the
# case passes under both) = and the fixture holds nothing. = ⇒ MEASURED:
# with two parseable case lines the mutation that takes one scope instead
# of per-bundle left the suite GREEN.
XCTEST_TWO_BUNDLES = """Test Suite 'Selected tests' started at 2026-11-11 08:00:00.000.
Test Suite 'WenshuDataTests.xctest' started at 2026-11-11 08:00:00.010.
Test Case 'WenshuDataTests.DataTests testFails' failed (0.05 seconds).
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
Test Suite 'WenshuDataTests.xctest' failed at 2026-11-11 08:00:00.100.
Test Suite 'Selected tests' started at 2026-11-11 08:00:01.000.
Test Suite 'WenshuAppTests.xctest' started at 2026-11-11 08:00:01.010.
Test Case '-[WenshuAppTests.AgentToolTests testTool]' failed (0.05 seconds).
\t Executed 3 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
\t Executed 3 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
\t Executed 3 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
Test Suite 'WenshuAppTests.xctest' failed at 2026-11-11 08:00:01.100.
"""

# The SAME two bundles, = but the tip FIXED bundle B: = only bundle A
# remains, = and its case line is the unparseable one.
XCTEST_ONE_BUNDLE = """Test Suite 'Selected tests' started at 2026-11-11 08:00:00.000.
Test Suite 'WenshuDataTests.xctest' started at 2026-11-11 08:00:00.010.
Test Case 'WenshuDataTests.DataTests testFails' failed (0.05 seconds).
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.05 (0.05) seconds
Test Suite 'WenshuDataTests.xctest' failed at 2026-11-11 08:00:00.100.
"""


def run_tool(base: str, tip: str) -> tuple[int, str]:
    """Run the tool on two log bodies (= written to temp files)."""
    with tempfile.TemporaryDirectory() as tmp:
        base_path = Path(tmp) / "base.log"
        tip_path = Path(tmp) / "tip.log"
        base_path.write_text(base, encoding="utf-8")
        tip_path.write_text(tip, encoding="utf-8")
        proc = subprocess.run(
            [sys.executable, str(TOOL), str(base_path), str(tip_path)],
            capture_output=True,
            text=True,
        )
        return proc.returncode, proc.stdout + proc.stderr


def main() -> int:
    print("test_swift_test_compare.py")

    # 1. A Swift Testing failure is found.
    code, out = run_tool(SWIFT_TESTING_LOG, SWIFT_TESTING_LOG)
    check(
        "a Swift Testing failure is found",
        "AsyncDelegationRegistryTests.swift:104:9" in out,
        out[:300],
    )

    # 2. An XCTest failure is ALSO found (= the case a one-shape
    #    comparison misses).
    code, out = run_tool(XCTEST_LOG, XCTEST_LOG)
    check(
        "an XCTest failure is found (= not only the Swift Testing shape)",
        "ImportAgentRefusalLadderTests" in out,
        out[:300],
    )

    # 3. A tip that ADDS a failure exits 1.
    code, out = run_tool(SWIFT_TESTING_LOG, SWIFT_TESTING_LOG + "\n" + XCTEST_LOG)
    check("a tip that adds a failure exits 1", code == 1, f"exit={code}")
    check("the new failure is named", "ImportAgentRefusalLadderTests" in out, out[:300])

    # 4. A tip that adds NO failure exits 0.
    code, out = run_tool(SWIFT_TESTING_LOG, SWIFT_TESTING_LOG)
    check("a tip that adds no failure exits 0", code == 0, f"exit={code}")

    # 4b. A tip that LOSES a failure is not a regression (= the base's
    #     failures that the tip does not have are not the tip's fault).
    both = SWIFT_TESTING_LOG + "\n" + XCTEST_LOG
    code, out = run_tool(both, SWIFT_TESTING_LOG)
    check("a tip that loses a failure exits 0", code == 0, f"exit={code}")
    check(
        "the lost failure is reported as absent (= not as a regression)",
        "absent in the tip" in out,
        out[:400],
    )

    # 4c. An EQUAL count with a DIFFERENT set is still a new failure
    #     (= the verdict is the SET, = not the count: = a mutant that
    #     compares the counts stays GREEN on this case, = and it misses a
    #     genuinely new failure).
    code, out = run_tool(SWIFT_TESTING_LOG, XCTEST_LOG)
    check("an equal count with a different set exits 1", code == 1, f"exit={code}")
    check(
        "the different failure is named",
        "ImportAgentRefusalLadderTests" in out,
        out[:300],
    )

    # 4d. A tip that LOSES a failing SUITE (= the count path) exits 0
    #     (= the fallback's key must not carry the count: = a base at two
    #     failing suites and a tip at one would otherwise read as "the
    #     tip introduced one").
    two_suites = """Test run with 10 tests in 2 suites failed after 1.0 seconds with 2 issues.
\t Executed 4 tests, with 2 failures (0 unexpected) in 0.300 (0.301) seconds
"""
    one_suite = """Test run with 10 tests in 2 suites failed after 1.0 seconds with 1 issue.
\t Executed 4 tests, with 1 failure (0 unexpected) in 0.300 (0.301) seconds
"""
    code, out = run_tool(two_suites, one_suite)
    check("a tip that loses a failing suite exits 0", code == 0, f"exit={code}")

    # 5. ONE XCTest failure is counted ONCE (= the case line names it, =
    #    and the tally is the fallback, = so a double count miscounts).
    #    ⇒ AND THE ASSERTION IS THE SET'S CARDINALITY, = not the number
    #    of times a NAME appears: = the old assertion counted a name's
    #    occurrences, = so a phantom key (= which does not carry the name)
    #    slipped past it. = ⇒ MEASURED by the review: with the fixture
    #    changed to the real multi-level shape the suite stayed green
    #    while the tool reported TWO failures for ONE failing test.
    code, out = run_tool(XCTEST_LOG, XCTEST_LOG)
    body = out.split("=== tip:")[0]
    count = body.count("ImportAgentRefusalLadderTests")
    check("one XCTest failure is counted once", count == 1, f"counted {count} times")

    # 5b. The REAL shape: = ONE failing test tallied at THREE levels must
    #     read as ONE failure (= the tally lines are AGGREGATES, = not
    #     independent counts, = so summing them invents a second failure).
    code, out = run_tool(XCTEST_REAL_LOG, XCTEST_REAL_LOG)
    check(
        "one failing test on the real three-level shape reads as ONE failure",
        "1 failure(s)" in out and "unnamed failure" not in out,
        out[:400],
    )

    # 5c. The verdict does NOT move with the capture's tally LEVELS: =
    #     the same failing test, = once tallied at one level and once at
    #     three, = is the same failure set.
    one_level = """Test run with 2 tests in 1 suite failed after 0.055 seconds with 1 issue.
Test Case '-[XctlogTests.XctlogTests testFails]' failed (0.055 seconds).
\t Executed 2 tests, with 1 failure (0 unexpected) in 0.055 (0.055) seconds
"""
    code, out = run_tool(one_level, XCTEST_REAL_LOG)
    check(
        "the verdict does not move with the capture's tally levels",
        code == 0,
        f"exit={code}",
    )

    # 6. A non-zero tally with no case line is still reported.
    tally_only = """Test run with 10 tests in 2 suites failed after 1.0 seconds with 1 issue.
\t Executed 4 tests, with 2 failures (0 unexpected) in 0.300 (0.301) seconds
"""
    code, out = run_tool(tally_only, tally_only)
    check(
        "a non-zero XCTest tally with no case line is still reported",
        "tally" in out.lower(),
        out[:300],
    )

    # 7. TWO failing bundles (= the run has three `.xctest` bundles, = and
    #    they are SIBLING scopes). = A tip that FIXED one of them must
    #    NOT read as "the tip introduced a failure".
    #    ⇒ MEASURED by the review: with the count taken at ONE bundle's
    #    scope while the named cases were counted across ALL bundles, = the
    #    base's two bundles read as a tallied count of 1 against 1 named
    #    case, = and the tip's one bundle read as 1 against 0, = so the
    #    fallback APPEARED on the tip only and the gate said the tip
    #    introduced a failure it had FIXED.
    code, out = run_tool(XCTEST_TWO_BUNDLES, XCTEST_ONE_BUNDLE)
    check("a tip that fixed a failing bundle exits 0", code == 0, f"exit={code}")
    check(
        "the tip that fixed a bundle is not reported as adding one",
        "introduced 1 NEW failure" not in out,
        out[:400],
    )

    # 8. And the MIRROR: = a tip that ADDED a failing bundle must be
    #    reported (= the same scope mismatch read the other way and
    #    called the tip clean).
    code, out = run_tool(XCTEST_ONE_BUNDLE, XCTEST_TWO_BUNDLES)
    check("a tip that added a failing bundle exits 1", code == 1, f"exit={code}")
    check(
        "the added failure is reported",
        "introduced 1 NEW failure" in out,
        out[:400],
    )

    # 9. An unreadable log exits 2.
    proc = subprocess.run(
        [sys.executable, str(TOOL), "/nonexistent/base.log", "/nonexistent/tip.log"],
        capture_output=True,
        text=True,
    )
    check("an unreadable log exits 2", proc.returncode == 2, f"exit={proc.returncode}")

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s) failed: {', '.join(FAILURES)}")
        return 1
    print(f"swift_test_compare: all {PASSES} cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
