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


# = = ⇒ AND A MEMBER'S IDENTITY IS (OWNING TYPE, NAME). = = ⇒ The
# = = = = promotions arm's base-side scan used to key a member by
# = = = = (file, name) and keep the LAST match, = = = = and two things
# = = = = overwrote a real `private` member: = = = = a LOCAL in a
# = = = = function body (= = = = the flat regex admitted any indentation)
# = = = = and the SAME NAME in a DIFFERENT type of the same file.
# = = = = Measured on `main`: = = = = 65 (file, name) pairs where a local
# = = = = hides a type's `private` member (= = = = 52 of them in
# = = = = `Sources/` and `Tests/`), = = = = and, in `Sources/` and
# = = = = `Tests/`, = = = = 15 (file, name) pairs where the name lives in
# = = = = two types with disagreeing privacy (= = = = 14 names).
_TYPE_DECL = re.compile(
    r"\b(?:struct|class|enum|actor|protocol|extension)\s+(\w+)"
)


# = = ⇒ AND A STRING LITERAL'S BRACES ARE NOT BRACES. = = Measured on
# = = = = `main`: = = = = 90 files hold an unbalanced brace inside a
# = = = = string literal, = = = = and the type stack goes wrong from the
# = = = = first one. = = ⇒ So the scan reads the code with the literals
# = = = = masked out.

# = = ⇒ ⇒ AND THE LITERAL HAS FOUR FORMS, = = = = and a REGEX reads one
# = = = = of them. = = = = The plain one (`"…"`), = = = = the RAW one
# = = = = (`#"…"#`), = = = = the multi-line one (`"""…"""`), = = = = and the
# = = = = raw multi-line one (`#"""…"""#`). = = = = The old regex
# = = = = (`"(?:\\.|[^"\\\n])*"`) matched the INNER quotes of a raw
# = = = = string and blanked only that part, = = = = so the REST of the
# = = = = literal leaked in as code, = = = = the type stack went off, = =
# = = = = and a member was read at FILE scope (= = = = measured: = = = =
# = = = = `LabelIconSweepTests.swift` read `totalSitesConsistent` at file
# = = = = scope instead of inside its type). = = ⇒ So the mask is a
# = = = = SCANNER, = = = = and it reads the comments and the literals in
# = = = = ONE pass (= = = = a quote inside a comment is not a literal, = =
# = = = = and a `//` inside a literal is not a comment).


def _blank(text: str) -> str:
    """The text blanked with spaces, = = = = the LINE COUNT kept."""
    return "".join(c if c == "\n" else " " for c in text)


def _block_comment_end(text: str, index: int) -> int:
    """The index just past the `*/` that closes the block comment at `index`.

    = = ⇒ AND THE COMMENTS NEST, = = = = because Swift's block comments do.

    = = ⇒ ⇒ AND `index` POINTS AT THE `/*`. = = = = = = = = = = The depth
    # = = = # = = = # = = counts it, = = = = = = = = = = so a nested one
    # = = = # = = = # = = closes with its own `*/`.
    """
    size = len(text)
    depth = 0
    cursor = index
    while cursor < size:
        if text.startswith("/*", cursor):
            depth += 1
            cursor += 2
            continue
        if text.startswith("*/", cursor):
            depth -= 1
            cursor += 2
            if depth == 0:
                return cursor
            continue
        cursor += 1
    return size


def _interpolation_end(text: str, index: int) -> int:
    """The index just past the `)` that closes the interpolation at `index`.

    = = ⇒ AND THE INTERPOLATION IS CODE, = = = = so the scan reads THROUGH
    # = = = = it: = = = = a literal in it is a literal, = = = = = = and a
    # = = = # = = = # = comment in it is a comment, = = = = = = and a paren
    # = = = # = = = # = in it is a paren. = = ⇒ Without this the scan
    # = = = # = = = # = stopped at the FIRST quote inside the interpolation,
    # = = = # = = = # = and the literal's own text leaked in as code (= =
    # = = # = = = # = = a brace in it moved the type stack).
    """
    size = len(text)
    depth = 1
    cursor = index + 1
    while cursor < size:
        char = text[cursor]
        if char == "(":
            depth += 1
            cursor += 1
            continue
        if char == ")":
            depth -= 1
            cursor += 1
            if depth == 0:
                return cursor
            continue
        if char == "#":
            hashes = 0
            while cursor + hashes < size and text[cursor + hashes] == "#":
                hashes += 1
            if cursor + hashes < size and text[cursor + hashes] == '"':
                cursor = _literal_end(text, cursor + hashes, hashes)
                continue
            cursor += hashes
            continue
        if char == '"':
            cursor = _literal_end(text, cursor, 0)
            continue
        if char == "/" and text.startswith("//", cursor):
            stop = text.find("\n", cursor)
            cursor = size if stop < 0 else stop
            continue
        if char == "/" and text.startswith("/*", cursor):
            cursor = _block_comment_end(text, cursor)
            continue
        cursor += 1
    return size


def _literal_end(text: str, start: int, hashes: int) -> int:
    """The index just past the literal that opens at `start`.

    = = ⇒ AND `start` POINTS AT THE FIRST QUOTE, = = = = and `hashes` is
    # = = = = the number of `#` that open it (= = = = 0 for a plain one).

    = = ⇒ ⇒ AND THE INTERPOLATION IS CODE, = = = = = = so the scan reads
    # = = = # = = = # = through it (= = = = = = = = = = a `\\(` in a plain
    # = = = # = = = # = literal, = = = = = = = = = = and a `\\#(` in a raw
    # = = = # = = = # = one), = = = = = = = = = and the literal's own end is
    # = = = # = = = # = the one AFTER it.
    """
    size = len(text)
    if text.startswith('"""', start):
        cursor = start + 3
        while cursor < size:
            char = text[cursor]
            if char == "\\":
                if hashes == 0:
                    if text[cursor + 1:cursor + 2] == "(":
                        cursor = _interpolation_end(text, cursor + 1)
                        continue
                    cursor += 2
                    continue
                if (text[cursor + 1:cursor + 1 + hashes] == "#" * hashes
                        and text[cursor + 1 + hashes:cursor + 2 + hashes] == "("):
                    cursor = _interpolation_end(text, cursor + 1 + hashes)
                    continue
                cursor += 1
                continue
            if text.startswith('"""', cursor) and text[cursor + 3:cursor + 3 + hashes] == "#" * hashes:
                return cursor + 3 + hashes
            cursor += 1
        return size
    cursor = start + 1
    while cursor < size:
        char = text[cursor]
        if char == "\\":
            if hashes == 0:
                if text[cursor + 1:cursor + 2] == "(":
                    cursor = _interpolation_end(text, cursor + 1)
                    continue
                cursor += 2
                continue
            if (text[cursor + 1:cursor + 1 + hashes] == "#" * hashes
                    and text[cursor + 1 + hashes:cursor + 2 + hashes] == "("):
                cursor = _interpolation_end(text, cursor + 1 + hashes)
                continue
            cursor += 1
            continue
        if char == '"':
            after = cursor + 1
            if text[after:after + hashes] == "#" * hashes:
                return after + hashes
            cursor += 1
            continue
        if char == "\n":
            break
        cursor += 1
    return min(cursor, size)


def literal_spans(text: str) -> list[tuple[int, int]]:
    """The span of every literal, = = = = = = the opening delimiter through
    the closing one.

    = = ⇒ THIS IS THE SCANNER'S OWN READ, = = = = and a caller that builds
    # = = = = a variant of the file (= = = = = = = = = = the measurement
    # = = = = = = does) uses THE SAME boundaries the mask uses, = = = = = =
    # = = = = = = otherwise the variant straddles a literal and the
    # = = = = = = measurement reads the probe's error.

    = = ⇒ ⇒ AND IT IS COMMENT-AWARE, = = = = because the mask is: = = = =
    # = = = = = = a quote inside a comment is not a literal, = = = = = = =
    # = = = = = = and a span that opened there would swallow real code.
    """
    spans: list[tuple[int, int]] = []
    index = 0
    size = len(text)
    while index < size:
        char = text[index]
        if char == "/" and text.startswith("//", index):
            end = text.find("\n", index)
            index = size if end < 0 else end
            continue
        if char == "/" and text.startswith("/*", index):
            depth = 0
            cursor = index
            while cursor < size:
                if text.startswith("/*", cursor):
                    depth += 1
                    cursor += 2
                    continue
                if text.startswith("*/", cursor):
                    depth -= 1
                    cursor += 2
                    if depth == 0:
                        break
                    continue
                cursor += 1
            index = cursor
            continue
        if char == "#":
            hashes = 0
            while index + hashes < size and text[index + hashes] == "#":
                hashes += 1
            if index + hashes < size and text[index + hashes] == '"':
                end = _literal_end(text, index + hashes, hashes)
                spans.append((index, end))
                index = end
                continue
        if char == '"':
            end = _literal_end(text, index, 0)
            spans.append((index, end))
            index = end
            continue
        index += 1
    return spans


def mask_code(text: str) -> str:
    """The code, = = with the comments and the string literals' contents
    blanked, = = and the LINE COUNT kept.

    = = ⇒ AND THE LINE COUNT MATTERS. = = = = The scan says which LINE a
    # = = = = declaration is on, = = = = and the arm rewrites that line,
    # = = = = so a mask that DROPPED the comment lines (= = = = the
    # = = = = tool's own `strip_comments` does) would count them out.

    = = ⇒ ⇒ AND THIS IS ONE PASS. = = = = A `//` inside a string literal is
    # = = = = not a comment, = = = = and a `//` inside a comment is not the
    # = = = = start of a string, = = = = so the two cannot be masked in two
    # = = = = separate passes (= = = = a quote in a comment would open a
    # = = = = literal that swallowed the real code after it).

    = = ⇒ ⇒ AND THE DELIMITERS STAY. = = = = A declaration that HOLDS a
    # = = = = literal is a member, = = = = so the literal's opening and
    # = = = = closing delimiters are kept and only its INTERIOR is blanked.
    """
    out: list[str] = []
    index = 0
    size = len(text)
    while index < size:
        char = text[index]
        if char == "/" and text.startswith("//", index):
            end = text.find("\n", index)
            end = size if end < 0 else end
            out.append(_blank(text[index:end]))
            index = end
            continue
        if char == "/" and text.startswith("/*", index):
            depth = 0
            cursor = index
            while cursor < size:
                if text.startswith("/*", cursor):
                    depth += 1
                    cursor += 2
                    continue
                if text.startswith("*/", cursor):
                    depth -= 1
                    cursor += 2
                    if depth == 0:
                        break
                    continue
                cursor += 1
            out.append(_blank(text[index:cursor]))
            index = cursor
            continue
        if char == "#":
            hashes = 0
            while index + hashes < size and text[index + hashes] == "#":
                hashes += 1
            if index + hashes < size and text[index + hashes] == '"':
                quote_at = index + hashes
                end = _literal_end(text, quote_at, hashes)
                out.append(text[index:quote_at])
                out.append('"')
                out.append(_blank(text[quote_at + 1:end - 1 - hashes]))
                out.append('"' + "#" * hashes)
                index = end
                continue
        if char == '"':
            end = _literal_end(text, index, 0)
            out.append('"')
            out.append(_blank(text[index + 1:end - 1]))
            out.append('"')
            index = end
            continue
        out.append(char)
        index += 1
    return "".join(out)



def _owner_survives(owner: str, tips_of_base: dict[str, list[str]],
                    tip_types: dict[str, set[str]]) -> bool:
    """Does the base's owning type STILL EXIST in the tip's own family?

    = = ⇒ AND THIS IS THE GUARD ON THE RENAMED-TYPE RULE. = = = = A name
    # = = = = with ONE candidate in the base file pairs with a tip member
    # = = = = of another owner (= = = = the type was renamed), = = = = but
    # = = = = only when the base's type is GONE from the tip. = = = = If it
    # = = = = is still there, = = = = then the tip's other-owner member is a
    # = = = = DIFFERENT member (= = = = measured: = = = = `ExportSheet`
    # = = = = still holds `chapters`, = = = = and the tip's NEW
    # = = = = `ChapterFileExporter.chapters` is a new member, = = = = not a
    # = = = = widening of it).

    = = ⇒ AND THE FAMILY, = = = = NOT THE ONE FILE. = = = = A split moves
    # = = = = a type into a NEW file, = # = = = and the type is still there
    # = = = = (= = = = the tip's family holds it). = = ⇒ So the question is
    # = = = = asked of every tip file that came from the base's file.
    """
    if not owner:
        return False
    for base_rel, tip_rels in tips_of_base.items():
        for tip_rel in tip_rels:
            if owner in tip_types.get(tip_rel, set()):
                return True
    return False


def scoped_members(text: str) -> list[tuple[str, str, bool, int]]:
    """The MEMBERS a file declares, = = each with the TYPE that owns it.

    = = ⇒ AND A MEMBER IS A DECLARATION WHOSE ENCLOSING FRAME IS A TYPE.
    # = = = = A local inside a function body sits in a deeper frame, = = = =
    # = = = = and it is not a member (= = = = the tool's own
    # = = = = `_declarations` says the same thing). = = = = The old scan
    # = = = = read a local as a member, = = = = and = = = = the LAST match
    # = = = = won, = = = = so a local overwrote a type's `private` member.

    = = ⇒ AND THE OWNING TYPE IS PART OF THE IDENTITY. = = = = Two types
    # = = = = can declare the same name, = = = = and one can be private
    # = = = = while the other is not, = = = = so (type, name) is what
    # = = = = names a member. = = = = Measured on `main`: = = = = 65
    # = = = = (file, name) pairs where a local hides a type's `private`
    # = = = = member (= = = = 52 of them in `Sources/` and `Tests/`), = =
    # = = = = and, in `Sources/` and `Tests/`, = = = = 15 (file, name)
    # = = = = pairs where the name lives in two types with disagreeing
    # = = = = privacy (= = = = 14 names).

    = = ⇒ AND THE ACCESS LEVEL IS READ IN ITS WHOLE VOCABULARY. = = = =
    # = = = = `public`, `internal`, `private`, `fileprivate` and `open`,
    # = = = = and an absent access level means `internal`. = = = = The old
    # = = = = scan admitted `private` only, = = = = so a `fileprivate`
    # = = = = member was not read as private at all.
    """
    code = mask_code(text)
    frames: list[str] = []   # the type name of each open frame (= = "" = not a type)
    out: list[tuple[str, str, bool, int]] = []
    for number, line in enumerate(code.split("\n"), 1):
        tm = _TYPE_DECL.search(line)
        dm = re.match(
            r"^(\s*)(?:@\w+(?:\([^)]*\))?\s+)*"
            r"(?:(public|internal|private|fileprivate|open)\s+)?"
            rf"(?:{_MEMBER_MODIFIERS})(?:var|let|func)\s+(\w+)",
            line,
        )
        # = = ⇒ AND THE OWNER IS THE TYPE, = = or the FILE for a
        # = = = = declaration at file scope (= = = = a top-level `private
        # = = = = func is file-scoped, = = = = and promoting it IS a
        # = = = = widening). = = = = A local inside a function body sits
        # = = = = in a non-type frame, = = = = and it is not a member.
        if dm and (not frames or frames[-1]):
            access = (dm.group(2) or "").strip()
            out.append((frames[-1] if frames else "", dm.group(3),
                        access in ("private", "fileprivate"), number))
        for ch in line:
            if ch == "{":
                frames.append(tm.group(1) if tm else "")
            elif ch == "}" and frames:
                frames.pop()
    return out


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
    # = = ⇒ AND THE TOOL OWNS ONLY WHAT IT MADE. = = A caller may point
    # = = = = `--lint-work-parent` at a directory of its own, = = = = and
    # = = = = the old code DELETED that directory (= = = = and everything
    # = = = = in it) = = = = because the flag was meant to make an
    # = = = = unreadable base injectable. = = ⇒ So the flag says where
    # = = = = the throwaway worktree goes, = = = = and the tool removes
    # = = = = ONLY that worktree (= = = = never the directory it was
    # = = = = pointed at).
    own_parent = work_parent is None
    parent = Path(work_parent) if work_parent else Path(
        tempfile.mkdtemp(prefix="wenshu-lint-")
    )
    work = parent / "tree"
    # = = ⇒ AND WHETHER THE TOOL MADE IT. = = The hook exists so that a
    # = = = = caller can point at a directory that already holds a
    # = = = = `tree/`, = = = = and the refusal of `git worktree add` is
    # = = = = what makes the base unreadable. = = ⇒ If the directory was
    # = = = = already there, = = = = it is NOT the tool's, = = = = and the
    # = = = = tool must not remove it.
    made_work = not work.exists()
    try:
        code, out = sh("worktree", "add", "--detach", str(work), ref)
        if code != 0:
            # = = ⇒ AND A `tree/` THAT WAS ALREADY THERE IS NOT OURS TO
            # = = = = REMOVE. = = `git worktree add` refuses an existing
            # = = = = directory, = = = = and when the caller's directory
            # = = = = already holds a `tree/`, = = = = that refusal is the
            # = = = = ONLY reason the tool is here. = = ⇒ Measured: = = = =
            # = = = = a caller's `tree/precious.txt` and `tree/sub/also.txt`
            # = = = = were GONE after a run that exited 0. = = ⇒ So the
            # = = = = directory is removed ONLY when the tool MADE it.
            # = = ⇒ AND A FAILURE TO MAKE THE WORKTREE IS SAID OUT
            # = = = = LOUD. = = An empty finding set reads as "nothing to
            # = = = = report", = = = = and that is the worst failure this
            # = = = = tool can have: = = = = it says nothing while it
            # = = = = checked nothing.
            findings["__ERROR__"] = [
                f"the worktree at {ref} could not be made: {out.strip()[:160]}"
            ]
            return findings
        # = = ⇒ AND THE VENDORED TREE IS EXEMPT HERE, = = = = and ONLY
        # = = = = HERE. = = = = The tree's own formatting gate drops the
        # = = = = vendored paths before its SwiftFormat run (= = = = they
        # = = = = are upstream's own code byte for byte), = = = = but the
        # = = = = tree's SWIFTLINT does not exclude them (= = = = and a
        # = = = = vendored file carrying a forbidden token makes the
        # = = = = tree's own lint exit 2). = = ⇒ The exemption belongs to
        # = = = = the arm that needs it, = = = = and the swiftlint arm
        # = = = = still sees the vendored tree (= = = = as the tree's own
        # = = = = lint does).
        # = = ⇒ AND THE VENDORED TREE IS NOT EXEMPT HERE. = = The tree's
        # = = = = own `.swiftlint.yml` excludes `.build`, = = = = `build`,
        # = = = = `DerivedData`, = = = = `.scratch` and a handful of named
        # = = = = files, = = = = and `Vendor/` is NOT among them. = = ⇒ So
        # = = = = the lint arm sees the vendored tree, = = = = = because the
        # = = = = tree's own lint does. = = ⇒ Measured: = = = = the tree's
        # = = = = lint on a vendored file carrying a forbidden token exits
        # = = = = 2, = = = = so a tool that hid it would be hiding a
        # = = = = failure the tree really has.
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
        # = = ⇒ AND THE GIT REMOVAL IS GUARDED TOO. = = `git worktree
        # = = = = remove --force` on a path the CALLER registered takes the
        # = = = = caller's directory, = = = = its files, = = = = its
        # = = = = uncommitted work and its git registration with it (= =
        # = = = = measured: = = = = 3/3 trials, = = = = all four gone). = =
        # = = = = ⇒ So the removal happens ONLY when the tool made the
        # = = = = worktree, = = = = and the caller's own stays.
        if made_work:
            sh("worktree", "remove", "--force", str(work))
        # = = ⇒ AND ONLY THE DIRECTORY THE TOOL MADE GOES. = = A parent
        # = = = = the caller supplied is NOT the tool's to remove, = = = =
        # = = = = and measured: = = = = a directory holding a file and a
        # = = = = subdirectory was GONE after a run that exited 0.
        # = = ⇒ AND THE SAME RULE GOVERNS THE WORKTREE'S OWN DIRECTORY.
        # = = = = A caller's directory that ALREADY held a `tree/` is the
        # = = = = caller's, = = = = and `git worktree add` refuses to
        # = = = = write into it (= = = = which is the point of the hook),
        # = = = = so removing it after that refusal deletes what the
        # = = = = refusal protected.
        if own_parent:
            shutil.rmtree(parent, ignore_errors=True)
        elif made_work:
            shutil.rmtree(work, ignore_errors=True)
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
        # = = ⇒ AND THE VENDORED TREE IS EXEMPT HERE, = = = = and ONLY
        # = = = = HERE. = = = = The tree's own formatting gate drops the
        # = = = = vendored paths before its SwiftFormat run (= = = = they
        # = = = = are upstream's own code byte for byte), = = = = but the
        # = = = = tree's SWIFTLINT does not exclude them (= = = = and a
        # = = = = vendored file carrying a forbidden token makes the
        # = = = = tree's own lint exit 2). = = ⇒ The exemption belongs to
        # = = = = the arm that needs it, = = = = and the swiftlint arm
        # = = = = still sees the vendored tree (= = = = as the tree's own
        # = = = = lint does).
        present = [
            p for p in paths
            if (work / p).is_file() and not p.startswith(VENDORED_PREFIX)
        ]
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
# = = ⇒ AND THE SAME VOCABULARY, CAPTURED. = = The rewrite has to put the
# = = = = modifier words BACK, = = = = and a non-capturing group cannot be
# = = = = re-emitted (= = = = `\g<n>` of a group that never matched). = = ⇒
# = = = = So the rewrite uses its own capturing form, = = = = and the
# = = = = capture is the modifiers = = = = = and nothing else.
_MEMBER_MODIFIERS_CAPTURE = (
    r"(?:(?:static|final|lazy|weak|unowned|override|nonisolated|class|mutating|dynamic)\s+)*"
)


def _rewrite_to_private(text: str, name: str, owner: str | None = None) -> str:
    """The promotions arm's REWRITE: = = the access level becomes
    `private`, = = and the modifier words STAY.

    = = ⇒ AND THIS IS ONE FUNCTION, = = = = NOT A PATTERN INLINED IN THE
    # = = = = ARM. = = ⇒ A case that copies the pattern into itself = = = =
    # = = = = cannot see the arm change its own pattern (= = = = measured:
    # = = = = the review's MUT C left the suite green, = = = = and so would
    # = = = = mine). = = ⇒ So the case calls THIS, = = = = and a mutation
    # = = = = here is a mutation the case sees.

    = = ⇒ AND THE OWNING TYPE PICKS THE LINE. = = = = Without it the
    # = = = = rewrite takes the FIRST declaration of that name in the
    # = = = = file, = = = = and a file with the same name in two types
    # = = = = would have the WRONG one put back to `private` (= = = = and
    # = = = = the probe then measured a member nobody widened).
    """
    pattern = (
        rf"^(\s*)((?:@\w+(?:\([^)]*\))?\s+)*)"
        rf"(?:(?:public|internal|private|fileprivate|open)\s+)?"
        rf"({_MEMBER_MODIFIERS_CAPTURE})(var|let|func)\s+{re.escape(name)}\b"
    )
    replacement = rf"\g<1>\g<2>private \g<3>\g<4> {name}"
    if owner is None:
        # = = ⇒ AND WITHOUT AN OWNER, = = = = the rewrite takes the FIRST
        # = = = = declaration of that name, = = = = wherever it is (= = = =
        # = = = = the helper's own contract, = = = = and a caller with no
        # = = = = type context still gets a rewrite).
        return re.sub(pattern, replacement, text, count=1, flags=re.M)
    lines = text.split("\n")
    target = None
    for member_owner, member_name, _private, number in scoped_members(text):
        if member_name != name:
            continue
        if member_owner != owner:
            continue
        target = number
        break
    if target is None:
        return text
    line = lines[target - 1]
    lines[target - 1] = re.sub(
        rf"^(\s*)((?:@\w+(?:\([^)]*\))?\s+)*)"
        rf"(?:(?:public|internal|private|fileprivate|open)\s+)?"
        rf"({_MEMBER_MODIFIERS_CAPTURE})(var|let|func)\s+{re.escape(name)}\b",
        rf"\g<1>\g<2>private \g<3>\g<4> {name}",
        line, count=1,
    )
    return "\n".join(lines)


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
            # = = ⇒ AND THE BASE'S MEMBERS ARE PAIRED WITH THE TIP'S BY
            # = = = = THEIR OWN IDENTITY, = = = = and the pairing has
            # = = = = THREE RULES. = = = = Measured on `main`: = = = = 65
            # = = = = (file, name) pairs where a LOCAL hides a type's
            # = = = = `private` member (= = = = 52 of them in `Sources/`
            # = = = = and `Tests/`), = = = = and, in `Sources/` and
            # = = = = `Tests/`, = = = = 15 (file, name) pairs where the
            # = = = = name lives in two types with disagreeing privacy (= =
            # = = = = = the flat scan's LAST match wins, = = = = = and the
            # = = = = = private one lost; = = = = = = 14 names).
            # = = = = 1. THE OWNING TYPE MATCHES = = = = ⇒ that is the
            # = = = =    same member, = = = = whatever the file.
            # = = = = 2. THE OWNING TYPE DOES NOT MATCH, = = = = and the
            # = = = =    NAME has ONE candidate in the base file = = = = ⇒
            # = = = =    the type was RENAMED (= = = = a split that
            # = = = =    renamed its type), = = = = and it is the same
            # = = = =    member.
            # = = = = 3. THE OWNING TYPE DOES NOT MATCH, = = = = and the
            # = = = =    NAME has SEVERAL candidates = = = = ⇒ the arm
            # = = = =    cannot say which one this is, = = = = and it
            # = = = =    says NOTHING (= = = = the arm is a gate, = = = =
            # = = = = and a gate that guesses is worse than a gate that
            # = = = =    is silent).
            base_members: dict[tuple[str, str, str], bool] = {}
            base_by_name: dict[str, dict[str, list[tuple[str, bool]]]] = {}
            for base_rel in {b for bs in counterparts.values() for b in bs}:
                text = base_tree.get(base_rel) or ""
                for owner, name, private, _number in scoped_members(text):
                    base_members[(base_rel, owner, name)] = private
                    base_by_name.setdefault(base_rel, {}).setdefault(
                        name, []
                    ).append((owner, private))
            # = = ⇒ THE FAMILY MAPS. = = = = The tip's files that came
            # = = = = from each base file, = = = = and the types each tip
            # = = = = file declares.
            tips_of_base: dict[str, list[str]] = {}
            for tip_rel, base_rels in counterparts.items():
                for base_rel in base_rels:
                    tips_of_base.setdefault(base_rel, []).append(tip_rel)
            tip_types: dict[str, set[str]] = {
                rel: set(_TYPE_DECL.findall(head_tree.get(rel) or ""))
                for rel in paths
            }
            widened = []
            for rel in paths:
                after = head_tree.get(rel)
                if after is None:
                    continue
                # = = ⇒ AND THE TIP SIDE READS THE SAME IDENTITY AS THE
                # = = = = BASE SIDE. = = = = The tip's member is (OWNING
                # = = = = TYPE, NAME), = = = = and so is the base's, = = = =
                # = = = = and the two are compared as one pair. = = = = ⇒
                # = = = = The tip side's own access level is read here
                # = = = = (= = the old regex admitted none, = = = = so a
                # = = = = `private` -> `public` widening was invisible).
                own_bases = counterparts.get(rel, [])
                for owner, name, private, number in scoped_members(after):
                    if private:
                        continue
                    # = = ⇒ AND THE PAIRING IS THE THREE RULES ABOVE.
                    candidates = [
                        (base_rel, candidate_owner, candidate_private)
                        for base_rel in own_bases
                        for candidate_owner, candidate_private
                        in base_by_name.get(base_rel, {}).get(name, [])
                    ]
                    exact = [c for c in candidates if c[1] == owner]
                    if exact:
                        matched = exact[0]
                    elif len(candidates) == 1 and not _owner_survives(
                        candidates[0][1], tips_of_base, tip_types
                    ):
                        # = = ⇒ THE TYPE WAS RENAMED, = = = = and the
                        # = = = = member is the same member.
                        matched = candidates[0]
                    else:
                        # = = ⇒ AMBIGUOUS, = = = = and the arm says NOTHING.
                        continue
                    if not matched[2]:
                        continue
                    lines = after.split("\n")
                    widened.append((rel, owner, name, lines[number - 1]))
            if not widened:
                return []
            for rel, owner, name, line in widened:
                target = work / rel
                text = target.read_text(encoding="utf-8")
                # = = ⇒ AND THE REWRITE TAKES THE SAME MODIFIER
                # = = = = VOCABULARY THE DETECTION TAKES, = = = = and it
                # = = = = swaps ONLY the access level. = = = = The old
                # = = = = rewrite matched `(var|let|func)` directly, = =
                # = = = = so a line that said `public func helper` (= = =
                # = = = the very shape a widening produces) = = = = did
                # = = = = NOT match, = = = = the file was unchanged, = = =
                # = = = = the build succeeded, = = = = = and the arm said
                # = = = = "no file needed it" (= = = = measured: = = = =
                # = = = = the verdict was the OPPOSITE of the truth). = =
                # = = = = ⇒ The modifier words stay, = = = = the access
                # = = = = level becomes `private`, = = = = and a member
                # = = = = that was already `private` is left alone.
                # = = ⇒ AND THE MODIFIER WORDS COME BACK OUT. = = The
                # = = = = detection's modifier vocabulary is NOT a capture
                # = = = = group, = = = = so a match CONSUMED them and never
                # = = = = re-emitted them: = = = = `public static func` became
                # = = = = `private func`, = = = = and the probe then built a
                # = = = = DIFFERENT PROGRAM than the one under review (= = =
                # = = = = measured on a real file: = = = = `private static
                # = = = = func blocks` lost its `static`). = = ⇒ So the
                # = = = = modifiers are captured in their OWN group, = = = =
                # = = = = and the rewrite re-emits them = = = = = and swaps
                # = = = = ONLY the access level.
                new_text = _rewrite_to_private(text, name, owner)
                target.write_text(new_text, encoding="utf-8")
                proc = subprocess.run(
                    ["swift", "build"], cwd=str(work), capture_output=True, text=True, timeout=1800
                )
                log = proc.stdout + proc.stderr
                # = = ⇒ AND THE COMPLAINT IS READ IN BOTH SHAPES. = = = =
                # = = = = Swift names the MEMBER when another file reads it
                # = = = = directly (= = = = `'engine' is inaccessible`), = = = =
                # = = = = and it names the TYPE when another file builds the
                # = = = = member through the SYNTHESIZED memberwise
                # = = = = initializer (= = = = `'Reader' initializer is
                # = = = = inaccessible due to 'private' protection level`).
                # = = = = The old test read only the first shape, = = = = and
                # = = = = the second one (= = = = the common one for a
                # = = = = stored property) = = = = read as "the probe could
                # = = = = not measure it" (= = = = measured: = = = = a member
                # = = = = that genuinely must stay cross-file was reported
                # = = = = as a finding).
                # = = ⇒ AND THERE IS A THIRD SHAPE, = = = = and it is a
                # = = = = PROPERTY WRAPPER'S PROJECTED VALUE. = = = = Swift
                # = = = = says `'$engine' is inaccessible due to 'private'
                # = = = = protection level`, = = = = and the `$` sits
                # = = = = BETWEEN the quote and the name (= = = = measured
                # = = = = with `swiftc -swift-version 6 -typecheck`). = = = =
                # = = = = ⇒ So the test reads the `$` as part of the name, = =
                # = = = = and it is the SAME member (= = = = the projected
                # = = = = value of the very property that was widened).
                # = = ⇒ AND THIS SHAPE IS REACHABLE ONLY BECAUSE THE BASE
                # = = = = SIDE READS `private` AFTER AN ATTRIBUTE (= = = = =
                # = = = = the old base-side scan placed the access level
                # = = = = BEFORE the attribute, = = = = = so it never saw
                # = = = = `@AppStorage(...) private var x` at all). = = = =
                # = = ⇒ So the repair that DETECTS the widening and the probe
                # = = = = that READS the compiler's answer are ONE repair, = =
                # = = = = and the third shape is part of it (= = = = measured
                # = = = = at `906079ac0d58`: = = = = the base's
                # = = = = `@AppStorage("wenshu.llm.reasoningEffort") private
                # = = = = var reasoningEffort` = = = = = and the tip drops the
                # = = = = `private`).
                complained = re.search(
                    rf"'\$?{re.escape(name)}' is inaccessible", log
                ) or (
                    bool(owner)
                    and re.search(
                        rf"'{re.escape(owner)}' initializer is inaccessible", log
                    )
                )
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
                # = = ⇒ AND THE FINDING NAMES THE OWNING TYPE. = = = =
                # = = = = Two types can hold the same member name, = = = =
                # = = = = and a finding that does not say which one is not
                # = = = = actionable.
                where = f"{owner}.{name}" if owner else name
                if proc.returncode != 0 and not complained:
                    findings.append(
                        f"{rel}: `{where}` was widened, = = and the build with it put "
                        f"back to `private` FAILED (= = so the probe could not "
                        f"measure it, = = and this is not a verdict)"
                    )
                    continue
                if not complained:
                    findings.append(
                        f"{rel}: `{where}` was widened, = = and putting it back to `private` still builds"
                        + (f" (= = so no file needed it)" if True else "")
                    )
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(work)], cwd=str(CHECK_REPO), capture_output=True)
    finally:
        shutil.rmtree(parent, ignore_errors=True)
    return findings



def registry_loc_mismatches(base: str, head: str, paths: list[str]) -> list[str]:
    """The registry rows this change ADDED, = = and whether they carry
    their file's own line count.

    = = ⇒ AND THE COUNT IS THE FILE'S, = = counted the way the registry
    # = = = = itself counts (= = `wc -l`, = = = = the newline-terminated
    # = = = = count). = = ⇒ A row that names a file the change added or
    # = = = = rewrote must carry THAT file's count, = = = = because the
    # = = = = registry's merge driver merges at the KEY level, = = = = and
    # = = = = a key's whole row text is its value (= = = = so one side's
    # = = = = wrong number is carried through silently).

    = = ⇒ MEASURED: = = the review of the export sheet's split found the
    # = = = = row carrying 192 while the file was 197, = = = = and the
    # = = = = tree's own `nfi-loc-check` caught it (= = = = and this arm
    # = = = = did not, = = = = because the arm set had no such check).
    """
    findings: list[str] = []
    # = = ⇒ AND THE BASE IS THE BASE, = = = = not "HEAD". = = = = "HEAD"
    # = = = = IS THE BRANCH UNDER TEST, = = = = so reading it here made
    # = = = = every row look old, = = = = and the check reported nothing
    # = = = = about a row that was wrong.
    # = = ⇒ AND A BASE WITH NO REGISTRY MEANS EVERY ROW IS NEW. = = = =
    # = = = = Returning nothing there made the arm silently blind on a
    # = = = = tree that did not have the registry yet (= = = = and on the
    # = = = = first change that adds it).
    base_text = _git_show(base, "docs/agents/nfi.md")
    if not base_text:
        base_keys: set[str] = set()
    else:
        base_keys = _registry_keys(base_text)
    try:
        head_text = _git_show(head, "docs/agents/nfi.md")
    except Exception:
        return findings
    head_rows = _registry_rows(head_text)
    for key, cells in head_rows:
        if key in base_keys:
            continue
        if not any(key.endswith(p) or p.endswith(key) for p in paths):
            continue
        loc_cell = next((c for c in cells[2:] if re.fullmatch(r"\d+", c)), None)
        if loc_cell is None:
            continue
        actual = _wc_lines(key, ref=head)
        if actual is None:
            continue
        if int(loc_cell) != actual:
            findings.append(
                f"the registry row for {key} says {loc_cell}, = = and the file is {actual}"
            )
    return findings


def _git_show(ref: str, path: str) -> str:
    """A file at a ref, = = read in the tree under test.

    = = ⇒ AND IT RUNS IN THAT TREE, = = = = because `git show` resolves
    # = = = = the ref against the CURRENT repository, = = = = and the
    # = = = = current repository is wherever the caller stood. = = = = On
    # = = = = a fixture in a temporary directory that is not the current
    # = = = = one, = = = = the read returned nothing, = = = = and the arm
    # = = = = that used it reported nothing about a row that was wrong.
    """
    out = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        cwd=str(CHECK_REPO),
        capture_output=True,
        text=True,
    )
    return out.stdout


def _registry_rows(text: str) -> list[tuple[str, list[str]]]:
    """The table's rows, = = each as (the key, the cells)."""
    rows = []
    for line in text.split("\n"):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        key = cells[1].strip("`")
        if key:
            rows.append((key, cells))
    return rows


def _registry_keys(text: str) -> set[str]:
    return {key for key, _ in _registry_rows(text)}


def _wc_lines(path: str, ref: str | None = None) -> int | None:
    """The file's own `wc -l` count (= = the registry's own convention).

    = = ⇒ AND THE PATH IS RESOLVED AGAINST THE TREE UNDER TEST, = = = =
    # = = = = not against the process's own directory. = = = = The tool
    # = = = = runs from wherever the caller stood, = = = = and a relative
    # = = = = key (= = "Sources/...") = = = = read against that directory
    # = = = = silently found nothing, = = = = and the check said "ok"
    # = = = = without having looked at anything.

    = = ⇒ AND THE COUNT COMES FROM THE COMMIT, = = = = not from the
    # = = = = working tree. = = = = The tree under test may already carry
    # = = = = a fix that the reviewed commit does not have, = = = = and a
    # = = = = check that reads the working tree measures the WRONG tree.
    """
    if ref:
        out = subprocess.run(
            ["git", "show", f"{ref}:{path}"],
            cwd=str(CHECK_REPO),
            capture_output=True,
            text=True,
        )
        if out.returncode == 0:
            return out.stdout.count("\n")
        return None
    full = Path(CHECK_REPO) / path
    try:
        with open(full, "rb") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return None

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

    print()
    print("=== 6. the registry rows this change added, = = and their own counts ===")
    reg = registry_loc_mismatches(args.base, args.head, paths)
    if reg:
        for f in reg:
            print(f"  ! {f}")
        failures.append(f"{len(reg)} registry row(s) carry a count their file does not have")
    else:
        print("  ok  every added row carries its file's own count")

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
