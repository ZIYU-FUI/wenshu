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
import fnmatch
import re
import subprocess
import sys
from pathlib import Path

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
#
# The marker can be a section number with a subsection (= "AGENTS.md §7.3"),
# so the number part takes decimals. And the path and the marker are often
# separated by a closing backtick (= "Follow `AGENTS.md` §7.3"), so the
# pattern allows quotes and spaces between them.
#
# Measured: the pattern without the decimals and the quotes matched neither
# "§7.3" nor "`AGENTS.md` §7.3", and the gate counted "Follow AGENTS.md §7.3"
# as a write of AGENTS.md.
CITATION_RE = re.compile(
    r"[A-Za-z0-9_./-]+\.(?:swift|md|sh|xcstrings|py|yml|yaml|plist)"
    r"[\"'`\s]*(?:§|section|rule|clause)\s*[0-9]+(?:\.[0-9]+)*"
)

# A sentence that GRANTS an edit to the path it names, even when the
# sentence sits in an exclusion section.
#
# Measured: a card's "MUST NOT CHANGE" list held the line "docs/agents/nfi.md.
# The nervous file index must gain a row for each of the four moved files",
# and another held "No other row of the docs/agents/nfi.md table may be
# edited. You are adding one row, not rewriting the table." Both GRANT a
# write. Classifying them as forbidden made the gate report a stale
# must-not-change list against a file every card writes, and it hid the
# real fact (three cards append a row to the same table).
GRANT_RE = re.compile(
    r"\b(?:must|should|has to|needs to|will)\s+"
    r"(?:gain|add|append|register|be registered|get a row|receive a row)"
    r"|\byou are (?:adding|appending|registering)\b"
    r"|\badd(?:s|ing)? (?:a|an|one|two|three|four|five) (?:new )?rows?\b"
    r"|\bappend(?:s|ing)? (?:a|an|one|two|three|four|five) (?:new )?rows?\b"
    r"|\bregister(?:s|ing)? (?:a|the|its|each)\b"
    r"|\bnew file must be registered\b"
    r"|\bmust be registered in\b"
    r"|\bgain a row\b"
    r"|\bmust gain\b"
    r"|\bupdate it in this ticket\b"
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


def driver_for(path: str) -> str | None:
    """The merge driver git uses for a path, or None.

    A file with a merge driver is NOT a collision that needs serializing: the
    driver merges the file at the key level, so two cards that each add one
    row both keep theirs. The gate reports the driver so the boss knows the
    overlap is already handled, instead of serializing cards for nothing.

    The driver name comes from .gitattributes (tracked), and the driver
    itself is a local git config (= .git/config), so the gate reads the
    attributes file and not the config.
    """
    attrs = Path(REPO) / ".gitattributes"
    if not attrs.exists():
        return None
    name = Path(path).name
    for line in attrs.read_text(encoding="utf-8").split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        pattern, attr = parts[0], parts[1]
        if not attr.startswith("merge="):
            continue
        if fnmatch.fnmatch(name, pattern) or fnmatch.fnmatch(path, pattern):
            return attr[len("merge=") :]
    return None


def card_ids() -> list[tuple[str, str]]:
    """Every card on the board as (id, status)."""
    found = []
    for line in kanban("list").splitlines():
        m = re.match(r"\S*\s*([a-z]_[0-9a-f]{8})\s+(\S+)\s+(\S+)\s+(.*)", line)
        if m:
            found.append((m.group(1), m.group(2)))
    return found


def card_body(card_id: str) -> str:
    """The card's body text, WITHOUT its comments and event log.

    `hermes kanban show` prints the body and then the comments and the event
    log under the same stream, so taking everything after "Body:" sweeps the
    comments in too. A comment that names a file then reads as if the card
    writes it, and the gate reports a collision that does not exist.

    Measured: a comment on a card that said "take main's AGENTS.md unchanged"
    made the gate report that card and another as both writing AGENTS.md,
    when neither card's body mentions it.

    The body ends where the comments begin ("Comments (N):"), and also at
    the event log if the card has no comments.
    """
    text = kanban("show", card_id)
    i = text.find("\nBody:\n")
    if i < 0:
        return ""
    body = text[i + 7 :]
    for marker in ("\nComments (", "\nEvents", "\nRun History"):
        j = body.find(marker)
        if j >= 0:
            body = body[:j]
    return body


def sections(body: str) -> list[tuple[str, str]]:
    """Split a card body into (section name, section text)."""
    marks = [(m.start(), m.group(1).strip()) for m in SECTION_RE.finditer(body)]
    out = []
    for k, (pos, name) in enumerate(marks):
        end = marks[k + 1][0] if k + 1 < len(marks) else len(body)
        out.append((name, body[pos:end]))
    return out


def files_of(body: str) -> tuple[set[str], set[str]]:
    """The (written, forbidden) file sets of a card body.

    A path in an exclusion section is forbidden only when the sentence that
    names it does NOT also grant an edit to it. A card can list a file under
    "MUST NOT CHANGE" and still be told to add a row to it (= the nervous
    file index, which every card appends to), and classifying that as
    forbidden hides the real collision.
    """
    written: set[str] = set()
    forbidden: set[str] = set()
    for name, text in sections(body):
        stripped = CITATION_RE.sub("", text)
        if name not in EXCLUSION_SECTIONS:
            written |= set(PATH_RE.findall(stripped))
            continue
        for bullet in _bullets(stripped):
            paths = set(PATH_RE.findall(bullet))
            if not paths:
                continue
            if GRANT_RE.search(bullet):
                written |= paths
            else:
                forbidden |= paths
    return written - forbidden, forbidden


def _bullets(text: str) -> list[str]:
    """Split a section into BULLETS.

    A bullet is the unit of meaning here, not a sentence: the card writes
    "docs/agents/nfi.md. The nervous file index must gain a row for each of
    the four moved files", where the path and the sentence that grants the
    write are two sentences of ONE bullet. Splitting on sentence ends would
    separate the path from its own permission.

    A line that starts with "-" opens a bullet; the lines that follow belong
    to it until the next "-" or a blank line.
    """
    bullets: list[str] = []
    current: list[str] = []
    for line in text.split("\n"):
        stripped = line.strip()
        if not stripped:
            if current:
                bullets.append(" ".join(current))
                current = []
            continue
        if re.match(r"^[-*]\s+", stripped) and current:
            bullets.append(" ".join(current))
            current = []
        current.append(stripped)
    if current:
        bullets.append(" ".join(current))
    return [b for b in bullets if b.strip()]


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
    # A file with a merge driver is not a collision to serialize: the driver
    # merges it at the key level, so both cards keep their row. Those are
    # reported separately, as "handled by the driver".
    collisions = []
    driver_managed = []
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            shared = cards[a]["written"] & cards[b]["written"]
            if not shared:
                continue
            driven = [f for f in sorted(shared) if driver_for(f)]
            plain = [f for f in sorted(shared) if not driver_for(f)]
            if plain:
                collisions.append((len(plain), a, b, plain))
            if driven:
                driver_managed.append((len(driven), a, b, driven))

    # --- staleness: one card writes a file another was told to leave ---
    # A scoped constraint (= "no OTHER row of this table may be edited")
    # is not a stale list: the card that holds it also writes the file, and
    # the constraint is about the other rows, not the file. Only a file the
    # card is told to leave ENTIRELY counts.
    stale = []
    scoped = []
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            crossed = (cards[a]["written"] & cards[b]["forbidden"]) | (
                cards[b]["written"] & cards[a]["forbidden"]
            )
            if not crossed:
                continue
            own = [
                f
                for f in sorted(crossed)
                if f in cards[a]["written"] and f in cards[b]["written"]
            ]
            whole = [f for f in sorted(crossed) if f not in own]
            if whole:
                stale.append((len(whole), a, b, whole))
            if own:
                scoped.append((len(own), a, b, own))

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

    if driver_managed:
        print("=== HANDLED BY A MERGE DRIVER: both cards keep their rows ===")
        for n, a, b, shared in sorted(driver_managed, reverse=True):
            print(f"\n  {a} [{cards[a]['status']}] vs {b} [{cards[b]['status']}]")
            for f in shared:
                print(f"      {f}   (= merges by key, driver '{driver_for(f)}')")
        print()

    if stale:
        print("=== STALE must-not-change lists: the second card's list is out of date ===")
        for n, a, b, shared in sorted(stale, reverse=True):
            print(f"\n  {a} vs {b}")
            for f in shared:
                d = driver_for(f)
                note = f"   (= merges by key, driver '{d}')" if d else ""
                print(f"      {f}{note}")
        print()

    if scoped:
        print("=== SCOPED constraints: both cards write this file, and each limits itself ===")
        for n, a, b, shared in sorted(scoped, reverse=True):
            print(f"\n  {a} vs {b}")
            for f in shared:
                d = driver_for(f)
                note = f"   (= merges by key, driver '{d}')" if d else ""
                print(f"      {f}{note}")
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
