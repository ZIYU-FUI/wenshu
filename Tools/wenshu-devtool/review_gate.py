#!/usr/bin/env python3
"""
review_gate.py - the independent-review gate: who owes a verdict, and who gave it.

Two questions, one gate:

  CONTRACT  does this card owe an independent review verdict, and does the body
            name a reviewer profile that is NOT the implementer?
  RECORD    does the board already hold an approving verdict for this card, and
            which profile gave it?

The contract is DERIVED from the work the body describes, never hand-set, and it
is independent of the difficulty tier: AGENTS.md 1.13 makes the tier the cost
of a card and never the quality bar, so the tier cannot decide who reviews a
card.

WHY THE GATE EXISTS (measured on board wenshu-par, 2026-10-26):

  - 113 of 114 done cards carried ZERO review events. The reviewer profile was
    named in the docs and never ran.
  - The one review that did run was the implementer reviewing ITSELF, and it
    found a card reported done with no commit on its branch and both of its
    acceptance criteria unmet. A self-review is not a verdict.
  - The cause was concrete: no card body named a reviewer, so
    ``kanban_request_review`` fell back to the assignee, and the assignee was
    the implementer.
  - 5 done cards promised files in their body that their branch does not
    contain (= a false done), and all 5 write code. 0 prose-only card was
    false done. So a card that writes CODE owes a verdict, and a card that
    writes prose does not.

A card writes CODE when its body writes a file outside the documentation set
(docs/ and the root markdown files). Prose is already read against the spec by
the dual-axis audit (AGENTS.md 7.4); code is not.

THE GATE STARTS ON A DATE, NOT ON A FLAG. A card created before
REVIEW_CONTRACT_FROM is a pre-contract card: it is reported, never blocked,
because the cards already on the board were dispatched under the old contract
and rewriting them is not this tool's business. A card created on or after
that epoch owes a verdict when it writes code, and a body that writes code
without naming a reviewer is a contract error.

Usage:
    review_gate.py --body FILE      the contract of one draft body
    review_gate.py --card ID        the record of one card on the board
    review_gate.py --check          every card on the board
    review_gate.py --json           machine-readable output

Exit code 0 = the gate is satisfied, 1 = a contract error, 2 = the board could
not be read, 3 = a card owes a verdict it does not have.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)
import ticket_tier  # noqa: E402  (sibling module, same directory)
from ticket_tier import normalized, sections  # noqa: E402  (sibling module, same directory)

# The board this tool reads when the caller names none. Declared in one
# place (= product_lines), so a tool that sweeps boards reads the same
# board list the rest of the devtool does.
BOARD = product_lines.DEFAULT_BOARD

# The epoch the review contract starts at (= when this gate landed on main).
# A card created before it was dispatched under the old contract, so it is
# reported and never blocked.
REVIEW_CONTRACT_FROM = 1792953600  # 2026-10-26 02:40 CST

# The CONTRACT half of the gate (what the card owes) is a contract on the
# card body, so it lives with the body parser in ticket_tier.py. The RECORD
# half (who actually gave the verdict) needs the board, so it lives here.
code_paths = ticket_tier.code_paths
review_required = ticket_tier.review_required
review_required_for_kind = ticket_tier.review_required_for_kind
card_type = ticket_tier.card_type
handoff_text = ticket_tier.handoff_text
named_reviewer = ticket_tier.named_reviewer


def is_subject(created_at: int | None) -> bool:
    """Whether a card was created under the review contract."""
    if created_at is None:
        return True  # a draft body is a card that does not exist yet
    return created_at >= REVIEW_CONTRACT_FROM


def is_review_card(doc: dict) -> bool:
    """Whether this card has NO implementation phase (= it IS a review).

    A card that reviews a commit somebody else already wrote has no
    implementation phase: every run on it carries the SAME profile, because
    the only profile that ever touched it is the reviewer. Measured
    2026-10-29 on board wenshu-mob-par: card t_809184d0 carried exactly ONE
    run, by wenshu-review, and named wenshu-review as its reviewer. The
    contract check called that a self-review, which is a false positive that
    blocks the merge of code the reviewer already approved.

    The shape alone is wide (= 155 of the 206 cards on wenshu-par are
    single-profile), so it is only ever used together with the card's
    declared kind: the kind says the card is a review, and the shape says it
    has no implementation phase to be reviewed against.
    """
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    runs = [r for r in runs if r.get("profile")]
    if not runs:
        # A card with NO run has no implementation phase: it cannot have
        # run one. Under the one-developer flow a review card is created
        # FOR the reviewer and has no run until the reviewer picks it up,
        # so "every run carries the same profile" is vacuously true here.
        #
        # Measured 2026-10-31: a freshly created review card read as a
        # contract error (= "the REVIEW HANDOFF section names no reviewer
        # profile") because of this, and the error was a false positive:
        # the card WAS the review, exactly like the ones that had already
        # run and passed. The shape is only ever used together with the
        # card's DECLARED kind (= the kind says the card is a review, and
        # the shape says it has no implementation phase), so a build card
        # with no run is still judged as a build card.
        return True
    return len({str(r.get("profile")) for r in runs}) == 1


def card_kind(doc: dict) -> str:
    """The kind of work this card is, derived from its body and its runs."""
    task = doc.get("task") or {}
    body = task.get("body") or ""
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    return ticket_tier.card_type(body, runs, str(task.get("title") or ""))


def contract_errors(
    body: str,
    assignee: str | None = None,
    created_at: int | None = None,
    kind: str | None = None,
    is_review: bool = False,
) -> list[str]:
    """Every way the body breaks the review contract."""
    errors = ticket_tier.review_contract_errors(
        body, assignee, kind=kind, is_review_card=is_review
    )
    if created_at is not None and not is_subject(created_at):
        # A card dispatched under the old contract is reported, never blocked.
        return []
    return errors


def _hermes() -> str | None:
    """The hermes executable, resolved so a missing PATH is not a silent pass."""
    found = shutil.which("hermes")
    if found:
        return found
    for candidate in (
        os.environ.get("HERMES_BIN"),
        str(Path.home() / ".local" / "bin" / "hermes"),
    ):
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            return candidate
    return None


def _run_hermes(args: list[str]) -> tuple[int, str]:
    """Run the hermes CLI, returning (returncode, stdout)."""
    binary = _hermes()
    if binary is None:
        return 127, ""
    proc = subprocess.run([binary, *args], capture_output=True, text=True)
    return proc.returncode, proc.stdout


def _run_hermes_all(args: list[str]) -> tuple[int, str, str]:
    """Run the hermes CLI, returning (returncode, stdout, stderr).

    The CLI writes its failure messages to STDERR ("no such task: t_x"),
    so a caller that has to tell one failure from another needs both
    streams.
    """
    binary = _hermes()
    if binary is None:
        return 127, "", ""
    proc = subprocess.run([binary, *args], capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr


def board_doc(card_id: str, board: str = BOARD) -> dict | None:
    """The board record of one card, or None when the board cannot be read."""
    code, out = _run_hermes(
        ["kanban", "--board", board, "show", card_id, "--json"]
    )
    if code != 0:
        return None
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def card_absent(card_id: str, board: str = BOARD) -> bool:
    """Whether the card is simply NOT on the board.

    A card that does not exist and a board that cannot be read both make
    the CLI fail, so ``board_doc`` returns None for either. They are
    different facts: the first means "this card owes nothing", the
    second means "nobody can tell". The gate reports the first as
    ``card_absent`` and the second as ``board_unreadable``, so a missing
    card is never read as a broken board.

    The CLI writes the message to stderr, so both streams are read.
    """
    code, out, err = _run_hermes_all(
        ["kanban", "--board", board, "show", card_id, "--json"]
    )
    if code == 0:
        return False
    return "no such task" in ((out or "") + (err or "")).lower()


def board_cards(board: str = BOARD) -> list[dict] | None:
    """Every card on the board, or None when the board cannot be read."""
    code, out = _run_hermes(["kanban", "--board", board, "list", "--json"])
    if code != 0:
        return None
    try:
        data = json.loads(out)
    except json.JSONDecodeError:
        return None
    if isinstance(data, dict):
        data = data.get("tasks", [])
    return list(data) if isinstance(data, list) else None



def review_cards_for(board: str = BOARD) -> list[dict] | None:
    """Every card on the board, with its runs, read cheaply (= one query).

    A card body is not always TEXT: the board stores some of them as a
    BLOB, and a NULL for the cards created without one. Both are decoded
    here, so the caller never has to know the storage type.

    None means the board could not be read, and an empty list means the
    board is readable and holds no cards. The two are different facts: an
    empty board is a board where nobody has a card, and an unreadable
    one is a board nobody can ask.
    """
    path = _board_db_path(board)
    if path is None:
        return None
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error:
        return None
    try:
        conn.row_factory = sqlite3.Row
        cards = [dict(r) for r in conn.execute("SELECT * FROM tasks")]
        runs: dict[str, list[dict]] = {}
        for r in conn.execute("SELECT * FROM task_runs ORDER BY started_at ASC"):
            runs.setdefault(r["task_id"], []).append(dict(r))
    except sqlite3.Error:
        return None
    finally:
        conn.close()
    for c in cards:
        c["runs"] = runs.get(c.get("id") or "", [])
        # A card body is not always TEXT: the board stores some of them as
        # a BLOB, and a NULL for the cards created without one. The gate
        # reads every card on the board, so it must not die on one card's
        # storage type.
        body = c.get("body")
        if isinstance(body, (bytes, bytearray)):
            c["body"] = body.decode("utf-8", errors="replace")
        elif body is None:
            c["body"] = ""
        title = c.get("title")
        if isinstance(title, (bytes, bytearray)):
            c["title"] = title.decode("utf-8", errors="replace")
    return cards


def _git_out(args: list[str], stdin: str | None = None) -> str | None:
    """Run a git command and return its stdout, or None when it fails."""
    try:
        # The BYTES are captured and decoded HERE. ``text=True`` builds a
        # TextIOWrapper with universal newlines, which translates \r\n
        # into \n DURING the decode, and a CRLF payload and an LF payload
        # are different payloads. Passing ``encoding``/``errors`` implies
        # text mode in CPython, so the decode is done here instead.
        out = subprocess.run(
            ["git", *args],
            input=(
                stdin.encode("utf-8", "surrogateescape") if stdin is not None else None
            ),
            capture_output=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    # "surrogateescape" round-trips the bytes exactly: an undecodable byte
    # becomes a lone surrogate, and encoding it back with the same escape
    # gives the byte again. ("replace" would map every undecodable byte
    # to U+FFFD, so two payloads that differ only in that byte would
    # hash the same = a fail-open collision.)
    return out.stdout.decode("utf-8", "surrogateescape")


def _merge_base(a: str, b: str) -> str | None:
    """Where two refs diverged, or None when either cannot be read."""
    out = _git_out(["merge-base", a, b])
    return out.strip() if out and out.strip() else None


def change_id(sha: str, main: str = "main") -> str | None:
    """The identity of the change a sha carries, or None.

    A verdict names a sha. A sha dies the moment the branch is rebased,
    and a rebase is exactly what the merge gate demands of a branch that
    fell behind main. So a verdict that binds to a commit id is voided by
    somebody ELSE landing their work: that is the interference this
    function removes. The verdict must attach to the CHANGE.

    WHAT the identity must be, and what it must NOT be:

    * NOT the line numbers. A rebase shifts them, and the change is the
      same change. So the hunk headers (``@@ -a,b +c,d @@``) are dropped.
    * NOT the whitespace. In Python the indent IS the meaning, and
      ``git patch-id --stable`` strips it (= two different programs share
      an id, measured 2026-10-31). So the +/- lines are kept VERBATIM.
    * NOT the context. A landing that edits a nearby line in the same
      file must not void a verdict for a change nobody touched, and a
      context line is not part of the change. So the diff is produced
      with ``-U0``: no context lines at all.

    What is left = which file changed, and exactly which lines were
    added and removed, verbatim. That is the change, and its identity is
    a hash of it.

    The change a sha carries = the diff from where its branch left main.
    None when the sha carries no change at all (= an empty diff, or a
    sha this repository does not have), and the caller must then fall
    back to comparing the commit ids.
    """
    base = _merge_base(main, sha)
    if base is None:
        return None
    # ``--full-index`` prints the WHOLE blob hashes in the ``index`` line
    # (= the abbreviated ones are too short to be an identity).
    diff = _git_out(
        ["diff", "-U0", "--no-color", "--full-index", f"{base}..{sha}"]
    )
    if diff is None or not diff.strip():
        return None
    body = _change_body(diff)
    if not body.strip():
        return None
    # Encode back with the same escape, so the hash is over the BYTES the
    # diff carried (= a payload that is not UTF-8 keeps its identity).
    return hashlib.sha256(body.encode("utf-8", "surrogateescape")).hexdigest()


def _change_body(diff: str) -> str:
    """The diff text that IS the change, section by section.

    Per file section:

    * The hunk headers are dropped (= the line numbers move in a rebase).
    * The ``index`` line is dropped for a TEXT file (= the +/- lines
      carry the content, and the base's blob hash moves as soon as the
      base does).
    * The ``index`` line is KEPT for a BINARY file. Git renders a binary
      diff as one constant line, so the new blob hash is the only thing
      in the section that says WHICH payload it is. Measured 2026-10-31:
      dropping it gave two different PNGs one identity, and the gate
      cleared a branch carrying a different image.

    The ``index`` line has to be read PER SECTION: git prints it before
    the "Binary files" line, so a line-order check reads the wrong
    answer.
    """
    kept: list[str] = []
    for part in diff.split("diff --git ")[1:]:
        section = "diff --git " + part
        # Git's own marker for a binary diff is a line that STARTS with
        # "Binary files ". A substring test over the whole section also
        # matches a TEXT file whose CONTENT says "Binary files ...", and
        # that text file would then keep its whole-file blob hash (= its
        # identity would depend on the whole file, and a landing near
        # the change would move it).
        # Split on "\n" ONLY. ``str.splitlines()`` also splits on \r (and
        # on \x0b \x0c \x1c \x1d \x1e \x85 and two Unicode ones), so a
        # lone \r inside a line would be dropped and the line cut in
        # half (= a second collision of the same shape).
        section_lines = section.split("\n")
        binary = any(line.startswith("Binary files ") for line in section_lines)
        for line in section_lines:
            if line.startswith("@@"):
                continue
            if line.startswith("index "):
                if not binary:
                    continue
                parts = line.split()
                # The mode can be on the next line (= "new file mode"), so
                # the index line carries only the two blob hashes.
                if len(parts) >= 2 and ".." in parts[1]:
                    old_blob, new_blob = parts[1].split("..", 1)
                    # A DELETION carries its payload in the OLD half (=
                    # the new half is all zeros), so keep whichever half
                    # holds the bytes. Keeping the wrong one gives every
                    # deleted file of that path one identity.
                    keep = old_blob if set(new_blob) == {"0"} else new_blob
                    line = "index " + keep
                else:
                    continue
            kept.append(line)
        kept.append("")
    return "\n".join(kept)


def patch_id(sha: str, main: str = "main") -> str | None:
    """``git patch-id --stable`` of the change a sha carries, or None.

    Kept for the record and for the test that compares the two: the
    stable patch-id ignores whitespace AND the line numbers, so it
    cannot be the identity of a change (= it merges two different
    programs). See ``change_id`` for the one the gate uses.
    """
    base = _merge_base(main, sha)
    if base is None:
        return None
    diff = _git_out(["diff", f"{base}..{sha}"])
    if diff is None or not diff.strip():
        return None
    out = _git_out(["patch-id", "--stable"], stdin=diff)
    if not out:
        return None
    parts = out.split()
    return parts[0] if parts else None


def branch_tip_history(branch: str, limit: int = 12) -> list[str]:
    """The shas a branch has pointed at, newest first.

    A rebase leaves the branch's old tip in its reflog. That is where a
    card's sha goes when the branch is rewritten: the card still names
    it, the branch no longer points at it, and the sha comparison misses.
    The reflog says "this branch used to be that"; the patch-id says
    "and it still carries the same change".
    """
    out = _git_out(["reflog", "show", "--format=%H", branch])
    if not out:
        return []
    shas: list[str] = []
    for line in out.splitlines():
        sha = line.strip()
        if sha and sha not in shas:
            shas.append(sha)
        if len(shas) >= limit:
            break
    return shas


def matching_cards(
    cards: list[dict], target_sha: str, branch: str | None = None
) -> list[tuple[str | None, str | None, str | None, str]]:
    """The review cards whose verdict covers the sha a branch points at.

    Two ways to cover it. The same commit id (= the card was written for
    this exact tip), or the same CHANGE (= the branch was rebased since,
    which rewrites the commit id and leaves the edit alone). The second
    one is what stops somebody else landing their work from voiding a
    verdict that is still good.

    THE ORDER IS THE AUTHORITY. The caller takes the FIRST card, so the
    order must put the card that governs the branch first: a card that
    names the CURRENT sha governs it, and among cards that cover the
    same tree the LATER verdict governs (= a later refusal voids an
    earlier approval, which is the gate's own rule). Only when no card
    names the current sha does a card that covers the same change come
    into it.

    Measured 2026-10-31: the caller collapsed the list with ``head -1``,
    and the board hands the cards over in creation order (= oldest
    first), so an OLD approval of a pre-rebase tree shadowed a NEWER
    refusal of the current tree and the branch landed. The order below
    is what makes ``head -1`` correct.

    Returns ``(card id, verdict status, reviewer, how)`` for every card
    that covers it, where ``how`` is ``"sha"`` or ``"change"``.
    """
    history = branch_tip_history(branch) if branch else []
    # THE BRANCH'S OWN HISTORY, not the sha being asked about, is what the
    # sha reader uses to break a tie between several commits in one body:
    # the branch says which of them the card reviewed. Passing the target in
    # here would be a guess that pays for itself the wrong way (= measured
    # on t_673fae4f, whose body cites round 1's sha before naming its own:
    # asked about round 1's head it would have answered as though IT had
    # reviewed round 1, and its refusal would have outranked the card that
    # really did). Claims are resolved with one git call before the loop, so
    # the reader can ask "is this a commit?" about every card without paying
    # a subprocess per card.
    _prime_review_claims(cards)
    target_cid: str | None = None
    target_cid_done = False
    found: list[tuple[str | None, str | None, str | None, str]] = []
    for card in cards:
        # ``review_cards_for`` returns RAW task rows (= no ``task``
        # key). ``card_kind`` reads the body and the title out of
        # ``doc["task"]``, so it must be handed the WRAPPED doc. A raw
        # row makes it judge the card on an empty body and an empty
        # title, and a card whose runs carry two profiles then reads as
        # a research card and is skipped here: the review card of a
        # card that was reworked would vanish from the lookup.
        doc = {"task": card, "runs": card.get("runs") or [], "events": []}
        if card_kind(doc) != "review":
            continue
        body = card.get("body") or ""
        sha = reviewed_sha(body, history, branch)
        if not sha:
            continue
        if _same_sha(sha, target_sha):
            verdict = verdict_from_doc(doc)
            found.append((
                card.get("id"), verdict.get("status"), verdict.get("reviewer"), "sha",
                _verdict_time(doc),
            ))
            continue
        # Not the same commit id. Is it the same CHANGE? Only a sha this
        # branch used to point at can be (= the reflog), and the change
        # has to agree.
        if not any(_same_sha(sha, h) for h in history):
            continue
        if not target_cid_done:
            target_cid = change_id(target_sha)
            target_cid_done = True
        if target_cid is None:
            continue
        card_cid = change_id(sha)
        if card_cid is None or card_cid != target_cid:
            continue
        verdict = verdict_from_doc(doc)
        found.append((
            card.get("id"), verdict.get("status"), verdict.get("reviewer"), "change",
            _verdict_time(doc),
        ))
    # THE AUTHORITY ORDER IS THE VERDICT'S OWN TIME, because EVERY card
    # in this list covers the SAME EDIT: the "sha" group names the sha
    # the branch points at, and the "change" group names a sha the
    # branch used to point at whose change identity agrees (= the same
    # edit, under an older commit id). The groups say HOW a card matched
    # (= by id or by edit), not WHICH edit it is about, so they cannot
    # outrank the time.
    #
    # The LATER verdict governs, so a later refusal is never shadowed by
    # an earlier approval. Measured 2026-10-31: an OLD approval of a
    # pre-rebase tree shadowed a NEWER refusal of the current tree, and
    # the branch landed. Measured 2026-11-01: the same shadowing in the
    # other direction (= a card approved the current sha at t=100, a
    # LATER card refused the same change under its pre-rebase sha at
    # t=500, and the group order let the approval win).
    #
    # The group is the TIE-BREAK: at the same time, the card that names
    # the current sha is the more specific answer about what will land.
    found.sort(key=lambda row: (-(row[4] or 0), 0 if row[3] == "sha" else 1))
    return [(row[0], row[1], row[2], row[3]) for row in found]


def _verdict_time(doc: dict) -> int:
    """When the card's VERDICT landed (= the run the verdict comes from).

    Not the newest run that ENDED: a run that carried no verdict (a
    crash, a superseded attempt) is not a verdict, and its timestamp
    would let an OLD approval look newer than a newer refusal.
    Measured 2026-10-31: a card approved at t=100 with a later run that
    ended at t=400 carrying no verdict sorted as the newer verdict, so
    the caller took the OLD approval over a refusal that landed at
    t=200. The selection mirrors ``verdict_from_doc``: the runs that
    carry a verdict, and the newest of those.
    """
    task = doc.get("task") or {}
    reviewer = named_reviewer(task.get("body") or "") or str(
        task.get("assignee") or ""
    ) or None
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    verdicts = _verdict_runs(runs, reviewer)
    if verdicts:
        chosen = max(verdicts, key=lambda r: _at(r, "ended_at", "started_at"))
        at = _at(chosen, "ended_at", "started_at")
        if isinstance(at, (int, float)):
            return int(at)
    created = task.get("created_at")
    return int(created) if isinstance(created, (int, float)) else 0


def _git_tip(ref: str) -> str | None:
    """The sha a branch or ref points at, or None when it cannot be read.

    The review card that covers a branch is the one whose body names the
    sha the branch points at, so the branch's own tip is the lookup key.
    A ref that does not resolve must NOT match anything: a lookup that
    falls back to "any review card" would let an unrelated card satisfy
    the gate for a branch nobody reviewed.
    """
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--verify", "-q", f"{ref}^{{commit}}"],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    sha = out.stdout.strip()
    return sha or None


# The heading the sha claim has historically lived under.
WHAT_TO_BUILD_HEADING = "what to build"
# A sha claim is 7..40 lowercase hex characters (= a git short id is unique
# at 7, an object id is 40). The minimum is written by repeating the
# character class and the maximum is enforced by ``_sha_token``, so the
# reader's bound is stated once and in words.
SHA_TOKEN_MIN = 7
SHA_TOKEN_MAX = 40
_SHA_TOKEN_PATTERN = "[0-9a-f]" * (SHA_TOKEN_MIN - 1) + "[0-9a-f]+"

# The words a review card uses when it states WHICH commit it reviewed.
# Measured 2026-11-20 on board wenshu-par: the cards this reader could not
# read all said the same thing in a line of their own (= t_673fae4f wrote
# "Head under review: **`4044f733a9`**" under a section titled "The delta
# under review", and t_7dc465c0 wrote the same line in a preamble), and 5 of
# them headed that section "SHA UNDER REVIEW". A line or heading that says
# "under review" is the card naming its SUBJECT; a bare hex run anywhere
# else in the body is a CITATION (= the round before it, the merge base, a
# landed sibling). Reading a citation as the subject is what lets one round's
# verdict answer for another round's head, measured on t_673fae4f: its body
# cites round 1's sha before naming its own, so a reader that took "the
# first token that resolves" gave round 1's head round 2's refusal.
_CLAIM_LABEL = "under review"


def _sha_token(match) -> str | None:
    """The commit id a hex run names, or None.

    A run longer than an object id is cut to 40, which is exactly what the
    reader's old quantified pattern matched, and a run shorter than a unique
    short id names nothing.
    """
    if match is None:
        return None
    token = match.group(0)
    if len(token) > SHA_TOKEN_MAX:
        return token[:SHA_TOKEN_MAX]
    return token if len(token) >= SHA_TOKEN_MIN else None


def _first_token(text: str) -> str | None:
    """The first sha-shaped hex run in a piece of text, or None."""
    return _sha_token(re.search(_SHA_TOKEN_PATTERN, text))


# A branch name: something with a slash in it, written as a word (= "wt/x",
# "project/t_1-…", "feature/y"). An ABSOLUTE PATH also has slashes, so a
# match preceded by "/" is not a branch (= a card's Worktree line would
# otherwise be read as the branch it reviewed).
_BRANCHISH_PATTERN = "[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9._/-]+"


def _subject_branch(body: str) -> str | None:
    """The branch this card says it reviewed, or None when it says none.

    A card states its branch the way it states its sha (= "Branch
    `wt/x`", or a section headed "The branch"), and it is the FIRST branch
    it states: a second one is what the branch stacks on (= measured on
    t_6f4a84c5, whose own branch is wt/inspector-9roles-2026-11-19 and whose
    body cites wt/inspector-style-2026-11-19 as the base under it).
    """
    def first(line: str) -> str | None:
        for hit in re.finditer(_BRANCHISH_PATTERN, line):
            if hit.start() and line[hit.start() - 1] == "/":
                continue  # an absolute path, not a branch
            return hit.group(0)
        return None

    for name, text in sections(body):
        for line in text.splitlines():
            if "branch" in line.lower():
                found = first(line)
                if found:
                    return found
        if "branch" in normalized(name):
            found = first(text)
            if found:
                return found
    return None


# The fallback reads at most this many distinct hex runs out of one body. A
# review card names the commit it reviewed in its opening lines; a body that
# carries a hundred hex runs (= a list of landed commits, a quoted diff) is
# not a card that names one sha, and the cap keeps a board sweep from paying
# a git lookup for every one of them.
_SHA_SCAN_CAP = 64

# token -> does it resolve as a commit in this repository? A sweep reads
# hundreds of bodies that repeat the same shas, so the answer is kept once.
_COMMIT_CACHE: dict[str, bool] = {}


def _same_sha(a: str | None, b: str | None) -> bool:
    """Whether two hex tokens name the same commit at either length.

    Bodies carry short ids and full ids, and the caller resolves refs to 40
    characters, so a comparison that insists on equal length misses. This is
    the same both-directions test ``matching_cards`` has always used.
    """
    return bool(a) and bool(b) and (a.startswith(b) or b.startswith(a))


def _claims_commit(token: str) -> bool:
    """Whether a hex token resolves as a commit object in this repository.

    A review card body is full of hex that is NOT a commit: card ids
    (``t_7c12b4c5`` carries 8 hex characters), the round before it, and
    truncated transcriptions. Measured 2026-11-10 on card t_82a8a618: a body
    that opened its WHAT TO BUILD with "Round 1 (``t_66145c1b``) found TWO
    blocking defects" made the reader return ``66145c1b`` (= a TASK ID), and
    the landing gate then reported a branch whose verdict existed as a branch
    nobody had reviewed.
    """
    hit = _COMMIT_CACHE.get(token)
    if hit is not None:
        return hit
    out = _git_out(["rev-parse", "--verify", "--quiet", f"{token}^{{commit}}"])
    ok = bool(out) and re.fullmatch(r"[0-9a-f]{40}", (out or "").strip()) is not None
    _COMMIT_CACHE[token] = ok
    return ok


def _prime_commit_cache(tokens: set[str]) -> None:
    """Resolve a whole set of hex tokens with ONE git call, and memoize.

    The reader needs "is this a commit?" for every sha claim on the board
    (= 528 of wenshu-par's 583 review cards carry one), and a per-token
    ``git rev-parse`` would pay one subprocess each: a ``merge-preflight``
    sweep that asks about 40 branches would spend the run resolving shas.
    ``cat-file --batch-check`` answers the full set in one call, and it
    answers in input order, one line per object.
    """
    todo = sorted(t for t in tokens if t and t not in _COMMIT_CACHE)
    if not todo:
        return
    payload = "".join(f"{t}^{{commit}}\n" for t in todo)
    out = _git_out(
        ["cat-file", "--batch-check=%(objectname) %(objecttype)"], stdin=payload
    )
    if out is None:
        return  # git unusable: leave the tokens uncached, the slow path answers
    answers = out.splitlines()
    for i, token in enumerate(todo):
        if i >= len(answers):
            break
        parts = answers[i].split()
        _COMMIT_CACHE[token] = (
            len(parts) >= 2
            and parts[1] == "commit"
            and re.fullmatch(r"[0-9a-f]{40}", parts[0]) is not None
        )


def _what_to_build_claim(body: str) -> str | None:
    """The first hex run of the first paragraph of WHAT TO BUILD, or None.

    This is the reader exactly as it stood, kept whole for back-compat: the
    cards already on the board were written against it, and AGENTS.md 1.15
    still asks for the heading.
    """
    for name, text in sections(body):
        if normalized(name) != WHAT_TO_BUILD_HEADING:
            continue
        lines = text.splitlines()
        if lines and lines[0].lstrip().startswith("#"):
            lines = lines[1:]
        for para in "\n\n".join(lines).split("\n\n"):
            claim = para.strip()
            if not claim:
                continue
            return _sha_token(re.search(_SHA_TOKEN_PATTERN, claim))
    return None


def _body_sha_tokens(body: str) -> list[str]:
    """Every distinct hex run in a body, in the order it appears."""
    out: list[str] = []
    seen: set[str] = set()
    for hit in re.finditer(_SHA_TOKEN_PATTERN, body):
        token = _sha_token(hit)
        if not token or token in seen:
            continue
        seen.add(token)
        if len(seen) > _SHA_SCAN_CAP:
            break
        out.append(token)
    return out


def _claim_tokens(body: str) -> list[str]:
    """The hex runs this body PRESENTS as the commit it reviewed, in order.

    Two signals, in the order a reader would trust them: a line that says
    "under review" states the subject outright, and a section whose heading
    says the same (= "SHA UNDER REVIEW", "The delta under review") states it
    with the first sha it carries. Everything else in the body is a citation
    and stays out of here, because a citation is how one round of a stack
    quotes the round before it.
    """
    out: list[str] = []

    def add(token: str | None) -> None:
        if token and token not in out:
            out.append(token)

    for name, text in sections(body):
        norm = normalized(name)
        for line in text.splitlines():
            if _CLAIM_LABEL in line.lower():
                add(_first_token(line))
        if _CLAIM_LABEL in norm or "sha" in norm.split():
            for hit in re.finditer(_SHA_TOKEN_PATTERN, text):
                add(_sha_token(hit))
    return out


def reviewed_sha(
    body: str, history: list[str] | None = None, branch: str | None = None
) -> str | None:
    """The sha a review card names. None never comes from a heading name.

    THE ORDER (= the decision, not a preference):

    1. The WHAT TO BUILD claim, exactly as the gate has always read it, when
       that token resolves as a commit here. 528 of the board's review cards
       are written this way and their answer must not move.
    2. Otherwise the sha the body NAMES AS ITS SUBJECT (= ``_claim_tokens``).
       Measured 2026-11-19 on rounds 2 and 3 of one stack (= ``t_673fae4f``,
       ``t_7c12b4c5``): both titled that section something other than WHAT TO
       BUILD, the old reader returned None, ``matching_cards`` skipped the
       card in silence, and ``merge-preflight`` printed UNREVIEWED over a
       branch whose approval was real and readable by ``--card``. A gate that
       guards a landing must not fail open on the spelling of a heading.
    3. When the card states no subject, the first hex run in the body that
       resolves as a commit -- and when the body names SEVERAL, the one this
       branch's own history contains wins (= ``history``: the shas the branch
       has pointed at). That tie-break is the decision and it is the whole of
       it: when the branch's history holds none of them, or holds several,
       this tool cannot tell which sha the card reviewed, and the answer is
       None. Guessing here is the leak that would let round 2's refusal
       answer for round 1's head (= measured: ``t_673fae4f`` cites round 1's
       sha in its opening paragraph before naming its own).
       And the guess stays inside the branch the card says it reviewed
       (= ``branch`` against ``_subject_branch``): measured on t_6f4a84c5, a
       card for wt/inspector-9roles-2026-11-19 whose body names the sha of
       the branch UNDER it, a fallback with no branch guard handed that
       stacked-on sha to a lookup for a different branch, and the verdict
       that was never about it came first.
    4. When NOTHING in the body resolves as a commit, the WHAT TO BUILD claim
       comes back anyway (= a card naming a sha this repository does not
       hold: today's answer, and the right one, because that card really does
       not cover the sha asked about). With no claim at all the answer is
       None, which means "the gate could not read this card's sha" and NOT
       "no card covers this sha" = see ``unread_review_cards``.

    A WHAT TO BUILD claim is never overridden by another sha that merely
    sits in the body: a card that reviewed head N and quotes head N-1 must
    not be read as a verdict on N-1, which is how the rounds of one stack
    differ from each other.
    """
    claim = _what_to_build_claim(body)
    if claim is not None and _claims_commit(claim):
        return claim
    subject = [t for t in _claim_tokens(body) if _claims_commit(t)]
    if subject:
        return subject[0]
    stated = _subject_branch(body)
    if branch is None or stated is None or stated == branch:
        loose = [t for t in _body_sha_tokens(body) if _claims_commit(t)]
        if len(loose) == 1:
            return loose[0]
        if loose and history:
            in_history = [t for t in loose if any(_same_sha(t, h) for h in history)]
            if len(in_history) == 1:
                return in_history[0]
    return claim


def unread_review_cards(cards: list[dict], branch: str | None = None) -> list[str]:
    """Review cards whose sha the gate could not read (= the OTHER failure).

    ``matching_cards`` returns an empty list both when no card covers the sha
    and when a card covers the branch and the reader could not parse which
    sha it named. Measured 2026-11-19: the same sentence
    ("NO REVIEW CARD names the sha") was printed for both, so a branch with a
    real approval looked like a branch nobody reviewed, and the first thing a
    reader did with that answer was re-review work that was already approved.

    A card counts here only when it is a review card, names no sha the gate
    can read, and (= when a branch was asked for) names that branch in its
    body or title. Without the branch filter every unread review card on the
    board (= 55 on wenshu-par today) would be reported against every branch.
    """
    _prime_review_claims(cards)
    # Read the sha EXACTLY the way the covering lookup reads it (= same
    # history, same branch guard), or this list would report cards the lookup
    # can in fact read, and the new sentence would be a new false alarm.
    history = branch_tip_history(branch) if branch else []
    out: list[str] = []
    for card in cards:
        doc = {"task": card, "runs": card.get("runs") or [], "events": []}
        if card_kind(doc) != "review":
            continue
        body = card.get("body") or ""
        if reviewed_sha(body, history, branch) is not None:
            continue
        # A card that says it reviewed ANOTHER branch is not unreadable here,
        # it is simply not about this one (= t_6f4a84c5 reviews
        # wt/inspector-9roles-2026-11-19 and cites the branch under it; the
        # mention is a base, not a subject). Reporting it would send a reader
        # to fix a card that is written correctly.
        stated = _subject_branch(body)
        if branch and stated and stated != branch:
            continue
        if branch:
            haystack = f"{body}\n{card.get('title') or ''}"
            if branch not in haystack:
                continue
        card_id = str(card.get("id") or "?")
        if card_id not in out:
            out.append(card_id)
    return out


def _prime_review_claims(cards: list[dict]) -> None:
    """Resolve every sha these cards could name with ONE git call.

    A card that carries a WHAT TO BUILD heading can only answer with that
    token, so only it is worth resolving. A card without one can fall
    through to its subject lines and then to any hex run in its body, so
    those candidates go in as well (= the ~55 cards on wenshu-par today that
    the heading-only reader could not read). Without this priming the same
    sweep pays one subprocess per token, and the sweep is what a landing
    runs on every branch it is about to merge.
    """
    need: set[str] = set()
    for card in cards:
        doc = {"task": card, "runs": card.get("runs") or [], "events": []}
        if card_kind(doc) != "review":
            continue
        body = card.get("body") or ""
        claim = _what_to_build_claim(body)
        if claim is None:
            # No heading to read: everything the card could answer with.
            need.update(_claim_tokens(body))
            need.update(_body_sha_tokens(body))
            continue
        need.add(claim)
    _prime_commit_cache(need)
    # SECOND PASS, and it is the whole reason this is not one call: a card
    # whose WHAT TO BUILD claim does NOT resolve falls through to the tokens
    # around it, and those were never in the first set (= measured: one
    # lookup over wenshu-par spent 3.6 s in per-token ``git rev-parse``
    # calls for exactly that path, against 0.3 s for everything else). The
    # first pass makes "which claims resolve?" a cache read, so the second
    # one can ask it and prime the remainder in one more call.
    again: set[str] = set()
    for card in cards:
        doc = {"task": card, "runs": card.get("runs") or [], "events": []}
        if card_kind(doc) != "review":
            continue
        body = card.get("body") or ""
        claim = _what_to_build_claim(body)
        if claim is None or _claims_commit(claim):
            continue
        again.update(t for t in _claim_tokens(body) if t not in _COMMIT_CACHE)
        again.update(t for t in _body_sha_tokens(body) if t not in _COMMIT_CACHE)
    _prime_commit_cache(again)


def branch_miss_lines(
    sha: str | None, branch: str, unread: list[str]
) -> list[str]:
    """What the gate prints when it found no covering card.

    Two different facts, and today they must not share a sentence: the sha
    lookup found nothing (= the work carries no verdict), and a card that
    names the branch is unreadable (= the verdict may exist and this tool
    cannot say). The first is a refusal, the second is a bug report.
    """
    if unread:
        return [
            f"REVIEW CARD UNREADABLE: {', '.join(unread)} names branch "
            f"{branch} and the gate could not read its sha",
            f"         (= the reader found no commit token the repository "
            f"resolves; asked about sha {sha or '?'}).",
            "         This is NOT \"no review card covers this sha\": a verdict "
            "may exist on that card, so read it with --card <id> before "
            "re-reviewing the branch.",
        ]
    return [
        f"NO REVIEW CARD names the sha {sha or '?'} on branch {branch}",
        "         (= no review card covers this sha: the branch carries no "
        "verdict on this commit).",
    ]


def branch_of(doc: dict) -> str | None:
    """The branch a card carries, if the board knows one."""
    return (doc.get("branch_name") or None)


def _profiles_of(card_id: str, board: str = BOARD) -> set[str]:
    """The profiles that ran this card, read from the board's run table.

    A REVIEW card has no implementation phase, so the only profile that
    touched it is the reviewer, and it is not reviewing itself.
    """
    path = _board_db_path(board)
    if path is None:
        return set()
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error:
        return set()
    try:
        rows = conn.execute(
            "SELECT DISTINCT profile FROM task_runs "
            "WHERE task_id = ? AND profile IS NOT NULL AND profile != ''",
            (card_id,),
        ).fetchall()
    except sqlite3.Error:
        return set()
    finally:
        conn.close()
    return {str(row[0]) for row in rows}


def _kind(event: dict) -> str:
    return str(event.get("kind") or "")


def _payload(event: dict) -> dict:
    raw = event.get("payload")
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {}
    return {}


def _at(item: dict, *names: str) -> int:
    """A timestamp in seconds, or 0 when the item carries none."""
    for name in names:
        value = item.get(name)
        if isinstance(value, (int, float)) and value > 0:
            return int(value)
    return 0


def implementer_of(doc: dict) -> str | None:
    """The profile that IMPLEMENTED the card.

    Not the card's current assignee: a handoff reassigns the card to the
    reviewer, so the assignee is the reviewer for the whole review, and the
    rework after a change request. The implementer is the profile the
    handoff recorded, or the profile of the first run that touched the card.
    """
    events = [e for e in (doc.get("events") or []) if isinstance(e, dict)]
    handoffs = [e for e in events if _kind(e) == "review_requested"]
    if handoffs:
        handoff = max(handoffs, key=lambda e: _at(e, "created_at"))
        recorded = _payload(handoff).get("implementer")
        if recorded:
            return str(recorded)
    if card_kind(doc) == "review":
        created_by = str((doc.get("task") or {}).get("created_by") or "").strip()
        if created_by and created_by not in ("user", "system"):
            return created_by
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    runs = [r for r in runs if r.get("profile")]
    if runs:
        first = min(runs, key=lambda r: _at(r, "started_at"))
        return str(first.get("profile"))
    return None


def implementers_from_board(board: str = BOARD) -> dict[str, str | None]:
    """Every card's implementer, read from the board's own run history.

    A handoff reassigns the card to the reviewer, so the card's CURRENT
    assignee is the reviewer for the whole review, and reading it as the
    implementer reports every finished card as reviewing itself.

    Measured 2026-10-30: 27 of 166 cards on wenshu-par were reported as
    self-reviews for that reason, and all 27 are BUILD cards whose
    implementer was wenshu-dev.

    The board's LIST view does not carry the run history, so the run table
    is read directly. That is what makes a sweep of the whole board cheap:
    one query instead of one CLI call per card.
    """
    out: dict[str, str | None] = {}
    path = _board_db_path(board)
    if path is None:
        return out
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    except sqlite3.Error:
        return out
    try:
        rows = conn.execute(
            "SELECT task_id, profile FROM task_runs "
            "WHERE profile IS NOT NULL AND profile != '' "
            "ORDER BY started_at ASC"
        ).fetchall()
    except sqlite3.Error:
        return out
    finally:
        conn.close()
    for task_id, profile in rows:
        if task_id not in out:
            out[task_id] = profile
    return out


def _board_db_path(board: str) -> Path | None:
    """The board's database file, or None when it cannot be found.

    ``HERMES_HOME`` points at the PROFILE's directory, not at the home
    that holds the boards, so the profile's own copy is tried first and
    the shared home second. Getting this wrong is not a slow path, it is
    a WRONG path: the sweep then finds no implementers at all and
    reports every finished card as reviewing itself.
    """
    candidates = []
    env = os.environ.get("HERMES_HOME")
    if env:
        candidates.append(Path(env))
    candidates.append(Path.home() / ".hermes")
    for home in candidates:
        candidate = home / "kanban" / "boards" / board / "kanban.db"
        if candidate.is_file():
            return candidate
    return None


def _implementer_of_card(card_id: str, board: str = BOARD) -> str | None:
    """The profile that implemented this card, read from the board.

    The board's LIST view does not carry the run history, so the card's
    own record is read instead (= the same record ``implementer_of`` reads).
    """
    doc = board_doc(card_id, board)
    if doc is None:
        return None
    return implementer_of(doc)


def _run_metadata(run: dict) -> dict:
    """The run's metadata, whatever shape the reader found it in.

    The board stores ``task_runs.metadata`` as JSON TEXT: the CLI decodes
    it, and the sqlite reader does not. A run read straight out of the
    database therefore carries a string, and a test for
    ``isinstance(metadata, dict)`` drops the verdict on the floor: the
    ``--branch`` path read the approval as no approval, while the
    ``--card`` path (through the CLI) read the same run as approved.
    """
    metadata = run.get("metadata")
    if isinstance(metadata, dict):
        return metadata
    if isinstance(metadata, (bytes, bytearray)):
        metadata = metadata.decode("utf-8", errors="replace")
    if isinstance(metadata, str) and metadata.strip():
        try:
            parsed = json.loads(metadata)
        except json.JSONDecodeError:
            return {}
        return parsed if isinstance(parsed, dict) else {}
    return {}


def _verdict_runs(runs: list[dict], reviewer: str | None) -> list[dict]:
    """The completed runs that carry a verdict from the reviewer.

    A verdict is either an approval or a request for changes. The board
    stores the run's metadata as JSON TEXT, so both shapes are read
    through ``_run_metadata``.
    """
    out = []
    for run in runs:
        if str(run.get("outcome") or "") != "completed":
            continue
        metadata = _run_metadata(run)
        if metadata.get("review_outcome") not in ("approved", "changes_requested"):
            continue
        if reviewer and str(run.get("profile") or "") != str(reviewer):
            continue
        out.append(run)
    return out


def verdict_from_doc(doc: dict) -> dict:
    """The verdict the board record carries for one card.

    A verdict counts only when the handoff named a reviewer, that reviewer
    profile gave it, and no rework was asked for afterwards.

    A REVIEW card is the other shape (boss ruling 2026-10-30): it was
    created FOR the reviewer and never handed off, so its verdict is the
    reviewer's own completion, and the implementer is the profile that
    created it (the one that wrote the code).

    Its verdict is read from the run's metadata field, which carries
    either ``approved`` or ``changes_requested``. The board's own
    ``request_changes`` transition is NOT the route here: it requires a
    ``review_requested`` handoff event and a run claimed out of the
    ``review`` status, and this flow never creates either.
    """
    events = [e for e in (doc.get("events") or []) if isinstance(e, dict)]
    runs = [r for r in (doc.get("runs") or []) if isinstance(r, dict)]
    handoffs = [e for e in events if _kind(e) == "review_requested"]
    if not handoffs:
        if card_kind(doc) == "review":
            task = doc.get("task") or {}
            reviewer = str(task.get("assignee") or "") or None
            implementer = str(task.get("created_by") or "") or None
            verdicts = _verdict_runs(runs, reviewer)
            if verdicts:
                verdict = max(verdicts, key=lambda r: _at(r, "ended_at", "started_at"))
                outcome = _run_metadata(verdict).get("review_outcome")
                if outcome == "changes_requested":
                    return {
                        "status": "changes_requested",
                        "reviewer": reviewer,
                        "run_id": verdict.get("id"),
                    }
                if implementer and implementer != reviewer:
                    return {
                        "status": "approved",
                        "reviewer": reviewer,
                        "implementer": implementer,
                        "run_id": verdict.get("id"),
                    }
                return {
                    "status": "self_review",
                    "reviewer": reviewer,
                    "reason": "the reviewer profile is the implementer profile",
                }
            return {
                "status": "not_approved",
                "reviewer": reviewer,
                "reason": f"no approving verdict from {reviewer or 'the reviewer'} is on the record",
            }
        return {
            "status": "no_handoff",
            "reason": "the card never handed off for review (= it was completed by its implementer)",
        }
    handoff = max(handoffs, key=lambda e: _at(e, "created_at"))
    handoff_at = _at(handoff, "created_at")
    payload = _payload(handoff)
    reviewer = payload.get("reviewer")
    implementer = payload.get("implementer")
    if not reviewer:
        return {
            "status": "no_reviewer_named",
            "reason": (
                "the handoff named no reviewer, so the board fell back to the "
                f"implementer ({implementer or 'unknown'})"
            ),
        }
    if reviewer == implementer:
        return {
            "status": "self_review",
            "reviewer": reviewer,
            "reason": "the reviewer profile is the implementer profile",
        }
    approvals = []
    for run in runs:
        if str(run.get("outcome") or "") != "completed":
            continue
        metadata = _run_metadata(run)
        if metadata.get("review_outcome") != "approved":
            continue
        if str(run.get("profile") or "") != str(reviewer):
            continue
        if _at(run, "ended_at", "started_at") < handoff_at:
            continue
        approvals.append(run)
    if not approvals:
        return {
            "status": "not_approved",
            "reviewer": reviewer,
            "reason": f"no approving verdict from {reviewer} is on the record",
        }
    approval = max(approvals, key=lambda r: _at(r, "ended_at", "started_at"))
    approved_at = _at(approval, "ended_at", "started_at")
    for event in events:
        if _kind(event) != "changes_requested":
            continue
        if _at(event, "created_at") > approved_at:
            return {
                "status": "changes_requested",
                "reviewer": reviewer,
                "reason": "changes were requested after the last approving verdict",
            }
    return {
        "status": "approved",
        "reviewer": reviewer,
        "implementer": implementer,
        "run_id": approval.get("id"),
    }


def card_record(card_id: str, board: str = BOARD) -> dict:
    """The gate state of one card on the board."""
    doc = board_doc(card_id, board)
    if doc is None:
        if card_absent(card_id, board):
            return {
                "card": card_id,
                "gate": "card_absent",
                "reason": "the card is not on the board",
            }
        return {
            "card": card_id,
            "gate": "board_unreadable",
            "reason": "the board could not be read",
        }
    task = doc.get("task") or {}
    body = task.get("body") or ""
    created_at = task.get("created_at")
    created_at = int(created_at) if isinstance(created_at, (int, float)) else None
    verdict = verdict_from_doc(doc)
    implementer = implementer_of(doc)
    kind = card_kind(doc)
    is_review = kind == "review" and is_review_card(doc)
    errors = contract_errors(body, implementer, created_at, kind=kind, is_review=is_review)
    if not is_subject(created_at):
        gate = "pre_contract"
        reason = (
            "the card was created before the review contract started "
            "(= reported, never blocked)"
        )
    elif errors:
        gate = "contract_error"
        reason = errors[0]
    else:
        gate = verdict["status"]
        reason = verdict.get("reason")
        if gate == "approved":
            reason = f"approved by {verdict.get('reviewer')}"
    return {
        "card": card_id,
        "title": task.get("title"),
        "status": task.get("status"),
        "assignee": task.get("assignee"),
        "implementer": implementer,
        "created_at": created_at,
        "pre_contract": not is_subject(created_at),
        "review_required": review_required_for_kind(body, kind)[0],
        "kind": kind,
        "reviewer": named_reviewer(body),
        "errors": errors,
        "gate": gate,
        "reason": reason,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", help="check the contract of one body file")
    parser.add_argument("--card", help="check the record of one card")
    parser.add_argument("--branch", help="the branch under review")
    parser.add_argument("--sha", help="the sha the branch points at")
    parser.add_argument("--check", action="store_true", help="check every card")
    parser.add_argument("--assignee", help="the implementer profile, for the body check")
    parser.add_argument("--board", default=BOARD, help="board slug")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()

    if args.body:
        body = Path(args.body).read_text(encoding="utf-8")
        kind = card_type(body, None, "")
        required, code = review_required_for_kind(body, kind)
        errors = contract_errors(body, args.assignee, kind=kind)
        result = {
            "card": args.body,
            "kind": kind,
            "review_required": required,
            "code_paths": code,
            "reviewer": named_reviewer(body),
            "errors": errors,
        }
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"kind: {kind}")
            print(f"review required: {'yes' if required else 'no'}")
            if code:
                print("  code: " + ", ".join(code))
            print(f"  reviewer: {result['reviewer'] or '-'}")
            for error in errors:
                print(f"  ! {error}")
        return 1 if errors else 0

    if args.card:
        record = card_record(args.card, args.board)
        if args.json:
            print(json.dumps(record, indent=2))
        else:
            print(f"{record['card']}  {record['gate']}  {record['reason'] or ''}")
            for error in record.get("errors") or []:
                print(f"  ! {error}")
        if record["gate"] == "board_unreadable":
            return 2
        if record["gate"] == "card_absent":
            # The card is not on the board. That is not an unreadable
            # board (= nobody can tell): it is a card that owes nothing,
            # and a branch naming it has no verdict.
            return 4
        if record["gate"] == "contract_error":
            return 1
        if record["gate"] in (
            "not_approved",
            "no_handoff",
            "no_reviewer_named",
            "self_review",
            "changes_requested",
        ):
            return 3
        return 0

    if args.branch:
        # The review card that covers a branch, read by the sha the branch
        # points at (= the sha the card's body names under review).
        #
        # Without --sha the branch's OWN tip is the key. A lookup that
        # matched any review card would let an unrelated card satisfy the
        # gate for a branch nobody reviewed, which is the exact defect this
        # gate exists to prevent.
        sha_filter = args.sha
        if not sha_filter:
            resolved = _git_tip(args.branch)
            if resolved is None:
                print(f"NO REVIEW CARD: branch {args.branch} has no resolvable tip")
                return 3
            sha_filter = resolved
        cards = review_cards_for(args.board)
        if cards is None:
            # The board could not be read. That is not "no card names
            # this sha": it is "nobody can ask", and an answer nobody can
            # get must not read as a refusal the caller can ignore.
            print("BOARD UNREADABLE: the board could not be read")
            return 2
        found = matching_cards(cards, sha_filter, args.branch)
        for card_id, status, reviewer, how in found:
            print(f"CARD {card_id}")
            print(f"  verdict: {status} by {reviewer}")
            if how == "change":
                print("  matched by change (= the branch was rebased; the change is the same)")
        if not found:
            # The two ways this lookup comes back empty are NOT the same
            # fact, and printing one sentence for both sent branches to be
            # re-reviewed that an approving verdict already covered
            # (= measured 2026-11-19, board wenshu-par).
            for line in branch_miss_lines(
                sha_filter, args.branch, unread_review_cards(cards, args.branch)
            ):
                print(line)
        return 0 if found else 3

    if args.check:
        cards = board_cards(args.board)
        if cards is None:
            print("the board could not be read", file=sys.stderr)
            return 2
        implementers = implementers_from_board(args.board)
        rows = []
        for card in cards:
            body = card.get("body") or ""
            created_at = card.get("created_at")
            created_at = int(created_at) if isinstance(created_at, (int, float)) else None
            kind = card_type(body, None, str(card.get("title") or ""))
            required, code = review_required_for_kind(body, kind)
            # The implementer is NOT the card's current assignee: a handoff
            # reassigns the card to the reviewer, so the assignee is the
            # reviewer for the whole review. Reading the assignee as the
            # implementer reported every finished card as reviewing itself.
            # Measured 2026-10-30: 27 of 166 cards on wenshu-par were
            # reported as self-reviews for that reason, and all 27 are
            # BUILD cards whose implementer was wenshu-dev.
            implementer = implementers.get(card.get("id") or "")
            # A REVIEW card has no implementation phase, so it is not
            # reviewing itself (= the only profile that touched it is the
            # reviewer). The sweep reads the runs directly, because the
            # board's list view does not carry them.
            profiles = _profiles_of(card.get("id"), args.board)
            is_review = kind == "review" and len(profiles) == 1
            errors = contract_errors(
                body, implementer, created_at, kind=kind, is_review=is_review
            )
            rows.append({
                "card": card.get("id"),
                "title": card.get("title"),
                "status": card.get("status"),
                "assignee": card.get("assignee"),
                "created_at": created_at,
                "pre_contract": not is_subject(created_at),
                "kind": kind,
                "review_required": required,
                "code_paths": code,
                "reviewer": named_reviewer(body),
                "errors": errors,
            })
        if args.json:
            print(json.dumps(rows, indent=2))
            return 1 if any(r["errors"] for r in rows) else 0

        subject = [r for r in rows if not r["pre_contract"]]
        failing = [r for r in subject if r["errors"]]
        owed = [r for r in subject if r["review_required"] and not r["errors"]]
        print(
            f"=== {len(rows)} card(s): {len(subject)} under the review contract, "
            f"{len(failing)} break it, {len(owed)} owe a verdict"
        )
        for row in failing:
            print(f"  {row['card']}  {row['title']}")
            for error in row["errors"]:
                print(f"      ! {error}")
        for row in owed:
            print(f"  {row['card']}  {row['title']}  (owes a verdict)")
        return 1 if failing else 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
