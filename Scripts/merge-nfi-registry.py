#!/usr/bin/env python3
"""merge-nfi-registry.py — a key-level merge driver for the NFI registry.

WHY THIS EXISTS

The nervous file index is a table with one row per extracted file. The
extracted file is the row's KEY (= the second column), and it is unique: 30
rows, 30 distinct keys.

Two cards that each add one row collided, because the table is append-only
(= a new row lands at the END), so both insertions wrote the same last line.
Measured: `git merge-tree` on two branches that each appended one row
returned CONFLICT.

`git merge=union` fixes that, but it has a hole: when two cards change the
SAME row to different values, union keeps BOTH versions as two rows with the
same key, silently. Measured on this registry: the merged file carried the
same extracted file twice, once with LOC 777 and once with LOC 888. That
breaks the registry's one-row-per-file invariant without reporting anything.

So the registry gets a driver that merges at the KEY level, the same shape as
the string catalog's driver:

  - a key only in one side        -> that side's row
  - a key in base, changed in one side only -> that side's row
  - a key in base, changed in BOTH sides to the SAME row -> that row
  - a key in base, changed in BOTH sides to DIFFERENT rows -> CONFLICT, and
    the driver NAMES the key
  - a key deleted on one side, changed on the other -> CONFLICT, named

The output preserves the base file's row order and appends the new keys, so a
row that only one card added lands at the end (= the append-only convention
the registry's own footer states).

THE OUTPUT

Byte-identical to the input when nothing changed: the file is read and
rewritten as text, with only the table's data rows replaced.

Usage (this is what git runs):

    merge-nfi-registry.py <base> <ours> <theirs>

git passes the three temp files and expects the merged result written back
into <ours>. Exit 0 = merged, exit 1 = conflict (the conflicted keys are
listed on stderr).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# A data row starts with the parent cell and carries the KEY (= the extracted
# file) in its SECOND cell. The parent cell can carry trailing prose after
# its backticked path (= "(`Sources/.../ImportService.swift` (now 444 LOC,
# under cap))"), so the row is recognised by its KEY cell, not by its first
# cell's shape.
ROW_RE = re.compile(r"^\|\s*`[^|]*`[^|]*\|\s*`([^`]+)`\s*\|")
KEY_RE = re.compile(r"^\|\s*`[^|]*`[^|]*\|\s*`([^`]+)`\s*\|")


def split_rows(text: str) -> tuple[list[str], list[str], list[str]]:
    """Split a registry file into (before, data rows, after).

    The header row and its separator are part of `before`, so the merged file
    keeps the table's shape even when every row changed.

    A blank line does NOT end the table: a card appends its row at the end
    of the table, and the file carries a blank line between the last row and
    the trailing comment. So the scan collects every row it finds and the
    table's tail is whatever follows the LAST row.
    """
    lines = text.split("\n")
    header_idx = None
    for i, line in enumerate(lines):
        if line.startswith("| Parent (god-class)"):
            header_idx = i
            break
    if header_idx is None:
        return ([], [], lines)

    rows: list[str] = []
    last_row_idx = header_idx + 1
    for i in range(header_idx + 2, len(lines)):
        if ROW_RE.match(lines[i]):
            rows.append(lines[i])
            last_row_idx = i
    return (lines[: header_idx + 2], rows, lines[last_row_idx + 1 :])


def key_of(row: str) -> str | None:
    m = KEY_RE.match(row)
    return m.group(1) if m else None


def merge_docs(base: str, ours: str, theirs: str) -> tuple[str, list[str]]:
    """Merge two registry files at the key level. Returns (merged, conflicted)."""
    _, base_rows, _ = split_rows(base)
    _, our_rows, _ = split_rows(ours)
    _, their_rows, _ = split_rows(theirs)

    base_by_key = {key_of(r): r for r in base_rows if key_of(r)}
    our_by_key = {key_of(r): r for r in our_rows if key_of(r)}
    their_by_key = {key_of(r): r for r in their_rows if key_of(r)}

    order: list[str] = []
    for row in base_rows + our_rows + their_rows:
        k = key_of(row)
        if k is not None and k not in order:
            order.append(k)

    merged_rows: list[str] = []
    conflicted: list[str] = []

    for key in order:
        b = base_by_key.get(key)
        o = our_by_key.get(key)
        t = their_by_key.get(key)

        if o is not None and t is not None:
            if o == t:
                merged_rows.append(o)
                continue
            if b is not None and o == b:
                merged_rows.append(t)
                continue
            if b is not None and t == b:
                merged_rows.append(o)
                continue
            # Both sides changed this key to different rows.
            conflicted.append(key)
            merged_rows.append(o)
            continue
        if o is not None:
            merged_rows.append(o)
            continue
        if t is not None:
            merged_rows.append(t)
            continue
        # Deleted on both sides: nothing to keep.
        continue

    before, _, after = split_rows(ours)
    if not before:
        before, _, after = split_rows(base)
    merged = "\n".join(before + merged_rows + after)
    return merged, conflicted


def main() -> int:
    if len(sys.argv) != 4:
        sys.stderr.write("usage: merge-nfi-registry.py <base> <ours> <theirs>\n")
        return 2

    base, ours_path, theirs_path = sys.argv[1], sys.argv[2], sys.argv[3]

    def read(path: str) -> str:
        p = Path(path)
        return p.read_text(encoding="utf-8") if p.exists() else ""

    merged, conflicted = merge_docs(read(base), read(ours_path), read(theirs_path))
    Path(ours_path).write_text(merged, encoding="utf-8")

    if conflicted:
        sys.stderr.write("merge-nfi-registry: conflicted keys:\n")
        for key in conflicted:
            sys.stderr.write(f"  {key}\n")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
