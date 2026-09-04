#!/usr/bin/env bash
# Install wenshu pre-commit hook for pollution vocabulary filter.
# Idempotent: re-running overwrites existing hook.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FILTER_SCRIPT="$SCRIPT_DIR/commit_filter.py"

if [ ! -f "$FILTER_SCRIPT" ]; then
    echo "ERROR: $FILTER_SCRIPT not found" >&2
    exit 1
fi

GIT_DIR="$(git rev-parse --git-dir)"
HOOK_PATH="$GIT_DIR/hooks/pre-commit"

mkdir -p "$(dirname "$HOOK_PATH")"

cat > "$HOOK_PATH" <<EOF
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

chmod +x "$HOOK_PATH"

echo "wenshu pre-commit hook installed: $HOOK_PATH"
echo "Filter: $FILTER_SCRIPT"
echo "Test: try a commit with forbidden vocab to verify it blocks."