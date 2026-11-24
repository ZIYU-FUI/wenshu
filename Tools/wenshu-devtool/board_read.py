"""ONE reader for the board's card list, with a read-only fallback.

Why this file exists. `ticket_tier.py --check --live` and
`gate_width_gate.py --check` both enumerated the board by shelling out to
`hermes kanban list --json`. That command is a READ, but it runs through
the same CLI the kernel gates for WRITE access, so inside a delegated
child (= the review lane) it returns
`kanban: delegate_task child contexts cannot mutate Kanban tasks or boards`
and both checks answered "the board could not be read". A check the review
lane cannot run is a check the reviewer can only take on faith, and the
round that reviewed this wave hit exactly that (finding N6).

The fallback reads the board's own SQLite file with `mode=ro`, the same
file and the same open mode the ownership gate, the review gate and the
review-handoff gate already read. This module does NOT replace those
tools' own opens; it exists so the two board-wide sweeps share ONE read
path instead of each growing its own copy, which is the same rule a card's
gate section follows (`card_gate_command.py`, AGENTS.md 7.10).

Contract:

  cards(board) -> list[dict] | None

  A list is a board that WAS read. It may be empty (= a board with no
  cards is a read board, not a failure). None is a board this tool never
  read at all, for any reason: the CLI refused AND the file was missing,
  unopenable, or shaped wrong. Callers must treat None and [] as different
  facts — collapsing them is what let an unverified sweep print "agreed".

The CLI stays the primary path: it is the documented interface, it carries
fields the table does not, and a board read from the file must agree with
the board the flow itself shows. The file is the fallback, not the truth.
"""

from __future__ import annotations

import json
import sqlite3
import subprocess
import sys
from pathlib import Path

import sys as _sys

_sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)

REPO = Path(__file__).resolve().parents[2]

# The field names `hermes kanban list --json` prints for a card, measured
# 2026-11-24 against board `wenshu-par`. The file reader intersects this with
# the table's real columns so a card means the same thing whichever way it was
# read; a field this list does not name is a field no reader downstream can
# be depending on.
CLI_CARD_FIELDS = frozenset(
    {
        "assignee",
        "body",
        "branch_name",
        "completed_at",
        "completion_contract",
        "created_at",
        "created_by",
        "current_step_key",
        "id",
        "last_failure_error",
        "max_retries",
        "max_runtime_seconds",
        "model_override",
        "priority",
        "project_id",
        "provider_override",
        "result",
        "session_id",
        "skills",
        "started_at",
        "status",
        "tenant",
        "title",
        "workflow_template_id",
        "workspace_kind",
        "workspace_path",
    }
)


def _as_text(value: object) -> str:
    """The board stores a body as BLOB bytes; every reader wants a string.

    Decoded `utf-8` with replacement, because a body that fails to decode is
    still a body the gate must look at (= dropping it would read as "no gate
    section" and blame the author for the board's encoding).
    """
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8", "replace")
    return "" if value is None else str(value)


def _as_field(name: str, value: object) -> object:
    """One column, in the shape the CLI prints it.

    `body` is text, the epochs are ints, the absent ones stay None so a
    caller asking "does this card carry a runtime cap" gets the same answer
    from the file it gets from the CLI.
    """
    if name == "body":
        return _as_text(value)
    if name in {"created_at", "started_at", "completed_at", "max_runtime_seconds",
                "max_retries", "priority", "block_recurrences"}:
        return None if value is None else int(value)
    if isinstance(value, (bytes, bytearray)):
        return _as_text(value)
    return value




def cli_cards(board: str | None) -> list[dict] | None:
    """Every card from `hermes kanban list --json`, or None if unreadable.

    None covers every failure shape: the binary missing or refusing, a
    non-zero exit, a payload that is not JSON, and a payload that is not a
    card list. A card list wrapped in {"tasks": [...]} is unwrapped, because
    that is one of the shapes this CLI prints.
    """
    args = ["hermes", "kanban"]
    if board:
        args += ["--board", board]
    args += ["list", "--json"]
    try:
        out = subprocess.run(args, cwd=REPO, capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"the board CLI could not be run: {exc}", file=sys.stderr)
        return None
    if out.returncode != 0:
        detail = out.stderr.strip() or out.stdout.strip()
        print(f"the board CLI refused the read: {detail}", file=sys.stderr)
        return None
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        print("the board CLI printed no card list", file=sys.stderr)
        return None
    if isinstance(data, dict):
        data = data.get("tasks", [])
    if not isinstance(data, list):
        print("the board CLI printed no card list", file=sys.stderr)
        return None
    return list(data)


def db_path(board: str | None) -> Path | None:
    """The board's database file, or None when it cannot be found.

    The path comes from `product_lines.board_db`, the same lookup the
    ownership gate, the review gate and the review-handoff gate use, because
    a gate with its own copy of the board search is a gate that can read a
    DIFFERENT board than the gate beside it. `HERMES_HOME` points at the
    PROFILE's directory, not the home that holds the boards, and
    `product_lines` already carries that; a `--board` slug is passed through
    so a named board is found under whichever home holds it.

    None is returned only when no candidate is a real file, and `--board`
    with no value falls back to the board the flow calls current (= the
    default `product_lines.board_db` resolves), so `--check` with no
    `--board` still reads the board the author meant rather than nothing.
    """
    try:
        candidate = Path(product_lines.board_db(board or product_lines.DEFAULT_BOARD))
    except Exception:
        return None
    return candidate if candidate.is_file() else None


def file_cards(
    board: str | None, include_archived: bool = False
) -> list[dict] | None:
    """Every card read straight from the board file, read-only.

    This is the path a delegated lane CAN run: `sqlite3` with `mode=ro`
    opens the database without writing to it, so nothing here can mutate a
    task or a board. Returns None when the file is missing, cannot be
    opened, or has no `tasks` table carrying the four columns a card needs
    (= id, status, title, body). Cards with unreadable bodies are NOT
    dropped: an empty body is what the caller sees, and a caller that
    refuses to answer on an unreadable card is doing its job.

    **THE ROWS CARRY THE SAME FIELDS AS THE CLI.** The columns read are the
    intersection of the table's columns with the field names the CLI prints
    (= measured 2026-11-24: `assignee`, `body`, `created_at`, `id`, `status`,
    `title`, plus `max_runtime_seconds`, `result`, `model_override` and the
    rest), NOT a hand-picked few. The first cut here read five columns and
    the sweep then DISAGREED WITH ITSELF: `ticket_tier.py:1118` reads the
    card's `assignee` and `:1157` reads `max_runtime_seconds`, so both were
    derived as empty/default on the file path and two review cards came back
    T3 from the file and T2 from the CLI. A fallback that changes the answer
    is worse than no fallback, because it reads as a clean run.

    **THE POPULATION MATCHES THE CLI, NOT THE TABLE.** Measured the same day:
    `hermes kanban list --json` printed 982 cards (981 done, 1 ready) while
    the `tasks` table holds 1124 rows, and the 142 extra rows are exactly the
    `archived` ones. Archived rows are dropped here too unless a caller asks,
    because a fallback that swept a different population than the path it
    replaces would report 142 findings on cards nobody can act on.
    """
    path = db_path(board)
    if path is None:
        print("the board file could not be found", file=sys.stderr)
        return None
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=30)
    except sqlite3.Error as exc:
        print(f"the board file could not be opened: {exc}", file=sys.stderr)
        return None
    try:
        columns = [str(r[1]) for r in conn.execute("PRAGMA table_info(tasks)")]
        missing = {"id", "status", "title", "body"} - set(columns)
        if missing:
            print(
                f"the board file's tasks table lacks {sorted(missing)}",
                file=sys.stderr,
            )
            return None
        wanted = [c for c in columns if c in CLI_CARD_FIELDS]
        rows = conn.execute(f"SELECT {', '.join(wanted)} FROM tasks").fetchall()
    except sqlite3.Error as exc:
        print(f"the board file could not be read: {exc}", file=sys.stderr)
        return None
    finally:
        conn.close()
    cards = []
    for row in rows:
        card = {name: _as_field(name, value) for name, value in zip(wanted, row)}
        card["body"] = _as_text(card.get("body"))
        cards.append(card)
    if not include_archived:
        cards = [c for c in cards if c.get("status") != "archived"]
    # A PATH has to be a drop-in, so the file reader attaches its own runs
    # rather than relying on a caller to remember: a card list missing run
    # history is a card list `card_type()` mis-labels.
    attach_runs(cards, board)
    return cards


def one_card(board: str | None, card_id: str) -> dict | None:
    """One card by id from the board file, read-only, or None.

    The single-card path the gates use (`--card <id>`) shells out to
    `hermes kanban show` and scrapes a body out of its printed text. Inside
    a delegated lane that read is refused as well, and a scraped body plus a
    regex-poked epoch is a weaker read than the row itself. This is the
    fallback for that path: the same five columns, straight from the row.
    """
    if not board or not card_id:
        return None
    cards = file_cards(board, include_archived=True)
    if cards is None:
        return None
    for card in cards:
        if str(card.get("id")) == str(card_id):
            attach_runs([card], board)
            return card
    return None


def attach_runs(cards: list[dict], board: str | None) -> None:
    """Give each card its run history, from the board file, read-only.

    `hermes kanban list --json` carries no runs, and the tier derivation
    needs them: a card whose every run names the reviewer's profile has no
    implementation phase, and that is what separates a review card from a
    build card parked in the review lane. This is the same read
    `ticket_tier._attach_runs` does; it lives here so the fallback path and
    the CLI path produce cards of ONE shape.

    A missing file is not a failure: the cards stay without runs and the
    caller's own rule for "no run history" applies. Silently claiming runs
    that were never read is the error this avoids.
    """
    path = db_path(board)
    if path is None or not cards:
        return
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=30)
    except sqlite3.Error:
        return
    try:
        rows = conn.execute(
            "SELECT task_id, profile FROM task_runs "
            "WHERE profile IS NOT NULL AND profile != ''"
        ).fetchall()
    except sqlite3.Error:
        return
    finally:
        conn.close()
    runs: dict[str, list[dict]] = {}
    for task_id, profile in rows:
        runs.setdefault(str(task_id), []).append({"profile": str(profile)})
    for card in cards:
        card_id = str(card.get("id") or "")
        if not card.get("runs"):
            card["runs"] = runs.get(card_id, [])


def cards(board: str | None = None) -> list[dict] | None:
    """The board's cards: the CLI first, the read-only file as fallback.

    Both paths get their run history attached, so a card list means the same
    thing whichever way it arrived. None is returned only when BOTH reads
    failed (= the board was never read), and the caller says so out loud.
    """
    found = cli_cards(board)
    if found is None:
        found = file_cards(board)
        if found is not None:
            print(
                "read the board from its file in read-only mode "
                "(the CLI refused; this is the shape a delegated lane gets)",
                file=sys.stderr,
            )
    if found is None:
        return None
    attach_runs(found, board)
    return found
