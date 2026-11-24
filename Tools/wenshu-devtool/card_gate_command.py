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

# A `swift test --filter <name>` invocation. Both quote styles are
# accepted: a card written with double quotes names the same suite as one
# written with single quotes, and a reader that takes only one of them
# turns the card's own gate into a filter that ran nothing.
FILTER = re.compile(r"swift test --filter\s+(['\"])(.+?)\1")

# The phrase that says the card names a Swift filter at all.
FILTER_PHRASE = "swift test --filter"

# The gate command of a card that writes NO Swift code (= the devtool's own
# test script, a pytest run, a docs link check). The forms are the ones
# this project runs as a gate. This is the SAME set the width gate reads,
# so the two gates cannot drift apart again.
OWN_COMMAND = re.compile(
    r"python3\s+\S*tests?/test_\S+\.py"
    r"|python3\s+-m\s+pytest"
    r"|\bpytest\b"
    r"|bash\s+\S*tests?/test_\S+\.sh"
    r"|markdown[- ]link[- ]check"
    r"|\bglossary\b.*\bcheck\b"
    r"|\bdictionary\b.*\bcheck\b",
    re.I,
)

# The gate command, captured whole (= so a gate can RUN it and not just
# recognise it). The command is a path or a module, optionally with the
# python that runs it.
OWN_COMMAND_FULL = re.compile(
    # `python3 <path>` or `python3 -m <module>`
    r"python3\s+(?:-m\s+)?[^\s]*tests?/test_\S+\.py"
    r"|python3\s+-m\s+\S+"
    r"|\bpytest\b(?:\s+[^\s]+)*"
    r"|bash\s+[^\s]*tests?/test_\S+\.sh"
    r"|markdown[- ]link[- ]check\b",
    re.I,
)


def swift_filters(body: str) -> list[str]:
    """The `swift test --filter <suite>` names the card asks for."""
    return [m.group(2) for m in FILTER.finditer(body or "")]


def _commands_in(text: str) -> list[str]:
    """The gate commands in this text, as the command TEXT to run."""
    seen: list[str] = []
    for match in OWN_COMMAND_FULL.finditer(text or ""):
        command = match.group(0).strip()
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
    return _commands_in(gate_scope(body or ""))


def named_own_commands(body: str) -> list[str]:
    """The card's OWN gate commands, read from the WHOLE body.

    This is the RECOGNITION view (= "does this card name a gate at all?"),
    and it is what the width gate asks. It is wider than the execution
    view on purpose: a card that names its gate command in prose has still
    named a gate, and the width gate's job is to know that, not to run it.

    The two views differ in WHERE they read, not in WHAT they recognise,
    so the two gates cannot answer differently about the same card.
    """
    return _commands_in(body or "")


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
    """
    core = (line or "").strip()
    core = re.sub(r"^[-*+]\s+", "", core)
    core = re.sub(r"^\d+\.\s+", "", core)
    core = core.strip("`").strip()
    if not core:
        return False
    if FILTER_PHRASE not in core and not OWN_COMMAND.search(core):
        return False
    index = core.find(FILTER_PHRASE)
    if index == -1:
        index = core.lower().find("pytest")
        if index == -1:
            index = core.lower().find("markdown")
            if index == -1:
                index = core.lower().find("link-check")
                if index == -1:
                    index = 0
    before = core[:index].rstrip()
    if before == "":
        return True
    return before.endswith(("&&", ";", "|", "||", "(", "{"))


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
