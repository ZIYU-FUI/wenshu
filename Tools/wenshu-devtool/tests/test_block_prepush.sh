#!/usr/bin/env bash
# Test: pre-push hook blocks push when an unpushed commit contains forbidden vocab,
# EVEN IF the commit was created with --no-verify.
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

# Build a local "remote" (separate bare repo) so we can push to it.
git clone -q --bare "$TMPDIR" "$TMPDIR/remote.git"
cd "$TMPDIR"
git remote add origin "$TMPDIR/remote.git"
# But we're back in the empty working dir after clone, so:
cd "$TMPDIR"

# Re-init the working dir (clone above just made remote.git).
rm -rf "$TMPDIR/.git" "$TMPDIR/remote.git"
git init -q
git config user.email "test@example.com"
git config user.name "Test"
git remote add origin "$TMPDIR/remote.git"

# Install hooks
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

# Initial baseline commit
echo "clean" > a.md
git add a.md
git commit -m "baseline" --no-verify -q

# Create a polluted commit via --no-verify (simulates agent bypassing pre-commit)
echo "修真因 fix" > b.md
git add b.md
git commit -m "修真因 patch" --no-verify -q

# Now try to push — pre-push should BLOCK because the unpushed commit is polluted.
if git push origin master 2>/dev/null; then
    echo "FAIL: pre-push should have blocked push of polluted commit"
    exit 1
fi
echo "PASS: pre-push blocked push of unpushed polluted commit (caught --no-verify bypass)"
