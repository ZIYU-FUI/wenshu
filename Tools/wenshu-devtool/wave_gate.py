#!/usr/bin/env python3
"""wave-gate.py — the pre-dispatch file-ownership gate.

Two cards that write the same file cannot land in any order without a text
conflict. The card body already names every file the worker will touch, so
the collision is knowable BEFORE the wave starts.

Measured on this board: 16 of 153 card pairs write the same file, and 23
pairs are stale in the other direction (one card writes a file another card
was told not to touch, so the second card's must-not-change list is already
out of date when it lands).

A naive scan that counts every path in every body over-reports (90 of 153
pairs), because a body mentions a file it will only READ, or a rule it
cites ("AGENTS.md §7.3"). This gate reads the body's SECTIONS, so:

  - a path under a WRITE section (= WHAT TO BUILD, and the body text outside
    the exclusion sections) = the card will edit it
  - a path under an EXCLUSION section (= MUST NOT CHANGE, DO NOT TOUCH) = the
    card must not edit it
  - a path followed by a section marker ("AGENTS.md §7.3") = a citation, not
    an edit

Usage:
    wave-gate.py                    # every card on the board
    wave-gate.py t_123 t_456        # only these cards
    wave-gate.py --live             # only cards that are not done
    wave-gate.py --plan             # print the serialization order to apply

Exit code 0 = no collision, 1 = at least one collision to serialize.
"""
from __future__ import annotations

import argparse
import collections
import re
import subprocess
import sys

REPO = "/Volumes/ANAN/Engineering/wenshu"

# Sections whose paths are files the card must NOT touch.
EXCLUSION_SECTIONS = {
    "MUST NOT CHANGE",
    "DO NOT TOUCH THE APP",
    "DO NOT TOUCH",
    "MUST NOT REINTRODUCE",
    "FILES TO LEAVE ALONE",
}

# A path followed by a section marker (= a citation of a rule, not an edit).
CITATION_RE = re.compile(
    r"[A-Za-z0-9_./-]+\.(?:swift|md|sh|xcstrings|py|yml|yaml|plist)"
    r"\s*(?:§|section|rule|clause)\s*[0-9]"
)

PATH_RE = re.compile(
    r"(?:Sources|Tests|Tools|docs|Scripts)/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+"
    r"|(?:AGENTS|Package|CHANGELOG|OOB|CONTEXT|README)\.md"
    r"|Package\.(?:swift|resolved)"
    r"|\.(?:swiftlint\.yml|swift-format)"
)

# A section header: "WHAT TO BUILD", "## MUST NOT CHANGE", "MUST NOT CHANGE:".
SECTION_RE = re.compile(r"^(?:#{1,3}\s*)?([A-Z][A-Z0-9 /()\-]{2,45})\s*:?\s*$", re.M)


def kanban(*args: str) -> str:
    out = subprocess.run(
        ["hermes", "kanban", *args], cwd=REPO, capture_output=True, text=True
    )
    return out.stdout


def card_ids() -> list[tuple[str, str]]:
    """Every card on the board as (id, status)."""
    found = []
    for line in kanban("list").splitlines():
        m = re.match(r"\S*\s*([a-z]_[0-9a-f]{8})\s+(\S+)\s+(\S+)\s+(.*)", line)
        if m:
            found.append((m.group(1), m.group(2)))
    return found


def card_body(card_id: str) -> str:
    text = kanban("show", card_id)
    i = text.find("\nBody:\n")
    return text[i + 7 :] if i >= 0 else ""


def sections(body: str) -> list[tuple[str, str]]:
    """Split a card body into (section name, section text)."""
    marks = [(m.start(), m.group(1).strip()) for m in SECTION_RE.finditer(body)]
    out = []
    for k, (pos, name) in enumerate(marks):
        end = marks[k + 1][0] if k + 1 < len(marks) else len(body)
        out.append((name, body[pos:end]))
    return out


def files_of(body: str) -> tuple[set[str], set[str]]:
    """The (written, forbidden) file sets of a card body."""
    written: set[str] = set()
    forbidden: set[str] = set()
    for name, text in sections(body):
        stripped = CITATION_RE.sub("", text)
        paths = set(PATH_RE.findall(stripped))
        if name in EXCLUSION_SECTIONS:
            forbidden |= paths
        else:
            written |= paths
    return written - forbidden, forbidden


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cards", nargs="*", help="card ids; default = every card")
    ap.add_argument("--live", action="store_true", help="only cards that are not done")
    ap.add_argument("--plan", action="store_true", help="print the serialization order")
    args = ap.parse_args()

    wanted = set(args.cards)
    cards: dict[str, dict] = {}
    for cid, status in card_ids():
        if wanted and cid not in wanted:
            continue
        if args.live and status == "done":
            continue
        written, forbidden = files_of(card_body(cid))
        cards[cid] = {"status": status, "written": written, "forbidden": forbidden}

    if not cards:
        print("no cards to check")
        return 0

    ids = sorted(cards)

    # --- collisions: two cards writing the same file -------------------
    collisions = []
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            shared = cards[a]["written"] & cards[b]["written"]
            if shared:
                collisions.append((len(shared), a, b, sorted(shared)))

    # --- staleness: one card writes a file another was told to leave ---
    stale = []
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            crossed = (cards[a]["written"] & cards[b]["forbidden"]) | (
                cards[b]["written"] & cards[a]["forbidden"]
            )
            if crossed:
                stale.append((len(crossed), a, b, sorted(crossed)))

    magnets = collections.Counter()
    for c in cards.values():
        for f in c["written"]:
            magnets[f] += 1
    magnets = [(f, n) for f, n in magnets.most_common() if n > 1]

    print(f"cards checked: {len(cards)}")
    print(f"file collisions (two cards write the same file): {len(collisions)}")
    print(f"stale must-not-change lists (one card writes what another must leave): {len(stale)}\n")

    if magnets:
        print("=== magnet files (written by more than one card) ===")
        for f, n in magnets:
            owners = [cid for cid in ids if f in cards[cid]["written"]]
            print(f"  {n}x  {f}")
            print(f"      {', '.join(owners)}")
        print()

    if collisions:
        print("=== COLLISIONS: serialize these, or split the shared file ===")
        for n, a, b, shared in sorted(collisions, reverse=True):
            print(f"\n  {a} [{cards[a]['status']}] vs {b} [{cards[b]['status']}]")
            for f in shared:
                print(f"      {f}")
        print()

    if stale:
        print("=== STALE must-not-change lists: the second card's list is out of date ===")
        for n, a, b, shared in sorted(stale, reverse=True):
            print(f"\n  {a} vs {b}")
            for f in shared:
                print(f"      {f}")
        print()

    if args.plan:
        # The plan is only actionable for cards that have not landed yet: a
        # done card cannot be linked, and its collision is already history.
        live = [cid for cid in ids if cards[cid]["status"] != "done"]
        live_collisions = [
            (n, a, b) for n, a, b, _ in collisions if a in live and b in live
        ]
        if not live_collisions:
            print("=== serialization plan: no live card collides with another live card ===")
            return 0
        print("=== serialization plan (land the first, then the second) ===")
        for n, a, b in sorted(live_collisions, reverse=True):
            print(f"  {a} -> {b}   (= link {a} as the PARENT of {b})")
        print()
        print("  hermes kanban link <parent> <child>")
        return 0

    return 1 if collisions else 0


if __name__ == "__main__":
    sys.exit(main())
