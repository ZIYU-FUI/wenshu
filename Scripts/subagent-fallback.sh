#!/bin/bash
# subagent-fallback.sh — Detect subagent timeout / failure and re-dispatch with smaller scope.
#
# Usage: subagent-fallback.sh <transcript-path> <original-task-summary>
#
# Exit 0 = failure mode detected and a smaller-scope re-dispatch is staged
# Exit 1 = no fallback needed (= success or non-recoverable error)
#
# Failure modes recognized:
#   - "Invalid API response" (provider-side stream corruption)
#   - "slow response" (model latency over the subagent ceiling)
#   - "timeout" (subagent wall-clock exceeded)
#   - "max_iterations" (model iteration budget exhausted)
#
# What "re-dispatch with smaller scope" means here:
#   The script does NOT actually re-spawn a subagent (that is the parent
#   orchestrator's job). It writes a single-line re-dispatch suggestion
#   to stdout and a corresponding marker file under
#   .scratch/subagent-fallback/<basename>.dispatch so the parent can
#   pick it up. The marker is idempotent (= existing file is replaced,
#   no parallel duplicate is created).

set -euo pipefail

TRANSCRIPT="${1:-}"
ORIGINAL="${2:-}"

if [ -z "$TRANSCRIPT" ] || [ -z "$ORIGINAL" ]; then
  echo "subagent-fallback: usage: subagent-fallback.sh <transcript-path> <original-task-summary>" >&2
  exit 2
fi

if [ ! -f "$TRANSCRIPT" ]; then
  echo "subagent-fallback: transcript not found = $TRANSCRIPT" >&2
  exit 2
fi

# Patterns observed across the 4 subagent failures on 2026-09-04.
# Combined as an OR; first match wins (= we report the most specific cause).
PATTERNS=(
  'max_iterations (iteration budget exhausted)'
  'Invalid API response'
  'slow response'
  'timeout'
)

# Only inspect the tail (= last 80 lines) — the failure signature is at the
# end of the transcript, not buried in earlier iteration output.
TAIL=$(mktemp)
trap 'rm -f "$TAIL"' EXIT
tail -80 "$TRANSCRIPT" > "$TAIL"

DETECTED=""
for pat in "${PATTERNS[@]}"; do
  if grep -qF "$pat" "$TAIL"; then
    DETECTED="$pat"
    break
  fi
done

if [ -z "$DETECTED" ]; then
  echo "subagent-fallback: no failure detected in $TRANSCRIPT"
  exit 1
fi

# Pick a smaller scope: split in half (= "5K LOC chunks" instead of full 14K).
# Scope sizing is intentionally coarse — the parent orchestrator decides the
# actual chunking. We only emit a recommended scope shape.
SCOPE_HINT="halved"
case "$DETECTED" in
  'max_iterations (iteration budget exhausted)')
    SCOPE_HINT="commit current wip + retry with same scope (post-delegate-task handles commit)"
    ;;
  'Invalid API response'|'slow response'|'timeout')
    SCOPE_HINT="halved (split LOC by half, re-dispatch in 5K-LOC chunks)"
    ;;
esac

OUT_DIR="$(cd "$(dirname "$TRANSCRIPT")" 2>/dev/null && pwd || echo .)/.scratch/subagent-fallback"
mkdir -p "$OUT_DIR"
MARKER="$OUT_DIR/$(basename "$TRANSCRIPT").dispatch"

# Idempotent: replace existing marker atomically.
TMP_MARKER=$(mktemp)
{
  echo "# subagent-fallback dispatch suggestion"
  echo "# generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# transcript: $TRANSCRIPT"
  echo "# detected: $DETECTED"
  echo "# scope: $SCOPE_HINT"
  echo "# original: $ORIGINAL"
} > "$TMP_MARKER"
mv "$TMP_MARKER" "$MARKER"

echo "subagent-fallback: detected '$DETECTED' in $TRANSCRIPT"
echo "subagent-fallback: scope = $SCOPE_HINT"
echo "subagent-fallback: dispatch marker written to $MARKER"

# Final explicit exit — guard against set -e interactions with earlier conditionals.
exit 0
