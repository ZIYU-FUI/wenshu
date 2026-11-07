#!/usr/bin/env python3
"""
pre_review_gate.py · Wenshu (文枢)

The gate that runs BEFORE a branch goes back to the review lane.

WHY THIS EXISTS

Six review rounds on one branch found, in order: = a tree that did not
compile, = a formatting gate that exited 1, = a registry row carrying
another file's count, = a heading face that never reached the editor, =
an assertion written about a range the author had never looked at, =
and a card whose GATES did not run the engine's own suite. = Every one
of those was a claim made from REASONING and not from a measurement.

So the rule this tool enforces is simple: = a branch goes back to
review only when every gate has been MEASURED ON THE EXACT TREE THAT
WILL BE REVIEWED, = and the tool says so in its output.

THE THREE RULES IT ENFORCES

1. = THE TREE MUST BE COMMITTED. = A gate reads HEAD, = so a gate run
   against a dirty worktree measures the wrong tree, = and the amend
   that follows it moves HEAD again. = So the tool refuses a dirty
   tree BEFORE it measures anything.
2. = THE BUILD MUST BUILD THE TESTS. = `swift build` does not build
   the test target, = so a green build says nothing about a broken
   test file. = `swift build --build-tests` is the check that covers
   it.
3. = EVERY GATE THE CARD NAMES MUST RUN, = and every tree the change
   touches must have its own suite. = The vendored engine has its own
   suite, = and a change that touches the vendored tree runs it.

USAGE

    python3 Tools/wenshu-devtool/pre_review_gate.py --base <sha> \\
        --filter '<the card's own suite>' [--filter '<another>'] \\
        [--card <the card body file>]

EXIT

    0 = every gate measured and green
    1 = a gate failed, = or the tree is dirty, = or a gate could not run
"""

import argparse
import os
import re
import subprocess
import sys

REPO = os.getcwd()
DEVTOOL = os.path.join(REPO, "Tools", "wenshu-devtool")


def sh(command, cwd=REPO, timeout=3600):
    """Run a command, = and return (exit code, output)."""
    try:
        done = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return 124, f"TIMEOUT: {command}"
    return done.returncode, (done.stdout + done.stderr)


def cjk_audit(base):
    """§7.5: zero new CJK in the COMMENTS this change adds."""
    diff = sh(f"git diff {base} HEAD -- '*.swift'")[1]
    added = [line[1:] for line in diff.split("\n") if line.startswith("+") and not line.startswith("+++")]
    is_comment = lambda line: line.strip().startswith("//") or line.strip().startswith("*")
    cjk = re.compile(r"[一-鿿]")
    comments = [line for line in added if is_comment(line) and cjk.search(line)]
    if comments:
        return 1, "CJK comment lines added:\n" + "\n".join("  " + line[:110] for line in comments)
    return 0, f"no new CJK comment line ({len(added)} added line(s) scanned)"


def card_gates(card_path):
    """The card's own narrow suites, = read from its GATES section."""
    if not card_path:
        return []
    text = open(card_path, encoding="utf-8").read()
    return re.findall(r"swift test --filter '([^']+)'", text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--filter", action="append", default=[])
    parser.add_argument("--card", default=None)
    args = parser.parse_args()

    failures = []

    # RULE 1: the tree must be committed.
    dirty = sh("git status --porcelain")[1].strip()
    if dirty:
        print("pre_review_gate: FAILED")
        print("  the worktree is dirty, = so a gate would measure the WRONG tree:")
        for line in dirty.split("\n")[:10]:
            print("    " + line)
        print("  commit first, = then measure.")
        return 1

    print(f"pre_review_gate: the tree is clean at {sh('git rev-parse --short HEAD')[1].strip()}")

    # RULE 2: the build must build the tests.
    code, out = sh("swift build --build-tests")
    print(f"  build --build-tests: exit {code}")
    if code != 0:
        failures.append(("swift build --build-tests", out[-800:]))

    # The card's own narrow suites, = and the ones named on the command line.
    filters = list(dict.fromkeys(args.filter + card_gates(args.card)))
    for name in filters:
        code, out = sh(f"swift test --filter '{name}'")
        summary = [line for line in out.split("\n") if "Test run with" in line or "Executed" in line]
        print(f"  swift test --filter '{name}': exit {code} {summary[-1].strip() if summary else ''}")
        if code != 0:
            failures.append((f"swift test --filter '{name}'", out[-800:]))

    # RULE 3: the vendored engine has its own suite, = and a change that
    # touches the vendored tree runs it.
    vendored = sh("git diff --name-only %s HEAD -- 'Vendor/MarkdownEngine/*'" % args.base)[1].split()
    if vendored:
        code, out = sh("swift test", cwd=os.path.join(REPO, "Vendor", "MarkdownEngine"))
        summary = [line for line in out.split("\n") if "Test run with" in line]
        print(f"  the vendored engine's own suite: exit {code} {summary[-1].strip() if summary else ''}")
        if code != 0:
            failures.append(("the vendored engine's suite", out[-800:]))

    # The house's own gates.
    for check in ("formatting", "pollution"):
        code, out = sh(f"python3 {DEVTOOL}/ci_change_gate.py --base {args.base} --check {check}")
        print(f"  ci_change_gate --check {check}: exit {code}")
        if code != 0:
            failures.append((f"ci_change_gate --check {check}", out[-800:]))

    code, out = cjk_audit(args.base)
    print(f"  the CJK audit: exit {code} ({out.splitlines()[0] if out else ''})")
    if code != 0:
        failures.append(("the CJK audit", out))

    code, out = sh(f"python3 {DEVTOOL}/verify-dead.py")
    dead = [line for line in out.split("\n") if "DEAD" in line]
    print(f"  verify-dead: exit {code} {dead[-1].strip() if dead else ''}")
    if code != 0:
        failures.append(("verify-dead", out[-800:]))

    code, out = sh(f"python3 {os.path.join(REPO, 'Scripts', 'merge-nfi-registry.py')} {args.base} docs/agents/nfi.md docs/agents/nfi.md")
    print(f"  the registry's round-trip: exit {code}")
    if code != 0:
        failures.append(("the registry's round-trip", out[-800:]))

    if failures:
        print("pre_review_gate: FAILED")
        for name, detail in failures:
            print(f"  --- {name}")
            for line in detail.split("\n")[-12:]:
                print("    " + line)
        return 1

    print("pre_review_gate: every gate was measured on this tree and is green")
    return 0


if __name__ == "__main__":
    sys.exit(main())
