#!/usr/bin/env python3
"""
ticket_tier.py - the difficulty tier of a wenshu card, and the contract the tier buys.

A card's tier is DERIVED from the work its body describes, never hand-set:

  T1  trivial   one or two files, no persistence, no live-app proof, no new subsystem
  T2  standard  the default
  T3  deep      persistence, a new subsystem, a package boundary, or a wide blast radius

The tier sets four things and nothing else:

  runtime cap   the board's --max-runtime for the card
  retry budget  the board's --max-retries for the card
  gate width    which suites prove the claim (= T1 names ONE filtered suite)
  body budget   how long the card body may be

WHY THIS EXISTS (measured on board wenshu-par, 41 done cards, 2026-10-22):

  34.4 h of worker time, of which 6.9 h (20%) sat in a run that FINISHED. The
  other 27.5 h (80%) sat in runs that timed out, were reclaimed, or crashed, and
  the cards averaged 2.6 runs each. The gates themselves are cheap: an
  incremental `swift build` is 0.73 s, the full suite is 66 s, double-axis.sh
  is 0.36 s. The hours went into REPEATED attempts, not into verification.

  46 runs hit the 30-minute cap and were killed, and 46 of the 46 were cards
  that had ALREADY been given a bigger budget than the work needed. A card
  that times out is not slow, it is mis-sized: the cap did not match the work,
  so the worker spent the whole budget and the card was re-dispatched to spend
  it again.

  Two measured signals separate the work from the prose:
    - a body demanding a red-baseline comparison averages 83.1 m over 4.00
      runs, against 52.4 m over 2.97 runs for a body that does not, WITHIN the
      same tier;
    - a body naming a runtime surface (= AppKit, AX census, a screenshot, a
      launch) is a card that cannot be proven by a build alone.

  So the tier narrows the gate to the cheapest proof of the claim and sizes
  the cap to the work. A stuck card then dies cheap instead of burning a full
  cap and starting over from zero.

  The tier never skips the dual-axis review (AGENTS.md rule 1.10). It narrows
  the gate to the cheapest proof, and it never marks a test as skipped.

Usage:
    ticket_tier.py <card-id>...      classify cards (reads the board)
    ticket_tier.py --body FILE       classify a card body from a file
    ticket_tier.py --live            classify every card that is not done
    ticket_tier.py --check           report tier mismatches (exit 1 on any error)
    ticket_tier.py --plan            print the tier contract table
    ticket_tier.py --json            machine-readable output

Exit code 0 = pass, 1 = at least one error.
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

REPO = "/Volumes/ANAN/Engineering/wenshu"

# The contract each tier buys.
#
# The caps are fitted to the measured duration of a run that FINISHED, per
# tier, so a card that does the work never loses to its own cap:
#
#   tier  successful runs (m)          cap    headroom
#   T1    max 10.5                      15m    1.43x
#   T2    max 16.0                      25m    1.56x
#   T3    p50 20.3, p75 26.2, max 39.2  45m    1.15x on the max
#
# The retry budget is the board's --max-retries, which trips the breaker when
# the CONSECUTIVE failure count reaches it (a success resets the count). It is
# fitted to the longest failure streak the board has actually produced per
# tier, plus one: measured worst streaks were T1 1, T2 2, T3 3, so the budgets
# are 2 / 3 / 4. Under those budgets, replaying every historical card blocks
# ZERO cards that used to succeed.
#
# A cap that is too small does not save time, it moves the work to a human:
# replayed, a 25m T3 cap blocked 7 cards that used to land, and a 30m T3 cap
# blocked 2. So T3's cap stays above its measured maximum, and the fast lane
# takes its time out of the GATE, not out of the cap.
TIERS = {
    "T1": {
        "label": "trivial",
        "runtime": 900,
        "runtime_text": "15m",
        "retries": 2,
        "body_max": 4000,
        "gate": "swift build + ONE filtered suite that owns the touched file",
    },
    "T2": {
        "label": "standard",
        "runtime": 1500,
        "runtime_text": "25m",
        "retries": 3,
        "body_max": 10000,
        "gate": "swift build + a filtered suite per touched area; baseline compare only where the baseline is red",
    },
    "T3": {
        "label": "deep",
        "runtime": 2700,
        "runtime_text": "45m",
        "retries": 4,
        "body_max": 32000,
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
# catalog rewrites. So every signal is read from the WORK, and the two
# file-shaped signals are read from the files the card actually writes.
SIGNALS = {
    "persistence": re.compile(
        r"@Model|ModelContainer|Schema\(|versionedSchema|makeContainer|migration",
        re.I,
    ),
    "live_app": re.compile(
        r"AX ?census|AXScrollBar|screenshot|screencapture|launch the app|app bundle"
        r"|Wenshu\.app|visual proof|on the running app|unified log|processIdentifier",
        re.I,
    ),
    "new_subsystem": re.compile(
        r"\bnew (?:feature|service|model|view|screen|pane|subsystem|package)\b", re.I
    ),
    "package_boundary": re.compile(r"\bWenshuAgent\b|\bWenshuData\b", re.I),
}

# The file-shaped deep signals: they fire on a file the card WRITES.
CATALOG_RE = re.compile(r"\.xcstrings$|\.lproj/|Info\.plist$", re.I)
MANIFEST_RE = re.compile(r"^Package\.swift$")

# The expensive gate form. A card that DEMANDS a red-baseline comparison, or
# the whole suite, pays for it: measured, such a card averages 83.1 m over
# 4.00 runs against 52.4 m over 2.97 for one that does not, inside one tier.
BASELINE_DEMAND_RE = re.compile(
    r"versus the baseline|against the baseline|compared to the baseline"
    r"|no NEW failing test",
    re.I,
)
FULL_SUITE_RE = re.compile(r"\bswift test\b(?![^\n]*--filter)")

# Sections whose paths are files the card must NOT touch.
EXCLUSION_SECTIONS = wave_gate.EXCLUSION_SECTIONS | {
    "DO NOT CHANGE",
    "OUT OF SCOPE",
}


def work_scope(body: str) -> tuple[set[str], set[str]]:
    """The (written, forbidden) file sets of a card body, for TIERING.

    A path the card names in a MUST NOT CHANGE section is not work. This is
    the same reading wave_gate uses, and for the same reason: the tier must
    describe what the card CHANGES, not what it promises not to touch.

    A path named in BOTH a write section and an exclusion section is
    contradictory in the body; for the tier it counts as written, because
    the card does reach that file.
    """
    written: set[str] = set()
    forbidden: set[str] = set()
    for name, text in wave_gate.sections(body):
        stripped = wave_gate.CITATION_RE.sub("", text)
        if name not in EXCLUSION_SECTIONS:
            written |= set(wave_gate.PATH_RE.findall(stripped))
            continue
        for bullet in wave_gate._bullets(stripped):
            paths = set(wave_gate.PATH_RE.findall(bullet))
            if not paths:
                continue
            if wave_gate.GRANT_RE.search(bullet):
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
    return "\n".join(
        text for name, text in wave_gate.sections(body) if name not in EXCLUSION_SECTIONS
    )


def code_volume(body: str) -> int:
    """The characters of source the body inlines.

    A body that pastes the code to write is a body that has already done the
    design work, and a card that carries a full implementation in its prompt
    is a card the worker will re-derive line by line. Measured: the one-file
    card that inlined three whole type definitions took 58.8 m.
    """
    return sum(len(block) for block in CODE_RE.findall(body))


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
        "code": code_volume(body),
        "persistence": bool(SIGNALS["persistence"].search(text)),
        "live_app": bool(SIGNALS["live_app"].search(text)),
        "new_subsystem": bool(SIGNALS["new_subsystem"].search(text)),
        "package_boundary": bool(SIGNALS["package_boundary"].search(text))
        or any(MANIFEST_RE.match(p) for p in written),
        "catalog": any(CATALOG_RE.search(p) for p in written),
    }


def tier_of(body: str) -> tuple[str, list[str]]:
    """The tier a card body earns, and the reasons that decided it.

    The inputs are the WORK and the RISK. They are never the body's length
    and never the gates the body asks for: the tier CHANGES the cap and the
    gate, so a tier derived from either would be circular.
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
    if sig["code"] >= 3000:
        deep.append(f"{sig['code']} chars of code inlined in the body")
    if sig["live_app"] and sig["n_files"] >= 2:
        deep.append("a live-app proof")
    if sig["catalog"] and sig["n_files"] >= 2:
        deep.append("a catalog rewrite")
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

    This is the lever that carries the time, not the cap. Measured: a body
    asking for a red-baseline comparison averaged 83.1 m over 4.00 runs
    against 52.4 m over 2.97 runs for a body that does not, INSIDE one tier.
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


def find_errors(card: dict) -> list[str]:
    """Every way the card disagrees with the tier it earns.

    An error is a contradiction between the card and the contract. A note is
    a cost warning that the tier permits.
    """
    body = card.get("body") or ""
    title = card.get("title") or ""
    tier, _reasons = tier_of(body)
    contract = TIERS[tier]
    errors: list[str] = []
    notes: list[str] = []

    claimed = declared_tier(title)
    if claimed is None:
        errors.append(f"title carries no tier tag (expected [{tier}])")
    elif claimed != tier:
        errors.append(f"title says {claimed}, the body earns {tier}")

    runtime = card.get("max_runtime_seconds")
    if runtime is not None and runtime != contract["runtime"]:
        errors.append(
            f"runtime cap {runtime}s, tier {tier} buys {contract['runtime']}s "
            f"({contract['runtime_text']})"
        )

    if len(body) > contract["body_max"]:
        errors.append(f"body is {len(body)} chars, tier {tier} buys {contract['body_max']}")

    if tier == "T1":
        if BASELINE_DEMAND_RE.search(body):
            errors.append("T1 must not demand a red-baseline comparison")
        if FULL_SUITE_RE.search(body):
            errors.append("T1 must name a filtered suite, not the whole suite")
    elif tier == "T2" and BASELINE_DEMAND_RE.search(body):
        notes.append(
            "T2 demands a red-baseline comparison; the measured cost of that "
            "demand is 83.1 m over 4.00 runs against 52.4 m over 2.97"
        )

    return errors + notes


def kanban_cards(board: str | None = None) -> list[dict]:
    """Every card on the board, with its body and its runtime cap."""
    args = ["hermes", "kanban"]
    if board:
        args += ["--board", board]
    args += ["list", "--json"]
    out = subprocess.run(args, cwd=REPO, capture_output=True, text=True)
    if out.returncode != 0:
        print(out.stderr.strip(), file=sys.stderr)
        return []
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        return []
    if isinstance(data, dict):
        data = data.get("tasks", [])
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
        "body_len": len(body),
        "gate": contract["gate"],
        "gate_width": gate_width(body),
        "findings": find_errors(card),
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
            print(f"  body budget   {contract['body_max']} chars")
            print(f"  gate          {contract['gate']}")
        print("\nThe tier is derived from the card body by this script. The title")
        print("carries it as [T1] / [T2] / [T3] so `kanban list` shows the rating.")
        return 0

    if args.body:
        cards = [card_from_file(args.body)]
    else:
        cards = kanban_cards(args.board)
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
        errors = [r for r in rows if r["findings"]]
        if errors:
            print(f"=== {len(errors)} card(s) disagree with their tier ===")
            for row in errors:
                print(f"  {row['id']}  {row['title']}")
                for finding in row["findings"]:
                    print(f"      ! {finding}")
            return 1
        print("=== every card agrees with its tier ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
