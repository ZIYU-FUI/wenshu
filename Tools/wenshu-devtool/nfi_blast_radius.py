#!/usr/bin/env python3
"""The blast radius of `nfi-loc-check`, measured at each branch's OWN tip.

= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
WHY THIS SCRIPT EXISTS (= = and what it refuses to do)
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

`nfi-loc-check.py` reads its SCOPE from `HEAD` (= = the diff it is asked
about) = = and its COUNTS from the WORKING TREE (= = `wc -l` of the file on
disk) = = and its REGISTRY from the repository directory it was pointed at.
= = ⇒ So a sweep that walks OTHER people's live worktrees measures their
UNCOMMITTED BUFFERS, = = and reports them as those branches' debt. = = That
is the same error class the gate's own scoping rule exists to end (= = main's
committed drift charged to a branch), = = one level down: = = a SIBLING's
uncommitted edit charged to the branch that hosts it.

= = ⇒ ⇒ ⇒ SO THIS SCRIPT MEASURES AT EACH BRANCH'S NAMED TIP SHA, IN A
CLEAN DETACHED WORKTREE, = = and it ASSERTS both facts before it reads a
single number:

  1. `git -C <wt> rev-parse HEAD` == the tip sha the row names, and
  2. `git -C <wt> status --porcelain` == 0 lines.

= = ⇒ A branch whose worktree is dirty is NOT measured from its worktree at
all; = = it is measured from a detached worktree at its tip, = = and the
dirty buffer is reported in its OWN column, labelled as not committed.

= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
USAGE
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    python3 Tools/wenshu-devtool/nfi_blast_radius.py --base <a-named-sha>
    python3 Tools/wenshu-devtool/nfi_blast_radius.py --base <a-named-sha> \\
        --json

= = ⇒ ⇒ **⇒ NAME THE BASE, = = DO NOT WRITE `origin/main`** (= = the branch
moves, = = and every number this script prints belongs to a snapshot): = = the
run prints its own `base = <sha>` and its own `measured at = <when>`, = = so
the table says which snapshot it is.

= = ⇒ It PRINTS the table and, on every red point, the branch and the tip it
was measured at (= = `### `<branch>` at <full tip sha>`, = = followed by the
point). = = ⇒ ⇒ **⇒ AND THE COMMAND THAT REPRODUCES A POINT** (= = the gate,
= = in that tree, = = against that base) = = = =
`python3 Tools/wenshu-devtool/nfi-loc-check.py --base <the sweep's base>`,
= = run in a detached worktree at that tip; = = the header above each point
names the branch and the tip, = = so the point is reproducible. = = ⇒ ⇒ **⇒ (At
this tree the sweep does NOT print the point's own gate command line by
line; = = it prints what the point is, = = where it is, = = and the base, = =
= = and this sentence is the promise the tool actually keeps.)**

= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
THE RULER INVARIANT (= = stated here because this is the file that enforces it)
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

**A sweep runs with ONE NAMED RULER, = = or it does not run at all.**

  • the ruler is `--gate <path>` when given (= = and the path MUST exist, = = or
    the run prints `NOT MEASURED: --gate names no readable file` and exits 2),
  • otherwise it is the gate BESIDE THIS SCRIPT (= = = = NOT the one in
    `--repo`'s tree, = = which is a DIFFERENT FILE whenever the sweep runs from a
    worktree, = = and measuring a lane with another tree's ruler is the silent
    false green this file was fixed for),
  • if THAT is missing too, = = the run prints `NOT MEASURED: this sweep has no
    ruler beside it` and exits 2 = = BEFORE it walks a single worktree.

**A measured tree is NOT required to carry its own gate.** = The sweep injects
the ruler it named, = = so a branch whose tip predates `nfi-loc-check.py` is
measured with the sweep's ruler (= = and the tree is left exactly as found: =
the injected file is removed, = = or the tree's own gate is restored).

= = ⇒ This is a CHANGE of invariant, = = made in round 8 and stated in round 10
= = because round 9 shipped it silently: = = the OLD rule was "a tree with no
= = gate is NOT MEASURED", = = and under injection that path can no longer be
= = reached by any command a person can type. = = The tree-level refusal still
= = exists inside `measure_at_tip` as the last line of defence for a caller that
= = hands it `gate=None` directly. = = Both are pinned by name in
= = `tests/test_nfi_blast_guards.py` (`G6` = = the `--gate` path, = = `G7` = = a
= = copy of this script with nothing beside it) = = and each arm is proven
= = load-bearing by the mutation log, = = never by this sentence.
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

# = = ⇒ ⇒ ⇒ THE DEFAULT REPO IS THIS SCRIPT'S OWN TREE, = = DERIVED FROM THE
# = = SCRIPT'S PATH. = = A hard-coded machine path (= = the main checkout)
# = = made the sweep measure OTHER lanes with THAT checkout's ruler, = = and
# = = that is a silent false green: = = the sweep printed a clean repo while
# = = measuring with a gate that is not the one shipping beside it.
REPO_DEFAULT = str(Path(__file__).resolve().parents[2])


def git(*args: str, cwd: str | None = None) -> str:
    r = subprocess.run(
        ["git", "-C", cwd or REPO_DEFAULT, *args],
        capture_output=True,
        text=True,
    )
    return r.stdout


def git_rc(*args: str, cwd: str | None = None) -> tuple[int, str, str]:
    r = subprocess.run(
        ["git", "-C", cwd or REPO_DEFAULT, *args],
        capture_output=True,
        text=True,
    )
    return r.returncode, r.stdout, r.stderr


@dataclass
class Branch:
    """One branch-backed worktree, with the tip sha it is measured at."""

    branch: str
    worktree: Path
    tip: str
    lane_buffer_dirty: int = 0
    lane_buffer_points: list[str] = field(default_factory=list)
    tip_points: list[str] = field(default_factory=list)
    tip_rc: int = 0
    measured: bool = False
    note: str = ""


def list_worktrees(repo: str) -> list[tuple[str, Path]]:
    out = git("worktree", "list", "--porcelain", cwd=repo)
    entries: list[tuple[str, Path]] = []
    cur: dict[str, str] = {}
    for line in out.splitlines():
        if not line.strip():
            if "worktree" in cur:
                entries.append((cur.get("branch", ""), Path(cur["worktree"])))
            cur = {}
            continue
        k, _, v = line.partition(" ")
        cur[k] = v
    if "worktree" in cur:
        entries.append((cur.get("branch", ""), Path(cur["worktree"])))
    return entries


def branch_name_of(porcelain_branch: str) -> str:
    return porcelain_branch.replace("refs/heads/", "")


def parse_gate_output(text: str) -> list[str]:
    """The gate's per-file failure lines (= = the red points)."""
    out = []
    for line in text.splitlines():
        m = re.match(r"^\s{2}(\S+): the row says (\d+), the file is (\d+)", line)
        if m:
            out.append(f"{m.group(1)} {m.group(2)}->{m.group(3)}")
    return out


def run_gate_at(
    repo: str,
    wt: Path,
    base: str,
    gate: Path | None = None,
) -> tuple[int, str]:
    """Run the gate IN this tree.

    = = `gate` = = a gate file to INJECT (= = the sweep's own gate), = = so
    = = every branch is measured with the SAME ruler. = = Without it, = =
    = each branch would be measured with the gate ITS OWN tree carries
    = = (= = an old added-only gate), = = and the sweep would compare
    = = different rulers. = = ⇒ ⇒ ⇒ So the injection is the default, = =
    = and a branch WITHOUT a gate = = = = no measurement at all.
    """
    dest = Path(wt) / "Tools/wenshu-devtool/nfi-loc-check.py"
    injected = False
    saved: bytes | None = None
    # = = ⇒ ⇒ ⇒ THE TREE MUST COME BACK EXACTLY AS IT WAS FOUND, = = AND A
    # = = DIRECTORY THE SWEEP CREATED IS PART OF "AS IT WAS FOUND": = = so
    # = = remember whether the directory existed, = = and remove it again if
    # = = the sweep made it.
    made_parent = False
    if gate is not None:
        if not dest.parent.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            made_parent = True
        if dest.exists() and dest.resolve() == gate.resolve():
            # = = The tree already carries THIS gate: = = nothing to inject
            # = = and nothing to restore.
            pass
        else:
            if dest.exists():
                # = = The tree's OWN gate is saved, = = because the sweep must
                # = = NOT leave the tree changed: = = the live worktree belongs
                # = = to another lane, = = and deleting its gate would break it.
                saved = dest.read_bytes()
            shutil.copyfile(gate, dest)
            injected = True
    elif not dest.exists():
        # = = A MISSING GATE IS NOT A GREEN GATE. = = Measuring a tree with
        # = = no gate in it would report "0 red points" for every branch,
        # = = and that reads like a clean sweep. = = So it is an ERROR.
        return 2, f"the gate is not in this tree: {dest}"
    r = subprocess.run(
        ["python3", str(dest), "--base", base],
        capture_output=True,
        text=True,
        cwd=str(wt),
    )
    if injected:
        # = = The tree must be left EXACTLY as it was found: = = the injected
        # = = gate is removed (or the tree's own gate is put back), = = so
        # = = a detached worktree stays clean = = and another lane's LIVE
        # = = worktree keeps the gate it had.
        try:
            if saved is None:
                dest.unlink()
            else:
                dest.write_bytes(saved)
            if made_parent:
                # = = The directory the sweep made, = = and nothing else in
                # = = it (= = the gate is already gone), = = so it goes too.
                try:
                    dest.parent.rmdir()
                except OSError:
                    pass
        except OSError:
            pass
    return r.returncode, r.stdout + r.stderr


def collect(repo: str, base: str, only: list[str] | None) -> list[Branch]:
    rows: list[Branch] = []
    for porcelain_branch, wt in list_worktrees(repo):
        branch = branch_name_of(porcelain_branch)
        if not branch:
            # a detached worktree: not branch-backed, so not a branch's debt
            continue
        if only and not any(o in branch for o in only):
            continue
        rc, out, _ = git_rc("rev-parse", "HEAD", cwd=str(wt))
        if rc != 0:
            continue
        tip = out.strip()
        rc, status, _ = git_rc("status", "--porcelain", cwd=str(wt))
        rows.append(
            Branch(
                branch=branch,
                worktree=wt,
                tip=tip,
                lane_buffer_dirty=len([x for x in status.splitlines() if x.strip()]),
            )
        )
    return rows


def measure_at_tip(
    repo: str,
    b: Branch,
    base: str,
    keep: Path,
    gate: Path | None = None,
) -> None:
    """Measure b at its OWN tip sha, in a CLEAN DETACHED worktree."""
    wt = Path(tempfile.mkdtemp(prefix="blast-", dir=str(keep)))
    target = wt / "wt"
    rc, _, err = git_rc(
        "worktree", "add", "--detach", str(target), b.tip, cwd=repo
    )
    if rc != 0:
        b.note = f"could not add a detached worktree: {err.strip()[:120]}"
        return
    try:
        _, head, _ = git_rc("rev-parse", "HEAD", cwd=str(target))
        head = head.strip()
        _, status, _ = git_rc("status", "--porcelain", cwd=str(target))
        if head != b.tip:
            b.note = f"HEAD is {head[:12]}, expected {b.tip[:12]}"
            return
        if status.strip():
            b.note = "the detached worktree was not clean"
            return
        rc, out = run_gate_at(repo, target, base, gate)
        if rc == 2:
            # = = The gate is not in this tree (= = an old branch, = = or a
            # = = tree that predates the tool). = = That is NOT a green
            # = = measurement, = = it is no measurement at all.
            b.note = f"no gate in this tree: {out.strip()[:160]}"
            return
        b.tip_rc = rc
        b.tip_points = parse_gate_output(out)
        b.measured = True
    finally:
        git_rc("worktree", "remove", "--force", str(target), cwd=repo)
        try:
            os.rmdir(wt)
        except OSError:
            pass


def measure_lane_buffer(
    b: Branch,
    base: str,
    repo: str,
    gate: Path | None = None,
) -> None:
    """What the LIVE worktree says (= = NOT committed; = = its own column)."""
    rc, out = run_gate_at(repo, b.worktree, base, gate)
    b.lane_buffer_points = parse_gate_output(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--base",
        required=True,
        help=(
            "the sha the blast radius is measured against (= = NAME IT: = = "
            "every number this script prints belongs to a snapshot, = = and "
            "`origin/main` moves under the reader's feet)"
        ),
    )
    ap.add_argument("--repo", default=REPO_DEFAULT)
    ap.add_argument("--only", action="append", default=[])
    ap.add_argument(
        "--gate",
        default=None,
        help=(
            "the gate file to INJECT into every measured tree (= = the "
            "sweep's own gate, = = so every branch is measured with the "
            "SAME ruler); = = default: = = this script's own tree's gate"
        ),
    )
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    repo = args.repo
    base_sha = git("rev-parse", args.base, cwd=repo).strip()
    rows = collect(repo, args.base, args.only)

    # = = ⇒ ⇒ ⇒ **THE INVARIANT, = = STATED WHERE IT IS ENFORCED**: = = a sweep
    # = = runs with ONE NAMED RULER, = = or it does not run at all. = = The
    # = = ruler is `--gate` when given, = = and otherwise the gate BESIDE THIS
    # = = SCRIPT ( = = never `--repo`'s tree's, = = which is a different file
    # = = whenever the sweep runs from a worktree, = = and measuring a lane
    # = = with another tree's ruler is a SILENT FALSE GREEN). = = A MEASURED
    # = = TREE IS NOT REQUIRED TO CARRY ITS OWN GATE: = = the sweep injects
    # = = the ruler it named, = = and a tree that had none is measured with
    # = = that injected ruler.
    # = =
    # = = Round 8 moved the "no gate" refusal from the TREE to here, = = and
    # = = round 9 was asked to say so out loud rather than leave the old suite
    # = = pinning a path that can no longer be reached. = = The refusal inside
    # = = `measure_at_tip` stays as the last line of defence for any caller
    # = = that hands it `gate=None` directly; = = the run a person can type
    # = = refuses BEFORE it walks a single worktree, = = which is where a
    # = = false green would otherwise be printed. = = Both are pinned in
    # = = `tests/test_nfi_blast_guards.py` ( = = `G6` names `--gate` missing,
    # = = `G7` runs a copy of this script with no gate beside it).
    if args.gate:
        gate = Path(args.gate).resolve()
        if not gate.is_file():
            print(f"NOT MEASURED: --gate names no readable file: {gate}")
            return 2
    else:
        gate = Path(__file__).resolve().parent / "nfi-loc-check.py"
        if not gate.is_file():
            print(f"NOT MEASURED: this sweep has no ruler beside it: {gate}")
            return 2
    gate_blob = subprocess.run(
        ["git", "hash-object", str(gate)], capture_output=True, text=True
    ).stdout.strip()

    keep = Path(tempfile.mkdtemp(prefix="nfi-blast-", dir="/tmp"))
    try:
        for b in rows:
            measure_at_tip(repo, b, base_sha, keep, gate)
            if b.lane_buffer_dirty:
                measure_lane_buffer(b, base_sha, repo, gate)
    finally:
        subprocess.run(["rm", "-rf", str(keep)], check=False)

    measured = [b for b in rows if b.measured]
    red = [b for b in measured if b.tip_points]
    green = [b for b in measured if not b.tip_points]

    if args.json:
        print(json.dumps({
            "base": base_sha,
            "gate": {"path": str(gate) if gate else None, "blob": gate_blob},
            "branches_measured": len(measured),
            "red_branches": len(red),
            "green_branches": len(green),
            "red_points": sum(len(b.tip_points) for b in red),
            "rows": [
                {
                    "branch": b.branch,
                    "tip": b.tip,
                    "tip_rc": b.tip_rc,
                    "tip_points": b.tip_points,
                    "lane_buffer_dirty": b.lane_buffer_dirty,
                    "lane_buffer_points": b.lane_buffer_points,
                    "note": b.note,
                }
                for b in rows
            ],
        }, indent=2))
        return 0

    print(f"base = {base_sha}")
    print(f"gate = {gate if gate else '(no gate)'} {gate_blob}".rstrip())
    print(f"measured at = {time.strftime('%Y-%m-%d %H:%M:%S %z')}")
    print(f"branch-backed worktrees measured = {len(measured)} "
          f"(green {len(green)}, red {len(red)})")
    print(f"red points = {sum(len(b.tip_points) for b in red)}")
    print()
    print("| branch | tip | red points at tip | lane buffer dirty | lane buffer points (NOT committed) |")
    print("| ------ | --- | ------------------ | ----------------- | ---------------------------------------- |")
    for b in sorted(rows, key=lambda x: (not x.tip_points, x.branch)):
        if not b.measured:
            print(f"| `{b.branch}` | {b.tip[:9]} | NOT MEASURED: {b.note} | {b.lane_buffer_dirty} | - |")
            continue
        print(f"| `{b.branch}` | {b.tip[:9]} | {len(b.tip_points)} | {b.lane_buffer_dirty} | "
              f"{'; '.join(b.lane_buffer_points) if b.lane_buffer_points else '-'} |")
    print()
    for b in red:
        print(f"### `{b.branch}` at {b.tip}")
        for p in b.tip_points:
            print(f"    {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
