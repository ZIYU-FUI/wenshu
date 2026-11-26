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

  - a key only in one side        -> THREE WAYS against base, like the header
    and the tail below (= this is what `f1646a0c43` changed; the rule used to
    be "that side's row", which silently RESURRECTED a deleted row whenever
    the other side merely had not touched it):
      * never in base             -> that side ADDED it: keep that row
      * in base, unchanged there  -> the other side DELETED it: the deletion
                                     wins, the row does not come back
      * in base, edited there     -> deleted on one side, changed on the
                                     other: CONFLICT, and the key is named
  - a key in base, changed in one side only -> that side's row
  - a key in base, changed in BOTH sides to the SAME row -> that row
  - a key in base, changed in BOTH sides to DIFFERENT rows -> CONFLICT, and
    the driver NAMES the key

The deletion rule is the one an unedited side cannot see coming, so it is
pinned by a COUNT of driver invocations, not by its output: cases 18-20 of
`Tools/wenshu-devtool/tests/test_nfi_registry.sh` run the driver through a
wrapper that appends one line per invocation and assert `driver_ran >= 1` on
the merge that must reach it and `== 0` on the shape that must not (= one
side never touched the file, so ort takes the other side's blob and no driver
is consulted). An arm that prints `driver_ran: 0` and exits 0 measures the
tip, not the driver.

One numbering note, because `f1646a0c43`'s commit message calls this the
"fourth rule" and the file then carried it as the FIFTH bullet (= below the
two-sided disagreement, at `:29`). Both counts were wrong about the file the
commit shipped. The rule now lives inside the FIRST bullet as three named
outcomes, so no ordinal points at it: cite the shape — a one-sided key, three
ways against base — and not a position in this list, which has moved twice.

THE FILE'S HEADER

The registry is a table PLUS a header: everything above the table (= the LOC
convention prose). The header belongs to the file, not to one side, so the
driver merges it like a row:

  - a header changed on ONE side only      -> that side's header
  - a header changed on BOTH sides to the
    SAME text                              -> that text
  - DIFFERENT headers on both sides        -> CONFLICT, named
                                             "<the file's header>"

Taking the header from "ours" alone dropped the other side's edit to it: in a
rebase "ours" is the side being rebased ONTO, so a branch that edited the
prose had its edit discarded silently, and the cherry-pick came out EMPTY
(= git printed "patch contents already upstream"). Measured 2026-11-20.

THE FILE'S TAIL

The registry is a table PLUS a tail: everything after the LAST table row. The
tail is not decoration (= it is the marker that says where a new row goes),
so the driver merges it like a row, THREE WAYS against base (= the same rule
the header above follows):

  - a tail on one side only          -> that side's tail
  - the SAME tail on both sides      -> that tail
  - a tail changed on ONE side only  -> that side's tail
  - DIFFERENT tails on both sides    -> CONFLICT, named "<the file's tail>"

A tail is present when the text after the last table row is not only
whitespace. Taking the tail from one side alone dropped the tail whenever
that side had none, so a rebase onto a base without the tail silently
deleted it. And comparing the two tails alone called every difference a
disagreement, so a branch that EDITED the tail collided with a sibling that
merely re-landed it: the driver named "<the file's tail>" and exited 1
although only one side had changed anything.

The output preserves the RECEIVING side's row order and appends the new
keys, so a row that only one card added lands at the end (= the append-only
convention the registry's own footer states). "Receiving" = the side git
calls "ours" (= in a rebase, the upstream being rebased onto). Seeding the
order with the BASE instead rewrote a row that neither side had edited,
because a rebase's base is the replayed commit's ancestor and does not
carry the upstream's rows.

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


def has_tail(tail: list[str]) -> bool:
    """True when the text after the last table row is not only whitespace.

    An empty tail and a whitespace-only tail are the same thing here: a side
    with neither has no tail to keep.
    """
    return any(line.strip() for line in tail)


def merge_docs(base: str, ours: str, theirs: str) -> tuple[str, list[str]]:
    """Merge two registry files at the key level. Returns (merged, conflicted)."""
    base_before, base_rows, base_after = split_rows(base)
    our_before, our_rows, our_after = split_rows(ours)
    their_before, their_rows, their_after = split_rows(theirs)

    base_by_key = {key_of(r): r for r in base_rows if key_of(r)}
    our_by_key = {key_of(r): r for r in our_rows if key_of(r)}
    their_by_key = {key_of(r): r for r in their_rows if key_of(r)}

    # THE ORDER SEED IS "OURS", NOT "BASE". Git calls the side being
    # landed ONTO "ours" (= in a rebase that is the UPSTREAM, = and in a
    # merge it is the branch receiving), = and "base" is the common
    # ancestor (= in a rebase the ancestor of the replayed commit, = which
    # does NOT carry the upstream's rows).
    #
    # Seeding with BASE put the replayed branch's EARLIER rows first, = so
    # the upstream's own row was pushed down and had to be rewritten: a
    # rebase that replayed a second row-add commit moved the upstream's
    # row and re-wrote it (measured: +2/-1 instead of +1/-0, = and the
    # rewrite touched a row NEITHER side had edited). Seeding with OURS
    # keeps the receiving side's rows exactly where they are and appends
    # the new keys (= +1/-0), = which is also the registry's own
    # append-only convention.
    order: list[str] = []
    for row in our_rows + their_rows:
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
        # A key present on exactly ONE side has two completely different
        # causes, and this branch used to treat them as one: it appended
        # whichever row it found. That silently RESURRECTED a deletion -- a
        # card that repaired a defective key by deleting its row lost the row
        # again the moment the branch merged, because the base and the other
        # side still carried it (measured: a landing merge put both repaired
        # keys back alongside their defective forms, rc=0, and the LOC gate
        # then read the landed tree and reported success, because a
        # resurrected row is in neither `added` nor `rewritten`).
        #
        # So a one-sided row is resolved THREE WAYS against base, the way the
        # header and the tail above already are:
        #   - never in base            -> that side ADDED it; keep it.
        #   - in base, unchanged here  -> the other side DELETED it; honour
        #     the deletion. That is the whole point of a key-level driver: an
        #     unedited side is not a claim that the row must live forever.
        #   - in base, edited here     -> deleted on one side, changed on the
        #     other: the CONFLICT the module docstring promises to NAME.
        #     The row is still written out (= the human needs a file to
        #     resolve from) and rc=1, exactly like a two-sided disagreement.
        if o is not None:  # theirs has no row for this key
            if b is None:
                merged_rows.append(o)
            elif o == b:
                pass  # theirs deleted it and ours never touched it
            else:
                conflicted.append(key)
                merged_rows.append(o)
            continue
        if t is not None:  # ours has no row for this key
            if b is None:
                merged_rows.append(t)
            elif t == b:
                pass  # ours deleted it and theirs never touched it
            else:
                conflicted.append(key)
                merged_rows.append(t)
            continue
        # Deleted on both sides: nothing to keep.
        continue

    if not our_before:
        our_before, our_after = base_before, base_after

    # The header (= everything above the table, prose included) belongs to
    # the file, not to one side: the side that changed it keeps it, two
    # sides that changed it the same way agree, and two sides that changed
    # it differently disagree the way two rows disagree.
    #
    # Taking it from "ours" alone dropped the other side's edit to it: in a
    # rebase "ours" is the side being rebased ONTO, so a branch that edited
    # the prose lost the edit silently and the cherry-pick came out empty.
    if our_before == their_before:
        before = our_before
    elif our_before == base_before:
        before = their_before
    elif their_before == base_before:
        before = our_before
    else:
        conflicted.append("<the file's header>")
        before = our_before

    # The tail (= everything after the last table row) belongs to the file,
    # not to one side: the driver merges it THREE WAYS against base, the
    # way it merges the header above.
    #
    # Comparing the two sides alone made a branch that EDITED the tail
    # collide with a sibling that merely re-landed it: the two-way rule
    # called that a disagreement, named "<the file's tail>" and exited 1,
    # even though only one side had changed anything. So when both sides
    # have a tail, the side that did NOT change it loses (= the other
    # side's edit wins), and only two DIFFERENT edits disagree.
    #
    # The three-way comparison applies ONLY when both sides have a tail:
    # a side that DELETED the tail while the other kept it keeps it (= the
    # tail is the marker that says where a new row goes).
    if has_tail(our_after) and has_tail(their_after):
        if our_after == their_after:
            after = our_after
        elif our_after == base_after:
            after = their_after
        elif their_after == base_after:
            after = our_after
        else:
            conflicted.append("<the file's tail>")
            after = our_after
    elif has_tail(our_after):
        after = our_after
    elif has_tail(their_after):
        after = their_after
    else:
        after = our_after

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
