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

So the gate reads the rows this change ADDED **union** the rows whose
NAMED FILE this change REWROTE: = the added half is a key the base's
registry does not carry and the tip's does; = the rewritten half is a
key whose file the change rewrote. = For each, = the row must name a
file, = and that row's LOC cell must be that file's own `wc -l`
(= the convention the registry's own header names).

= The REWRITTEN half is NOT optional, = and the header already says
so: = "a row for a file this change ADDED is written with that file's
count, = and the row is CORRECTED if the same change REWRITES the
file". = So a change that rewrites a registered file must rewrite that
row too, = even when the change adds no registry row at all.

= MEASURED 2026-11-19 (= the library card's round 3): = a replay of
that branch onto a moved `main` ran the registry's merge driver, = the
driver NAMED two conflicted keys and exited 1, = and still wrote
`main`'s rows into the file with ZERO conflict markers. = Every gate
read green, = because the two lost rows were SAME-KEY rows and this
gate scoped itself to the ADDED half alone.

= A row this change touched NEITHER half of is NOT this change's
business: = the row was written when the file was split out, = and
the file's later growth is the tree's own drift (= which the header
says is expected). = The rule this gate holds is the one the driver
cannot: = a row that is ADDED with the WRONG count, = or a count
pasted over another file's row, = or a row this change made a lie by
rewriting the file it names.

⇒ ⇒ ⇒ AND THE TWO COUNTS A ROW CARRIES USE TWO CONVENTIONS, = = AND
THEY CAN DIFFER BY ONE: = = the registry's PARENT cell's prose (= "= =
(now N LOC, under cap)") = = follows the CAP TOOL's `splitlines()`
convention, = = and the LOC COLUMN = = follows `wc -l` (= = = the
convention this gate measures, = = = and the one the registry's own
header names). = ⇒ ⇒ ⇒ A FILE WITHOUT A TRAILING NEWLINE = = HAS
`splitlines()` = = `wc -l` + 1, = = so for a file that ends WITHOUT a
trailing newline the two numbers differ by one, = = and BOTH are right
(= = = each in its own convention). = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ THIS GATE MEASURES THE LOC COLUMN
ONLY** (= = = the `wc -l` half), = = = and it does NOT read the parent
cell's prose, = = = because the parent cell is a DIFFERENT FILE's count
(= = = the parent's own, = = = under the cap tool's convention) = = = =
and a change that rewrites a child does not necessarily rewrite the
parent's count. = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ SO A STALE PARENT PROSE
IS NOT WHAT THIS GATE CHARGES** (= = = and a reviewer reading this
card's own fixture must not expect it to).

WHAT A ROW THE GATE CANNOT OPEN DOES
====================================
⇒ ⇒ ⇒ THE TWO SHAPES THAT ARE NOT ABSENT FILES, = = AND THE ONE
RESULT THEY USED TO SHARE: = = a key can be a real PATH that names a
DIRECTORY (= `Vendor/MarkdownEngine/`), = = or a cell that is not a
path at all (= = the bare number `262`, = = = = which is the count of a
closeout document pasted into the FILE column, = = measured at
`899cb3a1ee`, = = = card `t_70592b92`). = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ BOTH return
`None` from `wc_lines`, = = and until card `t_70592b92` BOTH hit the
same silent `continue`, = = so the gate's own output could not tell an
absent file from a directory key from a mis-pasted count, = = = and the
three shapes need three different repairs.
⇒ ⇒ ⇒ **⇒ A ROW'S LOC CELL IS THEREFORE NOT EVIDENCE THAT ANYTHING WAS
MEASURED.** = The gate now prints each added or rewritten row whose key
opens nowhere, = with `absent` / `not-a-file` / `not-a-path` on the
line, = = and fails the run (= exit 1) on it, = = because a report the
exit code ignores is still read as clean.
⇒ ⇒ ⇒ AND THE CENSUS, = = so the split cannot be read as "all rows
measured": = = measured with this file's own `rows()` / `LITERAL` /
`wc_lines` over the live registry at `b96d3f7cb5` (= = the tip this
change rebases onto), = = 461 rows carry a literal LOC cell, = = of
which 423 open a readable file, = = 33 are the table's own `...`
shorthand (= = = `rows()` skips them, = = = not a defect), = = and 5
open nothing (= = = 3 absent files, = = 1 DIRECTORY, = = 1 bare
NUMBER). = ⇒ ⇒ ⇒ THIS CHANGE REPAIRS the last two of those five, = = so at
this tip the same census reads 425 open a readable file and 3 open
nothing, = = and the 3 are the absent files, = = which this card does
not own.

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

    ⇒ ⇒ ⇒ AND THE SCOPE IS **THIS CHANGE'S OWN WORK**, = = NOT EVERY
    FILE THAT DIFFERS FROM THE BASE: = = the diff is THREE-DOT (= =
    `base...HEAD` = = = the merge-base to HEAD), = = = = = so it names
    the files THIS branch rewrote. = = ⇒⇒⇒ MEASURED 2026-11-19 (= = =
    = the review's F1): = = = = = a two-dot diff named every file `main`
    changed after the fork, = = = = = = so a branch BEHIND `main` was
    charged for a row `main` itself had corrected (= = = = = = = = the
    branch's tree still carried the pre-correction row, = = = = = = = =
    = and rebasing onto `main` fixes it). = = ⇒⇒⇒ **⇒ SO THE GATE
    CHARGES A REWRITE THE BRANCH ITSELF DID, = = = = = = = = = = = = =
    = = = = and never one it merely inherited.**
    """
    changed = set(run(["git", "diff", "--name-only", f"{base}...HEAD"]).split("\n"))
    changed = {name.strip() for name in changed if name.strip()}
    tip_text = run(["git", "show", "HEAD:docs/agents/nfi.md"])
    keys = set()
    for cells in rows(tip_text):
        key = cells[1].strip("`")
        if key and key in changed:
            keys.add(key)
    return keys


def wc_lines(path):
    """The file's own `wc -l` count (= the registry's own convention).

    = = ⇒ ⇒ ⇒ **⇒ COUNT THE NEWLINES, = = NOT THE LINES.** = = `wc -l`
    counts newline-terminated lines, = = so a file that ends WITHOUT a
    trailing newline counts ONE LESS than the number of lines it holds.
    = = The registry's own header says so (= = "counting a file's lines the
    way `wc -l` does (= = newline-terminated lines, = = so a file that ends
    WITHOUT a trailing newline counts one less), = = and the header is the
    source of that convention.

    = = ⇒ ⇒ ⇒ AND THE IMPLEMENTATION MUST MATCH THAT: = = counting the
    ITERATIONS of a binary file handle (= = `sum(1 for _ in handle)`) counts
    the LINES, = = which is `splitlines()`, = = and that is ONE HIGHER for
    such a file. = = ⇒ ⇒ ⇒ MEASURED 2026-11-19: = = on
    `wt/inspector-9roles-2026-11-19` the gate reported
    `InspectorStylePageFixture.swift: the row says 218, the file is 219`
    = = where the file holds 218 newlines and 219 lines (= = it ends without
    a trailing newline). = = The row was RIGHT (= = 218 = = the registry's
    own convention) and the gate was wrong. = = ⇒ ⇒ ⇒ So this counts the
    newlines, = = and that is the registry's LOC column.
    """
    try:
        with open(path, "rb") as handle:
            return handle.read().count(b"\n")
    except OSError:
        return None


def why_unreadable(key):
    """WHY this row's key resolves to no readable file, = in one phrase.

    ⇒ ⇒ ⇒ `wc_lines` returns `None` for every shape below, = = and they
    need three different repairs: = an ABSENT path is a row whose file
    is gone (= = delete the row, = = or point it where the file went), =
    a DIRECTORY is a row that registered a whole tree (= = name one
    file of it), = and a BARE TOKEN is not a path at all (= = the count
    was pasted into the FILE column, = = = = so the row's key and its
    LOC are the same number, = = = = which is the tell).
    ⇒ ⇒ ⇒ ⇒ ⇒ The gate's output has to carry the difference; = = = a row
    reported as merely "unmeasurable" tells the next reader nothing
    about which repair applies. = = = Measured 2026-11-20, = = = card
    `t_70592b92`.
    """
    path = os.path.join(REPO, key)
    # ⇒ ⇒ THE SHORTHAND TEST COMES FIRST, = = BEFORE ANY EXISTENCE BRANCH.
    # Every one of the 33 live abbreviated keys in the table contains `/`
    # (`Sources/.../ImportService.swift`), = = so a branch that tests
    # `"/" in key and not exists` first answers `absent (= = no such path in
    # the tree)` for a row the table's OWN convention sanctions — = and the
    # repair it then suggests (= = "repoint or delete") is the wrong repair.
    # Measured 2026-11-20 by authoring such a row: rc=1, reason `absent`.
    # The reason label is the only thing the next reader acts on, = = so a
    # label that points at the wrong repair is a defect in the gate, = = not
    # cosmetics. = = Card `t_702d729c`, = = non-blocking 2.
    if "..." in key:
        return "not-a-path (the key is the table's `...` shorthand, not a path)"
    if key.endswith("/") and os.path.isdir(path):
        return "not-a-file (the key names a DIRECTORY, not a file)"
    if "/" in key and not os.path.exists(path):
        return "absent (no such path in the tree)"
    if os.path.isdir(path):
        return "not-a-file (the key names a DIRECTORY, not a file)"
    if os.path.exists(path):
        return "not-a-file (the key exists, but it is not a regular file)"
    if not key.strip("/").strip():
        return "not-a-path (the file's cell is EMPTY)"
    if LITERAL.match(key):
        return "not-a-path (the file's cell carries a bare NUMBER, not a path)"
    if "/" not in key:
        # NOT the shorthand case, which is answered above before any existence
        # test; this is a token with no separator at all that is also not a bare
        # number (the bare-number shape is caught just below).
        return "not-a-path (the key carries no directory separator, so no file can be opened from it)"
    return "not-a-path (the key is not a path this gate can open)"


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
    unmeasurable = []
    checked = 0
    for cells in rows(text):
        key = cells[1].strip("`")
        if key not in checked_keys:
            continue
        named = key
        loc_cell = next((index for index in range(2, len(cells)) if LITERAL.match(cells[index])), None)
        if loc_cell is None:
            unmeasurable.append(
                f"{named}: the row carries no LITERAL LOC cell (= nothing to compare)"
            )
            continue
        actual = wc_lines(os.path.join(REPO, named))
        if actual is None:
            # ⇒ ⇒ ⇒ **⇒ THE SILENT `continue` WAS THE DEFECT.** = = The row
            # was not measured, = = and until this line existed neither the
            # output nor the exit code said so.
            unmeasurable.append(
                f"{named}: {why_unreadable(named)} (= the row says {cells[loc_cell]})"
            )
            continue
        checked += 1
        if int(cells[loc_cell]) != actual:
            failures.append(f"{named}: the row says {cells[loc_cell]}, the file is {actual}")

    if failures or unmeasurable:
        print("nfi-loc-check: FAILED")
        for failure in failures:
            print("  " + failure)
        if unmeasurable:
            print(
                f"  {len(unmeasurable)} added or rewritten row(s) name no readable file "
                f"(= NOT measured, = NOT clean):"
            )
            for line in unmeasurable:
                print("  " + line)
        print(
            f"  ({checked} row(s) checked against the files this change added or rewrote; "
            f"{len(added)} key(s) added, {len(rewritten - added)} rewritten)"
        )
        print(
            "  exit 1 = a row disagreed with its file OR could not be opened at all;\n"
            "  exit 0 = every checked row was opened and agreed. A row the gate could not\n"
            "  measure is NEVER counted clean."
        )
        return 1

    print(
        f"nfi-loc-check: every added or rewritten file's row carries its own count "
        f"({checked} row(s) checked: = {len(added)} the change added, "
        f"= {len(rewritten - added)} whose named file the change rewrote "
        f"and did not add)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
