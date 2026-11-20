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
# ⇒⇒⇒ WHAT IT ACTUALLY DOES, = = CORRECTED 2026-11-20 AFTER VERDICT COMMENT 2186 (R11-B6). = = An
# earlier version of this header claimed the extractor "substituted the path into three of five
# commands and ran two LITERALLY with the placeholder still in them". = = That is false: = = every
# extracted command is run through `real = c.replace("<this body>", str(body_path))` — = one
# substitution site, = applied to all of them. = = The placeholder the log appeared to show came from
# a DISPLAY bug fixed in the same change: = the `crashed` / `ran but found nothing` lists printed the
# TEMPLATE `c` while the run used `real`, = so the log accused the tool of running a file named
# `<this body>` that nobody ran. = = Two real limits replace that invented one, = and they are the
# reason a clean report from this gate is not a verdict:
#   (i) the extractor matches only `grep` spans naming `<this body>`, = so a `git show` provenance
#       command, = a `pandoc` render and a sqlite census never run under it at all; = and
#  (ii) `grep -c` returns rc=1 when the answer is 0, = which is often the CORRECT answer (gate 5b
#       expects 0), = so rc is data here and not a pass/fail. = = Use
#       `verify-report-body.py` for claims that must assert.
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
results = []          # (executed command, returncode) — the lists below reuse THIS pass, not a re-run
for c in cmds:
    real = c.replace("<this body>", str(body_path))
    proc = subprocess.run(["/bin/sh", "-c", real], capture_output=True, text=True)
    results.append((real, proc.returncode))
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
# rc 0 = ran and found; rc 1 = ran and found NOTHING (a finding, not a crash; and for `grep -c` an
# answer of 0 is often the EXPECTED answer, so this is data, not a verdict);
# rc >= 2 = the command did not run at all, which is round 9's defect exactly.
#
# THE LISTS BELOW PRINT WHAT WAS EXECUTED, = not the template. = = Until 2026-11-20 they printed `c`,
# which still held the `<this body>` placeholder, = and a reader concluded the tool had run a command
# against a nonexistent file (verdict comment 2186, = R11-B6). = = The runs are also REUSED from the
# loop above instead of re-executed: = a second pass could disagree with the first (a body that
# changes between passes, = or a `git show` that races a fetch) and then the counts printed above
# would not be the counts that decided the lists below.
crashed = [real for real, rc in results if rc >= 2]
silent = [real for real, rc in results if rc == 1]
print("=== crashed (rc>=2, = the gate could not run): " + str(len(crashed)))
for c in crashed:
    print("   " + c[:160])
print("=== ran but found nothing (rc=1): " + str(len(silent)))
for c in silent:
    print("   " + c[:160])
sys.exit(1 if crashed else 0)
