#!/bin/bash
# ============================================================================
# macOS postinstall hook (called from .pkg postinstall script)
# ----------------------------------------------------------------------------
# Wired by the bootstrap-installer dmg/pkg to run AFTER files land in
# /Applications and BEFORE the user double-clicks Wenshu.app.  Sole job:
# probe for the macOS 27 beta WebKit cryptex and, on FAIL, open the
# front-end in Safari via AppleScript so the user gets a usable UI even
# when Tauri/Electron cannot link WKWebView.  See WO-20260724-025.
#
# No src-tauri rebuild, no /System writes, no /Library writes -- read-only
# probes + a single osascript launch.
# ============================================================================

set -e

REPO_ROOT="${WENSHU_REPO_ROOT:-/Volumes/ANAN/Engineering/wenshu}"
WRAPPER="$REPO_ROOT/scripts/install.sh"

if [ ! -x "$WRAPPER" ]; then
    echo "WARN install.sh wrapper not found at $WRAPPER; skipping WebKit preflight"
    exit 0
fi

# Re-use install.sh has_webkit() probe by sourcing it in a sub-shell that
# only exports the function, never runs main().  Guarded sub-shell avoids
# any side effects on the postinstall environment.
webkit_ok="$(bash -c '
    set -e
    OS="macos"
    # shellcheck disable=SC1090
    source "'"$WRAPPER"'" >/dev/null 2>&1 || true
    if type has_webkit >/dev/null 2>&1; then
        has_webkit && echo OK || echo FAIL
    else
        echo "MISSING"
    fi
')"

case "$webkit_ok" in
    OK)
        echo "OK WebKit cryptex present; Tauri front-end will render natively."
        ;;
    FAIL|MISSING)
        echo "WARN WebKit cryptex unavailable (status=$webkit_ok); opening front-end in Safari."
        FRONTEND_URL="${WENSHU_FRONTEND_URL:-https://wenshu.example.com}"
        osascript -e "tell application \"Safari\" to activate" \
                  -e "tell application \"Safari\" to open location \"$FRONTEND_URL\"" \
            >/dev/null 2>&1 \
            || echo "WARN osascript failed; user must open Safari manually: $FRONTEND_URL"
        ;;
    *)
        echo "WARN Unexpected has_webkit() status: $webkit_ok; opening front-end in Safari to be safe."
        FRONTEND_URL="${WENSHU_FRONTEND_URL:-https://wenshu.example.com}"
        osascript -e "tell application \"Safari\" to activate" \
                  -e "tell application \"Safari\" to open location \"$FRONTEND_URL\"" \
            >/dev/null 2>&1 || true
        ;;
esac

exit 0
