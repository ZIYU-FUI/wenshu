#!/usr/bin/env python3
"""Compare two `swift test` logs for the failure set, in BOTH shapes.

Why this exists: a `swift test` log carries TWO per-target summary shapes,
and a comparison that reads only one of them silently misses half the
failures.

  - Swift Testing prints `Test run with N tests in M suites passed/failed`
    and, for a failed expectation, `... recorded an issue at FILE:LINE:COL`.
  - The XCTest bundles print NO `Test run with` line at all. They report
    through `Test Case '-[Suite testName]' failed` and
    `Executed N tests, with M failures`.

So a comparison that greps only `recorded an issue at` sees the Swift
Testing failures and NONE of the XCTest ones. Measured 2026-11-03 on the
repository's own logs: /tmp/base_full.log held a real XCTest failure
(`WenshuAppTests.ImportAgentRefusalLadderTests`) that no `Test run with`
line mentions.

Usage:
    swift_test_compare.py BASE_LOG TIP_LOG [--base-label L] [--tip-label L]

Exit status:
    0  the tip introduced NO new failure (the tip's set is a subset of the
       base's, counting both shapes)
    1  the tip introduced at least one NEW failure (the list goes to stdout)
    2  a log could not be read

The verdict is about the SET, never about the count: a count moves with the
machine's load, because two suites that measure a time budget fail under
parallel load and pass alone.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Swift Testing: a failed expectation names the file and the position.
_SWIFT_ISSUE = re.compile(r"recorded an issue at\s+([^\s:]+):(\d+):(\d+)")

# XCTest: a failed test case names the suite and the test.
_XCTEST_CASE = re.compile(r"^Test Case '-\[([^\s]+)\s+([^\]]+)\]' failed", re.MULTILINE)

# XCTest: the per-suite tally, which is the only place an XCTest failure
# count appears.
#
# The optional "N tests skipped and" clause is the shape the repository's
# own logs use (= "Executed 10 tests, with 1 test skipped and 0
# failures"), = and a regex that requires the failure count immediately
# after "with " matches NONE of those lines. = ⇒ A suite that both
# SKIPS a test and FAILS another was read as clean.
_XCTEST_TALLY = re.compile(
    r"Executed\s+(\d+)\s+tests?, with\s+(?:\d+\s+tests?\s+skipped\s+and\s+)?(\d+)\s+failures?",
    re.MULTILINE,
)


def _swift_failures(text: str) -> set[str]:
    """The Swift Testing failures, keyed by file:line:column."""
    return {f"{m.group(1)}:{m.group(2)}:{m.group(3)}" for m in _SWIFT_ISSUE.finditer(text)}


def _xctest_failures(text: str) -> set[str]:
    """The XCTest failures.

    Two sources, because they disagree: a failed test case names the
    suite and the test (= the precise site), = while the tally only
    gives a count (= which suite failed, = and only if the count is
    non-zero). The precise sites are what a reader needs, = so the
    tally is used to DETECT that a suite failed and the case lines to
    NAME it, = and a failure the tally sees and no case line names is
    reported by its own key (= so it is never silently dropped).

    ⇒ ⇒ AND THAT KEY MUST NOT CARRY A COUNT. = The verdict is the SET
    (= never the count: = a count moves with the machine's load), = so a
    key that embeds the count makes two logs with DIFFERENT counts
    produce different keys, = and a tip that LOSES a failing suite then
    reads as a tip that ADDED one. = ⇒ MEASURED: the base at two
    failing suites and the tip at one read as "the tip introduced 1 NEW
    failure", = which is the exact failure mode this tool exists to
    avoid.
    """
    cases = {f"XCTest {suite}.{test}" for suite, test in _XCTEST_CASE.findall(text)}
    failures = set(cases)

    # The tally's failures that no case line named: = those are the
    # unnamed ones, = and they are reported with a COUNT-FREE key (= so
    # the key is the same whatever the count is).
    tallied_failures = sum(int(failed) for _, failed in _XCTEST_TALLY.findall(text))
    if tallied_failures > len(cases):
        failures.add("XCTest tally: an unnamed failure (no case line parsed)")

    return failures


def read(path: str) -> str:
    p = Path(path)
    if not p.is_file():
        print(f"cannot read {path}", file=sys.stderr)
        sys.exit(2)
    return p.read_text(encoding="utf-8", errors="replace")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("base_log")
    ap.add_argument("tip_log")
    ap.add_argument("--base-label", default="base")
    ap.add_argument("--tip-label", default="tip")
    args = ap.parse_args()

    base_text = read(args.base_log)
    tip_text = read(args.tip_log)

    base = _swift_failures(base_text) | _xctest_failures(base_text)
    tip = _swift_failures(tip_text) | _xctest_failures(tip_text)

    new = sorted(tip - base)
    gone = sorted(base - tip)

    print(f"=== {args.base_label}: {len(base)} failure(s) ===")
    for f in sorted(base):
        print(f"  {f}")
    print(f"=== {args.tip_label}: {len(tip)} failure(s) ===")
    for f in sorted(tip):
        print(f"  {f}")

    if new:
        print(f"\nVERDICT: the {args.tip_label} introduced {len(new)} NEW failure(s):")
        for f in new:
            print(f"  + {f}")
        return 1

    print(f"\nVERDICT: the {args.tip_label} introduced NO new failure.")
    if gone:
        print(f"  ({len(gone)} failure(s) present in the {args.base_label} and absent in the {args.tip_label}:")
        for f in gone:
            print(f"  - {f}")
        print("   = = the two shapes of that difference are a load-sensitive suite that red under")
        print("   = = parallel load and green alone, = or a fix. = The SET is the verdict, = not the count.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
