#!/usr/bin/env python3
"""test_merge_preflight.py — the landing gate's branch-name CLAIM is a claim.

= = WHY THIS TEST EXISTS. = = The preflight answers two questions about one
branch and used to answer them with two different authorities without ever
comparing them:

  * `review_gate.py --branch <b> --sha <tip>` — the sha lookup, which the
    script's own header calls the authority under the one-developer flow.
  * `review_gate.py --card <the id inside the branch name>` — the CLAIM.

Two defects came from trusting the claim alone. Both were measured on the
real board on 2026-11-19, and both are reproduced here on a fixture.

  1. A branch named after a BUILD card. The build card breaks the contract
     (it writes code and carries no REVIEW HANDOFF), the gate answers
     `contract_error` (= exit 1), and the preflight refused the branch —
     even though a REVIEW card on the board carried an APPROVING verdict on
     the very sha the branch pointed at. The rule the script already states
     ("a card that is not a review card at all does not decide the branch")
     was implemented by matching ONE literal, `no_handoff`, so its sibling
     `contract_error` was missed.
  2. A branch named after a REVIEW CARD whose approval belongs to a
     DIFFERENT commit. The claim answered `approved` (exit 0), the preflight
     accepted it without asking the sha lookup, and the branch printed a
     bare `CLEAN` with no verdict line at all — while the branch's own tip
     carried a NEWER `changes_requested` verdict from another card. A gate
     that skips its own check silently is the exact defect this gate exists
     to prevent.

Run:  python3 Tools/wenshu-devtool/tests/test_merge_preflight.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""

from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent.parent
PREFLIGHT = REPO / "Scripts" / "merge-preflight.sh"
GATE = REPO / "Tools" / "wenshu-devtool" / "review_gate.py"

FAILURES: list[str] = []

# A card created before 2026-10-26 02:40 CST is `pre_contract` and the gate
# reports it without blocking (= exit 0). A fixture that wants the gate to
# ANSWER about a verdict must therefore post-date the review contract, or
# every case passes because the gate refused to judge it at all.
CONTRACT_T = 1_793_000_000


def expect(name: str, ok: bool, detail: str = "") -> None:
    if ok:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}" + (f"\n          {detail}" if detail else ""))
        FAILURES.append(name)


def git(tmp: Path, *args: str) -> str:
    r = subprocess.run(
        ["git", "-c", "user.email=t@t", "-c", "user.name=t", *args],
        capture_output=True, text=True, cwd=tmp, check=True,
    )
    return r.stdout.strip()


SHIM = r'''#!/usr/bin/env python3
"""A `hermes kanban` shim for the fixture board.

review_gate.py reads ONE card through the CLI (`kanban --board B show ID
--json`) and the WHOLE board through sqlite (`_board_db_path`). A test that
only lays down the sqlite file therefore answers the sha lookup and gets
`board_unreadable` from the card path, which is the fixture's limitation,
not the script's. This shim reads the SAME fixture database and prints the
same JSON shape the real CLI prints (= `task` / `runs` / `events` /
`comments`), so the script under test runs its real path on both readers.

The argv it accepts is exactly what the gate sends:
`kanban --board <board> show <id> --json` and `--board list`.
"""
import json
import sqlite3
import sys
from pathlib import Path


def db(board):
    import os
    return Path(os.environ["HERMES_HOME"]) / "kanban" / "boards" / board / "kanban.db"


def main(argv):
    board = "fixture"
    if "--board" in argv:
        board = argv[argv.index("--board") + 1]
    path = db(board)
    if not path.is_file():
        sys.stderr.write("kanban: board %r does not exist\n" % board)
        return 1
    con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row
    if "list" in argv:
        rows = [dict(r) for r in con.execute("SELECT * FROM tasks")]
        print(json.dumps(rows))
        return 0
    if "show" in argv:
        card = argv[argv.index("show") + 1]
        task = con.execute("SELECT * FROM tasks WHERE id=?", (card,)).fetchone()
        if task is None:
            sys.stderr.write("no such task: %s\n" % card)
            return 1
        runs = [dict(r) for r in con.execute(
            "SELECT * FROM task_runs WHERE task_id=? ORDER BY started_at ASC", (card,))]
        for run in runs:
            if isinstance(run.get("metadata"), str):
                try:
                    run["metadata"] = json.loads(run["metadata"])
                except json.JSONDecodeError:
                    pass
        print(json.dumps({
            "task": dict(task), "runs": runs, "events": [], "comments": [],
            "children": [], "parents": [], "latest_summary": None,
        }))
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
'''


def make_bin(tmp: Path) -> Path:
    """The fixture `hermes` on PATH, plus the home the shim resolves to."""
    bin_dir = tmp / "hermes-home" / "bin"
    bin_dir.mkdir(parents=True)
    shim = bin_dir / "hermes"
    shim.write_text(SHIM)
    shim.chmod(0o755)
    return bin_dir


def make_repo(tmp: Path) -> dict:
    """A repo with main, one reviewed commit, and two feature branches.

    `tip`      — a branch whose own commit is the sha a review card approved.
    `stale`    — a branch whose NAME claims a review card that approved a
                 DIFFERENT commit; the branch's tip is approved by nobody and
                 refused by a newer card.

    The preflight reads the gate at `$REPO/Tools/wenshu-devtool/review_gate.py`
    and refuses every branch with `NO GATE` when that file is absent (= a
    check that cannot fail is not a check). The fixture therefore links the
    real gate and its sibling module into the temp repo, so the script under
    test runs its own path and not a stub.
    """
    repo = tmp / "repo"
    repo.mkdir()
    gate_dir = repo / "Tools" / "wenshu-devtool"
    gate_dir.mkdir(parents=True)
    for name in ("review_gate.py", "ticket_tier.py"):
        os.symlink(REPO / "Tools" / "wenshu-devtool" / name, gate_dir / name)
    git(repo, "init", "-q", "-b", "main")
    (repo / "a.txt").write_text("base\n")
    git(repo, "add", "a.txt")
    git(repo, "commit", "-q", "-m", "base")

    # the commit the stale branch's named card approved (= a different tree)
    git(repo, "checkout", "-q", "-b", "other")
    (repo / "b.txt").write_text("other\n")
    git(repo, "add", "b.txt")
    git(repo, "commit", "-q", "-m", "the other stream")
    other = git(repo, "rev-parse", "HEAD")

    git(repo, "checkout", "-q", "main")

    # the tip branch: one commit, reviewed and approved
    git(repo, "checkout", "-q", "-b", "project/t_cccc0003-t1-the-tip-branch")
    (repo / "c.txt").write_text("the tip's own edit\n")
    git(repo, "add", "c.txt")
    git(repo, "commit", "-q", "-m", "the tip's own edit")
    tip = git(repo, "rev-parse", "HEAD")

    # the stale branch: its name claims t_rev_a, its tip is a DIFFERENT edit
    git(repo, "checkout", "-q", "-b", "project/t_aaaa0001-t1-the-stale-claim")
    (repo / "d.txt").write_text("a newer edit nobody approved\n")
    git(repo, "add", "d.txt")
    git(repo, "commit", "-q", "-m", "a newer edit nobody approved")
    stale = git(repo, "rev-parse", "HEAD")

    git(repo, "checkout", "-q", "main")
    return {"repo": repo, "tip_sha": tip, "stale_sha": stale, "other_sha": other}


def review_body(sha: str) -> str:
    return (
        "## WHAT TO BUILD\n\n"
        f"A verdict on `{sha}`.\n\n"
        "## GATES\n\n"
        "- `swift build`\n\n"
        "## EVIDENCE\n\nThe verdict is in the run metadata.\n\n"
        "## REVIEW HANDOFF\n\n"
        "This card is the review. There is no implementer to hand off from.\n"
    )


def build_body() -> str:
    return (
        "## WHAT TO BUILD\n\n"
        "Rewrite `Tools/wenshu-devtool/commit_filter.py` so the guard holds.\n\n"
        "## GATES\n\n"
        "- `python3 Tools/wenshu-devtool/tests/test_install_hook.sh`\n"
    )


def make_board(tmp: Path, cards: list[dict], runs: list[dict]) -> Path:
    """A board file with the columns the gate reads, and those rows.

    The home also carries the fixture `hermes` on its bin path, because the
    gate reads ONE card through the CLI and the WHOLE board through sqlite.
    """
    home = tmp / "hermes-home"
    board_dir = home / "kanban" / "boards" / "fixture"
    board_dir.mkdir(parents=True)
    make_bin(tmp)
    db = board_dir / "kanban.db"
    con = sqlite3.connect(db)
    con.execute(
        "CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT, body TEXT,"
        " status TEXT, assignee TEXT, created_by TEXT, created_at INTEGER)"
    )
    con.execute(
        "CREATE TABLE task_runs (id INTEGER PRIMARY KEY, task_id TEXT,"
        " profile TEXT, outcome TEXT, metadata TEXT,"
        " started_at INTEGER, ended_at INTEGER)"
    )
    for c in cards:
        con.execute(
            "INSERT INTO tasks VALUES (?,?,?,?,?,?,?)",
            (c["id"], c["title"], c["body"], c["status"], c["assignee"],
             c["created_by"], c["created_at"]),
        )
    for r in runs:
        con.execute(
            "INSERT INTO task_runs VALUES (?,?,?,?,?,?,?)",
            (r.get("id"), r["task_id"], r["profile"], r["outcome"],
             json.dumps(r.get("metadata") or {}), r["started_at"],
             r.get("ended_at")),
        )
    con.commit()
    con.close()
    return home


def verdict_run(task_id: str, outcome: str, at: int, run_id: int) -> dict:
    return {
        "id": run_id,
        "task_id": task_id,
        "profile": "wenshu-review",
        "outcome": "completed",
        "metadata": {"review_outcome": outcome},
        "started_at": at,
        "ended_at": at + 1,
    }


def build_card(cid: str, sha: str, *, outcome: str, at: int, run_id: int) -> tuple[dict, dict]:
    return (
        {
            "id": cid,
            "title": f"[T1][审核] the review of {sha[:8]}",
            "body": review_body(sha),
            "status": "done",
            "assignee": "wenshu-review",
            "created_by": "pocock",
            "created_at": at - 10,
        },
        verdict_run(cid, outcome, at, run_id),
    )


def fixture_env(home: Path, repo: Path) -> dict:
    """The environment the fixture speaks.

    `HERMES_HOME` is where BOTH readers look (= review_gate.py's sqlite
    path and this test's shim). `PATH` carries the shim FIRST, because the
    gate resolves the CLI with `shutil.which("hermes")` before `HERMES_BIN`
    and would otherwise read the real board.
    """
    env = dict(os.environ)
    env["HERMES_HOME"] = str(home)
    env["PATH"] = str(home / "bin") + os.pathsep + env.get("PATH", "")
    env.pop("HERMES_BIN", None)
    return env


def run_preflight(home: Path, repo: Path, branch: str) -> tuple[int, str]:
    env = fixture_env(home, repo)
    env["WENSHU_REPO"] = str(repo)
    env["WENSHU_BOARD"] = "fixture"
    r = subprocess.run(
        ["bash", str(PREFLIGHT), branch], capture_output=True, text=True, env=env
    )
    return r.returncode, r.stdout + r.stderr


def run_gate_card(home: Path, repo: Path, card: str) -> int:
    env = fixture_env(home, repo)
    env["WENSHU_REPO"] = str(repo)
    env["WENSHU_BOARD"] = "fixture"
    return subprocess.run(
        ["python3", str(GATE), "--card", card, "--board", "fixture"],
        capture_output=True, text=True, env=env,
    ).returncode


def case_the_fixture_board_is_readable() -> None:
    """The fixture is only evidence if the gate itself can answer on it."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        g = make_repo(tmp)
        card, run = build_card("t_cccc0003", g["tip_sha"], outcome="approved", at=CONTRACT_T, run_id=1)
        home = make_board(tmp, [card], [run])
        rc = run_gate_card(home, g["repo"], "t_cccc0003")
        expect("the fixture board answers approved on its review card", rc == 0, f"gate rc={rc}")


def case_a_claim_that_is_not_a_review_card_falls_through() -> None:
    """A branch named after a BUILD card is decided by its sha, not by the claim."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        g = make_repo(tmp)
        card, run = build_card("t_cccc0003", g["tip_sha"], outcome="approved", at=CONTRACT_T, run_id=1)
        build = {
            "id": "t_dddd0004",
            "title": "[T1] build the guard",
            "body": build_body(),
            "status": "done",
            "assignee": "pocock",
            "created_by": "pocock",
            "created_at": CONTRACT_T - 50,
        }
        home = make_board(tmp, [card, build], [run])
        branch = "project/t_dddd0004-t1-the-tip-branch"
        subprocess.run(["git", "branch", "-m", "project/t_cccc0003-t1-the-tip-branch", branch],
                       cwd=g["repo"], capture_output=True, text=True)
        rc, out = run_preflight(home, g["repo"], branch)
        expect(
            "a build card's contract_error does not veto an approved sha",
            rc == 0,
            f"rc={rc}\n          {out.strip()[:400]}",
        )


def case_a_claim_on_another_commit_does_not_bless_the_branch() -> None:
    """A review card that approved a DIFFERENT commit must not print CLEAN."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        g = make_repo(tmp)
        # the card the stale branch's NAME claims approved another commit
        stale_card, stale_run = build_card(
            "t_aaaa0001", g["other_sha"], outcome="approved", at=CONTRACT_T, run_id=1
        )
        # and a newer card reviewed the stale branch's OWN tip and refused it
        newer_card, newer_run = build_card(
            "t_bbbb0002", g["stale_sha"], outcome="changes_requested", at=CONTRACT_T + 100, run_id=2
        )
        home = make_board(tmp, [stale_card, newer_card], [stale_run, newer_run])
        rc, out = run_preflight(home, g["repo"], "project/t_aaaa0001-t1-the-stale-claim")
        expect(
            "a claim that covers another commit never prints a bare CLEAN",
            rc == 3 and "t_aaaa0001" not in out.split("CLEAN")[0],
            f"rc={rc}\n          {out.strip()[:400]}",
        )
        expect(
            "and the refusal names the card that actually reviewed the tip",
            "t_bbbb0002" in out,
            f"rc={rc}\n          {out.strip()[:400]}",
        )


def case_an_approved_tip_still_lands() -> None:
    """The gate must still let through the branch a review card approved."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        g = make_repo(tmp)
        card, run = build_card("t_cccc0003", g["tip_sha"], outcome="approved", at=CONTRACT_T, run_id=1)
        home = make_board(tmp, [card], [run])
        rc, out = run_preflight(home, g["repo"], "project/t_cccc0003-t1-the-tip-branch")
        expect("an approved tip still lands", rc == 0, f"rc={rc}\n          {out.strip()[:300]}")


def case_a_sha_no_card_names_is_refused() -> None:
    """A branch nobody reviewed is refused, not skipped."""
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        g = make_repo(tmp)
        card, run = build_card("t_cccc0003", g["tip_sha"], outcome="approved", at=CONTRACT_T, run_id=1)
        home = make_board(tmp, [card], [run])
        rc, out = run_preflight(home, g["repo"], "project/t_aaaa0001-t1-the-stale-claim")
        expect(
            "a tip no review card names is refused",
            rc == 3,
            f"rc={rc}\n          {out.strip()[:300]}",
        )


def main() -> int:
    for case in (
        case_the_fixture_board_is_readable,
        case_a_claim_that_is_not_a_review_card_falls_through,
        case_a_claim_on_another_commit_does_not_bless_the_branch,
        case_an_approved_tip_still_lands,
        case_a_sha_no_card_names_is_refused,
    ):
        case()
    print(f"\n{len(FAILURES)} failure(s)")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
