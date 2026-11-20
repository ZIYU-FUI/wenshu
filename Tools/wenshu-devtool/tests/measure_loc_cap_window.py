#!/usr/bin/env python3
"""measure_loc_cap_window.py — replay the loc-cap check over a window of commits.

WHY THIS EXISTS. `ci_change_gate.py --check loc-cap` reports a number in its
own docstring (17 reds over main's last 300 commits, and a STATE check's 20),
and AGENTS.md 10 says a number in a document must be checkable. This file is
the instrument that produced it, = so a reviewer re-runs the measurement
instead of trusting the prose.

It drives THE GATE'S OWN functions (`changed_paths`, `loc_cap_offenders`,
`swift_loc`) — never a re-implementation — so what it counts is the instrument
that lands. It runs in a throwaway `--shared` clone and checks each commit out
detached there, because the gate reads blobs at HEAD and the replay must not
move the real working tree (= other cards' worktrees are live off it).

It reports BOTH arms of the design question, = the same pair the
markdown-newline check reports for its own rule:
  * the RATCHET's reds (= the check as written: a shrinking over-cap file lands)
  * the STATE's reds   (= the counterfactual: any touched file over 600 is red)
and the files the window touches while over the cap, with a commit count each,
= which is the backlog's real cost, not an estimate.

Run:
    python3 Tools/wenshu-devtool/tests/measure_loc_cap_window.py --n 300
    python3 Tools/wenshu-devtool/tests/measure_loc_cap_window.py --ref main --n 100
Exit: 0 always (= a measurement, not a gate); the report is the result.
"""
from __future__ import annotations

import argparse
import importlib.util
import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "ci_change_gate.py"

spec = importlib.util.spec_from_file_location("ci_change_gate", TOOL)
assert spec is not None and spec.loader is not None
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def git(args: list[str], cwd: Path) -> str:
    return subprocess.run(
        ["git", *args], cwd=str(cwd), capture_output=True, text=True, check=True
    ).stdout


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=None, help="the repository to replay (= default: cwd)")
    parser.add_argument("--ref", default="main", help="the branch whose history is replayed")
    parser.add_argument("--n", type=int, default=300, help="how many commits to replay")
    parser.add_argument(
        "--clone",
        default=None,
        help="where to build the throwaway clone (= default: a temp dir, removed after)",
    )
    args = parser.parse_args(argv if argv is not None else sys.argv[1:])

    src = Path(args.repo).resolve() if args.repo else Path(git(["rev-parse", "--show-toplevel"], Path.cwd())).resolve()
    shas = git(["log", "--format=%H", "-n", str(args.n), args.ref], src).split()

    if args.clone:
        clone, keep = Path(args.clone), True
        if not (clone / ".git").exists():
            clone.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(
                ["git", "clone", "--shared", "--no-checkout", str(src), str(clone)],
                check=True,
                capture_output=True,
            )
    else:
        clone, keep = Path(tempfile.mkdtemp(prefix="loc-cap-window-")), False

    try:
        ratchet_red: list[tuple[str, list[tuple[str, int, int | None]], list[str]]] = []
        excused: list[tuple[str, list[tuple[str, int]]]] = []
        greens = swift_window = 0
        touched_over: Counter[str] = Counter()
        for sha in shas:
            git(["checkout", "-q", "--detach", sha], clone)
            base = f"{sha}^"
            try:
                paths = gate.changed_paths(base, clone)
            except subprocess.CalledProcessError:
                continue  # a root commit in the window has no parent to diff against
            swift = [p for p in paths if p.endswith(gate.SWIFT_SUFFIX)]
            if not swift:
                continue
            swift_window += 1
            offenders, shrinking, unmeasurable = gate.loc_cap_offenders(base, swift, clone)
            for path in swift:
                size = gate.swift_loc("HEAD", path, clone)
                if size is not None and size > gate.LOC_CAP:
                    touched_over[path] += 1
            if offenders or unmeasurable:
                ratchet_red.append((sha, offenders, unmeasurable))
            elif shrinking:
                excused.append((sha, [(p, b) for p, b, _ in shrinking]))
            else:
                greens += 1

        print(f"window: {args.ref}'s last {len(shas)} commits; {swift_window} touched a .swift file")
        print(f"RATCHET reds (the check as landed): {len(ratchet_red)}")
        for sha, offenders, unmeasurable in ratchet_red:
            detail = "; ".join(
                f"{p}={head} (base={base if base is not None else 'NEW'})"
                for p, head, base in offenders
            )
            print(f"  {sha[:10]}: {detail}" + (f" UNMEASURABLE={unmeasurable}" if unmeasurable else ""))
        print(f"excused by the ratchet (over the cap but SHRANK): {len(excused)}")
        for sha, shrunk in excused:
            print(f"  {sha[:10]}: " + "; ".join(f"{p} was {b} LOC at the base" for p, b in shrunk))
        print(
            f"STATE reds (the counterfactual, = offenders + excused): "
            f"{len(ratchet_red) + len(excused)}"
        )
        print(f"greens: {greens}")
        print("files the window touches while over the cap (commits -> path):")
        for path, count in touched_over.most_common():
            print(f"  {count:>3}  {path}")
        return 0
    finally:
        if not keep:
            shutil.rmtree(clone, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
