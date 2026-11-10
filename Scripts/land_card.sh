#!/usr/bin/env bash
# land_card.sh <card_id> <branch> <cmd1> [cmd2 ...]
# Full landing flow for ONE card. Never force-pushes.
# Loops: rebase -> card gates -> ff merge. If main moved under us (not ff),
# rebase again and RE-RUN the gates (a rebase can invalidate what a gate proved).
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"

resolve_worktree() {
  # = = = = The convention first, = = = = then the card's own path.
  local card="$1" repo="$2" wt card_ws
  wt="$repo/.worktrees/$card"
  card_ws="$(python3 "$repo/Scripts/land_worktree.py" "$card" 2>/dev/null)"
  if [ -n "$card_ws" ] && [ -d "$card_ws" ]; then
    wt="$card_ws"
  fi
  printf '%s\n' "$wt"
}

# = = ⇒ AND THE RESOLUTION CAN BE ASKED FOR ON ITS OWN, = = = = so a test can
# = = = = run the SHELL'S OWN block (= = and not a copy of it). = = ⇒ A test
# = = = = that calls the helper directly does NOT hold the seam this exists to
# = = = = hold: = = removing the shell's call leaves the helper tested and the
# = = = = script broken, = = and nothing goes red.
if [ "${1:-}" = "--resolve-only" ]; then
  shift
  resolve_worktree "${1:-}" "$REPO"
  exit 0
fi
CARD="$1"; BRANCH="$2"; shift 2
# = = ⇒ AND THE WORKTREE IS THE ONE THE CARD NAMES, = = = = not one
# = = = = guessed from the card's id. = = = = The convention that the
# = = = = worktree lives at `.worktrees/<card id>` is only a convention:
# = = = = a card whose workspace points at an existing worktree (= = = =
# = = = = the review lane's own, = = = = which is where the reviewer
# = = = = read the tree from) = = = = has its worktree elsewhere, = = = =
# = = = = and this script then rebased a path that does not exist, = =
# = = = = said "REBASE CONFLICT", = = = = and landed nothing. = = ⇒ The
# = = = = card's own workspace_path is the authority, = = = = and the
# = = = = convention is the fallback. = = = = ⇒ The resolution lives in
# = = = = `Scripts/land_worktree.py`, = = = = so it can be TESTED (= = = =
# = = = = and a shell script's path arithmetic is exactly the kind of
# = = = = thing a test is cheaper for than a reader).
WT="$(resolve_worktree "$CARD" "$REPO")"
if [ "$WT" != "$REPO/.worktrees/$CARD" ]; then
  echo "--- the card's own worktree: $WT"
fi
LOGDIR="${LOGDIR:-$REPO/.gate-logs}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-4}"
mkdir -p "$LOGDIR"

echo "##### CARD $CARD"
echo "##### BRANCH $BRANCH"

echo "--- step 1: preflight"
cd "$REPO" || exit 2
pf="$(bash Scripts/merge-preflight.sh "$BRANCH" 2>&1)"
echo "$pf"
if echo "$pf" | grep -q 'CONFLICT'; then echo "RESULT: SKIP ($CARD) reason=CONFLICT"; exit 10; fi
if echo "$pf" | grep -q 'a card that writes code needs one approving verdict'; then echo "RESULT: SKIP ($CARD) reason=NO_VERDICT"; exit 11; fi
if ! echo "$pf" | grep -q '^CLEAN'; then echo "RESULT: SKIP ($CARD) reason=PREFLIGHT_NOT_CLEAN"; exit 12; fi

echo "--- step 2: worktree status"
st="$(git -C "$WT" status --porcelain)"
if [ -n "$st" ]; then echo "WORKTREE DIRTY:"; echo "$st"; echo "RESULT: SKIP ($CARD) reason=DIRTY_WORKTREE"; exit 20; fi
echo "clean"

attempt=1
while [ $attempt -le $MAX_ATTEMPTS ]; do
  echo "=== ATTEMPT $attempt: rebase onto current main ($(git -C "$REPO" rev-parse --short main))"
  if ! git -C "$WT" rebase main > "$LOGDIR/${CARD}_rebase.log" 2>&1; then
    echo "REBASE CONFLICT:"; cat "$LOGDIR/${CARD}_rebase.log"
    git -C "$WT" rebase --abort
    echo "RESULT: SKIP ($CARD) reason=REBASE_CONFLICT"; exit 30
  fi
  cat "$LOGDIR/${CARD}_rebase.log"
  echo "rebased head: $(git -C "$WT" log --oneline -1)"

  echo "--- step 4: card gates (attempt $attempt)"
  PER_CMD_TIMEOUT=300 bash "$(dirname "$0")/gate_run.sh" "$WT" "${CARD}_a${attempt}" "$@"
  grc=$?
  if [ $grc -ne 0 ]; then echo "RESULT: SKIP ($CARD) reason=GATE_FAILED"; exit 40; fi

  echo "--- step 5: fast-forward merge"
  cd "$REPO" || exit 2
  if ! git merge --ff-only "$BRANCH" > "$LOGDIR/${CARD}_merge.log" 2>&1; then
    echo "MERGE FAILED (not fast-forward): main moved again; re-rebase and re-run gates"
    cat "$LOGDIR/${CARD}_merge.log"
    attempt=$((attempt+1))
    continue
  fi
  cat "$LOGDIR/${CARD}_merge.log"
  LOCAL_SHA="$(git rev-parse main)"
  break
done

if [ -z "${LOCAL_SHA:-}" ]; then echo "RESULT: SKIP ($CARD) reason=NOT_FF_AFTER_${MAX_ATTEMPTS}_ATTEMPTS"; exit 50; fi

echo "--- step 6: push"
if ! git push origin main > "$LOGDIR/${CARD}_push.log" 2>&1; then
  echo "PUSH FAILED:"; cat "$LOGDIR/${CARD}_push.log"
  echo "RESULT: SKIP ($CARD) reason=PUSH_FAILED (local main=$LOCAL_SHA not pushed)"; exit 60
fi
cat "$LOGDIR/${CARD}_push.log"

echo "--- step 7: read back remote"
REMOTE_SHA="$(git ls-remote origin main 2>/dev/null | cut -f1)"
echo "local main : $LOCAL_SHA"
echo "remote main: $REMOTE_SHA"
if [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then echo "RESULT: SKIP ($CARD) reason=REMOTE_MISMATCH"; exit 70; fi
echo "RESULT: LANDED ($CARD) sha=$LOCAL_SHA"
exit 0
