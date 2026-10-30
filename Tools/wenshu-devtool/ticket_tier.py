#!/usr/bin/env python3
"""
ticket_tier.py - the difficulty tier of a wenshu card, and the contract the tier buys.

A card's tier is DERIVED from the work its body describes, never hand-set:

  T1  trivial   one or two files in one place, no persistence, no live-app proof
  T2  standard  the default
  T3  deep      persistence, a new subsystem, a package boundary, or a wide blast radius

The tier sets four things and nothing else:

  runtime cap   the board's --max-runtime for the card
  retry budget  the board's --max-retries for the card
  gate width    which suites prove the claim (= T1 names ONE filtered suite)
  body budget   how long the card body may be

WHY THIS EXISTS (measured on board wenshu-par, 43 done cards, 2026-10-22):

  35.7 h of worker time across the 43 done cards, in 126 runs, and only 44
  of those runs COMPLETED. 37 timed out, 28 were reclaimed, 9 crashed, 7
  blocked: the cards averaged 2.93 runs each, and the 82% of the time that
  sits in a run that did NOT finish is the cost.

  The gates are not the cost. An incremental `swift build` is 0.73 s, the full
  suite is 66 s, double-axis.sh is 0.36 s. The hours went into REPEATED
  attempts, not into verification.

  A BIGGER CAP MAKES IT WORSE, which is the result that decides the design.
  Measured by the cap each card was given: the cards on a 45-minute cap
  burned 100.8 min per card over 4.80 runs; the cards on a 30-minute cap
  burned 43.8 min per card over 2.71 runs. A cap does not buy fewer attempts.
  It buys more expensive attempts. So the tier's cap is sized to NOT KILL the
  work (= it sits above the longest run that actually finished, in that tier),
  and the tier takes its time out of the GATE and the BODY instead.

  What predicts the cost, measured as the correlation with minutes per card:
    the number of body SECTIONS   r = +0.589
    the body LENGTH               r = +0.406
    a WIDE gate (the whole suite) r = +0.402
    a live-app proof              r = +0.175
    the number of FILES the card touches   r = +0.068   (nothing)

  So the file count does NOT predict how long a card takes. What it predicts
  is whether a NARROW gate is SAFE. That is the tier's real job: it is a
  BLAST-RADIUS rating, and it decides how many suites have to prove the card.

  Inside one tier the gate is the whole difference: a card whose body demands
  the whole suite against a red baseline ran 3.44 times for 65.7 min per
  card; a card whose body named no suite ran 2.00 times for 17.6 min per card.

  The tier never skips the dual-axis review (AGENTS.md rule 1.10). It narrows
  the gate to the cheapest proof of the claim, and it never marks a test as
  skipped.

Usage:
    ticket_tier.py <card-id>...      classify cards (reads the board)
    ticket_tier.py --body FILE       classify a card body from a file
    ticket_tier.py --live            classify every card that is not done
    ticket_tier.py --check           report tier mismatches (exit 1 on any error)
    ticket_tier.py --plan            print the tier contract table
    ticket_tier.py --json            machine-readable output

Exit code 0 = pass, 1 = at least one error, 2 = the board could not be read.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wave_gate  # noqa: E402  (sibling module, same directory)
import effort_budget_gate  # noqa: E402  (sibling module, same directory)

REPO = "/Volumes/ANAN/Engineering/wenshu"

# The contract each tier buys.
#
# The caps are fitted to the measured duration of a run that FINISHED, per
# tier, so a card that does the work never loses to its own cap:
#
#   tier  longest successful run   cap    headroom
#   T1    10.5 m                   15m    1.43x
#   T2    16.0 m                   25m    1.56x
#   T3    39.2 m                   45m    1.15x
#
# The retry budget is the board's --max-retries, which trips the breaker when
# the CONSECUTIVE failure count reaches it (a success resets the count, and a
# reclaimed run does not count at all). It is fitted to the longest failure
# streak the board has actually produced per tier, plus one: measured worst
# streaks were T1 1, T2 2, T3 4, so the budgets are 2 / 3 / 5. Replaying every
# historical card under those budgets blocks ZERO cards that used to succeed.
# T3's budget is 5, not 4: a budget of 4 blocks one card that later landed.
#
# The body budget is the tier's real speed lever, and it is measured, not
# guessed. The board's cards split cleanly on the number of body SECTIONS:
# the cards with fewer than 9 sections ran 2.12 times for 25.3 min per card
# with 0.25 timeouts per card, the cards with 9-11 ran 3.05 times for 59.5
# min with 1.10 timeouts, and the cards with 11+ ran 4.50 times for 93.3 min
# with 1.25 timeouts. The same split holds INSIDE one tier, so it is not the
# tier talking. Measured as timeouts per card, a 9+ section body runs 1.21
# against 0.20 for a shorter one, while the number of FILES the card touches
# runs 0.96 against 0.75 (= nothing). So the body shape decides whether the
# worker finishes inside its budget, and the file count does not.
#
# A body over its tier's budget is a body that should be TWO cards, not a
# body the worker should be given more clock.
#
# A cap that is too small does not save time, it moves the work to a human:
# the cards on a 45-minute cap burned 100.8 min each over 4.80 runs, against
# 43.8 min each over 2.71 runs for the cards on a 30-minute cap. A cap does
# not buy fewer attempts; it buys more expensive ones. So T3's cap stays
# above its measured maximum, and the fast lane takes its time out of the
# GATE and the BODY, not out of the cap.
# The REVIEW lane's cap is the lane's own, not the tier's. A review run
# re-reads the diff, re-derives the acceptance and re-runs the gates, so it
# takes longer than the implementation it audits: measured 2026-10-27, the
# board's completed reviews ran 15.5-73.9 min (p90 43.2 min). The tier's cap
# is fitted to an IMPLEMENTATION run, so a review card judged against it dies
# on the clock before it can produce a verdict.
#
# Measured on this board: at a 1500 cap the review runs died at 25.1 min
# (seven of them), and at 3600 a 27-min review completed. So the lane's FLOOR
# is 3600 s, and a card carrying less will die before it can hand back a
# verdict. A card carrying more is generous, not wrong, so the floor is what
# this gate checks.
#
# The floor is one number for the lane: the width of a REVIEW is not
# derivable from the card body, because that body describes the work under
# review, not the review itself.
REVIEW_LANE_CAP_FLOOR = 3600

TIERS = {
    "T1": {
        "label": "trivial",
        "runtime": 900,
        "runtime_text": "15m",
        "retries": 2,
        "body_max": 4000,
        "sections_max": 7,
        "gate": "swift build + ONE filtered suite that owns the touched file",
    },
    "T2": {
        "label": "standard",
        "runtime": 1500,
        "runtime_text": "25m",
        "retries": 3,
        "body_max": 8000,
        "sections_max": 9,
        "gate": "swift build + a filtered suite per touched area; baseline compare only where the baseline is red",
    },
    "T3": {
        "label": "deep",
        "runtime": 2700,
        "runtime_text": "45m",
        "retries": 5,
        "body_max": 32000,
        "sections_max": 12,
        "gate": "the full gate set, incl. a red-baseline comparison and a visual proof",
    },
}

# The epoch of the "a card must carry a cap" rule. A card with no
# `max_runtime_seconds` has no fuse: the dispatcher's reaper only sees the
# workers whose card carries one (= its query is `WHERE
# t.max_runtime_seconds IS NOT NULL`), so a card without a cap runs until
# the provider's quota wall or the process dies.
#
# Cards created before this epoch were dispatched under a flow that did
# not ask for a cap, and they have all finished or been archived. So the
# rule starts here and does not look back.
CAP_CONTRACT_FROM = 1793260800  # 2026-10-30 00:00 CST


# A card carries its tier in the title, so `kanban list` shows the rating at a
# glance and the worker reads it without hunting for it.
TITLE_RE = re.compile(r"^\[(T[123])\]\s*")

# A card carries its TYPE in the title too, right after the tier, so the
# board shows what KIND of work the card is at a glance: `[T2][排查] ...`.
#
# The type is DERIVED from the body (= see ``card_type``), and the title
# only DECLARES it, so the declaration and the derivation can be compared
# and a card that lies about its kind is reported. The tier is derived the
# same way, and for the same reason: a hand-set rating is a rating nobody
# checks.
#
# The four tags are the four kinds of work the board has:
#
#   [工单]  BUILD     a card that changes the tree. It owes an independent
#                     verdict, and it lands on main.
#   [审核]  REVIEW    a card that VERIFIES work somebody else already wrote
#                     and ends with a verdict. It owes no verdict of its own
#                     (= giving one IS its work), and it lands nothing.
#   [排查]  DIAGNOSE  a card that MEASURES the built product: it runs an
#                     instrument, waits, and reads a verdict out of the run.
#                     It reports a finding, and it lands nothing.
#   [调研]  RESEARCH  a card that READS and reports. It lands nothing.
#
# The tag is written in the board's own language (the board's cards are
# written in Chinese as often as in English), and the code carries the
# English name, so the two never drift apart.
TYPE_TAGS = {
    "工单": "build",
    "审核": "review",
    "排查": "diagnose",
    "调研": "research",
}
TYPE_TAG_NAMES = {v: k for k, v in TYPE_TAGS.items()}
TYPE_TAG_RE = re.compile(r"^\[(T[123])\]\s*\[(" + "|".join(TYPE_TAGS) + r")\]\s*")

# A cited rule is not a write. A path followed by a section marker
# ("AGENTS.md §7.3") is a reference, so it must not count as work scope.
CITATION_RE = re.compile(
    r"[A-Za-z0-9_./-]+\.(?:swift|md|sh|xcstrings|py|yml|yaml|plist)"
    r"[\"'`\s]*(?:§|section|rule|clause)\s*[0-9]+(?:\.[0-9]+)*"
)
SWIFT_RE = re.compile(r"(?:Sources|Tests)/[A-Za-z0-9_./-]+\.swift")
CODE_RE = re.compile(r"```[a-zA-Z]*\n(.*?)```", re.S)

# Work-shaped signals. Each names the WORK, not the prose: a short body for a
# big change is still a big change, and the tier must not reward prose.
#
# The SCOPE of the search matters as much as the pattern. A card that writes
# "Package.swift - NO CHANGE" in its MUST NOT CHANGE list is NOT doing a
# package-boundary change, and a card that names the string catalog in its
# LOCALIZATION section is often saying it adds no string. Measured: 15 of 47
# cards name Package.swift and 13 of them do it to forbid it, so a tier that
# reads the whole body called 24 cards package-boundary work and 20 more
# catalog rewrites. So every signal is read from the WORK.
#
# These three fire on the WORK and drive the TIER:
#   persistence    the card touches the store
#   new_subsystem  the card introduces a thing that did not exist
#   package_boundary  the card moves code across a package boundary
SIGNALS = {
    "persistence": re.compile(
        r"@Model|ModelContainer|Schema\(|versionedSchema|makeContainer|migration",
        re.I,
    ),
    "new_subsystem": re.compile(
        r"\bnew (?:feature|service|model|view|screen|pane|subsystem|package)\b", re.I
    ),
}

# These two are VERIFICATION KINDS, not blast radius, so they do not make a
# card T3. They are reported as notes instead: a live-app proof is extra
# evidence to gather, and the string catalog merges by key, so a card that
# adds one key is not a rewrite.
NOTES = {
    "live_app": re.compile(
        r"AX ?census|AXScrollBar|screenshot|screencapture|launch the app|app bundle"
        r"|Wenshu\.app|visual proof|on the running app|unified log|processIdentifier",
        re.I,
    ),
}

# An INSTRUMENT card measures the built product instead of writing it.
#
# The tier is derived from the ORDER (= the files the card writes), so a
# card that writes NO source file reads as the cheapest tier there is: it
# looks like a card that touches nothing. But the work of an instrument
# card is the ARM: it builds the app, launches it, waits, and reads a
# verdict out of the run. That work has a wall clock of its own, and the
# tier cannot see it.
#
# Measured 2026-10-30: the card `t_0cb4b46d` (launch-time crash triage)
# writes no source file, so the tier priced it T1 (= a 15-minute cap). It
# ran the arm twice on that cap and timed out both times (908 s and 906 s
# against a 900 s limit), and it only closed after a human raised the cap
# by hand. Its own gate names the arm's invocation, including the trial
# count and the per-trial wait, so the floor was written in the card the
# whole time.
#
# So an instrument card is a card that NAMES THE INSTRUMENT, and the
# vocabulary here is the instrument's own (= its script, its flags, its
# verdict), NOT the general English of "launching" and "measuring". A wide
# net was tried first and rejected: `"the arm"` alone matched 32 cards
# that had nothing to do with an arm, and `measure` matched 20 of 28
# cards on the board. The narrow net below matches 4 cards on a board of
# 166, and every one of the 4 is an instrument card.
INSTRUMENT = re.compile(
    r"launch_arm\.py"      # the instrument's own script
    r"|--arm\s+\w"         # the arm it selects
    r"|--trials\s+\d"      # how many trials it runs
    r"|vacuous\b"          # the verdict it renders
    r"|crash oracle",       # the oracle it matches on
    re.I,
)

# The package boundary is a PATH, not a word. The app's facade TYPE is named
# WenshuAgent, so matching the word calls a card that mentions the type a
# package-boundary change. Measured: the word fired on 11 cards and the path
# on 16, and 4 of the word's hits were the type.
PACKAGE_PATHS = ("Sources/WenshuAgent/", "Sources/WenshuData/")
# The file-shaped deep signals: they fire on a file the card WRITES.
CATALOG_RE = re.compile(r"\.xcstrings$|\.lproj/|Info\.plist$", re.I)
MANIFEST_RE = re.compile(r"^Package\.swift$")

# The expensive gate form. A card that DEMANDS a red-baseline comparison, or
# the whole suite, pays for it: measured, inside one tier, such a card
# averages 65.7 m over 3.44 runs against 46.4 m over 2.60 for one naming a
# narrow gate.
BASELINE_DEMAND_RE = re.compile(
    r"versus the baseline|against the baseline|compared to the baseline"
    r"|no NEW failing test",
    re.I,
)
FULL_SUITE_RE = re.compile(r"\bswift test\b(?![^\n]*--filter)")

# ---------------------------------------------------------------------------
# THE CARD-BODY VOCABULARY IS wave_gate.py's
#
# Two tools that read the same board must answer the same question about the
# same body: which files does this card write, and which files must it leave
# alone? They used to keep TWO COPIES of that vocabulary, and the copies
# drifted: this file normalized the heading and carried a seven-phrase
# exclusion set, wave_gate.py compared the raw heading with `in` against a
# five-phrase set, so "WHAT THIS CARD MUST NOT CHANGE" was a prohibition
# here and a WRITE there, on the same board, at the same moment. Measured
# on this board, 2026-10-25: the two tools read the same five cards in five
# different ways.
#
# The vocabulary, the heading reader, the citation pattern and the path
# pattern all live in wave_gate.py now, and the names below are this file's
# view of them (= the rest of this file, and its tests, keep reading the
# same way). One vocabulary, so the next phrase added to it cannot land in
# one tool and not the other.
EXCLUSION_SECTIONS = wave_gate.EXCLUSION_SECTIONS
sections = wave_gate.sections
# = wave_gate.files_of: the same (written, forbidden) sets, read the same way.
work_scope = wave_gate.files_of
work_text = wave_gate.work_text


def _is_exclusion(name: str) -> bool:
    """Whether a section's paths are files the card must NOT touch."""
    return wave_gate.is_exclusion(name)


# Sections that ROUTE the card instead of describing its work. A routing
# section is not a work section, so it is not charged against the body
# budget: measured, 46 of the board's bodies carry exactly 9 sections and
# T2 buys exactly 9, so charging the handoff section would push 8 T2 bodies
# over their own budget and make the tier wrong for cards that did nothing
# wrong. The body budget measures the RECIPE the worker has to absorb.
ROUTING_SECTIONS = {
    "review handoff",
}


def _is_routing(name: str) -> bool:
    """Whether a section routes the card instead of describing its work."""
    return name.strip().rstrip(":").lower() in ROUTING_SECTIONS


def work_sections(body: str) -> list[tuple[str, str]]:
    """The sections that describe the WORK (= all of them but the routing ones).

    A routing section names who reviews the card. It is not part of the
    recipe, so it is not charged against the body budget and its paths are
    not files the card writes.
    """
    return [(name, text) for name, text in sections(body) if not _is_routing(name)]


def work_length(body: str) -> int:
    """The body's length, minus its routing sections.

    A routing section is a fixed declaration (the reviewer's address), the
    same length on every card, so charging it against the body budget would
    push every card toward the cap for a cost the card's work does not carry.
    The budget measures the RECIPE the worker has to absorb.
    """
    routing = sum(
        len(text)
        for name, text in sections(body)
        if _is_routing(name)
    )
    return len(body) - routing


# --------------------------------------------------------------------------
# The review contract. It lives here because it is a contract on the CARD
# BODY, and this module is where the body is parsed.
#
# The obligation to get an independent verdict is DERIVED from the work the
# body describes, never hand-set, and it is independent of the difficulty
# tier: AGENTS.md 1.13 makes the tier the cost of a card and never the
# quality bar, so the tier cannot decide who reviews a card.
#
# A card owes a verdict when it writes CODE. Prose is already read against
# the spec by the dual-axis audit (AGENTS.md 7.4); code is not. Measured on
# board wenshu-par, 2026-10-26: of the done cards whose body promised files
# their branch does not contain, 5 wrote code and 0 wrote prose.
# --------------------------------------------------------------------------

# A body path that is prose, not code.
DOC_ROOTS = ("docs/",)
DOC_FILES = (
    "AGENTS.md", "OOB.md", "README.md", "CHANGELOG.md", "CONTEXT.md",
    ".hermes.md",
)

# The section a card body carries to name its reviewer.
HANDOFF_HEADING = "review handoff"

# reviewer="wenshu-review" or reviewer: wenshu-review
REVIEWER_RE = re.compile(r"reviewer\s*[=:]\s*[\"']?([A-Za-z0-9_.-]+)")


def is_documentation(path: str) -> bool:
    """Whether a path is prose (= the dual-axis audit already reads it)."""
    if path in DOC_FILES:
        return True
    return path.startswith(DOC_ROOTS)


def code_paths(body: str) -> list[str]:
    """The code files the body writes (= the work a reviewer must read)."""
    written, _forbidden = work_scope(body)
    return sorted(p for p in written if not is_documentation(p))


def review_required(body: str) -> tuple[bool, list[str]]:
    """Whether the body owes an independent verdict, and the code it writes."""
    code = code_paths(body)
    return bool(code), code


def review_required_for_kind(body: str, kind: str) -> tuple[bool, list[str]]:
    """Whether a card of this kind owes an independent verdict.

    Only a BUILD card does. The obligation used to be derived from ONE
    fact (= "the body writes code"), and that fact does not separate the
    kinds: a REVIEW card names the files under review (= it writes no
    code, but it reads a diff), and a DIAGNOSE or RESEARCH card reports a
    finding, which is not a diff and so has nothing to review.

    Measured 2026-10-30: the false positive this removes is the card
    `t_809184d0` (= a review of an orphaned commit), which the review
    contract called a self-review because the reviewer profile was also
    the only profile that had run it.
    """
    if kind == "build":
        code = code_paths(body)
        return bool(code), code
    return False, []


def normalized(name: str) -> str:
    """A heading reduced to comparable words."""
    return re.sub(r"[^a-z]+", " ", (name or "").strip().lower()).strip()


def handoff_text(body: str) -> str | None:
    """The text of the card's REVIEW HANDOFF section, or None."""
    for name, text in sections(body):
        if normalized(name) == HANDOFF_HEADING:
            return text
    return None


def named_reviewer(body: str) -> str | None:
    """The reviewer profile the handoff names, or None."""
    text = handoff_text(body)
    if not text:
        return None
    match = REVIEWER_RE.search(text)
    return match.group(1) if match else None


# The profile that reviews on this board. A card assigned to it is a review
# card, whatever the card's status is at this instant.
REVIEW_PROFILE = "wenshu-review"


def in_review_lane(card: dict) -> bool:
    """Whether this card is in the review lane.

    A card is a review card when it is ASSIGNED to the reviewer. That holds
    for the whole review: the handoff reassigns the card to the reviewer, the
    reviewer runs it, and the card stays with the reviewer until it is
    approved or sent back for changes.

    The card's status is NOT the lane. A card is handed off while it is
    "running" (the implementer calls the handoff), sits "review" while it
    waits for a reviewer, and goes back to "running" while the reviewer works
    on it -- so a status test sees the review lane only in the queue window
    and mistakes the review itself for implementation work.

    The reviewer named in the body's handoff counts too: a card that names
    a reviewer is a card that will be reviewed, whatever it is doing now.
    """
    assignee = str(card.get("assignee") or "").strip()
    if assignee == REVIEW_PROFILE:
        return True
    body = card.get("body") or ""
    reviewer = named_reviewer(body)
    if reviewer and assignee and assignee == reviewer:
        return True
    # A card can also be queued for review before it is reassigned.
    return str(card.get("status") or "") == "review" and not assignee


def review_contract_errors(
    body: str,
    assignee: str | None = None,
    kind: str | None = None,
    is_review_card: bool = False,
) -> list[str]:
    """Every way the body breaks the review contract.

    This is the CONTRACT half of the gate: what the card owes. Whether the
    verdict was actually given is the RECORD half, and that one needs the
    board (see Tools/wenshu-devtool/review_gate.py).

    ``kind`` is the card's TYPE (= build / review / diagnose / research),
    when the caller knows it. The obligation follows the TYPE: only a build
    card owes an independent verdict, because only a build card leaves a
    diff for a reviewer to read. A review card GIVES the verdict, and a
    diagnose or research card reports a finding.

    ``is_review_card`` says the card has no implementation phase (= every
    run on it carries the same profile). It is what keeps a review card from
    being reported as reviewing itself.
    """
    if kind is None:
        kind = card_type(body, None, "")
    required, code = review_required_for_kind(body, kind)
    errors: list[str] = []
    text = handoff_text(body)
    reviewer = named_reviewer(body)

    if text is not None:
        if reviewer is None:
            errors.append(
                "the REVIEW HANDOFF section names no reviewer profile "
                '(write reviewer="wenshu-review")'
            )
        elif assignee and reviewer == assignee and not is_review_card:
            errors.append(
                f"the REVIEW HANDOFF names the implementer profile ({reviewer}); "
                "a card cannot be reviewed by the profile that implemented it"
            )

    if required and text is None:
        errors.append(
            "the body writes code ("
            + ", ".join(code[:3])
            + ") but carries no REVIEW HANDOFF section"
        )
    return errors


def code_volume(body: str) -> int:
    """The characters of source the body inlines.

    A body that pastes the code to write is a body that has already done the
    design work, and a card that carries a full implementation in its prompt
    is a card the worker will re-derive line by line. Measured: the one-file
    card that inlined three whole type definitions took 58.8 m.
    """
    return sum(len(block) for block in CODE_RE.findall(body))


def areas_of(paths: list[str]) -> set[str]:
    """The distinct areas of the tree a card's written files live in.

    This is the blast radius the tier actually measures: a card that writes
    one file in one feature is narrow, and a card that writes files in three
    areas can break a caller it never named, so its narrow gate would not
    prove the change.

    An area is a DIRECTORY, so the file's name never becomes one. A path
    with fewer directories than the cut (= `Tests/WenshuMobileTests/
    GlassSurfaceTests.swift`, where the tree is two levels deep, not four)
    used to fall through to the file path itself, so ONE test file counted
    as its own area and a five-file card measured five areas = a T3 it did
    not earn. The cut is on the directory, so the depth of the tree
    decides how deep the area goes, not how many segments the path has.
    """
    areas: set[str] = set()
    for path in paths:
        parts = path.split("/")
        if (path.startswith("Sources/") or "/Tests/" in f"/{path}") and len(parts) > 2:
            # Drop the file's name, so the deepest segment is a directory.
            directory = "/".join(parts[:-1])
            areas.add("/".join(directory.split("/")[:3]))
        elif path.startswith(("Tools/", "Scripts/", "docs/")):
            areas.add(parts[0])
        else:
            areas.add(path)
    return areas


# The sections that carry the ORDER: the paths in them are the files the
# card WRITES. Every other section that names a path is naming CONTEXT
# (= the current state, a sibling's file, a reference). The tier rates the
# writing set, so this list is what decides the card's file counts.
#
# The heading vocabulary is shared with wave_gate.py on purpose: both tools
# must read the same card the same way, or a card can be narrow to one tool
# and wide to the other.
#
# **THE LIST IS THE CARD TEMPLATE'S OWN VOCABULARY, NOT A GUESS.** The
# template (= `wenshu-parallel-dev/templates/kanban-card-body.md`) fixes the
# sections a card has: GOAL, WHY, BASE, WHAT TO BUILD, MUST NOT CHANGE,
# LOCALIZATION, TESTS, EVIDENCE BUDGET, GATES, ACCEPTANCE, REVIEW HANDOFF.
# Of those, the writing ones are WHAT TO BUILD (= the code), TESTS (= the
# tests that prove it), LOCALIZATION (= the string catalog) and BASE (= the
# files the change starts from), and the list carries them plus the older
# names cards already in the board use.
#
# The list used to MISS `TESTS`, and that was not a rare case: measured over
# 173 real cards, 43 of them carry their test files under a `TESTS` heading,
# so the tier rated those cards by their source files alone and the
# slice gate could not see the test file that proves the work. A whitelist
# is a guess that has to be re-guessed for every new heading, so the fix is
# to take the headings from the template, which is a contract.
WRITE_SECTIONS = {
    # The template's writing sections.
    "what to build",
    "tests",
    "localization",
    "base",
    # The older names the cards already on the board use.
    "what to change",
    "the change",
    "the build",
    "the order",
    "write order",
    "landing order",
    "plan",
    "implementation",
    "files to write",
    "files to change",
}

# A file name with NO directory (= `ChatSessionViewModel.swift`). PATH_RE
# requires the leading `Sources/` / `Tests/`, so a bare name is invisible to
# it; the order's own files are named that way whenever the card already
# named the directory for its neighbours.
_BARE_FILE_RE = re.compile(r"[A-Za-z0-9_-]+\.(?:swift|xcstrings|md|py|sh)")


def _is_write_section(name: str) -> bool:
    """Whether a section carries the card's ORDER (= the files it writes)."""
    return name.strip().rstrip(":").strip().lower() in WRITE_SECTIONS


def order_paths(body: str) -> set[str]:
    """The files the card's ORDER names (= the paths in its writing sections).

    A card is an order: the paths in its writing sections are the files it
    writes, and the paths elsewhere in the body are CONTEXT (= what the
    current state looks like, what a sibling card owns, what a sibling
    commit touched). Rating a card on every path it MENTIONS charges it for
    work it never asked for: measured on board wenshu-par, 2026-10-29, card
    t_6876ec70 wrote two files and was rated T3 because its CURRENT STATE
    section described seven others, and t_dae9ab0d wrote none and was rated
    T3 because the body named a package boundary in passing.

    So the tier rates the WRITING SET, and a card whose writing set cannot be
    read (= no writing section at all) falls back to the whole body, so an
    unparseable card never earns a cheaper tier by being unreadable.
    """
    written, _forbidden = work_scope(body)
    order: set[str] = set()
    bare_only: set[str] = set()
    found = False
    for name, text in sections(body):
        if _is_routing(name) or _is_exclusion(name) or wave_gate.is_read_only(name):
            continue
        if not _is_write_section(name):
            continue
        found = True
        stripped = wave_gate.CITATION_RE.sub("", text)
        qualified = set(wave_gate.PATH_RE.findall(stripped))
        order |= qualified
        # A bare file name (= `ChatSessionViewModel.swift`, no directory) is
        # NOT a PATH_RE match, because PATH_RE requires the leading
        # `Sources/` / `Tests/`. A card's order names its file that way
        # whenever the file is in the same directory as the ones already
        # named, so counting only PATH_RE would UNDER-count the order and
        # rate the card by the files it merely mentions. The bare name is
        # resolved against the qualified paths (= same basename) so it
        # counts as the file it is, not as a nameless string.
        bare = set(_BARE_FILE_RE.findall(stripped))
        for name_only in bare:
            resolved = next(
                (p for p in qualified if p.rsplit("/", 1)[-1] == name_only),
                None,
            )
            if resolved is not None:
                # The bare name IS a qualified path already in the set: add
                # it once, so it does not count as a second file.
                order.add(resolved)
                continue
            # An unresolvable bare name (= no qualified path shares its
            # basename) cannot be placed in the tree, so it counts as a
            # FILE but not as an AREA: counting it as an area would rate the
            # card by a directory we do not know. Measured 2026-10-29, card
            # t_222d0c87 named `SidebarInline.swift` next to three qualified
            # paths in two areas, and the unresolved name pushed it over the
            # three-area T3 line.
            bare_only.add(name_only)
    if not found:
        # No writing section: fall back to what the body writes anywhere, so
        # the tier of an unreadable card is the CONSERVATIVE one.
        return written
    return (order | bare_only) or written


def signals(body: str) -> dict:
    """The work-shaped signals a tier is derived from.

    The file counts come from the ORDER (= the writing sections), not from
    every path the body mentions: a card that describes the current state
    must not be charged a deeper tier for the files the current state
    happens to contain. See ``order_paths``.
    """
    written, forbidden = work_scope(body)
    order = order_paths(body)
    # A bare file name (= `SidebarInline.swift`) has no directory, so it is
    # neither a source file nor an area of the tree: it counts as a FILE the
    # card touches, but the tier counts sources and areas, so an
    # unplaceable name cannot inflate either.
    qualified = {p for p in order if "/" in p}
    sources = sorted(p for p in qualified if p.startswith("Sources/") and p.endswith(".swift"))
    # A TEST FILE IS A PATH WITH A `Tests/` SEGMENT, not a path that starts
    # with `Tests/`: the packages nest their test target inside the package
    # (= `Sources/WenshuAgent/Tests/WenshuAgentTests/...`), so a rule that
    # only counted the top-level test target read those files as source.
    tests = sorted(p for p in qualified if "/Tests/" in f"/{p}" and p.endswith(".swift"))
    text = work_text(body)
    return {
        "files": sorted(written),
        "order_files": sorted(order),
        "forbidden": sorted(forbidden),
        "n_files": len(order),
        "n_sources": len(sources),
        "n_tests": len(tests),
        "n_areas": len(areas_of(sorted(qualified))),
        "code": code_volume(body),
        "persistence": bool(SIGNALS["persistence"].search(text)),
        "new_subsystem": bool(SIGNALS["new_subsystem"].search(text)),
        "package_boundary": any(p.startswith(PACKAGE_PATHS) for p in qualified)
        or any(MANIFEST_RE.match(p) for p in qualified),
        "live_app": bool(NOTES["live_app"].search(text)),
        "instrument": bool(INSTRUMENT.search(text)),
        "catalog": any(CATALOG_RE.search(p) for p in qualified),
    }


def tier_of(body: str) -> tuple[str, list[str]]:
    """The tier a card body earns, and the reasons that decided it.

    The inputs are the BLAST RADIUS and the RISK. They are never the body's
    length and never the gates the body asks for: the tier CHANGES the cap
    and the gate, so a tier derived from either would be circular.

    The file count is a blast-radius input, NOT a cost input. Measured as the
    correlation with minutes per card, the number of files a card touches is
    r = +0.068 (= nothing), while the number of body sections is +0.589. So
    the tier does not exist to guess how long a card takes; it exists to
    decide how many suites have to prove it.
    """
    sig = signals(body)
    deep = []
    if sig["persistence"]:
        deep.append("persistence")
    if sig["new_subsystem"]:
        deep.append("a new subsystem")
    if sig["package_boundary"]:
        deep.append("a package boundary")
    if sig["n_sources"] >= 6:
        deep.append(f"{sig['n_sources']} source files")
    if sig["n_areas"] >= 3:
        deep.append(f"{sig['n_areas']} areas of the tree")
    if sig["code"] >= 3000:
        deep.append(f"{sig['code']} chars of code inlined in the body")
    if deep:
        return "T3", deep

    # An instrument card is BLOCKING, so it cannot be T1: T1 is the tier
    # for a card that touches almost nothing, and an instrument card runs
    # the built product for a wall clock of its own. It is not DEEP, so it
    # does not become T3: it writes no source file, so its blast radius is
    # small even though its clock is long. T2 (= 25m) is where it belongs.
    blocking = [
        name
        for name in ("persistence", "live_app", "new_subsystem", "package_boundary")
        if sig[name]
    ]
    if sig["instrument"]:
        blocking.append("an instrument to run")
    if (
        sig["n_sources"] <= 1
        and sig["n_files"] <= 2
        and sig["code"] < 800
        and not blocking
    ):
        return "T1", [
            f"{sig['n_sources']} source file, {sig['n_tests']} test file(s)",
            "no persistence, no live-app proof, no new subsystem",
        ]
    reasons = [
        f"{sig['n_sources']} source file(s), {sig['n_tests']} test file(s)",
    ]
    if sig["instrument"]:
        # Say WHY the card is not T1. A card that writes no source file
        # would otherwise read as the cheapest tier there is, and the
        # reason it is not is invisible: it runs an instrument.
        reasons.append("it runs an instrument, so it has a clock of its own")
    else:
        reasons.append("no deep-work signal")
    return "T2", reasons


def gate_width(body: str) -> str:
    """The gate the body asks for: "narrow", "wide", or "unstated".

    This is the lever that carries the time, not the cap. Measured, INSIDE
    one tier: a body asking for a red-baseline comparison averaged 65.7 m
    over 3.44 runs against 46.4 m over 2.60 for one naming a narrow gate.
    A narrow body carries a narrow gate, so the tier's gate is the body's
    gate, and this reads which one the card brought.
    """
    if BASELINE_DEMAND_RE.search(body) or FULL_SUITE_RE.search(body):
        return "wide"
    if re.search(r"\bswift test\b", body, re.I):
        return "narrow"
    return "unstated"


def declared_tier(title: str) -> str | None:
    """The tier the card title claims, or None."""
    match = TITLE_RE.match(title or "")
    return match.group(1) if match else None


def declared_type(title: str) -> str | None:
    """The card type the title claims, or None.

    The title carries the tier first and the type second (= `[T2][排查] ...`),
    so a title that names only a tier declares no type, and the type is
    derived from the body alone.
    """
    match = TYPE_TAG_RE.match(title or "")
    if not match:
        return None
    return TYPE_TAGS.get(match.group(2))


def _is_subject(card: dict) -> bool:
    """Whether this card was created on or after the cap contract's epoch.

    A rule that starts on a date does not look back: the cards created
    before it were dispatched under a flow that did not ask for the thing
    the rule asks for, and they have all finished or been archived. So the
    finding is scoped to the cards a session could still dispatch.
    """
    try:
        created = int(card.get("created_at") or 0)
    except (TypeError, ValueError):
        return False
    return created >= CAP_CONTRACT_FROM


# The INSTRUMENT LANE has its own clock, the way the review lane does.
#
# A card that runs an instrument spends most of its time WAITING for the
# instrument, and the wait is written in the card: the invocation names
# the trial count and the per-trial wait, so the wall clock the card
# cannot avoid is DERIVABLE instead of guessed.
#
# Measured 2026-10-30: the launch-time crash triage card
# (`t_0cb4b46d`) runs `launch_arm.py --trials 6 --wait 95`, so the arm
# alone costs 570 s of waiting before the card has read a single line.
# The tier priced that card T1 (= a 900 s cap), it timed out twice
# (908 s and 906 s against the 900 s limit), and it closed only after a
# human raised the cap by hand.
#
# So the instrument's own wait is a FLOOR on the cap, the way the review
# lane's 3600 s is a floor: a card carrying less dies on the clock
# before its instrument can report. A card carrying more is generous,
# not wrong, so the floor is what this gate checks.
#
# The floor is the arm's wait PLUS the tier's own runtime, because the
# wait is EXTRA time: the tier's runtime covers the build, the reading
# and the gate, and an instrument card spends all of that AND THEN waits
# for the arm to report. So the floor is the tier's runtime with the
# arm's wait added on, and there is no second magic number here.
_TRIALS_RE = re.compile(r"--trials\s+(\d+)")
_WAIT_RE = re.compile(r"--wait\s+(\d+)")


def instrument_wait(body: str) -> int:
    """The wall clock the arm itself spends, in seconds.

    Zero when the card names no instrument, or names one whose wait the
    card does not spell out.
    """
    trials = _TRIALS_RE.search(body)
    wait = _WAIT_RE.search(body)
    if not (trials and wait):
        return 0
    try:
        arm = int(trials.group(1)) * int(wait.group(1))
    except ValueError:
        return 0
    return arm if arm > 0 else 0


def instrument_floor(body: str, tier_runtime: int) -> int:
    """The wall clock an instrument card cannot avoid, in seconds.

    Zero when the card names no instrument. The floor is a floor, not a
    cap: it says what the card MUST be given, and a card that asks for
    more is fine.
    """
    arm = instrument_wait(body)
    if not arm:
        return 0
    return int(tier_runtime) + arm


# ===========================================================================
# THE FOUR CARD TYPES
# ===========================================================================
#
# A card is one of four kinds of work, and the kind decides what the card
# OWES and what it COSTS. The kinds are not the tier: the tier is the blast
# radius (= how many suites must prove the claim), and a card can be any
# kind at any tier. The kinds are what the card is FOR.
#
#   BUILD     a card that changes the tree. It owes an independent verdict,
#             because a reviewer has to read the diff, and it lands on main.
#   REVIEW    a card that VERIFIES work somebody else already wrote and
#             ends with a verdict. It owes no verdict of its own (= giving
#             one IS its work), and it lands nothing.
#   DIAGNOSE  a card that MEASURES the built product: it runs an
#             instrument, waits, and reads a verdict out of the run. It owes
#             no verdict and it lands nothing; it reports a finding.
#   RESEARCH  a card that READS and reports. It owes no verdict and it
#             lands nothing.
#
# WHY THE KINDS MATTER, MEASURED 2026-10-30: the review obligation used
# to be derived from ONE fact (= "the body writes code"), and that fact
# does not separate the kinds. A card that runs an instrument and reports
# a finding carries no code, so it was correctly not obliged to owe a
# verdict; but the same rule made a REVIEW card look like a build card,
# and a review card that names the reviewer profile as its own profile was
# reported as reviewing itself (= the false positive the merge gate
# refused, measured on card t_809184d0).
#
# The kinds are DERIVED, never hand-set, and each one is derived from a
# fact that can be checked:
#
#   REVIEW    the body says what it is for (= "A verdict on <sha>"), or the
#             card has no implementation phase (= every run on it carries
#             the SAME profile). The second half needs the board, so it is
#             read there; the first half is in the body, so a card that
#             has not run yet still knows what it is.
#   DIAGNOSE  the body names an instrument (= it runs the arm, the probe,
#             the measurement).
#   BUILD     the body writes code.
#   RESEARCH  none of the above: the body reads and reports.
#
# The order matters: a review card can also run an instrument (a reviewer
# re-runs the gates), and a review card's body names files (the ones under
# review), so REVIEW is decided FIRST.

CARD_TYPES = ("build", "review", "diagnose", "research")

# The REVIEW card's own claim. It is not a keyword soup: it is the first
# sentence of WHAT TO BUILD, and it names the commit under review. Measured
# on the two boards (176 cards), the two cards that carry it are exactly
# the two cards the board says have no implementation phase, and no other
# card carries it (= zero false positives).
VERDICT_CLAIM_RE = re.compile(r"^\**\s*A verdict on\b", re.I)


def declares_verdict(body: str) -> bool:
    """Whether the body says, in its own first claim, that it gives a verdict.

    The claim is read from WHAT TO BUILD (= the section that says what the
    card is for), and only its FIRST paragraph, so a later paragraph that
    mentions a verdict cannot turn a build card into a review card.
    """
    for name, text in sections(body):
        if normalized(name) != "what to build":
            continue
        # The section's text carries its own heading line, so the claim is
        # the first paragraph after it (= a heading cannot be the claim).
        lines = text.splitlines()
        if lines and lines[0].lstrip().startswith("#"):
            lines = lines[1:]
        body_text = "\n".join(lines)
        for para in body_text.split("\n\n"):
            claim = para.strip()
            if claim:
                return bool(VERDICT_CLAIM_RE.match(claim))
    return False


def card_type(body: str, runs: list[dict] | None = None, title: str = "") -> str:
    """The kind of work this card is, derived from what it says and what it did.

    ``runs`` is the card's run history, when the board has it. It is what
    tells a review card from a build card that is sitting in the review
    lane right now: a review card has no implementation phase (= every run
    on it carries the same profile), so the runs all carry the reviewer's
    profile and nothing else.

    ``title`` is the card's title, when it carries a type tag. A card that
    declares its kind is taken at its word, because the declaration and the
    derivation are compared elsewhere (= the conflict is reported), and a
    declaration is what the board's own readers see.

    Without the board and without a declaration, a card is judged on its
    body alone, and a card that has not declared a verdict is a build card
    or a research card.
    """
    declared = declared_type(title)
    if declared:
        return declared
    if declares_verdict(body):
        return "review"
    if runs:
        profiles = {str(r.get("profile") or "") for r in runs if r.get("profile")}
        if len(profiles) == 1 and REVIEW_PROFILE in profiles:
            # No implementation phase: the card IS the review.
            return "review"
    if INSTRUMENT.search(work_text(body)):
        return "diagnose"
    if code_paths(body):
        return "build"
    return "research"


def type_owes_verdict(kind: str) -> bool:
    """Whether a card of this kind owes an independent verdict.

    Only a build card does. A review card GIVES the verdict (= that is its
    work), and a diagnose or research card reports a finding, which is not
    a diff and so has nothing to review.
    """
    return kind == "build"


def find_contract_errors(card: dict) -> list[str]:
    """Every way the card CONTRADICTS the tier it earns.

    An error is a contradiction between the card and the contract (= the
    title's tier tag is wrong, = the runtime cap is not the tier's, = the
    body is over the tier's budget, = the evidence budget is missing).
    """
    body = card.get("body") or ""
    title = card.get("title") or ""
    tier, _reasons = tier_of(body)
    contract = TIERS[tier]
    errors: list[str] = []

    claimed = declared_tier(title)
    if claimed is None:
        errors.append(f"title carries no tier tag (expected [{tier}])")
    elif claimed != tier:
        errors.append(f"title says {claimed}, the body earns {tier}")

    # The card's TYPE is derived from its body (= and from the board, when
    # the board is available), and the title may DECLARE it. A declaration
    # that contradicts the derivation is a contradiction, the same way a
    # wrong cap is: the card says one thing and the body says another.
    kind = card_type(body, card.get("runs"), str(card.get("title") or ""))
    declared = declared_type(str(card.get("title") or ""))
    derived = card_type(body, card.get("runs"), "")
    if declared and declared != derived:
        errors.append(
            f"the title says the card is {TYPE_TAG_NAMES[declared]} (= {declared}), "
            f"but its body makes it {TYPE_TAG_NAMES[derived]} (= {derived})"
        )

    runtime = card.get("max_runtime_seconds")
    if runtime is None:
        # A card with NO cap has no fuse, so it is a contradiction with the
        # tier the same way a wrong cap is: the tier says how long the work
        # gets, and a card that carries no time at all carries no answer.
        #
        # Measured 2026-10-30: the newest card on the board
        # (`t_c2483505`) was created with no cap at all, and it was running
        # with no fuse on it. The cards created before the epoch were
        # dispatched under a flow that did not ask for a cap, and they have
        # all finished or been archived, so the rule does not look back.
        if _is_subject(card):
            errors.append(
                f"the card carries no runtime cap, so it has no fuse: tier {tier} "
                f"buys {contract['runtime']}s ({contract['runtime_text']}), and a "
                "card without a cap runs until the quota wall, not until its "
                "work is done"
            )
    else:
        # A card in the review lane runs the REVIEW's work, so it is judged
        # against the review lane's cap (= the lane's own measured
        # distribution), not against the tier's implementation cap.
        #
        # The lane is WHO IS ASSIGNED, not the card's momentary status. A
        # review card is assigned to the reviewer the moment it is handed off
        # and stays assigned to it for the whole review, so the reviewer is
        # the durable signal. Keying on status == "review" only covered the
        # QUEUED window: a card under review (status "running") was judged as
        # implementation work, which both flagged a generous review cap as a
        # tier violation and MISSED a review whose cap was under the floor --
        # the exact card that dies on the clock and hands back no verdict.
        # A REVIEW card runs the REVIEW's work (= re-read the diff, re-derive
        # the acceptance, re-run the gates), which is slower than the
        # implementation it audits, so it is judged against the review
        # lane's floor. The TYPE decides that, not the card's status at this
        # instant: a review card that has not been picked up yet still owes
        # the review's clock, and a build card that happens to be sitting in
        # the review queue still runs the implementation's clock.
        if kind == "review" or in_review_lane(card):
            if runtime < REVIEW_LANE_CAP_FLOOR:
                errors.append(
                    f"runtime cap {runtime}s, the review lane needs at least "
                    f"{REVIEW_LANE_CAP_FLOOR}s (= a review that runs out of "
                    f"clock hands back no verdict)"
                )
        else:
            # The INSTRUMENT lane has its own floor, the way the review
            # lane does. The floor is DERIVED from the card (= the arm's
            # own trial count and per-trial wait), so a card that spells
            # out a long arm cannot be priced under it. A card carrying
            # more than the floor is generous, not wrong.
            floor = instrument_floor(body, contract["runtime"])
            if floor:
                # An instrument card is judged against its FLOOR, not
                # against the tier's exact cap: the tier's cap is fitted
                # to an implementation run, and an instrument card is not
                # one. A card carrying less than the floor dies on the
                # clock before its instrument can report; a card carrying
                # more is generous, not wrong (= the review lane's rule).
                if runtime < floor:
                    errors.append(
                        f"runtime cap {runtime}s, the instrument needs at least "
                        f"{floor}s (= the arm's own wait plus the build and the "
                        f"reading around it), and a card that runs out of clock "
                        f"hands back no verdict"
                    )
            elif runtime != contract["runtime"]:
                errors.append(
                    f"runtime cap {runtime}s, tier {tier} buys {contract['runtime']}s "
                    f"({contract['runtime_text']})"
                )

    if work_length(body) > contract["body_max"]:
        errors.append(
            f"body is {work_length(body)} chars, tier {tier} buys {contract['body_max']}"
        )

    body_sections = len(work_sections(body))
    if body_sections > contract["sections_max"]:
        errors.append(
            f"body has {body_sections} sections, tier {tier} buys "
            f"{contract['sections_max']}; a body over its budget is a body "
            f"that should be two cards"
        )

    if tier == "T1":
        if BASELINE_DEMAND_RE.search(body):
            errors.append("T1 must not demand a red-baseline comparison")
        if FULL_SUITE_RE.search(body):
            errors.append("T1 must name a filtered suite, not the whole suite")

    # The evidence budget rides with the tier because the tier already
    # prices the card: the tier says how long a card may run, the budget
    # says how much it may READ. Both are contracts the card states before
    # a worker touches it.
    #
    # Only cards created on or after the contract epoch are judged. The
    # cards already on the board were dispatched under the old contract,
    # and rewriting them is not this tool's business. The rule is the same
    # one the review gate uses (REVIEW_CONTRACT_FROM).
    if effort_budget_gate.is_subject(card.get("created_at")):
        for finding in effort_budget_gate.contract_errors(card):
            errors.append(finding)

    return errors


def find_notes(card: dict) -> list[str]:
    """The cost warnings the tier PERMITS (= not a disagreement).

    A note is a fact about the work that the tier already pays for: a card
    that writes the string catalog still merges by key, a card that touches
    several areas is still priced by its tier. The notes are printed with
    the findings so the reader sees the whole picture, but they are NOT
    contradictions and they never fail the check.
    """
    body = card.get("body") or ""
    tier, _reasons = tier_of(body)
    notes: list[str] = []

    if tier == "T2" and BASELINE_DEMAND_RE.search(body):
        notes.append(
            "T2 demands a red-baseline comparison; the measured cost of that "
            "demand, inside one tier, is 65.7 m over 3.44 runs against "
            "46.4 m over 2.60 for a narrow gate"
        )

    sig = signals(body)
    if sig["live_app"] and tier != "T3":
        notes.append(
            "this card also needs a live-app proof (a screenshot or an AX "
            "census); that is extra evidence to gather, not a deeper tier"
        )
    if sig["catalog"]:
        notes.append(
            "this card writes the string catalog, which merges by key; it is "
            "not a catalog rewrite on its own"
        )
    if sig["n_areas"] >= 2 and tier != "T3":
        notes.append(
            f"this card writes {sig['n_areas']} areas of the tree "
            f"({', '.join(sorted(areas_of(sig['files'])))})"
        )

    return notes


def find_errors(card: dict) -> list[str]:
    """Every way the card disagrees with the tier it earns.

    An error is a contradiction between the card and the contract. A note is
    a cost warning that the tier permits.

    The two travel in ONE list on purpose (= the reader sees the whole
    picture), and the two verdicts are separated by FUNCTION: `find_errors`
    is what the reader prints, `find_contract_errors` is what the check
    counts. A note that rode in the check's list would be counted as a
    contradiction, so a card that writes the string catalog (= a note, = the
    catalog merges by key) would read as a tier mismatch and fail the check
    it passes.
    """
    return find_contract_errors(card) + find_notes(card)


def kanban_cards(board: str | None = None) -> list[dict] | None:
    """Every card on the board, or None when the board could not be read.

    None and [] are DIFFERENT facts. [] is a board that was read and holds
    no cards; None is a board this tool never read at all. The two used to
    be the same value, so a board that could not be read looked exactly like
    a clean board and the sweep reported an agreement it never verified.

    None is returned for every way the read can fail: the CLI refusing (a
    mistyped board slug, a missing binary), a payload that is not a card
    list, and a payload that is not JSON. The shape matches the review
    gate's board reader, so the two gates read a board the same way.
    """
    args = ["hermes", "kanban"]
    if board:
        args += ["--board", board]
    args += ["list", "--json"]
    try:
        out = subprocess.run(args, cwd=REPO, capture_output=True, text=True)
    except OSError as exc:
        print(f"the board could not be read: {exc}", file=sys.stderr)
        return None
    if out.returncode != 0:
        detail = out.stderr.strip() or out.stdout.strip()
        print(f"the board could not be read: {detail}", file=sys.stderr)
        return None
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        print("the board could not be read: the CLI printed no card list", file=sys.stderr)
        return None
    if isinstance(data, dict):
        data = data.get("tasks", [])
    if not isinstance(data, list):
        print("the board could not be read: the CLI printed no card list", file=sys.stderr)
        return None
    return list(data)


def card_from_file(path: str) -> dict:
    """A card-shaped dict from a body file, for classifying a draft."""
    body = Path(path).read_text(encoding="utf-8")
    return {"id": path, "title": "", "body": body, "status": "draft"}


def report(card: dict) -> dict:
    """The tier of one card, its reasons, and every disagreement."""
    body = card.get("body") or ""
    tier, reasons = tier_of(body)
    contract = TIERS[tier]
    return {
        "id": card.get("id"),
        "title": card.get("title"),
        "status": card.get("status"),
        "tier": tier,
        "label": contract["label"],
        "reasons": reasons,
        "declared_tier": declared_tier(card.get("title") or ""),
        "kind": card_type(body, card.get("runs"), card.get("title") or ""),
        "declared_kind": declared_type(card.get("title") or ""),
        "runtime_seconds": card.get("max_runtime_seconds"),
        "runtime_text": contract["runtime_text"],
        "retries": contract["retries"],
        "body_max": contract["body_max"],
        "body_len": work_length(body),
        "body_sections": len(sections(body)),
        "sections_max": contract["sections_max"],
        "gate": contract["gate"],
        "gate_width": gate_width(body),
        "findings": find_errors(card),
        "errors": find_contract_errors(card),
    }


def print_card(row: dict) -> None:
    print(f"  {row['id']}  {row['tier']} ({row['label']})  {row['title']}")
    print(
        f"      cap {row['runtime_text']}  retries {row['retries']}  "
        f"body {row['body_len']}/{row['body_max']}  "
        f"gate {row['gate_width']}  declared {row['declared_tier'] or '-'}"
    )
    kind = row.get("kind")
    if kind:
        print(
            f"      kind {kind} ({TYPE_TAG_NAMES.get(kind, kind)})"
            f"  declared {row.get('declared_kind') or '-'}"
        )
    print(f"      gate: {row['gate']}")
    for reason in row["reasons"]:
        print(f"      because: {reason}")
    for finding in row["findings"]:
        print(f"      ! {finding}")
    for note in row.get("notes", []):
        print(f"      - {note}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cards", nargs="*", help="card ids; default = every card")
    parser.add_argument("--body", help="classify a card body from a file")
    parser.add_argument("--live", action="store_true", help="only cards that are not done")
    parser.add_argument("--check", action="store_true", help="report tier mismatches")
    parser.add_argument("--plan", action="store_true", help="print the tier contract table")
    parser.add_argument("--board", help="board slug; default = the current board")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()

    if args.plan:
        print("=== wenshu ticket tier contract ===")
        for tier, contract in TIERS.items():
            print(f"\n{tier} ({contract['label']})")
            print(f"  runtime cap   --max-runtime {contract['runtime_text']}")
            print(f"  retry budget  --max-retries {contract['retries']}")
            print(f"  body budget   {contract['body_max']} chars, {contract['sections_max']} sections")
            print(f"  gate          {contract['gate']}")
        print("\nThe tier is derived from the card body by this script. The title")
        print("carries it as [T1] / [T2] / [T3] so `kanban list` shows the rating.")
        return 0

    if args.body:
        cards = [card_from_file(args.body)]
    else:
        cards = kanban_cards(args.board)
        if cards is None:
            # The reader already said why, on stderr. An unreadable board is
            # not an empty board: the sweep refuses instead of reporting an
            # agreement over cards it never read.
            if not args.json:
                print("=== the board could not be read ===")
            return 2
        if args.live:
            cards = [c for c in cards if c.get("status") != "done"]
        if args.cards:
            wanted = set(args.cards)
            cards = [c for c in cards if c.get("id") in wanted]

    rows = [report(card) for card in cards]

    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        for row in rows:
            print_card(row)
            print()

    if args.check:
        # The check counts CONTRADICTIONS, not notes. A note is a cost the
        # tier already pays for (= the string catalog merges by key, = a
        # multi-area card is priced by its tier), so a card whose only
        # finding is a note agrees with its tier.
        errors = [r for r in rows if r["errors"]]
        if errors:
            print(f"=== {len(errors)} card(s) disagree with their tier ===")
            for row in errors:
                print(f"  {row['id']}  {row['title']}")
                for finding in row["errors"]:
                    print(f"      ! {finding}")
            return 1
        print("=== every card agrees with its tier ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
