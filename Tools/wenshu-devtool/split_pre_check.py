#!/usr/bin/env python3
"""split_pre_check.py · Wenshu (文枢)

The check that runs BEFORE a split goes back to the review lane, and
= = BEFORE the author has spent the review's time on it.

WHY THIS EXISTS

Measured 2026-11-09: six splits went to review in one session, = = and
the review sent back FOUR of them, = = and five of the defects were the
SAME KIND: = = mechanical, = = visible in the diff, = = and NOT caught by
any gate the tree runs:

= = = = the defect = = = = and why no gate saw it
| unused import lines | SwiftFormat has no unused-import rule, = = and swiftlint's config has no unused_import entry |
| an orphan leading blank line | swiftlint's `leading_whitespace` DOES catch it, = = and the tree's CI does not run swiftlint |
| a doc comment downgraded `///` to `//` by hand | no rule reads it |
| a semantic modifier lost (= = `nonisolated`) | no rule reads it |
| a promotion no file needed | no rule reads it |

= = = = and the fifth one is a TRAP FOR THE ORACLE EVERYONE REACHES FOR:

= = = = "the compiler is the oracle" is TRUE FOR A TYPE NAME AND FALSE
FOR AN EXTENSION MEMBER. = = Swift resolves an extension member on a
stdlib type across the files of a module, = = so a file that uses
`String.trimmingCharacters(in:)` compiles without `import Foundation`
as long as a SIBLING file imports it. = = A Foundation TYPE NAME stays
file-scoped, = = so the same probe does catch it. = = ⇒ Deleting an
import and seeing the tree still build PROVES NOTHING about an extension
member, = = and one split lost a `Foundation` import that way.

⇒ So this tool does five things the tree's gates do not:

1. = = SWIFTLINT, on every file the change touched. = = (The tree's CI
   does not run it, = = and it catches the orphan blank line.)
2. = = THE HEADER SHAPE: = = a file must not start with a blank line, = =
   and a deleted import must not leave one behind.
3. = = THE DELETED IMPORTS: = = every import the change removed is named,
   = = and the file's own uses of that module are listed, = = so a
   reviewer (= = and the author) can see the extension members.
4. = = THE TOKEN MULTISET, = = base against tip, = = over the whole
   change: = = every token the base had and the tip does not is named,
   = = so a lost modifier (= = `nonisolated`) and a downgraded doc
   comment (= = `///` -> `//`) both show up.
5. = = THE PROMOTIONS, = = by COMPILER: = = every member the change
   widened is put back to `private` in a throwaway worktree and the
   target is rebuilt, = = and a member the compiler never complains
   about is a member no file needed. = = (This one costs a build per
   widened member, = = so it is opt-in with `--probe-promotions`.)

Usage:
    python3 Tools/wenshu-devtool/split_pre_check.py --base <sha> [--head <sha>]
    python3 Tools/wenshu-devtool/split_pre_check.py --base <sha> --probe-promotions

Exit: 0 = every case passed, 1 = at least one case FAILED.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent

# = = The tree the change is checked IN. = = Every git call reads it, = =
# = = so the check measures the branch and not whatever the shared
# = = checkout happens to be on.
CHECK_REPO = REPO

# = = The Foundation members that are TYPE NAMES: = = file-scoped, = = so
# = = a probe on one of them is decisive.
FOUNDATION_TYPE_NAMES = [
    "CharacterSet", "Date", "DateFormatter", "ISO8601DateFormatter", "URL",
    "UUID", "Data", "NSLock", "NSObject", "NSString", "Bundle",
    "UserDefaults", "NotificationCenter", "FileManager", "IndexSet", "Timer",
    "DispatchQueue", "ProcessInfo", "Calendar", "Locale", "TimeInterval",
    "JSONEncoder", "JSONDecoder", "DateComponents", "Scanner", "NSRange",
    "NSNumber", "NSError", "OperationQueue", "RunLoop", "Thread",
]

# = = The Foundation members that are EXTENSION MEMBERS on a stdlib type:
# = = they LEAK across the files of a module, = = so "it still builds"
# = = proves nothing about them.
FOUNDATION_EXTENSION_MEMBERS = [
    "trimmingCharacters", "addingPercentEncoding", "removingPercentEncoding",
    "replacingOccurrences", "components", "folding", "enumerateLines",
    "write(to:", "data(using:", "localizedCapitalized", "compare(options",
]

# = = The modifiers a split can lose, = = and the compiler will not
# = = complain about losing.
SEMANTIC_MODIFIERS = [
    "nonisolated", "mutating", "nonmutating", "static", "final",
    "lazy", "weak", "unowned", "indirect", "dynamic", "optional",
    "convenience", "required", "override", "async", "throws", "rethrows",
]


def sh(*args: str, cwd: Path | None = None) -> tuple[int, str]:
    proc = subprocess.run(
        ["git", *args], cwd=str(cwd or CHECK_REPO), capture_output=True, text=True
    )
    return proc.returncode, proc.stdout + proc.stderr


def changed_swift_files(base: str, head: str) -> list[str]:
    code, out = sh("diff", "--name-status", base, head)
    files = []
    for line in out.splitlines():
        parts = line.split("\t")
        if not parts or not parts[0]:
            continue
        status = parts[0]
        path = parts[-1]
        if not path.endswith(".swift"):
            continue
        if status.startswith("D"):
            continue
        files.append(path)
    return files


_TREE_CACHE: dict[str, dict[str, str]] = {}


def read_tree(ref: str) -> dict[str, str]:
    """Every Swift file of a ref, = = read in ONE call.

    = = A per-file `git show` over a 547-file tree is thousands of
    # = = processes, = = and the check then takes minutes. = = `git
    # = = archive` reads the tree once.
    """
    if ref in _TREE_CACHE:
        return _TREE_CACHE[ref]
    tree: dict[str, str] = {}
    tmp = Path(tempfile.mkdtemp(prefix="wenshu-tree-"))
    try:
        proc = subprocess.run(
            ["git", "archive", ref, "Sources/"],
            cwd=str(CHECK_REPO), capture_output=True,
        )
        if proc.returncode == 0:
            tar = subprocess.run(
                ["tar", "-x", "-C", str(tmp)], input=proc.stdout, capture_output=True
            )
            if tar.returncode == 0:
                for path in tmp.rglob("*.swift"):
                    rel = str(path.relative_to(tmp))
                    try:
                        tree[rel] = path.read_text(encoding="utf-8", errors="replace")
                    except OSError:
                        pass
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    _TREE_CACHE[ref] = tree
    return tree


def file_at(ref: str, path: str) -> str | None:
    tree = read_tree(ref)
    if path in tree:
        return tree[path]
    code, out = sh("show", f"{ref}:{path}")
    return out if code == 0 else None


def strip_comments(text: str) -> str:
    """The code, = = without the comment lines (= = a comment can NAME a
    member, = = and a mention is not a use)."""
    out = []
    in_block = False
    for line in text.split("\n"):
        stripped = line.strip()
        if in_block:
            if "*/" in stripped:
                in_block = False
            continue
        if stripped.startswith("/*"):
            if "*/" not in stripped:
                in_block = True
            continue
        if stripped.startswith("//"):
            continue
        out.append(line)
    return "\n".join(out)


def tokens(text: str) -> list[str]:
    return re.findall(r"[A-Za-z_][A-Za-z0-9_]*", strip_comments(text))


def swiftlint_available() -> bool:
    return shutil.which("swiftlint") is not None


def run_swiftlint(paths: list[str], ref: str) -> list[str]:
    """swiftlint over the files, = = on a throwaway tree of the ref."""
    findings = []
    if not swiftlint_available():
        return ["swiftlint is not installed (= = the orphan-blank-line case cannot be checked)"]
    work = Path(tempfile.mkdtemp(prefix="wenshu-lint-"))
    try:
        for rel in paths:
            src = file_at(ref, rel)
            if src is None:
                continue
            target = work / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(src, encoding="utf-8")
        proc = subprocess.run(
            ["swiftlint", "lint", "--quiet", str(work)],
            capture_output=True, text=True,
        )
        for line in (proc.stdout + proc.stderr).splitlines():
            line = line.strip()
            if not line or ":" not in line:
                continue
            # = = keep the tree-relative part, = = and drop the temp path.
            if str(work) in line:
                line = line.split(str(work) + "/", 1)[1]
            # = = A rule RENAMED by swiftlint is a warning about the tool,
            # = = not about the file.
            if "has been renamed to" in line:
                continue
            findings.append(line)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return findings


def run_swiftlint_whole_tree(ref: str) -> list[str]:
    """swiftlint over EVERY Swift file of a ref, = = in one call."""
    findings = []
    if not swiftlint_available():
        return []
    tree = read_tree(ref)
    if not tree:
        return []
    work = Path(tempfile.mkdtemp(prefix="wenshu-lint-all-"))
    try:
        for rel, text in tree.items():
            target = work / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
        proc = subprocess.run(
            ["swiftlint", "lint", "--quiet", str(work)],
            capture_output=True, text=True,
        )
        for line in (proc.stdout + proc.stderr).splitlines():
            line = line.strip()
            if not line or ":" not in line:
                continue
            if str(work) in line:
                line = line.split(str(work) + "/", 1)[1]
            if "has been renamed to" in line:
                continue
            findings.append(line)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return findings


def _same_rule(a: str, b: str) -> bool:
    """Whether two swiftlint findings are the SAME finding, = = wherever
    they landed."""
    def norm(text: str) -> str:
        text = re.sub(r"^\S+?\.swift:\d+:\d+:\s*", "", text)
        text = re.sub(r"\b\d+:\d+\b", "", text)
        return text.strip()
    return norm(a) == norm(b)


def _base_counterpart(paths: list[str], base: str) -> list[str]:
    """The base's file for each tip file, = = matched by STEM.

    = = A split creates `Name+Cluster.swift` out of `Name.swift`, = = and
    # = = the base's file is the one whose name (without its extension) is
    # = = the tip file's stem. = = Without this, = = every finding in a
    # = = NEW file reads as "introduced by this change", = = because the
    # = = base has no counterpart to compare it with.
    """
    tree = read_tree(base)
    base_names = {Path(p).name.replace(".swift", "") for p in tree}
    out = []
    for rel in paths:
        name = Path(rel).name
        stem = name.split("+")[0].replace(".swift", "")
        if name.replace(".swift", "") in base_names:
            out.append(rel)
            continue
        if stem in base_names:
            for p in tree:
                if Path(p).name.replace(".swift", "") == stem:
                    out.append(p)
                    break
    return sorted(set(out))


def header_shape(paths: list[str], ref: str) -> list[str]:
    out = []
    for rel in paths:
        src = file_at(ref, rel)
        if src is None:
            continue
        if src.startswith("\n"):
            out.append(f"{rel}: starts with a BLANK LINE (= = an import that was deleted left its line behind)")
        elif src.startswith("\n\n"):
            out.append(f"{rel}: starts with TWO blank lines")
    return out


def removed_imports(base: str, head: str, paths: list[str]) -> list[tuple[str, str, list[str]]]:
    """Every module the change stopped importing, = = and which tip file
    still uses one of its members.

    = = The comparison is over the WHOLE change, = = not file by file: = =
    = = a split moves a file's contents into several files, = = so a
    = = per-file comparison sees "the tip's new file has no import" and
    = = calls it fine, = = while the module the base imported is gone
    = = from every file that needs it.
    """
    out = []
    base_files = [p for p in _all_swift(base)]
    head_files = [p for p in _all_swift(head)]
    b_modules = set()
    for rel in base_files:
        text = file_at(base, rel)
        if text:
            b_modules |= set(re.findall(r"^import\s+(\S+)", text, re.M))
    a_modules = set()
    for rel in head_files:
        text = file_at(head, rel)
        if text:
            a_modules |= set(re.findall(r"^import\s+(\S+)", text, re.M))
    for module in sorted(b_modules - a_modules):
        uses = []
        for rel in head_files:
            text = file_at(head, rel)
            if not text:
                continue
            code = strip_comments(text)
            if module == "Foundation":
                found = [t for t in FOUNDATION_TYPE_NAMES if re.search(rf"\b{t}\b", code)]
                found += [e for e in FOUNDATION_EXTENSION_MEMBERS if e in code]
            else:
                found = []
            if found:
                uses.append(f"{rel} uses {sorted(set(found))}")
        out.append((module, uses))
    return out


def _all_swift(ref: str) -> list[str]:
    return sorted(read_tree(ref))


def lost_tokens(base: str, head: str, paths: list[str]) -> list[str]:
    """The tokens the base had and the tip does not.

    = = Over the WHOLE change: = = a split moves a file's contents into
    = = several files, = = so a per-file comparison calls every modifier
    = = that moved "lost".
    """
    out = []
    base_tree = read_tree(base)
    head_tree = read_tree(head)
    # = = Only the files this change TOUCHED count. = = A split moves a
    # = = file's contents into new files, = = so the base's file and the
    # = = tip's files are compared as ONE SET (= = the base's file plus
    # = = every file the tip created out of it).
    touched = set(paths)
    created = {
        rel for rel in head_tree
        if rel not in base_tree and _shares_stem(base_tree, head_tree, rel)
    }
    b_tokens = []
    for rel in touched:
        text = base_tree.get(rel)
        if text:
            b_tokens += tokens(text)
    a_tokens = []
    for rel in touched | created:
        text = head_tree.get(rel)
        if text:
            a_tokens += tokens(text)
    a_set = set(a_tokens)
    missing = [t for t in b_tokens if t not in a_set]
    for modifier in SEMANTIC_MODIFIERS:
        if modifier in missing:
            out.append(f"the base had `{modifier}` and the tip does not (= = a modifier a split lost)")
    # = = A doc comment that became a plain comment: = = the base's
    # = = `///` line and the tip's `//` line, = = in the SAME file set.
    # = = The plain comments are collected PER FILE SET (= = the base's
    # = = file plus the tip's files split out of it). = = A sentence that
    # = = appears as a plain comment SOMEWHERE ELSE in the tree is not a
    # = = downgraded doc comment: = = the tree says the same thing in
    # = = more than one place, = = and that is not this change's doing.
    for rel in touched:
        before = base_tree.get(rel)
        if not before:
            continue
        family = {rel} | {c for c in created if _shares_stem(base_tree, head_tree, c)
                          and _shares_stem_for(base_tree, head_tree, rel, c)}
        a_doc = set()
        a_plain = set()
        for fam in family:
            text = head_tree.get(fam)
            if not text:
                continue
            for line in text.split("\n"):
                s = line.strip()
                if s.startswith("///"):
                    a_doc.add(s[3:].strip())
                elif s.startswith("//"):
                    a_plain.add(s[2:].strip())
        for line in [l.strip()[3:].strip() for l in before.split("\n") if l.strip().startswith("///")]:
            if line and line not in a_doc and line in a_plain:
                out.append(f"{rel}: the base's `///` doc comment became a plain `//` (= = {line[:70]})")
                break
    return out


def _shares_stem_for(base_tree: dict, head_tree: dict, base_rel: str, tip_rel: str) -> bool:
    """Whether a tip file was split out of a particular base file."""
    stem = Path(tip_rel).name.split("+")[0].replace(".swift", "")
    return Path(base_rel).name.replace(".swift", "") == stem


def _shares_stem(base_tree: dict, head_tree: dict, rel: str) -> bool:
    """Whether a tip file was split out of one of the base's files."""
    stem = Path(rel).name.split("+")[0].replace(".swift", "")
    for base_rel in base_tree:
        if Path(base_rel).name.replace(".swift", "") == stem:
            return True
    return False


def probe_promotions(base: str, head: str, paths: list[str]) -> list[str]:
    """Put every widened member back to `private` and rebuild.

    = = A member the compiler never complains about is a member no file
    # = = needed.
    """
    findings = []
    work = Path(tempfile.mkdtemp(prefix="wenshu-probe-"))
    try:
        code, out = sh("worktree", "add", "--detach", str(work), head)
        if code != 0:
            return [f"the probe worktree could not be made: {out.strip()[:160]}"]
        try:
            widened = []
            for rel in paths:
                after = file_at(head, rel)
                if after is None:
                    continue
                for i, line in enumerate(after.split("\n")):
                    m = re.match(r"^(\s*)((?:@\w+(?:\([^)]*\))?\s+)*)(var|let|func)\s+(\w+)", line)
                    if not m:
                        continue
                    name = m.group(4)
                    after_text = file_at(head, rel)
                    # = = Only a member whose base line said `private`
                    # = = and whose tip line does not = = was widened.
                    before = file_at(base, rel)
                    if before is None:
                        continue
                    if re.search(rf"^\s*private\s+(?:@\w+\s+)*(?:var|let|func)\s+{re.escape(name)}\b", before, re.M):
                        if not re.search(rf"^\s*private\s+{re.escape(name)}\b", line):
                            widened.append((rel, name, line))
            if not widened:
                return []
            for rel, name, line in widened:
                target = work / rel
                text = target.read_text(encoding="utf-8")
                new_text = re.sub(
                    rf"^(\s*)((?:@\w+(?:\([^)]*\))?\s+)*)(var|let|func)\s+{re.escape(name)}\b",
                    rf"\g<1>\g<2>private \g<3> {name}",
                    text, count=1, flags=re.M,
                )
                target.write_text(new_text, encoding="utf-8")
                proc = subprocess.run(
                    ["swift", "build"], cwd=str(work), capture_output=True, text=True, timeout=1800
                )
                log = proc.stdout + proc.stderr
                complained = re.search(rf"'{re.escape(name)}' is inaccessible", log)
                target.write_text(text, encoding="utf-8")
                if not complained:
                    findings.append(
                        f"{rel}: `{name}` was widened, = = and putting it back to `private` still builds"
                        + (f" (= = so no file needed it)" if True else "")
                    )
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(work)], cwd=str(CHECK_REPO), capture_output=True)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="the base sha (= = what the change is measured against)")
    parser.add_argument("--head", default="HEAD", help="the tip sha (= = HEAD)")
    parser.add_argument("--probe-promotions", action="store_true", help="also rebuild with every widened member put back to private (= = slow)")
    parser.add_argument("--repo", default=None, help="the tree to check (= = the worktree the branch is in)")
    args = parser.parse_args()

    global CHECK_REPO
    if args.repo:
        CHECK_REPO = Path(args.repo).resolve()
    print(f"split_pre_check: the tree under test = {CHECK_REPO}")

    paths = changed_swift_files(args.base, args.head)
    print(f"split_pre_check: {len(paths)} changed Swift file(s) between {args.base[:12]} and {args.head[:12]}")
    print()

    failures = []

    print("=== 1. swiftlint (= = the tree's CI does not run it) ===")
    if not swiftlint_available():
        print("  ! swiftlint is not installed")
        failures.append("swiftlint is not installed")
    else:
        head_findings = run_swiftlint(paths, args.head)
        # = = The base is linted WHOLE: = = a pre-existing finding in a
        # = = file this change did not touch must not read as new, = =
        # = and the tip's new files have no base counterpart at all.
        base_findings = run_swiftlint_whole_tree(args.base)
        # = = A finding's LINE NUMBER is not part of it: = = a split moves
        # = = the code, = = so the same warning sits on a different line
        # = = in the tip. = = So the comparison is on the rule and the
        # = = message, = = and not on where it landed.
        new_findings = [
            f for f in head_findings
            if not any(_same_rule(f, b) for b in base_findings)
        ]
        for f in new_findings:
            print(f"  ! {f}")
        if new_findings:
            failures.append(f"{len(new_findings)} swiftlint finding(s) this change introduced")
        elif head_findings:
            print(f"  ok  no NEW finding (= = {len(head_findings)} pre-existing one(s) carried over)")
        else:
            print("  ok  no finding")

    print()
    print("=== 2. the header shape (= = a deleted import leaves a blank line behind) ===")
    findings = header_shape(paths, args.head)
    if findings:
        for f in findings:
            print(f"  ! {f}")
        failures.append(f"{len(findings)} header shape finding(s)")
    else:
        print("  ok  every file starts with content")

    print()
    print("=== 3. the imports the change removed (= = and what the file still uses) ===")
    removed = removed_imports(args.base, args.head, paths)
    if not removed:
        print("  ok  no module was dropped from the whole tree")
    for module, uses in removed:
        print(f"  ! `import {module}` was removed from the WHOLE tree")
        if uses:
            for u in uses:
                leak = "EXTENSION MEMBER (= = it LEAKS across files, = = so 'it still builds' proves nothing)" if any(e in FOUNDATION_EXTENSION_MEMBERS for e in re.findall(r"'([^']+)'", u)) else "type name (= = file-scoped)"
                print(f"        {u}  (= = {leak})")
        else:
            print("        no tip file names a member of it")
    if removed:
        failures.append(f"{len(removed)} removed import(s) to confirm")

    print()
    print("=== 4. the tokens the base had and the tip does not ===")
    findings = lost_tokens(args.base, args.head, paths)
    if findings:
        for f in findings:
            print(f"  ! {f}")
        failures.append(f"{len(findings)} lost token(s)")
    else:
        print("  ok  no modifier lost, = = no doc comment downgraded")

    if args.probe_promotions:
        print()
        print("=== 5. the promotions (= = by the compiler) ===")
        findings = probe_promotions(args.base, args.head, paths)
        if findings:
            for f in findings:
                print(f"  ! {f}")
            failures.append(f"{len(findings)} unneeded promotion(s)")
        else:
            print("  ok  every widened member is read across the file boundary")
    else:
        print()
        print("=== 5. the promotions (= = by the compiler) = = SKIPPED (= = pass --probe-promotions) ===")

    print()
    if failures:
        print(f"split_pre_check: {len(failures)} case(s) FAILED")
        for f in failures:
            print(f"  - {f}")
        print()
        print("⇒ ⇒ ⇒ FIX THESE BEFORE THE REVIEW, = = not after it.")
        return 1
    print("split_pre_check: every case passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
