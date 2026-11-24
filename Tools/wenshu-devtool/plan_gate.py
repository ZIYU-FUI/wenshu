#!/usr/bin/env python3
"""
plan_gate.py - the plan-of-record gate: does this scope's plan exist and hold together?

One question, one gate:

  CONTRACT  does the scope's plan of record carry all four parts (= a spec
            with the four canonical sections, an issues/ ticket set, an
            _index.md, and edges that resolve)?

WHY THE GATE EXISTS (measured on this repo, 2026-11-24):

  - 9 specs exist under `.scratch/`, and 0 `issues/` directories and 0
    `_index.md` (= the plan stops at the spec, so the scope's edges are
    never written down).
  - Nothing in the tree reads a plan: `effort_budget_gate.py` checks a
    card's `## EVIDENCE BUDGET` and nothing else, so "write a plan when a
    new requirement arrives" had no teeth.
  - A plan written into a card worktree's `.scratch/` died with that
    worktree (= 245 lines of spec, gone with the branch), so the plan of
    record lives in the SHARED checkout and this gate reads it there.

THE GATE READS THE SHARED CHECKOUT, NEVER A CARD WORKTREE. A worktree's
`.scratch/` is deleted with the worktree, so the plan is read from the
checkout that owns the repo's `.git` directory (= the main checkout), no
matter which checkout the caller stands in. `--repo` says WHICH repo, and
the plan is read from that repo's shared checkout.

WHAT A COMPLETE PLAN CARRIES:

  spec.md      the four canonical sections (= business / current state /
               Apple canonical / after fix), matched in any case, with or
               without a leading number, and in the repo's Chinese
               spelling too
  issues/      at least one ticket file (= NNN-slug.md)
  _index.md    the index, and every blocked-by edge in it naming an issue
               that exists

Usage:
    plan_gate.py --scope NAME   the plan of record for one scope
    plan_gate.py --card ID      the plan the card's body names
    plan_gate.py --json         machine-readable output

Exit code 0 = the plan of record is complete, 1 = it is missing or
incomplete (= the findings name what is missing).
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)

# The repo this file lives in. A card worktree carries its own copy of this
# tool, so the default is that worktree, and the gate resolves the shared
# checkout from it before it reads anything.
REPO = Path(__file__).resolve().parents[2]

# The four canonical spec sections (AGENTS.md 8.3), and the spellings a
# heading may carry for each of them.
#
# The Chinese spellings are written as escapes on purpose: this file carries
# no CJK characters (AGENTS.md 1.1), and a reader who wants to see the
# phrase can decode it. = = They are DATA (= the headings the repo's own
# Chinese spec uses), = = so the 1.1 exemption for data covers them.
SECTION_SPELLINGS = (
    ("business", ("business", "\u4e1a\u52a1")),
    ("current state", ("current state", "\u73b0\u72b6")),
    ("apple canonical", ("apple canonical", "apple \u5b98\u65b9\u4f9d\u636e")),
    (
        "after fix",
        ("after fix", "after the fix", "\u6539\u5b8c\u662f\u4ec0\u4e48\u6837"),
    ),
)

# A heading's leading index (= "1." / "2b."), dropped before the heading
# text is compared. = = The index is followed by a stop, = = so a heading
# that opens with a year keeps it. = = The Chinese enumeration comma is
# written as an escape, = = so this file carries no CJK characters.
LEADING_INDEX_RE = re.compile(r"^\s*\(?\d{1,3}[a-z]?\)?[.\u3001)]\s*")

# A markdown heading, and the CJK ideograph range.
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$")
CJK_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")

# A ticket file (= NNN-slug.md) and a ticket row in the index (= NNN-slug).
TICKET_FILE_RE = re.compile(r"^\d{3}-[A-Za-z0-9][A-Za-z0-9._-]*\.md$")
TICKET_ROW_RE = re.compile(r"^\d{3}-[A-Za-z0-9][A-Za-z0-9._-]*$")

# The edge vocabulary of the tracker convention (docs/agents/issue-tracker.md):
# an edge is written "blocked by: 003" or in a "Blocked by" column. = = The
# fullwidth colon is written as an escape, = = so this file carries no CJK
# characters.
BLOCKED_BY_RE = re.compile(r"blocked[\s-]*by", re.I)
BLOCKED_BY_LINE_RE = re.compile(r"blocked[\s-]*by\b\s*[:\uff1a]?\s*(.+)$", re.I)

# A ticket number inside an edge cell: three digits, not glued to a word.
TICKET_NUMBER_RE = re.compile(r"(?<![\w-])(\d{3})(?![\d])")

# The scope a card body names (= a `.scratch/<scope>/` path).
SCOPE_RE = re.compile(r"\.scratch/([A-Za-z0-9][A-Za-z0-9._-]*)")


def shared_checkout(repo: Path) -> Path:
    """The checkout that owns the plan of record for a repo.

    A card worktree's `.git` is a FILE that names the main checkout's
    `worktrees/<name>` directory, so the shared checkout is the directory
    that owns the `.git` directory the worktree points at. A repo whose
    `.git` is a directory IS the shared checkout.
    """
    git = repo / ".git"
    if git.is_dir():
        return repo
    if git.is_file():
        text = git.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"gitdir:\s*(.+)", text)
        if match:
            gitdir = Path(match.group(1).strip())
            if not gitdir.is_absolute():
                gitdir = repo / gitdir
            for parent in (gitdir, *gitdir.parents):
                if parent.name == ".git":
                    return parent.parent
    return repo


def strip_fenced_blocks(text: str) -> str:
    """Blank out every fenced code block, keeping the line count aligned.

    A spec that quotes another spec writes its four headings inside a
    fence, and a heading scan that reads the fence reads the example's
    headings as the spec's own.
    """
    out: list[str] = []
    fence: str | None = None
    for line in text.splitlines():
        stripped = line.lstrip()
        if fence is None:
            if stripped.startswith("```") or stripped.startswith("~~~"):
                fence = stripped[:3]
                out.append("")
                continue
            out.append(line)
        else:
            out.append("")
            if stripped.startswith(fence):
                fence = None
    return "\n".join(out)


def normalize_heading(text: str) -> str:
    """The heading as the vocabulary compares it.

    The index is dropped (= "## 1. Business" is the business section), the
    markdown decoration is dropped, and the case is folded.
    """
    stripped = text.strip()
    stripped = LEADING_INDEX_RE.sub("", stripped)
    stripped = stripped.strip("*_`~ \t")
    stripped = stripped.rstrip(":").strip()
    return re.sub(r"\s+", " ", stripped).lower()


def spelling_matches(normalized: str, spelling: str) -> bool:
    """Does a normalized heading carry this spelling?

    A heading that IS the spelling matches, and a heading that BEGINS with
    the spelling matches when the rest starts on a word boundary (= "Business
    (why it matters)"), so a section may carry a parenthetical. = = A
    Chinese spelling has no word boundary, = = so it matches on the prefix.
    """
    if normalized == spelling:
        return True
    if not normalized.startswith(spelling):
        return False
    if CJK_RE.search(spelling):
        return True
    return normalized[len(spelling):][:1] in (" ", ":", ",", "-", "(")


def spec_sections(spec_text: str) -> list[str]:
    """The canonical sections the spec carries, in the canonical order."""
    found: set[str] = set()
    for line in strip_fenced_blocks(spec_text).splitlines():
        match = HEADING_RE.match(line)
        if match is None:
            continue
        normalized = normalize_heading(match.group(2))
        if not normalized:
            continue
        for name, spellings in SECTION_SPELLINGS:
            if name in found:
                continue
            if any(spelling_matches(normalized, spelling) for spelling in spellings):
                found.add(name)
    return [name for name, _ in SECTION_SPELLINGS if name in found]


def table_cells(line: str) -> list[str] | None:
    """The cells of a markdown table row, or None when the line is not one."""
    stripped = line.strip()
    if not stripped.startswith("|"):
        return None
    return [cell.strip() for cell in stripped.strip("|").split("|")]


def is_separator_row(cells: list[str]) -> bool:
    """Is this the rule under a table's header (= no data)?"""
    return bool(cells) and all(re.fullmatch(r":?-{2,}:?", cell) for cell in cells)


def read_index(index_text: str) -> tuple[list[dict], list[str]]:
    """The blocked-by edges the index carries, and its ticket rows.

    Two shapes carry an edge (= the tracker convention): a "Blocked by"
    column in the issue table, and a "blocked by: NNN" line. = = A cell
    that names no ticket (= a dash) carries no edge.

    A table's rows are read only while the table lasts: a blank line ends
    it, so the second table in a file is read on its own header.
    """
    edges: list[dict] = []
    rows: list[str] = []
    column: int | None = None
    lines = index_text.splitlines()
    for lineno, line in enumerate(lines, 1):
        if not line.strip():
            column = None
            continue
        cells = table_cells(line)
        if cells is None:
            continue
        if column is None:
            hits = [i for i, cell in enumerate(cells) if BLOCKED_BY_RE.search(cell)]
            if hits:
                column = hits[0]
            continue
        if is_separator_row(cells):
            continue
        source = cells[0] if cells else ""
        if TICKET_ROW_RE.match(source):
            rows.append(source)
        cell = cells[column] if column < len(cells) else ""
        for number in TICKET_NUMBER_RE.findall(cell):
            edges.append(
                {"source": source, "target": number, "where": f"_index.md:{lineno}"}
            )
    for lineno, line in enumerate(lines, 1):
        if line.lstrip().startswith("|"):
            continue
        match = BLOCKED_BY_LINE_RE.search(line)
        if match is None:
            continue
        for number in TICKET_NUMBER_RE.findall(match.group(1)):
            edges.append(
                {"source": "", "target": number, "where": f"_index.md:{lineno}"}
            )
    return edges, rows


def ticket_files(issues_dir: Path) -> list[str]:
    """The ticket files in the issues directory, by name."""
    if not issues_dir.is_dir():
        return []
    return sorted(
        path.name
        for path in issues_dir.iterdir()
        if path.is_file() and TICKET_FILE_RE.match(path.name)
    )


def check_scope(repo: Path, scope: str) -> dict:
    """Read a scope's plan of record and report whether it is complete."""
    checkout = shared_checkout(repo)
    plan_dir = checkout / ".scratch" / scope
    findings: list[str] = []

    if not plan_dir.is_dir():
        findings.append(f"the scope has no plan directory ({plan_dir})")

    spec_path = plan_dir / "spec.md"
    spec_exists = spec_path.is_file()
    sections: list[str] = []
    missing: list[str] = []
    if spec_exists:
        sections = spec_sections(spec_path.read_text(encoding="utf-8", errors="replace"))
        missing = [name for name, _ in SECTION_SPELLINGS if name not in sections]
        for name in missing:
            findings.append(f"the spec has no '{name}' section")
    else:
        findings.append(f"the plan has no spec.md ({spec_path})")

    issues_dir = plan_dir / "issues"
    issues_exists = issues_dir.is_dir()
    files = ticket_files(issues_dir)
    if not issues_exists:
        findings.append(f"the plan has no issues/ directory ({issues_dir})")
    elif not files:
        findings.append("the issues/ directory holds no ticket file (NNN-slug.md)")

    index_path = issues_dir / "_index.md"
    index_exists = index_path.is_file()
    edges: list[dict] = []
    rows: list[str] = []
    if index_exists:
        edges, rows = read_index(index_path.read_text(encoding="utf-8", errors="replace"))
        known = {name.split("-", 1)[0] for name in files}
        for edge in edges:
            edge["resolved"] = edge["target"] in known
            if not edge["resolved"]:
                source = edge["source"] or "?"
                findings.append(
                    f"the blocked-by edge {source} -> {edge['target']} names an "
                    "issue that does not exist"
                )
    else:
        findings.append(f"the plan has no issues/_index.md ({index_path})")

    return {
        "scope": scope,
        "card": "",
        "board": "",
        "repo": str(repo),
        "shared_checkout": str(checkout),
        "plan_dir": str(plan_dir),
        "spec": {
            "path": str(spec_path),
            "exists": spec_exists,
            "sections": sections,
            "missing": missing,
        },
        "issues": {
            "dir": str(issues_dir),
            "exists": issues_exists,
            "declared": rows,
            "files": files,
        },
        "index": {"path": str(index_path), "exists": index_exists},
        "edges": edges,
        "findings": findings,
        "ok": not findings,
    }


def extract_scopes(body: str) -> list[str]:
    """The scope names a card body names, in the order it names them.

    A card names its plan of record by the path it lives at (= the
    `.scratch/<scope>/` a card body carries).
    """
    seen: list[str] = []
    for match in SCOPE_RE.finditer(body or ""):
        name = match.group(1)
        if name not in seen:
            seen.append(name)
    return seen


def scope_dirs(checkout: Path) -> list[str]:
    """The scope folders the shared checkout's .scratch holds."""
    scratch = checkout / ".scratch"
    if not scratch.is_dir():
        return []
    return sorted(path.name for path in scratch.iterdir() if path.is_dir())


def board_body(board: str, card_id: str) -> str | None:
    """One card's body from one board, or None when the board does not hold it.

    The board database is read read-only and in place (= no board is
    written, and no board is copied).
    """
    db = Path(product_lines.board_db(board))
    if not db.exists():
        return None
    try:
        conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
        row = conn.execute("SELECT body FROM tasks WHERE id = ?", (card_id,)).fetchone()
        conn.close()
    except sqlite3.Error:
        return None
    if row is None:
        return None
    body = row[0] or ""
    if isinstance(body, bytes):
        body = body.decode("utf-8", "replace")
    return body


def card_body(card_id: str, board: str) -> tuple[str, str]:
    """The card's body and the board it was read from (= "" when unreadable)."""
    for slug in (board, *product_lines.BOARDS):
        body = board_body(slug, card_id)
        if body is not None:
            return body, slug
    return "", ""


def scope_of_card(card_id: str, board: str, checkout: Path) -> tuple[str, list[str], str]:
    """The scope a card names, every scope its body names, and its board."""
    body, slug = card_body(card_id, board)
    candidates = extract_scopes(body)
    if not candidates:
        candidates = [name for name in scope_dirs(checkout) if name and name in body]
    for candidate in candidates:
        if (checkout / ".scratch" / candidate).is_dir():
            return candidate, candidates, slug
    if candidates:
        return candidates[0], candidates, slug
    return "", candidates, slug


# The contract epoch. A card created before this date is reported, never
# blocked: the cards already on the board were typed under the old rule,
# and rewriting them is not this tool's business (= the same shape as
# effort_budget_gate.EVIDENCE_CONTRACT_FROM).
PLAN_CONTRACT_FROM = 1795449600  # 2026-11-24 00:00 CST


def is_subject(created_at: int | None) -> bool:
    """Is this card under the plan contract?

    A card with no creation time is treated as a subject: a card the board
    cannot date is a card the board cannot excuse.
    """
    if created_at is None:
        return True
    return int(created_at) >= PLAN_CONTRACT_FROM


def contract_errors(body: str, repo: Path | None = None) -> list[str]:
    """Every way the card's plan of record is missing or incomplete.

    A card that names NO scope is not judged: a bug fix, a review card, or
    a card for work that carries no new requirement is not a plan's
    business. The rule fires on the cards that CLAIM a plan of record, and
    those are the ones that promise a plan exists.

    The plan is read in the SHARED checkout, so a card's worktree never
    decides whether a plan exists.
    """
    scopes = extract_scopes(body)
    if not scopes:
        return []
    repo = Path(repo).resolve() if repo else REPO
    errors: list[str] = []
    for scope in scopes:
        report = check_scope(repo, scope)
        if report["ok"]:
            continue
        errors.append(
            f"the plan of record for scope {scope} is incomplete: "
            + "; ".join(report["findings"])
        )
    return errors


def print_report(report: dict) -> None:
    """Print the plan the gate read, the scope it read it for, and the verdict."""
    print(f"=== plan gate: scope {report['scope']}")
    if report["card"]:
        print(f"    card:     {report['card']} (board {report['board']})")
    print(f"    repo:     {report['repo']}")
    print(f"    checkout: {report['shared_checkout']}")
    print(f"    plan:     {report['plan_dir']}")

    spec = report["spec"]
    if spec["exists"]:
        sections = ", ".join(spec["sections"]) or "(none)"
        print(
            f"    spec:     {spec['path']}  "
            f"({len(spec['sections'])} of 4 sections: {sections})"
        )
    else:
        print(f"    spec:     {spec['path']}  (missing)")

    issues = report["issues"]
    print(f"    issues:   {issues['dir']}")
    for issue in issues["declared"]:
        print(f"                index row: {issue}")
    for ticket in issues["files"]:
        print(f"                ticket:    {ticket}")

    index = report["index"]
    print(f"    index:    {index['path']}  ({'present' if index['exists'] else 'missing'})")
    for edge in report["edges"]:
        state = "resolved" if edge.get("resolved") else "MISSING"
        source = edge["source"] or "?"
        print(f"    edge:     {source} -> {edge['target']}  ({state})")

    for finding in report["findings"]:
        print(f"    ! {finding}")
    if report["ok"]:
        print("    ok:       the plan of record is complete")
    else:
        print("    NOT OK:   the plan of record is incomplete")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--scope", help="the scope folder under .scratch")
    target.add_argument("--card", help="the card whose body names the plan of record")
    parser.add_argument("--repo", default=str(REPO), help="the repo the plan belongs to")
    parser.add_argument("--board", default=product_lines.DEFAULT_BOARD, help="board slug")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args(argv)

    repo = Path(args.repo).resolve()
    checkout = shared_checkout(repo)

    card = ""
    board = ""
    scope = args.scope or ""
    if args.card:
        card = args.card
        scope, _candidates, board = scope_of_card(card, args.board, checkout)
        if not scope:
            report = {
                "scope": "",
                "card": card,
                "board": board,
                "repo": str(repo),
                "shared_checkout": str(checkout),
                "plan_dir": "",
                "spec": {"path": "", "exists": False, "sections": [], "missing": []},
                "issues": {"dir": "", "exists": False, "declared": [], "files": []},
                "index": {"path": "", "exists": False},
                "edges": [],
                "findings": [
                    f"the card {card} names no plan of record (= no .scratch/<scope>/ path)"
                ],
                "ok": False,
            }
            if args.json:
                print(json.dumps(report, indent=2))
            else:
                print_report(report)
            return 1

    report = check_scope(repo, scope)
    report["card"] = card
    report["board"] = board

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
