#!/usr/bin/env bash
# Test: the installer puts ALL THREE hooks in place (= AGENTS.md 1.4),
# and each hook blocks the thing it owns.
#
# WHY THIS FILE EXISTS: install_hook.sh used to install ONE hook (= the
# pre-commit one), = = so a fresh clone carried none of the three and
# the commit-msg guard (= the commit MESSAGE) and the pre-push guard
# (= the commits a push would send) were simply absent.  ⇒ This file
# runs the INSTALLER (= not a hand-written hook, = = which is what
# test_block_prepush.sh does) and proves each hook bites.
#
# Run from Tools/wenshu-devtool/tests/ directory.

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
case "$SCRIPT_PATH" in
    /*) ;;
    *)  SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
esac
SCRIPT_DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
DEVTOOL_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

git init -q
git config user.email "test@example.com"
git config user.name "Test"

# The installer needs its sibling (= the filter), = = so the devtool
# comes along as a whole.
cp -R "$DEVTOOL_DIR" ./devtool

# 1) The installer writes THREE hooks.
bash ./devtool/install_hook.sh > /dev/null
for hook in pre-commit commit-msg pre-push; do
    if [ ! -x ".git/hooks/$hook" ]; then
        echo "FAIL: the installer did not install .git/hooks/$hook"
        exit 1
    fi
done
echo "PASS: the installer installed pre-commit, commit-msg and pre-push"

# 2) The commit-msg hook blocks a polluted MESSAGE.
echo clean > a.md
git add a.md
if git commit -m "修真因 fix" 2>/dev/null; then
    echo "FAIL: commit-msg hook should have blocked a polluted commit message"
    exit 1
fi
git commit --no-verify -m "clean fix" -q
echo "PASS: the commit-msg hook blocked a polluted commit message"

# 3) The pre-commit hook blocks a polluted STAGED CONTENT.
echo "修真因 x" > b.md
git add b.md
if git commit -m "feat: a clean subject" 2>/dev/null; then
    echo "FAIL: pre-commit hook should have blocked polluted staged content"
    exit 1
fi
git reset -q
rm -f b.md
echo "PASS: the pre-commit hook blocked polluted staged content"

# 4) The pre-push hook blocks a push that carries a polluted commit
#    made with --no-verify (= the commit the pre-commit hook never saw).
#
#    WHY THE LAST COMMIT IS CLEAN: the pre-push mode reads the COMMITS
#    the push carries, = = and a scanner that only looked at the last
#    commit's message would pass this case.  ⇒ A polluted commit
#    followed by a clean one proves the scanner reads the range.
git init -q --bare remote.git
git remote add origin "$TMPDIR/remote.git"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
CLEAN_BEFORE="$(git rev-parse HEAD)"
echo "修真因 y" > c.md
git add c.md
git commit --no-verify -m "polluted message" -q
echo "clean afterwards" > d.md
git add d.md
git commit --no-verify -m "clean later message" -q
set +e
PUSH_OUT="$(git push origin "$BRANCH" 2>&1)"
PUSH_RC=$?
set -e
if [ "$PUSH_RC" -eq 0 ]; then
    echo "FAIL: pre-push hook should have blocked a push carrying a polluted commit"
    exit 1
fi
# The block must come from the HOOK (= = not from a refspec, a = = not
# from a hook that cannot push at all).
case "$PUSH_OUT" in
    *"forbidden vocabulary"*) ;;
    *)  echo "FAIL: the push failed for the wrong reason: $PUSH_OUT"
        exit 1
        ;;
esac
echo "PASS: the pre-push hook blocked a push carrying a polluted commit"

# 5) And the hooks must not block a CLEAN push (= = a guard that stops
#    everything is not a guard).  ⇒ The polluted commit is taken off the
#    branch first, = = so the push carries only clean commits.
git reset -q --hard "$CLEAN_BEFORE"
echo "clean push" > e.md
git add e.md
git commit --no-verify -m "clean subject" -q
if ! git push origin "$BRANCH" 2>/dev/null; then
    echo "FAIL: pre-push hook blocked a clean push"
    exit 1
fi
echo "PASS: a clean push went through"

# 6) The range must be built against the REMOTE's own refs (= = and not
#    the local tracking refs).
#
#    WHY THIS CASE: a tracking ref (= `refs/remotes/<remote>/<branch>`)
#    is a LOCAL cache of what the remote had, = = and it is often ahead
#    of what the remote holds now.  ⇒ With the tracking ref holding the
#    tip and the remote EMPTY, a range built from the tracking refs
#    scans NOTHING, = = and the push carries the polluted commit
#    unchecked.  ⇒ This case must FAIL on that code and PASS here.
git remote remove origin 2>/dev/null || true
git init -q --bare "$TMPDIR/remote2.git"
git remote add origin "$TMPDIR/remote2.git"
BRANCH2="$(git rev-parse --abbrev-ref HEAD)"
echo "修真因 z" > f.md
git add f.md
git commit --no-verify -m "polluted after the tracking ref" -q
# A local tracking ref that already holds the tip (= = the trap).
git update-ref "refs/remotes/origin/$BRANCH2" HEAD
# The remote is EMPTY (= = it never got the branch).
set +e
PUSH2_OUT="$(git push origin "$BRANCH2" 2>&1)"
PUSH2_RC=$?
set -e
if [ "$PUSH2_RC" -eq 0 ]; then
    echo "FAIL: the pre-push hook should have blocked the push"
    exit 1
fi
case "$PUSH2_OUT" in
    *"forbidden vocabulary"*) ;;
    *)  echo "FAIL: the push failed for the wrong reason: $PUSH2_OUT"
        exit 1
        ;;
esac
echo "PASS: the pre-push hook scans the remote's refs, not the local tracking ref"

# 7) A diff's CONTEXT is not this change's text.
#
#    WHY THIS CASE: a diff carries the added lines, = = the removed
#    ones, = = and the CONTEXT (= = the unchanged neighbours).  ⇒ The
#    context is the file as it was, = = so a forbidden token sitting in
#    it is the FILE's token, = = not this change's.  ⇒ Scanning the
#    context blocked any commit that merely touched a file near one.
#
#    ⇒ This case adds a CLEAN line to a file whose neighbour holds the
#    token: = = it must go through.
printf 'let a = 1\n// 修真因 x\nlet b = 2\n' > ctx.swift
git add ctx.swift
git commit --no-verify -m "baseline with a token nearby" -q
printf 'let a = 1\n// 修真因 x\nlet b = 2\nlet c = 3\n' > ctx.swift
git add ctx.swift
if ! git commit -m "feat: add a clean line beside a token" > /dev/null 2>&1; then
    echo "FAIL: the pre-commit hook blocked a commit that added no forbidden token"
    exit 1
fi
echo "PASS: a diff's context is not this change's text"
