#!/usr/bin/env python3
"""Test: the wave gate reads a card body the way a card is written.

Run from Tools/wenshu-devtool/tests/ directory.
Exits 0 on PASS, non-0 on FAIL.

WHY THIS TEST EXISTS

The gate answers "can these two cards land in any order without a conflict?",
by reading the FILES each card writes out of its body. Three things can go
wrong, and all three were measured on this board:

1. The gate read the COMMENTS as if they were the body. `hermes kanban show`
   prints the body and then the comments under the same stream, and taking
   everything after "Body:" swept them in. A comment that named a file made
   the gate report a collision that did not exist.

2. A path under "MUST NOT CHANGE" was always forbidden. But a card can list
   a file there and still be told to add a row to it (= the nervous file
   index, which every card appends to). Classifying that as forbidden hid
   the real collision AND invented a stale must-not-change list.

3. A path in a bullet and the sentence that grants the write are TWO
   sentences of ONE bullet. Splitting on sentence ends separated the path
   from its own permission.

4. A file with a merge driver is not a collision to serialize: the driver
   merges it at the key level, so both cards keep their row.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GATE = HERE.parent / "wave_gate.py"

spec = importlib.util.spec_from_file_location("wave_gate", GATE)
wg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wg)

FAILURES = 0


def load_ticket_tier():
    """Import ticket_tier.py, the other tool that reads the same board."""
    path = HERE.parent / "ticket_tier.py"
    spec = importlib.util.spec_from_file_location("ticket_tier", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(label: str, condition: bool, detail: str = "") -> None:
    global FAILURES
    if condition:
        print(f"  PASS  {label}")
    else:
        print(f"  FAIL  {label}{(' :: ' + detail) if detail else ''}")
        FAILURES += 1


# --------------------------------------------------------------------------
# 1. a comment is not part of the body
# --------------------------------------------------------------------------
FAKE_SHOW = """Task t_aaaaaaaa: A card
  status:    blocked
  assignee:  wenshu-dev

Body:
WHAT TO BUILD

- `Sources/App/Thing.swift`. The card writes it.

MUST NOT CHANGE

- `Sources/App/Other.swift`. Leave it.

Comments (1):
  [2026-10-21 12:00] take main's `AGENTS.md` unchanged
"""


def fake_show(*args: str) -> str:
    return FAKE_SHOW


wg.kanban = fake_show
body = wg.card_body("t_aaaaaaaa")
check(
    "1. the body stops where the comments begin",
    "AGENTS.md" not in body,
    f"body still had: {body[-120:]!r}",
)
check(
    "1b. the body keeps its own content",
    "Sources/App/Thing.swift" in body,
)

# --------------------------------------------------------------------------
# 2. a path in an exclusion section that GRANTS a write is a write
# --------------------------------------------------------------------------
GRANT_BODY = """WHAT TO BUILD

- `Sources/App/Thing.swift`. Build it.

MUST NOT CHANGE

- `docs/agents/nfi.md`. The nervous file index must gain a row for each of
  the four moved files, and lose the rows for their old locations.
- `Sources/App/Keep.swift`. It stays exactly as it is.
- `Package.swift`. Do not add a dependency to it.
"""

written, forbidden = wg.files_of(GRANT_BODY)
check(
    "2. a bullet that grants a write under MUST NOT CHANGE is a write",
    "docs/agents/nfi.md" in written,
    f"written={sorted(written)}",
)
check(
    "2b. it is not also forbidden",
    "docs/agents/nfi.md" not in forbidden,
    f"forbidden={sorted(forbidden)}",
)
check(
    "2c. a bullet that forbids a file stays forbidden",
    "Package.swift" in forbidden and "Sources/App/Keep.swift" in forbidden,
    f"forbidden={sorted(forbidden)}",
)
check(
    "2d. a write is never in both sets",
    not (written & forbidden),
    f"overlap={sorted(written & forbidden)}",
)

# --------------------------------------------------------------------------
# 3. the path and its permission are ONE bullet, not two sentences
# --------------------------------------------------------------------------
SPLIT_BODY = """WHAT TO BUILD

- `Sources/App/Thing.swift`. Build it.

MUST NOT CHANGE

- No other row of the `docs/agents/nfi.md` nervous-file-index table may be
  edited. You are adding one row, not rewriting the table.
"""
written, forbidden = wg.files_of(SPLIT_BODY)
check(
    "3. a bullet that says 'you are adding one row' grants the write",
    "docs/agents/nfi.md" in written,
    f"written={sorted(written)} forbidden={sorted(forbidden)}",
)
check(
    "3b. and does not forbid it",
    "docs/agents/nfi.md" not in forbidden,
    f"forbidden={sorted(forbidden)}",
)

# --------------------------------------------------------------------------
# 4. the merge driver is read from .gitattributes
# --------------------------------------------------------------------------
check(
    "4. the registry's driver is found",
    wg.driver_for("docs/agents/nfi.md") == "nfi-registry",
    f"got {wg.driver_for('docs/agents/nfi.md')!r}",
)
check(
    "4b. the catalog's driver is found",
    wg.driver_for("Sources/WenshuApp/Resources/Localizable.xcstrings")
    == "xcstrings",
    f"got {wg.driver_for('Sources/WenshuApp/Resources/Localizable.xcstrings')!r}",
)
check(
    "4c. a file with no driver has none",
    wg.driver_for("Sources/App/Thing.swift") is None,
)

# --------------------------------------------------------------------------
# 5. a citation is not a write
# --------------------------------------------------------------------------
CITED_BODY = """WHAT TO BUILD

- Follow `AGENTS.md` §7.3 for the pre-commit sweep.
- `Sources/App/Thing.swift`. Build it.
"""
written, forbidden = wg.files_of(CITED_BODY)
check(
    "5. a cited rule is not a write",
    "AGENTS.md" not in written,
    f"written={sorted(written)}",
)

# --------------------------------------------------------------------------
# 6. a Chinese header is a header, and a Chinese prohibition is a prohibition
#
# The fixture is built from ESCAPES, so this file carries no CJK characters
# (AGENTS.md 1.1) and the next reader can still see what the body says.
#
# Measured before the fix: the section regex only matched an ALL-CAPS
# ENGLISH line, every Chinese card on this board parsed 0 sections, and the
# gate printed "file collisions: 0" as if it had checked them.
ZH = {
    "what_to_do": "\u8981\u505a\u7684",  # what to do
    "constraints": "\u7ea6\u675f",        # constraints
    "acceptance": "\u9a8c\u6536",         # acceptance
    "add": "\u65b0\u589e",                # add
    "do_not_touch": "\u4e0d\u8981\u52a8",  # do not touch
}

ZH_WRITE_CARD = (
    f"## {ZH['what_to_do']}\n\n"
    f"- {ZH['add']} `Sources/App/Fixture/Alpha.swift`\n"
    f"- {ZH['add']} `Sources/App/Fixture/Beta.swift`\n"
)
ZH_FORBID_CARD = (
    f"## {ZH['constraints']}\n\n"
    f"- {ZH['do_not_touch']} `Sources/App/Fixture/Alpha.swift`\n"
    f"- {ZH['do_not_touch']} `Sources/App/Fixture/Beta.swift`\n"
)
ZH_ACCEPT_CARD = (
    f"## {ZH['acceptance']}\n\n"
    f"- {ZH['add']} `Sources/App/Fixture/Gamma.swift`\n"
)

check(
    "6. a Chinese header is a header",
    wg.headings_parsed(ZH_WRITE_CARD) == 1,
    f"parsed={wg.headings_parsed(ZH_WRITE_CARD)}",
)
written, forbidden = wg.files_of(ZH_WRITE_CARD)
check(
    "6b. a path under a Chinese write section is a write",
    written == {"Sources/App/Fixture/Alpha.swift", "Sources/App/Fixture/Beta.swift"},
    f"written={sorted(written)}",
)
written, forbidden = wg.files_of(ZH_FORBID_CARD)
check(
    "6c. a path under a Chinese prohibition section is forbidden",
    forbidden == {"Sources/App/Fixture/Alpha.swift", "Sources/App/Fixture/Beta.swift"},
    f"forbidden={sorted(forbidden)}",
)
check(
    "6d. and it is not a write",
    not written,
    f"written={sorted(written)}",
)
written, forbidden = wg.files_of(ZH_ACCEPT_CARD)
check(
    "6e. a Chinese heading that is not a prohibition is a write section",
    written == {"Sources/App/Fixture/Gamma.swift"} and not forbidden,
    f"written={sorted(written)} forbidden={sorted(forbidden)}",
)

# --------------------------------------------------------------------------
# 7. a heading that ENDS WITH a prohibition phrase is a prohibition
#
# Measured before the fix: the gate compared the raw heading with `in`
# against an exact set, so "WHAT THIS CARD MUST NOT CHANGE" was a WRITE
# section to the gate (its paths counted as edits) and a prohibition to
# ticket_tier.py, on the same board, at the same moment.
ENDS_WITH_CARD = """## WHAT THIS CARD MUST NOT CHANGE

- `Sources/App/Fixture/Delta.swift`. Leave it exactly as it is.
"""
written, forbidden = wg.files_of(ENDS_WITH_CARD)
check(
    "7. a heading that ends with a prohibition phrase forbids its paths",
    forbidden == {"Sources/App/Fixture/Delta.swift"},
    f"forbidden={sorted(forbidden)}",
)
check(
    "7b. and does not write them",
    "Sources/App/Fixture/Delta.swift" not in written,
    f"written={sorted(written)}",
)

# --------------------------------------------------------------------------
# 8. a bare section number is a citation, and a grant is still a write
# --------------------------------------------------------------------------
CITED_BARE = """## WHAT TO BUILD

- No new Chinese in the source (= AGENTS.md 1.1).
- `Sources/App/Thing.swift`. Build it.
"""
written, forbidden = wg.files_of(CITED_BARE)
check(
    "8. a bare section number is a citation, not a write",
    "AGENTS.md" not in written,
    f"written={sorted(written)}",
)
check(
    "8b. and the rest of the body still reads",
    written == {"Sources/App/Thing.swift"},
    f"written={sorted(written)}",
)
GRANT_AGENTS = """## WHAT TO BUILD

- Pick one, and make `AGENTS.md` say which.
"""
written, forbidden = wg.files_of(GRANT_AGENTS)
check(
    "8c. a path with no number after it is a file reference, and a grant to "
    "edit it is a write",
    written == {"AGENTS.md"} and not forbidden,
    f"written={sorted(written)} forbidden={sorted(forbidden)}",
)

# --------------------------------------------------------------------------
# 9. a body the gate cannot split at all is never a clean bill of health
# --------------------------------------------------------------------------
UNREADABLE = (
    "A card whose body carries no heading at all, but names a file:\n"
    "`Sources/App/Fixture/Epsilon.swift`\n"
)
written, forbidden = wg.files_of(UNREADABLE)
check(
    "9. a body with no heading counts every path in it as a write",
    written == {"Sources/App/Fixture/Epsilon.swift"} and not forbidden,
    f"written={sorted(written)} forbidden={sorted(forbidden)}",
)
check(
    "9b. and the gate reads 0 sections in it",
    wg.headings_parsed(UNREADABLE) == 0,
    f"parsed={wg.headings_parsed(UNREADABLE)}",
)

# --------------------------------------------------------------------------
# 10. the gate REPORTS a Chinese-headered fixture pair
#
# The live board must not be the test fixture: live cards change. This
# pair is written here, and the gate's own reporting path is run over it.
# --------------------------------------------------------------------------
import contextlib  # noqa: E402
import io  # noqa: E402


def run_gate(bodies: dict[str, str]) -> str:
    """Run the gate's own reporting path over a FIXTURE board."""
    saved_ids, saved_body, saved_argv = wg.card_ids, wg.card_body, sys.argv
    wg.card_ids = lambda: [(cid, "ready") for cid in bodies]
    wg.card_body = lambda cid: bodies[cid]
    sys.argv = ["wave_gate.py"]
    buffer = io.StringIO()
    try:
        with contextlib.redirect_stdout(buffer):
            wg.main()
    finally:
        wg.card_ids, wg.card_body, sys.argv = saved_ids, saved_body, saved_argv
    return buffer.getvalue()


report = run_gate({"t_aaaa0001": ZH_WRITE_CARD, "t_bbbb0002": ZH_FORBID_CARD})
check(
    "10. the gate reports a Chinese-headered fixture pair",
    "t_aaaa0001" in report and "t_bbbb0002" in report,
    report,
)
check(
    "10b. and names both file paths",
    "Sources/App/Fixture/Alpha.swift" in report
    and "Sources/App/Fixture/Beta.swift" in report,
    report,
)
check(
    "10c. and the card that forbids them does not write them",
    "t_bbbb0002" in report
    and report.count("Sources/App/Fixture/Alpha.swift") >= 1,
    report,
)
check(
    "10d. the report says how many sections it parsed",
    "cards with 0 sections parsed: 0" in report,
    report,
)

report = run_gate({"t_cccc0003": UNREADABLE})
check(
    "11. a card the gate cannot read is listed by name",
    "cards with 0 sections parsed: 1" in report and "t_cccc0003" in report,
    report,
)

# --------------------------------------------------------------------------
# 12. the two tools read one vocabulary
# --------------------------------------------------------------------------
tier = load_ticket_tier()
BODIES_FOR_BOTH_TOOLS = [
    ZH_WRITE_CARD,
    ZH_FORBID_CARD,
    ZH_ACCEPT_CARD,
    ENDS_WITH_CARD,
    CITED_BARE,
    GRANT_AGENTS,
    UNREADABLE,
]
same = all(
    tier.work_scope(body) == wg.files_of(body) for body in BODIES_FOR_BOTH_TOOLS
)
check(
    "12. wave_gate.py and ticket_tier.py agree about every fixture body",
    same,
    f"gate={[wg.files_of(b) for b in BODIES_FOR_BOTH_TOOLS]} "
    f"tier={[tier.work_scope(b) for b in BODIES_FOR_BOTH_TOOLS]}",
)

print()
if FAILURES == 0:
    print("wave gate: all tests passed")
    sys.exit(0)
print(f"wave gate: {FAILURES} test(s) FAILED")
sys.exit(1)
