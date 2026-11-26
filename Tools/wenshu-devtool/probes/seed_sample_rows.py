#!/usr/bin/env python3
"""seed_sample_rows.py — count the board rows a dev seed wrote into a live store.

The sample plan is written by the app's own seed path. That path is the only
place the sample's identity is defined, so this probe reads the seed's source
and takes its title/body pairs from there: a copy of the literals in this file
would drift the moment the sample changed, and a drifted copy reports a number
for rows the app no longer writes.

READ-ONLY. `--dry-run` is the mode and there is no other: removal belongs to
the seed path, which replaces its own rows before it writes them. A probe that
deleted from a user's live store would be a second writer to a file the app
owns, and the number it reported afterwards would describe its own write.

Every line carries the tree it was measured on, because a count of nobody's
tree cannot be re-used. It exits 2 when it took no number, so a run that read
nothing cannot be read as a clean store.

Usage:
  python3 Tools/wenshu-devtool/probes/seed_sample_rows.py <store-dir-or-.store>
"""
from __future__ import annotations

import argparse
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

TABLE = "ZWSKANBANTASK"

# One sample row in the seed's own array: (status, title, body), three string
# literals on one line. The tuple is matched as a whole so a status word cannot
# be read as a title.
SAMPLE_LINE_RE = re.compile(
    r'^\s*\("(?P<status>[^"]*)",\s*"(?P<title>[^"]*)",\s*"(?P<body>[^"]*)"\),?\s*$'
)

STORE_FILENAME = "WenshuStore.store"


def repo_root() -> Path:
    """The checkout this probe is running from."""
    out = subprocess.run(
        ["git", "rev-parse", "show-toplevel"],
        cwd=Path(__file__).resolve().parent,
        capture_output=True,
        text=True,
    )
    return Path(out.stdout.strip()) if out.returncode == 0 else Path.cwd()


def tree_sha(root: Path) -> str:
    """The commit the measurement describes."""
    out = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=root, capture_output=True, text=True
    )
    return out.stdout.strip() or "no-commit"


def seed_source(root: Path, override: str | None) -> Path:
    """The file that defines the sample, or the path the operator named."""
    if override:
        return Path(override)
    return root / "Sources" / "WenshuApp" / "App" / "PlanSeed.swift"


def samples_from_source(path: Path) -> list[tuple[str, str]]:
    """The seed's (title, body) pairs, read out of the seed itself.

    A pair, never a title alone: a task the user wrote that borrows a sample's
    title is the user's, and the seed's own rows carry the body they were given.
    """
    pairs: list[tuple[str, str]] = []
    if not path.is_file():
        return pairs
    for line in path.read_text(encoding="utf-8").splitlines():
        m = SAMPLE_LINE_RE.match(line)
        if m:
            pairs.append((m.group("title"), m.group("body")))
    return pairs


def store_path(argument: str) -> Path:
    """The store file, given a directory or the file itself."""
    p = Path(argument).expanduser()
    if p.is_dir():
        return p / STORE_FILENAME
    return p


def report(label: str, value, tree: str) -> None:
    print(f"{label}: {value} (tree {tree[:12]})")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="count the board rows a dev seed wrote into a live store (read-only)"
    )
    ap.add_argument("store", help="the library directory or its .store file")
    ap.add_argument("--dry-run", action="store_true", help="the only mode; kept explicit")
    ap.add_argument("--seed-source", help="the seed file to read the sample from")
    args = ap.parse_args()

    root = repo_root()
    tree = tree_sha(root)
    source = seed_source(root, args.seed_source)

    pairs = samples_from_source(source)
    if not pairs:
        print(f"no sample pair could be read from {source} (tree {tree[:12]})", file=sys.stderr)
        return 2

    db = store_path(args.store)
    if not db.is_file():
        print(f"no store at {db} (tree {tree[:12]})", file=sys.stderr)
        return 2

    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        total = conn.execute(f"select count(*) from {TABLE}").fetchone()[0]
        rows = conn.execute(f"select ZTITLE, ZBODY from {TABLE}").fetchall()
    except sqlite3.Error as exc:
        print(f"the store could not be read ({exc}) (tree {tree[:12]})", file=sys.stderr)
        conn.close()
        return 2
    conn.close()

    # A row with no body is never taken, whatever its title says.
    keyed = {(t, b) for t, b in pairs}
    seed_rows = sum(1 for t, b in rows if (t, b) in keyed)
    bodyless = sum(1 for _t, b in rows if b is None)

    report("store", db, tree)
    report("sample pairs read from the seed", len(pairs), tree)
    report("rows total", total, tree)
    report("rows carrying a sample's title AND body", seed_rows, tree)
    report("rows with no body (never eligible)", bodyless, tree)
    report("rows that are not the seed's", total - seed_rows, tree)
    return 0


if __name__ == "__main__":
    sys.exit(main())
