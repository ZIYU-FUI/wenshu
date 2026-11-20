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
TOOL = os.environ.get("NFI_LOC_CHECK_TOOL") or os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "nfi-loc-check.py")


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


def behind_main_case():
    """F1 EXACTLY: a branch BEHIND main must NOT be charged for a rewrite
    MAIN did.

    THE SHAPE: the branch forked from BASE; main then moved on and
    rewrote a registered file (and corrected that row); the BRANCH's own
    tree still carries the OLD (pre-correction) row. The branch did NOT
    touch that file (it has zero commits naming it), and by the
    registry's header the row's staleness is the TREE's own drift, not
    this branch's business.

    SO THE GATE MUST NOT CHARGE IT, and the fix is the THREE-DOT diff
    (base...HEAD = the merge-base to HEAD = this branch's own work).

    MEASURED 2026-11-19 (the review's F1): a two-dot diff named every
    file main changed after the fork, so the branch was charged for a
    row main itself had corrected.
    """
    with tempfile.TemporaryDirectory() as tmp:
        run(["git", "init", "-q", tmp], cwd=tmp)
        run(["git", "config", "user.email", "t@t"], cwd=tmp)
        run(["git", "config", "user.name", "t"], cwd=tmp)
        os.makedirs(os.path.join(tmp, "Sources"), exist_ok=True)
        os.makedirs(os.path.join(tmp, "docs", "agents"), exist_ok=True)
        theirs = os.path.join(tmp, "Sources", "Theirs.swift")
        ours = os.path.join(tmp, "Sources", "Ours.swift")
        registry = os.path.join(tmp, "docs", "agents", "nfi.md")

        # = the base: = one registered file, = and a row for it.
        with open(theirs, "w", encoding="utf-8") as handle:
            handle.write("let a = 1\nlet b = 2\n")
        with open(ours, "w", encoding="utf-8") as handle:
            handle.write("let x = 1\n")
        write_registry(registry, [("Sources/Theirs.swift", "Sources/Theirs.swift", 99)])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "base"], cwd=tmp)

        # = the BRANCH forks here, = and never touches Theirs.swift.
        run(["git", "checkout", "-qb", "branch"], cwd=tmp)
        with open(ours, "w", encoding="utf-8") as handle:
            handle.write("let x = 1\nlet y = 2\n")
        write_registry(
            registry,
            [
                ("Sources/Theirs.swift", "Sources/Theirs.swift", 99),
                ("Sources/Ours.swift", "Sources/Ours.swift", 2),
            ],
        )
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "the branch's own work"], cwd=tmp)

        # = MAIN moves on: = it rewrites Theirs.swift, = and corrects the
        # = row (= = so main's own tree is consistent).
        run(["git", "checkout", "-q", "main"], cwd=tmp)
        with open(theirs, "w", encoding="utf-8") as handle:
            handle.write("let a = 1\nlet b = 2\nlet c = 3\n")
        write_registry(
            registry,
            [
                ("Sources/Theirs.swift", "Sources/Theirs.swift", 3),
                ("Sources/Ours.swift", "Sources/Ours.swift", 1),
            ],
        )
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "main moved on"], cwd=tmp)
        main = run(["git", "rev-parse", "HEAD"], cwd=tmp).stdout.strip()

        # = the branch's tree still carries the PRE-correction row (= = = 2
        # = = = = for a file that is now 3 lines), = = and that is the drift
        # = = = = the header says is NOT this branch's business.
        run(["git", "checkout", "-q", "branch"], cwd=tmp)

        # = the gate, = = run against MAIN (= = = = = the landing case).
        result = run([sys.executable, TOOL, "--base", main, "--registry", registry], cwd=tmp)
        if result.returncode != 0:
            print("FAILED: the gate charged a branch for a rewrite MAIN did")
            print("  (= = = the F1 shape: = the row's staleness is the tree's drift)")
            print(result.stdout)
            return 1

        # = AND the gate must STILL charge the branch for ITS OWN work:
        # = the branch rewrote Ours.swift (= = and the row in the branch's
        # = tree says 1 while the file is 3 lines).
        with open(ours, "w", encoding="utf-8") as handle:
            handle.write("let x = 1\nlet y = 2\nlet z = 3\n")
        write_registry(
            registry,
            [
                ("Sources/Theirs.swift", "Sources/Theirs.swift", 99),
                ("Sources/Ours.swift", "Sources/Ours.swift", 1),
            ],
        )
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "the branch rewrote its own file"], cwd=tmp)

        result = run([sys.executable, TOOL, "--base", main, "--registry", registry], cwd=tmp)
        if result.returncode == 0:
            print("FAILED: the gate did NOT charge the branch for its OWN rewrite")
            print(result.stdout)
            return 1
        if "Ours.swift" not in result.stdout:
            print("FAILED: the gate went red without naming the branch's own row")
            print(result.stdout)
            return 1
        if "Theirs.swift" in result.stdout:
            print("FAILED: the gate charged the branch for MAIN's rewrite too")
            print(result.stdout)
            return 1

    return 0


def no_trailing_newline_case():
    """The LOC column counts NEWLINES (= = `wc -l`), = = not LINES.

    MEASURED 2026-11-19: the gate counted the ITERATIONS of a binary file
    handle (= = the LINES, = = `splitlines()`), = = and for a file that ends
    WITHOUT a trailing newline that is ONE HIGHER than the registry's own
    convention. = = So on `wt/inspector-9roles-2026-11-19` the gate reported
    `InspectorStylePageFixture.swift: the row says 218, the file is 219`
    = = where the file holds 218 newlines and 219 lines. = = The ROW was
    right and the GATE was wrong.

    ⇒ ⇒ ⇒ So this case writes a file with NO trailing newline, = = gives
    its row the NEWLINE count (= = what `wc -l` says), = = and the gate
    must be GREEN. = = And the RED half: the row carries the LINE count
    (= = one higher), = = and then the gate must go red and name it.
    """
    with tempfile.TemporaryDirectory() as tmp:
        run(["git", "init", "-q", tmp], cwd=tmp)
        run(["git", "config", "user.email", "t@t"], cwd=tmp)
        run(["git", "config", "user.name", "t"], cwd=tmp)
        os.makedirs(os.path.join(tmp, "Sources"), exist_ok=True)
        os.makedirs(os.path.join(tmp, "docs", "agents"), exist_ok=True)
        src = os.path.join(tmp, "Sources", "NoNewline.swift")
        registry = os.path.join(tmp, "docs", "agents", "nfi.md")

        # = the base: = one file with NO trailing newline (= = 2 newlines,
        # = = 3 lines), = and no row for it yet.
        with open(src, "w", encoding="utf-8") as handle:
            handle.write("let a = 1\nlet b = 2\nlet c = 3")  # = = no trailing \n
        write_registry(registry, [])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "base"], cwd=tmp)
        base = run(["git", "rev-parse", "HEAD"], cwd=tmp).stdout.strip()

        with open(src, "rb") as handle:
            raw = handle.read()
        newlines = raw.count(b"\n")
        lines = len(raw.decode("utf-8").splitlines())
        if newlines != 2 or lines != 3:
            print(f"FAILED: the fixture is not the shape: newlines={newlines} lines={lines}")
            return 1

        # = the GREEN half: = the row carries the NEWLINE count (= = `wc -l`).
        write_registry(registry, [("Sources/NoNewline.swift", "Sources/NoNewline.swift", newlines)])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "the row carries wc -l's count"], cwd=tmp)
        result = run([sys.executable, TOOL, "--base", base, "--registry", registry], cwd=tmp)
        if result.returncode != 0:
            print("FAILED: the gate charged a row that carries wc -l's own count")
            print(result.stdout)
            return 1

        # = the RED half: = the row carries the LINE count (= = one higher),
        # = = and the gate must go red and name it.
        write_registry(registry, [("Sources/NoNewline.swift", "Sources/NoNewline.swift", lines)])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "the row carries the line count instead"], cwd=tmp)
        result = run([sys.executable, TOOL, "--base", base, "--registry", registry], cwd=tmp)
        if result.returncode == 0:
            print("FAILED: the gate did NOT charge a row that carries the line count")
            print(result.stdout)
            return 1
        if "NoNewline.swift" not in result.stdout:
            print("FAILED: the gate went red without naming the row")
            print(result.stdout)
            return 1

    return 0


def unmeasurable_row_case():
    """THE DEFECT THIS CASE WAS WRITTEN FOR (= = card `t_70592b92`): = a row whose
    key the gate cannot open used to hit a bare `continue`, = = so the table could
    carry a row that had NEVER been measured, = = and neither the output nor the
    exit code said so.

    FOUR SHAPES, = = = = because they need three DIFFERENT repairs and a report
    that only says "unmeasurable" tells the next reader which one to do:
    a DIRECTORY (= the row registered a whole vendored tree), = a bare NUMBER
    (= = a count pasted into the file column), = an ABSENT path (= the file is
    gone), = = and a row with no literal LOC cell at all.
    """
    with tempfile.TemporaryDirectory() as tmp:
        run(["git", "init", "-q", tmp], cwd=tmp)
        run(["git", "config", "user.email", "t@t"], cwd=tmp)
        run(["git", "config", "user.name", "t"], cwd=tmp)
        os.makedirs(os.path.join(tmp, "Sources"), exist_ok=True)
        os.makedirs(os.path.join(tmp, "docs", "agents"), exist_ok=True)
        registry = os.path.join(tmp, "docs", "agents", "nfi.md")

        with open(os.path.join(tmp, "Sources", "Real.swift"), "w", encoding="utf-8") as handle:
            handle.write("let a = 1\n")
        # = a real DIRECTORY the change adds rows beside, = so the directory key is
        # not a fiction of the fixture (= = = `wc_lines` opens it and gets EISDIR).
        os.makedirs(os.path.join(tmp, "Sources", "Vendored"), exist_ok=True)
        with open(os.path.join(tmp, "Sources", "Vendored", "Manifest.swift"), "w", encoding="utf-8") as handle:
            handle.write("let m = 1\n")

        # = the base: one ordinary row, so the added set is everything below.
        write_registry(registry, [("Sources/Real.swift", "Sources/Real.swift", 1)])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "base"], cwd=tmp)

        # = the change: the same row, plus one of each unreadable shape.
        write_registry(registry, [
            ("Sources/Real.swift", "Sources/Real.swift", 1),
            ("Sources/Vendored/Manifest.swift", "Sources/Vendored/", 742),
            ("docs/agents/a-closeout.md", "262", 190),
            ("Sources/Gone.swift", "Sources/Gone.swift", 88),
            ("Sources/Approx.swift", "Sources/Approx.swift", "~428"),
            # and the table's OWN shorthand form (33 live rows use it). It contains
            # `/` like every real path, so it is the case that used to be labelled
            # `absent` — "the file is gone, repoint or delete" — for a row the table
            # itself sanctions. Card t_702d729c, non-blocking 2.
            ("Sources/AbbrevParent.swift", "Sources/.../Abbrev.swift", 99),
        ])
        run(["git", "add", "-A"], cwd=tmp)
        run(["git", "commit", "-qm", "the change adds rows the gate cannot open"], cwd=tmp)

        result = run([sys.executable, TOOL, "--base", "HEAD~1", "--registry", registry], cwd=tmp)
        if result.returncode == 0:
            print("FAILED: a row the gate cannot open left the run GREEN")
            print(result.stdout)
            return 1

        # = each shape is NAMED, = = with the reason that tells the reader which
        # repair applies (= the three reasons were the acceptance).
        for needle, why in [
            ("Sources/Vendored/", "not-a-file"),
            ("262", "not-a-path"),
            ("Sources/Gone.swift", "absent"),
            ("Sources/Approx.swift", "no LITERAL LOC cell"),
            ("Sources/.../Abbrev.swift", "shorthand"),
        ]:
            line = next((ln for ln in result.stdout.split("\n") if needle in ln), "")
            if why not in line:
                print(f"FAILED: the gate did not name {needle} as {why}: {line!r}")
                print(result.stdout)
                return 1

        # = and the count is stated, = = so "unmeasurable" cannot read as "clean".
        if "NOT measured" not in result.stdout or "NOT clean" not in result.stdout:
            print("FAILED: the gate reported unreadable rows without saying they are NOT clean")
            print(result.stdout)
            return 1
        if "exit 1" not in result.stdout:
            print("FAILED: the gate's output does not state its own exit-code rule")
            return 1

        # = = ⇒ AND THE COUNT IT PRINTS IS THE COUNT IT ACTUALLY OPENED: = the
        # only readable row in this fixture was carried by the base (= = = it is
        # NOT an added row), = so the honest number is 0 checked against 4 named,
        # = = and a gate that folds the rows it could not open into that count
        # reports 4 measured when it opened none.
        if "0 row(s) checked" not in result.stdout:
            print("FAILED: the gate counted rows it never opened as checked")
            print(result.stdout)
            return 1
        # The count and the list must AGREE, = = not merely both exist. Asserting a
        # literal here is the same stale-number trap the closeout document names:
        # adding one shape to this fixture silently turned `4` into `5`, and a test
        # that only checks a hard-coded number would then fail for the wrong reason
        # (or, worse, pass while the gate under-counts). So: the stated N must equal
        # the number of reason lines the gate printed, AND that N must be the five
        # shapes this fixture authors.
        import re as _re
        _stated = _re.search(r"(\d+) added or rewritten row\(s\) name no readable file", result.stdout)
        _named = sum(1 for ln in result.stdout.split("\n")
                     if _re.match(r"^  \S.*: (not-a-file|not-a-path|absent|the row carries no LITERAL)", ln))
        if _stated is None or int(_stated.group(1)) != _named or _named != 5:
            print(f"FAILED: the gate's count and its list disagree (stated={_stated and _stated.group(1)}, named={_named}, expected 5)")
            print(result.stdout)
            return 1

        # = = ⇒ ⇒ ⇒ AND THE SCOPE STILL HOLDS: = a row the change did NOT add,
        # whose key opens nowhere, must NOT be reported (= = = the table's standing
        # debt is the census's business, = = = not every branch's red run).
        base_only = run(
            [sys.executable, TOOL, "--base", "HEAD", "--registry", registry], cwd=tmp
        )
        if "Sources/Vendored/" in base_only.stdout and "HEAD~1" not in base_only.stdout:
            # HEAD vs HEAD = nothing added; the gate must say nothing to check.
            if "nothing to check" not in base_only.stdout:
                print("FAILED: the gate charged rows the change did not add")
                print(base_only.stdout)
                return 1
        print("ok: an unmeasurable row is named with its reason and fails the run")
        return 0


if __name__ == "__main__":
    code = main()
    if code == 0:
        code = rewritten_row_case()
    if code == 0:
        code = behind_main_case()
    if code == 0:
        code = no_trailing_newline_case()
    if code == 0:
        code = unmeasurable_row_case()
    sys.exit(code)
