#!/usr/bin/env python3
# ⇒ ⇒ ⇒ COMMITTED INTO THE REPO BY round 11 OF THE STANDARDS-AXIS REPORT (R10-B4, = = board
# comment 2163): = = this gate used to live only in the implementer's profile scratch
# (`cache/scratch/t2/`), = which is idle-pruned at 24h, = so the claim it backed could
# outlive the instrument. = = Provenance: = carried over BYTE-IDENTICAL below this header
# from that path; = = the reason for the move is that a gate which can be garbage-collected
# is not a gate.
# ⇒ ⇒ ⇒ WHAT IT SEES AND WHAT IT CANNOT: = = it extracts the `grep` commands naming
# this body and the unbalanced-backtick scan. = = It does NOT reach a `git show`
# provenance command or a property-count gate, = = so a clean report from it is not
# proof that every printed command runs (R10-B2's finding).
# ⇒⇒⇒ MEASURED DEFECT, = = LEFT IN AND NAMED HERE (2026-11-20, = = on the round-10
# report body): = = of 5 extracted commands it substituted the given file path into
# three and ran two LITERALLY with the card's own placeholder still in them — = =
# `grep -cE '0[ ]outside[ ]it' <this body>` — = = so those arms read rc=1 "found
# nothing" against a file named `<this body>` that does not exist, = = and the
# summary printed `gates answering themselves: 0`. = = ⇒ ⇒ ⇒ ⇒ SO ITS rc=0 COVERS
# THE ARMS IT SUBSTITUTED, = = = NOT THE ARMS IT PARSED BUT COULD NOT PLACE: = =
# count the `commands extracted` line against the substitution lines before quoting
# it as a pass.
"""Run EVERY grep the card prints, = = VERBATIM, = = against the card's own body.

Why this exists: = round 9 (report lane) was refused because "the sites grep
cannot run as printed" — the pattern string was broken across a line, = so the
command the card tells a reader to run dies with `grep: empty (sub)expression`,
rc 2, = 0 hits. = = A gate that cannot be executed off the page proves nothing,
and a card that cites it is citing prose. = = This script is the check the card
cannot do on itself at writing time: = it extracts each printed command, =
substitutes the body for `<this body>`, = and runs it.

Printed per command: = the exact string extracted, = its rc, = its hit count,
and whether it is the gate answering itself (= a hit on the line that carries
the command).

Usage: = python3 run-the-card-gates.py <body.md>
"""
import re
import subprocess
import sys
from pathlib import Path

body_path = Path(sys.argv[1])
text = body_path.read_text()
lines = text.split("\n")

# Every backticked grep the card tells a reader to run, = single-line only.
cmds = [c for c in re.findall(r"`(grep [^`]*<this body>[^`]*)`", text)
        if "…" not in c and "..." not in c]
# A prose mention of the placeholder (round 10 wrote "grep … <this body>" while
# describing this very script) matches the extraction pattern and is NOT a
# runnable command: = grep with no pattern reads its argument as the pattern,
# returns something, = and the harness would report a fabricated gate as green.
dropped = [c for c in re.findall(r"`(grep [^`]*<this body>[^`]*)`", text) if c not in cmds]
if dropped:
    print("    skipped " + str(len(dropped)) + " prose mention(s) of the placeholder,")
    print("    not runnable as printed: " + "; ".join(d[:60] for d in dropped))
print(f"=== extracted {len(cmds)} grep command(s) naming <this body>")

# Any prose line with an ODD number of backticks is either a command folded
# across lines or an inline span that never closed — = both leave the card's own
# text ambiguous, = and a reviewer cannot tell which one it is holding. = Fenced
# blocks are skipped: = a line inside a fence is not prose.
in_fence = False
open_spans = []
for i, l in enumerate(lines):
    if l.lstrip().startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    if l.count("`") % 2 == 1:
        open_spans.append(i + 1)
print("    prose lines with an UNBALANCED backtick (= a folded command, or an")
print("    inline span that never closed; = fences excluded): " + str(len(open_spans)))
for n in open_spans[:12]:
    print("      L" + str(n) + ": " + lines[n - 1][:120])

self_hits = 0
for c in cmds:
    real = c.replace("<this body>", str(body_path))
    proc = subprocess.run(["/bin/sh", "-c", real], capture_output=True, text=True)
    hits = [l for l in proc.stdout.split("\n") if l.strip()]
    # which line of the body carries this command?
    carrier = next((i + 1 for i, l in enumerate(lines) if c in l), 0)
    answered_itself = any(h.split(":")[0].strip().isdigit() and int(h.split(":")[0]) == carrier
                          for h in hits)
    self_hits += answered_itself
    print(f"\n--- rc={proc.returncode}  hits={len(hits)}  "
          f"{'GATE ANSWERS ITSELF' if answered_itself else 'clean'}")
    print(f"    cmd: {real[:150]}")
    if proc.stderr.strip():
        print(f"    STDERR: {proc.stderr.strip()[:200]}")
    for h in hits[:9]:
        print(f"    {h[:150]}")

print("\n=== total: " + str(len(cmds)) + " commands extracted; gates answering themselves: " + str(self_hits))
# rc 0 = ran and found; rc 1 = ran and found NOTHING (a finding, not a crash);
# rc >= 2 = the command did not run at all, which is round 9's defect exactly.
rcs = []
for c in cmds:
    rcs.append(subprocess.run(["/bin/sh", "-c", c.replace("<this body>", str(body_path))],
                              capture_output=True, text=True).returncode)
crashed = [c for c, r in zip(cmds, rcs) if r >= 2]
silent = [c for c, r in zip(cmds, rcs) if r == 1]
print("=== crashed (rc>=2, = the gate could not run): " + str(len(crashed)))
for c in crashed:
    print("   " + c[:160])
print("=== ran but found nothing (rc=1): " + str(len(silent)))
for c in silent:
    print("   " + c[:160])
sys.exit(1 if crashed else 0)
