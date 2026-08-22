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
exec python3 "$FILTER_SCRIPT"
EOF

chmod +x "$HOOK_PATH"

echo "wenshu pre-commit hook installed: $HOOK_PATH"
echo "Filter: $FILTER_SCRIPT"
echo "Test: try a commit with forbidden vocab to verify it blocks."