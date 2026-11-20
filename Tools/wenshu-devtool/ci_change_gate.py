#!/usr/bin/env python3
"""The CI's change gate: measure the CHANGE, not the history.

Four checks, two about the lines a change ADDS and two about the bytes
a change leaves behind:

* ``pollution``: the added lines carry no forbidden vocabulary. The
  vocabulary and the path allowlist come from ``commit_filter.py``, which is
  the repository's own source for both (= this tool does not carry a second
  copy of either).
* ``formatting``: the added lines are not the ones SwiftFormat wants to
  change.
* ``markdown-newline``: the change does not DROP a changed ``.md`` file's
  trailing newline. = = The byte is unguarded elsewhere, = = and it is not
  cosmetic: = = ``docs/agents/nfi.md`` carries the house's key-level merge
  driver, = = whose ``split_rows()`` puts everything after the last table
  row into a TAIL, = = and ``text.split("\n")`` on a newline-terminated
  file leaves a final empty string while a file without the newline does
  not (= = so the tail differs).
  = = **HOW THE DRIVER TREATS THAT DIFFERENCE CHANGED ON 2026-11-20**: = = the
  tail is now merged THREE WAYS against the base (= = one side changed ⇒ = =
  that side's tail wins outright; = = both sides changed differently ⇒ = = a
  CONFLICT named ``<the file's tail>``), = = so a side that DROPS the
  trailing newline no longer trips a conflict against the sibling that kept
  it: = = the newline-less side's tail simply wins, = = and the merge says
  nothing about the dropped byte. = = ⇒ ⇒ **⇒ ⇒ AND THIS CHECK IS NOW THE
  ONLY GUARD FOR THAT BYTE** (= = the driver's conflict is no longer the
  backstop). = = HISTORY (= = 2026-11-17, = = twice, = = under the driver of
  that day): = = a scope that dropped the byte cost a review round to find,
  = = and the same byte used to break the merge driver against a sibling
  card's registry row (= = that failure mode is what this check's history
  records; = = the driver's rule is what changed).
  = = ⇒ AND IT IS A DELTA CHECK, = = NOT A STATE CHECK: = = it compares
  the file's blob at the MERGE-BASE with its blob at HEAD, = = and it
  reports only what THIS change did (= = a file that already lacked the
  byte is the tree's drift, = = and it is not this change's business = =
  the same rule the other two checks follow). = = MEASURED: = = a state
  check went RED on 13 of main's last 300 COMMITS, = = and 11 of those 13
  were FALSE (= = the commit never touched the byte).

* ``loc-cap``: the change leaves no ``.swift`` file over the 600-LOC cap
  (AGENTS.md 6.6). = = The cap covers EVERY ``.swift`` file in this
  repository (= = ``Vendor/`` alone is exempt, = = and ``changed_paths``
  already drops it), = = so the top-level ``Tests/`` tree and the probes
  under ``Tools/`` are inside it too: = = the rule's own text never exempted
  them, = = and until this check existed nothing measured them (= = measured
  2026-11-21 on main: 8 files under ``Tests/`` and 1 probe are over the cap,
  = = the largest 1372 LOC, = = and the newest of them was added by a card
  whose run went green). = = ⇒ ⇒ **⇒ IT IS A RATCHET, = = NOT A STATE CHECK**
  (= = the delta rule the other three follow): = = a change that makes an
  over-cap file SMALLER is the split in progress and lands, = = while a
  change that leaves it the same size or grows it is charged.
  = = MEASURED (the replay drives THIS tool's own functions over main's
  last 300 COMMITS in a --shared clone): = = 81 of the 300 touched a
  ``.swift`` file, = = the RATCHET goes RED on 17 (= = 61 green, = = 3
  excused for shrinking), = = and both additions to the blind spot are
  among the 17 (= = ``31b5c3929a`` added a 1092-line test file and grew
  ``LabelSegmentedControl`` to 670, = = ``9776b4dc7c`` added the 635-line
  probe). = = A STATE check would red 20, = = and its 3 extra are EXACTLY
  the three splits in progress (= = ``124ce32757``, = = ``9639ff9d60``,
  ``de3f287f4d``) = = so a state check would have punished the only commits
  that were fixing the file.

WHY THIS EXISTS. The CI used to run ``git log --all -p | grep <vocabulary>``
for the pollution check (= 4788 hits on the repository's own history, = the
step could never be green) and ``swiftformat --lint`` on every file a change
touched for the formatting check (= the tree carries 1033 files that were
never formatted, = 529 of 537 under Tests/, = so the step was red before any
change and could never be green either). Both steps reported the history
instead of the change, which is the opposite of what their own comments say
they are for. These two checks measure the change.

USAGE::

    python3 Tools/wenshu-devtool/ci_change_gate.py --base <sha> --check pollution
    python3 Tools/wenshu-devtool/ci_change_gate.py --base <sha> --check formatting
    python3 Tools/wenshu-devtool/ci_change_gate.py --base <sha> --check markdown-newline
    python3 Tools/wenshu-devtool/ci_change_gate.py --base <sha> --check loc-cap

``--base`` is the commit the change is measured against (= the CI resolves
it per trigger, because ``origin/main`` is the wrong base for a push to
``main``). The exit status is 0 when the change is clean and 1 when it is
not, and every offender is printed with its file and line.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from commit_filter import PATTERN, is_allowed  # noqa: E402  (= the vocabulary SSOT)

# The hunk header of a unified diff: "@@ -old_start,old_count +new_start,new_count @@"
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(?P<start>\d+)(?:,(?P<count>\d+))? @@")

# A SwiftFormat violation line: "path:line:col: error: (ruleName) message"
VIOLATION = re.compile(
    r"^(?P<path>.+?):(?P<line>\d+):(?P<col>\d+):\s*error:\s*\((?P<rule>[^)]*)\)\s*(?P<message>.*)$"
)

SWIFT_SUFFIX = ".swift"
MD_SUFFIX = ".md"

#: The file-size cap of AGENTS.md 6.6, = in lines. = The count is the cap
#: tool's own convention (= ``len(text.splitlines())``, = the way
#: ``Tools/wenshu-devtool/inventory-measure.py`` sizes a file), = NOT the
#: registry's ``wc -l`` column: = for a file that does not end with a
#: newline the two differ by one, = and the question this check answers is
#: the cap's.
LOC_CAP = 600


def parse_diff(diff_text: str) -> tuple[dict[str, list[tuple[int, int]]], dict[str, dict[int, str]]]:
    """Read a unified diff into the lines it adds.

    Returns ``(ranges, lines)`` where ``ranges`` maps a path to the
    ``(first, last)`` line numbers of every block the diff adds (= in the
    NEW file's numbering, = the numbering SwiftFormat reports), and ``lines``
    maps a path to the added line's number and its content.

    A deleted line is not an added line: a change that REMOVES a violation
    adds nothing, and a change that rewrites a file adds the rewritten lines
    (= which are the lines it is responsible for).
    """
    ranges: dict[str, list[tuple[int, int]]] = {}
    lines: dict[str, dict[int, str]] = {}
    path: str | None = None
    new_line = 0
    for raw in diff_text.splitlines():
        if raw.startswith("+++ "):
            target = raw[4:].strip()
            if target == "/dev/null":
                path = None
            else:
                path = target[2:] if target.startswith("b/") else target
            continue
        if raw.startswith("--- ") or raw.startswith("diff --git "):
            continue
        header = HUNK.match(raw)
        if header:
            start = int(header.group("start"))
            count = int(header.group("count") or 1)
            new_line = start
            if count > 0 and path:
                ranges.setdefault(path, []).append((start, start + count - 1))
            continue
        if path is None:
            continue
        if raw.startswith("+"):
            lines.setdefault(path, {})[new_line] = raw[1:]
            new_line += 1
        elif raw.startswith("-"):
            continue
        elif raw.startswith(" "):
            new_line += 1
    return ranges, lines


def pollution_offenders(
    added_lines: dict[str, dict[int, str]],
    pattern: re.Pattern[str] = PATTERN,
    allowed=is_allowed,
) -> list[tuple[str, int, str, str]]:
    """The added lines that carry forbidden vocabulary.

    A path on the allowlist is skipped (= it legitimately enumerates the
    vocabulary: the rule documents, the templates, the pollution fixtures).
    """
    offenders: list[tuple[str, int, str, str]] = []
    for path, numbered in sorted(added_lines.items()):
        if allowed(path):
            continue
        for line_no, content in sorted(numbered.items()):
            match = pattern.search(content)
            if match:
                offenders.append((path, line_no, match.group(0), content.strip()[:80]))
    return offenders


def relativize(path: str, root: Path | None) -> str:
    """Bring a path to the repository-relative form the diff uses.

    SwiftFormat reports an ABSOLUTE path even when it is given a relative
    one (= it resolves the file before it prints it), and the diff carries
    repository-relative paths. Without this, the two never meet and the gate
    reports nothing (= a false green: measured on 2026-11-02, the first
    version of this gate passed a change that added an unformatted line).
    """
    if root is None:
        return path
    try:
        return str(Path(path).resolve().relative_to(root.resolve()))
    except ValueError:
        return path


def format_violations(
    swiftformat_output: str, root: Path | None = None
) -> list[tuple[str, int, str, str]]:
    """Read SwiftFormat's report into ``(path, line, rule, message)``."""
    violations: list[tuple[str, int, str, str]] = []
    for raw in swiftformat_output.splitlines():
        match = VIOLATION.match(raw.strip())
        if match:
            violations.append(
                (
                    relativize(match.group("path"), root),
                    int(match.group("line")),
                    match.group("rule"),
                    match.group("message").strip(),
                )
            )
    return violations


def format_offenders(
    violations: list[tuple[str, int, str, str]],
    ranges: dict[str, list[tuple[int, int]]],
) -> list[tuple[str, int, str, str]]:
    """The violations that fall on a line the change added.

    A violation on a line the change did not touch is the tree's own drift
    and belongs to the tree (= not to this change).
    """
    offenders: list[tuple[str, int, str, str]] = []
    for path, line, rule, message in violations:
        for first, last in ranges.get(path, []):
            if first <= line <= last:
                offenders.append((path, line, rule, message))
                break
    return offenders


#: The vendored tree's prefix. = The files under it are upstream's own
#: code (= byte for byte), = so this repository's formatting gate does
#: not reach them.
VENDORED_PREFIX = "Vendor/"


def _git(args: list[str], cwd: Path) -> str:
    result = subprocess.run(
        ["git", *args], cwd=str(cwd), capture_output=True, text=True, check=True
    )
    return result.stdout


def changed_paths(base: str, cwd: Path) -> list[str]:
    """The paths this change touches, WITHOUT the deleted ones.

    A deleted path must not reach SwiftFormat: ``swiftformat --lint`` aborts
    the whole run on the first missing file (= "error: File not found at
    ...", exit 70) and reports NOTHING for the files that do exist, so the
    deleted path swallows the entire report (= a false green: measured
    2026-11-02, a change that deleted one Swift file and added an unformatted
    line to another passed this gate). The diff filter is what keeps the
    deleted path out of the list.

    The VENDORED tree is exempt too: = it is upstream's own code, = byte
    for byte (= so the vendoring card can hold "the tree IS upstream's
    code"), = and upstream's own files are not this repository's
    formatting (= measured 2026-11-07: 134 of the 141 vendored files
    fail ``swiftformat --lint`` on the pristine upstream checkout too).
    = Linting them would ask the change to rewrite upstream's bytes,
    = which is the opposite of what vendoring is for. = The 600-LOC cap
    exempts the same tree for the same reason (= AGENTS.md 6.6).
    """
    out = _git(["diff", "--name-only", "--diff-filter=d", f"{base}...HEAD"], cwd)
    return [
        line.strip()
        for line in out.splitlines()
        if line.strip() and not line.strip().startswith(VENDORED_PREFIX)
    ]


def swiftformat_args(paths: list[str], cwd: Path) -> list[str]:
    """The SwiftFormat command for a lint run.

    The repository's own ``.swift-format`` is NOT passed, for two separate
    reasons, both measured 2026-11-02:

    1. SwiftFormat discovers its configuration under the name
       ``.swiftformat`` (no dash). The repository's file is named
       ``.swift-format`` (with a dash), so SwiftFormat never reads it: a
       lint run in this repository does not print "Reading config file" at
       all. The two names are not interchangeable.
    2. Even under the name SwiftFormat does read, the file's CONTENT would
       be rejected: it is in the ``swift-format`` JSON dialect, the file
       starts with a brace, and SwiftFormat 0.62.1 answers "error: Unknown
       option '{' in configuration file", exits 70, and reports NO
       violation. Nine of the rule names it lists do not exist in this
       SwiftFormat version at all (= only ``RedundantReturn`` and
       ``TrailingCommas`` do). A rejected config makes SwiftFormat report
       nothing, so passing it would make this gate silently green (= the
       very failure this gate exists to remove).

    So the lint runs with SwiftFormat's DEFAULT rules, and the
    configuration file's own repair (= its name AND its dialect) is its own
    card.
    """
    return ["swiftformat", "--lint", *paths]


class SwiftFormatFailure(RuntimeError):
    """SwiftFormat refused to lint (= exit 70): the report is not trustworthy.

    SwiftFormat exits 70 when it cannot do the work at all: a missing file,
    a configuration file it rejects, a syntax error in a file it was asked to
    lint. In every one of those cases it reports NO violation, so treating
    "no violation parsed" as clean makes the gate silently green on the very
    drift it exists to catch. A run that could not be completed must be
    loud, not clean.
    """

    def __init__(self, exit_code: int, output: str) -> None:
        self.exit_code = exit_code
        self.output = output
        super().__init__(f"swiftformat exited {exit_code}")


def swiftformat_report(paths: list[str], cwd: Path) -> str:
    """SwiftFormat's report for the given files (= lint only, no rewrite).

    Raises :class:`SwiftFormatFailure` when SwiftFormat could not complete the
    run (= a non-zero exit that is not the "violations found" exit). The
    caller must treat that as a failure, never as a clean file.
    """
    if not paths:
        return ""
    result = subprocess.run(
        swiftformat_args(paths, cwd),
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )
    output = (result.stdout or "") + (result.stderr or "")
    # SwiftFormat exits 0 = clean, 1 = violations found, 70 = could not run.
    if result.returncode not in (0, 1):
        raise SwiftFormatFailure(result.returncode, output)
    return output


def _blob_bytes(rev: str, path: str, cwd: Path) -> bytes | None:
    """A file's bytes at a revision (= = None when the path is not there).

    The bytes come from the git OBJECT, = = not from the working tree:
    this gate measures a COMMIT, = = and a working tree that differs from
    the commit (= = a staged fix, = = an unstaged edit) would otherwise
    make the gate read a tree the commit does not have.
    """
    result = subprocess.run(
        ["git", "cat-file", "blob", f"{rev}:{path}"],
        cwd=str(cwd),
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def _rename_sources(base: str, cwd: Path) -> dict[str, str]:
    """The changed paths that are RENAMES (= = the new path -> the old path).

    = = A rename is why the merge-base blob can be ABSENT for a path that
    is not new: = = the content moved, = = so the byte it carries is the
    SOURCE's byte (= = and a rename drops nothing).
    """
    output = _git(["diff", "--find-renames", "--name-status", f"{base}...HEAD"], cwd)
    sources: dict[str, str] = {}
    for line in output.splitlines():
        parts = line.split("\t")
        if len(parts) == 3 and parts[0].startswith("R"):
            sources[parts[2]] = parts[1]
    return sources


def markdown_newline_offenders(
    base: str, paths: list[str], cwd: Path
) -> list[tuple[str, str]]:
    """The changed ``.md`` files THAT THIS CHANGE dropped the newline from.

    Returns ``(path, reason)`` pairs, = = and the reason says what
    happened (= = the change removed the byte, = = or the file is new and
    never had one). = = The comparison is the DELTA (= = the blob at the
    merge-base against the blob at HEAD), = = so a file that already
    lacked the byte is the tree's drift and is NOT this change's = = the
    rule the other two checks in this gate follow (= = "measure the
    CHANGE, = = not the history").

    = = MEASURED (= = the review that asked for it): = = over main's last
    300 COMMITS, = = a state check (= = "does the file on disk end with a
    newline?") goes RED on 13, = = and 11 of those 13 are FALSE (= = the
    commit never touched the byte, = = and the tree already has 28 files
    without it). = = ⇒ The delta rule goes RED on 2, = = and those 2 are
    the real defect (= = the two commits that dropped the byte from the
    two registries). = = ⇒ AND OVER THE LAST 300 ``.md``-TOUCHING COMMITS
    (= = a different, = = larger window): = = DELTA REDs 3 (= = all three
    genuine drops) = = and STATE REDs 20 (= = 17 of them false).
    """
    merge_base = _git(["merge-base", base, "HEAD"], cwd).strip()
    renames = _rename_sources(base, cwd)
    offenders: list[tuple[str, str]] = []
    for path in paths:
        if not path.endswith(MD_SUFFIX):
            continue
        after = _blob_bytes("HEAD", path, cwd)
        if after is None:
            # The file is not at HEAD (= = the change deleted it) = = and a
            # deleted file cannot have dropped a byte.
            continue
        if not after or after.endswith(b"\n"):
            # It ends with the byte (= = or it is empty = = and there is
            # nothing to drop).
            continue
        source = renames.get(path)
        if source is not None:
            # = = A RENAME: = = the content moved, = = so the byte the file
            # carries is the SOURCE's byte. = = ⇒ A rename drops nothing,
            # and a source that already lacked the byte moved its drift
            # with the file (= = the tree's drift, = = not this change's).
            before = _blob_bytes(merge_base, source, cwd)
            if before is None or not before.endswith(b"\n"):
                continue
            offenders.append(
                (path, "the change DROPPED the trailing newline (= = the byte the merge driver compares)")
            )
            continue
        before = _blob_bytes(merge_base, path, cwd)
        if before is None:
            offenders.append(
                (path, "the NEW .md does not end with a newline (= = the byte the merge driver compares)")
            )
        elif before.endswith(b"\n"):
            offenders.append(
                (path, "the change DROPPED the trailing newline (= = the byte the merge driver compares)")
            )
        # = = ELSE the file already lacked the byte (= = the tree's own
        # drift) = = and this change did not drop it = = so it is not this
        # change's business.
    return offenders


def swift_loc(rev: str, path: str, cwd: Path) -> int | None:
    """A blob's size in lines, = or None when there is no blob at ``rev``.

    None is NOT zero: = a path absent at the merge-base is NEW in this
    change, = and a path absent at HEAD could not be measured at all (= and
    a measurement that did not happen is never reported as a clean one).
    """
    data = _blob_bytes(rev, path, cwd)
    if data is None:
        return None
    return len(data.decode("utf-8", errors="replace").splitlines())


def loc_cap_offenders(
    base: str, paths: list[str], cwd: Path
) -> tuple[list[tuple[str, int, int | None]], list[tuple[str, int, int]], list[str]]:
    """The changed Swift files this change leaves over the ``LOC_CAP`` cap.

    Returns ``(offenders, shrinking, unmeasurable)``:

    * ``offenders`` = ``(path, head_loc, base_loc)``, = and ``base_loc`` is
      None for a file that is NEW in this change (= = so the report can say
      which of the two it is).
    * ``shrinking`` = ``(path, base_loc, head_loc)`` for the over-cap files
      the ratchet lets through, = printed so the report says what it excused
      instead of passing silently.
    * ``unmeasurable`` = the paths with no blob at HEAD. = The caller fails
      on these: = a file the gate could not read is not a file the gate
      found clean.

    The comparison is the DELTA (= = the blob at the merge-base against the
    blob at HEAD, = = the rule every other check in this gate follows), = =
    and a RENAME is charged to its source: = = a split that renames the
    parent keeps the parent's own base size, = = so moving an over-cap file
    is not "a new file over the cap".
    """
    merge_base = _git(["merge-base", base, "HEAD"], cwd).strip()
    renames = _rename_sources(base, cwd)
    offenders: list[tuple[str, int, int | None]] = []
    shrinking: list[tuple[str, int, int]] = []
    unmeasurable: list[str] = []
    for path in paths:
        head_loc = swift_loc("HEAD", path, cwd)
        if head_loc is None:
            unmeasurable.append(path)
            continue
        if head_loc <= LOC_CAP:
            continue
        source = renames.get(path)
        base_loc = swift_loc(merge_base, source if source is not None else path, cwd)
        if base_loc is not None and head_loc < base_loc:
            shrinking.append((path, base_loc, head_loc))
            continue
        offenders.append((path, head_loc, base_loc))
    return offenders, shrinking, unmeasurable


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="The CI's change gate")
    parser.add_argument("--base", required=True, help="the commit the change is measured against")
    parser.add_argument(
        "--check",
        choices=["pollution", "formatting", "markdown-newline", "loc-cap"],
        required=True,
        help="which check to run",
    )
    parser.add_argument("--repo", default=None, help="the repository root (= the cwd)")
    args = parser.parse_args(argv if argv is not None else sys.argv[1:])

    cwd = Path(args.repo).resolve() if args.repo else Path.cwd()
    diff_text = _git(["diff", "--unified=0", f"{args.base}...HEAD"], cwd)
    ranges, added_lines = parse_diff(diff_text)

    if args.check == "pollution":
        offenders = pollution_offenders(added_lines)
        if not offenders:
            print(f"pollution: the change adds no forbidden vocabulary ({args.base}...HEAD)")
            return 0
        print(f"pollution: {len(offenders)} forbidden vocabulary line(s) in this change")
        for path, line, token, context in offenders:
            print(f"  {path}:{line}: forbidden vocabulary '{token}' | {context}")
        return 1

    if args.check == "markdown-newline":
        md_paths = [p for p in changed_paths(args.base, cwd) if p.endswith(MD_SUFFIX)]
        offenders = markdown_newline_offenders(args.base, md_paths, cwd)
        if not offenders:
            print(
                f"markdown-newline: the change drops no .md's trailing newline "
                f"({len(md_paths)} changed .md file(s) checked)"
            )
            return 0
        print(
            f"markdown-newline: {len(offenders)} changed .md file(s) lost their trailing newline"
        )
        for path, reason in offenders:
            print(f"  {path}: {reason}")
        return 1

    if args.check == "loc-cap":
        cap_paths = [p for p in changed_paths(args.base, cwd) if p.endswith(SWIFT_SUFFIX)]
        offenders, shrinking, unmeasurable = loc_cap_offenders(args.base, cap_paths, cwd)
        if unmeasurable:
            # A file this gate could not read is NOT a file it found clean.
            print(
                f"loc-cap: {len(unmeasurable)} changed Swift file(s) could not be measured, "
                f"so the cap is not settled for this change"
            )
            for path in unmeasurable:
                print(f"  {path}: no blob at HEAD; the measurement did not happen")
            return 1
        if not offenders:
            print(
                f"loc-cap: every changed Swift file is within the {LOC_CAP}-LOC cap "
                f"({len(cap_paths)} file(s) checked"
                + (f", {len(shrinking)} over the cap but shrinking" if shrinking else "")
                + ")"
            )
            for path, base_loc, head_loc in shrinking:
                print(
                    f"  {path}: {base_loc} -> {head_loc} LOC (= still over the cap; "
                    f"the change shrank it, = so the ratchet lets it land)"
                )
            return 0
        print(
            f"loc-cap: {len(offenders)} changed Swift file(s) over the {LOC_CAP}-LOC cap "
            f"(AGENTS.md 6.6)"
        )
        for path, head_loc, base_loc in offenders:
            origin = "NEW in this change" if base_loc is None else f"was {base_loc}"
            print(
                f"  {path}: {head_loc} LOC (= {origin}); split it by CONCERN "
                f"(= one subject per file), = never by a line count"
            )
        return 1

    swift_paths = [p for p in changed_paths(args.base, cwd) if p.endswith(SWIFT_SUFFIX)]
    try:
        report = swiftformat_report(swift_paths, cwd)
    except SwiftFormatFailure as exc:
        # A run that could not be completed is NOT a clean file. Reporting it
        # as clean is exactly the false green this gate exists to remove.
        print(
            f"formatting: swiftformat could not lint the change "
            f"(exit {exc.exit_code}); the report is not trustworthy"
        )
        for line in exc.output.splitlines():
            if line.strip():
                print(f"  {line.strip()}")
        return 1
    violations = format_violations(report, cwd)
    offenders = format_offenders(violations, ranges)
    if not offenders:
        print(
            f"formatting: the change adds no unformatted line "
            f"({len(swift_paths)} changed Swift file(s) checked)"
        )
        return 0
    print(f"formatting: {len(offenders)} unformatted line(s) added by this change")
    for path, line, rule, message in offenders:
        print(f"  {path}:{line}: ({rule}) {message}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
