#!/usr/bin/env python3
"""measure_registry_merge_replay.py — how often the registry's merge driver
actually produced what landed, re-derived from history instead of asserted.

WHY THIS EXISTS

The claim under review is that `merge=nfi-registry` is not dormant: that the
key-level driver, and not a hand resolution, is what most registry merges on
main were built by. That claim decides a ruling (= whether the attribute stays
in .gitattributes), so it has to be a command, not a number quoted from a
review. Run it in any worktree or clone of this repo:

    python3 Tools/wenshu-devtool/tests/measure_registry_merge_replay.py
    python3 Tools/wenshu-devtool/tests/measure_registry_merge_replay.py main merge-tree

Two method switches, because the count MOVES with the method and a number that
does not name its method cannot be re-checked:

  DRIVER  merge (= default) replays each merge with the driver its OWN tree
          carries, which is the closest thing to what git ran at the time;
          main replays every merge with the driver main carries today, which
          is what a reader would get by running today's driver over old sides.
  TEXT    merge-file (= default) runs `git merge-file -p` over the three blobs;
          merge-tree runs `git merge-tree --write-tree` over the two parents,
          which is the shape a landing merge takes and consults .gitattributes
          AND .git/config (= on a checkout whose config defines no nfi driver,
          that arm is the no-driver comparison, not a driver run).

It writes nothing and reads nothing but git objects.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = str(Path(__file__).resolve().parents[2])
FILE = "docs/agents/nfi.md"
SINCE = "9301d5c4a2"
# DRIVER=merge replays each merge's OWN tree's driver (= what git would have
# run); DRIVER=main replays the driver as main carries it today.
# TEXT=merge-file runs git merge-file on the three blobs; TEXT=merge-tree runs
# git merge-tree on the two parents, which is the shape a real merge takes.
DRIVER = sys.argv[1] if len(sys.argv) > 1 else "merge"
TEXT = sys.argv[2] if len(sys.argv) > 2 else "merge-file"


def git(*args, **kw):
    out = subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True, **kw)
    if out.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed: {out.stderr.strip()}")
    return out.stdout


merges = git("rev-list", "--merges", f"{SINCE}..origin/main").split()
rows = []
with tempfile.TemporaryDirectory() as td:
    tdp = Path(td)
    for sha in merges:
        changed = git("diff-tree", "--no-commit-id", "--name-only", "-r",
                      "-m", "--root", sha).splitlines()
        # -m prints one block per parent; the file counts as changed on both
        # sides only when BOTH parents differ from their own merge-base.
        sides = []
        for p in (f"{sha}^1", f"{sha}^2"):
            base = git("merge-base", f"{sha}^1", f"{sha}^2").strip()
            d = git("diff-tree", "--no-commit-id", "--name-only", "-r", base, p)
            sides.append(FILE in d.split())
        if not all(sides):
            continue
        base = git("merge-base", f"{sha}^1", f"{sha}^2").strip()
        o = tdp / "ours"
        b = tdp / "base"
        t = tdp / "theirs"
        o.write_bytes(subprocess.run(["git", "show", f"{sha}^1:{FILE}"],
                                     cwd=REPO, capture_output=True).stdout)
        b.write_bytes(subprocess.run(["git", "show", f"{base}:{FILE}"],
                                     cwd=REPO, capture_output=True).stdout)
        t.write_bytes(subprocess.run(["git", "show", f"{sha}^2:{FILE}"],
                                     cwd=REPO, capture_output=True).stdout)
        drv = tdp / "driver.py"
        drv_src = f"{sha}:Scripts/merge-nfi-registry.py" if DRIVER == "merge" \
            else "origin/main:Scripts/merge-nfi-registry.py"
        drv.write_bytes(subprocess.run(["git", "show", drv_src],
                                       cwd=REPO, capture_output=True).stdout)
        # The driver writes its result over %A (= ours), so keep a pristine
        # copy of that side: reading the driver's own output back as "ours"
        # would understate what a plain text merge does to the real pair.
        (tdp / "ours0").write_bytes(o.read_bytes())
        landed = subprocess.run(["git", "show", f"{sha}:{FILE}"],
                                cwd=REPO, capture_output=True).stdout
        merged = subprocess.run([sys.executable, str(drv), str(b), str(o), str(t)],
                                capture_output=True, cwd=REPO)
        driver_out = o.read_bytes()
        if TEXT == "merge-file":
            plain = subprocess.run(
                ["git", "merge-file", "-p", str(tdp / "ours0"), str(b), str(t)],
                capture_output=True, cwd=REPO)
            text = plain.stdout.decode("utf-8", "replace")
            conflicted = bool([l for l in text.split("\n") if l.startswith("<<<<<<<")]) \
                or plain.returncode > 0
        else:
            # git's own merge over the two parents, attributes AND config
            # consulted: on this checkout the nfi driver is unset, so this is
            # what a landing merge would actually do today.
            plain = subprocess.run(
                ["git", "merge-tree", "--write-tree", f"{sha}^1", f"{sha}^2"],
                capture_output=True, text=True, cwd=REPO)
            conflicted = plain.returncode > 0
        identical = driver_out == landed
        dl = driver_out.decode("utf-8", "replace").split("\n")
        ll = landed.decode("utf-8", "replace").split("\n")
        import difflib
        diff = sum(1 for l in difflib.unified_diff(dl, ll, lineterm="")
                   if (l.startswith("+") or l.startswith("-"))
                   and not l.startswith(("+++", "---")))
        rows.append({
            "sha": sha[:10],
            "date": git("log", "-1", "--format=%cd", "--date=format:%Y-%m-%d %H:%M", sha).strip(),
            "driver_rc": merged.returncode,
            "identical": identical,
            "textmerge_conflict": conflicted,
            "diff_lines_vs_driver": diff,
        })

print(f"method: driver={DRIVER} text={TEXT} range={SINCE}..origin/main")
print(f"merges on origin/main since {SINCE} where both sides changed {FILE}: {len(rows)}")
for r in rows:
    print(f"  {r['sha']}  {r['date']}  identical={r['identical']}  "
          f"textmerge_conflict={r['textmerge_conflict']}  "
          f"driver_rc={r['driver_rc']}  diff_lines={r['diff_lines_vs_driver']}")
print(f"byte-identical to the driver's output: {sum(1 for r in rows if r['identical'])} of {len(rows)}")
print(f"plain git merge-file conflicts:        {sum(1 for r in rows if r['textmerge_conflict'])} of {len(rows)}")
print(f"deviating merges, by lines:            {[r['diff_lines_vs_driver'] for r in rows if not r['identical']]}")
dates = [(r["date"], r["sha"]) for r in rows]
if dates:
    newest, oldest = max(dates), min(dates)
    print(f"most recent such merge:                {newest[1]} {newest[0]}")
    print(f"oldest such merge:                     {oldest[1]} {oldest[0]}")
else:
    print("no such merge")
