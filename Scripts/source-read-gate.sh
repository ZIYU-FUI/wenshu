#!/usr/bin/env bash
# The gate for the "a source-text test must read the tree it is testing"
# card (= the test files that read a production source file).
#
# THE PROPERTY UNDER TEST
#   A suite that reads a production source file must give the SAME
#   verdict when it runs from the repository root and when it runs from
#   a directory with no Sources/ folder. If the verdict moves with the
#   working directory, a reader cannot tell whether a red test means
#   "the code is wrong" or "I ran it from the wrong place".
#
# WHY THE CANDIDATE SET IS DERIVED, NOT WRITTEN DOWN
#   An earlier version of this gate carried a hand-written list of the
#   suites the card had touched. It reported PASS while 29 failures were
#   still reachable (= a gate that cannot see the defect it exists to
#   catch is not a gate). The set now comes from
#   Scripts/source-read-candidates.py, which derives it from the tree:
#   every test file that reads a production source file, in any shape.
#   A file that starts reading production source tomorrow joins the set
#   with no edit here.
#
# WHY NOT THE WHOLE SUITE
#   The whole suite hangs in the swift-testing half on this machine (an
#   XPC call to the Core Spotlight daemon never returns; `main` alone
#   reproduces it, so it is not any card's diff). Every command below is
#   a NAMED, FILTERED suite.
#
# Usage:
#   Scripts/source-read-gate.sh                 # both working directories
#   Scripts/source-read-gate.sh root            # repository root only
#   Scripts/source-read-gate.sh cwd             # the other working directory only

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/wenshu-source-read-gate"
mkdir -p "$OUT"
MODE="${1:-both}"

# The candidate set, derived from the tree.
GROUPS_FILE="$OUT/groups.tsv"
python3 "$ROOT/Scripts/source-read-candidates.py" "$ROOT" >"$GROUPS_FILE"

# Every recorded issue, whatever its shape (= "Expectation failed" for a
# false assertion, "Caught error" for a thrown read error). The verdict
# is the SET of these, not a count: two runs that report the same count
# but different assertions are not the same verdict.
issues() {
  grep -oE 'recorded an issue at [^ ]+' "$1" \
    | sed -E 's/ recorded an issue at /|/' | sort -u
}

# Run one filtered suite with a wall-clock budget. A suite that overruns
# it is a HANG, not a verdict: the log is kept, the run is stopped, and
# the caller is told (= "TIMEOUT"), so the gate reports "no verdict"
# instead of reporting a half-finished run as a pass.
BUDGET="${SOURCE_READ_GATE_BUDGET:-300}"
run_suite() {
  # $1 = the directory to run in, $2 = the filter, $3 = the log file.
  ( cd "$1" && swift test --package-path "$4" --filter "$2" >"$3" 2>&1 ) &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$BUDGET" ]; then
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      kill -KILL "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid" 2>/dev/null
  return $?
}

cd "$ROOT" || exit 2

status=0
while IFS=$'\t' read -r label filter; do
  [ -z "$label" ] && continue
  # The label is a directory path (= it holds slashes); the log file
  # name cannot.
  slug="$(printf '%s' "$label" | tr '/' '_')"

  if [ "$MODE" = "root" ] || [ "$MODE" = "both" ]; then
    run_suite "$ROOT" "$filter" "$OUT/$slug.root.log" "."; root_rc=$?
    issues "$OUT/$slug.root.log" > "$OUT/$slug.root.issues"
  fi
  if [ "$MODE" = "cwd" ] || [ "$MODE" = "both" ]; then
    # The other working directory: a directory with no Sources/ folder,
    # so a cwd-relative source read cannot resolve there.
    run_suite "$ROOT/Sources/WenshuApp" "$filter" "$OUT/$slug.cwd.log" "."; cwd_rc=$?
    issues "$OUT/$slug.cwd.log" > "$OUT/$slug.cwd.issues"
  fi

  # A hang is not a verdict. Say so rather than pass a partial run.
  if [ "$MODE" = "both" ] \
     && { [ "${root_rc:-0}" -eq 124 ] || [ "${cwd_rc:-0}" -eq 124 ]; }; then
    echo "$label: TIMEOUT (a run exceeded ${BUDGET}s = no verdict)"
    status=1
    continue
  fi

  if [ "$MODE" = "both" ]; then
    if diff -q "$OUT/$slug.root.issues" "$OUT/$slug.cwd.issues" >/dev/null; then
      verdict="SAME"
    else
      verdict="DIFFERENT"
      status=1
    fi
    echo "$label: root=$(wc -l <"$OUT/$slug.root.issues" | tr -d ' ') \
|cwd=$(wc -l <"$OUT/$slug.cwd.issues" | tr -d ' ') -> $verdict"
  else
    side=$([ "$MODE" = "root" ] && echo root || echo cwd)
    echo "$label: $side=$(wc -l <"$OUT/$slug.$side.issues" | tr -d ' ')"
  fi
done < "$GROUPS_FILE"

if [ "$MODE" = "both" ]; then
  echo
  if [ "$status" -eq 0 ]; then
    echo "PASS: every source-reading suite gives the same verdict from both working directories"
  else
    echo "FAIL: a suite's verdict depends on the working directory"
    while IFS=$'\t' read -r label _; do
      [ -z "$label" ] && continue
      slug="$(printf '%s' "$label" | tr '/' '_')"
      diff "$OUT/$slug.root.issues" "$OUT/$slug.cwd.issues" | head -10
    done < "$GROUPS_FILE"
  fi
fi
exit "$status"
