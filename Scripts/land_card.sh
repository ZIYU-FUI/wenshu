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

worktree_for_branch() {
  # = = ⇒ THE TREE THAT LANDS IS THE TREE THE BRANCH IS CHECKED OUT IN, = = = =
  # = = = = and NOTHING else answers that question. = = ⇒ The card's own
  # = = = = `workspace_path` says WHO reviewed, = = = = which for a review card
  # = = = = is a different tree from the one under review: = = = = the review
  # = = = = lane's worktree sits on the derived branch at `main`, = = = = so it
  # = = = = has never contained the commits being landed. = = ⇒ Landing read
  # = = = = that path, = = = = rebased a tree that did not hold the work, = = = =
  # = = = = ran its gates over a window whose two ends were the SAME commit, =
  # = = = = and took `added comment lines: 0` for a pass. = = ⇒ So the
  # = = = = registered worktree whose `branch` line IS this branch is the
  # = = = = target, = = = = matched by branch identity and not by sha, = = = =
  # = = = = because a detached tree sitting on the same commit is not ON the
  # = = = = branch and cannot rebase it. = = ⇒ No such worktree is a REFUSAL
  # = = = = that names the branch, = = = = never a fallback to the card's path:
  # = = = = a landing that guesses a tree is the defect this function exists
  # = = = = to remove.
  local branch="$1" line path head wthead
  path=""; head=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) path="${line#worktree }" ;;
      "HEAD "*) head="${line#HEAD }" ;;
      "branch refs/heads/$branch")
        printf '%s\n' "$path"
        return 0
        ;;
    esac
  done < <(git -C "$REPO" worktree list --porcelain)
  return 1
}

assert_lane_has_commits() {
  # = = ⇒ A LANE WITH NOTHING IN IT IS NOT A LANE. = = ⇒ `main..BRANCH`
  # = = = = counting zero means the branch carries no commit that `main`
  # = = = = lacks, = = = = so every gate that reads a `base..head` window over
  # = = = = it measures NOTHING and reports a clean run, = = = = and the
  # = = = = landing then "succeeds" having moved `main` to a sha it already
  # = = = = held. = = ⇒ The count is printed in the refusal, = = = = because
  # = = = = the honest reading of an empty lane is usually "the wrong branch
  # = = = = was named", = = = = and a reader with the number can tell the two
  # = = = = apart.
  local base="$1" branch="$2" card="$3" count
  count="$(git -C "$REPO" rev-list --count "$base..$branch" 2>/dev/null)" || count="?"
  if [ "$count" = "0" ]; then
    echo "RESULT: SKIP ($card) reason=EMPTY_LANE ($branch carries 0 commits that $base does not; there is nothing here for a gate to measure)"
    return 22
  fi
  echo "--- the lane: $count commit(s) ahead of $base"
  return 0
}

assert_gated_tree_is_the_branch() {
  # = = ⇒ THE TREE THE GATES RAN IN IS THE TREE THAT LANDS, = = = = or the
  # = = = = gates proved nothing about this landing. = = ⇒ Checked AFTER the
  # = = = = rebase (= = = = when a rebased branch's tip and its worktree's HEAD
  # = = = = must be the same object) = = = = and again AFTER `main` moved.
  # = = ⇒ A mismatch means the resolution and the ref disagree, = = = = which
  # = = = is the shape of the incident this refuses: = = = = a verdict earned
  # = = = = in someone else's tree.
  local wt="$1" branch="$2" card="$3" wt_head branch_head
  wt_head="$(git -C "$wt" rev-parse HEAD 2>/dev/null)" || wt_head=""
  branch_head="$(git -C "$REPO" rev-parse "$branch" 2>/dev/null)" || branch_head=""
  if [ -z "$wt_head" ] || [ "$wt_head" != "$branch_head" ]; then
    echo "RESULT: SKIP ($card) reason=GATED_TREE_NOT_THE_BRANCH (the worktree $wt is at ${wt_head:-unreadable} and $branch is at ${branch_head:-unreadable})"
    return 23
  fi
  return 0
}


# = = ⇒ AND THE RESOLUTION CAN BE ASKED FOR ON ITS OWN, = = = = so a test can
# = = = = run the SHELL'S OWN block (= = and not a copy of it). = = ⇒ The DOOR
# = = = = sets a flag and does NOT exit, = = = = so the flow below runs and
# = = = = computes WT where it always computed it: = = = = a test that runs a
# = = = = SECOND entry point pins the second entry point, = = = = and the line
# = = = = the landing actually uses stays untested.
RESOLVE_ONLY=0
if [ "${1:-}" = "--resolve-only" ]; then
  RESOLVE_ONLY=1
  shift
fi
# = = ⇒ THE SAME DOOR, = = = = ONE STEP LATER. = = ⇒ Step 1 below is the ONLY thing in this script
# = = = = that decides whether a branch may reach main, = = = = and running the script end to end to
# = = = = test it would rebase, = = = = merge and PUSH. = = ⇒ So the veto can be asked for on its
# = = = = own, = = = = and an acceptance harness runs the SHELL'S OWN decision instead of a copy of
# = = = = it (= = the reason the door above exists at all).
PREFLIGHT_ONLY=0
if [ "${1:-}" = "--preflight-only" ]; then
  PREFLIGHT_ONLY=1
  shift
fi
CARD="${1:-}"; BRANCH="${2:-}"; shift 2
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
# = = ⇒ AND THIS IS THE ONE ASSIGNMENT THAT DECIDES THE WORKTREE, = = = = and
# = = = = the flow below uses it, = = = = and the door prints it. = = ⇒ A test
# = = = = that reverses THIS line reverses the landing itself, = = = = not a
# = = = = test-only path.
CARD_WT="$(resolve_worktree "$CARD" "$REPO")"
if [ "$RESOLVE_ONLY" = "1" ]; then
  printf '%s\n' "$CARD_WT"
  exit 0
fi
# = = ⇒ WHAT LANDS IS DECIDED BY THE BRANCH, = = = = and what REVIEWED is a
# = = = = different question. = = ⇒ `CARD_WT` answers the second (the card's
# = = = = own `workspace_path`), = = = = and it used to answer the first too, =
# = = = = which is how a REVIEW card = = = = whose workspace is the review
# = = = = lane's own tree = = = = sent the landing to rebase a tree that had
# = = = = never contained the commits under review. = = ⇒ The gate then read a
# = = = = window whose two ends were the same commit, = = = = printed that it
# = = = = had measured nothing, = = = = and the landing called that a pass.
# = = ⇒ So the target is resolved from the branch's own registration, = = = =
# = = = = and when no registered worktree is on the branch, = = = = NOTHING is
# = = = = rebased, = = = = gated, = = = = moved or pushed: = = = = the refusal
# = = = = names the branch it could not find. = = ⇒ The card's tree is still
# = = = = printed, = = = = because a reader wants to know who reviewed.
WT="$(worktree_for_branch "$BRANCH")"
if [ -z "$WT" ]; then
  echo "RESULT: SKIP ($CARD) reason=NO_WORKTREE_ON_BRANCH ($BRANCH is not checked out in any registered worktree, so the tree the gates would run in does not exist)"
  exit 21
fi
if [ "$CARD_WT" != "$WT" ]; then
  echo "--- the card's own worktree (WHO reviewed): $CARD_WT"
  echo "--- the branch's worktree  (WHAT lands):   $WT"
fi
LOGDIR="${LOGDIR:-$REPO/.gate-logs}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-4}"
mkdir -p "$LOGDIR"

echo "##### CARD $CARD"
echo "##### BRANCH $BRANCH"

echo "--- step 1: preflight"
cd "$REPO" || exit 2
pf="$(bash Scripts/merge-preflight.sh "$BRANCH" 2>&1)"; pfc=$?
echo "$pf"
# = = ⇒ THE VETO COMES FROM THE EXIT CODE, = = = = NOT FROM A SENTENCE. = = ⇒ merge-preflight exits
# = = = = 3 when a branch carries no approving verdict, = = = = and the SAME refused output also
# = = = = starts with a `CLEAN …` line, = = = = so the three text tests below were never a safety
# = = = = property: = = = = the veto survived only while one English sentence kept its exact
# = = = = wording. = = ⇒ Before this change `$?` was read ZERO TIMES in this segment, = = = = so
# = = = = rewording or deleting that sentence (the kind of edit any future message change makes)
# = = = = silently turned the board's last review gate into a no-op that rebases, = = = = merges and
# = = = = pushes UNREVIEWED code onto main (= = finding B6, = = card t_2699b55c). = = ⇒ The text
# = = = = tests stay for their better error strings; = = = = the refusal itself now comes from rc,
# = = = = which a reword cannot move.
if echo "$pf" | grep -q 'CONFLICT'; then echo "RESULT: SKIP ($CARD) reason=CONFLICT"; exit 10; fi
if [ "$pfc" -eq 3 ]; then echo "RESULT: SKIP ($CARD) reason=NO_VERDICT (merge-preflight rc=3)"; exit 11; fi
if [ "$pfc" -ne 0 ]; then echo "RESULT: SKIP ($CARD) reason=PREFLIGHT_FAILED (merge-preflight rc=$pfc)"; exit 12; fi
if echo "$pf" | grep -q 'a card that writes code needs one approving verdict'; then echo "RESULT: SKIP ($CARD) reason=NO_VERDICT"; exit 11; fi
if ! echo "$pf" | grep -q '^CLEAN'; then echo "RESULT: SKIP ($CARD) reason=PREFLIGHT_NOT_CLEAN"; exit 12; fi
if [ "$PREFLIGHT_ONLY" = "1" ]; then
  # = = ⇒ THE REHEARSAL OWES THE SAME THREE ANSWERS AS THE RUN. = = ⇒ A
  # = = = = rehearsal that skips what the real landing checks is a rehearsal
  # = = = = that passes for a reason the run will not accept, = = = = which is
  # = = = = exactly how an empty lane reached the merge step once. = = ⇒ So the
  # = = = = target above is already resolved (= or this never got here), = = = =
  # = = = and the lane's count and the tree's identity are asserted HERE, = = = =
  # = = = with the same refusals and the same codes.
  REHEARSAL_MAIN="$(git -C "$REPO" rev-parse main)"
  assert_lane_has_commits "$REHEARSAL_MAIN" "$BRANCH" "$CARD" || exit $?
  assert_gated_tree_is_the_branch "$WT" "$BRANCH" "$CARD" || exit $?
  echo "RESULT: PREFLIGHT_ONLY ($BRANCH) pfrc=$pfc decision=PROCEED"
  exit 0
fi

echo "--- step 2: worktree status"
st="$(git -C "$WT" status --porcelain)"
if [ -n "$st" ]; then echo "WORKTREE DIRTY:"; echo "$st"; echo "RESULT: SKIP ($CARD) reason=DIRTY_WORKTREE"; exit 20; fi
echo "clean"

attempt=1
while [ $attempt -le $MAX_ATTEMPTS ]; do
  EXPECTED_MAIN="$(git -C "$REPO" rev-parse main)"
  echo "=== ATTEMPT $attempt: rebase onto current main ($(git -C "$REPO" rev-parse --short "$EXPECTED_MAIN"))"
  # = = ⇒ BEFORE ANYTHING IS REBASED OR GATED, = = = = the lane must have
  # = = = = something in it. = = ⇒ An empty lane is not a clean lane: = = = = a
  # = = = = `base..head` window whose ends are the same commit measures
  # = = = = nothing, = = = = and the gate that prints that fact and exits 0
  # = = = = makes the landing read as proof.
  assert_lane_has_commits "$EXPECTED_MAIN" "$BRANCH" "$CARD" || exit $?
  if ! git -C "$WT" rebase "$EXPECTED_MAIN" > "$LOGDIR/${CARD}_rebase.log" 2>&1; then
    echo "REBASE CONFLICT:"; cat "$LOGDIR/${CARD}_rebase.log"
    git -C "$WT" rebase --abort
    echo "RESULT: SKIP ($CARD) reason=REBASE_CONFLICT"; exit 30
  fi
  cat "$LOGDIR/${CARD}_rebase.log"
  echo "rebased head: $(git -C "$WT" log --oneline -1)"
  assert_gated_tree_is_the_branch "$WT" "$BRANCH" "$CARD" || exit $?
  # = = ⇒ THIS IS THE SHA THE GATES ARE ABOUT TO RUN AGAINST, = = = = and it
  # = = = = is written down BEFORE they run. = = ⇒ A branch ref that moves
  # = = = = while the gates are running (= a sibling commit landing in the
  # = = = = same lane, = = = = or a rewrite) = = = = would otherwise be merged
  # = = = = on the strength of a verdict that never saw it.
  GATED_SHA="$(git -C "$WT" rev-parse HEAD)"

  echo "--- step 4: card gates (attempt $attempt)"
  PER_CMD_TIMEOUT=300 bash "$(dirname "$0")/gate_run.sh" "$WT" "${CARD}_a${attempt}" "$@"
  grc=$?
  if [ $grc -ne 0 ]; then echo "RESULT: SKIP ($CARD) reason=GATE_FAILED"; exit 40; fi
  # = = ⇒ THE GATED TREE IS RE-READ AFTER THE GATES RETURN, = = = = and a tree
  # = = = = that moved underneath them invalidates the verdict just earned. =
  # = ⇒ The loop rebases again rather than merging what it no longer proved.
  if [ "$(git -C "$WT" rev-parse HEAD)" != "$GATED_SHA" ]; then
    echo "RESULT: SKIP ($CARD) reason=THE_BRANCH_MOVED_DURING_THE_GATES ($BRANCH was at $GATED_SHA when the gates started and is at $(git -C "$WT" rev-parse HEAD) now; the verdict just earned is not a verdict on this tip)"
    exit 41
  fi

  # = = = = THE LANDING MOVES main AND NOTHING ELSE. = = = = = = = = =
  # = = = = The old step ran `git merge --ff-only` INSIDE the shared = = = = =
  # = = = = checkout (= the checkout every session reads and writes), = = = = =
  # = = = = so two sessions landing at once fought over one working = = = = =
  # = = = = tree, and a merge that succeeded half-way left the shared = = = = =
  # = = = = checkout's files on a branch the next session did not = = = = =
  # = = = = expect. = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
  # = = = = Now NOTHING is merged anywhere: the branch was already = = = = =
  # = = = = rebased onto main above, and `main`'s REF is moved by = = = = =
  # = = = = compare-and-swap against the sha this attempt read (= = = = = the
  # = = = = sha it rebased onto). = = = = = = = = = = = = = = = = = = = = = = =
  # = = = = The swap names the sha it expects, so a `main` that moved = = = = =
  # = = = = under us makes the swap FAIL (= = = = = the ref is not changed) = =
  # = = = = instead of overwriting the other session's landing, and the = = =
  # = = = = loop rebases onto the new main and RE-RUNS the gates. = = = = = =
  # = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
  # = = = = The shared checkout's FILES are never written by this script; = =
  # = = = = the ref moves, and whoever works in that checkout reads the = = =
  # = = = = new `main` on its next command (= = = = = `git reset --hard` if =
  # = = = = = it wants its files to match). = = = = = = = = = = = = = = = = =
  echo "--- step 5: the landed sha, then move main by compare-and-swap"
  echo "expected main (the main this attempt rebased onto): $EXPECTED_MAIN"
  # NOTHING is merged here. The old step ran `git merge --ff-only` inside
  # the SHARED checkout (= the checkout every session reads and writes), so
  # two sessions landing at once fought over one working tree. A
  # fast-forward merge moves a ref AND writes the tree, and the tree write
  # is the part that must not happen in the shared checkout.
  #
  # The branch was rebased onto $EXPECTED_MAIN above, so its tip already
  # carries main, and the compare-and-swap below moves main to that tip.
  # = = ⇒ WHAT IS LANDED IS THE TREE THE GATES JUST RAN IN, = = = = read from
  # = = = = that worktree's HEAD, = = = = and NOT from the branch ref. = = ⇒ The
  # = = = = ref can move between the last gate and this swap (= a sibling
  # = = = = session committing into the same branch, = = = = which is exactly
  # = = = = what the review lane does while a landing is in flight), = = = = and
  # = = = = reading it here would land a commit no gate ever saw. = = ⇒ The
  # = = = = assertion below refuses that instead, = = = = naming both shas.
  assert_gated_tree_is_the_branch "$WT" "$BRANCH" "$CARD" || exit $?
  MERGED_SHA="$GATED_SHA"
  if ! git -C "$WT" merge-base --is-ancestor "$EXPECTED_MAIN" "$MERGED_SHA"; then
    echo "THE CARD'S BRANCH DOES NOT CARRY MAIN: the landing refuses"
    echo "RESULT: SKIP ($CARD) reason=NOT_FF_IN_WORKTREE"
    exit 31
  fi
  # THE COMPARE-AND-SWAP: `git update-ref refs/heads/main NEW OLD` moves the
  # ref ONLY when it still points at OLD. A `main` that moved under this
  # landing makes the swap fail (= the ref is not changed) instead of
  # overwriting the other session's landing.
  if ! git -C "$REPO" update-ref refs/heads/main "$MERGED_SHA" "$EXPECTED_MAIN" \
       > "$LOGDIR/${CARD}_update_ref.log" 2>&1; then
    echo "MAIN MOVED UNDER THIS LANDING: the compare-and-swap refused to move main"
    cat "$LOGDIR/${CARD}_update_ref.log"
    # The next attempt rebases onto the NEW main and RE-RUNS the gates
    # (= a rebase can invalidate what a gate proved).
    attempt=$((attempt + 1))
    continue
  fi
  cat "$LOGDIR/${CARD}_update_ref.log"
  LOCAL_SHA="$(git -C "$REPO" rev-parse main)"
  echo "main moved by compare-and-swap: $EXPECTED_MAIN -> $LOCAL_SHA"
  # = = ⇒ AND RE-ASSERTED ON THE MERGED COMMIT: = = = = what `main` now points
  # = = = = at has to be the very tree the gates were run in, = = = = or the
  # = = = = verdict on the record is not the verdict on the landing.
  if [ "$LOCAL_SHA" != "$GATED_SHA" ]; then
    echo "RESULT: SKIP ($CARD) reason=LANDED_IS_NOT_THE_GATED_TREE (main is at $LOCAL_SHA, the gated tree is at $GATED_SHA)"
    exit 24
  fi
  echo "--- the gated tree is what landed: $GATED_SHA"
  break
done

if [ -z "${LOCAL_SHA:-}" ]; then
  echo "RESULT: SKIP ($CARD) reason=MAIN_MOVED_DURING_LANDING (after $MAX_ATTEMPTS attempts)"
  exit 50
fi

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
