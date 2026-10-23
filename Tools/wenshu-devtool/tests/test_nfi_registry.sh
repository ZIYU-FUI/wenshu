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
#  10. a REAL `git merge` with a tail on one side only => the tail survives
#      on disk (merge-tree covers the merge itself; this covers the path a
#      developer actually runs)
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
pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
git init -q -b main .
git config user.email "test@example.com"
git config user.name "Test"
mkdir -p "$(dirname "$REG")" docs/agents Scripts
cp "$REPO_ROOT/$REG" "$REG"
cp "$REPO_ROOT/AGENTS.md" AGENTS.md
cp "$REPO_ROOT/.gitattributes" .gitattributes
cp "$REPO_ROOT/Scripts/merge-nfi-registry.py" Scripts/
git config merge.nfi-registry.driver "python3 Scripts/merge-nfi-registry.py %O %A %B"
git add -A
git commit -qm "base"

BASE=$(git rev-parse HEAD)
BASEROWS=$(grep -cE '^\| `' "$REG")

# The fixture helpers read the table with the MERGE DRIVER'S OWN row rule
# (= its split_rows), so a fixture and the merge can never disagree about
# where the table ends, and so the fixture lands a row where the driver
# will read it as a row. nfi-split.py loads the driver the same way.
#
# reg <addrow|addtail|striptail|chgrow> ...
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
else:
    sys.exit(f"unknown fixture command: {cmd}")

open(reg_path, "w", encoding="utf-8").write(out)
PY
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

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "nfi registry: all tests passed"
    exit 0
fi
echo "nfi registry: $FAILURES test(s) FAILED"
exit 1
