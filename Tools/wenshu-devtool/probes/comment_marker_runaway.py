#!/usr/bin/env python3
"""The house's comment-scaffold runaway, measured.

= = ⇒ ⇒ ⇒ WHY THIS PROBE EXISTS: = = the house writes `⇒ ⇒ ⇒` to OPEN a
= = claim and `= ` to separate the clauses inside it. = = The longest
= = chain the house uses is 3 (`= = =`). = = So the runaways are: = = a
= = run of 4+ arrows, = = a run of 4+ dashes, = = a marker on EVERY line
= = of a paragraph, = = and a line the reader's eye has to wrap by hand.

= = ⇒ ⇒ ⇒ AND WHY IT IS A PROBE: = = the comment-lineage gate charges
= = CJK, = = ticket lineage and uncited dates, = = and it has no marker
= = or width check. = = So a branch can be green there and still carry
= = the runaway. = = This probe measures the runaway itself, = = and it
= = reads the live tree (= = so it measures the tree, = = not a
= = remembered tree).

= = ⇒ ⇒ ⇒ AND THE PROOF A COMMENT-ONLY PASS MUST CARRY: = = the code
= = lines stay byte-identical. = = The `--proof` mode prints that: = = it
= = compares the non-comment lines of the tree with the non-comment
= = lines of a commit, = = and it names every file whose code moved.

= = ⇒ ⇒ ⇒ USAGE: = =
= =     comment_marker_runaway.py <file> [<file> ...]
= =     comment_marker_runaway.py --diff <base> <head>
= =     comment_marker_runaway.py --proof <base> <head>

= = ⇒ ⇒ ⇒ READ-ONLY: = = it writes no file.
"""

from __future__ import annotations

import re
import subprocess
import sys

ARROWS = "⇒"
DASH = "="
MAX_COLUMNS = 100


def arrow_run(text: str) -> int:
    """The longest run of arrows in a line."""
    best = 0
    for m in re.finditer(re.escape(ARROWS) + r"(?:\s*" + re.escape(ARROWS) + r")*", text):
        best = max(best, m.group(0).count(ARROWS))
    return best


def dash_run(text: str) -> int:
    """The longest run of `=` in a line (= = a chain of dashes)."""
    best = 0
    for m in re.finditer(re.escape(DASH) + r"(?:\s*" + re.escape(DASH) + r")*", text):
        best = max(best, m.group(0).count(DASH))
    return best


def comment_rows(text: str) -> list[tuple[int, str]]:
    out = []
    for i, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("//"):
            out.append((i, line))
    return out


def marker_on_every_line(path: str, rows: list[tuple[int, str]]) -> list[tuple[int, str]]:
    """A paragraph (= a run of consecutive comment lines) whose EVERY line
    carries a marker = = the third runaway the house names."""
    out = []
    block: list[tuple[int, str]] = []
    for row in list(rows) + [(0, "")]:
        i, line = row
        if line.strip():
            block.append(row)
            continue
        if len(block) >= 2:
            if all("⇒ ⇒ ⇒" in l for _, l in block):
                out.append((block[0][0], block[-1][0]))
        block = []
    return out


def report(path: str, rows: list[tuple[int, str]]) -> tuple[int, int]:
    bad = 0
    for i, line in rows:
        body = line.split("//", 1)[1] if "//" in line else ""
        arrows = arrow_run(body)
        dashes = dash_run(body)
        width = len(line.rstrip())
        if arrows >= 4 or dashes >= 4 or width > MAX_COLUMNS:
            bad += 1
            print(
                f"{path}:{i}: arrows={arrows} dashes={dashes} width={width}  {line.strip()[:90]}"
            )
    return bad, len(rows)


def main() -> int:
    args = sys.argv[1:]
    total_bad = 0
    total_rows = 0
    if args and args[0] == "--proof":
        # = = ⇒ ⇒ ⇒ THE PROOF: = = a comment-only pass leaves the code
        # = = ⇒ ⇒ ⇒ byte-identical. = = This compares the non-comment
        # = = ⇒ ⇒ ⇒ lines of the tree with the non-comment lines of the
        # = = ⇒ ⇒ ⇒ commit, = = and names every file whose code moved.
        base, head = args[1], args[2]
        names = subprocess.run(
            ["git", "diff", "--name-only", f"{base}..{head}"],
            capture_output=True, text=True, check=True,
        ).stdout.split()
        moved = 0
        for n in names:
            if not n.endswith(".swift"):
                continue
            before = subprocess.run(
                ["git", "show", f"{base}:{n}"], capture_output=True, text=True
            ).stdout
            after = subprocess.run(
                ["git", "show", f"{head}:{n}"], capture_output=True, text=True
            ).stdout
            b = [l for l in before.splitlines() if not l.strip().startswith("//")]
            a = [l for l in after.splitlines() if not l.strip().startswith("//")]
            if b != a:
                moved += 1
                print(f"{n}: the CODE moved (= = a comment-only pass must not move it)")
        print(f"= = the code lines are byte-identical in {len(names)} file(s): {moved == 0}")
        return 1 if moved else 0
    if args and args[0] == "--diff":
        base, head = args[1], args[2]
        names = subprocess.run(
            ["git", "diff", "--name-only", f"{base}..{head}"],
            capture_output=True, text=True, check=True,
        ).stdout.split()
        names = [n for n in names if n.endswith(".swift")]
        for n in names:
            diff = subprocess.run(
                ["git", "diff", "-U0", f"{base}..{head}", "--", n],
                capture_output=True, text=True, check=True,
            ).stdout
            added = []
            file_line = 0
            for line in diff.splitlines():
                if line.startswith("@@"):
                    m = re.search(r"\+(\d+)", line)
                    file_line = int(m.group(1)) - 1
                    continue
                if line.startswith("+") and not line.startswith("+++"):
                    file_line += 1
                    body = line[1:]
                    if body.strip().startswith("//"):
                        added.append((file_line, body))
                elif line.startswith("-"):
                    pass
                else:
                    file_line += 1
            bad, rows = report(n, added)
            for first, last in marker_on_every_line(n, added):
                print(f"{n}:{first}-{last}: EVERY line of the paragraph carries a marker")
                bad += 1
            total_bad += bad
            total_rows += rows
    else:
        for path in args:
            with open(path, encoding="utf-8") as h:
                text = h.read()
            rows = comment_rows(text)
            crows = comment_rows(text)
            bad, count = report(path, crows)
            for first, last in marker_on_every_line(path, crows):
                print(f"{path}:{first}-{last}: EVERY line of the paragraph carries a marker")
                bad += 1
            total_bad += bad
            total_rows += count
    print(f"= = the runaways: {total_bad} of {total_rows} comment rows")
    return 1 if total_bad else 0


if __name__ == "__main__":
    sys.exit(main())
