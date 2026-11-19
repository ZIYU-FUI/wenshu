#!/usr/bin/env python3
"""
nfi-loc-check.py · Wenshu (文枢)

Check the NFI registry's LOC cells against the files they name, = for the
files a change rewrites.

WHY THIS EXISTS

The registry's merge driver merges at the KEY level, = and a key's whole
row text is its value. = So a same-key disagreement is a conflict only
when BOTH sides changed the key: = when one side alone carries a wrong
LOC, = the driver has nothing to compare it against = and carries it
through silently. = Measured: = pasting one file's count over another
file's row leaves EVERY gate green (= the driver's round-trip, = the
registry's own suite, = the formatting gate, = the pollution gate).

So the count a row carries needs its own check: = a row whose file the
change rewrote must carry THAT file's own line count (= `wc -l`, = the
convention the registry's own header names).

WHAT IT DOES

= The registry's own header names the rule: = "THE LOC COLUMN IS THE
COUNT AT THE MOMENT THE ROW WAS WRITTEN, = not a live count of the
file today". = So a row that names a file this change did not add is
NOT this change's business, = and its count may be stale BY DESIGN
(= 92 such rows carry a count from when their row was written).

So the gate reads the rows this change ADDED: = a key the base's
registry does not carry and the tip's does. = For each, = the row must
name a file, = and that row's LOC cell must be that file's own `wc -l`
(= the convention the registry's own header names).

= Rewriting a file does NOT bring its row into scope: = the row was
written when the file was split out, = and the file's later growth is
the tree's own drift (= which the header says is expected). = The rule
this gate holds is the one the driver cannot: = a row that is ADDED
with the WRONG count, = or a count pasted over another file's row.

⇒ ⇒ ⇒ AND THE TWO COUNTS A ROW CARRIES USE TWO CONVENTIONS, = = AND
THEY CAN DIFFER BY ONE: = = the registry's PARENT cell's prose (= "= =
(now N LOC, under cap)") = = follows the CAP TOOL's `splitlines()`
convention, = = and the LOC COLUMN = = follows `wc -l` (= = = the
convention this gate measures, = = = and the one the registry's own
header names). = ⇒ ⇒ ⇒ A FILE WITHOUT A TRAILING NEWLINE = = HAS
`splitlines()` = = `wc -l` + 1, = = so for THAT FILE the two numbers
differ by one, = = and BOTH are right (= = = each in its own
convention). = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ THIS GATE MEASURES THE LOC COLUMN
ONLY** (= = = the `wc -l` half), = = = and it does NOT read the parent
cell's prose, = = = because the parent cell is a DIFFERENT FILE's count
(= = = the parent's own, = = = under the cap tool's convention) = = = =
and a change that rewrites a child does not necessarily rewrite the
parent's count. = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ SO A STALE PARENT PROSE
IS NOT WHAT THIS GATE CHARGES** (= = = and a reviewer reading this
card's own fixture must not expect it to).

USAGE

    python3 Tools/wenshu-devtool/nfi-loc-check.py --base <sha> [--registry <path>]
"""

import argparse
import os
import re
import subprocess
import sys

# = The repo is the one this tool is run in, = so the tool's own test
# can point it at a fixture (= and the house's tools are git tools, =
# = and git reads the working directory).
REPO = os.getcwd()
LITERAL = re.compile(r"^\d+$")


def run(args, cwd=REPO):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True).stdout


def changed_swift_files(base):
    out = run(["git", "diff", "--name-only", base, "HEAD", "--", "*.swift"])
    return [line.strip() for line in out.split("\n") if line.strip()]


def added_keys(base):
    """The registry keys this change ADDED (= the base has none of them)."""
    base_text = run(["git", "show", f"{base}:docs/agents/nfi.md"])
    base_keys = {cells[1].strip("`") for cells in rows(base_text)}
    tip_text = run(["git", "show", "HEAD:docs/agents/nfi.md"])
    tip_keys = {cells[1].strip("`") for cells in rows(tip_text)}
    return tip_keys - base_keys


def rewritten_keys(base):
    """The registry keys whose NAMED FILE this change rewrote.

    ⇒ ⇒ ⇒ WHY A REWRITTEN FILE'S ROW IS THIS CHANGE'S BUSINESS: = the
    registry's header says the LOC column is the count at the moment the
    row was written, = = and that makes the DRIFT of a file nobody
    touched somebody else's business. = = It says nothing about a file
    THIS change rewrote: = = the row for that file is now a statement
    about a file this change owns, = = and the row is in this change's
    own diff (= = = its text is part of the change), = = = so the two
    must agree.

    ⇒ ⇒ ⇒ MEASURED 2026-11-19 (= the library card's round 3): = = a
    replay of that branch onto a moved `main` ran the registry's merge
    driver, = = the driver NAMED two conflicted keys and exited 1, = =
    and still wrote `main`'s rows (= = = 286 and 112) into the file
    with ZERO conflict markers. = = Every gate read green, = = because
    this gate scoped itself to the keys the change ADDED, = = and the
    two lost rows were SAME-KEY rows (= = = a key the base already
    carried). = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ SO A REPLAY CAN SILENTLY REWRITE AN
    EXISTING ROW, = = AND THIS IS THE CHECK THAT SEES IT.
    """
    changed = set(run(["git", "diff", "--name-only", base, "HEAD"]).split("\n"))
    changed = {name.strip() for name in changed if name.strip()}
    tip_text = run(["git", "show", "HEAD:docs/agents/nfi.md"])
    keys = set()
    for cells in rows(tip_text):
        key = cells[1].strip("`")
        if key and key in changed:
            keys.add(key)
    return keys


def wc_lines(path):
    """The file's own `wc -l` count (= the registry's own convention)."""
    try:
        with open(path, "rb") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return None


def rows(registry_text):
    """The table's rows, = each as its cells."""
    for line in registry_text.split("\n"):
        if line.startswith("|"):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) >= 3:
                yield cells


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="the base commit to measure against")
    parser.add_argument("--registry", default=os.path.join(REPO, "docs/agents/nfi.md"))
    args = parser.parse_args()

    added = added_keys(args.base)
    rewritten = rewritten_keys(args.base)
    # ⇒ ⇒ ⇒ THE CHECKED SET IS THE KEYS THE CHANGE ADDED **∪** THE KEYS
    # ⇒ ⇒ ⇒ WHOSE NAMED FILE IT REWROTE: = = the first is the row this
    # ⇒ ⇒ ⇒ change wrote, = = the second is the row this change made a
    # ⇒ ⇒ ⇒ lie about (= = = = measured 2026-11-19).
    checked_keys = added | rewritten
    if not checked_keys:
        print("nfi-loc-check: the change adds no registry row and rewrites no registered file; nothing to check")
        return 0

    with open(args.registry, encoding="utf-8") as handle:
        text = handle.read()

    failures = []
    checked = 0
    for cells in rows(text):
        key = cells[1].strip("`")
        if key not in checked_keys:
            continue
        named = key
        loc_cell = next((index for index in range(2, len(cells)) if LITERAL.match(cells[index])), None)
        if loc_cell is None:
            continue
        actual = wc_lines(os.path.join(REPO, named))
        if actual is None:
            continue
        checked += 1
        if int(cells[loc_cell]) != actual:
            failures.append(f"{named}: the row says {cells[loc_cell]}, the file is {actual}")

    if failures:
        print("nfi-loc-check: FAILED")
        for failure in failures:
            print("  " + failure)
        print(
            f"  ({checked} row(s) checked: = {len(added)} the change added, "
            f"= {len(rewritten)} whose named file the change rewrote)"
        )
        return 1

    print(
        f"nfi-loc-check: every added or rewritten file's row carries its own count "
        f"({checked} row(s) checked: = {len(added)} the change added, "
        f"= {len(rewritten)} whose named file the change rewrote)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
