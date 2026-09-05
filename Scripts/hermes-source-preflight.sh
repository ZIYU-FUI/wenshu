#!/bin/bash
# hermes-source-preflight.sh — Validate hermes source paths in a brief BEFORE
# subagent dispatch.
#
# Usage: hermes-source-preflight.sh <brief-path>
# Exit 0 = all paths valid (every hermes source reference exists on disk)
# Exit 1 = at least one path missing (brief has wrong / stale paths)
#
# Why this script exists:
#   On 2026-09-04, the first subagent dispatched with a HERMES-SUBSYSTEM
#   brief referenced hermes source paths that did NOT match the live
#   filesystem layout. The subagent refused to fabricate (= correct
#   behavior), but the dispatch wasted a full subagent cycle. This script
#   catches the same class of error BEFORE the subagent is spawned.
#
# What it does:
#   1. Extract every `/Volumes/ANAN/.hermes/...` token from the brief.
#   2. For each token, check whether the file exists.
#   3. For each missing file, emit one line:
#        preflight: MISSING hermes source = <path>
#      followed by up to 3 real-path candidates found via
#      `find /Volumes/ANAN/.hermes -name <basename>`.
#   4. If any path is missing, exit 1 (= brief needs human correction).
#   5. If every path exists, exit 0 (= safe to dispatch).

set -euo pipefail

BRIEF="${1:-}"

if [ -z "$BRIEF" ]; then
  echo "preflight: usage: hermes-source-preflight.sh <brief-path>" >&2
  exit 2
fi

if [ ! -f "$BRIEF" ]; then
  echo "preflight: brief not found = $BRIEF" >&2
  exit 2
fi

# 1. Extract every /Volumes/ANAN/.hermes/... reference.
#    Tokens stop at the first whitespace, closing paren, or backtick so we
#    capture real paths even when they appear inside markdown links,
#    backtick code spans, or parenthetical asides.
PATHS=$(grep -oE '/Volumes/ANAN/\.hermes/[^ )`]+' "$BRIEF" | sort -u || true)

if [ -z "$PATHS" ]; then
  echo "preflight: no hermes source paths found in $BRIEF (nothing to validate)"
  exit 0
fi

# 2. Validate each path.
MISSING=0
TOTAL=0
for p in $PATHS; do
  TOTAL=$((TOTAL + 1))
  if [ -f "$p" ]; then
    continue
  fi
  MISSING=$((MISSING + 1))
  echo "preflight: MISSING hermes source = $p"
  # Suggest real candidates so the human can patch the brief in one step.
  BASE=$(basename "$p")
  REAL=$(find /Volumes/ANAN/.hermes -name "$BASE" 2>/dev/null | head -3 || true)
  if [ -n "$REAL" ]; then
    echo "  real candidates:"
    echo "$REAL" | sed 's/^/    /'
  else
    echo "  real candidates: (none found under /Volumes/ANAN/.hermes)"
  fi
done

if [ "$MISSING" -eq 0 ]; then
  echo "preflight: all $TOTAL hermes source path(s) valid in $BRIEF"
  exit 0
else
  echo "preflight: $MISSING of $TOTAL hermes source path(s) missing — brief needs human correction before dispatch"
  exit 1
fi
