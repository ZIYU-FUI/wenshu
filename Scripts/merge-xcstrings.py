#!/usr/bin/env python3
"""merge-xcstrings.py — a JSON-aware merge driver for Xcode String Catalogs.

WHY THIS EXISTS

`Localizable.xcstrings` is the most-touched file in the wave (7 touches
inside a 12-commit window; 6 cards on the board write it). Its keys are NOT
sorted, and a new key lands in the MIDDLE of the file (256 of 275 additions
measured across the catalog's history). So two cards that each add a
DIFFERENT key still produce a textual conflict: git compares line offsets,
and both insertions land at the same neighbourhood.

Measured on this repo: `git merge-tree` on two branches that each added one
distinct key returned CONFLICT. That is the conflict class this driver
removes.

THE MERGE

Three-way, at the KEY level, per localization language:

    base / ours / theirs = the three JSON documents

  - a key only in one side        -> taken from that side
  - a key in base, changed in one side only -> that side wins
  - a key in base, changed in BOTH sides to the SAME value -> that value
  - a key in base, changed in BOTH sides to DIFFERENT values -> CONFLICT
  - a key deleted on one side, changed on the other -> CONFLICT
  - a key deleted on one side, untouched on the other -> the deletion wins

A conflict is reported per key, with the key name, so the human resolving it
knows WHICH string collided instead of hunting a 6400-line file for a
`<<<<<<<` marker.

THE OUTPUT

`json.dumps(indent=2, ensure_ascii=False)` + a trailing newline. Verified
byte-identical to the file Xcode writes on this repo.

THE ORDER

The base file's key order is preserved, then keys only in ours, then keys
only in theirs. Xcode rewrites the order whenever it saves the catalog, so
the order is not load-bearing; preserving it keeps the diff small.

Usage (this is what git runs):

    merge-xcstrings.py <base> <ours> <theirs>

git passes the three temp files and expects the merged result written back
into <ours>. Exit 0 = merged, exit 1 = conflict (the conflicted keys are
listed on stderr).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def load(path: str) -> dict:
    """Read one catalog document. A missing file = an empty document."""
    p = Path(path)
    if not p.exists():
        return {}
    raw = p.read_text(encoding="utf-8")
    if not raw.strip():
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"merge-xcstrings: cannot parse {path}: {exc}\n")
        sys.exit(1)


def strings_of(doc: dict) -> dict:
    """The `strings` map of a catalog document."""
    s = doc.get("strings")
    return s if isinstance(s, dict) else {}


def dump(doc: dict) -> str:
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


def merge_key(base: object, ours: object, theirs: object) -> tuple[object, bool]:
    """Merge one key's value. Returns (value, conflicted).

    A value of None means the key is ABSENT from the merged result (= a
    deletion won). A catalog value is always a dict, never None, so None is
    unambiguous here.
    """
    if ours == theirs:
        return ours, False
    if ours == base:
        return theirs, False
    if theirs == base:
        return ours, False
    # Both sides changed it, to different values.
    return None, True


def merge_docs(base: dict, ours: dict, theirs: dict) -> tuple[dict, list[str]]:
    """Merge the two catalogs at the key level. Returns (merged, conflicted keys)."""
    b, o, t = strings_of(base), strings_of(ours), strings_of(theirs)
    merged: dict = {}
    conflicted: list[str] = []

    for key in list(b) + [k for k in o if k not in b] + [k for k in t if k not in b]:
        if key in merged:
            continue
        bv = b.get(key)
        ov = o.get(key)
        tv = t.get(key)
        value, bad = merge_key(bv, ov, tv)
        if bad:
            conflicted.append(key)
            # Keep OUR value in the output so the file stays valid JSON and the
            # conflict is a human decision about a named key, not a hunt for a
            # marker inside 6400 lines.
            merged[key] = ov if ov is not None else tv
        elif value is None:
            # One side deleted the key and the other left it alone: the
            # deletion wins, so the key is absent from the merged result.
            continue
        else:
            merged[key] = value

    out = dict(ours)
    out["strings"] = merged
    return out, conflicted


def main() -> int:
    if len(sys.argv) != 4:
        sys.stderr.write("usage: merge-xcstrings.py <base> <ours> <theirs>\n")
        return 2

    base, ours_path, theirs_path = sys.argv[1], sys.argv[2], sys.argv[3]
    base_doc = load(base)
    ours_doc = load(ours_path)
    theirs_doc = load(theirs_path)

    merged, conflicted = merge_docs(base_doc, ours_doc, theirs_doc)

    Path(ours_path).write_text(dump(merged), encoding="utf-8")

    if conflicted:
        sys.stderr.write("merge-xcstrings: conflicted keys:\n")
        for key in conflicted:
            sys.stderr.write(f"  {key}\n")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
