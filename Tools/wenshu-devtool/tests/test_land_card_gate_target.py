#!/usr/bin/env python3
"""test_land_card_gate_target.py — the landing gates the tree the BRANCH is in, or refuses.

= = WHY THIS TEST EXISTS. = = The landing found the tree to rebase, gate and merge by
asking the CARD where its author sat (`Scripts/land_worktree.py`, the card's own
`workspace_path`). For a build card those are the same tree. For a REVIEW card they are
not: the review lane's worktree sits on the derived branch at `main` and has never
contained the commits under review. The landing rebased that tree — which already equalled
`main` — so `main..branch` over the tree it gated was EMPTY, every window-taking judge
printed that it had measured nothing, exited 0, and `RESULT: LANDED` was printed about a
branch the gated tree did not contain.

Four assertions, each with a case that goes red when the assertion is removed:

  1. the target is the registered worktree whose `branch` line IS the branch being landed,
     whether or not that is where the card's author was sitting.
  2. a branch with no commits ahead of `main` is refused BEFORE anything is rebased or
     gated, and the refusal names the count it saw.
  3. the tree that lands is the tree the gates ran in: if the branch ref moves between the
     last gate and the swap, the landing refuses instead of promoting an ungated commit.
  4. `--preflight-only` applies the same three refusals, so a rehearsal cannot pass for a
     reason the real run rejects.

THE FIXTURE is the one `test_land_card_cas.py` builds (= a bare remote, a shared checkout,
a card worktree, and the repo's OWN `Scripts/land_card.sh` copied in, = so the shell's own
blocks are what these cases run), plus a second worktree parked on `main` standing in for
the review lane.

Run:  python3 Tools/wenshu-devtool/tests/test_land_card_gate_target.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""

from __future__ import annotations

import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
CAS_PATH = HERE / "test_land_card_cas.py"

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}  {detail}")
        FAILURES.append(name)


def load_cas():
    spec = importlib.util.spec_from_file_location("test_land_card_cas", CAS_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def add_marker(worktree: Path, text: str, name: str) -> None:
    (worktree / name).write_text(text, encoding="utf-8")
    CAS.git(worktree, "add", name)
    CAS.git(worktree, "commit", "-qm", f"{name} on the branch")


def park_a_review_tree(shared: Path, tmp: Path) -> Path:
    """A second worktree standing in for the review lane: on `main`, not on the branch."""
    parked = tmp / "review-lane"
    parked.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["git", "-C", str(shared), "worktree", "add", "-q", "-b", "project/review_derived",
         str(parked), "main"],
        check=True,
    )
    return parked


def gate_marker(tmp: Path) -> Path:
    """A file the gate hook touches, proving WHETHER a gate ran at all.

    The marker lives in the case's own directory: a path shared by every case (a parent
    of it, say) is a flag a previous run left behind, and the case then reads a run that
    never happened.
    """
    return tmp / "gate-ran.flag"


def case_one_target_is_the_branch(tmp: Path) -> None:
    """The branch's worktree lands even though the card's own path points elsewhere."""
    print("case 1: the target is the branch's worktree, not the card's")
    _, shared, worktree = CAS.make_fixture(tmp)
    park_a_review_tree(shared, tmp)
    CAS.install_scripts(shared, CAS.STUB_PREFLIGHT)
    before = git_(shared, "rev-parse", "main")

    # The card id is deliberately NOT the branch's worktree name: the convention path
    # `.worktrees/t_reviewer` does not exist, which is the state that used to make the
    # landing rebase a directory it guessed.
    rc, out = CAS.land(shared, "t_reviewer", "wt/t_card", "true")

    after = git_(shared, "rev-parse", "main")
    check("case 1: the landing succeeded against a branch it did not guess",
          rc == 0 and "RESULT: LANDED" in out, f"rc={rc} tail={out[-400:]}")
    check("case 1: main moved to the branch's commit",
          after != before and git_(shared, "log", "-1", "--format=%s") == "the card's work",
          f"before={before[:8]} after={after[:8]}")
    check("case 1: the landing says which tree is landing",
          "WHAT lands" in out, f"tail={out[-400:]}")
    check("case 1: the review lane's parked tree was not rebased",
          git_(tmp / "review-lane", "rev-parse", "HEAD") == before,
          "the parked tree moved")


def case_two_no_worktree_on_branch(tmp: Path) -> None:
    print("case 2: a branch checked out nowhere is refused by name")
    _, shared, _ = CAS.make_fixture(tmp)
    CAS.install_scripts(shared, CAS.STUB_PREFLIGHT)
    before = git_(shared, "rev-parse", "main")
    rc, out = CAS.land(shared, "t_card", "wt/nowhere-at-all", "true")
    check("case 2: the landing refuses",
          rc == 21 and "reason=NO_WORKTREE_ON_BRANCH" in out, f"rc={rc} tail={out[-300:]}")
    check("case 2: the refusal names the branch it could not find",
          "wt/nowhere-at-all" in out, f"tail={out[-300:]}")
    check("case 2: main did not move", git_(shared, "rev-parse", "main") == before)


def case_three_empty_lane(tmp: Path) -> None:
    print("case 3: an empty lane is refused before anything is gated")
    _, shared, worktree = CAS.make_fixture(tmp)
    CAS.install_scripts(shared, CAS.STUB_PREFLIGHT)
    # A branch that carries NOTHING main lacks: reset it back onto main's own commit.
    base = git_(shared, "rev-parse", "main")
    git_(worktree, "reset", "--hard", base)
    before = git_(shared, "rev-parse", "main")
    marker = gate_marker(tmp)
    rc, out = CAS.land(shared, "t_card", "wt/t_card", f"touch {marker}")
    check("case 3: the landing refuses an empty lane",
          rc == 22 and "reason=EMPTY_LANE" in out, f"rc={rc} tail={out[-300:]}")
    check("case 3: the refusal prints the count it measured",
          "0 commits" in out, f"tail={out[-300:]}")
    check("case 3: no gate ran", not marker.exists(), f"{marker} exists")
    check("case 3: main did not move", git_(shared, "rev-parse", "main") == before)


def case_four_ref_moves_under_the_gates(tmp: Path) -> None:
    print("case 4: a branch that moves between the gates and the swap is refused")
    _, shared, worktree = CAS.make_fixture(tmp)
    CAS.install_scripts(shared, CAS.STUB_PREFLIGHT)
    add_marker(worktree, "second\n", "second.txt")
    branch_tip = git_(shared, "rev-parse", "wt/t_card")
    parent = git_(shared, "rev-parse", "wt/t_card^")
    before = git_(shared, "rev-parse", "main")
    # The gate hook IS the sibling: while the gates run, the branch ref is moved back, so
    # the tree the gates are standing in no longer equals the branch that is being landed.
    gate = f"git -C {shared} update-ref refs/heads/wt/t_card {parent}"
    rc, out = CAS.land(shared, "t_card", "wt/t_card", gate)
    check("case 4: the landing refuses instead of promoting an ungated commit",
          rc == 41 and "THE_BRANCH_MOVED_DURING_THE_GATES" in out,
          f"rc={rc} tail={out[-500:]}")
    check("case 4: main was not moved onto the ungated sha",
          git_(shared, "rev-parse", "main") == before,
          f"tip={branch_tip[:8]} main={git_(shared, 'rev-parse', 'main')[:8]}")


def case_five_preflight_applies_the_same_refusals(tmp: Path) -> None:
    print("case 5: --preflight-only refuses for the same reasons the run refuses")
    _, shared, worktree = CAS.make_fixture(tmp)
    CAS.install_scripts(shared, CAS.STUB_PREFLIGHT)
    base = git_(shared, "rev-parse", "main")
    git_(worktree, "reset", "--hard", base)

    def rehearsal() -> tuple[int, str]:
        env = {**os.environ, "LOGDIR": str(shared / ".gate-logs")}
        p = subprocess.run(
            ["bash", str(shared / "Scripts" / "land_card.sh"), "--preflight-only",
             "t_card", "wt/t_card", "true"],
            capture_output=True, text=True, cwd=str(shared), env=env)
        return p.returncode, p.stdout + p.stderr

    def real() -> tuple[int, str]:
        return CAS.land(shared, "t_card", "wt/t_card", "true")

    rrc, rout = rehearsal()
    prc, pout = real()
    rline = next((l for l in rout.splitlines() if l.startswith("RESULT:")), rout[-200:])
    pline = next((l for l in pout.splitlines() if l.startswith("RESULT:")), pout[-200:])
    check("case 5: the rehearsal refuses the empty lane",
          rrc == 22 and "reason=EMPTY_LANE" in rout, f"rc={rrc} tail={rout[-300:]}")
    check("case 5: rehearsal and run refuse with the SAME reason and code",
          (rrc, rline) == (prc, pline), f"rehearsal=({rrc},{rline}) run=({prc},{pline})")
    # And the rehearsal is not a mute button either: a lane that has a commit in it is
    # allowed to proceed, with the identical decision line the old script printed.
    add_marker(worktree, "land me\n", "land.txt")
    rrc2, rout2 = rehearsal()
    check("case 5: a lane with a commit in it still rehearses PROCEED",
          rrc2 == 0 and "decision=PROCEED" in rout2, f"rc={rrc2} tail={rout2[-300:]}")


def git_(cwd: Path, *args: str) -> str:
    return CAS.git(cwd, *args)


def main() -> int:
    global CAS
    CAS = load_cas()
    cases = (
        ("case 1 the branch's worktree is the target", case_one_target_is_the_branch),
        ("case 2 no worktree on the branch", case_two_no_worktree_on_branch),
        ("case 3 an empty lane", case_three_empty_lane),
        ("case 4 the ref moves under the gates", case_four_ref_moves_under_the_gates),
        ("case 5 the rehearsal owes the same refusals", case_five_preflight_applies_the_same_refusals),
    )
    for title, fn in cases:
        with tempfile.TemporaryDirectory() as td:
            try:
                fn(Path(td))
            except Exception as exc:  # a fixture that dies is a case that did not pass
                check(f"{title}: the case ran at all", False, f"{type(exc).__name__}: {exc}")
    print(f"\n{'FAILURES: ' + str(len(FAILURES)) if FAILURES else 'all cases passed'}")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
