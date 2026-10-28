#!/usr/bin/env bash
# THE NEGATIVE CONTROL for the source-read gate.
#
# WHAT IT PROVES
#   A gate that reports PASS on a tree where the defect is fully
#   reintroduced proves nothing. This script restores the DEFECTIVE
#   (pre-migration) version of a chosen set of files, re-runs the gate,
#   and reports the verdict.
#
#   The set under test is the UNION of:
#     - the twelve files review round 1 named (= every one of them
#       reads production source by a quoted repo-relative literal), and
#     - the eight files review round 2 named (= the shape WITHOUT a
#       quoted literal: the path is built from the working directory).
#
#   The union is the point. A control over only the twelve proves
#   nothing about the eight, and a control over only the eight proves
#   nothing about the twelve. A gate that sees one shape and is blind
#   to the other is exactly the failure this script exists to catch.
#
#   AND THE UNION ALONE IS NOT ENOUGH, because it cannot distinguish
#   "the gate sees both shapes" from "the gate sees one shape and the
#   union hides it". That is the blind spot review round 2 found: the
#   old gate saw the literal shape and was blind to the cwd shape.
#   So the control runs PER SHAPE as well:
#
#     --shape=union    both shapes (= the default)
#     --shape=literal  only the twelve quoted-literal files
#     --shape=cwd      only the eight working-directory files
#
#   Every mode must report DIFFERENT and exit non-zero. A mode that
#   reports PASS is a gate that is blind to that shape.
#
#   The control also checks TWO properties that a verdict alone does
#   not cover:
#     1. the tree with the defect restored still BUILDS (= the control
#        measures the gate, not a compile error), and
#     2. the candidate set still CONTAINS every file it contained
#        before the defect was restored (= the gate did not simply
#        stop looking at the file, which is the blind spot the review
#        found: a dropped file makes the gate report PASS).
#
# Usage:
#   Scripts/source-read-negative-control.sh [--shape=union|literal|cwd]
#
# The working tree is restored to the branch state on exit, whatever
# happens (a trap).

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

SHAPE="union"
for arg in "$@"; do
  case "$arg" in
    --shape=*) SHAPE="${arg#--shape=}" ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done
case "$SHAPE" in
  union|literal|cwd) ;;
  *) echo "--shape must be union, literal or cwd" >&2; exit 2 ;;
esac

MANIFEST="$ROOT/Scripts/source-read-negative-control-files.tsv"
OUT="${TMPDIR:-/tmp}/wenshu-source-read-gate"
mkdir -p "$OUT"

# The candidate set BEFORE the defect is restored (= the branch state).
python3 Scripts/source-read-candidates.py "$ROOT" | sort > "$OUT/nc-before.tsv"
echo "=== the branch state: $(wc -l < "$OUT/nc-before.tsv" | tr -d ' ') candidate groups ==="
echo "=== negative control, shape: $SHAPE ==="

restore() {
  echo
  echo "--- restoring the branch state ---"
  git checkout -- Tests/ 2>/dev/null
  git status --porcelain | head
}
trap restore EXIT INT TERM

echo
echo "=== restoring the DEFECTIVE version of each file in the manifest ==="
restored=0
while IFS=$'\t' read -r path parent shape; do
  case "$path" in \#*|"") continue ;; esac
  [ -n "${shape:-}" ] || continue
  if [ "$SHAPE" != "union" ] && [ "$shape" != "$SHAPE" ]; then
    continue
  fi
  if ! git show "$parent:$path" > "$path"; then
    echo "FAILED to restore $path"
    exit 1
  fi
  echo "  restored $path"
  restored=$((restored + 1))
done < "$MANIFEST"
echo "restored: $restored file(s)"
if [ "$restored" -eq 0 ]; then
  echo
  echo "=== NEGATIVE CONTROL INVALID: the manifest has no file for this shape ==="
  exit 1
fi

echo
echo "=== the candidate set WITH the defect restored ==="
python3 Scripts/source-read-candidates.py "$ROOT" | sort > "$OUT/nc-after.tsv"
echo "groups: $(wc -l < "$OUT/nc-after.tsv" | tr -d ' ')"

# Property 2: the candidate set must not LOSE a file to the defect.
# A file that drops out of the set is a file the gate no longer runs,
# and a gate that no longer runs the file reports PASS.
python3 - "$OUT/nc-before.tsv" "$OUT/nc-after.tsv" <<'PYEOF'
import sys

def suites(path):
    out = set()
    for line in open(path, encoding="utf-8"):
        if not line.strip():
            continue
        f = line.rstrip("\n").split("\t")[1]
        for s in f[f.index("(") + 1:f.rindex(")")].split("|"):
            out.add(s)
    return out

before, after = suites(sys.argv[1]), suites(sys.argv[2])
lost = sorted(before - after)
print()
print("=== candidate-set monotonicity ===")
if lost:
    print("FAIL: the defect DROPPED these suites from the gate (= the gate stopped looking):")
    for s in lost:
        print("   ", s)
    sys.exit(1)
print(f"OK: no suite was dropped ({len(before)} before, {len(after)} after)")
PYEOF
mono_rc=$?
if [ "$mono_rc" -ne 0 ]; then
  echo
  echo "=== NEGATIVE CONTROL FAILED: the candidate set is not monotone ==="
  exit 1
fi

echo
echo "=== the tree with the defect restored must still BUILD ==="
if ! swift build --build-tests 2>&1 | tail -3; then
  echo
  echo "=== NEGATIVE CONTROL INVALID: the defective tree does not build ==="
  exit 1
fi

echo
echo "=== running the gate on the defective tree ==="
SOURCE_READ_GATE_BUDGET="${SOURCE_READ_GATE_BUDGET:-420}" \
  bash Scripts/source-read-gate.sh both 2>&1 | tee "$OUT/nc-gate-$SHAPE.txt"
rc=${PIPESTATUS[0]}
echo
echo "=== NEGATIVE CONTROL (shape=$SHAPE): gate exit code = $rc (must be non-zero) ==="
exit "$rc"
