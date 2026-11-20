#!/usr/bin/env python3
# ⇒ ⇒ ⇒ COMMITTED INTO THE REPO BY round 11 OF THE STANDARDS-AXIS REPORT (R10-B4, = = board
# comment 2163): = = this gate used to live only in the implementer's profile scratch
# (`cache/scratch/t2/`), = which is idle-pruned at 24h, = so the claim it backed could
# outlive the instrument. = = Provenance, = = SCOPED (finding N1, = = verdict comment 2205): = =
# the body below this header was carried over BYTE-IDENTICAL from that scratch path AT THE
# CARRY-IN COMMIT, = = identified by its message ("tools(devtool): commit the three instruments
# the standards-axis report's closure claims rest on"; = = its sha moves on every rebase, = = so
# the message is the durable name). = = It diverged ONCE SINCE, = = on purpose: = = card
# t_2699b55c added the AN EMPTY UNIVERSE IS NOT A PASS refusal below (= = finding B1), = = which
# is the first intentional divergence. = = The claim is therefore scoped, = = not deleted: = = a
# reader who checks provenance by substring gets a TRUE answer for the carry-in body and must
# expect a FALSE one for anything edited after it (= = finding N1 is exactly that trap, = = walked
# into by run-the-card-gates.py one commit earlier than this file was). = = The reason for the move
# stands: = = a gate which can be garbage-collected is not a gate.
# ⇒ ⇒ ⇒ IT PRICES A CLAIM'S QUALIFIER, = = IT DOES NOT VERIFY THE NUMBER: = = a
# sentence quoting a count must name the population it counted, = = and this gate
# refuses the ones that do not.
"""The RULE-6.5 QUALIFIER GATE (= = the check the report card's own claim needs).

The card claims: = "every site of the citers-equality names the population in the
same sentence". = = Round 9 carried two sites that did not (= = one of them was
inside the ROUND-6 history block, = = and the reviewer wrote a blocker about it),
and the reviewer could only find them by reading. = = This turns the claim into
something a machine checks.

What it does:

  1. finds every site of the four claim-forms with the SAME pattern the card
     prints in GATES TO RUN (= = `exactl[y] the cards|exactl[y] this report|
     no card outsid[e]|NO CARD OUTSIDE THAT SE[T]`). = = The character classes are
     the point: = the gate's own command line contains the bracketed forms, = so it
     cannot answer itself; = = a pattern without a class (`exactly the cards`) would
     match the gate text and pass for the wrong reason.
  2. for each site, = = takes the SENTENCE it sits in — = = a sentence in this card
     wraps across up to three lines, = = so a one-line check reports a qualified
     claim as unqualified, = = which is a false finding of exactly the kind this
     scope keeps hitting.
  3. requires the sentence window to name a POPULATION (= = census universe /
     window-sha / not archived / population).
  4. reports sites whose sentence names no population, = = and separately reports
     whether the gate's own line was among the hits (= = self-answering).

Exit 0 only when the sites pattern found SOMETHING and every site is qualified and the gate does
not answer itself. = = An empty universe exits non-zero (= = finding B1): = = "every site qualified"
over zero sites is the same sentence as "no row violated the rule" over zero rows.

Usage: = python3 qualifier-gate.py BODY.md
"""
import re
import subprocess
import sys
from pathlib import Path

PATTERN = r"exactl[y] the cards|exactl[y] this report|no card outsid[e]|NO CARD OUTSIDE THAT SE[T]"
POPULATION = re.compile(
    r"census universe|window-sha|within the universe|not archived|population|the census", re.I)
WINDOW = 2  # = lines on either side that may carry the rest of the sentence

body_path = Path(sys.argv[1])
text = body_path.read_text()
lines = text.split("\n")

out = subprocess.run(["grep", "-nE", PATTERN, str(body_path)],
                     capture_output=True, text=True)
if out.returncode >= 2:
    sys.exit("the sites pattern did not run (rc=%d): %s" % (out.returncode, out.stderr.strip()))

hits = sorted({int(l.split(":", 1)[0]) for l in out.stdout.strip().split("\n") if l})
print("=== sites pattern: " + PATTERN)
print("=== hits: " + str(len(hits)) + " at body lines " + ", ".join(map(str, hits)))

# AN EMPTY UNIVERSE IS NOT A PASS (= = finding B1). = = Every site qualified, = = over zero sites,
# certifies the claim as loudly as a real census does, = = and it is reachable by the two routes
# that actually happen: = = the claim was reworded, = = or PATTERN above was typo'd. = = :57 already
# refuses the case where grep could not run; = = this is the case where it ran and found nothing.
# The precedent for refusing this shape is in the same commit: = = row-integrity.py:62-66, = =
# "ZERO rows parsed ... Fix the checker, = = do not report identity."
if not hits:
    sys.exit("qualifier-gate: the sites pattern matched 0 lines in " + str(body_path)
             + ": 0 unqualified over 0 sites is not a pass, it is an unread claim."
             " Either the claim was reworded out of PATTERN or PATTERN is broken;"
             " fix the checker, do not report identity.")

# self-answering: is the line that CARRIES the gate command itself a hit?
carrier = [i + 1 for i, l in enumerate(lines)
           if "grep -nE '" in l and "exactl[y]" in l]
self_answering = [n for n in hits if n in carrier]

unqualified = []
for n in hits:
    win = " ".join(lines[max(0, n - 1 - WINDOW): n + WINDOW])
    ok = bool(POPULATION.search(win))
    print("  L" + str(n).rjust(4) + "  " + ("QUALIFIED  " if ok else "UNQUALIFIED")
          + "  :: " + lines[n - 1][:100])
    if not ok:
        unqualified.append(n)

print("=== carrier line(s) of the gate itself: " + str(carrier or "none"))
print("=== gate answering itself: " + str(self_answering or "no"))
print("=== unqualified sites: " + str(unqualified or "none"))
sys.exit(0 if not unqualified and not self_answering else 1)
