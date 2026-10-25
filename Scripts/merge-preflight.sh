#!/usr/bin/env bash
# merge-preflight.sh — answer "will this card branch conflict with main?"
# WITHOUT merging.
#
# git merge-tree --write-tree does a real 3-way merge in memory and writes
# unreferenced objects only: no branch moves, no index changes, no file in
# the working tree changes. Its exit code is the answer.
#
#   0 = clean AND reviewed, land it
#   1 = conflict, and the conflicting paths are printed
#   3 = the card owes an independent review verdict it does not have
#
# The card branch usually also needs a rebase first (= it is behind main).
# That is drift, not a conflict: the rebase is what makes the landing a
# fast-forward, and it belongs in the card's OWN worktree so a conflict
# cannot destroy a sibling session's staged work.
#
# THE REVIEW GATE (added 2026-10-26). A conflict-free branch is not a
# landable branch. Measured on this board: 113 of 114 done cards carried zero
# review events, the one review that ran was the implementer reviewing itself,
# and 5 done cards promised files their branch does not contain (= a false
# done). All 5 write code; 0 prose card was false done. So a card that writes
# code owes one verdict from a profile that is not its implementer, and this
# script refuses to bless a merge until that verdict is on the record.
#
# The card id is read from the branch name (= project/<task-id>-<slug>), so
# the gate needs no argument beyond the branch. A branch with no card id, or
# a card created before the review contract started, is not gated: the cards
# already on the board were dispatched under the old contract.
#
# Usage:
#   merge-preflight.sh <card-branch> [<card-branch> ...]
#   merge-preflight.sh --all          # every project/ branch on the repo
set -uo pipefail

REPO="${WENSHU_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO" || exit 2

GATE="$REPO/Tools/wenshu-devtool/review_gate.py"
BOARD="${WENSHU_BOARD:-wenshu-par}"

branches=()
if [[ "${1:-}" == "--all" ]]; then
    while IFS= read -r b; do
        [[ -n "$b" ]] && branches+=("$b")
    done < <(git for-each-ref --format='%(refname:short)' 'refs/heads/project/')
else
    for b in "$@"; do
        [[ -z "$b" ]] && continue
        if ! git rev-parse --verify -q "$b" >/dev/null; then
            echo "no such branch: $b" >&2
            exit 2
        fi
        branches+=("$b")
    done
fi

if [[ ${#branches[@]} -eq 0 ]]; then
    echo "no branches to check" >&2
    exit 2
fi

# The card id a branch belongs to, or empty when the branch carries none.
card_id_of() {
    basename "$1" | grep -oE '^t_[0-9a-f]{8}' || true
}

conflict=0
unreviewed=0
for b in "${branches[@]}"; do
    out="$(git merge-tree --write-tree --name-only --messages main "$b" 2>&1)"
    rc=$?
    if [[ $rc -eq 0 ]]; then
        behind=$(git rev-list --count "$b..main" 2>/dev/null || echo "?")
        echo "CLEAN    $b   (behind main by $behind commit(s) -> rebase in its worktree, then ff)"
    else
        conflict=1
        echo "CONFLICT $b"
        echo "$out" | grep -E '^(CONFLICT|Auto-merging)' | sed 's/^/         /'
        echo "$out" | grep -E '^(Sources|Tests|Tools|docs|Scripts|AGENTS|Package)' | sed 's/^/         /'
    fi

    # The review gate. It runs even on a conflicting branch: a card that
    # owes a verdict owes it whether or not its branch also conflicts.
    card="$(card_id_of "$b")"
    [[ -z "$card" ]] && continue
    [[ -f "$GATE" ]] || continue
    gate_out="$(python3 "$GATE" --card "$card" --board "$BOARD" 2>&1)"
    gate_rc=$?
    if [[ $gate_rc -eq 3 ]]; then
        unreviewed=1
        echo "UNREVIEWED $b"
        echo "$gate_out" | sed 's/^/         /'
    elif [[ $gate_rc -eq 1 ]]; then
        unreviewed=1
        echo "CONTRACT  $b"
        echo "$gate_out" | sed 's/^/         /'
    fi
done

if [[ $unreviewed -eq 1 ]]; then
    echo
    echo "a card that writes code needs one approving verdict from a profile"
    echo "that is not its implementer before it lands (see Tools/wenshu-devtool/review_gate.py)"
    exit 3
fi

exit $conflict
