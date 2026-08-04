#!/usr/bin/env bash
# WENSHU plugin installer — rsync scaffold → hermes runtime.
#
# Source of truth: ~/wenshu-plugin/ (git repo)
# Runtime:        ~/.hermes/desktop-plugins/wenshu/ + ~/.hermes/plugins/wenshu/
# Profile:        ~/.hermes/profiles/wenshu/  (created if missing)
#
# AGENTS.md v0.2 §5 / §12 boundary:
#   - We rsync INTO ~/.hermes/, never edit hermes-owned files in place.
#   - We do NOT install/upgrade/modify the hermes CLI itself.
#   - We do NOT touch other profiles (aif, designer, my-pm, ...).
#
# v0.1.0 boundary decisions captured in this script:
#   1) If `hermes profile create` fails (e.g. venv typing-import bug on
#      this machine), fall back to mkdir + minimal config.yaml — that
#      satisfies the "create wenshu profile, do NOT inherit default" rule
#      from AGENTS.md §7 (wenshu profile is hermes-profile-体系内的一个
#      profile,不复用 default).
#   2) The desktop plugin is rsynced to the GLOBAL ~/.hermes/desktop-
#      plugins/wenshu/ (per AGENTS.md §13 runtime layout). The profile-
#      scoped variant is NOT used at v0.1.0.

set -euo pipefail

SRC="${HOME}/wenshu-plugin"
HERMES_HOME="${HOME}/.hermes"
DESKTOP_DST="${HERMES_HOME}/desktop-plugins/wenshu"
PY_PLUGIN_DST="${HERMES_HOME}/plugins/wenshu"
PROFILE_DIR="${HERMES_HOME}/profiles/wenshu"
PROFILE_CFG="${PROFILE_DIR}/config.yaml"

log()  { printf '[install] %s\n' "$*"; }
fail() { printf '[install] FAIL: %s\n' "$*" >&2; exit 1; }

[ -d "$SRC" ] || fail "source $SRC missing"
[ -f "$SRC/desktop-plugin/plugin.js" ] || fail "desktop-plugin/plugin.js missing"
[ -f "$SRC/plugins/wenshu/manifest.yaml" ] || fail "plugins/wenshu/manifest.yaml missing"
[ -f "$SRC/plugins/wenshu/dashboard/plugin_api.py" ] || fail "plugin_api.py missing"

log "rsync desktop plugin → ${DESKTOP_DST}"
mkdir -p "$DESKTOP_DST"
rsync -a --delete "${SRC}/desktop-plugin/" "${DESKTOP_DST}/"

log "rsync python backend  → ${PY_PLUGIN_DST}"
mkdir -p "${PY_PLUGIN_DST}/dashboard"
rsync -a --delete "${SRC}/plugins/wenshu/manifest.yaml"     "${PY_PLUGIN_DST}/"
rsync -a --delete "${SRC}/plugins/wenshu/dashboard/"        "${PY_PLUGIN_DST}/dashboard/"

log "ensure hermes profile 'wenshu' (no default inheritance)"
mkdir -p "$PROFILE_DIR"

# Try hermes native CLI first. If it errors out (e.g. this machine's
# venv has a Python 3.11 str|None typing import bug), fall back to a
# hand-written minimal config.yaml. Either way, we end up with a wenshu
# profile that does NOT inherit 'default'.
created_via="fallback"
if command -v hermes >/dev/null 2>&1; then
  if hermes profile create wenshu --no-default >/dev/null 2>&1; then
    created_via="hermes-cli"
  else
    log "hermes profile create failed (venv bug on this host) — using mkdir + minimal config.yaml fallback"
  fi
elif [ -x "${HERMES_HOME}/hermes" ]; then
  if "${HERMES_HOME}/hermes" profile create wenshu --no-default >/dev/null 2>&1; then
    created_via="hermes-wrapper"
  else
    log "hermes wrapper CLI failed (venv bug on this host) — using mkdir + minimal config.yaml fallback"
  fi
else
  log "hermes CLI not found — using mkdir + minimal config.yaml fallback"
fi

# Always (re-)stamp the plugin-enable line in the wenshu profile config,
# regardless of how the profile was created. We only touch wenshu's
# own config.yaml; other profiles (aif / designer / my-pm) are off-limits.
if [ ! -f "$PROFILE_CFG" ]; then
  cat > "$PROFILE_CFG" <<'YAML'
_config_version: 33
plugins:
  enabled:
    - wenshu
YAML
  log "wrote minimal wenshu profile config (created_via=${created_via})"
else
  if grep -q '^plugins:' "$PROFILE_CFG"; then
    if grep -q 'enabled:' "$PROFILE_CFG"; then
      # replace existing wenshu entry or append if missing
      if grep -q '^\s*-\s*wenshu\b' "$PROFILE_CFG"; then
        log "plugins.enabled already contains wenshu — leaving config.yaml untouched"
      else
        log "appending 'wenshu' to existing plugins.enabled list"
        # naive but safe: add a bullet right after the first 'enabled:' line
        awk '
          /^[[:space:]]*enabled:[[:space:]]*$/ {print; print "    - wenshu"; next}
          {print}
        ' "$PROFILE_CFG" > "${PROFILE_CFG}.tmp" && mv "${PROFILE_CFG}.tmp" "$PROFILE_CFG"
      fi
    else
      log "config.yaml has plugins: but no enabled: — appending enabled list"
      printf '\n  enabled:\n    - wenshu\n' >> "$PROFILE_CFG"
    fi
  else
    log "adding plugins.enabled: [wenshu] to wenshu profile config"
    printf '\nplugins:\n  enabled:\n    - wenshu\n' >> "$PROFILE_CFG"
  fi
fi

log "done. profile=${PROFILE_DIR} (created_via=${created_via})"
log "next: hermes desktop → ⌘K → 'Reload desktop plugins' (or restart profile 'wenshu')"
