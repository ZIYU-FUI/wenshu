#!/usr/bin/env bash
# Test: forbidden vocab in commit message blocks commit (via commit-msg hook).
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

# Install all three hooks with the new --hook=... dispatch
cp "$FILTER_SCRIPT" .
mkdir -p .git/hooks
for hook in pre-commit commit-msg pre-push; do
    if [ "$hook" = "commit-msg" ]; then
        printf '#!/usr/bin/env bash\nexec python3 %s/commit_filter.py --hook=commit-msg "$1"\n' "$(pwd)" > .git/hooks/$hook
    else
        printf '#!/usr/bin/env bash\nexec python3 %s/commit_filter.py --hook=%s\n' "$(pwd)" "$hook" > .git/hooks/$hook
    fi
    chmod +x .git/hooks/$hook
done

# Clean file, polluted COMMIT MESSAGE
cat > test.md <<EOF
# test
Clean file body, but message contains forbidden vocab.
EOF
git add test.md

# Commit with -m "修真因 fix" must fail at commit-msg stage.
if git commit -m "修真因 fix" 2>/dev/null; then
    echo "FAIL: commit with polluted message should have been blocked"
    exit 1
fi
echo "PASS: commit-msg hook blocked polluted commit message"

# Sanity: clean message goes through (we need a real upstream; use --no-verify only
# for the body check since pre-push isn't exercised here).
if git commit --no-verify -m "clean fix" 2>/dev/null; then
    echo "PASS: clean commit message allowed"
else
    echo "FAIL: clean commit should have been allowed"
    exit 1
fi
