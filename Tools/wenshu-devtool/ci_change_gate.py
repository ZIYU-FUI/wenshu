#!/usr/bin/env python3
"""The CI's change gate: measure the CHANGE, not the history.

Two checks, both about the lines a change ADDS:

* ``pollution``: the added lines carry no forbidden vocabulary. The
  vocabulary and the path allowlist come from ``commit_filter.py``, which is
  the repository's own source for both (= this tool does not carry a second
  copy of either).
* ``formatting``: the added lines are not the ones SwiftFormat wants to
  change.

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
    """
    out = _git(["diff", "--name-only", "--diff-filter=d", f"{base}...HEAD"], cwd)
    return [line.strip() for line in out.splitlines() if line.strip()]


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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="The CI's change gate")
    parser.add_argument("--base", required=True, help="the commit the change is measured against")
    parser.add_argument(
        "--check",
        choices=["pollution", "formatting"],
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
