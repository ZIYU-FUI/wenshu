#!/usr/bin/env bash
# Test: the NFI registry merges at the KEY level (= the extracted file).
#
# Run from Tools/wenshu-devtool/tests/ directory.
# Exits 0 on PASS, non-0 on FAIL.
#
# WHY THIS TEST EXISTS
#
# The NFI table was append-only inside AGENTS.md, so two cards each adding
# one row both wrote the same last line and collided. It now lives in
# docs/agents/nfi.md with a key-level merge driver.
#
# These cases pin the behaviour that matters:
#
#   1. two cards add a DIFFERENT row        => merged, both rows present
#   2. two cards add a row, same parent group => merged
#   3. one card adds a row, the other edits AGENTS.md prose => merged
#   4. two cards change the SAME row to different contents => CONFLICT, and
#      the key is named (= union would have kept two rows with the same key,
#      silently)
#   5. the merged registry keeps ONE row per key
#   6. AGENTS.md has no merge driver of its own => a prose conflict between
#      two cards still conflicts (the safety property of the split)
#   7. a tail (= the text after the last table row) on ONE side only => the
#      merged registry keeps it (= taking the tail from one side alone
#      dropped it, so a rebase onto a base without the tail deleted it)
#   8. DIFFERENT tails on both sides => CONFLICT, and the tail is named
#   9. the SAME tail on both sides => merged (a fix that flags every tail
#      as a disagreement would trade a silent loss for a false conflict)
#   10. a REAL `git merge` with a tail on one side only => the tail survives
#      on disk (merge-tree covers the merge itself; this covers the path a
#      developer actually runs)
#  11. a branch that edits ONLY the header prose => the edit SURVIVES the
#      merge (= taking the header from "ours" alone dropped it, so a rebase
#      discarded a branch's prose edit and git dropped the commit as
#      "patch contents already upstream")
#  12. DIFFERENT headers on both sides => CONFLICT, and the header is named
#  13. the SAME header edit on both sides => merged (= a false conflict on a
#      header the two sides agree on would be a false alarm)
#  14. ONE side edits the tail => the merge is CLEAN and the edited tail
#      wins (= the tail is merged THREE WAYS against base, the way the
#      header is: one side changed it => that side's tail. The two-way rule
#      called every difference a disagreement, so a branch that edited the
#      tail collided with a sibling that merely re-landed it)
# 14b. the same merge with the sides reversed => the same expectation
# 15. one side DROPS the trailing newline => clean, that side's tail wins, and
#     the dropped byte is silent (only ci_change_gate markdown-newline guards it)
# 16. a key DELETED on one side and UNCHANGED on the other => clean, and the
#     deletion WINS (= the old one-sided rule appended whichever row it found
#     with no reference to base, so a repaired row deleted its defective twin
#     and the defective twin came back on merge, rc=0, gate still green)
# 17. a key DELETED on one side and CHANGED on the other => CONFLICT, named
# 18. a branch that deletes two defective rows and adds two repaired forms,
#     against an untouched sibling => clean, repaired keys exactly once,
#     defective keys zero (the landing shape measured on 2026-11-20). THE
#     DRIVER'S INVOCATION COUNT IS ASSERTED, not assumed: `driver ran: N`.
# 19. THE FIRING ARM: both sides change the registry against a base that is
#     neither (base carries the two defective rows, ours deletes them and
#     adds a row, theirs adds a different row). Expects `driver ran >= 1`, a
#     clean merge, the defective keys ZERO times and each added key once.
#     Under the pre-fix driver this is the case that goes RED naming itself,
#     and the row count it prints is the 468-row blob.
# 20. THE NON-FIRING ARM, pinned at ZERO: ours changes the registry, theirs
#     never touches the file, so git takes ours and consults no driver at
#     all. This is the shape the published landing arms were in (= a census
#     taken on it says nothing about the driver, wired or not).
set -uo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
case "$SCRIPT_PATH" in
    /*) ;;
    *)  SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
esac
SCRIPT_DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"
REG="docs/agents/nfi.md"

FAILURES=0
PASSINGS=0
pass() { echo "  PASS  $1"; PASSINGS=$((PASSINGS + 1)); }
fail() { echo "  FAIL  $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d)
# The invocation log and its markers live OUTSIDE the scratch repository: a
# tracked log would be dirtied by every merge and then refuse the next
# `git checkout` (= measured: the first version of this counter committed the
# log with `git add -A`, and case 3 died on "local changes would be
# overwritten by checkout" rather than on its own assertion).
SANDBOX=$(mktemp -d)
DRIVER_LOG="$SANDBOX/driver-invocations.log"
trap 'rm -rf "$WORK" "$SANDBOX"' EXIT

cd "$WORK"
git init -q -b main .
git config user.email "test@example.com"
git config user.name "Test"
mkdir -p "$(dirname "$REG")" docs/agents Scripts
cp "$REPO_ROOT/$REG" "$REG"
cp "$REPO_ROOT/AGENTS.md" AGENTS.md
cp "$REPO_ROOT/.gitattributes" .gitattributes
cp "$REPO_ROOT/Scripts/merge-nfi-registry.py" Scripts/
# THE DRIVER IS RUN THROUGH A WRAPPER THAT COUNTS ITS INVOCATIONS. The suite
# used to call the driver directly, so nothing could tell a merge the driver
# resolved from a merge git never handed to the driver at all: an arm that
# fires the driver and an arm that silently takes one side's blob print the
# same thing. Cases 18-20 assert the COUNT, not the output (= the whole point
# of a driver arm is that the driver ran; see case 20 for the shape that never
# reaches it).
printf '#!/bin/sh\necho invoke >> "%s"\nexec python3 "%s/Scripts/merge-nfi-registry.py" "$@"\n' \
    "$DRIVER_LOG" "$WORK" > Scripts/driver-wrapper.sh
chmod +x Scripts/driver-wrapper.sh
git config merge.nfi-registry.driver "sh Scripts/driver-wrapper.sh %O %A %B"
: > "$DRIVER_LOG"
# driver_ran <since>  = invocations the driver appended since <since>'s snapshot was taken.
# The name is the same token `docs/agents/nfi.md` publishes beside every arm, so a reader
# can grep one word in both files instead of translating between two.
driver_ran() { echo "$(grep -c invoke "$DRIVER_LOG") - $(wc -l < "$1" | tr -d ' ')" | bc; }
# marker <name>  = snapshot of the log for the next driver_ran
marker() { cp "$DRIVER_LOG" "$SANDBOX/marker-$1"; }
git add -A
git commit -qm "base"

BASE=$(git rev-parse HEAD)
BASEROWS=$(grep -cE '^\| `' "$REG")

# The fixture helpers read the table with the MERGE DRIVER'S OWN row rule
# (= its split_rows), so a fixture and the merge can never disagree about
# where the table ends, and so the fixture lands a row where the driver
# will read it as a row. nfi-split.py loads the driver the same way.
#
# reg <add|addtail|striptail|chgrow|delrow|dupdef|chdr> ...
# The fixture's exit code is propagated: a command that refuses (delrow on a
# key it cannot find, dupdef on a key already present) MUST stop the case, or
# the case goes on to assert on a fixture that was never built (= measured on
# the first run of cases 19-20, where a refused delrow left the row in place
# and the arm failed on its row count instead of naming the refusal).
reg() { python3 - "$WORK/Scripts/merge-nfi-registry.py" "$REG" "$@" <<'PY'
import importlib.util
import re
import sys

driver_path, reg_path, cmd = sys.argv[1], sys.argv[2], sys.argv[3]
args = sys.argv[4:]

spec = importlib.util.spec_from_file_location("merge_nfi_registry", driver_path)
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)

text = open(reg_path, encoding="utf-8").read()
before, rows, after = driver.split_rows(text)
if "\n".join(before + rows + after) != text:
    sys.exit("the fixture helper cannot rebuild the registry byte-for-byte")

if cmd == "addrow":
    parent, fname, loc = args
    row = f"| `{parent}` | `{fname}` | {loc} | the {fname} surface. |"
    out = "\n".join(before + rows + [row] + after)
elif cmd == "addtail":
    out = "\n".join(before + rows + ["", args[0], ""])
elif cmd == "striptail":
    out = "\n".join(before + rows + [""])
elif cmd == "chgrow":
    fname, loc = args
    out = re.sub(rf"(\| `{re.escape(fname)}` \| )\d+( \|)", rf"\g<1>{loc}\g<2>", text)
elif cmd == "delrow":
    # Delete the row whose extracted-file key is exactly this, and refuse if
    # it is not exactly one row: a case that deletes nothing is a case that
    # tests nothing, and the resurrection defect hides in exactly that gap.
    fname = args[0]
    pat = re.compile(rf"^\| `[^|]*` \| `{re.escape(fname)}` \|")
    kept = [ln for ln in text.split("\n") if not pat.match(ln)]
    dropped = len(text.split("\n")) - len(kept)
    if dropped != 1:
        sys.exit(f"delrow: expected to delete exactly 1 row for {fname}, matched {dropped}")
    out = "\n".join(kept)
elif cmd == "dupdef":
    # Re-create a row the tree no longer carries (= the shape of `main`'s
    # registry before a repair landed). The fixture refuses a key that is
    # ALREADY present: a case that duplicates a live key would report a
    # resurrection that never needed one.
    fname, parent, loc, tag = args
    pat = re.compile(rf"^\| `[^|]*` \| `{re.escape(fname)}` \|")
    if any(pat.match(ln) for ln in text.split("\n")):
        sys.exit(f"dupdef: the key {fname} is already in the table; this case needs it absent")
    out = "\n".join(before + rows + [f"| `{parent}` | `{fname}` | {loc} | {tag} |"] + after)
elif cmd in ("count", "countkey"):
    # READ-ONLY probes, answered with the DRIVER'S OWN row and key rules
    # (split_rows / key_of) rather than a grep of ours: the bash `grep -c
    # '^| `' ruler counts the table's header and separator as rows too, so a
    # case that mixes the two gets an arithmetic it cannot explain.
    if cmd == "count":
        print(len(rows))
    else:
        print(sum(1 for r in rows if driver.key_of(r) == args[0]))
    sys.exit(0)
elif cmd == "chdr":
    old, new = args
    header = "\n".join(before)
    if header.count(old) != 1 or text.count(old) != 1:
        sys.exit(f"the header phrase is not unique in the header: {old}")
    out = text.replace(old, new, 1)
else:
    sys.exit(f"unknown fixture command: {cmd}")

open(reg_path, "w", encoding="utf-8").write(out)
PY
    return $?
}
# addrow <parent> <file> <loc>
# The row lands at the END of the table: after the last table row, so the
# text after it (= the tail) stays after the row.
addrow() { reg addrow "$1" "$2" "$3"; }
# addtail <text>  = set the file's tail (= the text after the last table row)
addtail() { reg addtail "$1"; }
# striptail  = drop the file's tail (= leave nothing after the last table row)
striptail() { reg striptail; }
# chgrow <file> <newloc>  = change an existing row's LOC
chgrow() { reg chgrow "$1" "$2"; }
# delrow <file>  = delete the row whose extracted-file key is exactly <file>.
# The fixture refuses to delete anything other than exactly one row, so a case
# cannot claim to test a deletion that never happened (= the shape that let the
# resurrection survive every earlier version of this suite).
delrow() { reg delrow "$1"; }
# dupdef <file> <parent> <loc> <tag>  = re-create a row this tree no longer
# carries, the way the defective rows sit on `main`. The fixture refuses a key
# that is already present, so case 19 cannot report a resurrection it never set up.
dupdef() { reg dupdef "$@"; }
# chdr <old> <new>  = change ONE phrase of the header (= the prose above the
# table). The fixture refuses a phrase that is not unique in the header, so
# a case cannot silently edit a row instead.
chdr() { reg chdr "$1" "$2"; }
branch() { git checkout -q -B "$1" "$BASE"; }

echo "nfi registry key-level merge tests (base rows = $BASEROWS)"

# 1. each side adds a DIFFERENT row => merged, both present
branch s1; addrow "Sources/.../A.swift" "TestAlpha.swift" 111; git commit -qam "A registers TestAlpha"
branch s2; addrow "Sources/.../B.swift" "TestBeta.swift"  222; git commit -qam "B registers TestBeta"
MRC=0; MT=$(git merge-tree --write-tree --name-only s1 s2 2>&1) || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "1. two cards adding DIFFERENT rows merge cleanly"
else
    fail "1. two cards adding different rows conflicted: $MT"
fi
TREE=$(echo "$MT" | head -1)
git cat-file -p "$TREE:$REG" > merged.md 2>/dev/null
if grep -q "TestAlpha.swift" merged.md && grep -q "TestBeta.swift" merged.md; then
    pass "1b. BOTH rows survive the merge"
else
    fail "1b. a row was lost in the merge"
fi
if [ "$(grep -cE '^\| `' merged.md)" -eq "$((BASEROWS + 2))" ]; then
    pass "1c. the merged registry has exactly 2 more rows"
else
    fail "1c. row count wrong (= $(grep -cE '^\| `' merged.md), expected $((BASEROWS + 2)))"
fi

# 2. both sides add a row to the SAME parent group => merged
branch s3; addrow "Sources/.../Same.swift" "TestGamma.swift" 333; git commit -qam "C registers TestGamma"
MRC=0; git merge-tree --write-tree --name-only s1 s3 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "2. two cards adding to the same parent group merge cleanly"
else
    fail "2. two cards adding to the same parent group conflicted"
fi

# 3. one card adds a row, the other edits AGENTS.md prose => merged
branch s4
python3 - <<'PY'
p = "AGENTS.md"
s = open(p, encoding="utf-8").read()
s = s.replace("## §2 Stack baseline", "## §2 Stack baseline\n\nA prose line only card s4 wrote.")
open(p, "w", encoding="utf-8").write(s)
PY
git commit -qam "s4 edits AGENTS.md prose"
MRC=0; git merge-tree --write-tree --name-only s1 s4 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "3. a registry append plus a prose edit merge cleanly"
else
    fail "3. a registry append plus a prose edit conflicted"
fi

# 4. two sides change the SAME row to different contents => CONFLICT, key named
FIRSTKEY=$(grep -oE '^\| `[^|]*` \| `[^`]+`' "$REG" | head -1 | sed -E 's/.*\| `([^`]+)`$/\1/')
branch s5; chgrow "$FIRSTKEY" 777; git commit -qam "s5 sets the LOC"
branch s6; chgrow "$FIRSTKEY" 888; git commit -qam "s6 sets a different LOC"
OUT=$(git merge-tree --write-tree --name-only --messages s5 s6 2>&1 || true)
if echo "$OUT" | grep -q "$FIRSTKEY"; then
    pass "4. a real disagreement on the same row conflicts AND names the key"
else
    fail "4. the disagreement did not conflict, or did not name the key (output: $OUT)"
fi
TREE=$(git merge-tree --write-tree s5 s6 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged3.md 2>/dev/null
if [ "$(grep -cE "^\| \`[^\`]*\` \| \`$FIRSTKEY\`" merged3.md)" -eq 1 ]; then
    pass "4b. the merged registry keeps ONE row for the disputed key"
else
    fail "4b. the disputed key ended up with $(grep -cE "^\| \`[^\`]*\` \| \`$FIRSTKEY\`" merged3.md) rows (= a duplicate key)"
fi

# 5. the merged registry keeps one row per key
if [ "$(grep -oE '^\| `[^|]*` \| `[^`]+`' merged.md | sed -E 's/.*\| `([^`]+)`$/\1/' | sort | uniq -d | wc -l | tr -d ' ')" = "0" ]; then
    pass "5. the merged registry has no duplicate key"
else
    fail "5. the merged registry has a duplicate key"
fi

# 6. AGENTS.md carries no merge driver => a prose conflict still conflicts
if grep -qE "^AGENTS\.md merge=" .gitattributes; then
    fail "6. AGENTS.md carries a merge rule (= a prose disagreement would be swallowed)"
else
    pass "6. AGENTS.md has no merge rule (= prose keeps the normal merge)"
fi

# 7. a tail on ONE side only => the merge keeps it
#    The tail is the marker that says where new rows go, so dropping it puts
#    the registry back to broken. Taking the tail from one side alone meant
#    the side without one lost it silently.
#    Both sides add a row (= both sides change the file, so the merge driver
#    runs) and only one of them carries the tail.
branch t1; addrow "Sources/.../TailOne.swift" "TestTailOne.swift" 111; striptail; git commit -qam "t1 has a row and no tail"
branch t2; addrow "Sources/.../TailTwo.swift" "TestTailTwo.swift" 222; addtail "<!-- Append new rows at the END of the table above. -->"; git commit -qam "t2 has a row and a tail"
MRC=0; git merge-tree --write-tree --name-only t1 t2 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "7. one side with a tail and one without merges cleanly"
else
    fail "7. a tail on one side only conflicted"
fi
TREE=$(git merge-tree --write-tree t1 t2 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged7.md 2>/dev/null
if grep -q "Append new rows" merged7.md; then
    pass "7b. the merged registry KEEPS the tail"
else
    fail "7b. the merge dropped the tail"
fi

# 7c. the same merge with the sides reversed => the tail survives either way
branch t3; addrow "Sources/.../TailThree.swift" "TestTailThree.swift" 333; addtail "<!-- Append new rows at the END of the table above. -->"; git commit -qam "t3 has a row and a tail"
branch t4; addrow "Sources/.../TailFour.swift" "TestTailFour.swift" 444; striptail; git commit -qam "t4 has a row and no tail"
MRC=0; git merge-tree --write-tree --name-only t3 t4 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "7c. the sides reversed merge cleanly"
else
    fail "7c. the sides reversed conflicted"
fi
TREE=$(git merge-tree --write-tree t3 t4 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged7c.md 2>/dev/null
if grep -q "Append new rows" merged7c.md; then
    pass "7d. the merged registry KEEPS the tail with the sides reversed"
else
    fail "7d. the merge dropped the tail with the sides reversed"
fi

# 8. DIFFERENT tails on both sides => CONFLICT, and the tail is named
#    A silent pick would trade a silent loss for a silent override.
branch t5; addrow "Sources/.../TailFive.swift" "TestTailFive.swift" 555; addtail "<!-- tail from card A -->"; git commit -qam "t5 has a row and tail A"
branch t6; addrow "Sources/.../TailSix.swift" "TestTailSix.swift" 666; addtail "<!-- tail from card B -->"; git commit -qam "t6 has a row and tail B"
OUT=$(git merge-tree --write-tree --name-only --messages t5 t6 2>&1 || true)
if echo "$OUT" | grep -q "<the file's tail>"; then
    pass "8. two different tails conflict AND name the tail"
else
    fail "8. the two different tails did not conflict, or did not name the tail (output: $OUT)"
fi
MRC=0; git merge-tree --write-tree --name-only t5 t6 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -ne 0 ]; then
    pass "8b. the driver exits non-zero on two different tails"
else
    fail "8b. the driver exited 0 on two different tails (= a silent override)"
fi

# 9. the SAME tail on both sides => merged
#    Two cards that restore the same marker must not conflict with each
#    other: the tails agree, so there is nothing to disagree about.
branch t7; addrow "Sources/.../TailSeven.swift" "TestTailSeven.swift" 777; addtail "<!-- Append new rows at the END of the table above. -->"; git commit -qam "t7 has a row and the same tail"
branch t8; addrow "Sources/.../TailEight.swift" "TestTailEight.swift" 888; addtail "<!-- Append new rows at the END of the table above. -->"; git commit -qam "t8 has a row and the same tail"
MRC=0; git merge-tree --write-tree --name-only t7 t8 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "9. the same tail on both sides merges cleanly"
else
    fail "9. the same tail on both sides conflicted (= a false disagreement)"
fi

# 10. a REAL `git merge` with a tail on one side only => the tail survives
#     on disk. The merge a developer actually runs, not a merge-tree.
branch r1; addrow "Sources/.../RealOne.swift" "TestRealOne.swift" 999; striptail; git commit -qam "r1 has a row and no tail"
branch r2; addrow "Sources/.../RealTwo.swift" "TestRealTwo.swift" 1010; addtail "<!-- Append new rows at the END of the table above. -->"; git commit -qam "r2 has a row and a tail"
git checkout -q r1
MRC=0; git merge r2 -m "merge r2" > realmerge.log 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ] && grep -q "Append new rows" "$REG"; then
    pass "10. a real git merge KEEPS the tail on disk"
else
    fail "10. a real git merge dropped the tail (exit $MRC): $(cat realmerge.log)"
fi
git merge --abort 2>/dev/null || true

# 11. a branch that edits ONLY the header prose => the edit SURVIVES
#     The header (= everything above the table, prose included) belongs to
#     the FILE, not to one side. Taking it from "ours" alone dropped the
#     other side's edit to it: in a rebase "ours" is the side being rebased
#     ONTO, so the branch's prose edit was discarded silently and the
#     cherry-pick came out empty (= git printed "patch contents already
#     upstream"). Here one side adds a row (= so the driver runs) and the
#     other edits only the prose.
HDR_OLD="next reader finds the file by concern in under five seconds"
HDR_A="next reader finds the file by concern in under five minutes"
HDR_B="next reader finds the file by concern in under one minute"
branch h1; addrow "Sources/.../HdrOne.swift" "TestHdrOne.swift" 111; git commit -qam "h1 adds a row and leaves the header alone"
branch h2; chdr "$HDR_OLD" "$HDR_A"; git commit -qam "h2 edits only the header prose"
MRC=0; git merge-tree --write-tree --name-only h1 h2 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "11. a header-only edit merges cleanly"
else
    fail "11. a header-only edit conflicted"
fi
TREE=$(git merge-tree --write-tree h1 h2 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged11.md 2>/dev/null
if grep -qF "$HDR_A" merged11.md && ! grep -qF "$HDR_OLD" merged11.md; then
    pass "11b. the merged registry KEEPS the header edit"
else
    fail "11b. the merge dropped the header edit"
fi
if grep -q "TestHdrOne.swift" merged11.md; then
    pass "11c. the row merge still works beside the header merge"
else
    fail "11c. the row from the other side was lost"
fi

# 12. DIFFERENT headers on both sides => CONFLICT, and the header is named
#     A silent pick would trade a silent loss for a silent override.
branch h3; chdr "$HDR_OLD" "$HDR_A"; git commit -qam "h3 edits the header"
branch h4; chdr "$HDR_OLD" "$HDR_B"; git commit -qam "h4 edits the header differently"
OUT=$(git merge-tree --write-tree --name-only --messages h3 h4 2>&1 || true)
if echo "$OUT" | grep -qF "<the file's header>"; then
    pass "12. two different headers conflict AND name the header"
else
    fail "12. the two different headers did not conflict, or did not name the header (output: $OUT)"
fi
MRC=0; git merge-tree --write-tree --name-only h3 h4 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -ne 0 ]; then
    pass "12b. the driver exits non-zero on two different headers"
else
    fail "12b. the driver exited 0 on two different headers (= a silent override)"
fi

# 13. the SAME header edit on both sides => merged
#     Two cards that made the same prose edit must not conflict with each
#     other: the headers agree, so there is nothing to disagree about.
branch h5; chdr "$HDR_OLD" "$HDR_A"; addrow "Sources/.../HdrFive.swift" "TestHdrFive.swift" 555; git commit -qam "h5 edits the header and adds a row"
branch h6; chdr "$HDR_OLD" "$HDR_A"; addrow "Sources/.../HdrSix.swift" "TestHdrSix.swift" 666; git commit -qam "h6 edits the header the same way and adds a row"
MRC=0; git merge-tree --write-tree --name-only h5 h6 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "13. the same header edit on both sides merges cleanly"
else
    fail "13. the same header edit on both sides conflicted (= a false disagreement)"
fi
TREE=$(git merge-tree --write-tree h5 h6 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged13.md 2>/dev/null
if grep -qF "$HDR_A" merged13.md; then
    pass "13b. the merged registry carries the agreed header"
else
    fail "13b. the merged registry lost the agreed header"
fi

# 14. ONE side edits the tail => the merge is CLEAN and the edited tail wins
#     The tail is merged THREE WAYS against base (= the header's rule): one
#     side changed it => that side's tail. The two-way rule compared the two
#     sides alone, so a branch that EDITED the tail collided with a sibling
#     that merely re-landed it (= the driver named "<the file's tail>" and
#     exited 1) although only one side had changed anything.
#     Here "ours" keeps the base's tail byte-for-byte and "theirs" edits it.
TAIL_BASE_MARK="Append new rows"
TAIL_EDITED="<!-- the tail marker, edited by one side -->"
branch u1; addrow "Sources/.../TailEditOne.swift" "TestTailEditOne.swift" 111; git commit -qam "u1 adds a row and keeps the tail byte-for-byte"
branch u2; addrow "Sources/.../TailEditTwo.swift" "TestTailEditTwo.swift" 222; addtail "$TAIL_EDITED"; git commit -qam "u2 adds a row and edits the tail"
MRC=0; git merge-tree --write-tree --name-only u1 u2 >/dev/null 2>&1 || MRC=$?
TREE=$(git merge-tree --write-tree u1 u2 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged14.md 2>/dev/null
if [ "$MRC" -eq 0 ] \
   && grep -qF "$TAIL_EDITED" merged14.md \
   && ! grep -qF "$TAIL_BASE_MARK" merged14.md \
   && grep -q "TestTailEditOne.swift" merged14.md \
   && grep -q "TestTailEditTwo.swift" merged14.md \
   && [ "$(grep -cE '^\| `' merged14.md)" -eq "$((BASEROWS + 2))" ]; then
    pass "14. one side edits the tail => the merge is clean, the edited tail wins and both rows survive"
else
    fail "14. one side editing the tail did not merge cleanly (exit $MRC, edited tail: $(grep -cF "$TAIL_EDITED" merged14.md), base tail: $(grep -cF "$TAIL_BASE_MARK" merged14.md), rows: $(grep -cE '^\| `' merged14.md), expected $((BASEROWS + 2)))"
fi

# 14b. the same merge with the sides reversed => the edited tail still wins
branch u3; addrow "Sources/.../TailEditThree.swift" "TestTailEditThree.swift" 333; addtail "$TAIL_EDITED"; git commit -qam "u3 adds a row and edits the tail"
branch u4; addrow "Sources/.../TailEditFour.swift" "TestTailEditFour.swift" 444; git commit -qam "u4 adds a row and keeps the tail byte-for-byte"
MRC=0; git merge-tree --write-tree --name-only u3 u4 >/dev/null 2>&1 || MRC=$?
TREE=$(git merge-tree --write-tree u3 u4 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged14b.md 2>/dev/null
if [ "$MRC" -eq 0 ] \
   && grep -qF "$TAIL_EDITED" merged14b.md \
   && ! grep -qF "$TAIL_BASE_MARK" merged14b.md \
   && grep -q "TestTailEditThree.swift" merged14b.md \
   && grep -q "TestTailEditFour.swift" merged14b.md \
   && [ "$(grep -cE '^\| `' merged14b.md)" -eq "$((BASEROWS + 2))" ]; then
    pass "14b. the sides reversed => the merge is clean and the edited tail still wins"
else
    fail "14b. the sides reversed did not merge cleanly (exit $MRC, edited tail: $(grep -cF "$TAIL_EDITED" merged14b.md), base tail: $(grep -cF "$TAIL_BASE_MARK" merged14b.md), rows: $(grep -cE '^\| `' merged14b.md), expected $((BASEROWS + 2)))"
fi

# 15. one side DELETES the registry's trailing newline => the merge is CLEAN
#     (no CONFLICT), that side's tail wins, and the merged file's last byte is
#     NOT a newline.
#     This is the shape the three-way rule changed: under the two-way rule the
#     two sides' tails differed, the driver named "<the file's tail>" and
#     exited 1; now the newline-less side simply wins and the merge is SILENT
#     about the dropped byte, so ci_change_gate.py's `markdown-newline` check
#     is the ONLY guard for it (= = its prose says so, = = and this case pins
#     the behaviour).
branch v1; addrow "Sources/.../TailNewlineOne.swift" "TestTailNewlineOne.swift" 111
python3 - "$REG" <<'PY'
import sys
p = sys.argv[1]
data = open(p, "rb").read()
if not data.endswith(b"\n"):
    sys.exit("the fixture already lacked the trailing newline")
open(p, "wb").write(data[:-1])
PY
git commit -qam "v1 adds a row and DROPS the trailing newline"
branch v2; addrow "Sources/.../TailNewlineTwo.swift" "TestTailNewlineTwo.swift" 222; git commit -qam "v2 adds a row and keeps the trailing newline"
MRC=0; git merge-tree --write-tree --name-only v1 v2 >/dev/null 2>&1 || MRC=$?
TREE=$(git merge-tree --write-tree v1 v2 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged15.md 2>/dev/null
LASTBYTE=$(tail -c 1 merged15.md 2>/dev/null | od -An -tx1 | tr -d ' \n')
if [ "$MRC" -eq 0 ] \
   && [ "$LASTBYTE" != "0a" ] \
   && grep -q "TestTailNewlineOne.swift" merged15.md \
   && grep -q "TestTailNewlineTwo.swift" merged15.md \
   && [ "$(grep -cE '^\| `' merged15.md)" -eq "$((BASEROWS + 2))" ]; then
    pass "15. one side drops the trailing newline => the merge is clean, that side's tail wins, and the byte is dropped in silence"
else
    fail "15. the newline-less side did not win silently (exit $MRC, last byte: $LASTBYTE, rows: $(grep -cE '^\| `' merged15.md), expected $((BASEROWS + 2)))"
fi

# Two base keys to delete, taken with the driver's own key rule so a fixture
# and the merge can never disagree about what the key of a row is.
K1=$(grep -oE '^\| `[^|]*` \| `[^`]+`' "$REG" | head -1 | sed -E 's/.*\| `([^`]+)`$/\1/')
K2=$(grep -oE '^\| `[^|]*` \| `[^`]+`' "$REG" | sed -n 2p | sed -E 's/.*\| `([^`]+)`$/\1/')
if [ -z "$K1" ] || [ -z "$K2" ] || [ "$K1" = "$K2" ]; then
    fail "fixture: two distinct base keys required (K1='$K1' K2='$K2')"
fi

# 16. one side DELETES a key, the other leaves it UNCHANGED => clean, and the
#     row is GONE from the merged file.
#     WHY THIS CASE EXISTS: the driver used to resolve "this key has a row on
#     exactly one side" by appending whichever row it found, with no reference
#     to base. A card that repairs a defective row by DELETING it therefore
#     lost the deletion the moment it merged -- the base and the untouched
#     sibling still had the row, so the defective key came back and the repair
#     sat next to it. Measured on a real landing merge: 468 rows, both repaired
#     keys present AND both resurrected defective keys present, merge rc=0,
#     and nfi-loc-check.py then printed success because a resurrected row is
#     in neither its `added` set nor its `rewritten` set.
branch d1; addrow "Sources/.../RepairOne.swift" "TestRepairOne.swift" 111; delrow "$K1"; git commit -qam "d1 deletes a base row and adds a repair"
branch d2; addrow "Sources/.../RepairTwo.swift" "TestRepairTwo.swift" 222; git commit -qam "d2 never touches the deleted key"
MRC=0; git merge-tree --write-tree --name-only d1 d2 >/dev/null 2>&1 || MRC=$?
TREE=$(git merge-tree --write-tree d1 d2 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged16.md 2>/dev/null
K1N=$(grep -cE "^\| \`[^|]*\` \| \`$K1\` \|" merged16.md)
if [ "$MRC" -eq 0 ] && [ "$K1N" -eq 0 ] \
   && grep -q "TestRepairOne.swift" merged16.md && grep -q "TestRepairTwo.swift" merged16.md \
   && [ "$(grep -cE '^\| `' merged16.md)" -eq "$((BASEROWS + 1))" ]; then
    pass "16. deleted on one side, unchanged on the other => clean merge and the deletion WINS (no resurrection)"
else
    fail "16. the deleted key came back (exit $MRC, copies of $K1: $K1N, rows: $(grep -cE '^\| `' merged16.md), expected $((BASEROWS + 1)))"
fi

# 17. one side DELETES a key, the other CHANGES it => CONFLICT, and the key is
#     NAMED (the third outcome of the docstring's one-sided rule; a silent
#     pick of either side would be the same class of loss one screen above).
branch e1; delrow "$K2"; addrow "Sources/.../DelAndChg.swift" "TestDelAndChg.swift" 333; git commit -qam "e1 deletes $K2"
branch e2; chgrow "$K2" 913; git commit -qam "e2 changes $K2's LOC"
OUT=$(git merge-tree --write-tree --name-only --messages e1 e2 2>&1 || true)
ERCT=0; git merge-tree --write-tree e1 e2 >/dev/null 2>&1 || ERCT=$?
if [ "$ERCT" -ne 0 ] && echo "$OUT" | grep -qF "$K2"; then
    pass "17. deleted on one side, changed on the other => CONFLICT naming the key"
else
    fail "17. the delete/modify disagreement was resolved silently (merge-tree rc $ERCT; output: $(echo "$OUT" | tr '\n' ' ' | cut -c1-120))"
fi

# 18. the landing shape this whole case block exists for: one side deletes TWO
#     defective rows and adds their two repaired forms, the other side is an
#     unrelated sibling that never touched either key. Expect clean, each
#     repaired key EXACTLY ONCE, each defective key ZERO times.
branch f1; delrow "$K1"; delrow "$K2"
addrow "Sources/.../Repaired.swift" "RepairedAlpha.swift" 1001
addrow "Sources/.../Repaired.swift" "RepairedBeta.swift"  1002
git commit -qam "f1 repairs two rows by re-keying them"
branch f2; addrow "Sources/.../Sibling.swift" "TestSibling.swift" 2001; git commit -qam "f2 an unrelated sibling row"
marker c18
MRC=0; git merge-tree --write-tree --name-only f1 f2 >/dev/null 2>&1 || MRC=$?
DR18=$(driver_ran "$SANDBOX/marker-c18")
TREE=$(git merge-tree --write-tree f1 f2 2>/dev/null | head -1)
git cat-file -p "$TREE:$REG" > merged18.md 2>/dev/null
DEAD1=$(grep -cE "^\| \`[^|]*\` \| \`$K1\` \|" merged18.md)
DEAD2=$(grep -cE "^\| \`[^|]*\` \| \`$K2\` \|" merged18.md)
REPA=$(grep -cE "^\| \`[^|]*\` \| \`RepairedAlpha.swift\` \|" merged18.md)
REPB=$(grep -cE "^\| \`[^|]*\` \| \`RepairedBeta.swift\` \|" merged18.md)
if [ "$DR18" -lt 1 ]; then
    fail "18. this merge never reached the driver (driver ran: $DR18, log $DRIVER_LOG) (= the shape this case used to be: a clean tree that measured nothing)"
elif [ "$MRC" -eq 0 ] && [ "$DEAD1" -eq 0 ] && [ "$DEAD2" -eq 0 ] \
   && [ "$REPA" -eq 1 ] && [ "$REPB" -eq 1 ] \
   && [ "$(grep -cE '^\| `' merged18.md)" -eq "$((BASEROWS + 1))" ]; then
    pass "18. a re-keying branch merges against an untouched sibling: repaired keys once, defective keys zero (driver ran: $DR18)"
else
    fail "18. the landing shape is wrong (exit $MRC, driver ran: $DR18, log $DRIVER_LOG, defective: $DEAD1/$DEAD2, repaired: $REPA/$REPB, rows: $(grep -cE '^\| `' merged18.md), expected $((BASEROWS + 1)))"
fi

# 19. THE LANDING ITSELF, AT THE KEYS THE DEFECT WAS ACTUALLY MEASURED ON.
#     This tree no longer carries the two defective rows `main` still does
#     (`262`, `Vendor/MarkdownEngine/`) and it carries their two repaired
#     forms. So: base = the tip's table PLUS those two defective rows; ours
#     deletes both and adds one well-formed row for a real file; theirs adds a
#     different well-formed row. Both sides change `docs/agents/nfi.md`
#     against a base that is neither, which is the only shape in which git
#     hands the file to an external merge driver at all (= case 20 is the
#     shape it does not). Expect: the driver RAN (count >= 1, asserted, not
#     assumed), the merge is clean, the repaired key and the added key each
#     arrive exactly once, and each defective key arrives ZERO times. Under
#     the pre-fix driver this goes RED on the defective keys (= the 468-row
#     blob reappearing on the next registry merge).
DEF1="262"
DEF2="Vendor/MarkdownEngine/"
REP1="docs/agents/2026-11-03-session-close-board-client.md"
REP2="Vendor/MarkdownEngine/Package.swift"
# `branch` always starts the new branch at the base commit, so BOTH defective
# rows go on one branch in one commit: that commit is the merge base of the
# pair below, exactly as `main`'s registry is the merge base of a repair
# branch and a sibling that landed after it.
branch g2
dupdef "$DEF1" "$REP1" 190 "the closeout record, keyed by a bare NUMBER (= nothing to open)"
dupdef "$DEF2" "Sources/WenshuApp/Features/Editor/Model/EngineStyleSheetBridge.swift" 30994 "a whole VENDORED TREE keyed as if it were one file"
git commit -qam "g2 base carries both defective rows"
git checkout -q -B g3 g2; delrow "$DEF1"; delrow "$DEF2"
addrow "Sources/.../LandingRepair.swift" "TestLandingRepair.swift" 111; git commit -qam "g3 the repair branch: deletes both defective rows, adds one well-formed row"
git checkout -q -B g4 g2; addrow "Sources/.../LandingSibling.swift" "TestLandingSibling.swift" 222; git commit -qam "g4 the sibling that landed first: another well-formed row"
marker c19
MRC=0; git checkout -q g3; git merge --no-ff -m "landing g4" g4 > merged19.log 2>&1 || MRC=$?
DR19=$(driver_ran "$SANDBOX/marker-c19")
D19A=$(reg countkey "$DEF1")
D19B=$(reg countkey "$DEF2")
R19A=$(reg countkey "TestLandingRepair.swift")
R19B=$(reg countkey "TestLandingSibling.swift")
M19=$(grep -cE '^(<<<<<<<|>>>>>>>) ' "$REG")
ROWS19=$(reg count)
# base = BASEROWS + 2 defective; the deletions win; +1 row per side.
EXPECT19=$((BASEROWS + 2))
if [ "$DR19" -lt 1 ]; then
    fail "19. FIRING arm: the merge never reached the driver (driver ran: $DR19, log $DRIVER_LOG) (= a clean tree from a one-sided take is not landing evidence)"
elif [ "$MRC" -ne 0 ]; then
    fail "19. FIRING arm: the landing merge did not complete (exit $MRC, driver ran: $DR19): $(tr '\n' ' ' < merged19.log | cut -c1-140)"
elif [ "$D19A" -ne 0 ] || [ "$D19B" -ne 0 ]; then
    fail "19. FIRING arm: the deleted defective keys came BACK (driver ran: $DR19, \`$DEF1\`: $D19A, \`$DEF2\`: $D19B, rows: $ROWS19) (= the pre-fix one-sided rule: it appended whichever row it found without consulting base)"
elif [ "$M19" -ne 0 ]; then
    fail "19. FIRING arm: the merged registry carries $M19 conflict markers (driver ran: $DR19)"
elif [ "$R19A" -ne 1 ] || [ "$R19B" -ne 1 ]; then
    fail "19. FIRING arm: an added key is not exactly once (driver ran: $DR19, added: $R19A/$R19B)"
elif [ "$ROWS19" -ne "$EXPECT19" ]; then
    fail "19. FIRING arm: row count wrong (driver ran: $DR19, rows: $ROWS19, expected $EXPECT19 = $BASEROWS base rows + 2 defective + 2 added - 2 deleted)"
else
    pass "19. FIRING arm: both sides changed the registry against a base that is neither, driver ran: $DR19, clean, defective keys $D19A/$D19B, added keys once, rows $ROWS19"
fi

# 20. THE NON-FIRING ARM, pinned at zero. Ours changes the registry; theirs
#     changes something else, so `docs/agents/nfi.md` on theirs IS the base's
#     blob and ort takes ours without consulting any driver (= the shape the
#     published landing arms were in, and the reason a census taken on it can
#     never be evidence about the driver). Assert the count is ZERO: a driver
#     that silently started running here would mean the rule above is wrong.
git checkout -q -B n1 g3
git checkout -q -B n2 g2; echo "a prose line only the sibling wrote" >> AGENTS.md; git commit -qam "n2 never touches the registry"
marker c20
MRC=0; git checkout -q n1; git merge --no-ff -m "merge n2" n2 > merged20.log 2>&1 || MRC=$?
DR20=$(driver_ran "$SANDBOX/marker-c20")
if [ "$MRC" -ne 0 ]; then
    fail "20. NON-FIRING arm: the one-sided merge failed (exit $MRC): $(tr '\n' ' ' < merged20.log | cut -c1-140)"
elif [ "$DR20" -ne 0 ]; then
    fail "20. NON-FIRING arm: the driver ran $DR20 times on a merge where only one side touched the file (log $DRIVER_LOG) (= the one-sided-take rule this case pins is false)"
elif [ "$(git rev-parse HEAD:docs/agents/nfi.md)" != "$(git rev-parse n1:docs/agents/nfi.md)" ]; then
    fail "20. NON-FIRING arm: the merged registry is not ours byte-for-byte (driver ran: $DR20)"
else
    pass "20. NON-FIRING arm: one side never touched the file => the tip, unmerged: driver ran: $DR20, merged blob == ours"
fi

echo
echo "nfi registry: PASS=$PASSINGS FAIL=$FAILURES  driver_ran: c18=$DR18 c19=$DR19 (must be >= 1), c20=$DR20 (must be 0); invocations logged this run: $(grep -c invoke "$DRIVER_LOG"), log $DRIVER_LOG)"
if [ "$FAILURES" -eq 0 ]; then
    echo "nfi registry: all tests passed"
    exit 0
fi
echo "nfi registry: $FAILURES test(s) FAILED"
exit 1
