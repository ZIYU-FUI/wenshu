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
#   3) All hermes CLI invocations use the ABSOLUTE PATH
#      ~/.hermes/hermes-agent/venv/bin/hermes — this host's $PATH has
#      two wrappers (old ~/.local/bin/hermes with a PEP 604 bug, and
#      the venv hermes v0.20.0) and CC previously ran into the stale
#      one. Hard-coding the absolute path bypasses the lookup.
#
# 8/4 boundary decision (撤回 reel_text 1V1 复刻):
#   4) 8/4 装机 user 第七轮拍:ReelText 1V1 复刻动画效果极差,撤掉整套
#      reel_text 翻译,改回最简单打字机。**整套 4 文件架构撤回**:
#      grapheme.js / measure.js / reel-text.js 全删,install.sh 不再做
#      inline-concat,plugin.js 单文件直 rsync。
#   5) plugin.js 顶层 React hook 只剩 useState / useEffect / useRef
#      (打字机需要),import React, { useEffect, useRef, useState } from
#      'react'。其他 hook (useLayoutEffect / useImperativeHandle /
#      forwardRef / createElement) 撤掉。

set -euo pipefail

SRC="${HOME}/wenshu-plugin"
HERMES_HOME="${HOME}/.hermes"
# Absolute path to the v0.20.0 venv hermes. Do NOT rely on $PATH; see
# boundary decision #3 above.
HERMES_BIN="${HERMES_HOME}/hermes-agent/venv/bin/hermes"
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

# ============================================================
# source plugin.js 语法检查 + 直接 cp 到 runtime
# ============================================================
#
# 8/4 第七轮拍:撤回 4 文件架构,plugin.js 单文件直 rsync,SDK 拦截
# 100% 合规(plugin.js 顶层 import 只用 @hermes/plugin-sdk /
# react / react/jsx-runtime)。

log "syntax check source plugin.js"
if command -v node >/dev/null 2>&1; then
  if ! node --check "$SRC/desktop-plugin/plugin.js" 2>/dev/null; then
    fail "source plugin.js parse FAILED — fix before installing"
  fi
  log "  ✅ source plugin.js node --check ok"
fi

# ============================================================
# rsync:desktop-plugin/plugin.js → ~/.hermes/desktop-plugins/wenshu/
# ============================================================

log "rsync desktop plugin → ${DESKTOP_DST}"
mkdir -p "${DESKTOP_DST}"

# 清掉旧的 4 文件架构残留(grapheme.js / measure.js / reel-text.js
# —— 8/4 装机 user 第七轮拍撤 4 文件架构,运行时只保留 plugin.js)。
rm -f "${DESKTOP_DST}/grapheme.js" "${DESKTOP_DST}/measure.js" "${DESKTOP_DST}/reel-text.js"

cp "${SRC}/desktop-plugin/plugin.js" "${DESKTOP_DST}/plugin.js"
log "  ✅ ${DESKTOP_DST}/plugin.js (single file, post-cleanup)"

# 验:runtime plugin.js 字节数 ≤ 64KB(8/4 PM-direct 拍板硬约束。
# plugin.js 单文件 ~25KB,留 buffer 到 64KB 充裕。)
runtime_bytes=$(wc -c <"${DESKTOP_DST}/plugin.js" | tr -d ' ')
[ "$runtime_bytes" -le 65536 ] || \
  fail "runtime plugin.js = $runtime_bytes bytes (> 64KB limit)"
log "  ✅ runtime plugin.js = $runtime_bytes bytes (≤ 64KB)"

# 验:runtime plugin.js 语法
if command -v node >/dev/null 2>&1; then
  if ! node --check "${DESKTOP_DST}/plugin.js" 2>/dev/null; then
    fail "runtime plugin.js parse FAILED — abort"
  fi
  log "  ✅ runtime plugin.js node --check ok"
fi

# ============================================================
# rsync:python backend
# ============================================================

log "rsync python backend  → ${PY_PLUGIN_DST}"
mkdir -p "${PY_PLUGIN_DST}/dashboard"
rsync -a --delete "${SRC}/plugins/wenshu/manifest.yaml"     "${PY_PLUGIN_DST}/"
rsync -a --delete "${SRC}/plugins/wenshu/dashboard/"        "${PY_PLUGIN_DST}/dashboard/"

# ============================================================
# Ensure hermes profile 'wenshu' (no default inheritance)
# ============================================================

log "ensure hermes profile 'wenshu' (no default inheritance)"
mkdir -p "$PROFILE_DIR"

# Try the v0.20.0 venv hermes via ABSOLUTE PATH (bypasses $PATH, see
# boundary decision #3). If it errors out (e.g. this machine's venv
# has a Python 3.11 str|None typing import bug), fall back to a hand-
# written minimal config.yaml. Either way, we end up with a wenshu
# profile that does NOT inherit 'default'.
created_via="fallback"
if [ -x "$HERMES_BIN" ]; then
  if "$HERMES_BIN" profile create wenshu --no-default >/dev/null 2>&1; then
    created_via="hermes-cli"
  else
    log "hermes profile create failed (venv bug on this host) — using mkdir + minimal config.yaml fallback"
  fi
else
  log "hermes CLI not found at ${HERMES_BIN} — using mkdir + minimal config.yaml fallback"
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
log "next: ${HERMES_BIN} desktop → ⌘K → 'Reload desktop plugins' (or restart profile 'wenshu')"
