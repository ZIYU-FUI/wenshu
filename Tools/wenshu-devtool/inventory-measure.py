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
TICKET_ID = re.compile(r"\b[A-Z]{1,3}\d{2,4}\b")
RECEIPT = re.compile(r"rationale lines collapsed")


def production_files(base):
    """Every `.swift` under `Sources/`, minus the package-local `Tests/`."""
    out = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", base, "--", "Sources/"],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    return [p for p in out if p.endswith(".swift") and "/Tests/" not in p]


def package_test_files(base):
    out = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", base, "--", "Sources/"],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    return [p for p in out if p.endswith(".swift") and "/Tests/" in p]


def read(base, path):
    return subprocess.run(
        ["git", "show", f"{base}:{path}"], capture_output=True, text=True, check=True
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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="HEAD")
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
            for m in TICKET_ID.finditer(line):
                ids += 1
                distinct.add(m.group(0))
    print("5. ticket ids")
    print("   method: `\\b[A-Z]{1,3}\\d{2,4}\\b` in a production comment line")
    print(f"   {ids} occurrences, {len(distinct)} distinct")
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
    repo = pathlib.Path(__file__).resolve().parents[2]
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
