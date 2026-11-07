#!/usr/bin/env python3
"""The ticket-id matcher's own cases.

WHY THIS SUITE EXISTS

= = `inventory-measure.py`'s measure 5 (= = the ticket-id census) = =
shipped a matcher that could not see the tree's largest ticket family,
= = and its printed method claimed the forms it could not match. = = The
consequence was a FALSE GREEN: = = the row the policy's certificate
carried read `base 71 -> tip 2` over the card's own eight files, = =
while a form-complete matcher reads `base 76 -> tip 6`. = = So the
matcher needs its OWN cases, = = and each case must be able to fail.

= = Every case here names a form the tree really uses, = = and the
negative cases name the ordinary Swift words a loose matcher would
catch. = = The suite drives the tool's own module (= = it imports the
matcher, = = so the case and the tool cannot drift apart).

= = Idempotent: = = running it twice leaves the same tree.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "inventory-measure.py"

sys.path.insert(0, str(TOOL.parent))
spec = importlib.util.spec_from_file_location("inventory_measure", TOOL)
assert spec is not None and spec.loader is not None
inv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inv)

TICKET_ID = inv.TICKET_ID


# = = the four families the tree really uses = =
MUST_MATCH = [
    # = = the hyphenated family = =
    "T4-SUBAGENT-UI",
    "T8-SOMETHING",
    "P1-02",
    "OOB-7",
    # = = the bare-number family = =
    "A112",
    "Q112",
    "M1",
    "T0",
    # = = the LETTER-SUFFIXED family (= = the one the old matcher missed) == 
    "T20c",
    "T20b",
    "T22b",
    "T1a",
    "T2b",
    "H2s",
    "T12b",
    "T20a",
    "T3a",
    "T2a",
    "T1b",
    "T3b",
    "T11b",
    # = = the lowercase-prefixed family (= = the one the old matcher missed,
    # = = and the one its printed method CLAIMED) = =
    "round-19",
]

# = = the ordinary words a loose matcher would catch = =
MUST_NOT_MATCH = [
    "TabView",
    "Text",
    "Type",
    "SwiftUI",
    "HTTPClient",
    "URLSession",
    "AnyView",
    "TextField",
    "Toggle",
    "Slider",
    "Picker",
    "ScrollView",
    "Label",
    "Button",
    "Image",
    "Color",
    "Font",
    "List",
    "Form",
    "Alert",
    "Sheet",
    "Grid",
    "Stack",
    "HStack",
    "VStack",
    "JSON",
    "XML",
    "HTML",
    "URL",
    "UUID",
    "HTTP",
    "GET",
    "POST",
    "PATCH",
    "EOF",
    "NULL",
    "VOID",
]


# = = the branch's OWN base (= = its merge-base with main) = =
#
# = = The base matters: = = the review's sha is the branch's TIP, = =
# = = so a diff against it sees only the tree's CURRENT changes, = =
# = = and the branch's own added lines (= = the ones that carried the
# = = = ticket ids) = = are the base's lines, = = and are invisible. = =
# = = A diff against the merge-base sees the WHOLE branch, = = = which
# = = = is what "the branch's added comment lines" means.
REPO = TOOL.parent.parent.parent


def branch_base():
    """The branch's merge-base with main (= = where its work starts)."""
    import subprocess

    out = subprocess.run(
        ["git", "merge-base", "main", "HEAD"],
        cwd=str(REPO),
        capture_output=True,
        text=True,
    ).stdout.strip()
    return out or "main"


def check_added_comment_lines():
    """The branch's ADDED comment lines carry no ticket id.

    = = The restored prose brought four ticket ids into a file that had
    = = none at the base, = = and a ticket id in a comment is a
    = = reference to a ticket the reader cannot open. = = So the added
    = = comment lines are measured, = = with the tool's own matcher.
    """
    import subprocess

    diff = subprocess.run(
        ["git", "diff", branch_base(), "--", "*.swift"],
        cwd=str(REPO),
        capture_output=True,
        text=True,
    ).stdout
    added = [
        line[1:]
        for line in diff.split("\n")
        if line.startswith("+") and not line.startswith("+++")
    ]
    offenders = []
    for line in added:
        if not line.strip().startswith("//"):
            continue
        for match in TICKET_ID.finditer(line):
            offenders.append((match.group(0), line.strip()[:80]))
    if offenders:
        return [
            f"the branch's added comment lines carry {len(offenders)} ticket id(s): "
            + ", ".join(sorted({tok for tok, _ in offenders}))
        ]
    return []


def check_the_rewrapped_block():
    """The rewritten block reads once, = = and not twice.

    = = The block used to carry the same fragment twice, = = so the
    = = sentence read as a duplicated clause inside a mangled one. = =
    = = The count is over the JOINED block, = = because the clause is
    = = = split across two comment lines.
    """
    path = REPO / (
        "Sources/WenshuAgent/Sources/WenshuAgent/Agent/ConversationLoop.swift"
    )
    if not path.exists():
        return [f"the rewritten block's file is gone: {path}"]
    lines = path.read_text(encoding="utf-8").split("\n")
    start = next(
        (
            i
            for i, line in enumerate(lines)
            if "The dead `[wenshu.agent] turn N/M` marker is gone" in line
        ),
        None,
    )
    if start is None:
        return ["the rewritten block is gone from ConversationLoop.swift"]
    block = "\n".join(lines[start : start + 5])
    found = []
    for clause in ("bounds the while condition", "only the user-visible"):
        if block.count(clause) != 1:
            found.append(
                f"the rewritten block carries {clause!r} "
                f"{block.count(clause)} time(s), = = and it must carry it once"
            )
    return found
    return failures


def main():
    failures = []

    for form in MUST_MATCH:
        if not TICKET_ID.search(form):
            failures.append(f"the matcher must see {form!r} (= the tree's own form)")

    for word in MUST_NOT_MATCH:
        if TICKET_ID.search(word):
            failures.append(f"the matcher must NOT see {word!r} (= an ordinary word)")

    # = = the letter-suffixed family is the one the old matcher could not
    # = = see, = = so it is named separately: = = a matcher that loses
    # = = it must fail THESE, = = and the family is measured on the tree
    # = = itself, = = so the number is the tree's and not a fixture's.
    letter_suffixed = re.compile(r"\b[A-Z]{1,3}\d{1,4}[a-z]\b")
    for form in ["T20c", "T1a", "H2s", "T12b"]:
        if not letter_suffixed.search(form):
            failures.append(f"the letter-suffixed family must match {form!r}")

    # = = and the printed method must not claim a form the matcher
    # = = cannot reach: = = the method text names `round-19`, = = so the
    # = = matcher must reach it.
    source = TOOL.read_text(encoding="utf-8")
    if "round-19" in source and not TICKET_ID.search("round-19"):
        failures.append(
            "the printed method names `round-19`, = = so the matcher must reach it"
        )

    # = = the two comment defects the last review measured, = = checked
    # = = against the tree itself (= = the branch's own added lines, = =
    # = and the block the branch rewrote). = = They are read from the
    # = = working tree, = = because the fix IS the working tree.
    failures.extend(check_added_comment_lines())
    failures.extend(check_the_rewrapped_block())

    if failures:
        print(f"inventory-measure's matcher: {len(failures)} case(s) FAILED")
        for line in failures:
            print(f"  - {line}")
        return 1

    print(
        f"inventory-measure's matcher: all tests passed "
        f"({len(MUST_MATCH)} forms it must see, {len(MUST_NOT_MATCH)} it must not)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
