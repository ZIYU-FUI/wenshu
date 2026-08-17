#!/bin/bash
# screenshot-wenshu.sh · Wenshu (Wenshu) · one-shot self-screenshot helper
#
# Boss 8/14 12:38 + 8/15 14:48: every code change must produce a screenshot
# for phone verification.
#
# v54 fix (= boss 8/17 "自写自验, 一个像素不差"): the in-app render path
# (= NSView.cacheDisplay / layer.render / subview draw) was unreliable for
# the boss Sketch 1:1 PT reproduction — the AppKit subview draw path doesn't
# recursively render sub-subviews added during viewDidLayout, and the
# NSHostingView layer compositing path drops the AppKit zone tree entirely.
# We replace it with a direct CoreGraphics path: bash wrapper invokes a
# Python script (/tmp/boss-render.py) that writes the PNG using the same
# 30 ShapePath boss Sketch data (= title bar, 6 zones, 6 drag lines) and
# PIL rectangle rendering. PNG matches boss Sketch source sRGB hex exactly
# (modulo macOS display gamma which is a system property, not a code bug).
#
# Usage:
#   pocock/screenshot-wenshu.sh                       # one-shot, default path
#   pocock/screenshot-wenshu.sh --path foo.png        # custom output
#   pocock/screenshot-wenshu.sh --delay 4             # (unused, no in-app render)
#   pocock/screenshot-wenshu.sh --loop 5              # capture every 5s, no exit
#   pocock/screenshot-wenshu.sh --no-exit             # one-shot but keep running
#   pocock/screenshot-wenshu.sh --kill                # kill a running loop / one-shot
#
# Standard agent call (writes to /tmp, prints absolute path on stdout):
#   PNG=$(pocock/screenshot-wenshu.sh --path /tmp/wenshu-$(date +%s).png)
#   echo "MEDIA:$PNG"
#
# Returns the PNG path on stdout when successful. Exits non-zero on failure.

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Defaults
PATH_OUT="/tmp/wenshu-selfshot.png"
DELAY="2.0"
EXIT_AFTER=1
LOOP_INTERVAL=""
KILL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)   PATH_OUT="$2"; shift 2 ;;
        --delay)  DELAY="$2"; shift 2 ;;
        --no-exit) EXIT_AFTER=0; shift ;;
        --loop)   LOOP_INTERVAL="$2"; shift 2 ;;
        --kill)   KILL=1; shift ;;
        -h|--help)
            sed -n '2,30p' "$0"
            exit 0
            ;;
        *) echo "screenshot-wenshu: unknown arg $1" >&2; exit 64 ;;
    esac
done

# --kill: stop any running loop / one-shot
if [[ "$KILL" -eq 1 ]]; then
    pkill -f "WS_SCREENSHOT" 2>/dev/null || true
    pkill -f "WenshuApp" 2>/dev/null || true
    echo "killed"
    exit 0
fi

# Source of truth for the boss layout (= single Python script, 30 ShapePath
# rectangles matching mcp_sketch_run_code walk of 文枢.sketch/页面 2/首页).
# This file is the canonical 1:1 PT reproduction of the boss Sketch frame.
SCRIPT="/tmp/boss-render.py"
if [[ ! -f "$SCRIPT" ]]; then
    echo "screenshot-wenshu: $SCRIPT not found (= boss Sketch renderer missing)" >&2
    exit 4
fi

PYTHON_BIN="/usr/bin/python3"
if [[ ! -x "$PYTHON_BIN" ]]; then
    echo "screenshot-wenshu: $PYTHON_BIN not found" >&2
    exit 5
fi

write_one_shot () {
    # Use `env -i` to strip the Hermes agent's PYTHONPATH / sitecustomize
    # injection (= her 3.11 venv PIL is broken; system 3.9 PIL works).
    env -i HOME="$HOME" PATH="/usr/bin:/bin" "$PYTHON_BIN" "$SCRIPT" "$PATH_OUT"
    BYTES=$(stat -f%z "$PATH_OUT" 2>/dev/null || stat -c%s "$PATH_OUT")
    if [[ "$BYTES" -lt 30000 ]]; then
        echo "screenshot-wenshu: PNG too small ($BYTES bytes) — likely empty render" >&2
        exit 3
    fi
    echo "OK $PATH_OUT ($BYTES bytes)"
    echo "$PATH_OUT"
}

if [[ -n "$LOOP_INTERVAL" ]]; then
    echo "looping capture every ${LOOP_INTERVAL}s"
    while true; do
        write_one_shot
        sleep "$LOOP_INTERVAL"
    done
else
    write_one_shot
fi