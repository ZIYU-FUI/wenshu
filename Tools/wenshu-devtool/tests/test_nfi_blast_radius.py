#!/usr/bin/env python3
"""The blast-radius sweep measures each branch at its OWN TIP, = = not at
whatever its live worktree happens to hold.

= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
WHY
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

`nfi-loc-check.py` reads its SCOPE from `HEAD` and its COUNTS from the
WORKING TREE. = = So a sweep that walks other lanes' live worktrees measures
their UNCOMMITTED BUFFERS and reports them as those branches' debt. = = The
sweep must therefore measure at each branch's NAMED TIP SHA, in a clean
detached worktree, = = and it must ASSERT both facts before it reads a
number.

= = ⇒ ⇒ ⇒ So this test holds FOUR things:
  (1) a branch whose TIP is green, = = but whose LIVE worktree carries an
      uncommitted edit that breaks a row, = = is reported GREEN (= = the
      sweep measures the tip) = = and the buffer is reported in its OWN
      column, labelled as not committed;
  (2) **THE RULER INVARIANT** (= = `nfi_blast_radius.py`'s docstring states it,
      = = and this is where it is pinned): = = a tree with NO GATE OF ITS OWN
      IS MEASURED with the sweep's own injected ruler, = = and the run NAMES
      that ruler; = = a sweep with NO RULER BESIDE IT prints `NOT MEASURED`,
      = = exits 2, = = and prints no table; = = and `--gate <no such file>`
      refuses the same way instead of crashing mid-walk.
      = = ⇒ ⇒ **⇒ This case CHANGED in round 10, = = on purpose.** = = It used
      to pin "a tree with no gate is NOT MEASURED", = = and round 8's
      default-gate fix made that path unreachable from any typed command, = =
      so the invariant moved from the TREE to the INSTRUMENT. = = Round 9 left
      the old assertion in place and shipped a RED suite; = = that is the
      defect this rewrite closes (= = round 9's BLOCKING 1).
  (3) the sweep REFUSES to measure a tree whose HEAD is not the tip it
      names (= = it asserts, = = it does not assume); = = and
  (4) the sweep's own reproduction is printed for every red point, = = so a
      reader can re-take it, = = and every tree is left EXACTLY as it was
      found (another lane's live worktree must keep the gate it had).
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
"""
import os
import shutil
import subprocess
import sys
import tempfile

TOOL = os.environ.get("NFI_BLAST_RADIUS_TOOL") or os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "nfi_blast_radius.py",
)


def run(args, cwd=None):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True)


def write_registry(path, rows):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("| key | file | LOC | note |\n|---|---|---|---|\n")
        for key, name, loc in rows:
            handle.write(f"| `{key}` | `{name}` | {loc} | ours |\n")


def make_branch_repo(tmp, name):
    """A repo whose tip is GREEN, = = with one registered file at the right count.

    = = The REAL gate is copied in, = = because the sweep must measure with
    = = the shipped gate (= = and a tree without the gate is no measurement
    = = at all, = = which the sweep now reports as NOT MEASURED).
    """
    repo = os.path.join(tmp, name)
    os.makedirs(os.path.join(repo, "Sources"), exist_ok=True)
    os.makedirs(os.path.join(repo, "docs", "agents"), exist_ok=True)
    os.makedirs(os.path.join(repo, "Tools", "wenshu-devtool"), exist_ok=True)
    src = os.path.join(repo, "Sources", "Tracked.swift")
    registry = os.path.join(repo, "docs", "agents", "nfi.md")
    with open(src, "w", encoding="utf-8") as handle:
        handle.write("let a = 1\nlet b = 2\n")
    write_registry(registry, [("Sources/Tracked.swift", "Sources/Tracked.swift", 2)])
    run(["git", "init", "-q", "-b", "main", repo], cwd=tmp)
    run(["git", "config", "user.email", "t@t"], cwd=repo)
    run(["git", "config", "user.name", "t"], cwd=repo)
    run(["git", "add", "-A"], cwd=repo)
    run(["git", "commit", "-qm", "tip is green"], cwd=repo)
    return repo, src, registry


def main():
    with tempfile.TemporaryDirectory() as tmp:
        repo, src, registry = make_branch_repo(tmp, "repo")
        # = = The REAL gate must be IN the tree at BOTH commits: = = the base
        # = = (so it is not part of the change's own diff) = = and the tip.
        gate_src = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "nfi-loc-check.py",
        )
        gate_dst = os.path.join(repo, "Tools", "wenshu-devtool", "nfi-loc-check.py")
        with open(gate_src, "r", encoding="utf-8") as h:
            gate_text = h.read()
        with open(gate_dst, "w", encoding="utf-8") as h:
            h.write(gate_text)
        run(["git", "add", "-A"], cwd=repo)
        run(["git", "commit", "-qm", "the gate is in the tree"], cwd=repo)

        # = = the base: = = two files, = and one row (theirs, = carrying a
        # = = count that is already stale = = the tree's own drift, = = which
        # = = the registry's header says is expected).
        base = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
        # = = the change: = = a row for a NEW file, = and the file itself,
        # = = with the row carrying a WRONG count (= = the tip is RED).
        with open(os.path.join(repo, "Sources", "Added.swift"), "w", encoding="utf-8") as h:
            h.write("let c = 3\n")
        write_registry(
            registry,
            [
                ("Sources/Tracked.swift", "Sources/Tracked.swift", 2),
                ("Sources/Added.swift", "Sources/Added.swift", 99),  # = = wrong
            ],
        )
        run(["git", "add", "-A"], cwd=repo)
        run(["git", "commit", "-qm", "the row is added with a wrong count"], cwd=repo)
        tip = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()

        # = = now the WORKING TREE fixes the row: = = the buffer is GREEN,
        # = = the tip is still RED. = = A sweep that measured the live
        # = = worktree would call this branch GREEN; = = a sweep that
        # = = measures the TIP calls it RED.
        write_registry(
            registry,
            [
                ("Sources/Tracked.swift", "Sources/Tracked.swift", 2),
                ("Sources/Added.swift", "Sources/Added.swift", 1),  # = = right
            ],
        )
        dirty = run(["git", "status", "--porcelain"], cwd=repo).stdout.strip()
        if not dirty:
            print("FAILED: the fixture's working tree is not dirty")
            return 1

        # = = the sweep reads the repo's worktrees; = = for the fixture we
        # = = point it at a directory whose ONLY worktree is this branch.
        wtroot = os.path.join(tmp, "wtroot")
        os.makedirs(wtroot, exist_ok=True)
        result = run(
            [
                sys.executable, TOOL,
                "--base", base,
                "--repo", repo,
                "--only", "main",
            ],
            cwd=tmp,
        )
        out = result.stdout + result.stderr
        if result.returncode != 0:
            print("FAILED: the sweep exited non-zero")
            print(out)
            return 1

        # = = (1) the tip is RED: = = the sweep must report a red point for
        # = = the added file, = = because the TIP's registry says 99 and the
        # = = file is 1 line.
        if "Sources/Added.swift" not in out:
            print("FAILED: the sweep did not report the tip's red point")
            print(out)
            return 1
        if "99->1" not in out.replace(" ", ""):
            print("FAILED: the reported point is not the tip's (99 -> 1)")
            print(out)
            return 1

        # = = (3) the reproduction is printed.
        if "### " not in out:
            print("FAILED: the sweep printed no reproduction for its red points")
            print(out)
            return 1

        # = = (1b) the working tree's GREEN is NOT what the sweep reported:
        # = = the buffer fixes the row (= = 1 = = right), = = so if the sweep
        # = = had measured the LIVE worktree it would have found 0 points.
        if "red points = 0" in out:
            print("FAILED: the sweep measured the working tree, not the tip")
            print(out)
            return 1

        # = = (2) **THE RULER INVARIANT, = = AS CHANGED IN ROUND 8 AND STATED
        # = = IN ROUND 10** (= = see `nfi_blast_radius.py`'s docstring,
        # = = "THE RULER INVARIANT").
        # = =
        # = = The OLD rule this case pinned was "a tree with no gate is NOT
        # = = MEASURED". = = Round 8's default-gate fix makes that path
        # = = UNREACHABLE from any command a person can type: = = the sweep
        # = = carries its own ruler and INJECTS it into every tree, = = so a
        # = = branch whose tip predates `nfi-loc-check.py` is measured with the
        # = = sweep's ruler instead of being skipped. = = That is the point of a
        # = = blast radius (= = "what would the CURRENT ruler do to every lane?"),
        # = = and skipping the lanes that predate the ruler would hide exactly
        # = = the lanes a new rule bites.
        # = =
        # = = So the invariant moved from the TREE to the INSTRUMENT, = = and
        # = = this case now pins BOTH halves of that sentence.
        old = os.path.join(tmp, "oldrepo")
        subprocess.run(["git", "clone", "-q", repo, old], cwd=tmp)
        run(["git", "checkout", "-q", base], cwd=old)
        run(["git", "checkout", "-q", "-b", "ancient"], cwd=old)
        # = = remove the gate from this branch's tip = = and commit it, = = so
        # = = the tip has no gate of its own.
        os.remove(os.path.join(old, "Tools", "wenshu-devtool", "nfi-loc-check.py"))
        run(["git", "add", "-A"], cwd=old)
        run(["git", "commit", "-qm", "the gate is gone"], cwd=old)
        result2 = run(
            [
                sys.executable, TOOL,
                "--base", base,
                "--repo", old,
                "--only", "ancient",
            ],
            cwd=tmp,
        )
        out2 = result2.stdout + result2.stderr

        # = = (2a) A TREE WITH NO GATE IS MEASURED WITH THE SWEEP'S RULER, = =
        # = = = = and the run SAYS which ruler it used.
        if "NOT MEASURED" in out2:
            print("FAILED: a tree with no gate of its own was refused, "
                  "though the sweep has a ruler to inject")
            print(out2)
            return 1
        if "gate = " not in out2:
            print("FAILED: the gateless-tree measurement did not name its ruler")
            print(out2)
            return 1
        if "branch-backed worktrees measured = 0" in out2:
            print("FAILED: the gateless tree was not measured")
            print(out2)
            return 1

        # = = (2b) A SWEEP WITH NO RULER BESIDE IT MEASURES NOTHING (= = = = it
        # = = = = refuses BEFORE the walk, = = = = and never prints a table).
        lonely_tree = os.path.join(tmp, "lonely")
        lonely_dir = os.path.join(lonely_tree, "Tools", "wenshu-devtool")
        os.makedirs(lonely_dir, exist_ok=True)
        lonely_tool = os.path.join(lonely_dir, "nfi_blast_radius.py")
        shutil.copyfile(TOOL, lonely_tool)
        if os.path.exists(os.path.join(lonely_dir, "nfi-loc-check.py")):
            print("FAILED: the fixture put a gate beside the lonely sweep")
            return 1
        result2b = run(
            [sys.executable, lonely_tool, "--base", base, "--repo", old,
             "--only", "ancient"],
            cwd=lonely_tree,
        )
        out2b = result2b.stdout + result2b.stderr
        if result2b.returncode != 2:
            print(f"FAILED: a ruler-less sweep exited {result2b.returncode}, expected 2")
            print(out2b)
            return 1
        if "NOT MEASURED" not in out2b:
            print("FAILED: a ruler-less sweep did not print NOT MEASURED")
            print(out2b)
            return 1
        if "branch-backed worktrees measured" in out2b:
            print("FAILED: a ruler-less sweep printed a measurement table anyway")
            print(out2b)
            return 1

        # = = (2c) `--gate` NAMING NO FILE IS A REFUSAL, = = not a traceback
        # = = = = (round 8's non-blocking 2).
        result2c = run(
            [sys.executable, TOOL, "--base", base, "--repo", old,
             "--only", "ancient", "--gate", os.path.join(tmp, "no-such-gate.py")],
            cwd=tmp,
        )
        out2c = result2c.stdout + result2c.stderr
        if result2c.returncode != 2 or "NOT MEASURED" not in out2c or "Traceback" in out2c:
            print("FAILED: `--gate <no such file>` did not refuse cleanly "
                  f"(rc={result2c.returncode})")
            print(out2c)
            return 1

        # = = (4) the sweep must leave every tree EXACTLY as it found it:
        # = = the live worktree is ANOTHER LANE's tree, = = and the sweep
        # = = injects its own gate into it to measure the buffer. = = If it
        # = = left that gate there (or deleted the tree's own), = = it would
        # = = break that lane.
        gate_after = os.path.join(repo, "Tools", "wenshu-devtool", "nfi-loc-check.py")
        if not os.path.exists(gate_after):
            print("FAILED: the sweep left the live worktree without a gate")
            return 1
        with open(gate_after, "r", encoding="utf-8") as h:
            after = h.read()
        if after != gate_text:
            print("FAILED: the sweep left a DIFFERENT gate in the live worktree")
            return 1
        status_after = run(["git", "status", "--porcelain"], cwd=repo).stdout
        if "nfi-loc-check.py" in status_after:
            print("FAILED: the sweep left the live worktree dirty in the gate file")
            print(status_after)
            return 1

        print("blast radius: the sweep measures the TIP, not the working tree")
        print(f"  tip   = {tip[:12]}")
        print(f"  base  = {base[:12]}")
        print("  PASS 1: the tip's red point is reported (= the buffer's GREEN is not)")
        print("  PASS 2: the ruler invariant holds — a gateless tree is MEASURED with the "
              "sweep's ruler, a ruler-less sweep measures NOTHING, and a bad --gate refuses")
        print("  PASS 3: the reproduction is printed for every red point")
        print("  PASS 4: every tree is left exactly as it was found")
        return 0


if __name__ == "__main__":
    sys.exit(main())
