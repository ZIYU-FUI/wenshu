#!/usr/bin/env python3
# ⇒ ⇒ ⇒ COMMITTED INTO THE REPO BY round 11 OF THE STANDARDS-AXIS REPORT (R10-B4, = = board
# comment 2163): = = this gate used to live only in the implementer's profile scratch
# (`cache/scratch/t2/`), = which is idle-pruned at 24h, = so the claim it backed could
# outlive the instrument. = = Provenance: = carried over BYTE-IDENTICAL below this header
# from that path; = = the reason for the move is that a gate which can be garbage-collected
# is not a gate.
# ⇒ ⇒ ⇒ KNOWN DEFECT, = = LEFT IN PLACE AND NAMED HERE (R10-B3): = = this script
# defines a row as `| Fnn |` up to the next `| F` or blank line — = = a SOURCE
# region, = = not a RENDERED row. = = `pandoc -f gfm` takes one row per physical
# line, = = so a 16-line cell is one row plus 15 lines of prose. = = ⇒⇒⇒ THEREFORE
# ITS OUTPUT IS EVIDENCE ABOUT BYTES AND IS NOT EVIDENCE THAT A TABLE RENDERS;
# render checks go through pandoc and count <td> rows.
"""Prove the 16 F-rows did not move between two versions of the report body.

Why: = the report card has asserted "0 withdrawn / = = 0 moved / = = 0 refuted" for
several rounds, = = in words, = = while the reviewer had to re-read the table to
check it. = = This makes the claim a command: = = parse every `| F<n> | … |` row out
of each body, = = compare byte-for-byte, = = and print one digest over the ordered
row block so a later round can say "same digest" instead of "nothing changed".

A row that was EDITED shows its unified diff, = = capped; = a row present in one
body and missing in the other is reported as WITHDRAWN or ADDED, = = which is the
claim the card is most likely to get wrong.

Usage: = python3 row-integrity.py OLD_BODY.md NEW_BODY.md
Exit: = 0 when every row is byte-identical and the sets are equal.
"""
import difflib
import hashlib
import re
import sys
from pathlib import Path

ROW = re.compile(r"(?m)^\| (F\d{1,2}) \|.*$")


def rows_of(text):
    out = {}
    for m in ROW.finditer(text):
        k, line = m.group(1), m.group(0)
        i = text.index(line, m.start())
        nxt = text.find("\n| F", i + 1)
        blank = text.find("\n\n", i)
        end = min(x for x in (nxt if nxt > 0 else 10 ** 9,
                              blank if blank > 0 else 10 ** 9, len(text)))
        out[k] = text[i:end]
    return out


def digest(rows):
    ordered = "".join(rows[k] for k in sorted(rows, key=lambda s: int(s[1:])))
    return hashlib.sha256(ordered.encode()).hexdigest()[:16]


if len(sys.argv) != 3:
    sys.exit("usage: python3 row-integrity.py OLD_BODY.md NEW_BODY.md")

a = rows_of(Path(sys.argv[1]).read_text())
b = rows_of(Path(sys.argv[2]).read_text())
print("rows parsed: OLD = " + str(len(a)) + "  NEW = " + str(len(b)))
if not a or not b:
    # A zero-row parse means the pattern did not match the table's shape. That
    # is NOT "no rows changed": it is the instrument failing, and printing an
    # empty comparison would let a broken checker certify the claim.
    sys.exit("ZERO rows parsed in at least one body: the row pattern does not "
             "match this table's shape. Fix the checker, do not report identity.")

gone = sorted(set(a) - set(b), key=lambda s: int(s[1:]))
added = sorted(set(b) - set(a), key=lambda s: int(s[1:]))
ident = [k for k in a if k in b and a[k] == b[k]]
moved = [k for k in a if k in b and a[k] != b[k]]

print("byte-identical: " + str(len(ident)) + "  edited: " + str(len(moved))
      + "  withdrawn: " + str(len(gone)) + "  added: " + str(len(added)))
for k in sorted(moved, key=lambda s: int(s[1:])):
    print("--- " + k + " was EDITED")
    for l in list(difflib.unified_diff(a[k].split("\n"), b[k].split("\n"),
                                       lineterm="", n=0))[2:8]:
        print("    " + l[:170])
for k in gone:
    print("--- " + k + " is WITHDRAWN (present in OLD, absent in NEW)")
for k in added:
    print("--- " + k + " is ADDED (absent in OLD)")
print("row-block digest OLD: " + digest(a))
print("row-block digest NEW: " + digest(b))
sys.exit(0 if (not moved and not gone and not added and len(a) == len(b)) else 1)
