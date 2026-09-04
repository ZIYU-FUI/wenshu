#!/usr/bin/env bash
# Test: only allowed tokens in staged .md → commit allowed.
# Run from Tools/wenshu-devtool/tests/ directory.

set -e

# Resolve script directory (works regardless of how script is invoked).
# Resolve script directory robustly across invocation styles
# (bash script.sh vs /full/path/script.sh vs cd ... && bash script.sh).
SCRIPT_PATH="${BASH_SOURCE[0]}"
# If relative, resolve via pwd.
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

# Copy filter script into tmpdir
cp "$FILTER_SCRIPT" .
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

# Test: allowlisted file (e.g. .github/PULL_REQUEST_TEMPLATE.md) with
# forbidden vocab → commit allowed (POLLUTION_ALLOWLIST skip).
echo "---"
echo "Test: allowlisted file with forbidden vocab → commit allowed"
TMPDIR2=$(mktemp -d)
cd "$TMPDIR2"
git init -q
git config user.email "test@example.com"
git config user.name "Test"
cp "$FILTER_SCRIPT" .
mkdir -p .git/hooks .github
echo "exec python3 $(pwd)/commit_filter.py" > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
# Forbidden vocab in .github/PULL_REQUEST_TEMPLATE.md → allowed via POLLUTION_ALLOWLIST.
cat > .github/PULL_REQUEST_TEMPLATE.md <<EOF
# Pollution check
- [ ] No 修真 渡劫 筑基 返虚 结丹 金丹 元婴 飞升 天劫 雷劫 心魔 魔障
EOF
git add .github/PULL_REQUEST_TEMPLATE.md
if git commit -m "test allowlist" 2>/dev/null; then
    echo "PASS: allowlisted file with forbidden vocab allowed"
else
    echo "FAIL: allowlisted file should skip pollution check"
    exit 1
fi
cd /
rm -rf "$TMPDIR2"
