#!/bin/bash
# wenshu-shot-isolated.sh — one screenshot of the app, isolated from the
# user's focus and from every parallel run.
#
# Usage:
#   Scripts/wenshu-shot-isolated.sh <output-path> [bundle-path]
#
#   <output-path>  where the PNG is written (absolute, or relative to cwd)
#   [bundle-path]  an existing .app bundle to shoot; when omitted, the
#                  bundle is built with Scripts/build-app.sh
#
# Prints the absolute path of the capture on stdout, and nothing else.
# Every diagnostic goes to stderr.
#
# Why this exists: a visual-verification run must not take the boss's
# keyboard focus, must not write into another run's file, and must not
# share a preferences domain (= a saved window geometry) with another run.
# Three shared resources carry that risk, and each has one owner here:
#
#   focus    the app activates itself at launch. Launching it through
#            `open -g` keeps it out of the foreground; running the bundle
#            executable directly does not.
#   path     the capture path travels per process (`open --env`), never as a
#            machine-wide environment setting, so two runs cannot claim the
#            same file.
#   identity every build ships the same bundle identifier, so two runs
#            would share one preferences domain. Each copy carries its own
#            identifier and its own executable name.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "usage: $(basename "$0") <output-path> [bundle-path]" >&2
    exit 64
fi

OUT_PATH="$1"
BUNDLE_PATH="${2:-}"

if [[ "$OUT_PATH" != /* ]]; then
    OUT_PATH="$PWD/$OUT_PATH"
fi
mkdir -p "$(dirname "$OUT_PATH")"

# The capture delay is the app's own layout settle time; the app reads it
# from the environment (WS_SCREENSHOT_DELAY).
DELAY="${WS_SHOT_DELAY:-5}"
# How long to wait for the capture to land on disk.
CAPTURE_TIMEOUT="${WS_SHOT_TIMEOUT:-90}"

# Build the bundle when the caller did not bring one.
if [[ -z "$BUNDLE_PATH" ]]; then
    echo "wenshu-shot-isolated: building the app bundle" >&2
    bash "$PROJECT_ROOT/Scripts/build-app.sh" >&2
    BUNDLE_PATH="$PROJECT_ROOT/build/Wenshu.app"
fi
if [[ ! -d "$BUNDLE_PATH" ]]; then
    echo "wenshu-shot-isolated: no bundle at $BUNDLE_PATH" >&2
    exit 66
fi

# Every run gets its own copy of the bundle, under the caller's own scratch
# area, so two runs never share a bundle on disk.
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wenshu-shot-isolated.XXXXXX")"
RUN_TAG="$(uuidgen | tr 'A-Z' 'a-z' | cut -c1-12)"
BUNDLE_ID="com.wenshu.app.shot.$RUN_TAG"
EXEC_NAME="WenshuShot$RUN_TAG"
APP_COPY="$WORK_DIR/$EXEC_NAME.app"

cleanup() {
    # The copy is disposable: the app runs from inside it, so it is removed
    # only after the app is gone.
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cp -R "$BUNDLE_PATH" "$APP_COPY"

PLIST="$APP_COPY/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXEC_NAME" "$PLIST"

# The executable name in the plist is the name of the file in Contents/MacOS.
mv "$APP_COPY/Contents/MacOS/WenshuApp" "$APP_COPY/Contents/MacOS/$EXEC_NAME"

# The copy is signed again because the plist and the executable name changed.
codesign --force --deep --sign - "$APP_COPY" >/dev/null 2>&1

EXEC_PATH="$APP_COPY/Contents/MacOS/$EXEC_NAME"

# The pid of this run's own app. The match is an exact comparison against
# this run's unique executable path, never a name pattern, so another run's
# app is never a candidate.
own_pid() {
    ps -Ao pid=,comm= | awk -v want="$EXEC_PATH" '$2 == want { print $1; exit }'
}

# The capture settings travel with the launch, per process. A machine-wide
# environment setting would be overwritten by the next parallel run.
open -g \
    --env WS_SCREENSHOT=1 \
    --env "WS_SCREENSHOT_PATH=$OUT_PATH" \
    --env "WS_SCREENSHOT_DELAY=$DELAY" \
    --env WS_SCREENSHOT_EXIT=1 \
    "$APP_COPY"

# The capture lands on disk before the app exits. Wait for the file.
for _ in $(seq 1 "$CAPTURE_TIMEOUT"); do
    [[ -s "$OUT_PATH" ]] && break
    sleep 1
done

if [[ ! -s "$OUT_PATH" ]]; then
    # No capture: the app exits on its own after its capture attempt
    # (WS_SCREENSHOT_EXIT=1), so nothing is stopped here. The process is
    # reported instead, so the caller can see what is still alive.
    echo "wenshu-shot-isolated: no capture at $OUT_PATH after ${CAPTURE_TIMEOUT}s" >&2
    STILL_RUNNING="$(own_pid || true)"
    if [[ -n "$STILL_RUNNING" ]]; then
        echo "wenshu-shot-isolated: app pid $STILL_RUNNING is still running" >&2
    fi
    exit 1
fi

# The capture exists. The app exits on its own; when it has not, this run's
# own process is stopped, and only this run's own process.
OWN_PID="$(own_pid || true)"
if [[ -n "$OWN_PID" ]]; then
    kill "$OWN_PID" 2>/dev/null || true
    for _ in $(seq 1 10); do
        kill -0 "$OWN_PID" 2>/dev/null || break
        sleep 0.5
    done
    kill -9 "$OWN_PID" 2>/dev/null || true
fi

echo "$OUT_PATH"
