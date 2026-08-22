#!/usr/bin/env bash
# Test: forbidden vocab in staged .md blocks commit.
# Run from Tools/wenshu-devtool/tests/ directory.

set -e

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

git init -q
git config user.email "test@example.com"
git config user.name "Test"

# Copy filter script into tmpdir
cp "$OLDPWD/../commit_filter.py" .
mkdir -p .git/hooks
echo "exec python3 $(pwd)/commit_filter.py" > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Forbidden vocab in staged .md
cat > test.md <<EOF
# test
This line should block: 修真 渡劫 筑基
EOF
git add test.md

# Commit must fail
if git commit -m "test" 2>/dev/null; then
    echo "FAIL: commit should have been blocked"
    exit 1
fi

echo "PASS: commit blocked by forbidden vocab filter"