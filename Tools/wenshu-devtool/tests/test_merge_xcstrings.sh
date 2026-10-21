#!/usr/bin/env bash
# Test: the xcstrings merge driver merges the catalog at the KEY level.
#
# Run from Tools/wenshu-devtool/tests/ directory.
# Exits 0 on PASS, non-0 on FAIL.
#
# WHY THIS TEST EXISTS
#
# The catalog is the most-touched file in a wave, and its keys are NOT sorted:
# a new key lands in the MIDDLE of the file. So two cards that each add a
# DIFFERENT key produce a textual conflict under git's normal merge, because
# both insertions land in the same neighbourhood. Measured on this repo:
# `git merge-tree` on two branches adding one distinct key each = CONFLICT.
#
# The driver removes that class. These cases pin the behaviour:
#
#   1. a byte-exact no-op on an untouched file
#   2. each side adds a DIFFERENT key        => merged, both keys present
#   3. both sides add the SAME key, same value => merged
#   4. both sides add the SAME key, different value => CONFLICT, key named
#   5. one side edits an existing key, other adds a new key => merged
#   6. one side DELETES a key, other edits it  => CONFLICT, key named
#   7. one side DELETES a key, other leaves it => the deletion wins
#   8. a REAL `git merge` uses the driver      => no conflict markers in the file

set -uo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
case "$SCRIPT_PATH" in
    /*) ;;
    *)  SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
esac
SCRIPT_DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"
DRIVER="$REPO_ROOT/Scripts/merge-xcstrings.py"
CAT="Sources/WenshuApp/Resources/Localizable.xcstrings"

FAILURES=0
pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; FAILURES=$((FAILURES + 1)); }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
git init -q -b main .
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p "$(dirname "$CAT")"
cp "$REPO_ROOT/$CAT" "$CAT"
cp "$DRIVER" ./driver.py
printf '*.xcstrings merge=xcstrings\n' > .gitattributes
git config merge.xcstrings.driver "python3 driver.py %O %A %B"
git add -A
git commit -qm "base"

BASE=$(git rev-parse HEAD)
KEYCOUNT=$(python3 -c "import json;print(len(json.load(open('$CAT'))['strings']))")

# setkey <key> <value>   = add a key
setkey() { python3 - "$CAT" "$1" "$2" <<'PY'
import json, sys
p, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(p, encoding="utf-8"))
d["strings"][k] = {"extractionState": "manual",
                   "localizations": {"en": {"stringUnit": {"state": "translated", "value": v}}}}
open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
PY
}
# editkey <key> <value>  = change an existing key's English value
editkey() { python3 - "$CAT" "$1" "$2" <<'PY'
import json, sys
p, k, v = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(p, encoding="utf-8"))
d["strings"][k]["localizations"]["en"]["stringUnit"]["value"] = v
open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
PY
}
# delkey <key>  = delete a key
delkey() { python3 - "$CAT" "$1" <<'PY'
import json, sys
p, k = sys.argv[1], sys.argv[2]
d = json.load(open(p, encoding="utf-8"))
del d["strings"][k]
open(p, "w", encoding="utf-8").write(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
PY
}

# branch <name> ; creates a branch off BASE with the working tree clean
branch() { git checkout -q -B "$1" "$BASE"; }

echo "merge-xcstrings driver tests (base key count = $KEYCOUNT)"

# 1. byte-exact no-op
cp "$CAT" /tmp/xc-orig.json
python3 driver.py "$CAT" "$CAT" "$CAT"
if cmp -s /tmp/xc-orig.json "$CAT"; then
    pass "1. no-op on an untouched file is byte-identical"
else
    fail "1. no-op on an untouched file changed the bytes"
fi

# 2. each side adds a DIFFERENT key => merged
branch s1; setkey "test.alpha" "Alpha"; git commit -qam "alpha"
branch s2; setkey "test.beta"  "Beta";  git commit -qam "beta"
MRC=0; MT=$(git merge-tree --write-tree --name-only s1 s2 2>&1) || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "2. two sides adding DIFFERENT keys merge cleanly"
else
    fail "2. two sides adding DIFFERENT keys conflicted: $MT"
fi
TREE=$(echo "$MT" | head -1)
git cat-file -p "$TREE:$CAT" > merged.json 2>/dev/null
if python3 -c "
import json
ks = json.load(open('merged.json'))['strings']
assert 'test.alpha' in ks and 'test.beta' in ks, 'a key was lost'
assert len(ks) == $KEYCOUNT + 2, len(ks)
" 2>/dev/null; then
    pass "2b. the merged catalog holds BOTH new keys"
else
    fail "2b. the merged catalog lost a key"
fi

# 3. both sides add the SAME key with the SAME value => merged
branch s3; setkey "test.same" "Same"; git commit -qam "same value"
MRC=0; git merge-tree --write-tree --name-only s1 s3 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "3. both sides adding the same key with the same value merges"
else
    fail "3. both sides adding the same key with the same value conflicted"
fi

# 4. both sides add the SAME key with DIFFERENT values => CONFLICT, key named
branch s4; setkey "test.same" "Different"; git commit -qam "different value"
OUT=$(git merge-tree --write-tree --name-only --messages s3 s4 2>&1 || true)
if echo "$OUT" | grep -q "test.same"; then
    pass "4. the same key with different values conflicts AND names the key"
else
    fail "4. the conflict did not name the key (output: $OUT)"
fi

# 5. one side edits an existing key, the other adds a new key => merged
branch s5; editkey "View" "Edited"; git commit -qam "edit View"
MRC=0; git merge-tree --write-tree --name-only s2 s5 >/dev/null 2>&1 || MRC=$?
if [ "$MRC" -eq 0 ]; then
    pass "5. editing an existing key while adding a new one merges"
else
    fail "5. editing an existing key while adding a new one conflicted"
fi

# 6. one side DELETES a key, the other edits it => CONFLICT, key named
branch s6; delkey "View"; git commit -qam "delete View"
OUT=$(git merge-tree --write-tree --name-only --messages s6 s5 2>&1 || true)
if echo "$OUT" | grep -q "View"; then
    pass "6. delete-vs-edit conflicts AND names the key"
else
    fail "6. the delete-vs-edit conflict did not name the key (output: $OUT)"
fi

# 7. one side DELETES a key, the other leaves it alone => the deletion wins
branch s7; delkey "View"; git commit -qam "delete View 2"
TREE=$(git merge-tree --write-tree s7 s2 2>/dev/null | head -1)
git cat-file -p "$TREE:$CAT" > merged2.json 2>/dev/null
if python3 -c "
import json
assert 'View' not in json.load(open('merged2.json'))['strings'], 'the deletion was lost'
" 2>/dev/null; then
    pass "7. a deletion wins over an untouched key"
else
    fail "7. the deletion was lost"
fi

# 8. a REAL git merge goes through the driver and leaves no conflict markers
git checkout -q s1
if git merge s2 >/dev/null 2>&1; then
    if grep -q '<<<<<<<' "$CAT"; then
        fail "8. the real merge succeeded but left conflict markers"
    else
        pass "8. a real git merge used the driver and left no conflict markers"
    fi
else
    fail "8. a real git merge failed (the driver did not run)"
fi
git merge --abort 2>/dev/null || true

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "merge-xcstrings: all tests passed"
    exit 0
fi
echo "merge-xcstrings: $FAILURES test(s) FAILED"
exit 1
