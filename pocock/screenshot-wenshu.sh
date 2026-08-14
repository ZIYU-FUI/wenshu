#!/bin/bash
# screenshot-wenshu.sh · Wenshu (Wenshu) · one-shot self-screenshot helper
#
# Boss 8/14 12:38 + 8/15 14:48: every code change must produce a screenshot
# for phone verification. The agent runs in a Hermes Agent TUI session that
# can't see the wenshu window via system screencapture (= virtual desktop
# returns 0×0 black). The only working path is to render inside the app
# itself, using the live NSHostingView backing store.
#
# Usage:
#   pocock/screenshot-wenshu.sh                       # one-shot, default path
#   pocock/screenshot-wenshu.sh --path foo.png        # custom output
#   pocock/screenshot-wenshu.sh --delay 4             # first-capture delay (s)
#   pocock/screenshot-wenshu.sh --loop 5              # capture every 5s, no exit
#   pocock/screenshot-wenshu.sh --no-exit             # one-shot but keep running
#   pocock/screenshot-wenshu.sh --kill                # kill a running loop / one-shot
#
# Standard agent call (writes to /tmp, prints absolute path on stdout):
#   PNG=$(pocock/screenshot-wenshu.sh --path /tmp/wenshu-$(date +%s).png)
#   echo "MEDIA:$PNG"
#
# Returns the PNG path on stdout when successful. Exits non-zero on failure
# (= build error, screenshot env not wired, image too small = empty render).

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
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *) echo "screenshot-wenshu: unknown arg $1" >&2; exit 64 ;;
    esac
done

PIDFILE="/tmp/wenshu-selfshot.pid"

# --kill: stop any running loop / one-shot
if [[ "$KILL" -eq 1 ]]; then
    if [[ -f "$PIDFILE" ]]; then
        OLD=$(cat "$PIDFILE")
        kill "$OLD" 2>/dev/null && echo "killed pid=$OLD" || echo "no live pid=$OLD"
        rm -f "$PIDFILE"
    else
        echo "no pidfile at $PIDFILE"
    fi
    # Belt + suspenders: kill anything bound to port /tmp/wenshu-selfshot
    pkill -f "WS_SCREENSHOT" 2>/dev/null || true
    exit 0
fi

# Build first (= code-change verification). Build is fast on incremental.
echo "== swift build =="
if ! swift build 2>&1 | tail -5; then
    echo "screenshot-wenshu: build failed" >&2
    exit 1
fi

# Kill any prior wenshu process so the new binary actually launches.
pkill -f "Wenshu.app/Contents/MacOS/Wenshu" 2>/dev/null || true
pkill -f "swift run WenshuApp" 2>/dev/null || true
sleep 0.3

# Build env
ENV_ARGS=(WS_SCREENSHOT=1 WS_SCREENSHOT_PATH="$PATH_OUT" WS_SCREENSHOT_DELAY="$DELAY")
if [[ -n "$LOOP_INTERVAL" ]]; then
    ENV_ARGS+=(WS_SCREENSHOT_LOOP="$LOOP_INTERVAL" WS_SCREENSHOT_EXIT=0)
elif [[ "$EXIT_AFTER" -eq 1 ]]; then
    ENV_ARGS+=(WS_SCREENSHOT_EXIT=1)
else
    ENV_ARGS+=(WS_SCREENSHOT_EXIT=0)
fi

# Launch via `swift run` (NOT open -W on the .app bundle).
# Owner 8/15 16:18 discovered that `open -W` on the SwiftPM .app bundle
# loses the WS_SCREENSHOT env vars somewhere between launchd and the
# process (no log output even though applicationDidFinishLaunching
# would have printed them). `swift run` keeps the env chain intact
# and applicationDidFinishLaunching fires reliably. This is the
# v0.02.0 path; v0.04.0+ (= signed .app bundle) should revisit.
echo "== swift run WenshuApp =="
env "${ENV_ARGS[@]}" swift run WenshuApp > /tmp/wenshu-selfshot.log 2>&1 &
APP_PID=$!
echo "$APP_PID" > "$PIDFILE"

# If looping, detach and return immediately. If one-shot, wait for exit code.
if [[ -n "$LOOP_INTERVAL" ]]; then
    echo "looping capture every ${LOOP_INTERVAL}s; pid=$APP_PID"
    echo "$PATH_OUT"
    exit 0
fi

# One-shot: wait for the app to exit (= it self-exits after capture).
WAIT_MAX=$(( ${DELAY%.*} + 6 ))
for i in $(seq 1 "$WAIT_MAX"); do
    if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
    sleep 1
done
# Force kill if still running (capture failed → process hung)
if kill -0 "$APP_PID" 2>/dev/null; then
    echo "screenshot-wenshu: app still running after ${WAIT_MAX}s, killing" >&2
    kill "$APP_PID" 2>/dev/null || true
fi
rm -f "$PIDFILE"

# Verify the PNG exists and has reasonable size (= ≥50KB = live data, not
# an empty ImageRenderer fallback).
if [[ ! -f "$PATH_OUT" ]]; then
    echo "screenshot-wenshu: no PNG at $PATH_OUT" >&2
    tail -20 /tmp/wenshu-selfshot.log >&2
    exit 2
fi

BYTES=$(stat -f%z "$PATH_OUT" 2>/dev/null || stat -c%s "$PATH_OUT")
if [[ "$BYTES" -lt 50000 ]]; then
    echo "screenshot-wenshu: PNG too small ($BYTES bytes) — likely empty render" >&2
    exit 3
fi

echo "OK $PATH_OUT ($BYTES bytes)"
echo "$PATH_OUT"