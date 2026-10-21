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

print()
if FAILURES == 0:
    print("wave gate: all tests passed")
    sys.exit(0)
print(f"wave gate: {FAILURES} test(s) FAILED")
sys.exit(1)
