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
    code, out = run_tool(XCTEST_LOG, XCTEST_LOG)
    body = out.split("=== tip:")[0]
    count = body.count("ImportAgentRefusalLadderTests")
    check("one XCTest failure is counted once", count == 1, f"counted {count} times")

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

    # 7. An unreadable log exits 2.
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
