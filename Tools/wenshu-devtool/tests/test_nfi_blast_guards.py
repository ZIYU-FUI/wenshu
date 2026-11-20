#!/usr/bin/env python3
"""The blast-radius sweep's GUARDS, tested where they can actually fail.

= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
WHY THIS FILE EXISTS
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

`tests/test_nfi_blast_radius.py` proves the sweep measures a TIP. = = But it
CANNOT prove the sweep's three GUARDS hold, = = and the round-3 review found
why (= = measured, not argued): = = that file has **no `--gate` argument
anywhere** (`grep -c -- '--gate'` on it = = 0), = = so it runs the sweep on the
default gate, = = which resolves to the very file being injected (= = the
bytes already equal), = = so `injected` is ALWAYS False there, = = so the
restore branch (= = the `if injected:` guard) is NEVER entered, = = and the
two refusals (= = the `if head != b.tip:` guard, = = and the `if
status.strip():` guard) are never reached. = = ⇒ ⇒ ⇒ ⇒ ⇒ ⇒ **⇒ ⇒ AND THE
GUARDS ARE NAMED, = = NOT NUMBERED**: = = a line number moves the moment
anything is inserted above it, = = and round 4's own edit moved four of them
(= = 165 / 225 / 228 / 242 became 166 / 226 / 229 / 243). = = ⇒ ⇒ ⇒ Three mutations of the guards = = = `if injected:` -> `if
injected and False:`, = = `if head != b.tip:` -> `if False:`, = = `if
status.strip():` -> `if False:` = = = = all leave that suite rc=0.

= = ⇒ ⇒ ⇒ So THIS file tests each guard DIRECTLY, = = and each test asserts
the guard's REFUSAL, = = so a mutation that removes the guard makes the test
fail. = = ⇒ ⇒ ⇒ And the three refusals are NOT reachable through the CLI
alone (= = the sweep builds its own detached worktree, = = so its HEAD is its
tip by construction): = = ⇒ ⇒ ⇒ ⇒ **⇒ the two refusal guards are tested by
injecting the fault the guard exists to catch** (= = `git_rc` is the one
chokepoint through which the sweep learns HEAD and cleanliness), = = and the
injection/restore guard is tested through the CLI, = = with a `--gate` whose
bytes DIFFER from the lane's own (= = so the injection really happens).

= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
THE THREE GUARDS, AND WHAT EACH TEST ASSERTS
= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

  G1  the injection/restore (= = the `if injected:` guard) = = the sweep puts the injected gate
      back (= = the tree's own bytes, = = or nothing at all). = = A test that
      only ever injects the SAME bytes can never see a clobber, = = so this
      test uses a `--gate` whose bytes DIFFER from the lane's tracked gate,
      and asserts afterwards that the lane's gate bytes and
      `status --porcelain` are EXACTLY as they were.
  G2  the HEAD refusal (= = the `if head != b.tip:` guard) = = a detached worktree whose HEAD is not the
      tip it names is NOT MEASURED.
  G3  the cleanliness refusal (= = the `if status.strip():` guard) = = a detached worktree that is not
      clean is NOT MEASURED.

= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
"""
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = os.environ.get("NFI_BLAST_RADIUS_TOOL") or str(
    HERE.parent / "nfi_blast_radius.py"
)


def load_tool():
    """Import the sweep as a module (= = so its internals can be driven)."""
    spec = importlib.util.spec_from_file_location("nfi_blast_radius", TOOL)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load the sweep from {TOOL}")
    module = importlib.util.module_from_spec(spec)
    # = = The dataclass machinery looks the class up in sys.modules, = = so the
    # = = module must be REGISTERED before it is executed.
    sys.modules["nfi_blast_radius"] = module
    spec.loader.exec_module(module)
    return module


def run(args, cwd=None):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True)


def make_repo(tmp, name, with_gate_dir=True):
    """A repo with a tracked gate, a registry, and one green tip.

    = = `with_gate_dir=False` builds a tree that has NO
    = = `Tools/wenshu-devtool/` at all, = = which is what G4 needs (= = the
    = = sweep then MAKES that directory when it injects the gate).
    """
    repo = os.path.join(tmp, name)
    if with_gate_dir:
        os.makedirs(os.path.join(repo, "Tools", "wenshu-devtool"), exist_ok=True)
    os.makedirs(os.path.join(repo, "docs", "agents"), exist_ok=True)
    os.makedirs(os.path.join(repo, "Sources"), exist_ok=True)
    with open(os.path.join(repo, "Sources", "Tracked.swift"), "w", encoding="utf-8") as h:
        h.write("let a = 1\n")
    with open(os.path.join(repo, "docs", "agents", "nfi.md"), "w", encoding="utf-8") as h:
        h.write("| key | file | LOC |\n|---|---|---|\n")
    run(["git", "init", "-q", "-b", "main", repo], cwd=tmp)
    run(["git", "config", "user.email", "t@t"], cwd=repo)
    run(["git", "config", "user.name", "t"], cwd=repo)
    run(["git", "add", "-A"], cwd=repo)
    run(["git", "commit", "-qm", "the tip"], cwd=repo)
    return repo


def case_g1_injection_restore(tool, tmp):
    """G1: a --gate whose bytes DIFFER must be put back, byte for byte."""
    repo = make_repo(tmp, "g1repo")
    lane_gate = os.path.join(repo, "Tools", "wenshu-devtool", "nfi-loc-check.py")
    # = = The lane tracks its OWN gate, whose bytes are NOT the sweep's gate.
    lane_text = "# the lane's own gate\nprint('lane')\n"
    with open(lane_gate, "w", encoding="utf-8") as h:
        h.write(lane_text)
    run(["git", "add", "-A"], cwd=repo)
    run(["git", "commit", "-qm", "the lane has its own gate"], cwd=repo)
    tip = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()

    # = = A gate whose bytes DIFFER from the lane's.
    other_gate = os.path.join(tmp, "other-gate.py")
    with open(other_gate, "w", encoding="utf-8") as h:
        h.write("# a DIFFERENT gate\nprint('other')\n")

    # = = ⇒ ⇒ ⇒ THE LANE MUST BE DIRTY, = = or the sweep never measures the
    # = = lane's BUFFER (= = `measure_lane_buffer` runs only for a dirty
    # = = lane), = = and so it never injects into the lane at all = = = = which
    # = = would make this case pass for the WRONG reason (= = the injection
    # = = never happened, = = so there was nothing to restore).
    with open(os.path.join(repo, "docs", "agents", "nfi.md"), "a", encoding="utf-8") as h:
        h.write("| `Sources/Tracked.swift` | `Sources/Tracked.swift` | 1 | ours |\n")
    dirty = run(["git", "status", "--porcelain"], cwd=repo).stdout.strip()
    if not dirty:
        print("FAILED: the fixture's lane is not dirty (= the injection would never happen)")
        return 1

    before_status = run(["git", "status", "--porcelain"], cwd=repo).stdout
    result = run(
        [
            sys.executable, TOOL,
            "--base", tip,
            "--repo", repo,
            "--only", "main",
            "--gate", other_gate,
        ],
        cwd=tmp,
    )
    out = result.stdout + result.stderr
    if result.returncode != 0:
        print("FAILED: the sweep exited non-zero")
        print(out)
        return 1

    # = = ⇒ ⇒ ⇒ THE LANE'S GATE BYTES MUST BE UNCHANGED. = = With
    # = = `if injected:` neutered, = = the injected gate is left behind = =
    # = = and this is the assertion that catches it.
    with open(lane_gate, "r", encoding="utf-8") as h:
        after = h.read()
    if after != lane_text:
        print("FAILED: the sweep left a DIFFERENT gate in the lane (= the restore did not happen)")
        print("  expected:", repr(lane_text))
        print("  found   :", repr(after))
        return 1

    # = = ⇒ ⇒ ⇒ AND THE LANE MUST NOT BE LEFT DIRTY IN THE GATE FILE.
    after_status = run(["git", "status", "--porcelain"], cwd=repo).stdout
    if "nfi-loc-check.py" in after_status:
        print("FAILED: the sweep left the lane dirty in the gate file (= the restore did not happen)")
        print(after_status)
        return 1
    if after_status != before_status:
        print("FAILED: the sweep changed the lane's status")
        print("  before:", repr(before_status))
        print("  after :", repr(after_status))
        return 1

    print("  G1: the injected gate is put back, byte for byte (= the lane is unchanged)")
    return 0


def case_g2_head_refusal(tool, tmp):
    """G2: a detached worktree whose HEAD is not the tip is NOT MEASURED."""
    repo = make_repo(tmp, "g2repo")
    tip = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
    keep = Path(tempfile.mkdtemp(prefix="g2-keep-"))

    branch = tool.Branch(branch="main", worktree=Path(repo), tip=tip)
    real = tool.git_rc

    def wrong_head(*args, cwd=None):
        if args[:2] == ("rev-parse", "HEAD"):
            return 0, "0" * 40 + "\n", ""
        return real(*args, cwd=cwd)

    tool.git_rc = wrong_head
    try:
        tool.measure_at_tip(repo, branch, tip, keep, None)
    finally:
        tool.git_rc = real

    if branch.measured:
        print("FAILED: a tree whose HEAD is not the tip was MEASURED (= the refusal did not fire)")
        return 1
    if "HEAD is" not in branch.note:
        print("FAILED: the refusal fired for the wrong reason")
        print("  note:", repr(branch.note))
        return 1
    print("  G2: a detached worktree whose HEAD is not the tip is NOT MEASURED")
    return 0


def case_g4_made_directory(tool, tmp):
    """G4: a DIRECTORY the sweep made must be gone again (= = the tree comes
    back EXACTLY as it was found, = = and a directory is part of that)."""
    repo = make_repo(tmp, "g4repo", with_gate_dir=False)
    # = = ⇒ ⇒ ⇒ THIS TREE HAS NO `Tools/wenshu-devtool/` AT ALL, = = so the
    # = = sweep MAKES the directory when it injects the gate, = = and must
    # = = take it away again.
    made_dir = os.path.join(repo, "Tools", "wenshu-devtool")
    if os.path.exists(made_dir):
        print("FAILED: the fixture's tree already carries the directory")
        return 1
    tip = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()

    other_gate = os.path.join(tmp, "g4-gate.py")
    with open(other_gate, "w", encoding="utf-8") as h:
        h.write("# a gate\nprint('g4')\n")

    # = = The lane must be dirty, = = or the sweep never measures its buffer
    # = = and never injects there.
    with open(os.path.join(repo, "docs", "agents", "nfi.md"), "a", encoding="utf-8") as h:
        h.write("| `Sources/Tracked.swift` | `Sources/Tracked.swift` | 1 | ours |\n")
    if not run(["git", "status", "--porcelain"], cwd=repo).stdout.strip():
        print("FAILED: the fixture's lane is not dirty")
        return 1

    result = run(
        [
            sys.executable, TOOL,
            "--base", tip,
            "--repo", repo,
            "--only", "main",
            "--gate", other_gate,
        ],
        cwd=tmp,
    )
    out = result.stdout + result.stderr
    if result.returncode != 0:
        print("FAILED: the sweep exited non-zero")
        print(out)
        return 1
    if os.path.exists(made_dir):
        print("FAILED: the sweep left the directory it made (= = the tree is not as it was found)")
        return 1
    status_after = run(["git", "status", "--porcelain"], cwd=repo).stdout
    if "wenshu-devtool" in status_after:
        print("FAILED: the sweep left the tree dirty in the directory it made")
        print(status_after)
        return 1
    print("  G4: the directory the sweep made is gone again (= = the tree is as it was found)")
    return 0


def case_g3_clean_refusal(tool, tmp):
    """G3: a detached worktree that is not clean is NOT MEASURED."""
    repo = make_repo(tmp, "g3repo")
    tip = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
    keep = Path(tempfile.mkdtemp(prefix="g3-keep-"))

    branch = tool.Branch(branch="main", worktree=Path(repo), tip=tip)
    real = tool.git_rc

    def dirty(*args, cwd=None):
        if args[:2] == ("status", "--porcelain"):
            return 0, " M Sources/Tracked.swift\n", ""
        return real(*args, cwd=cwd)

    tool.git_rc = dirty
    try:
        tool.measure_at_tip(repo, branch, tip, keep, None)
    finally:
        tool.git_rc = real

    if branch.measured:
        print("FAILED: a dirty detached worktree was MEASURED (= the refusal did not fire)")
        return 1
    if "not clean" not in branch.note:
        print("FAILED: the refusal fired for the wrong reason")
        print("  note:", repr(branch.note))
        return 1
    print("  G3: a detached worktree that is not clean is NOT MEASURED")
    return 0


def main():
    tool = load_tool()
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name, case in (
            ("G1 the injection/restore", case_g1_injection_restore),
            ("G2 the HEAD refusal", case_g2_head_refusal),
            ("G3 the cleanliness refusal", case_g3_clean_refusal),
            ("G4 the directory the sweep made", case_g4_made_directory),
        ):
            rc = case(tool, tmp)
            if rc != 0:
                failures += 1
            print(f"  {'PASS' if rc == 0 else 'FAIL'} {name}")
    if failures:
        print(f"FAILED: {failures} guard(s) did not hold")
        return 1
    print("blast radius: the sweep's four guards hold")
    return 0


if __name__ == "__main__":
    sys.exit(main())
