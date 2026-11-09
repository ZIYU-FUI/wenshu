#!/usr/bin/env python3
"""Re-derive the inventory's comment-drift numbers, each with its METHOD.

Every number in the record must be re-derivable by a reader, so this
script prints the definition it used next to the number. Run it from the
repository root:

    python3 Tools/wenshu-devtool/inventory-measure.py --base e9a85dcad9
"""
import argparse
import pathlib
import math
import re
import statistics
import subprocess
import sys
import tempfile

CJK = re.compile(r"[\u4e00-\u9fff]")
# The ticket families the tree's comment lines use, = = and the
# alternatives that reach them:
#
# = = `T4-SUBAGENT-UI` / `P1-02` / `C-4` = = the hyphenated family; = =
# = = `A112` / `Q112` / `M1` = = = the bare-number family; = =
# = = `T20c` / `T1a` / `H2s` = = = the LETTER-SUFFIXED family; = =
# = = `round-19` = = the lowercase-prefixed family; = =
# = = `GAP-003` / `TICKET-HERMES-GAP-002` / `TKT-028-025` = = = the
# = = connector-ticket family.
#
# = = The bare-number alternative cannot match the letter-suffixed
# = = family, = = because `\d{1,4}\b` needs a word boundary right after
# = = the digits, = = and the suffix letter continues the word. = = So the
# = = letter-suffixed family needs its OWN alternative, = = and the
# = = measured consequence of leaving it out was 22 invisible
# = = occurrences.
#
# = = THE CONNECTOR-TICKET FAMILY IS A FAMILY THE TREE CALLS TICKETS:
# = = its own prose says "out of scope per the GAP-003 ticket body" and
# = = "belong on the connector layer (ticket GAP-002)", = = so a census
# = = that named the tree's own ticket families and could not see these
# = = was not a census of them. = = The alternative below reaches them,
# = = and the suite names them.
TICKET_ID = re.compile(
    # = = THE HYPHENATED FAMILY. = = Its shape is a letter prefix, = = a
    # = = number, = = and then a hyphenated tail (= = `P1-02`, = =
    # = = `T4-SUBAGENT-UI`, = = `C-4`, = = `T0-PATH`, = = `P1-1`). = = The
    # = = tail is part of the id, = = so it is matched whole: = = a bare
    # = = `P1` would be a fragment of `P1-02`, = = and the at_base
    # = = attribution would be decided on a fragment.
    r"\b(?:T|P|A|B|C|Q|OOB|E|W|F|H|S|R)\d*-[A-Za-z0-9][A-Za-z0-9.-]*"
    # = = THE BARE-NUMBER FAMILY (= = A112, = = Q112, = = M1, = = T0). = =
    # = = Its boundary must NOT be a hyphen or a letter: = = otherwise it
    # = = wins over the hyphenated family on `P1-02` and reports the
    # = = half.
    r"|\b[A-Z]{1,3}\d{1,4}(?![-.A-Za-z0-9_])"
    # = = THE LETTER-SUFFIXED FAMILY (= = T20c, = = T1a, = = H2s, = =
    # = = = = the one the bare-number alternative cannot match, = = because
    # = = the suffix letter continues the word.
    r"|\b[A-Z]{1,3}\d{1,4}[a-z]\b"
    # = = THE LOWERCASE-PREFIXED FAMILY (= = round-19)
    r"|\bround-\d+\b"
    # = = THE CONNECTOR-TICKET FAMILY (= = GAP-003, = =
    # = = TICKET-HERMES-GAP-002, = = TKT-028-025): = = the tree's own
    # = = prose calls these tickets.
    r"|\b(?:GAP|TKT|TICKET-HERMES)[-][A-Za-z0-9][A-Za-z0-9.-]*"
)
RECEIPT = re.compile(r"rationale lines collapsed")


def production_files(base, cwd=None):
    """Every `.swift` under `Sources/`, minus the package-local `Tests/`.

    `cwd` says which repository to ask. = = Left unset, = = the question
    goes to the process's own directory, = = and the answer depends on
    where the caller happens to stand. = = A caller that must be right
    from any directory says which repository it means.
    """
    out = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", base, "--", "Sources/"],
        capture_output=True, text=True, check=True, cwd=cwd,
    ).stdout.splitlines()
    return [p for p in out if p.endswith(".swift") and "/Tests/" not in p]


def package_test_files(base, cwd=None):
    out = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", base, "--", "Sources/"],
        capture_output=True, text=True, check=True, cwd=cwd,
    ).stdout.splitlines()
    return [p for p in out if p.endswith(".swift") and "/Tests/" in p]


def read(base, path, cwd=None):
    """One file's text at `base`, read from the repository `cwd` names."""
    return subprocess.run(
        ["git", "show", f"{base}:{path}"],
        capture_output=True, text=True, check=True, cwd=cwd,
    ).stdout


def is_comment(line):
    s = line.strip()
    return s.startswith("//")


def is_doc(line):
    s = line.strip()
    return s.startswith("///")


def is_line_comment(line):
    s = line.strip()
    return s.startswith("//") and not s.startswith("///")


def strip_string_literals(line):
    """Remove the contents of Swift string literals from a line."""
    return re.sub(r'"(?:\\.|[^"\\])*"', '""', line)


# = = THE SKIP RULE, = = IN ONE PLACE. = =
# = =
# = = Two kinds of comment line are NOT ticket references: = = the
# = = collapse receipts (= = they carry their own A112/A115 labels, = =
# = = and those labels are measure 2's business), = = and the malformed
# = = `// /` doc comments (= = measure 1's business).
# = =
# = = THIS PREDICATE IS THE ONLY STATEMENT OF THAT RULE. = = Measure 5
# = = counts what survives it, = = the per-hit attribution reads what
# = = survives it, = = and the suite's guard PARSES IT = = so the
# = = printed method cannot drift from the measured row. = = A second
# = = copy of the rule would let the two drift again, = = which is the
# = = defect class this card exists to close.
SKIP_RULE = {
    "the collapse receipts": "RECEIPT.search(line)",
    "the `// /` lines": 'line.strip().startswith("// /")',
}


def skipped(line):
    """Whether this comment line is excluded from the ticket-id count.

    = = THE BODY IS GENERATED FROM `SKIP_RULE`. = = The rule lives in
    = = ONE table, = = and this function is that table compiled, = = so
    = = the measured row, = = the per-hit attribution and the suite's
    = = guard all read the SAME rule. = = A hand-written body beside the
    = = table would be a SECOND copy, = = and the last round measured
    = = exactly that: = = the guard saw the table, = = the measured row
    = = ran the copy, = = and removing a skip from the measured row left
    = = the guard green and the published number moving.
    """
    return any(eval(expression, {"RECEIPT": RECEIPT, "line": line}) for expression in SKIP_RULE.values())



def changed_files(base, tip):
    """The production files the change touched (= base vs tip).

    = = The attribution is about the change, = = so it names the files the
    = = change touched. = = The comparison is two-point (= = base vs tip),
    = = NOT the merge-base's merge-base semantics: = = `git diff base tip`
    = = = = exactly what changed between the two trees.
    """
    out = subprocess.run(
        ["git", "diff", "--name-only", base, tip],
        capture_output=True,
        text=True,
    ).stdout
    return {line.strip() for line in out.splitlines() if line.strip()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="HEAD")
    ap.add_argument(
        "--tip",
        default=None,
        metavar="SHA",
        help="the tree the change produced (= the working tree when omitted). "
        "With it, the ticket-id row also says, for each hit, whether the "
        "same hit was already at the base (= the base's debt) or is the "
        "change's own.",
    )
    ap.add_argument(
        "--files",
        nargs="+",
        default=None,
        metavar="PATH",
        help="scope the comment measures to these paths (= the whole production "
             "tree by default). The paths are repository-relative and are "
             "read at the base, so a card's own file list can be measured.",
    )
    args = ap.parse_args()
    base = args.base
    tip = args.tip

    if args.files:
        # A card's own file list: the paths are read at the base, so the
        # measure works on a tree where those files have already moved.
        files = list(args.files)
        scoped = True
    else:
        files = production_files(base)
        scoped = False
    print(f"base: {base}")
    if scoped:
        print(f"scope: the {len(files)} named file(s)")
    else:
        print(f"production .swift files (Sources/, minus */Tests/): {len(files)}")
    print()

    # 1. malformed doc comments: a comment line that starts `// /` (a
    #    plain comment carrying a slash, where `///` was meant).
    malformed = 0
    malformed_files = set()
    for p in files:
        for line in read(base, p).splitlines():
            s = line.strip()
            if s.startswith("// /"):
                malformed += 1
                malformed_files.add(p)
    print("1. malformed doc comments")
    print("   method: a production comment line whose trimmed text starts with `// /`")
    print(f"   {malformed} across {len(malformed_files)} files")
    print()

    # 2. collapse receipts
    receipts = 0
    a112 = a115 = 0
    for p in files:
        for line in read(base, p).splitlines():
            if not is_comment(line):
                continue
            if RECEIPT.search(line):
                receipts += 1
                if "A112" in line:
                    a112 += 1
                if "A115" in line:
                    a115 += 1
    print("2. collapse receipts")
    print("   method: a production comment line containing `rationale lines collapsed`")
    print(f"   {receipts} lines (A112 x {a112}, A115 x {a115}; sum {a112 + a115})")
    print()

    # 3. CJK in comments
    cjk_doc = cjk_line = 0
    cjk_doc_files, cjk_line_files = set(), set()
    cjk_doc_nolit = cjk_line_nolit = 0
    for p in files:
        for line in read(base, p).splitlines():
            if not is_comment(line):
                continue
            has = bool(CJK.search(line))
            lit_free = bool(CJK.search(strip_string_literals(line)))
            if is_doc(line):
                if has:
                    cjk_doc += 1
                    cjk_doc_files.add(p)
                if lit_free:
                    cjk_doc_nolit += 1
            elif is_line_comment(line):
                if has:
                    cjk_line += 1
                    cjk_line_files.add(p)
                if lit_free:
                    cjk_line_nolit += 1
    print("3. CJK in comments")
    print("   method: a production comment line containing a CJK character")
    print(f"   doc (`///`): {cjk_doc} across {len(cjk_doc_files)} files")
    print(f"   line (`//`): {cjk_line} across {len(cjk_line_files)} files")
    print("   with the string literals' contents removed from the line first:")
    print(f"   doc (`///`): {cjk_doc_nolit}")
    print(f"   line (`//`): {cjk_line_nolit}  (total {cjk_doc_nolit + cjk_line_nolit})")
    print()

    # 4. boss-directive references
    oob = 0
    oob_files = set()
    for p in files:
        for line in read(base, p).splitlines():
            if not is_comment(line):
                continue
            n = line.count("OOB.md")
            if n:
                oob += n
                oob_files.add(p)
    print("4. boss-directive references")
    print('   method: occurrences of the literal `OOB.md` in a production comment line')
    print(f"   {oob} across {len(oob_files)} files")
    print("   (rule 1.6 permits the form `(see OOB.md #YYYY-MM-DD)`, so this is an")
    print("    upper bound on the lines that violate it)")
    print()

    # 5. ticket ids
    ids = 0
    distinct = set()
    for p in files:
        for line in read(base, p).splitlines():
            if not is_comment(line):
                continue
            # = = the ONE skip rule (= = `skipped`), = = so the measured row
            # = = and the printed method cannot drift apart
            if skipped(line):
                continue
            for m in TICKET_ID.finditer(line):
                ids += 1
                distinct.add(m.group(0))
    print("5. ticket ids")
    print("   method: a form-complete ticket-id match in a production comment line:")
    print("   `\\b(?:T|P|A|B|C|Q|OOB|E|W|F|H|S|R)\\d*-[A-Za-z0-9][A-Za-z0-9.-]*`")
    print("   `|\\b[A-Z]{1,3}\\d{1,4}(?![-.A-Za-z0-9_])`")
    print("   `|\\b[A-Z]{1,3}\\d{1,4}[a-z]\\b`")
    print("   `|\\bround-\\d+\\b`")
    print("   `|\\b(?:GAP|TKT|TICKET-HERMES)[-][A-Za-z0-9][A-Za-z0-9.-]*`")
    print("   (= the families this rule covers, = = each with a form it")
    print("   reaches:")
    print("   the hyphenated one (= T4-SUBAGENT-UI, P1-02, C-4);")
    print("   the bare-number one (= A112, Q112, M1, T0);")
    print("   the LETTER-SUFFIXED one (= T20c, T1a, H2s, = = which the")
    print("   bare-number alternative cannot match, = = because the suffix")
    print("   letter continues the word);")
    print("   the lowercase-prefixed one (= round-19);")
    print("   the connector-ticket one (= GAP-003, TICKET-HERMES-GAP-002,")
    print("   TKT-028-025), = = which the tree's own prose calls tickets;")
    print("   AND TWO SKIPS, = = and the row above counts what survives them:")
    print("   the collapse receipts are skipped, because their own A112/A115")
    print("    labels are measure 2's business, not a ticket reference;")
    print("   the `// /` lines are skipped too, = = because they are malformed")
    print("    doc comments, = = and measure 1's business.)")
    print(f"   {ids} occurrences, {len(distinct)} distinct")
    print()

    # = = EACH HIT'S AT_BASE STATUS ( = = the base's debt vs the change's own )
    # = =
    # = = The aggregate row says how many; = = this says WHICH. = = A hit
    # = = is the base's debt when the base already carried that ticket id
    # = = on that line, = = and it is the change's own when the base's line
    # = = did not carry it. = = The comparison is on the LINE'S TEXT, = =
    # = = not on its number, = = because a change moves lines.
    if tip:
        # = = the hits, = = per file and per line, = = with each one's
        # = = at_base status.
        # = =
        # = = THE STATUS IS DECIDED ON THE BASE'S OWN TEXT FOR THAT FILE.
        # = = A hit is the base's debt when the base's SAME file already
        # = = carried that ticket id, = = and the change's own when it did
        # = = not. = = The comparison is on the FILE and the TOKEN, = =
        # = = not on the line's number (= = a change moves lines), = = and
        # = = NOT on a tree-wide token set: = = a token the base carried
        # = = in ANOTHER file is not this file's debt.
        def hits_in(text):
            found = []
            for lineno, line in enumerate(text.splitlines(), 1):
                if not is_comment(line):
                    continue
                # = = the ONE skip rule (= = `skipped`)
                if skipped(line):
                    continue
                for m in TICKET_ID.finditer(line):
                    found.append((lineno, m.group(0)))
            return found

        def read_at(rev, path):
            """The file's text at a revision, = = or None if it is not there.

            = = A file the change DELETED is not an error: = = it is absent
            = = at that revision, = = and the reader says so.
            """
            try:
                return read(rev, path)
            except subprocess.CalledProcessError:
                return None

        # = = the file sets: = = the base's own, = = and the tip's own. = =
        # = = The tip's set is NOT the base's set: = = a file the change
        # = = ADDED is in the tip and not in the base, = = and a file it
        # = = DELETED is in the base and not in the tip. = = Measuring the
        # = = base's list alone would miss an added file entirely.
        base_files = set(files)
        # = = THE SCOPE HOLDS ON BOTH SIDES. = = The last round measured
        # = = this failing: = = the tip's file set was the WHOLE tree, = =
        # = = so a `--files` run re-admitted every changed production file
        # = = = = the per-hit table published hits for files the caller did
        # = = = = NOT name, = = = = and (because the base's map was built
        # = = = = from the SCOPED set) = = the SAME hit flipped from
        # = = = = `at_base` to `the change's own` depending on an unrelated
        # = = = = flag. = = So the tip's set is the named set INTERSECTED
        # = = = = with the tip's own, = = and the scope is symmetric.
        tip_files = {p for p in production_files(tip) if p.endswith(".swift")}
        if scoped:
            # = = the SCOPE is the caller's OWN list of paths (= = `files`
            # = = = = at :192), = = so the tip's set is intersected with
            # = = = = THAT, = = not with the base's file set (= = a file
            # = = = = the change ADDED is in the tip and not in the base).
            tip_files &= set(files)
        measured_files = sorted((base_files | tip_files) & changed_files(base, tip))

        # = = THE SCOPE'S OWN FILE SET, = = FOR THE TREE'S ROW. = =
        # = =
        # = = The tree's row compares the base's tokens against the tip's
        # = = tokens, = = so BOTH SIDES MUST READ THE SAME FILES. = = The
        # = = last round measured this failing: = = the base side was
        # = = built from the CHANGED files and the tip side from the tip's
        # = = whole tree, = = so a scoped run published "base 43 -> tip
        # = = = = 306" (= = one file's base against the whole tree's tip)
        # = = = = and its own unscoped run said the true figure was 0.
        # = =
        # = = So the row reads the scope: = = the named files when the
        # = = caller named them, = = and the tip's production files when
        # = = they did not. = = And a file the scope names but the base
        # = = does not have is not an error (= = the change added it).
        scope_files = set(files) if scoped else set(tip_files)
        base_by_file = {}
        for p in scope_files:
            text = read_at(base, p)
            if text is None:
                continue
            base_by_file[p] = {token for _, token in hits_in(text)}
        base_hits = set()
        for tokens in base_by_file.values():
            base_hits |= tokens

        print("   each hit's at_base status:")
        reported = 0
        # = = THE FILES THE TABLE ACTUALLY READ. = = A file the change
        # = = DELETED is in the changed set and not at the tip, = = so it
        # = = = = the table never read it, = = = = and counting it in the
        # = = = = denominator would publish a number the table does not
        # = = = = support (= = the last round measured 2 where the table
        # = = = = read 1).
        read_files = []
        for p in measured_files:
            text = read_at(tip, p)
            if text is None:
                # = = the change DELETED this file: = = there is nothing at
                # = = the tip to attribute
                continue
            read_files.append(p)
            base_tokens = base_by_file.get(p, set())
            for lineno, token in hits_in(text):
                status = "at_base" if token in base_tokens else "the change's own"
                print(f"     {token:16s} {p}:{lineno} {status}")
                reported += 1
        print(
            f"   {reported} hit(s) over the {len(read_files)} production file(s) "
            f"this change touched"
        )

        tip_hits = set()
        for p in scope_files:
            text = read_at(tip, p)
            if text is None:
                continue
            for _, token in hits_in(text):
                tip_hits.add(token)
        debt = base_hits & tip_hits
        own = tip_hits - base_hits
        print(
            f"   the tree's row: base {len(base_hits)} -> tip {len(tip_hits)}, "
            f"of which {len(debt)} are the base's debt and {len(own)} the change's own"
        )
        print()

    if scoped:
        print("(the tree-level measures (= the size census and the three size")
        print(" rows) are not run for a scoped measurement: they are about the")
        print(" whole production tree, not about the named files.)")
        return

    # 6. the production tree's own size
    pkg_tests = package_test_files(base)
    print("6. the production tree's own size")
    print(f"   package-local test files under Sources/*/Tests/: {len(pkg_tests)}")
    sizes = sorted(len(read(base, p).splitlines()) for p in files)
    over = [s for s in sizes if s > 600]
    median = statistics.median(sizes)
    p90 = sizes[min(len(sizes) - 1, math.ceil(0.9 * len(sizes)) - 1)]
    print("   the production files' size (the cap is 600 LOC):")
    print(f"   method: the production .swift files' line counts at the base, sorted;")
    print(f"           the median is the middle one, the p90 the 90th percentile")
    print(f"   {len(sizes)} production files | median {median:g} | p90 {p90} | over 600: {len(over)}")
    print()

    # 7. the size table's three remaining rows, each with its method
    print("7. the size table's three remaining rows")
    print("   method (dead declarations): verify-dead.py over ALL the production")
    print("           files (= its default scope is the view directories only, and")
    print("           that narrower run reports a different number)")
    # verify-dead.py reads files from disk, so the pinned tree has to be on
    # disk: a temporary worktree at the base, removed afterwards.
    # = = THE REPOSITORY IS THE ONE THE TOOL RUNS IN, = = not the one the
    # = = tool happens to live in. = = The base and the tip are read with
    # = = `git show`, = = so they can name any repository, = = and the tree
    # = = that has to be ON DISK (= = for verify-dead) must be the SAME
    # = = repository's. = = Otherwise a run against another repository
    # = = builds a worktree of the wrong one.
    repo = pathlib.Path(
        subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    )
    with tempfile.TemporaryDirectory() as tmp:
        # The path has to be RESOLVED: the tool compares the paths it is
        # given against the git root it reports, and on macOS the
        # temporary directory's resolved path (/private/var/...) differs
        # from the one it was given (/var/...). An unresolved path makes
        # every file look alive, and the PARTIAL count reads 2 instead
        # of 35.
        tree = pathlib.Path(tmp).resolve()
        subprocess.run(
            ["git", "-C", str(repo), "worktree", "add", "--detach", str(tree), base],
            capture_output=True, text=True, check=True,
        )
        try:
            out = subprocess.run(
                [sys.executable, str(repo / "Tools/wenshu-devtool/verify-dead.py")]
                + [str(tree / f) for f in files],
                capture_output=True, text=True, cwd=str(tree),
            )
            for line in out.stdout.splitlines():
                if "PARTIAL" in line or "DEAD" in line:
                    print(f"   {line.strip()}")
        finally:
            subprocess.run(
                ["git", "-C", str(repo), "worktree", "remove", "--force", str(tree)],
                capture_output=True, text=True,
            )
    print("   method (no test coverage): a production file whose basename never")
    print("           appears in any test file's text (= a name-based probe, NOT")
    print("           coverage: no tool in this tree computes coverage)")
    test_files = package_test_files(base)
    test_files += subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", base, "--", "Tests/"],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    test_files = [f for f in test_files if f.endswith(".swift")]
    blobs = [read(base, f) for f in test_files]
    uncovered = [f for f in files if not any(pathlib.Path(f).stem in b for b in blobs)]
    print(f"   {len(uncovered)} of {len(files)} production files")
    print("   method (TODOs): a production file whose text contains `TODO`")
    todos = [f for f in files if "TODO" in read(base, f)]
    print(f"   {len(todos)} of {len(files)} production files")


if __name__ == "__main__":
    main()
