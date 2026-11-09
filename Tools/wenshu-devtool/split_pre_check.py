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
| an orphan leading blank line | swiftlint's `leading_whitespace` DOES catch it, = = and the tree's CI runs swiftlint report-only (= = it prints, = = and it does not fail a change) |
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

1. = = SWIFTLINT, on every file the change touched, = = and only the
   findings this change INTRODUCED. = = (The tree's CI runs swiftlint
   REPORT-ONLY, = = = = so it prints a pre-existing finding and does not
   fail the change, = = = = and it cannot say which findings are NEW.)
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
#: The vendored tree's prefix (= = upstream's own code, = = byte for
#: byte), = = and the tree's own formatting gate exempts it.
VENDORED_PREFIX = "Vendor/"

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



def _ref_exists(ref: str) -> bool:
    """Whether a ref is in this repo at all."""
    code, _ = sh("rev-parse", "--verify", f"{ref}^{{commit}}")
    return code == 0

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
        # = = ⇒ AND THE VENDORED TREE IS EXEMPT, = = exactly as the
        # = = = = tree's own formatting gate exempts it (= = = = the gate
        # = = = = drops the path before the lint, = = = = because the
        # = = = = vendored files are upstream's own code byte for byte).
        # = = = = ⇒ A tool that lints them charges the change for 61
        # = = = = findings the gate never charges anybody for.
        if path.startswith(VENDORED_PREFIX):
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
        # = = ⇒ AND THE WHOLE TREE, = = and not `Sources/`. = = A change
        # = = = = that touches only a TEST file is a real change (= = the
        # = = = = chat view's split changed 37 of them), = = = = and a tree
        # = = = = that reads `Sources/` only cannot see the test file at
        # = = = = all, = = = = so the tool reports a finding in a file it
        # = = = = never read. = = ⇒ AND THE PATHS ARE NOT NAMED, = = = =
        # = = = = because `git archive` FAILS ENTIRELY on a pathspec that
        # = = = = does not exist (= = a repo with no `Tests/`), = = = = =
        # = = = = and then the tree reads as EMPTY.
        proc = subprocess.run(
            ["git", "archive", ref],
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


def lint_in_tree(ref: str, paths: list[str], work_parent: Path | None = None) -> dict[str, list[str]]:
    """swiftlint over `paths` inside a THROWAWAY WORKTREE at `ref`.

    = = ⇒ AND THE WORKTREE, = = NOT A TEMP COPY OF THE FILES. = = A copy
    # = = = = carries no config, = = = = and the repo's config has an
    # = = = = `excluded:` list of RELATIVE paths, = = = = and those paths
    # = = = = do not resolve in a copy (= = so the copy lints files the
    # = = = = repo's own lint excludes, = = = = and the xianxia rule
    # = = = = reported 24 times where the repo's own lint reports 0).
    # = = = = ⇒ In the worktree the config, = = = = its excludes and the
    # = = = = paths all resolve, = = = = because it IS the repo.

    = = ⇒ AND THE RESULT IS PER FILE, = = because the comparison is
    # = = = = per file (= = a new finding in a changed file must not be
    # = = = = swallowed by an UNRELATED pre-existing finding elsewhere).
    """
    findings: dict[str, list[str]] = {}
    if not swiftlint_available():
        return findings
    # = = ⇒ AND THE WORKTREE'S DIRECTORY MUST NOT EXIST YET. = = `git
    # = = = = worktree add` refuses an existing directory, = = = = and
    # = = = = `mkdtemp` creates one. = = ⇒ So the worktree goes into a
    # = = = = fresh directory's CHILD.
    parent = Path(work_parent) if work_parent else Path(
        tempfile.mkdtemp(prefix="wenshu-lint-")
    )
    work = parent / "tree"
    try:
        code, out = sh("worktree", "add", "--detach", str(work), ref)
        if code != 0:
            # = = ⇒ AND A FAILURE TO MAKE THE WORKTREE IS SAID OUT
            # = = = = LOUD. = = An empty finding set reads as "nothing to
            # = = = = report", = = = = and that is the worst failure this
            # = = = = tool can have: = = = = it says nothing while it
            # = = = = checked nothing.
            findings["__ERROR__"] = [
                f"the worktree at {ref} could not be made: {out.strip()[:160]}"
            ]
            return findings
        present = [p for p in paths if (work / p).is_file()]
        if not present:
            return findings
        # = = ⇒ AND NO `--config`, = = because the worktree IS the repo
        # = = = = at that ref, = = = = and swiftlint finds the config
        # = = = = there (= = = = and a config that does not exist at that
        # = = = = ref is the one that ref had, = = = = which is right).
        cmd = ["swiftlint", "lint", "--quiet"] + present
        proc = subprocess.run(
            cmd, capture_output=True, text=True, cwd=str(work), timeout=1800
        )
        for line in (proc.stdout + proc.stderr).splitlines():
            line = line.strip()
            if not line or ":" not in line:
                continue
            head = line.split(":", 1)[0]
            if not head.endswith(".swift"):
                continue
            # = = ⇒ AND THE PATH IS RELATIVE TO THE WORKTREE. = = The
            # = = = = finding carries the worktree's own path (= = a
            # = = = = temporary directory), = = = = and the base's finding
            # = = = = carries ANOTHER temporary directory, = = = = so the
            # = = = = two do not compare (= = = = and a pre-existing
            # = = = = finding reads as a new one).
            # = = ⇒ AND BOTH SIDES ARE RESOLVED, = = = = because on
            # = = = = macOS `/var` is a symlink to `/private/var`, = = = =
            # = = = = and swiftlint prints the RESOLVED path while
            # = = = = `mkdtemp` hands back the unresolved one. = = ⇒ So a
            # = = = = plain `relative_to` raises, = = = = and the finding
            # = = = = keeps its absolute path (= = = = and the base's and
            # = = = = the tip's never compare).
            try:
                rel = str(Path(head).resolve().relative_to(work.resolve()))
            except ValueError:
                rel = head
            # = = A rule RENAMED by swiftlint is a warning about the tool,
            # = = not about the file.
            if "has been renamed to" in line:
                continue
            rest = line[len(head):]
            findings.setdefault(rel, []).append(f"{rel}{rest}")
    finally:
        sh("worktree", "remove", "--force", str(work))
        shutil.rmtree(parent, ignore_errors=True)
    return findings



def _added_lines(base: str, head: str, path: str) -> set[int]:
    """The line numbers a change ADDED in a file.

    = = ⇒ AND THE VIOLATION MUST BE ON AN ADDED LINE. = = The tree's own
    # = = = = formatting gate charges a change for the lines IT ADDED (= =
    # = = = = `git diff --unified=0`), = = = = and a violation that was
    # = = = = already there is the tree's own business. = = ⇒ So the
    # = = = = check is on the ADDED lines, = = = = and a file whose
    # = = = = pre-existing violations this change did not touch says
    # = = = = nothing.
    """
    code, out = sh("diff", "--unified=0", base, head, "--", path)
    added: set[int] = set()
    for line in out.split("\n"):
        # = = ⇒ AND THE GROUPS ARE THE RIGHT ONES. = = A hunk header is
        # = = = = `@@ -OLD[,OLD] +NEW[,NEW] @@`, = = = = so the NEW start
        # = = = = is the THIRD group, = = = = and the OLD start is the
        # = = = = first. = = = = ⇒ Reading the first one charged the
        # = = = = change for a violation on a line it did not touch.
        m = re.match(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
        if not m:
            continue
        start = int(m.group(3))
        count = int(m.group(4) or "1")
        for n in range(start, start + count):
            added.add(n)
    return added


SWIFTFORMAT_VIOLATION = re.compile(
    r"^(?P<path>.+?):(?P<line>\d+):(?P<col>\d+):\s*error:\s*\((?P<rule>[^)]*)\)\s*(?P<message>.*)$"
)


def swiftformat_findings(base: str, head: str, paths: list[str]) -> list[str]:
    """The SwiftFormat rules the change's ADDED lines break.

    = = ⇒ AND NOT SWIFTLINT'S RULES. = = The tree's formatting gate
    # = = = = charges a change for the lines IT ADDED, = = = = and it runs
    # = = = = SWIFTFORMAT (= = and not swiftlint). = = = = So a tool that
    # = = = = only runs swiftlint misses exactly the class the gate
    # = = = = charges: = = = = two consecutive blank lines, = = = = a
    # = = = = trailing comma, = = = = a space before a colon. = = = = ⇒
    # = = = = And that class is REAL: = = = = measured 2026-11-09, = = =
    # = = = = a helper added with TWO blank lines before it cost a
    # = = = = review card a round, = = = = and the card's own claim that
    # = = = = the gate exits 0 was false.

    = = = = ⇒ AND IT IS THE TREE'S OWN PARSING, = = = = so the two agree
    # = = = = on what a violation is: = = = = the same regex, = = = = the
    # = = = = same default rules (= = = = no config, = = = = because the
    # = = = = repo's config is in a dialect this SwiftFormat rejects), = =
    # = = = = and the same "only the ADDED lines" rule.

    = = = = ⇒ AND A RUN THAT COULD NOT COMPLETE IS LOUD, = = = = because
    # = = = = SwiftFormat exits 70 when it cannot do the work at all (= =
    # = = = = a missing file, = = = = a config it rejects, = = = = a syntax
    # = = = = error), = = = = and it reports NO violation, = = = = = so
    # = = = = "no violation" would read as clean.
    """
    findings: list[str] = []
    if shutil.which("swiftformat") is None:
        return findings
    parent = Path(tempfile.mkdtemp(prefix="wenshu-format-"))
    work = parent / "tree"
    try:
        code, out = sh("worktree", "add", "--detach", str(work), head)
        if code != 0:
            return [f"the worktree at {head} could not be made: {out.strip()[:160]}"]
        present = [p for p in paths if (work / p).is_file()]
        if not present:
            return findings
        proc = subprocess.run(
            ["swiftformat", "--lint", *present],
            capture_output=True, text=True, cwd=str(work), timeout=600,
        )
        if proc.returncode == 70:
            return [f"swiftformat refused to lint (= = its report is not trustworthy): "
                    f"{(proc.stdout + proc.stderr).strip()[:200]}"]
        for raw in (proc.stdout + proc.stderr).split("\n"):
            m = SWIFTFORMAT_VIOLATION.match(raw.strip())
            if not m:
                continue
            path = m.group("path")
            try:
                rel = str(Path(path).resolve().relative_to(work.resolve()))
            except ValueError:
                rel = path
            line = int(m.group("line"))
            if line not in _added_lines(base, head, rel):
                continue
            findings.append(f"{rel}:{line}: {m.group('rule')} = = {m.group('message').strip()}")
    finally:
        sh("worktree", "remove", "--force", str(work))
        shutil.rmtree(parent, ignore_errors=True)
    return findings


def _same_rule(a: str, b: str) -> bool:
    """Whether two swiftlint findings are the SAME finding, = = wherever
    they landed."""
    def norm(text: str) -> str:
        text = re.sub(r"^\S+?\.swift:\d+:\d+:\s*", "", text)
        text = re.sub(r"\b\d+:\d+\b", "", text)
        # = = A message that carries a COUNT (= = "555 lines", = = "373
        # = = lines") = = is not the same finding when the count moved:
        # = = a split's parent is 1125 lines and its tip is 555, = = and
        # = = that is the split itself, = = not a new violation.
        text = re.sub(r"\b\d+\b", "#", text)
        return text.strip()
    return norm(a) == norm(b)


def header_shape(paths: list[str], ref: str) -> list[str]:
    out = []
    for rel in paths:
        src = file_at(ref, rel)
        if src is None:
            continue
        leading = len(src) - len(src.lstrip("\n"))
        if leading == 1:
            out.append(f"{rel}: starts with a BLANK LINE (= = an import that was deleted left its line behind)")
        elif leading > 1:
            out.append(f"{rel}: starts with {leading} blank lines")
    return out


def removed_imports(base: str, head: str, paths: list[str]) -> list[tuple[str, str, list[str]]]:
    """Every module a file LOST, = = and which tip file still uses one of
    its members.

    = = ⇒ THE COMPARISON IS PER FILE, = = AND NOT OVER THE TREE'S UNION
    # = = OF IMPORTS. = = A union says "Foundation is still imported, = =
    # = = 473 files import it", = = and that is true, = = and it says
    # = = NOTHING about the one file that needs it and does not have it.
    # = = = = ⇒ The defect is a file's OWN import list, = = so the check
    # = = is a file's own import list.

    = = ⇒ AND THE QUESTION IS NOT "does this file compile", = = because
    # = = an extension MEMBER on a stdlib type leaks across the files of a
    # = = module: = = a file that calls `String.trimmingCharacters(in:)`
    # = = compiles without `import Foundation` as long as a SIBLING file
    # = = imports it. = = So the check asks a different question: = = does
    # = = THIS file name a member of the module, = = and is the module's
    # = = import in THIS file? = = The answer is yes for a type name, = =
    # = and the answer is a latent dependency for an extension member.

    = = ⇒ AND THE BASE SAYS WHETHER IT IS NEW: = = a file that used a
    # = = member without the import, = = and whose base held the same code
    # = = with the import, = = is this change's defect.
    """
    out = []
    base_tree = read_tree(base)
    head_tree = read_tree(head)
    # = = ⇒ ONLY THE FAMILIES THIS CHANGE TOUCHED. = = The check is
    # = = about THIS change, = = and a file elsewhere in the tree that
    # = = names a Foundation member without importing it is the tree's
    # = = own business (= = = = and it is a great many files, = = = =
    # = = because the repo leans on the module's other files' imports).
    family = [f for f in _families(base_tree, head_tree, paths)
              if set(f[1]) & set(paths)]

    for base_rel, tip_rels in family:
        base_text = base_tree.get(base_rel)
        if not base_text:
            continue
        base_imports = set(re.findall(r"^import\s+(\S+)", base_text, re.M))

        for rel in tip_rels:
            text = head_tree.get(rel)
            if not text:
                continue
            imports = set(re.findall(r"^import\s+(\S+)", text, re.M))
            code = strip_comments(text)
            used = _foundation_members(code)
            if not used:
                continue
            if "Foundation" in imports:
                continue
            # = = ⇒ AND THE REPORT IS ABOUT THIS CHANGE, = = SO IT NEEDS
            # = = THE BASE'S SAYING. = = A file that names a Foundation
            # = = member without importing Foundation is NOT this change's
            # = = defect when the base's file did the same: = = the tree
            # = = leans on `import SwiftUI` (= = which re-exports
            # = = Foundation), = = and that was true before the change too.
            # = = ⇒ So the finding is only a finding when the BASE's file
            # = = imported Foundation and the tip's does not.
            if "Foundation" not in base_imports:
                continue
            kinds = set()
            for member in used:
                kinds.add("type" if member in FOUNDATION_TYPE_NAMES else "extension member")
            reexport = "SwiftUI" in imports
            note = (f"{rel} uses {sorted(used)} ({', '.join(sorted(kinds))}) and does not "
                    f"import Foundation (= = and the base's file DID import it)")
            if reexport:
                note += (" (= = `import SwiftUI` re-exports Foundation, = = so it still "
                         "compiles, = = and the direct import is what this change dropped)")
            out.append(("Foundation", rel, [note]))
            break

    # = = AND THE FAMILY-SCOPE REMOVAL: = = a module the base's file
    # = = imported and NO tip file of the family imports any more.
    for base_rel, tip_rels in family:
        base_text = base_tree.get(base_rel)
        if not base_text:
            continue
        base_imports = set(re.findall(r"^import\s+(\S+)", base_text, re.M))
        tip_imports = set()
        for rel in tip_rels:
            text = head_tree.get(rel)
            if text:
                tip_imports |= set(re.findall(r"^import\s+(\S+)", text, re.M))
        for module in sorted(base_imports - tip_imports):
            # = = ⇒ AND A DROPPED MODULE IS A FINDING ONLY WHEN A FILE IN
            # = = = = THE FAMILY STILL USES IT AND DOES NOT IMPORT IT. = =
            # = = = = A module the family used and does not need any more
            # = = = = (= = = = the import was dead) = = = = is not a defect,
            # = = = = and saying so is how this arm stays worth reading:
            # = = = = measured: = = = = on a real split the family dropped
            # = = = = `AppKit` entirely, = = = = and nothing in it used
            # = = = = AppKit, = = = = and the arm said "still needs it".
            users = []
            for rel in tip_rels:
                text = head_tree.get(rel)
                if not text:
                    continue
                file_imports = set(re.findall(r"^import\s+(\S+)", text, re.M))
                if module in file_imports:
                    continue
                if module == "Foundation" and _foundation_members(strip_comments(text)):
                    users.append(rel)
            if users:
                out.append((
                    module, base_rel,
                    [f"the family of {base_rel} dropped `{module}` entirely, = = and "
                     f"{users[0]} still uses it (= = and does not import it)"],
                ))
    return out



def _counterparts(base_tree: dict, head_tree: dict, paths: list[str]) -> dict[str, list[str]]:
    """The base's files each changed tip file came from.

    = = ⇒ AND THE COMPARISON IS PER FILE, = = because a whole-tree base
    # = = = = lets an UNRELATED pre-existing finding swallow a new one in
    # = = = = a changed file (= = the rule and the message match, = = = =
    # = = = = and the path is not part of the comparison). = = ⇒ So each
    # = = = = tip file is compared with ITS OWN base, = = = = and a tip
    # = = = = file with no base at all (= = a brand-new file) has every
    # = = = = one of its findings as new.
    """
    out: dict[str, list[str]] = {}
    for tip_rel, base_rel in _origins(base_tree, head_tree, paths).items():
        out[tip_rel] = [base_rel]
    for tip_rel in paths:
        out.setdefault(tip_rel, [])
    return out

def _foundation_members(code: str) -> list[str]:
    """The Foundation names a body uses, = = types AND extension members."""
    found = [t for t in FOUNDATION_TYPE_NAMES if re.search(rf"\b{t}\b", code)]
    found += [e for e in FOUNDATION_EXTENSION_MEMBERS if e in code]
    return sorted(set(found))


def _families(base_tree: dict, head_tree: dict, paths: list[str]) -> list[tuple[str, list[str]]]:
    """The base file each tip file came from, = = and the tip files each
    base file became.

    = = ⇒ THE LINK IS BY DECLARATION, = = AND NOT BY NAME. = = A split
    # = = = = can RENAME the parent (= = `ChatSessionViewModel.swift`
    # = = = = becomes `ChatViewModel.swift`), = = = = and a name-based
    # = = = = link misses that entirely. = = And a name-based link that
    # = = = = tries to fix it with "the declarations overlap" fails too, = =
    # = = = because the parent's METHODS moved into the sibling files, = =
    # = = = and the parent kept only its stored properties.

    = = ⇒ AND EVERY TIP FILE HAS AT MOST ONE ORIGIN, = = AND THE LINK IS
    # = = = = ONLY MADE WHEN IT IS UNAMBIGUOUS. = = = = A declaration's
    # = = = = name is not unique (= = `one`, = = `body` and `id` are
    # = = = = everywhere), = = = = so a tip file that declares `func one`
    # = = = = can match TWO base files that each declare it. = = ⇒ And a
    # = = = = link that is ambiguous is WORSE THAN NO LINK: = = = = the
    # = = = = other file's findings then read as this one's, = = = = and
    # = = = = a new finding is swallowed. = = ⇒ So an ambiguous tip file
    # = = = = has NO origin, = = = = and every one of its findings is new.

    = = And the STEM is kept for the extension files (= = a
    # = = `Name+Cluster.swift` may hold no declaration of its own).
    """
    base_decls = {
        rel: _declarations(text)
        for rel, text in base_tree.items()
        if rel.endswith(".swift")
    }
    tip_decls = {
        rel: _declarations(text)
        for rel, text in head_tree.items()
        if rel.endswith(".swift")
    }

    origin: dict[str, str] = {}
    for rel, decls in tip_decls.items():
        if not decls:
            continue
        # = = ⇒ "THIS BASE HOLDS THE MAJORITY OF THIS FILE'S
        # = = = = DECLARATIONS", = = = = and the winner has to be
        # = = = = UNAMBIGUOUS. = = = = A count of three is blind to a
        # = = = = file that declares two things, = = = = and a split's
        # = = = = smallest file is often smaller than that.
        scored: list[tuple[int, float, str]] = []
        for base_rel, base_names in base_decls.items():
            shared = len(decls & base_names)
            if shared < 1:
                continue
            scored.append((shared, shared / len(decls), base_rel))
        if not scored:
            continue
        scored.sort(reverse=True)
        top_shared = scored[0][0]
        if scored[0][1] < 0.5:
            continue
        if len(scored) > 1 and scored[1][0] == top_shared:
            # = = ⇒ AMBIGUOUS, = = = = and so there is NO link.
            continue
        origin[rel] = scored[0][2]

    # = = And the stem link, = = for the extension files that declare
    # = = nothing of their own.
    base_stems = {Path(p).name.replace(".swift", "") for p in base_tree}
    for rel in tip_decls:
        if rel in origin:
            continue
        name = Path(rel).name.replace(".swift", "")
        stem = name.split("+")[0]
        if stem != name and stem in base_stems:
            for base_rel in base_tree:
                if Path(base_rel).name.replace(".swift", "") == stem:
                    origin[rel] = base_rel
                    break

    families: dict[str, list[str]] = {}
    for rel, base_rel in origin.items():
        families.setdefault(base_rel, []).append(rel)
    return [(b, sorted(set(t))) for b, t in sorted(families.items())]


def _origins(base_tree: dict, head_tree: dict, paths: list[str]) -> dict[str, str]:
    """Each tip file's ONE origin, = = and nothing for an ambiguous one."""
    out: dict[str, str] = {}
    for base_rel, tip_rels in _families(base_tree, head_tree, paths):
        for tip_rel in tip_rels:
            out.setdefault(tip_rel, base_rel)
    return out



def _declarations(text: str) -> set[str]:
    """The names a file DECLARES AS MEMBERS.

    = = ⇒ AND ONLY THE MEMBERS, = = and not every identifier. = = A
    # = = = = function body's `let a = 1` is a LOCAL, = = = = and two
    # = = = = files that both have one (= = `let a = 1` is everywhere)
    # = = = = are not related by it. = = ⇒ And a local that leaked into
    # = = = = the set made a tip file match an UNRELATED base file, = =
    # = = = = and that file's findings then read as this one's, = = = =
    # = = = = and a new finding was swallowed.

    = = ⇒ SO A MEMBER IS A DECLARATION AT THE TYPE'S OWN DEPTH. = = The
    # = = = = depth is the brace depth, = = = = and a type's body is one
    # = = = = level in, = = = = and a function's body is two.
    """
    code = strip_comments(text)
    depth = 0
    names: set[str] = set()
    for line in code.split("\n"):
        current = depth
        # = = The declarations this line carries, = = read BEFORE its own
        # = = braces move the depth.
        if current == 1:
            m = re.match(
                r"\s*(?:@[\w]+(?:\([^)]*\))?\s+)*(?:public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)?"
                r"(?:final\s+)?(?:mutating\s+|nonmutating\s+|static\s+|class\s+)?"
                r"(?:var|let)\s+(\w+)",
                line,
            )
            if m:
                names.add(m.group(1))
            m = re.match(
                r"\s*(?:@[\w]+(?:\([^)]*\))?\s+)*(?:public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)?"
                r"(?:final\s+)?(?:mutating\s+|nonmutating\s+|static\s+|class\s+)?"
                r"func\s+(\w+)",
                line,
            )
            if m:
                names.add(m.group(1))
            m = re.match(r"\s*init\b", line)
            if m:
                names.add("init")
        for ch in line:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth = max(0, depth - 1)
    for m in re.finditer(r"\b(?:class|struct|enum|protocol)\s+(\w+)", code):
        names.add(m.group(1))
    return {f for f in names if not f.startswith("_")}



def _all_swift(ref: str) -> list[str]:
    return sorted(read_tree(ref))


def lost_tokens(base: str, head: str, paths: list[str]) -> list[str]:
    """The tokens the base had and the tip does not.

    = = ⇒ THE BASE IS READ BY FAMILY, = = AND NOT BY PATH. = = A split
    # = = DELETES the base's file (= = `ChatSessionViewModel.swift` is
    # = = gone) and creates several, = = so a lookup by the base's own
    # = = path finds nothing, = = and the check is BLIND to exactly the
    # = = change it exists for. = = ⇒ The base's file is found by the
    # = = family it became, = = and its tokens are compared with the
    # = = tokens of every file that family produced.

    = = And the tip's side is the same: = = the tip's files that came out
    = = of the base's file, = = = = and nothing else, = = because a file
    = = the change did not touch cannot have lost a token.
    """
    out = []
    base_tree = read_tree(base)
    head_tree = read_tree(head)
    families = _families(base_tree, head_tree, paths)

    for base_rel, tip_rels in families:
        before = base_tree.get(base_rel)
        if not before:
            continue
        # = = Only the families this change touched matter.
        if not (set(tip_rels) & set(paths)):
            continue
        b_tokens = tokens(before)
        a_tokens = []
        for rel in tip_rels:
            text = head_tree.get(rel)
            if text:
                a_tokens += tokens(text)
        a_set = set(a_tokens)
        missing = [t for t in b_tokens if t not in a_set]
        for modifier in SEMANTIC_MODIFIERS:
            if modifier in missing:
                out.append(
                    f"{base_rel} had `{modifier}` and the family that replaced it "
                    f"does not (= = a modifier a split lost)"
                )
        # = = A doc comment that became a plain comment: = = the base's
        # = = `///` line and the tip's `//` line, = = in the SAME family.
        a_doc = set()
        a_plain = set()
        for rel in tip_rels:
            text = head_tree.get(rel)
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
                out.append(
                    f"{base_rel}: the base's `///` doc comment became a plain `//` "
                    f"(= = {line[:70]})"
                )
                break
    return out



# = = ⇒ AND THE MEMBER REGEX KNOWS SWIFT'S REAL MODIFIER ORDER. = =
# = = = = A member is `private` OR `private static` OR `private final`
# = = = = OR `private lazy` OR `private weak`, = = = = and the old
# = = = = regex read `private` as IMMEDIATELY followed by the name, = =
# = = = = so EVERY `private var x` and EVERY `private func x` read as
# = = = = "not private any more" (= = = = measured: = = = = 13 false
# = = = = = positives on one real split, = = = = every one of them a
# = = = = = member that was private in the base and private in the tip).
# = = = = ⇒ The modifier words sit BETWEEN the access level and the
# = = = = kind, = = = = and the regex says so.
_MEMBER_MODIFIERS = (
    r"(?:(?:static|final|lazy|weak|unowned|override|nonisolated|class|mutating|dynamic)\s+)*"
)


def probe_promotions(base: str, head: str, paths: list[str]) -> list[str]:
    """Put every widened member back to `private` and rebuild.

    = = A member the compiler never complains about is a member no file
    # = = needed.
    """
    findings = []
    parent = Path(tempfile.mkdtemp(prefix="wenshu-probe-"))
    work = parent / "tree"
    try:
        code, out = sh("worktree", "add", "--detach", str(work), head)
        if code != 0:
            return [f"the probe worktree could not be made: {out.strip()[:160]}"]
        try:
            # = = ⇒ AND THE BASE IS READ BY FAMILY, = = and not by path.
            # = = = = A split DELETES the base's file, = = = = so a lookup
            # = = = = by path finds nothing, = = = = and the check skips
            # = = = = the very file the split created (= = = = and the
            # = = = = member it widened is in THAT file).
            base_tree = read_tree(base)
            head_tree = read_tree(head)
            counterparts = _counterparts(base_tree, head_tree, paths)
            # = = The base's members, = = by name, = = and whether the
            # = = base said `private`.
            # = = ⇒ AND THE BASE'S MEMBERS ARE KEYED BY (FILE, NAME),
            # = = = = and not by NAME alone. = = = = ⇒ 322 real names
            # = = = = collide across the tree, = = = = and the same name
            # = = = = is private in one file and internal in another, = =
            # = = = = and a global name key made the arm's verdict FLIP
            # = = = = (5 against 7) = = = = = across twelve PYTHONHASHSEEDs
            # = = = = on one repo and one pair of shas. = = ⇒ The base is
            # = = = = the file this tip file came from, = = = = and the
            # = = = = member is looked up there.
            base_members: dict[tuple[str, str], bool] = {}
            for base_rel in {b for bs in counterparts.values() for b in bs}:
                text = base_tree.get(base_rel) or ""
                for m in re.finditer(
                    rf"^(\s*)(private\s+)?((?:@\w+(?:\([^)]*\))?\s+)*){_MEMBER_MODIFIERS}(var|let|func)\s+(\w+)",
                    text, re.M,
                ):
                    base_members[(base_rel, m.group(5))] = bool(m.group(2))
            widened = []
            for rel in paths:
                after = head_tree.get(rel)
                if after is None:
                    continue
                for i, line in enumerate(after.split("\n")):
                    # = = ⇒ AND THE TIP SIDE ACCEPTS AN ACCESS MODIFIER.
                    # = = = = The old regex admitted none, = = = = so a
                    # = = = = `private` -> `public` (= = = = and every
                    # = = = = other widening) = = = = was invisible, = = = =
                    # = = = = and the arm reported "every widened member is
                    # = = = = read across the file boundary" (= = = = = exit
                    # = = = = 0, = = = = measured).
                    m = re.match(
                        rf"^(\s*)((?:@\w+(?:\([^)]*\))?\s+)*)"
                        rf"(?:(public|internal|private|fileprivate|open)\s+)?"
                        rf"{_MEMBER_MODIFIERS}(var|let|func)\s+(\w+)",
                        line,
                    )
                    if not m:
                        continue
                    # = = ⇒ AND THE GROUP NUMBERS, = = because the
                    # = = = = access modifier added one. = = ⇒ The NAME is
                    # = = = = the FIFTH group (= = = = and the kind is the
                    # = = = = fourth), = = = = and reading the fourth as
                    # = = = = the name makes every member look like a
                    # = = = = keyword.
                    name = m.group(5)
                    # = = Only a member whose base said `private` and
                    # = = whose tip line does not = = was widened, = = and
                    # = = only in ITS OWN base file.
                    own_bases = counterparts.get(rel, [])
                    if not any(
                        base_members.get((base_rel, name)) is True for base_rel in own_bases
                    ):
                        continue
                    if not re.search(
                        rf"^\s*private\s+{_MEMBER_MODIFIERS}"
                        rf"(?:var|let|func)\s+{re.escape(name)}\b",
                        line,
                    ):
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
                # = = ⇒ AND THE BUILD'S EXIT CODE IS READ. = = The probe
                # = = = = used to grep the log for "is inaccessible" and
                # = = = = never looked at the status, = = = = so a FAILED
                # = = = = build (= = = = no compiler ran, = = = = or one
                # = = = = that died on something else) = = = = read as a
                # = = = = clean one (= = = = measured: = = = = exit 1 and
                # = = = = the tool still said "still builds (= = = = so no
                # = = = = file needed it)"). = = ⇒ A build that did not
                # = = = = succeed measures NOTHING, = = = = and it is said
                # = = = = out loud.
                if proc.returncode != 0 and not complained:
                    findings.append(
                        f"{rel}: `{name}` was widened, = = and the build with it put "
                        f"back to `private` FAILED (= = so the probe could not "
                        f"measure it, = = and this is not a verdict)"
                    )
                    continue
                if not complained:
                    findings.append(
                        f"{rel}: `{name}` was widened, = = and putting it back to `private` still builds"
                        + (f" (= = so no file needed it)" if True else "")
                    )
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(work)], cwd=str(CHECK_REPO), capture_output=True)
    finally:
        shutil.rmtree(parent, ignore_errors=True)
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True, help="the base sha (= = what the change is measured against)")
    parser.add_argument("--head", default="HEAD", help="the tip sha (= = HEAD)")
    parser.add_argument("--probe-promotions", action="store_true", help="also rebuild with every widened member put back to private (= = slow)")
    parser.add_argument("--repo", default=None, help="the tree to check (= = the worktree the branch is in)")
    parser.add_argument(
        "--lint-work-parent",
        default=None,
        help="where the throwaway lint worktrees go (= = for a test that needs the base's worktree to FAIL)",
    )
    args = parser.parse_args()

    global CHECK_REPO
    if args.repo:
        CHECK_REPO = Path(args.repo).resolve()
    print(f"split_pre_check: the tree under test = {CHECK_REPO}")

    # = = ⇒ AND THE BASE MUST EXIST. = = A base that does not exist
    # = = = = makes every comparison vacuous, = = = = and the run then
    # = = = = says "every case passed" (= = = = measured: = = = = a base
    # = = = = that does not exist gives byte-identical output to a change
    # = = = = with no Swift file).
    if not _ref_exists(args.base):
        print(f"split_pre_check: the base {args.base[:12]} does not exist in this repo")
        print("⇒ ⇒ ⇒ A BASE THAT DOES NOT EXIST MEANS NOTHING, = = = not clean.")
        return 1
    # = = ⇒ AND THE TIP IS CHECKED TOO, = = = = because a tip that
    # = = = = cannot be looked at is the same silence from the other side.
    if not _ref_exists(args.head):
        print(f"split_pre_check: the tip {args.head[:12]} does not exist in this repo")
        print("⇒ ⇒ ⇒ A TIP THAT CANNOT BE LOOKED AT MEANS NOTHING, = = = not clean.")
        return 1
    paths = changed_swift_files(args.base, args.head)
    print(f"split_pre_check: {len(paths)} changed Swift file(s) between {args.base[:12]} and {args.head[:12]}")
    for rel in paths:
        print(f"    = {rel}")
    print()

    failures = []

    print("=== 1. swiftlint (= = the tree's CI runs it report-only) ===")
    if not swiftlint_available():
        print("  ! swiftlint is not installed")
        failures.append("swiftlint is not installed")
    elif not paths:
        print("  ok  no Swift file changed (= = nothing for swiftlint to say)")
    else:
        # = = ⇒ THE COMPARISON IS PER FILE. = = The base is linted over
        # = = = = the base's COUNTERPART of each changed file (= = the
        # = = = = same path, = = = = or the base's file the tip's file was
        # = = = = split out of), = = = = and NOT over the whole tree. = =
        # = = = = ⇒ Because a whole-tree base lets an UNRELATED
        # = = = = pre-existing finding SWALLOW a new one in a changed
        # = = = = file (= = the rule and the message match, = = = = and
        # = = = = the path is not part of the comparison).
        head_by_file = lint_in_tree(args.head, paths)
        base_tree = read_tree(args.base)
        head_tree = read_tree(args.head)
        counterparts = _counterparts(base_tree, head_tree, paths)
        base_by_file = lint_in_tree(
            args.base,
            sorted({b for bs in counterparts.values() for b in bs}),
            Path(args.lint_work_parent) if args.lint_work_parent else None,
        )
        # = = ⇒ AND A TREE THAT COULD NOT BE READ IS SAID OUT LOUD. = =
        # = = = = A worktree that could not be made puts its failure in
        # = = = = `__ERROR__`, = = = = and nobody read it (= = = = so seven
        # = = = = pre-existing findings were reported as introduced, = =
        # = = = = with no "could not be made" anywhere). = = ⇒ And a base
        # = = = = that does not exist gives byte-identical output to a
        # = = = = change with no Swift file (= = = = "every case passed",
        # = = = = exit 0), = = = = and that is the worst thing a check can
        # = = = = do.
        for side, table in (("the base", base_by_file), ("the tip", head_by_file)):
            for problem in table.get("__ERROR__", []):
                print(f"  ! {side} could not be looked at: {problem}")
                failures.append(f"{side} could not be looked at")
        new_findings = []
        for tip_path, tip_list in sorted(head_by_file.items()):
            base_list: list[str] = []
            for counterpart in counterparts.get(tip_path, []):
                base_list += base_by_file.get(counterpart, [])
            # = = ⇒ AND THE COMPARISON IS A MULTISET, = = = = and not an
            # = = = = `any`. = = = = ⇒ A `any` says "the base had ONE of
            # = = = = these", = = = = and then it hides the tip's SECOND
            # = = = = finding of the same rule in the same file (= = = =
            # = = = = measured: = = = = swiftlint's own verdict was 2 and
            # = = = = the tool said 0, = = = = and 136 real files carry at
            # = = = = least one finding, = = = = 322 in all). = = ⇒ So
            # = = = = each base finding is CONSUMED once, = = = = and the
            # = = = = tip's extras are new.
            pool = list(base_list)
            for f in tip_list:
                match = None
                for index, b in enumerate(pool):
                    if _same_rule(f, b):
                        match = index
                        break
                if match is None:
                    new_findings.append(f)
                else:
                    pool.pop(match)
        for f in new_findings:
            print(f"  ! {f}")
        if new_findings:
            failures.append(f"{len(new_findings)} swiftlint finding(s) this change introduced")
        else:
            total = sum(len(v) for v in head_by_file.values())
            if total:
                print(f"  ok  no NEW finding (= = {total} pre-existing one(s) carried over)")
            else:
                print("  ok  no finding")

    print()
    print("=== 1b. swiftformat (= = the tree's formatting gate runs THIS, = = and it charges the ADDED lines) ===")
    if shutil.which("swiftformat") is None:
        print("  ok  swiftformat is not installed (= = the tree's own gate still runs it)")
    elif not paths:
        print("  ok  no Swift file changed")
    else:
        fmt = swiftformat_findings(args.base, args.head, paths)
        if fmt:
            for f in fmt:
                print(f"  ! {f}")
            failures.append(f"{len(fmt)} swiftformat finding(s) this change introduced")
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
        print("  ok  no file lost an import it still needs")
    for module, where, notes in removed:
        print(f"  ! `import {module}` was removed, = = and {where} still needs it")
        for note in notes:
            if "extension member" in note:
                kind = ("EXTENSION MEMBER (= = it LEAKS across files, = = so "
                        "'it still builds' proves nothing)")
            elif "type name" in note:
                kind = "type name (= = file-scoped, = = so the compiler catches it)"
            else:
                kind = ""
            print(f"        {note}")
            if kind:
                print(f"          (= = {kind})")
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
