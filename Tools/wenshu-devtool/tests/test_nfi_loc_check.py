#!/usr/bin/env python3
"""
test_nfi_loc_check.py · Wenshu (文枢)

The LOC gate must be able to FAIL: = a row whose LOC cell carries
another file's count must turn it red, = and a right registry must
leave it green.

THE FIXTURE'S SHAPE MATTERS: = the gate measures the registry ROWS a
change ADDS, = so the fixture's second commit must add a row (= and a
row whose key the base does not carry). = Otherwise the gate has
nothing to measure, = and it reports "nothing to check" = which is a
pass for the wrong reason.

AND THE ROW THE CHANGE DID NOT ADD IS NOT THIS CHANGE'S BUSINESS: = the
registry's header says the LOC column is the count at the moment the
row was written, = so a row that was written earlier may carry a stale
count BY DESIGN. = The fixture proves that too: = a row that carries a
stale count and that the change did not add leaves the gate GREEN.
"""

import os
import subprocess
import sys
import tempfile

# = The tool lives beside this test, = so its path is the test's own
# directory's parent.
TOOL = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "nfi-loc-check.py")


def run(args, cwd):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True)


def write_registry(path, rows):
    """The registry's rows, = each as (key, file, loc)."""
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("| key | file | LOC | note |\n|---|---|---|---|\n")
        for key, name, loc in rows:
            handle.write(f"| `{key}` | `{name}` | {loc} | ours |\n")


def main():
    with tempfile.TemporaryDirectory() as tmp:
        run(["git", "init", "-q", tmp], cwd=tmp)
        run(["git", "config", "user.email", "t@t"], cwd=tmp)
        run(["git", "config", "user.name", "t"], cwd=tmp)
        os.makedirs(os.path.join(tmp, "Sources"), exist_ok=True)
        os.makedirs(os.path.join(tmp, "docs", "agents"), exist_ok=True)
        ours = os.path.join(tmp, "Sources", "Ours.swift")
        theirs = os.path.join(tmp, "Sources", "Theirs.swift")
        registry = os.path.join(tmp, "docs", "agents", "nfi.md")

        # = the base: = two files, = and one row (theirs, = carrying a
        # count that is already stale = = the tree's own drift, = which
        # the registry's header says is expected).
        with open(ours, "w", encoding="utf-8") as handle:
            handle.write("let a = 1\nlet b = 2\n")
        with open(theirs, "w", encoding="utf-8") as handle:
            handle.write("let x = 1\n")
        write_registry(registry, [("Sources/Theirs.swift", "Sources/Theirs.swift", 99)])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "base"], cwd=tmp)

        # = the change: = a row for a NEW file, = and the file itself.
        with open(ours, "w", encoding="utf-8") as handle:
            handle.write("let a = 1\nlet b = 2\nlet c = 3\n")
        write_registry(
            registry,
            [
                ("Sources/Theirs.swift", "Sources/Theirs.swift", 99),
                ("Sources/Ours.swift", "Sources/Ours.swift", 3),
            ],
        )
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "the row is added"], cwd=tmp)

        # = the GREEN case: = the added row carries the file's own count.
        result = run([sys.executable, TOOL, "--base", "HEAD~1", "--registry", registry], cwd=tmp)
        if result.returncode != 0:
            print("FAILED: a right registry turned the gate red")
            print(result.stdout)
            print(result.stderr)
            return 1
        if "nothing to check" in result.stdout:
            print("FAILED: the gate measured nothing (= the fixture adds no row)")
            return 1

        # = the GREEN case the review named: = the row the change did
        # = NOT add carries a stale count, = and the gate must not care.
        # = (The base's row says 99, = and the file is one line.)
        stale = run([sys.executable, TOOL, "--base", "HEAD~1", "--registry", registry], cwd=tmp)
        if "Theirs.swift" in stale.stdout and "the row says 99" in stale.stdout:
            print("FAILED: the gate charged a row the change did not add")
            print(stale.stdout)
            return 1

        # = the RED case: = the ADDED row carries another file's count.
        write_registry(
            registry,
            [
                ("Sources/Theirs.swift", "Sources/Theirs.swift", 99),
                ("Sources/Ours.swift", "Sources/Ours.swift", 522),
            ],
        )
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "wrong loc"], cwd=tmp)
        result = run([sys.executable, TOOL, "--base", "HEAD~2", "--registry", registry], cwd=tmp)
        if result.returncode == 0:
            print("FAILED: a wrong LOC cell left the gate green")
            print(result.stdout)
            print(result.stderr)
            return 1

    print("test_nfi_loc_check: the gate fails on a wrong LOC cell, = and passes on a right one")
    return 0


if __name__ == "__main__":
    sys.exit(main())
