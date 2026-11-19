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

⇒ ⇒ ⇒ AND THE ROW THE CHANGE REWROTE IS THIS CHANGE'S BUSINESS: = the
header's rule (= the count is the count at the moment the row was
written) = = says the DRIFT of a file nobody touched is not this
change's business, = = and it says NOTHING about a file this change
REWROTE: = = the row for that file is now a lie about a file this
change owns, = = and the row is in this change's diff (= = = the row's
text changed, = = = the row's file changed, = = = = and the two must
agree). = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ MEASURED 2026-11-19 (= the library card's round
3): = = a replay of that branch onto a moved `main` ran the registry's
merge driver, = = the driver named two conflicted keys and exited 1,
= = and still wrote `main`'s rows (= = = 286 and 112) into the file
with ZERO conflict markers. = = Every gate read green, = = because
`nfi-loc-check.py` scoped itself to the keys the change ADDED (= = =
and the two lost rows were same-key rows), = = = = and no other gate
reads a registry row's truth. = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ SO THE FIXTURE
BELOW REPRODUCES THAT EXACTLY, = = AND IT IS RED BEFORE THE CHECKER
EXISTS.
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


def rewritten_row_case():
    """R8 EXACTLY: = a branch REWRITES a file whose registry row exists, = = and the
    row's LOC cell does not follow the file's own count. = The gate must be RED.

    THE SHAPE (= = = and this is the shape the merge driver's silent take-ours
    produces): = = the BASE carries the row with the file's own count, = = the
    change REWRITES the file (= = = its lines change), = = and the row in the
    change's own tree still carries the base's count (= = = which is what a
    replay's silent resolution leaves behind). = = The change does NOT add any
    row, = = so the ADDED-only scope has nothing to measure, = = and the gate
    reports "nothing to check" (= = = = which reads as a pass).
    """
    with tempfile.TemporaryDirectory() as tmp:
        run(["git", "init", "-q", tmp], cwd=tmp)
        run(["git", "config", "user.email", "t@t"], cwd=tmp)
        run(["git", "config", "user.name", "t"], cwd=tmp)
        os.makedirs(os.path.join(tmp, "Sources"), exist_ok=True)
        os.makedirs(os.path.join(tmp, "docs", "agents"), exist_ok=True)
        source = os.path.join(tmp, "Sources", "Rewritten.swift")
        registry = os.path.join(tmp, "docs", "agents", "nfi.md")

        # = the base: = the file carries three lines, = and the row says 3.
        with open(source, "w", encoding="utf-8") as handle:
            handle.write("let a = 1\nlet b = 2\nlet c = 3\n")
        write_registry(registry, [("Sources/Rewritten.swift", "Sources/Rewritten.swift", 3)])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "base"], cwd=tmp)

        # = the change: = the file is REWRITTEN (= five lines now), = = and the
        # = row still says 3 (= = = the count the base wrote, = = = = = which is
        # = = = now a lie about a file this change owns).
        with open(source, "w", encoding="utf-8") as handle:
            handle.write("let a = 1\nlet b = 2\nlet c = 3\nlet d = 4\nlet e = 5\n")
        write_registry(registry, [("Sources/Rewritten.swift", "Sources/Rewritten.swift", 3)])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "the file is rewritten, the row is not"], cwd=tmp)

        result = run([sys.executable, TOOL, "--base", "HEAD~1", "--registry", registry], cwd=tmp)

        # = the GREEN half: = THE SAME CHANGE (= = = the file is rewritten
        # = = = again, = = = so the gate's scope still carries it), = = with the
        # = = = row corrected to the file's own count. = The gate must pass, = =
        # = = = and it must have MEASURED something (= = = "nothing to check" is
        # = = = = a pass for the wrong reason).
        # ⇒ ⇒ ⇒ AND THE FILE IS REWRITTEN AGAIN ON PURPOSE: = = = a green
        # ⇒ ⇒ ⇒ half that changed only the registry would leave the source file
        # ⇒ ⇒ ⇒ OUT of the change's diff, = = = and the gate would have nothing
        # ⇒ ⇒ ⇒ to measure (= = = = which is the scope, = = = = not a pass).
        with open(source, "w", encoding="utf-8") as handle:
            handle.write("let a = 1\nlet b = 2\nlet c = 3\nlet d = 4\nlet e = 5\nlet f = 6\n")
        write_registry(registry, [("Sources/Rewritten.swift", "Sources/Rewritten.swift", 6)])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "the row is corrected"], cwd=tmp)
        green = run([sys.executable, TOOL, "--base", "HEAD~1", "--registry", registry], cwd=tmp)

        # = THE RED CASE: = the stale row, = and the gate must be red on it.
        if result.returncode == 0:
            print("FAILED: a REWRITTEN file's stale registry row left the gate green")
            print("  (= = the R8 shape: = the gate says nothing, = and the row lies)")
            print(result.stdout)
            print(result.stderr)
            return 1
        if "Rewritten.swift" not in result.stdout:
            print("FAILED: the gate went red without naming the stale row")
            print(result.stdout)
            return 1

        # = and the GREEN half: = the same change with the row corrected.
        if green.returncode != 0:
            print("FAILED: a right registry turned the gate red on a rewritten file")
            print(green.stdout)
            print(green.stderr)
            return 1
        if "nothing to check" in green.stdout:
            print("FAILED: the gate measured nothing (= = the added-only scope, = = = = which is the defect)")
            print(green.stdout)
            return 1

    return 0


if __name__ == "__main__":
    code = main()
    if code == 0:
        code = rewritten_row_case()
    sys.exit(code)
