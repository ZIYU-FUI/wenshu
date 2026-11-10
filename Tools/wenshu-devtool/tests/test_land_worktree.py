#!/usr/bin/env python3
"""The landing script's worktree resolution, = = and the card's own path
is the authority.

= = ⇒ WHY THIS TEST EXISTS. = = = = The landing script used to hardcode
# = = = = `.worktrees/<card id>` as the worktree's path. = = = = A card
# = = = = whose workspace points at an existing worktree (= = = = the
# = = = = review lane's own, = = = = which is where the reviewer read the
# = = = = tree from) has its worktree elsewhere, = = = = and the script
# = = = = then rebased a path that does not exist, = = = = said
# = = = = "REBASE CONFLICT", = = = = and landed nothing.

= = ⇒ AND THE MEASUREMENT IS THE CARD'S OWN ROW. = = = = The board keeps
# = = = = the worktree in `tasks.workspace_path`, = = = = beside the
# = = = = `workspace_kind` that says whether it names a directory or a git
# = = = = worktree.

= = ⇒ AND A PATH THAT IS NOT THERE IS NOT A PATH. = = = = Printing it
# = = = = would send the landing script straight back into the failure
# = = = = this exists to fix.

= = ⇒ AND A CARD THAT NAMES NO WORKTREE NAMES NONE. = = = = The empty
# = = = = string is the answer, = = = = and the caller falls back to the
# = = = = convention.
"""

from __future__ import annotations

import importlib.util
import sqlite3
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
HELPER = HERE.parent.parent.parent / "Scripts" / "land_worktree.py"

FAILURES: list[str] = []


def load_helper():
    spec = importlib.util.spec_from_file_location("land_worktree", HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def expect(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}  {detail[:200]}")
        FAILURES.append(name)


def make_board(tmp: Path, rows: list[tuple[str, str, str]]) -> str:
    """A board file with the columns the helper reads, and those rows."""
    db = tmp / "board.db"
    con = sqlite3.connect(db)
    con.execute(
        "CREATE TABLE tasks (id TEXT PRIMARY KEY, workspace_path TEXT, workspace_kind TEXT)"
    )
    for row in rows:
        con.execute("INSERT INTO tasks (id, workspace_path, workspace_kind) VALUES (?,?,?)", row)
    con.commit()
    con.close()
    return str(db)


def case_the_cards_own_worktree_is_the_answer() -> None:
    """THE DEFECT THE FIX EXISTS FOR: = = a card's worktree is NOT at
    `.worktrees/<card id>`.

    = = ⇒ Measured on the tree's own board: = = = = a review card whose
    # = = = = workspace is a directory named after the FEATURE reported
    # = = = = `fatal: cannot change to '.../.worktrees/<card id>': No such
    # = = = = file or directory` and its branch never reached main.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        worktree = tmp / "split-import-sheet"
        worktree.mkdir()
        db = make_board(tmp, [("t_abc123", str(worktree), "dir")])
        helper = load_helper()
        got = helper.card_workspace(db, "t_abc123")
        expect(
            "the card's own worktree is the answer",
            got == str(worktree),
            f"got {got!r}, want {str(worktree)!r}",
        )


def case_a_worktree_kind_is_named_too() -> None:
    """A `worktree` kind names a real directory, and it counts."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        worktree = tmp / "feature-named"
        worktree.mkdir()
        db = make_board(tmp, [("t_wt", str(worktree), "worktree")])
        helper = load_helper()
        got = helper.card_workspace(db, "t_wt")
        expect(
            "a worktree-kind workspace is named too",
            got == str(worktree),
            f"got {got!r}",
        )


def case_a_path_that_is_not_there_is_not_a_path() -> None:
    """A workspace that does not exist names nothing.

    = = ⇒ Printing it would send the landing script back into the failure.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        db = make_board(tmp, [("t_gone", str(tmp / "never-made"), "dir")])
        helper = load_helper()
        got = helper.card_workspace(db, "t_gone")
        expect("a path that is not there names nothing", got == "", f"got {got!r}")


def case_a_kind_that_is_not_a_worktree_names_nothing() -> None:
    """Only `dir` and `worktree` name a worktree."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        scratch = tmp / "scratch"
        scratch.mkdir()
        db = make_board(tmp, [("t_scratch", str(scratch), "scratch")])
        helper = load_helper()
        got = helper.card_workspace(db, "t_scratch")
        expect("a scratch workspace names nothing", got == "", f"got {got!r}")


def case_a_card_that_is_not_on_the_board_names_nothing() -> None:
    """A card id that is not on the board names nothing."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        db = make_board(tmp, [("t_here", str(tmp), "dir")])
        helper = load_helper()
        got = helper.card_workspace(db, "t_absent")
        expect("a card that is not on the board names nothing", got == "", f"got {got!r}")


def case_the_helper_reads_the_board_the_environment_names() -> None:
    """AND THE BOARD IS READ FROM WHERE THE ENVIRONMENT NAMES IT.

    = = ⇒ `HERMES_KANBAN_DB` names it, = = = = and the default is the
    # = = = = board this repository's own work uses.
    """
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        worktree = tmp / "wt"
        worktree.mkdir()
        db = make_board(tmp, [("t_env", str(worktree), "dir")])
        helper = load_helper()
        import os

        old = os.environ.get("HERMES_KANBAN_DB")
        os.environ["HERMES_KANBAN_DB"] = db
        try:
            got = helper.card_workspace(helper.board_db(), "t_env")
        finally:
            if old is None:
                os.environ.pop("HERMES_KANBAN_DB", None)
            else:
                os.environ["HERMES_KANBAN_DB"] = old
        expect("the board is read from where the environment names it", got == str(worktree), f"got {got!r}")


def case_the_home_above_the_profile_holds_the_boards() -> None:
    """AND THE HOME ABOVE THE PROFILE IS TRIED, = = because the profile's
    own copy of the boards does not exist.

    = = ⇒ `HERMES_HOME` POINTS AT THE PROFILE'S DIRECTORY, = = = = and
    # = = = = `<profile>/kanban` is absent, = = so a resolver that reads the
    # = = = = profile's home and stops there finds NO board, = = prints
    # = = = = nothing, = = and the landing script falls back to the convention
    # = = = = and the defect survives unchanged.
    """
    import os

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        profile = tmp / "profiles" / "pocock"
        profile.mkdir(parents=True)
        boards = tmp / "kanban" / "boards" / "wenshu-par"
        boards.mkdir(parents=True)
        db = boards / "kanban.db"
        con = sqlite3.connect(db)
        con.execute("CREATE TABLE tasks (id TEXT PRIMARY KEY, workspace_path TEXT, workspace_kind TEXT)")
        con.commit()
        con.close()

        helper = load_helper()
        old_home = os.environ.get("HERMES_HOME")
        old_db = os.environ.get("HERMES_KANBAN_DB")
        os.environ["HERMES_HOME"] = str(profile)
        os.environ.pop("HERMES_KANBAN_DB", None)
        try:
            got = helper.board_db("wenshu-par")
        finally:
            if old_home is None:
                os.environ.pop("HERMES_HOME", None)
            else:
                os.environ["HERMES_HOME"] = old_home
            if old_db is not None:
                os.environ["HERMES_KANBAN_DB"] = old_db
        expect(
            "the home above the profile holds the boards",
            got == str(db),
            f"got {got!r}, wanted {str(db)!r}",
        )


def case_the_shells_own_resolution_picks_the_cards_worktree() -> None:
    """AND THE SHELL'S OWN BLOCK IS WHAT THE TEST RUNS.

    = = ⇒ A TEST THAT CALLS THE HELPER DIRECTLY DOES NOT HOLD THE SEAM THIS
    # = = = = EXISTS TO HOLD: = = removing the shell's call leaves the helper
    # = = = = tested and the script broken, = = and nothing goes red. = = ⇒ So
    # = = = = this runs the SHELL, = = = = and reads what the SHELL resolves.
    """
    import os
    import subprocess

    repo = HELPER.parent.parent
    script = repo / "Scripts" / "land_card.sh"
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        worktree = tmp / "wt"
        worktree.mkdir()
        db = make_board(tmp, [("t_shell", str(worktree), "dir")])

        old_db = os.environ.get("HERMES_KANBAN_DB")
        os.environ["HERMES_KANBAN_DB"] = db
        try:
            proc = subprocess.run(
                ["bash", str(script), "--resolve-only", "t_shell", "wt/t_shell"],
                capture_output=True, text=True, cwd=str(repo),
            )
        finally:
            if old_db is None:
                os.environ.pop("HERMES_KANBAN_DB", None)
            else:
                os.environ["HERMES_KANBAN_DB"] = old_db
        got = proc.stdout.strip()
        expect(
            "the shell's own resolution picks the card's worktree",
            got == str(worktree),
            f"got {got!r}, wanted {str(worktree)!r} (rc={proc.returncode})",
        )
        expect(
            "the shell's own resolution is not the convention",
            got != str(repo / ".worktrees" / "t_shell"),
            f"got {got!r}",
        )


def main() -> int:
    print("land_worktree: the card's own worktree is the authority\n")
    for case in (
        case_the_cards_own_worktree_is_the_answer,
        case_a_worktree_kind_is_named_too,
        case_a_path_that_is_not_there_is_not_a_path,
        case_a_kind_that_is_not_a_worktree_names_nothing,
        case_a_card_that_is_not_on_the_board_names_nothing,
        case_the_helper_reads_the_board_the_environment_names,
        case_the_home_above_the_profile_holds_the_boards,
        case_the_shells_own_resolution_picks_the_cards_worktree,
    ):
        print(f"--- {case.__name__}")
        case()
    print()
    if FAILURES:
        print(f"land_worktree: {len(FAILURES)} case(s) FAILED: {', '.join(FAILURES)}")
        return 1
    print("land_worktree: every case passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
