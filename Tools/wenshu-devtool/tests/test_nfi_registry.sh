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

# addrow <parent> <file> <loc>
addrow() { python3 - "$REG" "$1" "$2" "$3" <<'PY'
import sys
p, parent, fname, loc = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
s = open(p, encoding="utf-8").read()
row = f"| `{parent}` | `{fname}` | {loc} | the {fname} surface. |\n"
marker = "\n<!-- Append new rows"
i = s.index(marker)
open(p, "w", encoding="utf-8").write(s[:i] + row + s[i:])
PY
}
# chgrow <file> <newloc>  = change an existing row's LOC
chgrow() { python3 - "$REG" "$1" "$2" <<'PY'
import re, sys
p, fname, loc = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding="utf-8").read()
s = re.sub(rf"(\| `{re.escape(fname)}` \| )\d+( \|)", rf"\g<1>{loc}\g<2>", s)
open(p, "w", encoding="utf-8").write(s)
PY
}
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

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "nfi registry: all tests passed"
    exit 0
fi
echo "nfi registry: $FAILURES test(s) FAILED"
exit 1
