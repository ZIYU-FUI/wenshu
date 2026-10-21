#!/usr/bin/env python3
"""nfi-split.py — extract the NFI table out of AGENTS.md into its own file.

The table moves VERBATIM (no row is rewritten, no row is reordered, no row is
dropped). The only change is the surrounding file: a header that states what
the table is and where it came from, plus a footer that names the rule.

WHY IT MOVES

AGENTS.md is the wave's second magnet (4 cards write it). Its NFI table is
APPEND-ONLY: every new row lands at the END of the table (measured: the last
8 rows landed at index 29/30, 28/29, 27/28, 24/28, 23/30, 17/18, 29/30,
29/30 = always the last row). So two cards each adding one row both write the
same last line, and they collide.

Measured on this repo's shape:
  - both cards APPEND a row          -> merge-tree rc=1 (CONFLICT)
  - both cards INSERT a sorted row   -> merge-tree rc=1 (still a conflict:
    sorting does NOT help, the hunks are adjacent)
  - the union merge driver           -> merge-tree rc=0, and BOTH rows survive
    BUT union has a hole: two cards changing the SAME row to different
    contents produced TWO rows with the same key, silently (measured: the
    merged file carried the key twice, once with LOC 777 and once with 888)

So the table gets its own file with a KEY-LEVEL merge driver
(`Scripts/merge-nfi-registry.py`), and AGENTS.md keeps a pointer to it. Two
properties follow:

  - two cards' rows both survive
  - a genuine disagreement (the same row, two different contents) still
    conflicts, WITH THE KEY NAMED (= union would have swallowed it)

And AGENTS.md's PROSE keeps the normal merge (= a disagreement between two
prose edits still conflicts, instead of silently keeping both).

Run from the repo root:

    python3 Tools/wenshu-devtool/nfi-split.py --check
    python3 Tools/wenshu-devtool/nfi-split.py --write
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
AGENTS = REPO / "AGENTS.md"
NFI = REPO / "docs" / "agents" / "nfi.md"

SECTION_HEADING = "### §1.11 Nervous file index (NFI)"
NEXT_HEADING = "## §2"

HEADER = """# Nervous file index (NFI)

The registry of every file split out of a god-class or extracted to its own
file. Each row: parent file, extracted file, current LOC, content tag. The
next reader finds the file by concern in under five seconds.

This table used to live in `AGENTS.md` §1.11. It moved here because it is
APPEND-ONLY (= every new row lands at the end), so two cards each adding one
row both wrote the same last line and collided. In its own file it merges at
the KEY level: `docs/agents/nfi.md merge=nfi-registry` in `.gitattributes`
makes two cards' rows both survive, and a genuine disagreement (the same row,
two different contents) still conflicts with the key named.

`AGENTS.md` keeps the rule and points here. The rule is unchanged: every
extracted or added file MUST be registered in this table, with parent
reference, LOC, and content tag.

| Parent (god-class) | Extracted file | LOC | Content tag |
| ------------------ | -------------- | --- | ----------- |
"""

FOOTER = """
<!-- Append new rows at the END of the table above. The key-level merge
     driver keeps both rows when two cards add one each. -->

<!-- SSOT: AGENTS.md §1.7 (registration is mandatory) and §1.11 (this table).
     Move the table back? Then it needs the same append-collision fix, and
     the fix is harder there, because AGENTS.md also holds prose. -->
"""


def extract_section(text: str) -> tuple[str, str, str]:
    """Return (before, table, after) around the NFI section."""
    i = text.index(SECTION_HEADING)
    j = text.index(NEXT_HEADING, i)
    before = text[:i]
    block = text[i:j]
    after = text[j:]
    rows = [
        line
        for line in block.split("\n")
        if line.startswith("|") and "---" not in line and "Parent (god-class)" not in line
    ]
    return before, "\n".join(rows), after


def pointer_section() -> str:
    """The AGENTS.md section that replaces the table."""
    return (
        SECTION_HEADING
        + "\n\n"
        + "The registry itself lives in `docs/agents/nfi.md` (= one row per\n"
        + "extracted or added file: parent file, extracted file, current LOC,\n"
        + "content tag). It lives there because it is append-only: two cards\n"
        + "each adding one row both wrote the same last line in this file and\n"
        + "collided. In its own file it merges at the key level, so two cards'\n"
        + "rows both survive and a genuine disagreement still conflicts with\n"
        + "the key named.\n\n"
        + "Register a new row there, not here. The rule is unchanged.\n\n"
    )


def last_version_with_the_table() -> str | None:
    """The last committed AGENTS.md that still carried the table.

    The check mode compares the registry against the table's last home, so
    the comparison survives the split (= the table is gone from the working
    tree by then, and there is nothing left to compare against).
    """
    import subprocess

    out = subprocess.run(
        ["git", "log", "--format=%H", "--", "AGENTS.md"],
        cwd=REPO, capture_output=True, text=True,
    ).stdout.split()
    for sha in out:
        blob = subprocess.run(
            ["git", "show", f"{sha}:AGENTS.md"], cwd=REPO, capture_output=True, text=True
        ).stdout
        if "| Parent (god-class) |" in blob:
            return blob
    return None


RULE_1_7 = (
    "| 1.7 | Nervous file index (NFI) registration: every extracted/added file "
    "(god-class split, scope views, helper namespace) MUST be registered in "
    "`docs/agents/nfi.md` with parent ref + LOC + content tag. Discoverability "
    "< 5s by name. | Manual. |"
)
RULE_1_11 = (
    "| 1.11 | NFI (nervous file index) = `docs/agents/nfi.md`. Lists every file "
    "split from a god-class or extracted to its own file via A55+ arcs. Each row: "
    "parent file, current LOC, content tag. The next reader finds the file by "
    "concern in < 5s. | Manual. |"
)
INDEX_ROW = (
    "| Nervous file index (NFI) | "
    "/Volumes/ANAN/Engineering/wenshu/docs/agents/nfi.md |"
)


def update_rules(text: str) -> str:
    """Point the rules that named the table at its new home.

    A split that moves the table but leaves rule 1.7 saying "in this section"
    sends the next worker to the wrong file, so the rules move with it.
    """
    out = []
    for line in text.split("\n"):
        if line.startswith("| 1.7 |"):
            out.append(RULE_1_7)
            continue
        if line.startswith("| 1.11 |"):
            out.append(RULE_1_11)
            continue
        out.append(line)
    joined = "\n".join(out)
    if "docs/agents/nfi.md |" not in joined:
        # Add the reference-index row after the parallel-dev row.
        lines = joined.split("\n")
        for i, line in enumerate(lines):
            if line.startswith("| Parallel dev convention"):
                lines.insert(i + 1, INDEX_ROW)
                break
        joined = "\n".join(lines)
    return joined


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="verify the split, change nothing")
    ap.add_argument("--write", action="store_true", help="perform the split")
    args = ap.parse_args()

    if not (args.check or args.write):
        ap.error("pass --check or --write")

    text = AGENTS.read_text(encoding="utf-8")

    if args.check:
        ok = True
        # The rows now live in the registry file, so the comparison baseline is
        # the LAST COMMIT that still had the table in AGENTS.md.
        before_text = last_version_with_the_table()
        if before_text is None:
            print("FAIL  no commit with the table in AGENTS.md (= nothing to compare against)")
            return 1
        _, rows, _ = extract_section(before_text)
        if not rows:
            print("FAIL  the last version with the table has no rows")
            return 1

        if not NFI.exists():
            print("FAIL  docs/agents/nfi.md does not exist")
            ok = False
        else:
            existing = NFI.read_text(encoding="utf-8")
            missing = [r for r in rows.split("\n") if r and r not in existing]
            if missing:
                for r in missing[:5]:
                    print(f"FAIL  row missing from the registry: {r[:70]}")
                ok = False
            else:
                print(f"      {len(rows.split(chr(10)))} rows verified in the registry")
        if "| Parent (god-class) |" in text:
            print("FAIL  AGENTS.md still carries the table")
            ok = False
        else:
            print("      AGENTS.md carries the pointer, not the table")
        for rule in ("1.7", "1.11"):
            line = next((l for l in text.split("\n") if l.startswith(f"| {rule} |")), "")
            if "docs/agents/nfi.md" not in line:
                print(f"FAIL  rule {rule} still points at the old home")
                ok = False
            else:
                print(f"      rule {rule} points at the registry")
        if "| Nervous file index (NFI) |" not in text:
            print("FAIL  the §9 reference index has no NFI row")
            ok = False
        else:
            print("      the §9 reference index lists the registry")
        if "docs/agents/nfi.md merge=nfi-registry" not in (REPO / ".gitattributes").read_text(encoding="utf-8"):
            print("FAIL  .gitattributes has no key-level rule for the registry")
            ok = False
        else:
            print("      .gitattributes has the key-level rule")
        if not (REPO / "Scripts" / "merge-nfi-registry.py").exists():
            print("FAIL  Scripts/merge-nfi-registry.py does not exist")
            ok = False
        else:
            print("      the registry's merge driver exists")
        print("nfi-split:", "PASS" if ok else "FAIL")
        return 0 if ok else 1

    before, rows, after = extract_section(text)
    if not rows:
        print("no NFI rows found in AGENTS.md", file=sys.stderr)
        return 1

    nfi_text = HEADER + rows + "\n" + FOOTER
    new_agents = before + pointer_section() + after
    new_agents = update_rules(new_agents)

    NFI.parent.mkdir(parents=True, exist_ok=True)
    NFI.write_text(nfi_text, encoding="utf-8")
    AGENTS.write_text(new_agents, encoding="utf-8")
    print(f"wrote {NFI.relative_to(REPO)} ({len(rows.split(chr(10)))} rows)")
    print(f"wrote {AGENTS.relative_to(REPO)} (pointer + rules)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
