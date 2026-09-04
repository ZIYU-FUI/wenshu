#!/usr/bin/env bash
# Test: forbidden vocab in staged file content (added lines, not context) blocks commit.
# Regression test: the OLD hook scanned context lines too, the NEW hook only scans +/-.
# This test pins the new behavior so we don't accidentally re-allow historical pollution.
# Run from Tools/wenshu-devtool/tests/ directory.

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
case "$SCRIPT_PATH" in
    /*) ;;
    *)  SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
esac
SCRIPT_DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
FILTER_SCRIPT="$SCRIPT_DIR/../commit_filter.py"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

git init -q
git config user.email "test@example.com"
git config user.name "Test"

cp "$FILTER_SCRIPT" .
mkdir -p .git/hooks
printf '#!/usr/bin/env bash\nexec python3 %s/commit_filter.py --hook=pre-commit\n' "$(pwd)" > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# First commit a clean file (so the context line has clean content).
cat > test.md <<EOF
# test
Clean baseline.
EOF
git add test.md
git commit -m "baseline" --no-verify -q

# Now modify it: add a polluted line.
cat >> test.md <<EOF
New line with forbidden vocab: 修真 渡劫
EOF
git add test.md

# Commit must FAIL (the added line is forbidden).
if git commit -m "add line" 2>/dev/null; then
    echo "FAIL: added-line pollution should have been blocked"
    exit 1
fi
echo "PASS: pre-commit blocked added-line pollution"
