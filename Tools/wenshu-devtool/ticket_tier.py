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

# A card carries its tier in the title, so `kanban list` shows the rating at a
# glance and the worker reads it without hunting for it.
TITLE_RE = re.compile(r"^\[(T[123])\]\s*")

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


# The profile that reviews. A card assigned to it is a review card, whatever
# the card's status is at this instant.
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
    """
    assignee = str(card.get("assignee") or "").strip()
    if assignee == REVIEW_PROFILE:
        return True
    # A card can also be queued for review before it is reassigned.
    return str(card.get("status") or "") == "review" and not assignee


def review_contract_errors(body: str, assignee: str | None = None) -> list[str]:
    """Every way the body breaks the review contract.

    This is the CONTRACT half of the gate: what the card owes. Whether the
    verdict was actually given is the RECORD half, and that one needs the
    board (see Tools/wenshu-devtool/review_gate.py).
    """
    required, code = review_required(body)
    errors: list[str] = []
    text = handoff_text(body)
    reviewer = named_reviewer(body)

    if text is not None:
        if reviewer is None:
            errors.append(
                "the REVIEW HANDOFF section names no reviewer profile "
                '(write reviewer="wenshu-review")'
            )
        elif assignee and reviewer == assignee:
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
    """
    areas: set[str] = set()
    for path in paths:
        parts = path.split("/")
        if path.startswith(("Sources/", "Tests/")) and len(parts) > 2:
            areas.add("/".join(parts[:3]))
        elif path.startswith(("Tools/", "Scripts/", "docs/")):
            areas.add(parts[0])
        else:
            areas.add(path)
    return areas


def signals(body: str) -> dict:
    """The work-shaped signals a tier is derived from."""
    written, forbidden = work_scope(body)
    sources = sorted(p for p in written if p.startswith("Sources/") and p.endswith(".swift"))
    tests = sorted(p for p in written if p.startswith("Tests/") and p.endswith(".swift"))
    text = work_text(body)
    return {
        "files": sorted(written),
        "forbidden": sorted(forbidden),
        "n_files": len(written),
        "n_sources": len(sources),
        "n_tests": len(tests),
        "n_areas": len(areas_of(sorted(written))),
        "code": code_volume(body),
        "persistence": bool(SIGNALS["persistence"].search(text)),
        "new_subsystem": bool(SIGNALS["new_subsystem"].search(text)),
        "package_boundary": any(p.startswith(PACKAGE_PATHS) for p in written)
        or any(MANIFEST_RE.match(p) for p in written),
        "live_app": bool(NOTES["live_app"].search(text)),
        "catalog": any(CATALOG_RE.search(p) for p in written),
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

    blocking = [
        name
        for name in ("persistence", "live_app", "new_subsystem", "package_boundary")
        if sig[name]
    ]
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
    return "T2", [
        f"{sig['n_sources']} source file(s), {sig['n_tests']} test file(s)",
        "no deep-work signal",
    ]


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

    runtime = card.get("max_runtime_seconds")
    if runtime is not None:
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
        if in_review_lane(card):
            if runtime < REVIEW_LANE_CAP_FLOOR:
                errors.append(
                    f"runtime cap {runtime}s, the review lane needs at least "
                    f"{REVIEW_LANE_CAP_FLOOR}s (= a review that runs out of "
                    f"clock hands back no verdict)"
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
