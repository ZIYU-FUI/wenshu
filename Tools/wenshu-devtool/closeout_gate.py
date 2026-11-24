#!/usr/bin/env python3
"""THE closeout gate: the eight closeout steps, fired by the scope's STATE.

The closeout's trigger today is a KEYWORD in the shared skill tree, so the
eight steps run when a human says the words and not when the scope has landed.
A scope that landed while nobody said the word never gets its closure record,
its lessons, or its residue sweep.

This gate fires on the scope's state instead. It reads the scope's plan of
record (= `<repo>/.scratch/<scope>/issues/*.md` plus `issues/_index.md`),
decides for every ticket whether it landed (= the ticket's branch tip is an
ancestor of `main`), and:

  * when a ticket has NOT landed: it says so, names the tickets that have not,
    and exits 0 (= nothing is due yet);
  * when every ticket HAS landed: it audits the eight closeout steps, prints
    one line per step with the evidence it actually read, and exits 1 when a
    step's evidence is missing.

THE EIGHT STEPS KEEP THE ORDER AND THE NAMES of
`wenshu-pocock-workflow/references/standard-closeout.md`. That file is not
edited here (= four executors share its prose), so this gate is the repo-side
half and the keyword trigger stays until the tree's owner edits it.

THE EVIDENCE OF EACH STEP IS READ, NEVER INVENTED. A step whose evidence is
not found prints MISSING and names what it looked for.

THE BOARD IS READ READ-ONLY (= sqlite3 in `mode=ro`), and nothing is written
to it, to the repo, or to the shared skill tree.

Exit 0 = the scope has not landed (= nothing is due), or the scope has landed
and all eight steps carry their evidence.
Exit 1 = the scope has landed and at least one step's evidence is missing.
Exit 2 = the scope's plan of record could not be read.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory: where the boards live)

# The board this gate reads (= the desktop line's board; the mobile line's
# board is a different database and holds none of the desktop scope's cards).
BOARD_DB = product_lines.board_db()

# The shared skill tree, where a scope's durable lessons are persisted. The
# data-disk copy is the one the wave's own prose names, and the home copy is
# the same directory reached by another path; the first candidate that exists
# is the one read.
SKILLS_ROOT_CANDIDATES = (
    Path("/Volumes/ANAN/.hermes/shared/wenshu-skills"),
    Path.home() / ".hermes" / "shared" / "wenshu-skills",
)

# The eight steps, in the order and under the names of the authoritative
# text. The order IS the contract (= a closeout that skips one is a
# half-finished scope), so the list is the single source of both the reading
# order and the printed names.
STEPS = (
    (1, "Re-run the section 7 gates on the MERGED tree"),
    (2, "Record the verdict on the board"),
    (3, "Write the closure doc"),
    (4, "Persist the durable lessons into the SKILLS"),
    (5, "Clean up YOUR OWN residue"),
    (6, "Re-check the final state and report it"),
    (7, "Sweep the board's open columns"),
    (8, "THE CARD YOU DISPATCHED IS YOURS TO LAND"),
)

# The board's statuses that are NOT terminal. A card in one of these columns
# is still open, so the sweep has something to close.
NON_TERMINAL_STATUSES = (
    "todo", "ready", "running", "blocked", "review", "scheduled", "triage",
)

# A branch-shaped token: a path-like name with at least one separator. The
# repository's own branches all carry one (= `wt/`, `project/`, `feature/`,
# `review/`, `hermes-subagent/`), and `main` alone is never a ticket's own
# branch.
_TOKEN = r"[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._/-]*"

# A branch named in prose: the word "branch" and the name on the same line.
# The window is one line, so a name on the next line is not read as this
# line's branch.
BRANCH_LABEL_RE = re.compile(r"(?i)\bbranch(?:es)?\b[^\n]{0,80}?(" + _TOKEN + r")")

# A branch named as a whole cell of an index row (= a `Branch` column).
BRANCH_CELL_RE = re.compile(r"^(" + _TOKEN + r")$")

# A candidate that names a source file is a path, not a branch.
SOURCE_SUFFIXES = (
    ".swift", ".py", ".sh", ".md", ".json", ".txt", ".yml", ".yaml", ".plist",
    ".xcstrings", ".sql", ".cfg", ".toml",
)

# The house closeout-doc shape: `<date>-session-close[-out]-<slug>.md`.
CLOSEOUT_DOC_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})-session-close(?:out)?-(.+)\.md$")

# A hex token of 7+ characters, for the prefix semantics the closeout's own
# reference mandates (= a sha is named by any 7+ character prefix of it).
HEX_TOKEN_RE = re.compile(rb"\b[0-9a-f]{7,40}\b")


# ===========================================================================
# THE PLAN'S OWN SCOPE DECISION
# ===========================================================================
# A ticket id inside the spec's Out-of-scope section: `0\d\d`, the shape this repository's
# issue files use. A number in that section that is not an issue's id is read as a number, not
# as a scope decision, because the ids are the section's only reference to the index.
OUT_OF_SCOPE_HEADING = re.compile(r"^#+\s*\d*\.?\s*Out of scope", re.I | re.M)
TICKET_ID_IN_TEXT = re.compile(r"\b(0\d\d)\b")


def out_of_wave_ids(repo, scope):
    """The ticket ids the plan's spec DECLARES out of this wave, by section.

    `(ids, heading)`; `ids` is empty when there is no spec or no such section, and an empty
    set means NOTHING is exempt — a gate may not invent a scope boundary it cannot quote.
    The section is read to its next heading, because an id mentioned in a different section
    is not a scope decision.
    """
    for candidate in (
        Path(repo) / ".scratch" / scope / "spec.md",
        Path(repo) / ".scratch" / scope / "SPEC.md",
    ):
        if not candidate.is_file():
            continue
        text = candidate.read_text(encoding="utf-8", errors="replace")
        m = OUT_OF_SCOPE_HEADING.search(text)
        if not m:
            return set(), None
        rest = text[m.end():]
        nxt = re.search(r"^#{1,6}\s", rest, re.M)
        section = rest[: nxt.start()] if nxt else rest
        return set(TICKET_ID_IN_TEXT.findall(section)), text[m.start():].splitlines()[0].strip("# ").strip()
    return set(), None


# ===========================================================================
# GIT
# ===========================================================================
def git(repo, *args):
    """Run one git command in the repo and return the finished process."""
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True, text=True,
    )


def git_out(repo, *args):
    """The stdout of one git command, stripped."""
    return git(repo, *args).stdout.strip()


def rev_parse(repo, rev):
    """The sha a rev names, or None when it names nothing."""
    proc = git(repo, "rev-parse", "--verify", "--quiet", f"{rev}^{{commit}}")
    sha = proc.stdout.strip()
    return sha if proc.returncode == 0 and sha else None


def is_ancestor(repo, sha, target="main"):
    """Is the commit an ancestor of the target ref? (= ancestry, not tips)."""
    return git(repo, "merge-base", "--is-ancestor", sha, target).returncode == 0


def commit_epoch(repo, sha):
    """The committer date of a commit, in epoch seconds."""
    out = git_out(repo, "show", "-s", "--format=%ct", sha)
    try:
        return int(out)
    except ValueError:
        return 0


def branches(repo):
    """Every local branch name, as git spells it."""
    out = git_out(repo, "for-each-ref", "--format=%(refname:short)", "refs/heads")
    return [line.strip() for line in out.splitlines() if line.strip()]


def main_sha(repo):
    """The sha `main` points at, or None when there is no `main`."""
    return rev_parse(repo, "main")


# ===========================================================================
# THE PLAN OF RECORD
# ===========================================================================
def scope_slug(scope):
    """The scope's topic (= the scope name without its leading date)."""
    return re.sub(r"^\d{4}-\d{2}-\d{2}-", "", scope)


def scope_date(scope):
    """The scope's starting date, or "" when the name carries none."""
    m = re.match(r"^(\d{4}-\d{2}-\d{2})-", scope)
    return m.group(1) if m else ""


def normal(text):
    """A name reduced to its comparable shape (= `-`, `_` and case folded)."""
    return re.sub(r"[-_\s]+", "-", text.lower())


def parse_index(index_path):
    """The index's rows, as {slug: {column: cell}}.

    The index is the plan's own list of its tickets (docs/agents/
    issue-tracker.md), so the header row decides what each column means.
    """
    header: list[str] = []
    rows: dict[str, dict[str, str]] = {}
    if not index_path.is_file():
        return header, rows
    for line in index_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if all(set(c) <= set("-: ") for c in cells):
            continue  # the separator row
        if not header:
            header = cells
            continue
        row = {header[i]: cells[i] for i in range(min(len(header), len(cells)))}
        rows[cells[0]] = row
    return header, rows


def branch_shaped(candidate):
    """Is this token a branch name and not a path to a file?"""
    if not candidate or "/" not in candidate:
        return False
    if candidate.endswith(SOURCE_SUFFIXES):
        return False
    return True


def index_branch(row):
    """The branch an index row names, or None.

    A cell is read as a branch only when it is branch-shaped (= it carries a
    separator, the way every branch in this repository does) and it is not a
    path to a file that exists.
    """
    for cell in row.values():
        m = BRANCH_CELL_RE.match(cell.strip())
        if m and branch_shaped(m.group(1)):
            return m.group(1)
    return None


def named_branch(text, repo):
    """The branch a ticket body names, or None.

    A candidate is read only when it is not a path to a file that exists:
    the word "branch" is often followed by a path in the same sentence, and a
    path is not a branch.
    """
    for m in BRANCH_LABEL_RE.finditer(text or ""):
        candidate = m.group(1).rstrip(".,;:")
        if not branch_shaped(candidate):
            continue
        if (Path(repo) / candidate).exists():
            continue
        return candidate
    return None


def read_tickets(repo, scope):
    """The scope's tickets, with their state and their branch.

    THE TICKET SET IS THE INDEX'S ROWS. The convention (docs/agents/
    issue-tracker.md) says the index lists every issue in the feature, so the
    index is the plan's own list of its tickets and the issue files are their
    bodies. An issue file the index does not name is a leftover from another
    round of the plan: it is REPORTED BY NAME and it is not a ticket of this
    plan, because a leftover file would otherwise hold the scope open for
    ever (= a draft nobody will land sits in the ticket directory).

    With no index at all, the issue files are the ticket set.
    """
    issues = Path(repo) / ".scratch" / scope / "issues"
    index_path = issues / "_index.md"
    header, rows = parse_index(index_path)
    files = {p.stem: p for p in sorted(issues.glob("*.md")) if p.name != "_index.md"}
    slugs = list(rows) if rows else sorted(files)
    tickets = []
    for slug in slugs:
        path = files.get(slug)
        body = path.read_text(encoding="utf-8") if path else ""
        row = rows.get(slug, {})
        branch = named_branch(body, repo)
        source = "body" if branch else None
        if not branch:
            branch = index_branch(row)
            source = "index row" if branch else None
        tickets.append({
            "id": slug,
            "file": str(path) if path else "",
            "state": row.get("State", ""),
            "branch": branch,
            "branch_source": source,
            "in_index": slug in rows,
        })
    unlisted = sorted(set(files) - set(rows)) if rows else []
    declared, section = out_of_wave_ids(repo, scope)
    for ticket in tickets:
        landed, why, tip = ticket_landed(repo, ticket)
        ticket["landed"] = landed
        ticket["why"] = why
        ticket["tip"] = tip
        # = = ⇒ A ROW THE SPEC DECLARES OUT OF THIS WAVE IS NOT A BLOCKER, and
        # = = = = it is not invisible either: it is printed with the section that
        # = = = = said so. = = ⇒ A scope with no spec, or with a spec that never
        # = = = = declared a boundary, holds every row blocking: = = = = a gate may
        # = = = = not invent an exemption it cannot quote.
        number = ticket["id"].split("-")[0]
        ticket["out_of_wave"] = bool(declared) and number in declared
    return {
        "scope_section": section,
        "declared_out_of_wave": sorted(declared),
        "dir": str(issues),
        "index": str(index_path),
        "index_rows": len(rows),
        "index_header": header,
        "issue_files": len(files),
        "unlisted_issue_files": unlisted,
        "tickets": tickets,
    }


def ticket_landed(repo, ticket):
    """Has this ticket landed? Returns (landed, why, tip sha)."""
    branch = ticket["branch"]
    if not branch:
        return False, "no branch named in its body or its index row", None
    tip = rev_parse(repo, branch)
    if not tip:
        return False, f"the branch it names ({branch}) is not in the repository", None
    if not main_sha(repo):
        return False, "the repository has no main to be an ancestor of", None
    if is_ancestor(repo, tip, "main"):
        return True, "its branch tip is an ancestor of main", tip
    return False, f"its branch tip ({tip[:10]}) is not an ancestor of main", tip


def last_landed(repo, tickets):
    """The scope's last landed ticket (= the newest landed branch tip).

    "Newest" is measured by ANCESTRY FIRST and by the commit date second:
    a ticket whose tip is an ancestor of another landed ticket's tip landed
    earlier, whatever the clock says (= two tickets committed in the same
    second are ordered by the tree, not by the sha they happen to have).
    """
    landed = []
    for ticket in tickets:
        ok, _why, tip = ticket_landed(repo, ticket)
        if ok and tip:
            landed.append({"epoch": commit_epoch(repo, tip), "tip": tip, "ticket": ticket})
    if not landed:
        return None
    newest = [
        row for row in landed
        if not any(is_ancestor(repo, row["tip"], other["tip"])
                   for other in landed if other["tip"] != row["tip"])
    ]
    if not newest:
        newest = landed
    newest.sort(key=lambda row: (row["epoch"], row["tip"]))
    row = newest[-1]
    return {
        "id": row["ticket"]["id"],
        "branch": row["ticket"]["branch"],
        "tip": row["tip"],
        "epoch": row["epoch"],
    }


# ===========================================================================
# THE EIGHT STEPS, ONE READING EACH
# ===========================================================================
def step_gates_on_merged_tree(repo, scope, last):
    """Step 1: a gate log under `.gate-logs/` that names the merged sha.

    The reading is the closeout reference's own: the gate log must NAME the
    landed sha, because a log that names only the branch tip is the BRANCH's
    gate run and cannot answer for the merged tree.

    The merged sha is the commit the scope's landing put on `main`, so the
    scope's last landed commit is the first candidate and `main`'s own tip is
    the second (= the merged tree as it stands now). The line says which one
    the log named.
    """
    logs = Path(repo) / ".gate-logs"
    if not logs.is_dir():
        return False, f"no .gate-logs directory at {logs} (the merged-tree gate run leaves none)"
    candidates = [last["tip"]]
    head = main_sha(repo)
    if head and head != last["tip"]:
        candidates.append(head)
    for sha in candidates:
        exact = sha.encode("ascii")
        for path in sorted(logs.rglob("*.log")):
            try:
                blob = path.read_bytes()
            except OSError:
                continue
            if exact in blob:
                return True, f"{path} names {sha}"
            for token in HEX_TOKEN_RE.findall(blob):
                if sha.startswith(token.decode("ascii")):
                    return True, f"{path} names {token.decode('ascii')} (a prefix of {sha})"
    return False, (f"no log under {logs} names the merged sha {last['tip']} "
                   f"(the merged tree's gate run leaves none)")


def open_board(path):
    """Open the board READ-ONLY, or return None when it cannot be read."""
    db = Path(path)
    if not db.is_file():
        return None
    try:
        conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error:
        return None


def scope_cards(conn, scope):
    """The board's tasks whose title or body names the scope."""
    like = f"%{scope}%"
    slug_like = f"%{scope_slug(scope)}%"
    rows = conn.execute(
        "SELECT id, title, body, status FROM tasks "
        "WHERE (title LIKE ? OR body LIKE ?) "
        "   OR (title LIKE ? OR body LIKE ?)",
        (like, like, slug_like, slug_like),
    ).fetchall()
    return rows


def verdict_of(metadata):
    """The review_outcome a run's metadata carries, or "".

    The column is JSON-ish text, so it is parsed as JSON and, when that
    fails, read for the field directly (= the field is what the gate reads,
    and a truncated or hand-edited column still carries it).
    """
    if not metadata:
        return ""
    try:
        data = json.loads(metadata)
        if isinstance(data, dict):
            value = data.get("review_outcome")
            if isinstance(value, str):
                return value
    except (ValueError, TypeError):
        pass
    m = re.search(r'"review_outcome"\s*:\s*"([^"]*)"', metadata)
    return m.group(1) if m else ""


def step_verdict_on_board(scope, board_db):
    """Step 2: a task naming the scope whose run carries an approved verdict."""
    conn = open_board(board_db)
    if conn is None:
        return False, f"no board database at {board_db}"
    try:
        cards = scope_cards(conn, scope)
        if not cards:
            return False, (f"no task on the board names the scope {scope} "
                           f"(read {board_db})")
        for card in cards:
            runs = conn.execute(
                "SELECT id, status, metadata FROM task_runs WHERE task_id = ? "
                "ORDER BY id DESC",
                (card["id"],),
            ).fetchall()
            for run in runs:
                if verdict_of(run["metadata"]) == "approved":
                    return True, (f"task {card['id']} (status {card['status']}) "
                                  f"run {run['id']} carries review_outcome=approved")
        return False, (f"{len(cards)} task(s) name the scope {scope} and none "
                       f"carries review_outcome=approved (read {board_db})")
    finally:
        conn.close()


def doc_slug(name: str) -> str:
    """The topic a docs/agents file's name carries (= its name minus the date).

    The house names a closure doc `<date>-<slug>.md` (= the slug is the
    scope's topic), with `session-close` / `session-closeout` in the house's
    own shapes. The date is dropped, because the date names no scope.
    """
    stem = name[:-3] if name.endswith(".md") else name
    return normal(re.sub(r"^\d{4}-\d{2}-\d{2}-", "", stem))


def mentions_topic(haystack: str, topic: str) -> bool:
    """Does the haystack name the topic?

    The topic is matched as a whole name on the hyphen-normalized strings
    (= `flow-gates` matches `flow-gates-2026-11-24` and `wt/flow-gates`,
    because the house's branch and worktree names carry the topic and then
    a suffix).
    """
    if not topic:
        return False
    return topic in haystack


def closure_doc(repo, scope):
    """The scope's closure doc, or None.

    A closure doc names the scope it closes, and the house names it by the
    scope's topic (= `<date>-<topic>.md`, with `session-close` /
    `session-closeout` in the house's own shapes). So the doc's slug is read
    for the scope's topic.

    A doc that matches only on its date names no scope (= every scope closes
    on some date, and docs/agents holds one closure doc per scope), so such a
    doc must also mention the scope in its text, or it closes a different
    scope.
    """
    docs = Path(repo) / "docs" / "agents"
    if not docs.is_dir():
        return None
    slug = normal(scope_slug(scope))
    scope_id = scope.lower()
    if not slug:
        return None
    for path in sorted(docs.glob("*.md")):
        if scope_id in path.name.lower() or mentions_topic(doc_slug(path.name), slug):
            return path
    start = scope_date(scope)
    for path in sorted(docs.glob("*.md")):
        m = CLOSEOUT_DOC_RE.match(path.name)
        if not m:
            continue
        if start and m.group(1) < start:
            continue
        try:
            body = path.read_text(encoding="utf-8").lower()
        except OSError:
            continue
        if mentions_topic(normal(body), slug):
            return path
    return None


def step_closure_doc(repo, scope):
    """Step 3: a closure doc under `docs/agents/` that names the scope."""
    path = closure_doc(repo, scope)
    if path is None:
        return False, (f"no file under {Path(repo) / 'docs' / 'agents'} names the "
                       f"scope {scope} or its closeout date")
    return True, str(path)


def skills_root():
    """The shared skill tree this gate reads."""
    for candidate in SKILLS_ROOT_CANDIDATES:
        if candidate.is_dir():
            return candidate
    return SKILLS_ROOT_CANDIDATES[0]


def skill_files(root):
    """Every file under the shared skill tree, EXCLUDING its `.git/`.

    The shared tree is itself a git repository (= 313 files under its
    `.git/`), and a `.git/` internal (= a reflog, an index, an object) is
    not a skill file and not a lesson. Reading the tree's own bookkeeping
    as "a durable lesson was persisted" is a false green.
    """
    if not root.is_dir():
        return []
    out = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        if ".git" in path.relative_to(root).parts:
            continue
        out.append(path)
    return out


def step_lessons_in_skills(scope, root, last):
    """Step 4: a durable lesson persisted into the shared skill tree.

    The mtime reading is the one the gate prefers (= a lesson written after
    the scope's last landing is a lesson about the scope), and the topic
    reading is the fallback (= a skill file that names the scope's topic
    carries its lesson whether or not it was written last night). The line
    says which reading answered.
    """
    files = skill_files(root)
    if not files:
        return False, f"no shared skill tree at {root}"
    newest = None
    for path in files:
        try:
            mtime = path.stat().st_mtime
        except OSError:
            continue
        if mtime > last["epoch"]:
            if newest is None or mtime > newest[1]:
                newest = (path, mtime)
    if newest is not None:
        return True, (f"{newest[0]} (mtime {int(newest[1])}) is newer than the "
                      f"scope's last landed commit ({last['tip'][:10]}), read by mtime")
    slug = normal(scope_slug(scope))
    for path in files:
        if path.suffix not in (".md", ".txt"):
            continue
        try:
            body = path.read_text(encoding="utf-8").lower()
        except (OSError, UnicodeDecodeError):
            continue
        if mentions_topic(normal(body), slug):
            return True, f"{path} mentions the scope's topic ({scope_slug(scope)}), read by topic"
    return False, (f"no file under {root} is newer than the scope's last landed "
                   f"commit ({last['tip'][:10]}) and none mentions its topic "
                   f"({scope_slug(scope)})")


def step_residue_cleaned(repo, scope):
    """Step 5: no worktree and no branch of this scope is left behind."""
    slug = normal(scope_slug(scope))
    worktrees = Path(repo) / ".worktrees"
    left = []
    if worktrees.is_dir():
        for path in sorted(worktrees.iterdir()):
            if path.is_dir() and mentions_topic(normal(path.name), slug):
                left.append(f"worktree {path}")
    for branch in branches(repo):
        if mentions_topic(normal(branch), slug):
            left.append(f"branch {branch}")
    if left:
        return False, "; ".join(left) + " (the scope's own residue)"
    return True, (f"no worktree under {worktrees} and no branch under refs/heads "
                  f"names {scope_slug(scope)}")


def step_final_state(repo, last):
    """Step 6: the scope's last landed commit is on main, and main is at it.

    Two readings, both printed: the scope's last landed commit is an
    ANCESTOR of main (= the durable fact, and the one that survives a
    sibling landing something else), and main POINTS AT that sha (= the
    merged tree is still the scope's tip, so nothing landed on top of it).
    """
    tip = last["tip"]
    head = main_sha(repo)
    if not head:
        return False, "the repository has no main to compare against"
    if not is_ancestor(repo, tip, "main"):
        return False, (f"the scope's last landed commit {tip[:10]} is not an "
                       f"ancestor of main ({head[:10]})")
    if tip != head:
        return False, (f"scope commit {tip[:10]} | main {head[:10]} (= the scope's "
                       f"last landed commit is an ancestor of main, but main is not "
                       f"at it: something landed on top of the scope)")
    return True, f"scope commit {tip[:10]} | main {head[:10]}"


def step_open_columns(scope, board_db):
    """Step 7: no card of this scope is left in an open column."""
    conn = open_board(board_db)
    if conn is None:
        return False, f"no board database at {board_db}"
    try:
        cards = scope_cards(conn, scope)
        open_rows = [c for c in cards if (c["status"] or "").lower() in NON_TERMINAL_STATUSES]
        if open_rows:
            names = ", ".join(f"{c['id']} ({c['status']})" for c in open_rows)
            return False, f"{len(open_rows)} card(s) of the scope are open: {names}"
        if not cards:
            return False, f"no task on the board names the scope {scope} (read {board_db})"
        return True, f"{len(cards)} card(s) name the scope and all are terminal"
    finally:
        conn.close()


def step_card_landed(repo, last):
    """Step 8: the scope's last landed branch tip is on main."""
    tip = last["tip"]
    head = main_sha(repo)
    if not head:
        return False, "the repository has no main to compare against"
    if not is_ancestor(repo, tip, "main"):
        return False, (f"the scope's last landed branch tip {tip[:10]} is not an "
                       f"ancestor of main ({head[:10]})")
    return True, f"branch {last['branch']} tip {tip[:10]} | main {head[:10]}"


# ===========================================================================
# THE AUDIT
# ===========================================================================
def audit(scope, repo, board_db=None, skills=None):
    """The scope's state and the eight steps' evidence."""
    repo = str(repo)
    board_db = str(board_db or BOARD_DB)
    root = Path(skills) if skills else skills_root()
    plan = read_tickets(repo, scope)
    if not plan["tickets"]:
        return None
    not_landed = [t for t in plan["tickets"] if not t["landed"] and not t.get("out_of_wave")]
    parked = [t for t in plan["tickets"] if not t["landed"] and t.get("out_of_wave")]
    last = last_landed(repo, plan["tickets"])
    report = {
        "scope": scope,
        "repo": repo,
        "board_db": board_db,
        "skills_root": str(root),
        "plan": plan,
        "tickets": plan["tickets"],
        "landed": not not_landed,
        "not_landed": [t["id"] for t in not_landed],
        "out_of_wave_not_landed": [t["id"] for t in parked],
        "last_landed": last,
        "steps": [],
        "missing_steps": [],
    }
    if not report["landed"] or last is None:
        return report
    readings = {
        1: lambda: step_gates_on_merged_tree(repo, scope, last),
        2: lambda: step_verdict_on_board(scope, board_db),
        3: lambda: step_closure_doc(repo, scope),
        4: lambda: step_lessons_in_skills(scope, root, last),
        5: lambda: step_residue_cleaned(repo, scope),
        6: lambda: step_final_state(repo, last),
        7: lambda: step_open_columns(scope, board_db),
        8: lambda: step_card_landed(repo, last),
    }
    for number, name in STEPS:
        ok, evidence = readings[number]()
        report["steps"].append({
            "n": number,
            "name": name,
            "verdict": "PASS" if ok else "MISSING",
            "evidence": evidence,
        })
        if not ok:
            report["missing_steps"].append(number)
    return report


def print_report(report) -> None:
    """The report, as the gate prints it."""
    print(f"closeout gate: scope {report['scope']}")
    print(f"  repo: {report['repo']}")
    print(f"  plan: {report['plan']['dir']} ({report['plan']['index_rows']} index "
          f"row(s), {report['plan']['issue_files']} issue file(s))")
    for ticket in report["tickets"]:
        branch = ticket["branch"] or "(no branch named)"
        state = ticket["state"] or "no state"
        print(f"    {ticket['id']} | branch {branch} | {state} | "
              f"{'LANDED' if ticket['landed'] else 'NOT LANDED'}")
    if report["plan"]["unlisted_issue_files"]:
        print("  issue files the index does not name (= not tickets of this plan): "
              + ", ".join(report["plan"]["unlisted_issue_files"]))
    if not report["landed"]:
        print(f"  scope {report['scope']} has NOT landed: nothing is due yet")
        for ticket in report["tickets"]:
            if not ticket["landed"] and not ticket.get("out_of_wave"):
                print(f"    not landed: {ticket['id']} ({ticket['why']})")
        for ticket in report["tickets"]:
            if not ticket["landed"] and ticket.get("out_of_wave"):
                print(f"    out of wave, declared: {ticket['id']} "
                      f"(spec \u00a7: {report['plan']['scope_section']}) "
                      f"\u2014 not blocking, and still not landed: {ticket['why']}")
        return
    parked = report.get("out_of_wave_not_landed") or []
    print(f"  scope {report['scope']} HAS landed ({len(report['tickets'])} "
          f"ticket(s)); the eight closeout steps:")
    if parked:
        print(f"  declared out of this wave and still open ({len(parked)}): "
              + ", ".join(parked)
              + f"  (spec \u00a7: {report['plan']['scope_section']})")
    for step in report["steps"]:
        print(f"    {step['n']} | {step['name']} | {step['verdict']} | {step['evidence']}")
    if report["missing_steps"]:
        names = ", ".join(f"{n} {dict(STEPS)[n]}" for n in report["missing_steps"])
        print(f"  closeout: {len(report['missing_steps'])} step(s) missing: {names}")
    else:
        print("  closeout: all eight steps carry their evidence")


def default_repo() -> Path:
    """The checkout the plan of record is read from.

    The plan lives in the SHARED checkout (= `.scratch/` is untracked, so a
    linked worktree carries none of it), and the shared checkout is the one
    the linked worktree's own git directory names.
    """
    here = Path(__file__).resolve()
    root = here.parents[2]
    if (root / ".scratch").is_dir():
        return root
    common = git_out(root, "rev-parse", "--git-common-dir")
    if common:
        path = Path(common)
        if not path.is_absolute():
            path = (root / path).resolve()
        shared = path.parent
        if (shared / ".scratch").is_dir():
            return shared
    return root


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="the closeout gate (the eight steps, on the scope's state)")
    parser.add_argument("--scope", required=True, help="the scope (= the .scratch folder's name)")
    parser.add_argument("--repo", default=None, help="repository root (= the checkout that holds .scratch/)")
    parser.add_argument("--board", default=None, help="the board database to read")
    parser.add_argument("--skills", default=None, help="the shared skill tree to read")
    parser.add_argument("--json", action="store_true", help="print the report as JSON")
    args = parser.parse_args(argv)

    repo = args.repo or str(default_repo())
    report = audit(args.scope, repo, board_db=args.board, skills=args.skills)
    if report is None:
        print(f"closeout gate: no plan of record for the scope {args.scope} under "
              f"{Path(repo) / '.scratch' / args.scope}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(report, indent=1, default=str))
    else:
        print_report(report)
    if not report["landed"]:
        return 0
    return 1 if report["missing_steps"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
