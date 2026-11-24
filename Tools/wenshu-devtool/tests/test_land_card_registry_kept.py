#!/usr/bin/env python3
"""test_land_card_registry_kept.py — a landing may not unmake a row it never wrote.

= = WHY THIS TEST EXISTS. = = `docs/agents/nfi.md` is append-only and `.gitattributes` gives it a
key-level MERGE driver, so two lanes that each append a row keep both rows on a merge. A landing is
not a merge: `land_card.sh` REBASES, the driver is never asked, and the replay lands one commit's
hunk on a tail that has grown since. Measured on a real branch tonight: a commit whose own effect on
the registry was `+3 / -0` replayed against a `main` nine commits newer as `+16 / -18` — eighteen
rows belonging to other lanes, every other gate in the flow green.

THE FOUR CASES

  1. two lanes each append a row, the second landing on top of the first: both rows survive, and the
     landing's own effect on the registry is `+1 / -0`.
  2. a branch that removes a row it never added is REFUSED, and the refusal names the row.
  3. a branch that REWRITES a row it owns (the rename case, where the row it deletes is the row it
     adds) is allowed: the guard counts rows, not lines, and a rewrite is not a loss.
  4. `--preflight-only` refuses case 2 with the same reason and the same code as the run, so a
     rehearsal cannot pass for a reason the landing rejects.

THE FIXTURE is the one `test_land_card_cas.py` builds (a bare remote, a shared checkout, a card
worktree, the repo's OWN `Scripts/land_card.sh` copied in), plus a real `docs/agents/nfi.md` table and
the registry's `.gitattributes` line, so what is tested is the shipped script against a registry that
behaves like the shipped one.

Run:  python3 Tools/wenshu-devtool/tests/test_land_card_registry_kept.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent.parent
LAND_SCRIPT = REPO_ROOT / "Scripts" / "land_card.sh"
GATE_SCRIPT = REPO_ROOT / "Scripts" / "gate_run.sh"

FAILURES: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}  {detail}")
        FAILURES.append(name)


def git(cwd: Path, *args: str, check: bool = True) -> str:
    r = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True,
                       env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t",
                            "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"})
    if check and r.returncode != 0:
        raise RuntimeError(f"git {args} failed: {r.stderr}")
    return r.stdout.strip()


# = = THE SAME SHAPE THE REAL REGISTRY HAS. = = `docs/agents/nfi.md` is append-only and says
# = = where to append (= a marker line at the foot of the table). The landing's replay
# = = depends on that marker: it is the reason a replay can put rows back without rewriting
# = = a table it does not own. = = A fixture with a bare table would be refused by the tool
# = = for the right reason about the wrong file, = = which is not a test.
NFI_FOOTER = ("<!-- Append new rows at the END of the table above. The key-level merge\n"
              "     driver keeps both rows when two cards add one each. -->\n")
NFI_HEADER = """# NFI registry

| Parent (god-class) | Extracted file | LOC | Content |
| ------------------ | -------------- | --- | ------- |
"""


def make_repo(tmp: Path) -> tuple[Path, Path]:
    """A shared checkout with a registry, and a lane worktree born inside it."""
    remote = tmp / "remote.git"
    subprocess.run(["git", "init", "-q", "--bare", str(remote)], check=True)
    shared = tmp / "shared"
    subprocess.run(["git", "init", "-q", "-b", "main", str(shared)], check=True)
    git(shared, "config", "user.name", "t")
    git(shared, "config", "user.email", "t@t")
    docs = shared / "docs" / "agents"
    docs.mkdir(parents=True)
    (docs / "nfi.md").write_text(NFI_HEADER + "| `Seed.swift` | `SeedA.swift` | 10 | seed a |\n"
                                "| `Seed.swift` | `SeedB.swift` | 20 | seed b |\n" + NFI_FOOTER,
                                encoding="utf-8")
    # = = THE REAL DRIVER, NOT A STUB. = = A stub that resolves nothing would make case 1
    # = = test the stub. = = The shipped `Scripts/merge-nfi-registry.py` is copied in and
    # = = wired exactly as `.gitattributes` wires it, = = so case 1 proves the real pairing
    # = = (the driver keeps both rows and the guard has nothing to refuse) and case 2 proves
    # = = the guard refuses what no driver can save (= a branch that deletes a row it never
    # = = added). = = And note what the driver does NOT cover: a rebase is not a merge, which
    # = = is the whole reason the guard exists.
    drivers = shared / "Scripts"
    drivers.mkdir(parents=True, exist_ok=True)  # = = before anything is copied into it
    shutil.copy(REPO_ROOT / "Scripts" / "merge-nfi-registry.py", drivers / "merge-nfi-registry.py")
    os.chmod(drivers / "merge-nfi-registry.py", 0o755)
    (shared / ".gitattributes").write_text("docs/agents/nfi.md merge=nfi-registry\n", encoding="utf-8")
    git(shared, "config", "merge.nfi-registry.driver",
        "python3 Scripts/merge-nfi-registry.py %O %A %B")
    (shared / "Scripts").mkdir(parents=True, exist_ok=True)
    for src, dst in ((LAND_SCRIPT, "land_card.sh"), (GATE_SCRIPT, "gate_run.sh")):
        p = shared / "Scripts" / dst
        p.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
        os.chmod(p, 0o755)
    (shared / "Scripts" / "merge-preflight.sh").write_text(
        '#!/usr/bin/env bash\necho "CLEAN    $1"\nexit 0\n', encoding="utf-8")
    os.chmod(shared / "Scripts" / "merge-preflight.sh", 0o755)
    (shared / "SeedA.swift").write_text("// a registered file\n", encoding="utf-8")
    git(shared, "add", "-A")
    git(shared, "commit", "-qm", "base")
    git(shared, "remote", "add", "origin", str(remote))
    git(shared, "push", "-q", "-u", "origin", "main")
    return remote, shared


def lane(shared: Path, tmp: Path, name: str) -> Path:
    wt = tmp / f"wt-{name}"
    subprocess.run(["git", "-C", str(shared), "worktree", "add", "-q", "-b", f"wt/{name}",
                    str(wt), "main"], check=True)
    return wt


def append_row(wt: Path, key: str, text: str) -> None:
    """Append in the registry's own place: above the append marker, or at the end of the table."""
    p = wt / "docs" / "agents" / "nfi.md"
    lines = p.read_text(encoding="utf-8").rstrip("\n").split("\n")
    at = [i for i, ln in enumerate(lines) if ln.startswith("<!-- Append new rows at the END")]
    assert len(at) == 1, "the fixture's registry lost its append marker"
    lines.insert(at[0], f"| `Seed.swift` | `{key}` | 30 | {text} |")
    p.write_text("\n".join(lines) + "\n", encoding="utf-8")
    git(wt, "add", "docs/agents/nfi.md")
    git(wt, "commit", "-qm", f"register {key}")


def run_land(shared: Path, card: str, branch: str, extra: list[str] | None = None) -> tuple[int, str]:
    env = {**os.environ, "LOGDIR": str(shared / ".gate-logs")}
    cmd = ["bash", str(shared / "Scripts" / "land_card.sh"), *(extra or []), card, branch, "true"]
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(shared), env=env)
    return r.returncode, r.stdout + r.stderr


def registry_effect(shared: Path, sha: str) -> tuple[int, int]:
    out = git(shared, "show", "--format=", "--numstat", sha, "--", "docs/agents/nfi.md")
    if not out.strip():
        return 0, 0
    added, removed, _ = out.split()[0:3]
    return int(added), int(removed)


def run_rehearse(shared: Path, card: str, branch: str) -> tuple[int, str]:
    """`--preflight-only` over the shipped script: the rehearsal, not a copy of it."""
    env = {**os.environ, "LOGDIR": str(shared / ".gate-logs")}
    r = subprocess.run(["bash", str(shared / "Scripts" / "land_card.sh"), "--preflight-only",
                        card, branch, "true"], capture_output=True, text=True,
                       cwd=str(shared), env=env)
    return r.returncode, r.stdout + r.stderr


def case_main_ahead_is_not_a_row_loss(tmp: Path) -> None:
    """The incident's geometry: `main` moved AHEAD of the branch under review.

    Lane A lands and the registry gains its row. Lane B is cut from the commit that WAS `main`
    before that, so B's tree genuinely never carried A's row. Rehearsing B against the newer
    `main` used to read every row B never had as a loss the branch caused — and then excuse them
    all, because the same range in `--diff-filter=D` lists the files other lanes ADDED as if B
    deleted them. The guard printed zero over a twelve-row gap. The window is the merge-base,
    so the rows outside B's own history are none of B's business, and the guard says nothing.
    """
    _remote, shared = make_repo(tmp)
    base = git(shared, "rev-parse", "main")

    a = lane(shared, tmp, "ahead-a")
    append_row(a, "AheadLane.swift", "a row landed while this branch slept")
    rc, out = run_land(shared, "t_ahead_a", "wt/ahead-a")
    check("case 5: the other lane landed first", rc == 0 and "RESULT: LANDED" in out,
          f"rc={rc} tail={out[-300:]}")
    main_now = git(shared, "rev-parse", "main")
    check("case 5b: `main` really moved ahead of the older base", main_now != base,
          f"{main_now[:8]} == {base[:8]}")

    # = = lane B is cut from the commit that was main BEFORE A landed.
    b = tmp / "wt-ahead-b"
    subprocess.run(["git", "-C", str(shared), "worktree", "add", "-q", "-b", "wt/ahead-b",
                    str(b), base], check=True)
    append_row(b, "MyRow.swift", "this lane's own row")

    code, out = run_rehearse(shared, "t_ahead_b", "wt/ahead-b")
    check("case 5c: the rehearsal does not read another lane's row as this branch's loss",
          "A REGISTRY ROW THIS TREE WOULD LOSE" not in out, f"rc={code} tail={out[-500:]}")
    check("case 5d: the window it used is the branch's own starting point",
          "registry window" in out and base[:7] not in "", f"tail={out[-200:]}")
    # = = ⇒ THE REPLAY OF AN OLDER LANE ONTO A NEWER `main` LOSES THE NEWER ROW, =
    # = = = = and the guard is the thing that says so. = = A rehearsal that only
    # = = looked at the branch's own diff would call this clean, = = = = because B
    # = = never deleted anything: = = the row simply was not in B's tree, = = = = and
    # = = the replay writes B's tail over the newer one.
    code2, out2 = run_land(shared, "t_ahead_b", "wt/ahead-b")
    check("case 5e: a lane cut from an older main lands, because the replay loses nothing",
          code2 == 0 and "RESULT: LANDED" in out2, f"rc={code2}\n{out2[-900:]}")
    text2 = git(shared, "show", "main:docs/agents/nfi.md")
    check("case 5e-b: and BOTH rows are on main afterwards",
          "AheadLane.swift" in text2 and "MyRow.swift" in text2, text2[-400:])
    check("case 5e-c: and the guard asked the window it means",
          "registry window" in out2 and "unexplained 0" in out2, f"tail={out2[-400:]}")
    # = = ⇒ WHY THIS CASE EXISTS. = = The ticket it came from claimed a replay unmakes rows, =
    # = and the number behind that claim was `git diff main..HEAD` measured against a `main`
    # = that had moved on: = = a two-dot diff reads the newer `main`'s own rows as this branch's
    # = deletions. = = Re-deriving the lane commit by commit against its OWN parent found zero
    # = unlicensed losses = = and the same reading found the guard itself excusing fourteen rows
    # = it had mislabelled as deletions. = = This case is the proof that the window, not the
    # = replay, was the bug: = = with the merge-base asked, = = the ordinary lane lands.


def case_the_excuse_is_a_deleted_file(tmp: Path) -> None:
    """A row may disappear exactly once: its registered file disappears with it.

    Two halves, because the guard's excuse test was written as its loss test and the two sets are
    the same set: a lane that deletes the FILE and the row together is forgiven and lands, and a
    lane that deletes the row while the file stands is refused and names the row.
    """
    _remote, shared = make_repo(tmp)

    # half one: the file goes, so the row may go
    wt = lane(shared, tmp, "excuser")
    p = wt / "docs" / "agents" / "nfi.md"
    victim = "| `Seed.swift` | `SeedA.swift` | 10 | seed a |\n"
    if victim not in p.read_text(encoding="utf-8"):
        check("case 6: the fixture carries the row this case deletes", False, "no victim row")
        return
    p.write_text(p.read_text(encoding="utf-8").replace(victim, ""), encoding="utf-8")
    (wt / "SeedA.swift").unlink()
    git(wt, "add", "-A")
    git(wt, "commit", "-qm", "retire a registered file and its row together")
    rc, out = run_land(shared, "t_excuser", "wt/excuser")
    check("case 6: deleting a file and its row together is excused",
          "excused, its registered file is deleted by this change: `SeedA.swift`" in out,
          f"rc={rc} tail={out[-500:]}")
    check("case 6b: the excuse count is printed beside the loss count",
          "row(s) gone (excused 1, unexplained 0)" in out, f"tail={out[-260:]}")
    check("case 6c: and the landing proceeds", rc == 0 and "RESULT: LANDED" in out,
          f"rc={rc} tail={out[-250:]}")

    # half two: the row goes and the file stays = the refusal in case 2's shape,
    # but asked of a registry that has already lost one row legitimately
    _r2, shared2 = make_repo(tmp / "second")
    wt2 = lane(shared2, tmp / "second", "keeper2")
    p2 = wt2 / "docs" / "agents" / "nfi.md"
    p2.write_text(p2.read_text(encoding="utf-8").replace(
        "| `Seed.swift` | `SeedB.swift` | 20 | seed b |\n", ""), encoding="utf-8")
    git(wt2, "add", "-A")
    git(wt2, "commit", "-qm", "drop a row whose file still stands")
    main_before = git(shared2, "rev-parse", "main")
    rc2, out2 = run_land(shared2, "t_keeper2", "wt/keeper2")
    check("case 6d: a row dropped while its file stands is refused",
          rc2 == 26 and "A REGISTRY ROW THIS TREE WOULD LOSE: `SeedB.swift`" in out2,
          f"rc={rc2} tail={out2[-400:]}")
    check("case 6e: and main did not move", git(shared2, "rev-parse", "main") == main_before)


def case_two_lanes_both_rows_survive(tmp: Path) -> None:
    print("case 1: two lanes each append a row, and the second lands on top of the first")
    _remote, shared = make_repo(tmp)
    a = lane(shared, tmp, "keeper-a")
    append_row(a, "LaneA.swift", "lane a's own row")
    rc, out = run_land(shared, "t_keeper_a", "wt/keeper-a")
    check("case 1: the first lane landed", rc == 0 and "RESULT: LANDED" in out,
          f"rc={rc} tail={out[-400:]}")

    # = = the second lane is cut from the main that ALREADY carries the first row, which is
    # = = the situation the guard exists for; the first cut of this case cut it too early and
    # = = was asserting a merge that had not been set up.
    b = lane(shared, tmp, "keeper-b")
    append_row(b, "LaneB.swift", "lane b's own row")
    tip_b = git(b, "rev-parse", "wt/keeper-b")

    rc, out = run_land(shared, "t_keeper_b", "wt/keeper-b")
    text = git(shared, "show", "main:docs/agents/nfi.md")
    check("case 1: the second lane landed", rc == 0 and "RESULT: LANDED" in out,
          f"rc={rc} tail={out[-400:]}")
    check("case 1: BOTH lanes' rows survive on main",
          "LaneA.swift" in text and "LaneB.swift" in text, text[-300:])
    added, removed = registry_effect(shared, tip_b)
    check("case 1: the second landing's own effect on the registry is an append",
          removed == 0 and added == 1, f"+{added} / -{removed}")
    check("case 1: the guard had nothing to refuse", "REGISTRY_ROWS_LOST" not in out,
          f"tail={out[-300:]}")


def case_removing_a_foreign_row_is_refused(tmp: Path) -> None:
    print("case 2: a branch that deletes a row it never added is refused, by name")
    _remote, shared = make_repo(tmp)
    wt = lane(shared, tmp, "thief")
    p = wt / "docs" / "agents" / "nfi.md"
    kept = [ln for ln in p.read_text(encoding="utf-8").splitlines() if "SeedB.swift" not in ln]
    p.write_text("\n".join(kept) + "\n", encoding="utf-8")
    git(wt, "add", "docs/agents/nfi.md")
    git(wt, "commit", "-qm", "drop someone else's row")

    main_before = git(shared, "rev-parse", "main")
    rc, out = run_land(shared, "t_thief", "wt/thief")
    check("case 2: the landing refuses", rc == 26 and "REGISTRY_ROWS_LOST" in out,
          f"rc={rc} tail={out[-300:]}")
    check("case 2: the refusal NAMES the row it saved", "`SeedB.swift`" in out,
          f"tail={out[-400:]}")
    check("case 2: main did not move", git(shared, "rev-parse", "main") == main_before)


def case_rewriting_its_own_row_is_allowed(tmp: Path) -> None:
    print("case 3: a branch that rewrites the row it owns is allowed")
    _remote, shared = make_repo(tmp)
    a = lane(shared, tmp, "owner-a")
    append_row(a, "Renamed.swift", "the row lane a added")
    tip_a = git(a, "rev-parse", "wt/owner-a")
    git(shared, "merge", "-q", "--ff-only", tip_a)

    b = lane(shared, tmp, "owner-b")
    p = b / "docs" / "agents" / "nfi.md"
    text = p.read_text(encoding="utf-8").replace("| `Seed.swift` | `Renamed.swift` | 30 | the row lane a added |",
                                                 "| `Seed.swift` | `Renamed.swift` | 44 | same row, its LOC moved |")
    p.write_text(text, encoding="utf-8")
    git(b, "add", "docs/agents/nfi.md")
    git(b, "commit", "-qm", "rewrite the row this lane owns")
    rc, out = run_land(shared, "t_owner_b", "wt/owner-b")
    check("case 3: a rewrite of its own row is not a refusal",
          rc == 0 and "REGISTRY_ROWS_LOST" not in out, f"rc={rc} tail={out[-300:]}")
    check("case 3: the guard counts the gap it sees and explains it",
          "row(s) gone (excused " in out and "unexplained 0)" in out,
          f"tail={out[-400:]}")
    text = git(shared, "show", "main:docs/agents/nfi.md")
    check("case 3: the rewritten row is the one on main", "| 44 | same row, its LOC moved |" in text,
          text[-300:])


def case_rehearsal_refuses_the_same_thing(tmp: Path) -> None:
    print("case 4: --preflight-only refuses for the same reason and the same code")
    _remote, shared = make_repo(tmp)
    wt = lane(shared, tmp, "thief2")
    p = wt / "docs" / "agents" / "nfi.md"
    kept = [ln for ln in p.read_text(encoding="utf-8").splitlines() if "SeedA.swift" not in ln]
    p.write_text("\n".join(kept) + "\n", encoding="utf-8")
    git(wt, "add", "docs/agents/nfi.md")
    git(wt, "commit", "-qm", "drop someone else's row, again")

    env = {**os.environ, "LOGDIR": str(shared / ".gate-logs")}
    rep = subprocess.run(["bash", str(shared / "Scripts" / "land_card.sh"), "--preflight-only",
                          "t_thief2", "wt/thief2", "true"], capture_output=True, text=True,
                         cwd=str(shared), env=env)
    rout = rep.stdout + rep.stderr
    rc, out = run_land(shared, "t_thief2", "wt/thief2")
    r_line = next((l for l in rout.splitlines() if l.startswith("RESULT:")), rout[-200:])
    l_line = next((l for l in out.splitlines() if l.startswith("RESULT:")), out[-200:])
    check("case 4: the rehearsal refuses the foreign deletion",
          rep.returncode == 26 and "REGISTRY_ROWS_LOST" in rout,
          f"rc={rep.returncode} tail={rout[-300:]}")
    check("case 4: rehearsal and run refuse identically",
          (rep.returncode, r_line) == (rc, l_line),
          f"rehearsal=({rep.returncode},{r_line}) run=({rc},{l_line})")


def main() -> int:
    cases = (
        ("case 1 two lanes, both rows", case_two_lanes_both_rows_survive),
        ("case 2 a foreign row is protected", case_removing_a_foreign_row_is_refused),
        ("case 5 main ahead is not a row loss", case_main_ahead_is_not_a_row_loss),
        ("case 6 the excuse is a deleted file", case_the_excuse_is_a_deleted_file),
        ("case 3 its own row may be rewritten", case_rewriting_its_own_row_is_allowed),
        ("case 4 the rehearsal owes the same answer", case_rehearsal_refuses_the_same_thing),
    )
    for title, fn in cases:
        with tempfile.TemporaryDirectory() as td:
            try:
                fn(Path(td))
            except Exception as exc:
                check(f"{title}: the case ran at all", False, f"{type(exc).__name__}: {exc}")
    print(f"\n{'FAILURES: ' + str(len(FAILURES)) if FAILURES else 'all cases passed'}")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
