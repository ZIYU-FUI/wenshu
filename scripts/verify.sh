#!/usr/bin/env bash
# WENSHU scaffold verifier — local-only checks, no hermes interaction.
#
# AGENTS.md v0.2 §12: CC MUST verify before claiming done.
#   - plugin.js parses (node --check)
#   - plugin_api.py imports cleanly + 8 editor modules import
#   - hermes profile 'wenshu' exists on disk
#   - rsync targets have the right files (only if a previous install ran)

set -euo pipefail

SRC="${HOME}/wenshu-plugin"
HERMES_HOME="${HOME}/.hermes"
PROFILE_DIR="${HERMES_HOME}/profiles/wenshu"

ok=0
fail=0
pass() { printf '  ✅ %s\n' "$*"; ok=$((ok+1)); }
miss() { printf '  ❌ %s\n' "$*"; fail=$((fail+1)); }
hdr()  { printf '\n=== %s ===\n' "$*"; }

hdr "1. plugin.js syntax"
if command -v node >/dev/null 2>&1; then
  if node --check "$SRC/desktop-plugin/plugin.js"; then
    pass "node --check desktop-plugin/plugin.js"
  else
    miss "node --check FAILED"
  fi
else
  miss "node not on PATH"
fi

hdr "2. plugin_api.py import"
if command -v python3 >/dev/null 2>&1; then
  if ( cd "$SRC/plugins/wenshu/dashboard" && python3 -c "
import plugin_api
assert plugin_api.manifest['id'] == 'wenshu', plugin_api.manifest
assert plugin_api.manifest['name'] == 'WENSHU', plugin_api.manifest
assert plugin_api.manifest['api'] == 'plugin_api.py', plugin_api.manifest
print('manifest:', plugin_api.manifest)
" ); then
    pass "plugin_api.py imports + manifest ok"
  else
    miss "plugin_api.py import FAILED"
  fi
else
  miss "python3 not on PATH"
fi

hdr "3. 8 editor modules import + run() signature"
if command -v python3 >/dev/null 2>&1; then
  if ( cd "$SRC/plugins/wenshu/dashboard/editors" && python3 -c "
import asyncio, importlib
mods = ['outline','research','style','character','plot','dialogue','proofread','chief']
for m in mods:
    mod = importlib.import_module(m)
    assert hasattr(mod, 'run'), f'{m} missing run()'
    out = asyncio.run(mod.run({}))
    assert out == {'status': 'stub', 'editor': m}, out
    print(f'{m}: {out}')
" ); then
    pass "all 8 editors import + run() returns {status:stub, editor:<name>}"
  else
    miss "editor import / run() FAILED"
  fi
else
  miss "python3 not on PATH"
fi

hdr "4. hermes profile 'wenshu' present"
if [ -d "$PROFILE_DIR" ]; then
  pass "profile dir exists: $PROFILE_DIR"
  if [ -f "$PROFILE_DIR/config.yaml" ]; then
    if grep -q 'wenshu' "$PROFILE_DIR/config.yaml"; then
      pass "profile config.yaml mentions 'wenshu'"
    else
      miss "profile config.yaml exists but does not mention 'wenshu'"
    fi
  else
    miss "profile dir exists but no config.yaml (run scripts/install.sh)"
  fi
else
  miss "profile dir missing (run scripts/install.sh first)"
fi

hdr "5. rsync targets (only meaningful after a prior install)"
if [ -f "${HERMES_HOME}/desktop-plugins/wenshu/plugin.js" ]; then
  pass "desktop runtime plugin present"
else
  printf '  ℹ️  desktop runtime plugin not yet rsynced (run scripts/install.sh)\n'
fi
if [ -f "${HERMES_HOME}/plugins/wenshu/manifest.yaml" ]; then
  pass "python runtime manifest present"
else
  printf '  ℹ️  python runtime manifest not yet rsynced (run scripts/install.sh)\n'
fi

hdr "summary"
printf '  passed=%d  failed=%d\n' "$ok" "$fail"
[ "$fail" -eq 0 ] || exit 1
