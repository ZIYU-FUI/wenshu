#!/usr/bin/env python3
"""card_gate_command.py — the ONE reader of "what gate does this card ask for?".

Two gates read the same card body, and they used to answer differently:

  - `gate_width_gate.py` (= the width gate) accepted a card that names its
    OWN gate command (= `python3 Tools/.../tests/test_x.py`), because a card
    that writes no Swift code has no Swift suite to filter.
  - `pre_review_gate.py` (= the pre-review gate) read ONLY
    `swift test --filter` lines, so a card that writes no Swift code could
    never satisfy it: the filter list was empty, and the gate failed with
    "no suite was measured" no matter what the card said.

Measured 2026-11-24 on board `wenshu-par`: 819 of the board's cards name
the devtool or `Scripts/` in their body, and 433 of those carry a comment
that quotes the suite rule. So the two gates disagreed on the majority of
the board's cards, and the disagreement had one shape: the width gate
accepted the card and the pre-review gate refused it.

The house reference already names this (`wenshu-parallel-dev/references/
card-body-authoring.md`): "A pre-review failure on a no-Swift card is a
GATE GAP, not a card defect", and "a gate tool that demanded one would
block every tool card and every docs card".

So this module is the ONE reader both gates call. It answers three
questions about a card body:

  - `swift_filters(body)`  the `swift test --filter <suite>` lines the card
    names (= the narrow Swift gate, when the card writes Swift).
  - `own_commands(body)`   the card's OWN gate command (= the devtool's
    test script, a pytest run, a docs link check), as the exact command
    text so a gate can RUN it.
  - `gate_lines(body)`     the gate lines that read as commands to run
    (= the reader that tells a command from a sentence that mentions one).

THE RULE THE READER ENCODES

  A card names its gate. When the card writes Swift, that gate is the
  filtered suite that owns the touched file. When it writes no Swift, that
  gate is its own command. Either way the gate must MEASURE something, and
  a command that ran nothing is not a gate.

Usage:
    from card_gate_command import swift_filters, own_commands, gate_lines
"""

from __future__ import annotations

import re

# The `--filter <name>` part of a `swift test --filter <name>` invocation.
# THREE spellings are the same invocation: the suite name quoted (either
# style), the suite name in backticks, and the suite name BARE. A reader
# that takes only one of them turns the card's own gate into a filter that
# ran nothing, = = and a reader that takes only the quoted ones credits a
# card the other gate refuses. Measured 2026-11-24 over the board's 1124
# cards: 288 cards name a filter in a spelling the quoted-only reader did
# not see, = = so the two gates answered differently about 204 live cards.
FILTER = re.compile(
    r"--filter\s+(?:(['\"])(.+?)\1|`([^\s`]+)`|([^\s`'\";|)]+))"
)

# The COMMAND the filter belongs to. A `--filter` with no `swift test` on
# its line is a fragment of prose, = = and a card's gate is a command.
# ⇒ ⇒ ⇒ AND EVERY filter on a line is read, = = = not only the last one:
# a card that writes "`swift test --filter A` / `--filter B`" names TWO
# suites, = = and SwiftPM takes both. The greedy form read such a line as
# naming the third, = = so the reader now reads the filter part and the
# command part SEPARATELY, = = and no caller has to know which one it is
# looking at.
SWIFT_TEST = re.compile(r"swift\s+test")

# The phrase that says the card names a Swift filter at all.
FILTER_PHRASE = "swift test --filter"

# The gate command of a card that writes NO Swift code (= the devtool's own
# test script, a pytest run, a docs link check). The forms are the ones
# this project runs as a gate. This is the SAME set the width gate reads,
# so the two gates cannot drift apart again.
# = = = RECOGNITION READS A WRAPPED COMMAND. = = = = = = = = = = = = = = =
# = = = = A card that wraps its gate command (= "python3" on one line and = =
# = = = = the path on the next) still NAMES a gate, so the recognition = =
# = = = = pattern tolerates a line break in the separator. The EXECUTION = =
# = = = = pattern below does not, and normalises the wrap instead, because = =
# = = = = a newline inside the text would run `bash` with no argument and = =
# = = = = then run the path as a second command. = = = = = = = = = = = = = = =
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
# = = = The path may WRAP across lines, so the path part reads as "any = = =
# = = = characters but a line break", and the wrap is allowed BETWEEN the = =
# = = = command and the path. A card that writes "python3" on one line and = =
# = = = "Tools/.../test_x.py" on the next names ONE gate. = = = = = = = = = =
_PATH = r"[^\s\n]*tests?/test_\S+\.py"
_SH_PATH = r"[^\s\n]*tests?/test_\S+\.sh"
OWN_COMMAND = re.compile(
    r"python3\s+" + _PATH +
    r"|python3\s+-m\s+pytest"
    r"|\bpytest\b"
    r"|bash\s+" + _SH_PATH +
    r"|markdown[- ]link[- ]check"
    r"|\bglossary\b.*\bcheck\b"
    r"|\bdictionary\b.*\bcheck\b",
    re.I,
)

# The gate command, captured whole (= so a gate can RUN it and not just
# recognise it). The command is a path or a module, optionally with the
# python that runs it.
# The EXECUTION pattern: the same forms, with only the ones a gate can
# RUN. A card may WRAP a command across lines, so the separator tolerates
# a line break here too, and `_commands_in` collapses the wrap into one
# space (= a command is run, and a command with a newline in it is two
# commands).
OWN_COMMAND_FULL = re.compile(
    # `python3 <path>` or `python3 -m <module>`
    r"python3\s+(?:-m\s+)?" + _PATH +
    r"|python3\s+-m\s+\S+"
    r"|\bpytest\b(?:\s+[^\s]+)*"
    r"|bash\s+" + _SH_PATH +
    r"|markdown[- ]link[- ]check\b",
    re.I,
)


def _filter_name(match) -> str | None:
    """The suite name in a filter match, whichever spelling carried it.

    The three spellings are three groups of the ONE pattern, so the name
    is read the same way every time, = = and no caller has to know which
    group the match filled.
    """
    for group in (2, 3, 4):
        if match.group(group):
            return match.group(group)
    return None


def filters_in_line(line: str) -> list[str]:
    """The suite names this ONE line asks for.

    A `--filter` with no `swift test` on its line is a fragment of prose,
    = = so the line must name the command too, = = and every filter the
    command carries is read, = = not only the last.
    """
    if not SWIFT_TEST.search(line or ""):
        return []
    names: list[str] = []
    for match in FILTER.finditer(line):
        name = _filter_name(match)
        if name and name not in names:
            names.append(name)
    return names


def _wrapped_name(line: str) -> str:
    """The suite name a WRAPPED filter carries on the NEXT line.

    A card that writes `swift test --filter` and the suite name on the
    next line names ONE suite: = = SwiftPM takes the filter and its name
    as two arguments, = = and the wrap is the card's line break, = = not a
    second command. Measured 2026-11-24: three live cards wrote it that
    way, = = and a reader that reads one line at a time lost their narrow
    gate.
    """
    text = (line or "").strip()
    text = re.sub(r"^[-*+]\s+", "", text)
    text = text.strip("`")
    parts = text.split()
    if not parts:
        return ""
    return parts[0].strip("'`\"")


def filters_in_lines(lines: list[str]) -> list[str]:
    """The suite names these lines ask for.

    A filter whose NAME is on the next line is one filter (= see
    `_wrapped_name`), = = and every filter the command carries is read,
    = = not only the last.
    """
    names: list[str] = []
    for index, line in enumerate(lines or []):
        if not SWIFT_TEST.search(line or ""):
            continue
        found = filters_in_line(line)
        if not found and (line or "").rstrip().endswith("--filter"):
            if index + 1 < len(lines):
                name = _wrapped_name(lines[index + 1])
                if name:
                    found = [name]
        for name in found:
            if name not in names:
                names.append(name)
    return names


def swift_filters(body: str) -> list[str]:
    """The `swift test --filter <suite>` names the card asks for.

    This is the RECOGNITION view (= the whole body): a card that names
    its suite in prose has still named it, = = and the width gate's job
    is to know that, = = not to run it.
    """
    return filters_in_lines((body or "").split("\n"))


def _commands_in(text: str, pattern) -> list[str]:
    """The gate commands in this text, as the command TEXT.

    A command the card WRAPPED across lines comes back as ONE line (= the
    line break and the indent that followed it become one space), because
    a command is run, and a command with a newline in it is two commands.
    """
    seen: list[str] = []
    for match in pattern.finditer(text or ""):
        command = " ".join(match.group(0).split())
        if command and command not in seen:
            seen.append(command)
    return seen


def own_commands(body: str) -> list[str]:
    """The card's OWN gate commands, AS COMMANDS TO RUN.

    Read from the card's GATES section only (= the same section the Swift
    filters are read from), because this is the list a gate RUNS, and a
    command is run only where the card says it is its gate. The shape is
    whitelisted (= `OWN_COMMAND_FULL`), so only the gate forms this
    project runs can ever be executed here.

    Returned as the command TEXT, so the caller can run it. A command is
    returned once, in the order it first appears.
    """
    return _commands_in(gate_scope(body or ""), OWN_COMMAND_FULL)


def named_own_commands(body: str) -> list[str]:
    """The card's OWN gate commands, read from the WHOLE body.

    This is the RECOGNITION view (= "does this card name a gate at all?"),
    and it is what the width gate asks. It is wider than the execution
    view on purpose: a card that names its gate command in prose has still
    named a gate, and the width gate's job is to know that, not to run it.

    The two views differ in WHERE they read, not in WHAT they recognise,
    so the two gates cannot answer differently about the same card.
    """
    return _commands_in(body or "", OWN_COMMAND)


def gate_scope(text: str) -> str:
    """The card's GATES section, or the whole body when it has none.

    A card's GATES section is where its gate lines live, so the reader
    reads that section and NOT the prose around it: a WHY sentence that
    merely MENTIONS `swift test --filter` is a sentence about the gate,
    not a gate, and reading it as one made the reader report a card as
    broken for its own explanation.
    """
    match = re.search(r"^##\s+GATES\b", text or "", re.MULTILINE | re.IGNORECASE)
    if not match:
        return text or ""
    rest = text[match.end():]
    following = re.search(r"^##\s+", rest, re.MULTILINE)
    return rest[:following.start()] if following else rest


def is_gate_line(line: str) -> bool:
    """Does the line READ as a command to run?

    The phrase alone does not make a line a gate: a sentence that mentions
    it (= "the reader read only the EXIT CODE of each `swift test
    --filter`") is prose. A gate line is one whose text starts with the
    command, or carries it after a shell connective (= `cd <wt> && swift
    test --filter ...`).

    ⇒ ⇒ ⇒ AND THE LINE MAY CARRY THE COMMAND IN FOUR WRAPPINGS, = = = and
    the reader strips all of them before it decides: a LIST MARKER (= `- `
    or `1. `), a MARKDOWN TABLE ROW (= a gate written in a table cell is a
    gate the reader must lift, = = and the row's own text starts the
    command, whatever cell it sits in), BACKTICKS, = = = and the shell's
    own PROMPT (= `$ swift test --filter "X"`, = = and the prompt is not
    part of the command). Measured 2026-11-24 over the board's 1124 cards:
    the shared reader and the pre-review gate's own copy disagreed on 16
    GATES-section lines (the prompt form) and on 625 lines the other way
    (every own-command line), = = so a card could be accepted by one gate
    and refused by the other.
    """
    core = (line or "").strip()
    core = re.sub(r"^[-*+]\s+", "", core)
    core = re.sub(r"^\d+\.\s+", "", core)
    if core.startswith("|"):
        core = core.lstrip("|").strip()
    while core.startswith("`"):
        core = core[1:].strip()
    core = re.sub(r"^\$\s*", "", core)
    core = core.strip("`").strip()
    if not core:
        return False
    command = SWIFT_TEST.search(core)
    own = OWN_COMMAND.search(core)
    if command is None and own is None:
        return False
    index = command.start() if command is not None else (own.start() if own is not None else 0)
    before = core[:index].rstrip()
    if before == "":
        return True
    return before.endswith(("&&", ";", "|", "||", "(", "{"))


def gate_filters(body: str) -> tuple[list[str], list[str]]:
    """The card's own narrow suites, and the gate lines it cannot read.

    Returns (filters, unparsed_lines). `unparsed_lines` names the card's
    GATE lines the reader could not parse, = = because a card whose gate
    line cannot be read measures nothing, = = and the reader must say so
    rather than measure a smaller set than the card asks for.

    ⇒ ⇒ ⇒ THIS IS THE EXECUTION VIEW: = = = only the card's GATES section
    is read, = = and only the lines in it that read as commands, = = so a
    card is never failed for its own explanation, = = and never measured
    against a suite its prose quoted. The recognition view
    (= `swift_filters`) is the whole body, = = and the two gates ask their
    own question of the ONE reader.
    """
    filters: list[str] = []
    unparsed: list[str] = []
    lines = gate_scope(body or "").split("\n")
    for index, line in enumerate(lines):
        if not SWIFT_TEST.search(line):
            continue
        if not is_gate_line(line):
            continue
        found = filters_in_line(line)
        if not found and line.rstrip().endswith("--filter"):
            if index + 1 < len(lines):
                name = _wrapped_name(lines[index + 1])
                if name:
                    found = [name]
        if found:
            for name in found:
                if name not in filters:
                    filters.append(name)
        else:
            unparsed.append(line.strip())
    return filters, unparsed


def gate_lines(body: str) -> list[str]:
    """The gate lines in the card's GATES section that read as commands.

    A card's own gate command is a gate line, exactly like a Swift filter
    is: the rule is "the card names the gate", and the gate is whatever
    owns the work.
    """
    scope = gate_scope(body or "")
    lines = []
    for line in scope.split("\n"):
        if not is_gate_line(line):
            continue
        core = re.sub(r"^[-*+]\s+", "", line.strip())
        core = re.sub(r"^\d+\.\s+", "", core)
        core = core.strip("`").strip()
        if core and core not in lines:
            lines.append(core)
    return lines
