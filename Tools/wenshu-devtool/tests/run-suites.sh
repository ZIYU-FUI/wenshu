#!/bin/bash
# Run the dev-tool suites from wherever this checkout lives, one honest exit code each.
#
# The code is captured BEFORE any command substitution runs. `printf "%s" "$(basename $f)" "$?"`
# expands the substitution FIRST and reports the SUBSTITUTION's status (= always 0), which once
# made a whole battery log read green while two of its suites were red. Same family as the `if !`
# trap: a negation, a substitution and a pipe each replace `$?` with their own status.
#
# Usage: run-suites.sh [from] [to]   (= 1-based indexes over the sorted test_*.py list)
# A suite that matched nothing is NOT a pass: read the per-line rc, not a summary line.
set -u
cd "$(dirname "$0")/../../.." || exit 70
from="${1:-1}"
to="${2:-999999}"
i=0
for f in Tools/wenshu-devtool/tests/test_*.py; do
  i=$((i + 1))
  [ "$i" -lt "$from" ] && continue
  [ "$i" -gt "$to" ] && break
  name=$(basename "$f" .py)
  timeout 600 python3 "$f" >/dev/null 2>&1
  rc=$?
  printf "%s rc=%s\n" "$name" "$rc"
done
