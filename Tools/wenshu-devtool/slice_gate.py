#!/usr/bin/env python3
"""
slice_gate.py — is this card a MINIMUM VERIFIABLE SLICE, checked before dispatch?

WHY THIS EXISTS
---------------
A board session is not an interactive session. It has NO prompt cache (the
worker rides the Anthropic-wire route to minimax-cn, and the worker log
records zero cache_read tokens), it starts from the card body alone, and it
is thrown away when the run ends. Nothing carries over: the next run of the
same card starts from zero, because Hermes has no cross-run session resume.

That makes the cost of a card a function of its LENGTH, not its difficulty.
Measured on the dev lane (2026-10-29, 24 h): 167 API calls per run and
35.5M tokens per run, with the input tokens of a single call growing from
26k at the first call to 380k at the last (= 15x inside one session). Every
call re-sends the whole history, so a run costs O(calls^2). A card that
runs long is therefore not "a hard card", it is an expensive one, and when it
hits its cap it is re-dispatched from zero: 89% of dev runs landed nothing.

So the card must be SMALL. But small is not "one file per card": a card that
edits one file without the seam that makes it work is not verifiable on its
own, and the worker has to rediscover the seam, which is where the 61% of
shell calls that only LOOK went.

The shape that is both small and complete is the POCOCK vertical slice
(``to-tickets``): "Each slice cuts a narrow but COMPLETE path through every
layer ... A completed slice is demoable or verifiable on its own ... Each
slice is sized to fit in a single fresh context window."

THE QUESTION THIS GATE ASKS
---------------------------
Two questions, and both are about the card's SHAPE, not its tier:

1. **Is the slice verifiable on its own?** Every area of the tree the card
   writes must have a named proof (a `swift test --filter <Suite>`, or a
   named gate command). An area with no named proof means the worker has to
   decide what "done" means for it, from scratch, inside a run that is
   already re-sending its history every turn.

2. **Is the slice narrow?** The card writes ONE area of the tree (plus its
   own test file). A card that writes files in three areas is three slices,
   and in a no-cache session three slices means three re-dispatches instead
   of one. Measured: cards writing 7+ files land 74% of the time and cards
   writing 1 file land 0% of the time, so this is NOT "one file per card":
   the unit is the vertical slice, and a slice may touch a source file, its
   test file and its strings.

WHAT IT DOES NOT DO
-------------------
- It does not judge the tier, the cap, the gate WIDTH or the evidence
  budget. Those are ``ticket_tier.py``, ``gate_width_gate.py`` and
  ``effort_budget_gate.py``. This one asks: is this card one slice that can
  be verified alone.
- It does not demand a suite for a card that writes NO code: a prose card
  is verified by reading it.
- A bare ``swift test`` is not a proof: the whole suite costs 224 s against
  10.5 s for one filtered suite, and it is not a slice's proof.

Usage:
    slice_gate.py --body FILE       check one card body
    slice_gate.py --card ID         check one card on the board
    slice_gate.py --check           every card on the board
    slice_gate.py --json            machine-readable output

Exit code 0 = pass, 1 = at least one error, 2 = the board could not be read.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wave_gate  # noqa: E402  (sibling module, same directory)
import ticket_tier  # noqa: E402  (sibling module, same directory)

# The contract starts on a date, not a flag. Cards created before it were
# dispatched under the old contract, and rewriting them is not this tool's
# business. Same shape as the other gates' epochs.
CONTRACT_FROM = 1793203200  # 2026-10-29 00:00 CST

# The areas a card may write. One slice lives in ONE area; the card's own
# test file rides along with it (= the test is part of the slice, not a
# second slice), so a test file does not count as a second area.
MAX_AREAS = 1

# A named suite: `swift test --filter XTests`. This is the proof a slice
# stands on. A bare `swift test` is the WHOLE suite and is NOT a slice's
# proof.
FILTER_RE = re.compile(r"swift\s+test\s+--filter\s+([A-Za-z0-9_]+)")

# A named gate command that is not a suite (= a card with no Swift code
# names its own gate: a script, a probe, a doctor command).
NAMED_GATE_RE = re.compile(
    r"(?:^|\s)(?:\./)?(?:Scripts|Tools)/[A-Za-z0-9_./-]+\.(?:sh|py)"
    r"|(?:^|\s)python3\s+(?:Scripts|Tools)/[A-Za-z0-9_./-]+\.py"
    r"|(?:^|\s)bash\s+(?:Scripts|Tools)/[A-Za-z0-9_./-]+\.sh"
    r"|(?:^|\s)swift\s+(?:build|format|lint)"
)

# The filter's suite list: one name, or several joined by `|` (= `swift test
# --filter "FooTests|BarTests"`, which is how a card names the suites that
# cover two files it wrote). The QUOTES are optional, because a card may
# write either form.
FILTER_LIST_RE = re.compile(
    r"swift\s+test\s+--filter\s+[\"']?([A-Za-z0-9_|]+)[\"']?"
)


def _is_subject(created_at) -> bool:
    """Whether a card is judged by this contract (older cards are reported only)."""
    try:
        return int(created_at or 0) >= CONTRACT_FROM
    except (TypeError, ValueError):
        return False


def order_files(body: str) -> list[str]:
    """The files the card's ORDER names (= the files it writes).

    **THE WRITE SET COMES FROM `ticket_tier.order_paths`, NOT FROM A LIST OF
    HEADINGS OF ITS OWN.** A card's headings are not a fixed vocabulary:
    measured over 173 real cards, the sections that carry file paths
    include `WHAT TO BUILD` (85 cards), `TESTS` (43), `ACCEPTANCE` (12),
    `WHY` (18), `LOCALIZATION` (22), `WHAT TO DO` (4), `FILES THIS CARD
    WRITES` (6), `THE 70 FILES` (1), `STEP 4 - CALL SITES AND IMPORTS`
    (1), and a hundred more, in Chinese and English alike. A tool with its
    own list misses most of them, and a list that has to be re-guessed for
    every new heading is not a rule.

    So the write set is the ONE the tier already computes, from the card
    TEMPLATE's own vocabulary (`ticket_tier.WRITE_SECTIONS` = the headings
    the template defines, plus the older names the cards already use), and
    this gate reads it from there. Two tools that read the same card the
    same way cannot disagree about what the card writes.

    The tier's set is the WRITE set (= the paths in the writing sections),
    not the whole body, so a `CURRENT STATE` section that describes seven
    other files does not make them the card's work.
    """
    return sorted(ticket_tier.order_paths(body))


def named_proofs(body: str) -> list[str]:
    """The named proofs the body carries (= the suites and gate commands).

    A bare `swift test` is NOT a proof: the whole suite is the board's, not
    a slice's, and it costs 224 s against 10.5 s for one filtered suite.
    """
    proofs: list[str] = []
    for suites in FILTER_LIST_RE.findall(body):
        for suite in suites.split("|"):
            suite = suite.strip()
            if not suite:
                continue
            label = f"swift test --filter {suite}"
            if label not in proofs:
                proofs.append(label)
    for line in body.splitlines():
        stripped = line.strip()
        if not stripped or FILTER_LIST_RE.search(stripped):
            continue
        if NAMED_GATE_RE.search(stripped):
            if stripped not in proofs:
                proofs.append(stripped)
    return proofs


def _slice_areas(body: str) -> dict[str, list[str]]:
    """The SLICE areas the card writes, and the files in each.

    A slice lives in one FEATURE (= `Sources/WenshuApp/Features/Agent`, one
    directory under the app's feature tree), not in one top-level area. The
    tier's own ``areas_of`` counts `Sources/WenshuApp/Features` (= every
    feature under it) as ONE area, which is the right blast radius for
    deciding how many suites must prove the card; it is too coarse for
    deciding whether the card is one slice, because every feature lives
    under the same three segments.

    So this gate counts the fourth segment: the feature directory. A card
    that writes `Features/Agent` and `Features/Chat` is two slices.

    **ONLY A `Features/` DIRECTORY OPENS A SLICE.** The directories beside
    it (= `App/`, `Shared/`) are the HOST layer: the app's assembly and the
    shared components every feature sits on. A card that writes a feature
    plus the shared component it needs plus the shell that assembles it is
    ONE vertical slice (= that is what "narrow but COMPLETE path through
    every layer" means), and counting `App/` and `Shared/` as features of
    their own reported every well-formed card as several slices.

    A card's own TEST file is part of the slice it proves, so it does not
    open a second slice: the test rides with the source area when there is
    one, and stands alone only when the card writes no source at all.
    """
    files = order_files(body)
    out: dict[str, list[str]] = {}

    def feature_of(path: str) -> str | None:
        """The feature a file belongs to, or None when it is host-layer."""
        parts = path.split("/")
        if len(parts) < 4:
            return None
        # A feature is a directory UNDER `Features/`: the segment after it
        # is the feature's name. `App/` and `Shared/` have no such segment
        # and are the host layer, so they never open a slice.
        try:
            features_at = parts.index("Features")
        except ValueError:
            return None
        if features_at + 1 >= len(parts):
            return None
        return "/".join(parts[: features_at + 2])

    source_slices: set[str] = set()
    for path in files:
        feature = feature_of(path)
        if feature is None:
            continue
        if path.startswith("Sources/"):
            source_slices.add(feature)
    for path in files:
        feature = feature_of(path)
        if feature is None:
            # Host layer and out-of-tree files ride with the slice that
            # needs them; they open none.
            continue
        if "/Tests/" in f"/{path}" and len(source_slices) == 1:
            # The test rides with the slice it proves.
            only = next(iter(source_slices))
            out.setdefault(only, []).append(path)
            continue
        out.setdefault(feature, []).append(path)
    return out


def named_suites(body: str) -> set[str]:
    """The suite names the card's GATES section names.

    A card may name several suites in one filter (= `--filter "FooTests|
    BarTests"`), so the list is split on the pipe and each name is counted.
    """
    suites: set[str] = set()
    for group in FILTER_LIST_RE.findall(body):
        for suite in group.split("|"):
            suite = suite.strip()
            if suite:
                suites.add(suite)
    return suites


def _suite_for_file(path: str) -> str | None:
    """The suite name a test file declares (= its struct name).

    A Swift Testing suite is a struct named `<Thing>Tests` in a file of the
    same name: `Tests/WenshuAppTests/Chat/View/ChatMessageViewTests.swift`
    declares `ChatMessageViewTests`. The card's gate names the SUITE, so the
    suite a test file carries is its basename without the `.swift` suffix.
    """
    base = path.rsplit("/", 1)[-1]
    if not base.endswith(".swift"):
        return None
    return base[:-len(".swift")]


def _is_test_path(path: str) -> bool:
    """Whether a path names a test file.

    A TEST FILE IS A PATH WITH A `Tests/` SEGMENT, not a path that STARTS
    with `Tests/`. The packages nest their test target inside the package
    (= `Sources/WenshuAgent/Tests/WenshuAgentTests/ConductorSessionScope
    Tests.swift`), and a rule that only counted the top-level test target
    called those cards "no test file" when they named their test file under
    a `TESTS` heading.

    So the rule is the SEGMENT, which holds in every tree: the test target
    is a directory called `Tests`, wherever the package puts it.
    """
    return "/Tests/" in f"/{path}" and path.endswith(".swift")


def contract_errors(body: str) -> list[str]:
    """Every way the card is not one minimum verifiable slice.

    **ONLY THE FINDINGS THAT NEED NO GUESS ARE ERRORS.** The POCOCK rule
    has three parts (= "narrow but COMPLETE path through every layer",
    "demoable or verifiable on its own", "sized to fit in a single fresh
    context window"), and only the middle one is decidable without knowing
    what the repository's directories MEAN. The narrowness part needs the
    repository's own shape (= which directory is a feature, which is the
    host layer), and that shape is written down per repository in its
    AGENTS.md, not in a tool: a path pattern that guesses it reads the
    wrong tree as often as the right one. So the narrowness is a NOTE
    (= a fact about the card, for the author to weigh), and the errors are
    the two findings that hold in every tree:

    1. the card writes a test file and does not name that file's suite, so
       the worker decides what "done" means for it, from scratch;
    2. the card writes source files and no test file at all, so it has no
       proof of its own.

    Both are decided by the card's OWN words (= the files it lists, the
    suites it names), so they hold whatever the tree looks like.
    """
    errors: list[str] = []
    files = order_files(body)
    if not files:
        # A card that writes no code (= a prose card) is verified by reading
        # it. Nothing to check.
        return errors

    suites = named_suites(body)
    proofs = named_proofs(body)
    if not proofs:
        # The card names no proof at all. gate_width_gate.py owns that
        # finding ("a card that names no suite"), so this gate does not
        # double-report it.
        return errors

    # 1. Verifiable: the slice carries its own proof. Two shapes:
    #    - the card writes a TEST file, and names that file's suite in its
    #      gates. The test IS the proof, and the card states which one.
    #    - the card writes NO test file, so its source files have no named
    #      proof at all: the worker has to decide what "done" means for
    #      them, from scratch, inside a run that re-sends its whole history
    #      every turn.
    #
    #    That is the POCOCK rule made checkable: the card names the suite
    #    that owns each file it writes.
    #
    #    A TEST FILE IS A PATH WITH A `Tests/` SEGMENT, not a path that
    #    STARTS with `Tests/`. The packages nest their test target inside
    #    the package (= `Sources/WenshuAgent/Tests/WenshuAgentTests/
    #    ConductorSessionScopeTests.swift`), and a rule that only counted
    #    the top-level test target called those cards "no test file" when
    #    they named their test file under a `TESTS` heading.
    test_files = [p for p in files if _is_test_path(p)]
    if test_files:
        for path in test_files:
            suite = _suite_for_file(path)
            if suite is None or suite in suites:
                continue
            errors.append(
                f"no named proof covers {path} (= suite {suite}); a slice is "
                "verifiable on its own, so name the suite that owns each file "
                f"it writes (swift test --filter {suite})"
            )
    else:
        source_files = [p for p in files if p.startswith("Sources/")]
        if source_files:
            listed = ", ".join(source_files[:3])
            errors.append(
                f"this card writes {len(source_files)} source file(s) and no "
                f"test file (= {listed}); a slice is verifiable on its own, so "
                "it must carry the test that proves it, named in the gates "
                "(swift test --filter <Suite>)"
            )

    return errors


def contract_notes(body: str) -> list[str]:
    """The facts about the card's size that the AUTHOR weighs.

    These are not errors, because deciding them needs the repository's own
    shape (= which directory is a feature), and that shape is written down
    in the repository's AGENTS.md, not here. A tool that guesses it reads
    the wrong tree as often as the right one, and a gate that cries wolf is
    worse than no gate: the author learns to ignore it, and the one real
    finding goes unread too.
    """
    notes: list[str] = []
    files = order_files(body)
    if not files:
        return notes

    source_files = [p for p in files if p.startswith("Sources/")]
    if not source_files:
        return notes

    areas = _slice_areas(body)
    if len(areas) > MAX_AREAS:
        listed = ", ".join(
            f"{area} ({', '.join(paths[:2])})" for area, paths in sorted(areas.items())
        )
        notes.append(
            f"this card writes {len(areas)} features of the tree ({listed}); a "
            "board session has no cache and starts from zero, so a card that "
            "spans features is usually several slices = split it into one card "
            "per feature, each with its own suite"
        )
    return notes


def _hermes_bin() -> str | None:
    """The hermes executable, resolved so a missing PATH is not a silent pass.

    Same resolution as ``gate_width_gate.py``: the PATH entry first, then the
    HERMES_BIN override, then the standard local install. Without it a
    subprocess that inherits a thin PATH reports "the board could not be
    read", which reads like an empty board and is not one.
    """
    found = shutil.which("hermes")
    if found:
        return found
    for candidate in (
        os.environ.get("HERMES_BIN"),
        str(Path.home() / ".local" / "bin" / "hermes"),
    ):
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return candidate
    return None


def _card_body(card_id: str, board: str | None = None) -> str | None:
    """Read one card's body through the hermes CLI (the board is read-only here)."""
    binary = _hermes_bin()
    if binary is None:
        return None
    # `--board` belongs to the kanban subcommand, not to the top-level parser:
    # `hermes --board X kanban ...` makes the top-level parser read X as a
    # command. So the order is kanban, --board, <slug>, then the subcommand.
    cmd = [binary, "kanban"]
    if board:
        cmd += ["--board", board]
    cmd += ["show", card_id, "--json"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    if isinstance(data, list):
        data = data[0] if data else {}
    if not isinstance(data, dict):
        return None
    # `kanban show --json` nests the card under "task"; the body is there.
    nested = data.get("task")
    task: dict = nested if isinstance(nested, dict) else data
    body = task.get("body")
    return body if isinstance(body, str) else None


def _hermes_json(args: list[str]) -> list[dict] | None:
    """Read cards through the hermes CLI; None = the board could not be read."""
    binary = _hermes_bin()
    if binary is None:
        return None
    try:
        proc = subprocess.run([binary, *args], capture_output=True, text=True, timeout=180)
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    text = proc.stdout.strip()
    start = text.find("[")
    if start < 0:
        return None
    try:
        data = json.loads(text[start:])
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, list) else None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", help="check one card body from a file")
    parser.add_argument("--card", help="check one card on the board")
    parser.add_argument("--check", action="store_true", help="every card on the board")
    parser.add_argument("--board", help="board slug; default = the current board")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args(argv)

    if args.body:
        body = Path(args.body).read_text(encoding="utf-8")
        errors = contract_errors(body)
        notes = contract_notes(body)
        if args.json:
            print(json.dumps(
                {"id": f"file:{args.body}", "errors": errors, "notes": notes},
                indent=2,
            ))
        else:
            for finding in errors:
                print(f"  ! {finding}")
            for finding in notes:
                print(f"  - {finding}")
            if not errors:
                print("  ok: this card carries its own proof")
        return 1 if errors else 0

    if args.card:
        body = _card_body(args.card, args.board)
        if body is None:
            print("the board could not be read", file=sys.stderr)
            return 2
        errors = contract_errors(body)
        notes = contract_notes(body)
        if args.json:
            print(json.dumps(
                {"id": args.card, "errors": errors, "notes": notes}, indent=2
            ))
        else:
            for finding in errors:
                print(f"  ! {finding}")
            for finding in notes:
                print(f"  - {finding}")
            if not errors:
                print(f"  {args.card}  ok: carries its own proof")
        return 1 if errors else 0

    if args.check:
        # `--board` belongs to the kanban subcommand: the top-level parser
        # would read the slug as a command.
        cli = ["kanban"]
        if args.board:
            cli += ["--board", args.board]
        cli += ["list", "--json"]
        cards = _hermes_json(cli)
        if cards is None:
            print("the board could not be read", file=sys.stderr)
            return 2
        judged = 0
        failures: list[tuple[str, list[str]]] = []
        noted: list[tuple[str, list[str]]] = []
        for card in cards:
            if card.get("status") in ("done", "archived"):
                continue
            if not _is_subject(card.get("created_at")):
                continue
            body = card.get("body")
            if not isinstance(body, str):
                continue
            judged += 1
            errors = contract_errors(body)
            if errors:
                failures.append((card.get("id", "?"), errors))
            else:
                notes = contract_notes(body)
                if notes:
                    noted.append((card.get("id", "?"), notes))
        if args.json:
            print(json.dumps(
                {"judged": judged, "failed": len(failures), "noted": len(noted),
                 "cards": [{"id": cid, "errors": errs} for cid, errs in failures],
                 "notes": [{"id": cid, "notes": ns} for cid, ns in noted]},
                indent=2,
            ))
        else:
            for cid, errs in failures:
                print(f"  {cid}")
                for finding in errs:
                    print(f"      ! {finding}")
            for cid, ns in noted:
                print(f"  {cid}")
                for finding in ns:
                    print(f"      - {finding}")
            print()
            print(
                f"=== {judged} card(s) judged, {len(failures)} without their own "
                f"proof, {len(noted)} to weigh ==="
            )
        return 1 if failures else 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
