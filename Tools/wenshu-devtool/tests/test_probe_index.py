#!/usr/bin/env python3
"""test_probe_index.py — the probe index's own test suite.

The index and the probes directory must agree in both directions:

  1. every probe file in the directory has a row in the index
  2. every probe named in the index exists in the directory

Drift in either direction breaks the index. A probe with no row is a
measurement nobody can find, and a row with no probe behind it is a number
that no probe produced, which is worse than no row at all.

Every case runs on a FIXTURE written to a temporary directory, so proving
that the checker fails never means breaking the live index, and the cases
stay valid when the live tree changes. The live tree is read once, by the
first case, and it is read through a copy in a temporary directory.

Run:  python3 Tools/wenshu-devtool/tests/test_probe_index.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import re
import shutil
import sys
import tempfile
from pathlib import Path

DEVTOOL = Path(__file__).resolve().parent.parent
LIVE_INDEX = DEVTOOL / "probe-index.md"
LIVE_PROBES = DEVTOOL / "probes"

# A commit reference in the index: a short or full SHA.
COMMIT_RE = re.compile(r"^[0-9a-f]{7,40}$")

HEADER = ("Probe", "Subject measured", "Numbers printed", "Commit measured against")


def probe_files(directory: Path) -> list[str]:
    """The probe files in a directory, by file name, sorted.

    A directory entry that is not a regular file, or whose name starts
    with a dot, is not a probe.
    """
    return sorted(
        entry.name
        for entry in directory.iterdir()
        if entry.is_file() and not entry.name.startswith(".")
    )


def index_rows(index_text: str) -> list[dict[str, str]]:
    """The rows of the index table, one dict per row.

    The first column names the probe file. The header row and the
    separator row are not rows of the table.
    """
    rows: list[dict[str, str]] = []
    for line in index_text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) < len(HEADER):
            continue
        if set("".join(cells)) <= set("-: "):
            continue
        if cells[0].strip("`") == HEADER[0]:
            continue
        rows.append(
            {
                "probe": cells[0].strip("`"),
                "subject": cells[1],
                "numbers": cells[2],
                "commit": cells[3].strip("`"),
            }
        )
    return rows


def drift(index_text: str, probe_names: list[str]) -> list[str]:
    """The ways the index and the directory disagree.

    An empty list means they agree.
    """
    rows = index_rows(index_text)
    named = [row["probe"] for row in rows]
    problems: list[str] = []

    for name in probe_names:
        if name not in named:
            problems.append(f"probe file has no index row: {name}")
    for row in rows:
        if row["probe"] not in probe_names:
            problems.append(f"index row names a file that is not there: {row['probe']}")
        if not COMMIT_RE.match(row["commit"]):
            problems.append(f"index row carries no commit: {row['probe']}")
    for name in sorted({name for name in named if named.count(name) > 1}):
        problems.append(f"index names the probe more than once: {name}")
    return problems


def render_index(rows: list[dict[str, str]]) -> str:
    """The index markdown for a fixture."""
    lines = ["| " + " | ".join(HEADER) + " |", "| " + " | ".join("---" for _ in HEADER) + " |"]
    for row in rows:
        lines.append(
            "| `{}` | {} | {} | `{}` |".format(
                row["probe"], row["subject"], row["numbers"], row["commit"]
            )
        )
    return "\n".join(lines) + "\n"


def fixture(root: Path, probes: dict[str, str], rows: list[dict[str, str]]) -> tuple[str, list[str]]:
    """Write a fixture tree, and return its index text and probe names."""
    directory = root / "probes"
    directory.mkdir(parents=True, exist_ok=True)
    for name, body in probes.items():
        (directory / name).write_text(body, encoding="utf-8")
    (root / "probe-index.md").write_text(render_index(rows), encoding="utf-8")
    return render_index(rows), sorted(probes)


def row(probe: str, commit: str = "78536bc945dc") -> dict[str, str]:
    """One index row for a fixture."""
    return {
        "probe": probe,
        "subject": "a subject",
        "numbers": "a_number_pt",
        "commit": commit,
    }


# ------------------------------------------------------------------ cases --


def case_1_live_index_agrees_with_live_directory():
    """The live index and the live probes directory agree.

    The live tree is copied into a temporary directory first, so the
    comparison itself runs against a fixture and never writes to the
    repository.
    """
    if not LIVE_INDEX.is_file():
        return False, f"{LIVE_INDEX} does not exist"
    if not LIVE_PROBES.is_dir():
        return False, f"{LIVE_PROBES} does not exist"
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        shutil.copytree(LIVE_PROBES, root / "probes")
        shutil.copy2(LIVE_INDEX, root / "probe-index.md")
        index_text = (root / "probe-index.md").read_text(encoding="utf-8")
        names = probe_files(root / "probes")
        problems = drift(index_text, names)
    if problems:
        return False, "; ".join(problems)
    return True, f"{len(names)} probe(s) indexed"


def case_2_a_matching_pair_reports_no_drift():
    """An index that names every probe, and only those probes, is clean."""
    with tempfile.TemporaryDirectory() as tmp:
        index_text, names = fixture(
            Path(tmp),
            {"chat_bubble_metrics.swift": "// probe\n", "chip_metrics.swift": "// probe\n"},
            [row("chat_bubble_metrics.swift"), row("chip_metrics.swift")],
        )
        problems = drift(index_text, names)
    if problems:
        return False, "; ".join(problems)
    return True, "no drift reported"


def case_3_a_probe_without_a_row_is_reported():
    """A probe file added without an index row is drift.

    This is the failure the index exists to catch: the measurement is in
    the directory and nobody can find it.
    """
    with tempfile.TemporaryDirectory() as tmp:
        index_text, names = fixture(
            Path(tmp),
            {"chat_bubble_metrics.swift": "// probe\n", "chip_metrics.swift": "// probe\n"},
            [row("chat_bubble_metrics.swift")],
        )
        problems = drift(index_text, names)
    if not any("chip_metrics.swift" in problem for problem in problems):
        return False, f"the unindexed probe was not reported: {problems}"
    return True, "the unindexed probe was reported"


def case_4_a_row_without_a_probe_is_reported():
    """An index row naming a file that is not there is drift.

    This is the failure where the index carries a number that no probe
    produced.
    """
    with tempfile.TemporaryDirectory() as tmp:
        index_text, names = fixture(
            Path(tmp),
            {"chat_bubble_metrics.swift": "// probe\n"},
            [row("chat_bubble_metrics.swift"), row("ghost_metrics.swift")],
        )
        problems = drift(index_text, names)
    if not any("ghost_metrics.swift" in problem for problem in problems):
        return False, f"the row without a probe was not reported: {problems}"
    return True, "the row without a probe was reported"


def case_5_a_row_without_a_commit_is_reported():
    """A row with no commit carries a number nobody can place.

    The commit is what makes a number reusable, so a row without one is
    drift.
    """
    with tempfile.TemporaryDirectory() as tmp:
        index_text, names = fixture(
            Path(tmp),
            {"chat_bubble_metrics.swift": "// probe\n"},
            [row("chat_bubble_metrics.swift", commit="")],
        )
        problems = drift(index_text, names)
    if not any("commit" in problem for problem in problems):
        return False, f"the row without a commit was not reported: {problems}"
    return True, "the row without a commit was reported"


CASES = [
    ("the live index and the live directory agree", case_1_live_index_agrees_with_live_directory),
    ("a matching index and directory report no drift", case_2_a_matching_pair_reports_no_drift),
    ("a probe without an index row is reported", case_3_a_probe_without_a_row_is_reported),
    ("an index row without a probe is reported", case_4_a_row_without_a_probe_is_reported),
    ("an index row without a commit is reported", case_5_a_row_without_a_commit_is_reported),
]


def main() -> int:
    passed = 0
    failed = 0
    for name, case in CASES:
        try:
            ok, detail = case()
        except Exception as exc:  # a case that raises is a failure, not a crash
            ok, detail = False, f"raised {type(exc).__name__}: {exc}"
        if ok:
            passed += 1
            print(f"PASS  {name}")
        else:
            failed += 1
            print(f"FAIL  {name}: {detail}")
    print(f"{passed} passed, {failed} failed, {len(CASES)} total")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
