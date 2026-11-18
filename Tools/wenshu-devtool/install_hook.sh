#!/usr/bin/env bash
# Install the wenshu git hooks for the pollution vocabulary filter.
#
# THREE hooks, = = and AGENTS.md 1.4 names all three: = = the pre-commit
# hook scans the staged CONTENT, = = the commit-msg hook scans the
# COMMIT MESSAGE, = = and the pre-push hook scans the commits a push
# would send (= the commits a `--no-verify` commit made).  ⇒ Installing
# one of the three leaves the other two unguarded, = = and a fresh clone
# carries none of them (= = a fresh clone has no hook at all).
#
# Idempotent: re-running overwrites every hook.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FILTER_SCRIPT="$SCRIPT_DIR/commit_filter.py"

if [ ! -f "$FILTER_SCRIPT" ]; then
    echo "ERROR: $FILTER_SCRIPT not found" >&2
    exit 1
fi

GIT_DIR="$(git rev-parse --git-dir)"
HOOKS_DIR="$GIT_DIR/hooks"

mkdir -p "$HOOKS_DIR"

# 1) pre-commit: the staged CONTENT (= plus the drag regression suite).
cat > "$HOOKS_DIR/pre-commit" <<EOF
#!/usr/bin/env bash
# wenshu pre-commit hook. installed by Tools/wenshu-devtool/install_hook.sh
set -e
# 1) Pollution vocabulary filter (= AGENTS.md §8 + §12 hard rule).
python3 "$FILTER_SCRIPT" "\$@"
# 2) Drag regression test (= v0.28 ticket 028-011 §"Acceptance
#    criteria" #3: 'Pre-commit hook runs the suite (= shell
#    Tools/wenshu-devtool/hooks/pre-commit runs swift test
#    --filter DragRegressionTests)'. Runs only on commits that
#    touch Sources/WenshuApp/State/WorkspaceState.swift or
#    Sources/WenshuApp/Views/Workspace/* (= the drag UX
#    surface) = avoids slow tests on unrelated commits.
#    Use || true so a non-match (= the common case on most
#    commits) doesn't trigger set -e.
if (git diff --cached --name-only | grep -qE '^Sources/WenshuApp/(State/WorkspaceState\.swift|Views/Workspace/.*)$') || false; then
  echo "wenshu pre-commit: running DragRegressionTests (= drag UX files changed)"
  swift test --filter DragRegressionTests 2>&1 | tail -20
fi
EOF

chmod +x "$HOOKS_DIR/pre-commit"

# 2) commit-msg: the COMMIT MESSAGE (= git passes its path as argv 1).
cat > "$HOOKS_DIR/commit-msg" <<EOF
#!/usr/bin/env bash
# wenshu commit-msg hook. installed by Tools/wenshu-devtool/install_hook.sh
# (= AGENTS.md 1.4: the commit message carries no forbidden vocabulary).
set -e
python3 "$FILTER_SCRIPT" --hook=commit-msg "\$1"
EOF

chmod +x "$HOOKS_DIR/commit-msg"

# 3) pre-push: the COMMITS A PUSH WOULD SEND (= the commits a
#    `--no-verify` commit made, = = which the pre-commit hook never saw).
#    git hands the hook the refs it is about to update on STDIN, = = and
#    its first two ARGV are the remote's name and URL, = = which the
#    filter does not take (= = so the hook passes none).
cat > "$HOOKS_DIR/pre-push" <<EOF
#!/usr/bin/env bash
# wenshu pre-push hook. installed by Tools/wenshu-devtool/install_hook.sh
# (= AGENTS.md 1.4: no pushed commit carries forbidden vocabulary).
#
# git hands the hook the remote's name (= argv 1) and its URL (= argv 2)
# on argv, and the refs to update on STDIN.  ⇒ The remote is what the
# range is built against, = = because a local tracking ref says nothing
# about what the remote holds now.
set -e
python3 "$FILTER_SCRIPT" --hook=pre-push --remote="\$1" --remote-url="\$2"
EOF

chmod +x "$HOOKS_DIR/pre-push"

echo "wenshu hooks installed: pre-commit, commit-msg, pre-push"
echo "  in: $HOOKS_DIR"
echo "Filter: $FILTER_SCRIPT"
echo "Test: try a commit with forbidden vocab to verify it blocks."
