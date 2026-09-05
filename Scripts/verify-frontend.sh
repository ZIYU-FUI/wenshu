#!/usr/bin/env bash
#
# verify-frontend.sh · Wenshu · v0.38 frontend verify (= 14 items from
# `.scratch/2026-09-05-today-retrospective.md` §5)
#
# Launches build/Wenshu.app in the background, opens each UI element
# (= via keyboard shortcut or AppleScript), captures a screenshot, then
# kills wenshu.app at the end. If any item fails (= osascript / SIGKILL
# / bundle not built), the script marks that item as "verify failed;
# boss must check manually".
#
# First line = fact. Last line = fact.
#

set -u  # Fail on undefined variable. Do NOT use -e (= individual item
         # failures must not abort the script).

# --- Configuration -----------------------------------------------------------

WENSHU_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WENSHU_APP="${WENSHU_REPO}/build/Wenshu.app"
SCREENSHOT_DIR="${WENSHU_REPO}/.scratch/2026-09-05-verify-screenshots"
LOG_FILE="${SCREENSHOT_DIR}/verify-frontend.log"

# 14 verify items (= each = a label + a verification action).
# Action types:
#   - osascript=...: run an AppleScript snippet to drive the UI.
#   - shortcut=CMD+KEY: send a system-level keyboard shortcut.
#   - manual:     : capture screenshot only (= boss must verify visually).
VERIFY_ITEMS=(
  "01_paragraph_ai|osascript=tell application \"System Events\" to keystroke \"r\" using {command down}"
  "02_kanban_write|shortcut=CMD+1"
  "03_kanban_per_book|manual"
  "04_polish_topbar|manual"
  "05_polish_sidebar|manual"
  "06_polish_editor_statusbar|manual"
  "07_polish_modal_sheet|osascript=tell application \"System Events\" to keystroke \"n\" using {command down}"
  "08_polish_menu_popover|osascript=tell application \"System Events\" to keystroke \"m\" using {command down}"
  "09_wiki_link|osascript=tell application \"System Events\" to keystroke \"l\" using {command down}"
  "10_image_resolve|manual"
  "11_default_edit_tab|manual"
  "12_mode_toggle|osascript=tell application \"System Events\" to keystroke \"t\" using {command down}"
  "13_scope_picker|manual"
  "14_disabled_state|manual"
)

mkdir -p "${SCREENSHOT_DIR}"

log() { echo "[$(date +'%H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }
fail() { echo "[$(date +'%H:%M:%S')] FAIL: $*" | tee -a "${LOG_FILE}"; }

# --- Pre-flight checks --------------------------------------------------------

log "=== verify-frontend.sh start ==="
log "Repo:   ${WENSHU_REPO}"
log "App:    ${WENSHU_APP}"
log "Output: ${SCREENSHOT_DIR}"

if [ ! -d "${WENSHU_APP}" ]; then
  fail "Wenshu.app not found at ${WENSHU_APP}. Run 'swift build' first."
  log "Marking all 14 items as 'verify failed; boss must check manually'."
  for item in "${VERIFY_ITEMS[@]}"; do
    name="${item%%|*}"
    echo "verify failed; boss must check manually" > "${SCREENSHOT_DIR}/${name}.FAILED.txt"
  done
  exit 1
fi

# --- Launch wenshu.app --------------------------------------------------------

log "Launching ${WENSHU_APP}..."
open "${WENSHU_APP}"
LAUNCH_RC=$?
if [ "${LAUNCH_RC}" -ne 0 ]; then
  fail "open(1) returned ${LAUNCH_RC}. App launch failed."
  for item in "${VERIFY_ITEMS[@]}"; do
    name="${item%%|*}"
    echo "verify failed; boss must check manually" > "${SCREENSHOT_DIR}/${name}.FAILED.txt"
  done
  exit 1
fi

# Wait for the window to appear (= up to 30s).
log "Waiting for wenshu.app window to appear..."
for attempt in $(seq 1 30); do
  if osascript -e 'tell application "System Events" to (exists process "Wenshu")' 2>/dev/null | grep -q true; then
    log "wenshu.app is running (attempt ${attempt})."
    break
  fi
  sleep 1
done

if ! osascript -e 'tell application "System Events" to (exists process "Wenshu")' 2>/dev/null | grep -q true; then
  fail "wenshu.app window did not appear within 30s."
  for item in "${VERIFY_ITEMS[@]}"; do
    name="${item%%|*}"
    echo "verify failed; boss must check manually" > "${SCREENSHOT_DIR}/${name}.FAILED.txt"
  done
  osascript -e 'tell application "Wenshu" to quit' 2>/dev/null || true
  exit 1
fi

# Bring wenshu.app to front.
osascript -e 'tell application "Wenshu" to activate' 2>/dev/null || true
sleep 2

# --- Verify items ------------------------------------------------------------

for item in "${VERIFY_ITEMS[@]}"; do
  name="${item%%|*}"
  action="${item#*|}"
  log "Verifying ${name} (action=${action})..."

  # 1) Drive the UI action.
  if [[ "${action}" == osascript=* ]]; then
    script="${action#osascript=}"
    if ! osascript -e "${script}" 2>>"${LOG_FILE}"; then
      fail "${name}: osascript failed. Marking as verify-failed."
      echo "verify failed; boss must check manually (osascript error)" > "${SCREENSHOT_DIR}/${name}.FAILED.txt"
      continue
    fi
  elif [[ "${action}" == shortcut=* ]]; then
    shortcut="${action#shortcut=}"
    log "  shortcut=${shortcut} (= manual: not driving the UI; boss must trigger)"
  fi

  # Give the UI a moment to update.
  sleep 1

  # 2) Capture screenshot.
  screenshot_path="${SCREENSHOT_DIR}/${name}.png"
  if screencapture -x -o "${screenshot_path}" 2>>"${LOG_FILE}"; then
    log "  screenshot saved to ${screenshot_path}"
    if [ ! -s "${screenshot_path}" ]; then
      fail "  screenshot is empty (= 0 bytes). Verify may have failed."
      echo "verify failed; boss must check manually (empty screenshot)" > "${SCREENSHOT_DIR}/${name}.FAILED.txt"
      rm -f "${screenshot_path}"
    fi
  else
    fail "  screencapture failed. Marking as verify-failed."
    echo "verify failed; boss must check manually (screencapture error)" > "${SCREENSHOT_DIR}/${name}.FAILED.txt"
  fi
done

# --- Cleanup ------------------------------------------------------------------

log "Killing wenshu.app..."
osascript -e 'tell application "Wenshu" to quit' 2>/dev/null || true
sleep 1
# Fallback: kill the process if AppleScript quit did not take.
if osascript -e 'tell application "System Events" to (exists process "Wenshu")' 2>/dev/null | grep -q true; then
  pkill -x "Wenshu" 2>/dev/null || true
  sleep 1
fi

# --- Summary ------------------------------------------------------------------

succeeded=$(find "${SCREENSHOT_DIR}" -name "*.png" -size +0 2>/dev/null | wc -l | tr -d ' ')
failed=$(find "${SCREENSHOT_DIR}" -name "*.FAILED.txt" 2>/dev/null | wc -l | tr -d ' ')

log "=== verify-frontend.sh done ==="
log "Screenshots saved: ${succeeded}/14"
log "Verify-failed (manual boss check needed): ${failed}/14"
log "Screenshots dir: ${SCREENSHOT_DIR}"

# First line = fact. Last line = fact.
