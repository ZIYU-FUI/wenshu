#!/usr/bin/env python3
"""
mutation_check.py - prove that a test suite actually BITES.

WHY THIS TOOL EXISTS
  A regression test that asserts on its OWN arithmetic instead of on the
  code's output is a guard that cannot fail, and the board's review lane
  found exactly that, three rounds in (2026-11-03): a case that was meant to
  guard a headline fix re-implemented the headline's formula inside the test
  and asserted on that, so reverting the guarded code left the suite green
  while the tool still printed the defective string.

  The acceptance criterion is not "the suite passes". It is:
      revert the guarded code  ->  the suite goes RED
      leave the code alone     ->  the suite stays GREEN
  A suite that passes in both states is decoration.

WHAT IT DOES
  It takes a mutation (= a find-and-replace in the guarded file) and runs
  the suite against a COPY of the tree with the mutation applied, in a fresh
  temporary directory, with a fresh subprocess (= no bytecode cache, and the
  real worktree is never edited). Then it reports whether the suite bit.

  The suite and the guarded file are named on the command line, so the tool
  is not tied to one project's tests.

Usage:
    python3 mutation_check.py --suite <test file> --guard <file under test> \\
        --mutate "<old text>" --replace "<new text>"

    # a control run (= no mutation) to prove the suite is green to begin with
    python3 mutation_check.py --suite <test file> --control

Exit code: 0 = the suite bit (it went red under the mutation and was green
without it), 1 = the suite did not bite (= the mutation left it green, so
the guard is empty), 2 = the suite was already red (= no verdict).
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run_suite(
    suite: Path, guard: Path, mutate: str | None, replace: str | None
) -> tuple[int, str]:
    """Run the suite against a copy of the tree, with the mutation applied.

    Returns (exit code, the suite's tail). The real tree is never touched:
    the copy lives in a temporary directory that is removed afterwards.
    """
    root = suite.resolve().parent.parent  # the package dir holding the suite
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / root.name
        shutil.copytree(root, work)
        try:
            target = work / guard.resolve().relative_to(root)
        except ValueError:
            return -1, (
                f"the guarded file is outside the suite's package directory "
                f"({guard} is not under {root}) = this tool copies that "
                f"directory, so it cannot mutate a file elsewhere"
            )
        if mutate is not None and replace is not None:
            text = target.read_text()
            if mutate not in text:
                return -1, f"THE MUTATION TEXT IS NOT IN {guard.name}"
            target.write_text(text.replace(mutate, replace))
        r = subprocess.run(
            [sys.executable, str(work / suite.resolve().relative_to(root))],
            capture_output=True,
            text=True,
        )
        tail = "\n".join(r.stdout.strip().splitlines()[-12:])
        return r.returncode, tail


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--suite", required=True, help="the test file to run")
    ap.add_argument("--guard", required=True, help="the file the suite guards")
    ap.add_argument("--mutate", default=None, help="the text to replace")
    ap.add_argument("--replace", default=None, help="the replacement text")
    ap.add_argument("--control", action="store_true", help="run without mutating")
    args = ap.parse_args()

    suite = Path(args.suite).resolve()
    guard = Path(args.guard).resolve()
    if not suite.exists():
        print(f"the suite does not exist: {suite}", file=sys.stderr)
        return 2
    if not guard.exists():
        print(f"the guarded file does not exist: {guard}", file=sys.stderr)
        return 2

    # The control: the suite must be green BEFORE the mutation.
    print("=== the control (no mutation) ===")
    rc, tail = run_suite(suite, guard, None, None)
    print(tail)
    if rc != 0:
        print(f"\nthe suite is already RED (rc={rc}) = no verdict", file=sys.stderr)
        return 2
    print(f"the suite is GREEN without the mutation (rc={rc})\n")

    if args.control:
        print("CONTROL ONLY: the suite is green, so it CAN bite.")
        print("(run it again with --mutate/--replace to see whether it does)")
        # A DIFFERENT exit code from "the suite bit": the control proves
        # the suite is green, and nothing more. A caller that gates on the
        # exit code must not read it as a proven bite.
        return 3

    if args.mutate is None or args.replace is None:
        print("--mutate and --replace go together", file=sys.stderr)
        return 2

    # The mutation: the suite must go RED.
    print("=== under the mutation ===")
    rc, tail = run_suite(suite, guard, args.mutate, args.replace)
    if rc == -1:
        print(tail, file=sys.stderr)
        return 2
    print(tail)
    print()
    if rc == 0:
        print(
            "THE SUITE DID NOT BITE: it stayed green with the guarded code "
            "reverted.\nThis guard cannot fail. Assert on the OUTPUT of the "
            "code, not on a formula re-implemented inside the test."
        )
        return 1
    print(f"THE SUITE BIT: it went RED (rc={rc}) with the guarded code reverted.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
