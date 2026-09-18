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

echo "[launch] killing any existing wenshu instances..."
pkill -f WenshuApp 2>/dev/null || true
sleep 1

echo "[launch] starting wenshu release build in background..."
nohup .build/release/WenshuApp > /tmp/wenshu-cua.log 2>&1 &
WENSHU_PID=$!
echo "[launch] wenshu PID = $WENSHU_PID"
echo "[launch] log = /tmp/wenshu-cua.log"
echo "[launch] ready for CUA: computer_use list_apps / focus_app wenshu"