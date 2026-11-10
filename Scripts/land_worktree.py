#!/usr/bin/env python3
"""land_worktree.py <card_id> = = the worktree the card names.

= = ⇒ WHY THIS IS A PROGRAM AND NOT A LINE IN THE LANDING SCRIPT. = = The
# = = = = landing script has to find the worktree a card was reviewed in,
# = = = = and the convention that a worktree lives at `.worktrees/<card
# = = = = id>` is only a convention: = = = = a card whose workspace points
# = = = = at an existing worktree (= = = = the review lane's own, = = = =
# = = = = which is where the reviewer read the tree from) has its worktree
# = = = = elsewhere. = = ⇒ So the CARD'S OWN `workspace_path` is the
# = = = = authority, = = = = and the convention is the fallback.

= = ⇒ AND THE CARD'S OWN PATH IS WHAT THIS PRINTS. = = = = The board
# = = = = keeps it in `tasks.workspace_path`, = = = = beside the
# = = = = `workspace_kind` that says whether it names a directory (= = = =
# = = = = `dir`) or a git worktree (= = = = `worktree`); = = = = a path of
# = = = = either kind names a real directory, = = = = and a blank one does
# = = = = not.

= = ⇒ AND THE BOARD IS READ FROM WHERE THE BOARD LIVES. = = = =
`HERMES_KANBAN_DB` names it, = = = = and the default is the board this
# = = = = repository's own work uses.

= = ⇒ AND A PATH THAT DOES NOT EXIST IS NOT PRINTED. = = = = Printing a
# = = = = path that is not there would send the landing script back into
# = = = = the failure this exists to fix (= = = = rebase a directory that
# = = = = = does not exist, = = = = report a conflict, = = = = land
# = = = = = nothing).
"""

import os
import sqlite3
import sys
from pathlib import Path

DEFAULT_BOARD = "wenshu-par"


def board_db(board: str = DEFAULT_BOARD) -> str:
    """The board's database file."""
    pinned = os.environ.get("HERMES_KANBAN_DB")
    if pinned:
        return pinned
    home = os.environ.get("HERMES_HOME") or os.path.expanduser("~/.hermes")
    return str(Path(home) / "kanban" / "boards" / board / "kanban.db")


def card_workspace(db_path: str, card_id: str) -> str:
    """The worktree the card names, or "" when it names none.

    = = ⇒ AND A CARD THAT NAMES NO WORKTREE NAMES NONE. = = = = The empty
    # = = = = string is the answer, = = = = and the caller decides what to
    # = = = = do with it (= = = = the landing script falls back to the
    # = = = = convention).
    """
    try:
        con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    except sqlite3.Error:
        return ""
    try:
        row = con.execute(
            "SELECT workspace_path, workspace_kind FROM tasks WHERE id = ?",
            (card_id,),
        ).fetchone()
    except sqlite3.Error:
        return ""
    finally:
        con.close()
    if not row:
        return ""
    path, kind = row
    if not path or kind not in ("dir", "worktree"):
        return ""
    if not Path(path).is_dir():
        return ""
    return path


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: land_worktree.py <card_id>", file=sys.stderr)
        return 2
    board = os.environ.get("HERMES_KANBAN_BOARD", DEFAULT_BOARD)
    path = card_workspace(board_db(board), argv[1])
    if path:
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
