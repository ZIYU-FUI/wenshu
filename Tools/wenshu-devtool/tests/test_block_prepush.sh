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

# A WORK REPO and a BARE REMOTE, = = side by side.
#
# WHY THIS SHAPE: the test used to build the remote by cloning the
# work tree and then DELETEING both (= `rm -rf "$TMPDIR/.git"
# "$TMPDIR/remote.git"`) = = so the push it measured failed with
# "Could not read from remote repository" = = and the hook never ran.
# ⇒ A push that cannot reach a remote proves nothing about the hook.
WORK="$TMPDIR/work"
REMOTE="$TMPDIR/remote.git"
git init -q --bare "$REMOTE"
mkdir -p "$WORK"
cd "$WORK"
git init -q
git config user.email "test@example.com"
git config user.name "Test"
git remote add origin "$REMOTE"

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

# A LATER, CLEAN commit (= = so a scanner that only reads the last
# commit's message would pass this case, = = and the test proves the
# scanner reads the RANGE the push carries).
echo "clean afterwards" > c.md
git add c.md
git commit -m "clean later message" --no-verify -q

# Now try to push — pre-push should BLOCK because the unpushed commit is polluted.
#
# WHY THE BRANCH NAME IS READ AND NOT WRITTEN: this test used to push
# "master", = = and a repository whose default branch is "main" answers
# "src refspec master does not match any" = = so the push failed before
# the hook ran, = = and the test passed without ever exercising it.
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
set +e
PUSH_OUT="$(git push origin "$BRANCH" 2>&1)"
PUSH_RC=$?
set -e
if [ "$PUSH_RC" -eq 0 ]; then
    echo "FAIL: pre-push should have blocked push of polluted commit"
    exit 1
fi
case "$PUSH_OUT" in
    *"forbidden vocabulary"*) ;;
    *)  echo "FAIL: the push failed for the wrong reason: $PUSH_OUT"
        exit 1
        ;;
esac
echo "PASS: pre-push blocked push of unpushed polluted commit (caught --no-verify bypass)"
