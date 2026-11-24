#!/usr/bin/env python3
"""test_land_card_cas.py — the landing moves `main` and NOTHING ELSE.

= = WHY THIS TEST EXISTS. = = The landing used to fast-forward `main` by
running `git merge --ff-only` INSIDE the shared checkout (= the checkout
every session reads and writes), so two sessions landing at once fought
over one working tree. The landing now merges in the card's OWN worktree
and moves `main`'s REF by compare-and-swap, so:

  1. the shared checkout's FILES are never written by a landing, and
  2. a `main` that moved under the landing makes the swap FAIL (= the ref
     is not changed) instead of overwriting the other session's landing.

Neither property had a test. The script's own header describes a loop
(= rebase, gates, merge) and a retry, and the CAS was the one step with
no proof, so a defect in it would have shipped as a silent revert.

THE THREE CASES

  1. a clean landing: `main`'s ref moves to the merged sha, and the shared
     checkout's working tree still holds the OLD files (= the landing moved
     a pointer, not a tree).
  2. a `main` that moves UNDER the landing (= during the gate step): the
     compare-and-swap refuses, and the other session's commit is still on
     `main` (= it was not overwritten).
  3. the retry: after the refusal, the loop rebases onto the NEW `main`
     and lands on top of it (= the other session's commit is still an
     ancestor of the landed sha).

THE FIXTURE

A real git repo with a real bare remote, a real shared checkout and a
real card worktree, and the repo's OWN `Scripts/land_card.sh` copied in
(= the script under test IS the shipped script, not a copy of it). The
preflight is stubbed (= the preflight has its own suite) and the gate
command is the test's own hook, which is where case 2 moves `main`.

Run:  python3 Tools/wenshu-devtool/tests/test_land_card_cas.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
LAND_SCRIPT = REPO_ROOT / "Scripts" / "land_card.sh"
GATE_SCRIPT = REPO_ROOT / "Scripts" / "gate_run.sh"

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}  {detail}")
        FAILURES.append(name)


def git(cwd: Path, *args: str) -> str:
    out = subprocess.run(
        ["git", "-C", str(cwd), *args],
        capture_output=True,
        text=True,
        env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t"},
    )
    if out.returncode != 0:
        raise RuntimeError(f"git {args} failed: {out.stderr}")
    return out.stdout.strip()


def git_ok(cwd: Path, *args: str) -> bool:
    """True when a git probe succeeds (= `merge-base --is-ancestor` says yes)."""
    return (
        subprocess.run(
            ["git", "-C", str(cwd), *args],
            capture_output=True,
            text=True,
        ).returncode
        == 0
    )


def make_fixture(tmp: Path) -> tuple[Path, Path, Path]:
    """A bare remote, a shared checkout with `main`, and a card worktree."""
    remote = tmp / "remote.git"
    subprocess.run(["git", "init", "-q", "--bare", str(remote)], check=True)

    shared = tmp / "shared"
    subprocess.run(["git", "init", "-q", "-b", "main", str(shared)], check=True)
    git(shared, "config", "user.name", "t")
    git(shared, "config", "user.email", "t@t")
    (shared / "file.txt").write_text("base\n", encoding="utf-8")
    (shared / "other.txt").write_text("other\n", encoding="utf-8")
    git(shared, "add", "-A")
    git(shared, "commit", "-qm", "base")
    git(shared, "remote", "add", "origin", str(remote))
    git(shared, "push", "-q", "-u", "origin", "main")

    # The card's own worktree, with the card's branch born IN it. The
    # branch is never checked out in the shared checkout, so the shared
    # checkout's index and working tree stay clean (= a dirty shared
    # checkout is what a landing must never create, and a fixture that
    # starts dirty cannot tell the two apart).
    worktree = tmp / "shared" / ".worktrees" / "t_card"
    worktree.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "git",
            "-C",
            str(shared),
            "worktree",
            "add",
            "-q",
            "-b",
            "wt/t_card",
            str(worktree),
            "main",
        ],
        check=True,
    )
    (worktree / "card.txt").write_text("card\n", encoding="utf-8")
    git(worktree, "add", "-A")
    git(worktree, "commit", "-qm", "the card's work")
    return remote, shared, worktree


def install_scripts(shared: Path, stub_preflight: str) -> None:
    """The repo's own land_card.sh and gate_run.sh, plus a stub preflight."""
    scripts = shared / "Scripts"
    scripts.mkdir(exist_ok=True)
    shutil.copy(LAND_SCRIPT, scripts / "land_card.sh")
    shutil.copy(GATE_SCRIPT, scripts / "gate_run.sh")
    os.chmod(scripts / "land_card.sh", 0o755)
    os.chmod(scripts / "gate_run.sh", 0o755)
    (scripts / "merge-preflight.sh").write_text(stub_preflight, encoding="utf-8")


STUB_PREFLIGHT = """#!/usr/bin/env bash
# The preflight has its own suite; the landing test stubs it.
echo "CLEAN    $1"
exit 0
"""


def land(
    shared: Path,
    card: str,
    branch: str,
    gate_cmd: str,
    env_extra: dict | None = None,
) -> tuple[int, str]:
    env = {**os.environ, "LOGDIR": str(shared / ".gate-logs")}
    env.update(env_extra or {})
    out = subprocess.run(
        ["bash", str(shared / "Scripts" / "land_card.sh"), card, branch, gate_cmd],
        capture_output=True,
        text=True,
        cwd=str(shared),
        env=env,
    )
    return out.returncode, out.stdout + out.stderr


def case_one(shared: Path, worktree: Path) -> None:
    """A clean landing moves the ref and does not write the shared files."""
    print("case 1: a clean landing moves main's ref and nothing else")
    before_files = (shared / "file.txt").read_text(encoding="utf-8")
    before_main = git(shared, "rev-parse", "main")
    shared_status_before = git(shared, "status", "--porcelain")

    rc, out = land(shared, "t_card", "wt/t_card", "true")

    after_main = git(shared, "rev-parse", "main")
    check(
        "case 1: main's ref moved to the card's commit",
        after_main != before_main and git(shared, "log", "-1", "--format=%s", after_main)
        == "the card's work",
        f"before={before_main} after={after_main}",
    )
    check(
        "case 1: the landing succeeded",
        rc == 0 and "RESULT: LANDED" in out,
        f"rc={rc} tail={out[-300:]}",
    )
    check(
        "case 1: the shared checkout's FILES were not written (= the landing moved a pointer, not a tree)",
        (shared / "file.txt").read_text(encoding="utf-8") == before_files
        and not (shared / "card.txt").exists(),
        "the shared checkout's working tree now holds the landed commit",
    )
    files_before = sorted(
        str(p.relative_to(shared))
        for p in shared.rglob("*")
        if p.is_file()
        and ".git/" not in str(p.relative_to(shared))
        and not str(p.relative_to(shared)).startswith(".worktrees/")
        and not str(p.relative_to(shared)).startswith(".gate-logs/")
        and not str(p.relative_to(shared)).startswith("Scripts/")
    )
    check(
        "case 1: the shared checkout's working tree holds no residue from the landing",
        files_before == sorted(
            str(p.relative_to(shared))
            for p in shared.rglob("*")
            if p.is_file()
            and ".git/" not in str(p.relative_to(shared))
            and not str(p.relative_to(shared)).startswith(".worktrees/")
            and not str(p.relative_to(shared)).startswith(".gate-logs/")
            and not str(p.relative_to(shared)).startswith("Scripts/")
        ),
        "the landing wrote a file into the shared checkout",
    )
    check(
        "case 1: the landed commit's file is NOT in the shared checkout (= the tree was not written)",
        not (shared / "card.txt").exists(),
        "the shared checkout's tree now holds the landed commit's file",
    )


def case_two_and_three(tmp: Path) -> None:
    """A main that moves under the landing is refused, then the retry lands."""
    print("case 2 and 3: a main that moves under the landing")
    remote, shared, worktree = make_fixture(tmp)
    install_scripts(shared, STUB_PREFLIGHT)

    # The hook that moves `main` while the landing runs (= during the
    # gate step, which is AFTER the landing read the sha it expects).
    marker = tmp / "moved.marker"
    mover = tmp / "mover.sh"
    mover.write_text(
        "#!/usr/bin/env bash\n"
        "# Move main once, so the first attempt's compare-and-swap refuses\n"
        "# and the retry lands on top of the other session's commit.\n"
        f"exec > '{tmp}/mover.log' 2>&1\n"
        "echo \"cwd=$PWD\"\n"
        "set -x\n"
        f"if [ ! -f '{marker}' ]; then\n"
        f"  touch '{marker}'\n"
        f"  cd '{shared}'\n"
        "  git checkout -q -b other-session\n"
        "  echo other > other-session.txt\n"
        "  git add -A\n"
        "  git commit -qm 'the other session lands'\n"
        "  git checkout -q main\n"
        "  git merge -q --ff-only other-session\n"
        "  git push -q origin main\n"
        "fi\n"
        "exit 0\n",
        encoding="utf-8",
    )
    os.chmod(mover, 0o755)

    # The gate command runs the hook. The paths are baked into the command
    # (= not passed through the environment), because the gate runner hands
    # the command to a fresh login shell and the test must not depend on
    # which variables that shell keeps.
    gate_cmd = f"bash '{mover}'"

    rc, out = land(shared, "t_card", "wt/t_card", gate_cmd)

    hook_log = ""
    if (tmp / "mover.log").is_file():
        hook_log = (tmp / "mover.log").read_text(encoding="utf-8")
    check(
        "case 2: the hook moved main while the landing ran",
        marker.exists(),
        "the gate hook never ran",
    )
    other_sha = git(shared, "log", "--format=%H %s", "main")
    check(
        "case 2: the other session's commit is on main",
        "the other session lands" in other_sha,
        other_sha + "\n--- the hook's own log ---\n" + hook_log,
    )

    landed = git(shared, "rev-parse", "main")
    check(
        "case 3: the retry landed the card ON TOP of the other session's commit (= nobody was reverted)",
        git_ok(shared, "merge-base", "--is-ancestor", "other-session", landed),
        f"main={landed}",
    )
    check(
        "case 3: the landed sha carries BOTH commits",
        git(shared, "log", "--format=%s", "-3", landed).count("the other session lands") >= 1
        and git(shared, "log", "--format=%s", "-3", landed).count("the card's work") >= 1,
        git(shared, "log", "--format=%s", "-3", landed),
    )
    check(
        "case 3: the landing reported success",
        rc == 0 and "RESULT: LANDED" in out,
        f"rc={rc} tail={out[-600:]}",
    )
    check(
        "case 3: the refusal was reported (= the retry is visible, not silent)",
        "MAIN MOVED UNDER THIS LANDING" in out,
        "the compare-and-swap refusal was not printed",
    )


def main() -> int:
    print("the landing moves main and nothing else")
    if not LAND_SCRIPT.is_file():
        print(f"FAILED: {LAND_SCRIPT} is missing")
        return 1
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        remote, shared, worktree = make_fixture(tmp_path)
        install_scripts(shared, STUB_PREFLIGHT)
        case_one(shared, worktree)
    with tempfile.TemporaryDirectory() as tmp:
        case_two_and_three(Path(tmp))

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s): {FAILURES}")
        return 1
    print("the landing moves main and nothing else: every case passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
