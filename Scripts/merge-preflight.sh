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
# The review card is read by the sha the branch points at: under the
# one-developer flow the branch is pocock's own (= it is not named after a
# card), so the card whose body names that sha is the only card that can
# cover the branch. A branch whose sha no card names carries NO verdict and
# is refused, never skipped.
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

# The review card that reviews this branch, or empty when none does.
#
# The lookup is by the sha the branch points at: the review card's body
# names the sha under review in its WHAT TO BUILD claim, and the branch
# tip is that sha once pocock has committed the work it reviews.
review_card_for_branch() {
    local branch="$1"
    local sha
    sha=$(git rev-parse --verify -q "$branch" 2>/dev/null) || return 0
    [[ -z "$sha" ]] && return 0
    python3 "$GATE" --branch "$branch" --sha "$sha" --board "$BOARD" 2>/dev/null \
        | sed -n 's/^CARD \([a-z_0-9]*\)$/\1/p' | head -1
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
    #
    # Under the one-developer flow (boss ruling 2026-10-30) the branch is
    # pocock's own, so the card id does not come from the branch name: the
    # review card that covers it is the one whose body names the sha the
    # branch points at. So the branch's tip sha is the lookup key.
    card="$(card_id_of "$b")"
    if [[ -n "$card" ]]; then
        # A card id in the branch name is a CLAIM, not a fact: the card may
        # have been archived, or the branch may name a card that never
        # existed. The claim only counts when the board still carries
        # that card. Otherwise the lookup falls through to the sha, and a
        # sha that no card names is refused below.
        if ! python3 "$GATE" --card "$card" --board "$BOARD" >/dev/null 2>&1; then
            gate_rc=$?
            if [[ $gate_rc -eq 2 ]]; then
                unreviewed=1
                echo "UNREADABLE $b"
                echo "         the board could not be read, so the card"
                echo "         ($card) this branch names cannot be checked"
                continue
            fi
            card=""
        fi
    fi
    if [[ -z "$card" ]]; then
        card="$(review_card_for_branch "$b")"
    fi
    if [[ -z "$card" ]]; then
        # No review card resolves this branch. That is NOT "no card to
        # gate": under the one-developer flow the sha lookup is the ONLY
        # lookup (= the branch is pocock's own and is not named after a
        # card), so a miss means the work carries no verdict. A gate that
        # skips its own check silently is the exact defect this gate
        # exists to prevent (= a check that cannot fail).
        unreviewed=1
        echo "UNREVIEWED $b"
        echo "         no review card names the sha this branch points at"
        echo "         (the review card's body names the sha under review;"
        echo "          a rebase rewrites the sha, so a re-review must name"
        echo "          the NEW sha)"
        continue
    fi
    if [[ ! -f "$GATE" ]]; then
        # A missing gate is NOT a pass. Refuse, because a merge gate that
        # skips its own check silently is the exact defect this gate exists
        # to prevent (= a check that cannot fail).
        unreviewed=1
        echo "NO GATE  $b"
        echo "         the review gate is missing: $GATE"
        echo "         (the gate ships with Tools/wenshu-devtool/review_gate.py;"
        echo "          merge that first, or this merge lands unchecked)"
        continue
    fi
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
    elif [[ $gate_rc -eq 2 ]]; then
        # The board could not be read. That is NOT "no verdict": it is
        # "the verdict is unknown", and an unknown verdict must not read
        # as an approving one.
        unreviewed=1
        echo "UNREADABLE $b"
        echo "$gate_out" | sed 's/^/         /'
    elif [[ $gate_rc -ne 0 ]]; then
        # Any other non-zero exit is a gate that could not give its
        # answer. Refuse: a gate that cannot fail is not a gate.
        unreviewed=1
        echo "UNREVIEWED $b"
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
