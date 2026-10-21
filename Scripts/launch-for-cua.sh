#!/bin/bash
# Launch wenshu release build for CUA testing (= background, headless-safe).
# After boss allows cua-driver in System Settings > Privacy & Security,
# the CUA tool can focus wenshu.app and run UI tests.
#
# Usage:
#   ./scripts/launch-for-cua.sh
#   (then in another terminal) run the CUA capture sequence
#
# Pre-flight: boss has allowed cua-driver once (Privacy & Security).
set -e

cd "$(dirname "$0")/.."

if [ ! -x .build/release/WenshuApp ]; then
    echo "[launch] release binary not found, building..."
    swift build -c release
fi

# Kill any prior wenshu instance belonging to THIS tree.
#
# The pattern is anchored to this tree's absolute path on purpose. A loose
# pattern like "WenshuApp" matches every build in the repo, because every
# tree's path ends that way — it would kill the shared checkout's instance,
# every worktree's instance, and other sessions' scratch builds. The repo
# runs several agents at once, so a cross-tree kill destroys someone
# else's running app.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "[launch] killing this tree's existing wenshu instances..."
pkill -f "$REPO_ROOT/build/Wenshu.app/Contents/MacOS/WenshuApp" 2>/dev/null || true
pkill -f "$REPO_ROOT/.build/release/WenshuApp" 2>/dev/null || true
sleep 1

echo "[launch] starting wenshu release build in background..."
nohup .build/release/WenshuApp > /tmp/wenshu-cua.log 2>&1 &
WENSHU_PID=$!
echo "[launch] wenshu PID = $WENSHU_PID"
echo "[launch] log = /tmp/wenshu-cua.log"
echo "[launch] ready for CUA: computer_use list_apps / focus_app wenshu"