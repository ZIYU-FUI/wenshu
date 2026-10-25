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

THREE THINGS THIS GATE NOW GETS RIGHT (each one measured on this board,
2026-10-25; the first one made the gate report a false clean bill of
health on 122 cards):

  1. A CHINESE HEADER IS A HEADER. The old section regex only matched an
     ALL-CAPS ENGLISH line, and every card on this board writes its
     headings in Chinese (= a numbered Chinese line: "## 1. the top bar:
     3 buttons -> 2"). The gate then parsed NOTHING in those bodies,
     gave every card an empty written set and an empty forbidden set, and
     reported "file collisions: 0" while a real conflict was live. Measured
     before the fix: the four Chinese cards on the board parsed 0 sections,
     the one English card parsed 4.

  2. A PROHIBITION IS NOT A PERMISSION. The old gate compared a heading
     with `in` against an exact set, so "WHAT THIS CARD MUST NOT CHANGE"
     was a WRITE section to the gate (its paths counted as edits) and a
     prohibition to ticket_tier.py (its paths counted as untouchable). The
     gate then reported the two cards that both PROHIBIT a file as the two
     cards that both EDIT it. The vocabulary is now normalized, shared
     with ticket_tier.py, and a heading that ENDS WITH a prohibition phrase
     is one.

  3. A RULE CITATION IS A CITATION. The old citation pattern only
     recognised a citation that carried a marker ("§", "section", "rule",
     "clause"), so it stripped "AGENTS.md §7.3" and left the project's own
     house style ("AGENTS.md 1.1", 61 occurrences on this board) standing
     as a write of AGENTS.md. A marker-less section number is a citation
     too; a path with NO number after it is still a file reference, so a
     card that says "make `AGENTS.md` say which" still writes AGENTS.md.

The gate also prints what it parsed, per card, because "0 collisions" is
only meaningful next to "how many sections did you actually read":

  cards checked: 122
  sections parsed per card:
    t_10607e80  53 sections
    ...
  cards with 0 sections parsed: 0
  file collisions (two cards write the same file): 0

A card whose body parses to 0 sections is LISTED BY NAME: a body the gate
cannot read must never earn a clean bill of health.

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

# ===========================================================================
# THE CARD-BODY VOCABULARY
#
# wave_gate.py and ticket_tier.py read the same board and must answer the
# same question about the same body: which files does this card write, and
# which files must it leave alone? They used to keep TWO COPIES of the same
# idea, and the copies drifted: wave_gate.py matched a heading exactly
# against a five-phrase set, ticket_tier.py normalized the heading and
# carried a seven-phrase set, so the same body was a prohibition to one
# tool and a write to the other, on the same board, at the same moment.
#
# Everything that decides what a body means lives HERE, and ticket_tier.py
# imports it, so the next phrase added to the vocabulary cannot land in one
# tool and not the other.
# ===========================================================================

# The headings whose paths are files the card must NOT touch, NORMALIZED
# (stripped, trailing colon dropped, lower-cased).
#
# The set is the UNION of what each tool used to carry, so no heading that
# was a prohibition to one of them stops being one:
#
#   wave_gate.py:   MUST NOT CHANGE, DO NOT TOUCH THE APP, DO NOT TOUCH,
#                   MUST NOT REINTRODUCE, FILES TO LEAVE ALONE
#   ticket_tier.py: the same five, plus "do not change" and "out of scope"
#
# "constraints" and its Chinese name are here because the board writes its
# prohibitions under them: measured on the live Chinese cards, every
# Chinese constraint heading (the word for "constraints") opens a list of
# "do not touch this" bullets, and an English "CONSTRAINTS" section is the
# same list. A vocabulary that knew the Chinese one and not the English one
# would rate a card by its language.
#
# The Chinese entries are written as escapes on purpose: this file carries
# no CJK characters (AGENTS.md 1.1), and a reader who wants to see the
# phrase can decode it.
EXCLUSION_SECTIONS = {
    # the ASCII phrases both tools already used
    "must not change",
    "do not touch the app",
    "do not touch",
    "must not reintroduce",
    "files to leave alone",
    "do not change",
    "out of scope",
    # the constraint section, in both languages
    "constraints",
    "\u7ea6\u675f",
    # the Chinese ways of writing "must not change" (= the direct
    # translation of the first phrase above)
    "\u4e0d\u5f97\u4fee\u6539",
    "\u7981\u6b62\u4fee\u6539",
    "\u4e0d\u53ef\u4fee\u6539",
    "\u4e0d\u8981\u4fee\u6539",
    # the Chinese ways of writing "do not touch" (= the board's own idiom:
    # every Chinese card on this board writes its prohibitions as a
    # "do not touch this" bullet)
    "\u4e0d\u5f97\u52a8",
    "\u7981\u6b62\u52a8",
    "\u4e0d\u8981\u52a8",
}


# A path followed by a section number = a citation of that path's rule, not
# an edit of the path.
#
# The number may carry a marker ("§7.3", "section 7.3", "rule 7.3") or
# stand on its own ("AGENTS.md 7.3", "AGENTS.md 1.1"): the bare form is the
# project's own citation style, measured at 61 occurrences on this board,
# and the marked form is rare. The path and the number are often separated
# by a closing backtick ("Follow `AGENTS.md` §7.3"), so the pattern allows
# quotes and spaces between them.
#
# A marker-less citation must be a DOTTED section number (= "N.M"), because
# that is how this project numbers its rules (AGENTS.md §1.1 .. §10.4), and
# a bare integer after a path is a COUNT, not a rule: measured on
# t_50223946, "ChromeMainToolbar.swift` 3 buttons" is the
# number of buttons, and reading it as a citation would drop a real write.
#
# The number is REQUIRED: a path with no number after it is a file
# reference, and a card that says "make `AGENTS.md` say which" IS asking to
# edit that file, and that grant must survive.
CITATION_RE = re.compile(
    r"[A-Za-z0-9_./-]+\.(?:swift|md|sh|xcstrings|py|yml|yaml|plist)"
    r"(?:[\"'`\s]*(?:§|section|rule|clause)\s*[0-9]+(?:\.[0-9]+)*"
    r"|[\"'`\s]+[0-9]+\.[0-9]+(?:\.[0-9]+)*)"
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

# --- what a heading looks like -------------------------------------------
#
# A heading is a SHORT line that opens a section, and this board writes
# them in two shapes: markdown hashes ("## GATES", "## acceptance"), a bare
# ALL-CAPS ENGLISH line ("GATES:"), and a bare CHINESE line
# (a numbered Chinese line: "## 1. the top bar: 3 buttons -> 2").
#
# The Chinese shape needs a guard, or every prose line in a Chinese body
# becomes a section boundary and the whole body becomes one exclusion
# section (= the gate would classify everything as forbidden = the other
# false verdict). A Chinese heading is short, carries no sentence
# punctuation, and is not a list item.
HASH_HEADING_RE = re.compile(r"^#{1,3}\s+(.+?)\s*$")
ALLCAPS_HEADING_RE = re.compile(r"^([A-Z][A-Z0-9 /()\-]{2,45})\s*:?$")
# CJK ideographs (U+3400..U+9FFF, U+F900..U+FAFF), written as escapes so
# this file carries no CJK characters.
CJK_IDEOGRAPH_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
# The sentence punctuation of a Chinese line: U+3002, U+FF01, U+FF1F, U+FF1B.
CJK_SENTENCE_RE = re.compile(r"[\u3002\uff01\uff1f\uff1b]")
# A list item opens with a bullet, a pipe, or a number (= "1." or a
# number followed by the Chinese comma).
LIST_ITEM_RE = re.compile(r"^(?:[-*+|>]|[\u2022]|\d+[.\u3001)\uff09])\s")


def heading_of(line: str) -> str | None:
    """The heading a line opens, or None if the line is content.

    The three shapes, in the order they are tried:

      - a markdown heading: "## GATES", "## acceptance", "## What changes"
      - a bare ALL-CAPS ENGLISH line: "GATES:", "MUST NOT CHANGE"
      - a bare CHINESE line (a short numbered Chinese line)

    A markdown heading may carry any text (the project writes "## What
    changes"), so the length bound is the only limit on it. A bare line
    must be short, and a Chinese one must not look like a sentence or a
    list item.
    """
    stripped = line.strip()
    if not stripped:
        return None
    match = HASH_HEADING_RE.match(stripped)
    if match:
        text = match.group(1).strip()
        return text if 2 <= len(text) <= 45 else None
    match = ALLCAPS_HEADING_RE.match(stripped)
    if match:
        return match.group(1).strip()
    if (
        CJK_IDEOGRAPH_RE.search(stripped)
        and not LIST_ITEM_RE.match(stripped)
        and not CJK_SENTENCE_RE.search(stripped)
        and 2 <= len(stripped) <= 45
    ):
        return stripped
    return None


def normalize_heading(name: str) -> str:
    """The heading as the vocabulary compares it."""
    return name.strip().rstrip(":").strip().lower()


def is_exclusion(name: str) -> bool:
    """Whether a heading's paths are files the card must NOT touch.

    A heading IS one of the exclusion phrases, or it ENDS WITH one ("WHAT
    THIS CARD MUST NOT CHANGE" ends with "must not change"), or it STARTS
    WITH one (a Chinese heading puts the prohibition at the head, an English
    one at the tail: a Chinese heading that STARTS with "must not
    change").

    The match is deliberately narrow. Widening it would turn a heading that
    is NOT a prohibition into one, and that direction UNDER-reports a
    collision: two cards edit one file and the gate calls the board clean,
    which is the failure this gate exists to prevent. A heading that
    cannot be classified with confidence is a WRITE section.
    """
    normalized = normalize_heading(name)
    if normalized in EXCLUSION_SECTIONS:
        return True
    return any(
        normalized.endswith(phrase) or normalized.startswith(phrase)
        for phrase in EXCLUSION_SECTIONS
    )


def sections(body: str) -> list[tuple[str, str]]:
    """Split a card body into (heading, text) pairs.

    The text before the first heading is kept as a section of its own, named
    "", because that is where a card that states its work in a preamble puts
    it. Measured: one card that MOVES a file across the app boundary opens
    with "## What changes", and a splitter that only knew ALL-CAPS English
    read that card as a card with no files at all, and a tier built on it
    rated a file move T1.

    A body with NO heading at all returns []. The caller then has to treat
    the whole body as one unknown section, instead of pretending it read a
    structure that is not there.
    """
    out: list[tuple[str, str]] = []
    name = ""
    lines: list[str] = []
    found = False
    for line in body.split("\n"):
        heading = heading_of(line)
        if heading is None:
            lines.append(line)
            continue
        found = True
        if lines:
            out.append((name, "\n".join(lines)))
        name = heading
        lines = [line]
    if not found:
        return []
    if lines:
        out.append((name, "\n".join(lines)))
    return out


def headings_parsed(body: str) -> int:
    """How many headings the reader found in a body (= the sections it named).

    This is the number that makes a verdict self-describing: "0 collisions"
    means something only next to "0 sections parsed" (= the gate read
    nothing, so it saw nothing to collide). Measured before the fix: the
    four Chinese cards on this board parsed 0 sections each, and the gate
    printed "file collisions: 0" as if it had checked them.
    """
    return len([name for name, _ in sections(body) if name])


def files_of(body: str) -> tuple[set[str], set[str]]:
    """The (written, forbidden) file sets of a card body.

    A path in an exclusion section is forbidden only when the sentence that
    names it does NOT also grant an edit to it. A card can list a file under
    "MUST NOT CHANGE" and still be told to add a row to it (= the nervous
    file index, which every card appends to), and classifying that as
    forbidden hides the real collision.

    A path named in BOTH a write section and an exclusion section is
    contradictory in the body; it counts as written, because the card does
    reach that file, and because counting it as forbidden would UNDER-report
    a collision (= the dangerous direction).

    A body the reader could not split at all (= no heading) counts every
    path in it as WRITTEN. A card the gate cannot parse must never earn a
    clean bill of health, and over-reporting a collision only blocks a card
    that need not be blocked.
    """
    written: set[str] = set()
    forbidden: set[str] = set()
    parsed = sections(body)
    if not parsed:
        return set(PATH_RE.findall(CITATION_RE.sub("", body))), set()
    for name, text in parsed:
        stripped = CITATION_RE.sub("", text)
        if not is_exclusion(name):
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
    return written, forbidden - written


def work_text(body: str) -> str:
    """The body text outside the exclusion sections.

    This is where a signal about the WORK is read from, so that a card
    saying "no persistence change here" in its MUST NOT CHANGE list does
    not read as a persistence card.
    """
    parsed = sections(body)
    if not parsed:
        return body
    return "\n".join(text for name, text in parsed if not is_exclusion(name))


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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cards", nargs="*", help="card ids; default = every card")
    ap.add_argument("--live", action="store_true", help="only cards that are not done")
    ap.add_argument("--plan", action="store_true", help="print the serialization order")
    args = ap.parse_args()

    wanted = set(args.cards)
    cards: dict[str, dict] = {}
    parsed: dict[str, int] = {}
    for cid, status in card_ids():
        if wanted and cid not in wanted:
            continue
        if args.live and status == "done":
            continue
        body = card_body(cid)
        written, forbidden = files_of(body)
        cards[cid] = {"status": status, "written": written, "forbidden": forbidden}
        parsed[cid] = headings_parsed(body)

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
    print("sections parsed per card:")
    for cid in ids:
        print(f"  {cid}  {parsed[cid]} sections")
    unread = [cid for cid in ids if parsed[cid] == 0]
    print(f"cards with 0 sections parsed: {len(unread)}")
    for cid in unread:
        print(
            f"  {cid}  (= the body has no heading the gate could read; "
            f"every path in it counts as a write)"
        )
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
