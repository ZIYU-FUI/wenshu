#!/usr/bin/env bash
# Test: only allowed tokens in staged .md → commit allowed.
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

# Only allowed tokens (per AGENTS.md §12)
cat > test.md <<EOF
# test
老板 拍 文枢 wenshu ※ project
EOF
git add test.md

# Commit must succeed
if git commit -m "老板 拍 test" 2>/dev/null; then
    echo "PASS: commit allowed with only project-mandated tokens"
else
    echo "FAIL: commit should have been allowed"
    exit 1
fi