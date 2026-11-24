#!/usr/bin/env python3
"""test_closeout_gate.py — the closeout gate's own suite.

THE GATE FIRES ON THE SCOPE'S STATE. The eight closeout steps are audited
when every ticket of a scope's plan has landed, and the gate says which
tickets have not when the scope is still open. So the suite builds FIXTURE
repos (= a git repo with a main branch, a scope's plan directory, a
`.gate-logs/` directory, a docs/agents closure doc, a fixture board
database, a fixture skills tree) and reads the gate's own report over them.

THE CASES:

  1. a scope whose tickets have NOT all landed exits 0, and it NAMES the
     ticket that has not;
  2. a ticket's branch is read from its body and from its index row, a
     ticket whose branch tip is not an ancestor of main is not landed, and a
     ticket with no branch named is not landed and is named;
  3. a scope whose tickets HAVE all landed prints EIGHT lines, one per step,
     in the canonical order of standard-closeout.md;
  4. a scope with all eight steps' evidence present exits 0;
  5. a scope with one step's evidence missing exits 1 and NAMES the missing
     step;
  6. a scope whose own residue is still on the tree reports step 5 MISSING
     and names the worktree and the branch;
  7. a scope with no plan of record exits 2;
  8. the report is machine-readable.

Run:  python3 Tools/wenshu-devtool/tests/test_closeout_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "closeout_gate.py"

FAILURES: list[str] = []


def load_tool():
    """Import closeout_gate.py as a module, whatever its directory is."""
    spec = importlib.util.spec_from_file_location("closeout_gate", TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(name: str, got, want) -> None:
    """Assert one case, and record the failure instead of raising."""
    if got == want:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}\n          got:  {got!r}\n          want: {want!r}")
        FAILURES.append(name)


def git(repo: Path, *args: str) -> str:
    """Run one git command in the fixture repo."""
    proc = subprocess.run(["git", "-C", str(repo), *args],
                          capture_output=True, text=True, check=True)
    return proc.stdout.strip()


# ===========================================================================
# THE FIXTURES
# ===========================================================================
SCOPE = "2026-11-24-fixture-scope"
TICKET_A = "001-the-first-ticket"
TICKET_B = "002-the-second-ticket"
BRANCH_A = "wt/ticket-a"
BRANCH_B = "wt/ticket-b"


def make_board(path: Path, cards: list[tuple[str, str, str, str, str | None]]) -> None:
    """A board database with the tables the gate reads.

    Each card is (id, title, body, status, verdict). A card with a verdict
    carries a task_runs row whose metadata holds `review_outcome`.
    """
    conn = sqlite3.connect(path)
    conn.execute("DROP TABLE IF EXISTS tasks")
    conn.execute("DROP TABLE IF EXISTS task_runs")
    conn.execute("CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT, body TEXT, status TEXT)")
    conn.execute(
        "CREATE TABLE task_runs (id INTEGER PRIMARY KEY AUTOINCREMENT, task_id TEXT, "
        "status TEXT, metadata TEXT)"
    )
    for card_id, title, body, status, verdict in cards:
        conn.execute(
            "INSERT INTO tasks (id, title, body, status) VALUES (?, ?, ?, ?)",
            (card_id, title, body, status),
        )
        if verdict:
            conn.execute(
                "INSERT INTO task_runs (task_id, status, metadata) VALUES (?, 'done', ?)",
                (card_id, json.dumps({"review_outcome": verdict})),
            )
    conn.commit()
    conn.close()


def make_repo(root: Path, *, landed: bool = True) -> dict:
    """A fixture repo: a main branch, a scope's plan, a gate log, a doc.

    `landed` decides whether the tickets' branch tips are ancestors of main.
    A ticket that has not landed is named by the report, so the fixture keeps
    both branch tips out of main's history when `landed` is False.

    The two tickets land in order, so `main`'s tip IS the last landed
    ticket's tip (= the state the final-state step reads).
    """
    repo = root / "repo"
    repo.mkdir(parents=True)
    git(repo, "init", "-q", "-b", "main")
    git(repo, "config", "user.email", "fixture@example.invalid")
    git(repo, "config", "user.name", "fixture")
    (repo / "docs" / "agents").mkdir(parents=True)
    (repo / ".gate-logs").mkdir()
    (repo / ".scratch" / SCOPE / "issues").mkdir(parents=True)

    (repo / "README.md").write_text("fixture\n", encoding="utf-8")
    git(repo, "add", "README.md")
    git(repo, "commit", "-q", "-m", "the fixture's first commit")

    # The first ticket's branch, one commit ahead of main.
    git(repo, "checkout", "-q", "-b", BRANCH_A)
    (repo / "a.txt").write_text("ticket\n", encoding="utf-8")
    git(repo, "add", "a.txt")
    git(repo, "commit", "-q", "-m", f"the {BRANCH_A} commit")
    if landed:
        git(repo, "checkout", "-q", "main")
        git(repo, "merge", "-q", "--ff-only", BRANCH_A)

    # The second ticket's branch: on top of the first when the scope landed,
    # beside it when it did not.
    git(repo, "checkout", "-q", "-b", BRANCH_B)
    (repo / "b.txt").write_text("ticket\n", encoding="utf-8")
    git(repo, "add", "b.txt")
    git(repo, "commit", "-q", "-m", f"the {BRANCH_B} commit")
    git(repo, "checkout", "-q", "main")
    if landed:
        git(repo, "merge", "-q", "--ff-only", BRANCH_B)
    merged = git(repo, "rev-parse", "main")

    # The plan of record: the index names both tickets, and the first
    # ticket's body names its branch (= the two places a branch is read).
    index = repo / ".scratch" / SCOPE / "issues" / "_index.md"
    index.write_text(
        "# Index — fixture scope\n\n"
        "| Issue | State | Blocked by | Branch |\n"
        "| ----- | ----- | ---------- | ------ |\n"
        f"| {TICKET_A} | ready | — | {BRANCH_A} |\n"
        f"| {TICKET_B} | ready | — | {BRANCH_B} |\n",
        encoding="utf-8",
    )
    (repo / ".scratch" / SCOPE / "issues" / f"{TICKET_A}.md").write_text(
        f"# {TICKET_A}\n\n## WHAT TO BUILD\n\n- the first thing\n\n"
        f"its branch is `{BRANCH_A}`\n",
        encoding="utf-8",
    )
    (repo / ".scratch" / SCOPE / "issues" / f"{TICKET_B}.md").write_text(
        f"# {TICKET_B}\n\n## WHAT TO BUILD\n\n- the second thing\n",
        encoding="utf-8",
    )

    # The gate log names the merged sha (= step 1's evidence).
    (repo / ".gate-logs" / "fixture_a1_1.log").write_text(
        f"comment-lineage: window aaaaaaaa..{merged}\n", encoding="utf-8"
    )

    # The closure doc names the scope (= step 3's evidence).
    (repo / "docs" / "agents" / f"2026-11-24-session-close-{SCOPE}.md").write_text(
        f"# The closeout of {SCOPE}\n", encoding="utf-8"
    )

    # The fixture board (= steps 2 and 7's evidence).
    board = root / "board" / "kanban.db"
    board.parent.mkdir(parents=True)
    make_board(board, [
        ("t_aaaa0001", f"[T1] the scope's card {SCOPE}", f"the {SCOPE} card",
         "done", "approved"),
        ("t_bbbb0002", "an unrelated card", "not about the scope", "done", None),
    ])

    # The fixture skills tree (= step 4's evidence). Its file is newer than
    # the scope's last landed commit, which the mtime reading requires.
    # The tree also carries a `.git/`, because the shared tree is a git
    # repository (= a `.git/` internal is not a lesson).
    skills = root / "skills"
    skills.mkdir()
    (skills / ".git" / "refs" / "heads").mkdir(parents=True)
    (skills / ".git" / "refs" / "heads" / "main").write_text("sha\n", encoding="utf-8")
    lesson = skills / "fixture-lesson.md"
    lesson.write_text(f"# The {SCOPE} lesson\n", encoding="utf-8")
    future = int(git(repo, "show", "-s", "--format=%ct", merged)) + 3600
    os.utime(lesson, (future, future))
    os.utime(skills / ".git" / "refs" / "heads" / "main", (future, future))

    return {"repo": repo, "board": board, "skills": skills, "merged": merged}


def run_gate(tool, scope: str, paths: dict) -> tuple[int, str]:
    """Run the gate over a fixture and return its exit code and its output."""
    argv = ["--scope", scope, "--repo", str(paths["repo"]),
            "--board", str(paths["board"]), "--skills", str(paths["skills"])]
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        code = tool.main(argv)
    return code, buffer.getvalue()


def step_lines(out: str) -> list[str]:
    """The gate's eight step lines, in the order they printed."""
    marks = tuple(f"{n} |" for n in range(1, 9))
    return [ln for ln in out.splitlines() if ln.strip().startswith(marks)]


def main() -> int:
    tool = load_tool()
    print("closeout gate: the eight steps, fired by the scope's state\n")

    root = Path(tempfile.mkdtemp(prefix="closeout-gate-"))
    try:
        landed = make_repo(root / "landed", landed=True)
        open_scope = make_repo(root / "open", landed=False)
        empty = make_repo(root / "empty", landed=True)
        # A scope with no plan of record at all.
        for path in (empty["repo"] / ".scratch" / SCOPE / "issues").glob("*.md"):
            path.unlink()

        # ------------------------------------------------------------------
        # 1. a scope whose tickets have NOT all landed exits 0 and NAMES the
        #    ticket that has not
        # ------------------------------------------------------------------
        code, out = run_gate(tool, SCOPE, open_scope)
        check("1. a scope that has not landed exits 0", code, 0)
        check(
            "1b. and the output says nothing is due",
            "has NOT landed" in out and "nothing is due yet" in out,
            True,
        )
        check(
            "1c. and it names the ticket that has not landed",
            f"not landed: {TICKET_A}" in out and f"not landed: {TICKET_B}" in out,
            True,
        )
        check(
            "1d. and the eight steps are not printed",
            step_lines(out) == [],
            True,
        )

        # ------------------------------------------------------------------
        # 2. a branch is read from the body and from the index row, a branch
        #    that is not on main is not landed, and no branch is not landed
        # ------------------------------------------------------------------
        tickets = tool.read_tickets(str(open_scope["repo"]), SCOPE)
        by_id = {t["id"]: t for t in tickets["tickets"]}
        check("2. the index's rows are the ticket set",
              sorted(by_id), sorted([TICKET_A, TICKET_B]))
        check(
            "2b. a branch named in the body is read from the body",
            (by_id[TICKET_A]["branch"], by_id[TICKET_A]["branch_source"]),
            (BRANCH_A, "body"),
        )
        check(
            "2c. a branch named in the index row is read from the index row",
            (by_id[TICKET_B]["branch"], by_id[TICKET_B]["branch_source"]),
            (BRANCH_B, "index row"),
        )
        check(
            "2d. a ticket whose branch is not on main is not landed",
            by_id[TICKET_A]["landed"],
            False,
        )
        check(
            "2e. and the report says why",
            "not an ancestor of main" in by_id[TICKET_A]["why"],
            True,
        )
        no_branch = tool.read_tickets(str(landed["repo"]), SCOPE)
        no_branch["tickets"][0]["branch"] = None
        ok, why, _tip = tool.ticket_landed(str(landed["repo"]), no_branch["tickets"][0])
        check("2f. a ticket with no branch named is not landed", ok, False)
        check("2g. and it is named as such", "no branch named" in why, True)

        # ------------------------------------------------------------------
        # 3. a scope whose tickets HAVE all landed prints EIGHT lines, one per
        #    step, in the canonical order
        # ------------------------------------------------------------------
        code, out = run_gate(tool, SCOPE, landed)
        lines = step_lines(out)
        check("3. a landed scope prints eight step lines", len(lines), 8)
        check(
            "3b. and they come out in the canonical order",
            [ln.split("|")[0].strip() for ln in lines],
            [str(n) for n in range(1, 9)],
        )
        check(
            "3c. and they carry the eight steps' names",
            [ln.split("|")[1].strip() for ln in lines],
            [name for _n, name in tool.STEPS],
        )
        check(
            "3d. and each line carries a verdict and its evidence",
            all(len(ln.split("|")) >= 4
                and ln.split("|")[2].strip() in ("PASS", "MISSING")
                and ln.split("|")[3].strip() != "" for ln in lines),
            True,
        )

        # ------------------------------------------------------------------
        # 4. a scope with all eight steps' evidence present exits 0
        # ------------------------------------------------------------------
        check("4. a scope with every step's evidence exits 0", code, 0)
        check(
            "4b. and every step reads PASS",
            [ln.split("|")[2].strip() for ln in lines],
            ["PASS"] * 8,
        )
        check(
            "4c. and the output says so",
            "all eight steps carry their evidence" in out,
            True,
        )
        check(
            "4d. and the evidence is concrete",
            ".gate-logs/fixture_a1_1.log" in out
            and "t_aaaa0001" in out
            and "docs/agents" in out
            and "fixture-lesson.md" in out
            and BRANCH_B in out,
            True,
        )
        check(
            "4e. and the skills reading is a skill file, not a .git internal",
            ".git" not in out.split("fixture-lesson.md")[0].rsplit("\n", 1)[-1],
            True,
        )

        # ------------------------------------------------------------------
        # 5. a scope with one step's evidence missing exits 1 and NAMES the
        #    missing step
        # ------------------------------------------------------------------
        broken = make_repo(root / "broken", landed=True)
        (broken["repo"] / ".gate-logs" / "fixture_a1_1.log").unlink()
        code, out = run_gate(tool, SCOPE, broken)
        check("5. a missing step's evidence exits 1", code, 1)
        check(
            "5b. and the missing step is named",
            "1 Re-run the section 7 gates on the MERGED tree" in out,
            True,
        )
        check(
            "5c. and the step's line reads MISSING with what it looked for",
            "no log under" in out and ".gate-logs" in out,
            True,
        )
        check(
            "5d. and the other seven steps still print",
            [ln.split("|")[2].strip() for ln in step_lines(out)],
            ["MISSING"] + ["PASS"] * 7,
        )

        # A second broken scope: the verdict is missing (step 2).
        no_verdict = make_repo(root / "no-verdict", landed=True)
        make_board(no_verdict["board"], [
            ("t_aaaa0001", f"[T1] the scope's card {SCOPE}", f"the {SCOPE} card",
             "done", None),
        ])
        code, out = run_gate(tool, SCOPE, no_verdict)
        check("5e. a scope with no approved verdict exits 1", code, 1)
        check(
            "5f. and step 2 is the one that is missing",
            "2 Record the verdict on the board" in out and "review_outcome=approved" in out,
            True,
        )

        # A third broken scope: a card of the scope is still open (step 7).
        open_card = make_repo(root / "open-card", landed=True)
        make_board(open_card["board"], [
            ("t_aaaa0001", f"[T1] the scope's card {SCOPE}", f"the {SCOPE} card",
             "done", "approved"),
            ("t_cccc0003", f"[T1] the scope's other card {SCOPE}", f"the {SCOPE} card",
             "blocked", "approved"),
        ])
        code, out = run_gate(tool, SCOPE, open_card)
        check("5g. a scope with a card still open exits 1", code, 1)
        check(
            "5h. and step 7 is the one that is missing",
            "7 Sweep the board's open columns" in out and "t_cccc0003" in out,
            True,
        )

        # A fourth broken scope: something landed on top of the scope, so
        # main is not at the scope's last landed commit (step 6).
        on_top = make_repo(root / "on-top", landed=True)
        (on_top["repo"] / "c.txt").write_text("a sibling\n", encoding="utf-8")
        git(on_top["repo"], "add", "c.txt")
        git(on_top["repo"], "commit", "-q", "-m", "a sibling's commit")
        code, out = run_gate(tool, SCOPE, on_top)
        check("5i. a scope with a sibling's commit on top exits 1", code, 1)
        check(
            "5j. and step 6 is the one that is missing",
            "6 Re-check the final state and report it" in out
            and "something landed on top of the scope" in out,
            True,
        )
        check(
            "5k. and step 8 still passes (= ancestry, not the tip)",
            "8 | THE CARD YOU DISPATCHED IS YOURS TO LAND | PASS" in out,
            True,
        )

        # ------------------------------------------------------------------
        # 6. a scope whose own residue is still on the tree reports step 5
        #    MISSING and names the worktree and the branch
        # ------------------------------------------------------------------
        residue = make_repo(root / "residue", landed=True)
        git(residue["repo"], "branch", "wt/fixture-scope-leftover")
        (residue["repo"] / ".worktrees").mkdir(exist_ok=True)
        (residue["repo"] / ".worktrees" / "fixture-scope-leftover").mkdir()
        code, out = run_gate(tool, SCOPE, residue)
        check("6. a scope with its own residue exits 1", code, 1)
        check(
            "6b. and step 5 is the one that is missing",
            "5 Clean up YOUR OWN residue" in out,
            True,
        )
        check(
            "6c. and it names the worktree and the branch",
            "wt/fixture-scope-leftover" in out
            and ".worktrees/fixture-scope-leftover" in out,
            True,
        )

        # ------------------------------------------------------------------
        # 7. a scope with no plan of record exits 2
        # ------------------------------------------------------------------
        code, _out = run_gate(tool, SCOPE, empty)
        check("7. a scope with no plan of record exits 2", code, 2)

        # ------------------------------------------------------------------
        # 8. the report is machine-readable
        # ------------------------------------------------------------------
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            tool.main(["--scope", SCOPE, "--repo", str(landed["repo"]),
                       "--board", str(landed["board"]), "--skills", str(landed["skills"]),
                       "--json"])
        payload = json.loads(buffer.getvalue())
        check("8. the JSON report carries the eight steps", len(payload["steps"]), 8)
        check(
            "8b. and the scope's state",
            (payload["landed"], payload["missing_steps"]),
            (True, []),
        )
    finally:
        shutil.rmtree(root, ignore_errors=True)

    print()
    if FAILURES:
        print(f"closeout gate: {len(FAILURES)} case(s) FAILED")
        for name in FAILURES:
            print(f"  - {name}")
        return 1
    print("closeout gate: all cases passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
