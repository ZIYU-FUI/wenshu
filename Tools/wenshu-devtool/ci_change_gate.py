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
touched for the formatting check (= the tree carries 1032 files that were
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
import os
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
CONFIG_NAME = ".swift-format"


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
    out = _git(["diff", "--name-only", f"{base}...HEAD"], cwd)
    return [line.strip() for line in out.splitlines() if line.strip()]


def swiftformat_args(paths: list[str], cwd: Path) -> list[str]:
    """The SwiftFormat command for a lint run.

    The repository's own ``.swift-format`` is NOT passed, because SwiftFormat
    rejects it: measured 2026-11-02, the file starts with a brace and
    SwiftFormat answers "Unknown option '{' in configuration file", and nine
    of the rule names it lists do not exist in this SwiftFormat version at
    all (= only ``RedundantReturn`` and ``TrailingCommas`` do). A rejected
    config makes SwiftFormat report nothing, so passing it would make this
    gate silently green (= the very failure this gate exists to remove).
    The configuration file's own repair is its own card.
    """
    return ["swiftformat", "--lint", *paths]


def swiftformat_report(paths: list[str], cwd: Path) -> str:
    """SwiftFormat's report for the given files (= lint only, no rewrite)."""
    if not paths:
        return ""
    result = subprocess.run(
        swiftformat_args(paths, cwd),
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )
    return (result.stdout or "") + (result.stderr or "")


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
    report = swiftformat_report(swift_paths, cwd)
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
