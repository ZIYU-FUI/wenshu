#!/bin/bash
# Run the dev-tool suites from wherever this checkout lives, one honest exit code each,
# and an aggregate exit code that MEANS the per-line codes.
#
# The code is captured BEFORE any command substitution runs. `printf "%s" "$(basename $f)" "$?"`
# expands the substitution FIRST and reports the SUBSTITUTION's status (= always 0), which once
# made a whole battery log read green while two of its suites were red. Same family as the `if !`
# trap: a negation, a substitution and a pipe each replace `$?` with their own status.
#
# The first version of this file carried that bug one level up: it printed one honest rc per
# suite and then exited with the status of its LAST STATEMENT, a `printf`, so 40 green lines plus
# one red line plus `rc=0` went out the door and a caller branching on the exit code read green.
# That is why the loop now counts and the last statement of this file is a decision, not a report.
#
# Usage: run-suites.sh [from] [to]   (= 1-based indexes over the sorted test_*.py list)
# Env:   RUN_SUITES_GLOB      the suite list (default: this repo's tests/test_*.py). The override
#        exists so the aggregation itself is testable on a fixture directory; without it the exit
#        code ships unverified.
# Env:   RUN_SUITES_BASELINE  suite names whose red is a KNOWN defect tracked somewhere else
#        (default: known-red.txt beside this script). A known red is counted separately and does
#        not fail the battery; a NEW red always does. Deleting a line is how a fixed suite returns
#        to being enforced — the baseline is a list of debts, not a mute button.
#
# A live entry in that register that names NO suite in this run's glob exits 93: a baseline that
# forgives nothing is an empty baseline, and a renamed or deleted suite would otherwise silently
# stop being enforced. The check compares the register against every suite the glob finds, so a
# window (`run-suites.sh 13 13`) does not make the out-of-window entries look stale. An unlisted
# RED is reported first (exit 1): a new red outranks a stale line, and the reader sees it either way.
#
# A battery that matched NO suite exits 92: nothing was measured, so it is not a pass. The CJK
# judge says the same sentence about an empty window; a script that reports it and still exits 0 is
# the bug that sentence exists to catch. 92 is its own code and not exit 1, so a caller can tell
# "the battery measured nothing" apart from "a suite is red and unlisted".
set -u
cd "$(dirname "$0")/../../.." || exit 70
from="${1:-1}"
to="${2:-999999}"
glob="${RUN_SUITES_GLOB:-Tools/wenshu-devtool/tests/test_*.py}"
baseline_file="${RUN_SUITES_BASELINE:-Tools/wenshu-devtool/tests/known-red.txt}"

known_red() {
  # A name is known-red only when the baseline carries it as a whole line, comments stripped.
  # awk, not sed: BSD sed reads `s/[ \t\r]//g` as the FIVE characters space, backslash, t, r and
  # happily eats the t out of every name, so a sed matcher silently matches nothing and the
  # baseline becomes a no-op that still prints green.
  [ -f "$baseline_file" ] || return 1
  awk '{ sub(/#.*/, ""); gsub(/[ \t\r]/, ""); if ($0 == name) found = 1 } END { exit !found }' \
    name="$1" "$baseline_file"
}

all_names=""
# Every suite the glob finds, window or not. The stale-register check below must not see an
# out-of-window suite as missing, so this list is built in its own pass BEFORE the run loop,
# which breaks early once the index passes `to`.
for f in $glob; do
  [ -f "$f" ] || continue
  all_names="$all_names $(basename "$f" .py)"
done

i=0
ran=0
red=0
known=0
for f in $glob; do
  # An unmatched glob hands the literal pattern back to the loop; that string is not a suite.
  [ -f "$f" ] || continue
  i=$((i + 1))
  [ "$i" -lt "$from" ] && continue
  [ "$i" -gt "$to" ] && break
  name=$(basename "$f" .py)
  timeout 600 python3 "$f" >/dev/null 2>&1
  rc=$?
  ran=$((ran + 1))
  if [ "$rc" -eq 0 ]; then
    printf "%s rc=0\n" "$name"
  elif known_red "$name"; then
    known=$((known + 1))
    printf "%s rc=%s known-red\n" "$name" "$rc"
  else
    red=$((red + 1))
    printf "%s rc=%s\n" "$name" "$rc"
  fi
done

printf "suites=%s red=%s known-red=%s\n" "$ran" "$red" "$known"

if [ "$ran" -eq 0 ]; then
  printf "FAIL no suite matched: %s\n" "$glob"
  # Its own code, so a caller can tell "nothing was measured" from "a new red" (exit 1).
  exit 92
fi
if [ "$red" -gt 0 ]; then
  printf "FAIL %s suite(s) red and not listed in %s\n" "$red" "$baseline_file"
  exit 1
fi
# A register entry that forgives no suite is a silent no-op: the debt it names has been renamed or
# deleted, and the battery would read green while enforcing one debt fewer than the reader counts.
if [ -f "$baseline_file" ] && [ -n "$all_names" ]; then
  stale=""
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    hit=0
    for n in $all_names; do
      [ "$n" = "$entry" ] && hit=1 && break
    done
    [ "$hit" -eq 0 ] && stale="$stale $entry"
  done < <(awk '{ sub(/#.*/, ""); gsub(/[ \t\r]/, ""); if (length($0) > 0) print }' "$baseline_file")
  if [ -n "$stale" ]; then
    printf "FAIL %s names suite(s) that do not exist:%s\n" "$baseline_file" "$stale"
    exit 93
  fi
fi
exit 0
