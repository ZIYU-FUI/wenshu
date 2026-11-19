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
# THE BRANCH NAME IS NOT ASKED (2026-11-19; the third pass at one defect). A
# card id inside a branch name is a CLAIM about a DIFFERENT commit, and a
# claim is not a verdict. It could not bless: `t_5bff7b80`'s approval of
# `7e3878dcdc` printed a bare CLEAN over a tip whose newest verdict was
# `changes_requested`. And it did veto. Measured on `wenshu-par` on
# 2026-11-19 against `origin/main`'s refusal path, = which whitelisted ONE
# literal, `no_handoff` (:174 of that version): SEVEN live branches were
# refused by a claim answering `changes_requested` about another commit, and
# ONE more, = `project/t_393cc135-…`, = by a claim answering `contract_error`.
# The first pass at this fix (commit `7992995e58`) whitelisted TWO literals
# there, = `no_handoff|contract_error` (:214 of that version), = which cleared
# the one and left the seven. Of the gate's four non-zero answers (1, 2 and 3
# named at `review_gate.py:49-50`, = plus the 4 `main()` returns), exactly ONE
# — 3, = the verdict owed — is what the seven hit: 1 was whitelisted by round
# 1, = 2 prints `UNREADABLE` from the board-read arm, = and 4 (`card_absent`,
# `review_gate.py:1048`) was refused like any other unwhitelisted answer.
# Both shapes are pinned by case functions rather than by a sentence here:
# `case_a_refusal_of_an_other_commit_does_not_veto_the_tip` (the veto that had
# to be removed) and
# `case_a_claim_that_is_not_a_review_card_decides_nothing` (a BUILD card's
# `contract_error`). So the sha lookup is the only reader, its order is the
# authority, and the claim is printed as context when a branch is refused. A
# card body that names its sha outside WHAT TO BUILD's first paragraph
# therefore no longer lands by its branch name: the first paragraph is what
# `review_gate.py:618` (`reviewed_sha`) parses, = = and a body that breaks
# that shape is a body defect, not something the landing gate routes around.
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
#
# ``lookup_rc`` carries the gate's exit code to the caller, because "the
# board could not be read" (= 2) and "no card names this sha" (= 3) are
# different failures and the caller names them differently. The caller
# reads it from a FILE: the lookup runs inside a command substitution
# (= a subshell), so a variable it set would not survive.
LOOKUP_RC="$(mktemp "${TMPDIR:-/tmp}/wenshu-lookup-rc.XXXXXX")"
trap 'rm -f "$LOOKUP_RC"' EXIT

# ``governing_card`` prints the ONE review-card id that decides a branch: the
# head of the list the sha lookup returns, = = which is the gate's own order
# (= newest verdict first, in ``matching_cards``). = = The tail is not
# returned because nothing may read it: = = round 1 of this fix kept it and
# consulted it on the refusal path only, = = and that asymmetry is the defect
# that vetoed live branches whose named card had refused an OLDER commit.
governing_card() {
    local branch="$1"
    local sha
    local out
    # The rc file is written on EVERY path, = = including the two failures
    # below: = = a reader that fell back to the previous branch's rc would
    # print this branch's answer as "the board is unreadable" because an
    # earlier branch could not be read. = = A command substitution cannot
    # return a value, = = so this file is the only channel the caller has.
    printf '0' > "$LOOKUP_RC"
    sha=$(git rev-parse --verify -q "$branch" 2>/dev/null) || return 0
    [[ -z "$sha" ]] && return 0
    out="$(python3 "$GATE" --branch "$branch" --sha "$sha" --board "$BOARD" 2>/dev/null)"
    printf '%s' "$?" > "$LOOKUP_RC"
    printf '%s\n' "$out" | sed -n 's/^CARD \([a-z_0-9]*\)$/\1/p' | head -1
}

conflict=0
unreviewed=0
for b in "${branches[@]}"; do
    out="$(git merge-tree --write-tree --name-only --messages main "$b" 2>&1)"
    rc=$?
    if [[ $rc -eq 0 ]]; then
        behind=$(git rev-list --count "$b..main" 2>/dev/null || echo "?")
        echo "CLEAN    $b   (behind main by $behind commit(s) -> rebase in its worktree, then ff;"
        echo "         a rebase rewrites the sha but not the edit, so the card that"
        echo "         reviewed it still covers the branch)"
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
    #
    # The gate file is checked FIRST: a missing gate is a missing gate, and
    # running the lookups before the check makes the gate's own failure
    # (= python cannot open the file) read as "the board is unreadable".
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
    # = = = THE AUTHORITY, READ ONCE. = = governing_card prints the ONE
    # = = = review card the sha lookup says decides this branch (the head of
    # = = = the gate's own order in matching_cards, = = review_gate.py:474),
    # = = = and it writes the gate's exit code to LOOKUP_RC because a command
    # = = = substitution cannot return one.
    governing="$(governing_card "$b")"
    lookup_rc="$(cat "$LOOKUP_RC" 2>/dev/null || echo 0)"

    # = = = THE BRANCH NAME IS NO LONGER ASKED. = = It used to be read for a
    # = = card id, and that id's verdict could decide the branch. Three
    # = = measured defects came from that, all on this board 2026-11-19:
    # = =
    # = =   1. hole 1: a branch named after its BUILD card. That card
    # = =      answers `contract_error`, and the gate refused a tip whose
    # = =      own covering card had approved it (= project/t_393cc135-t2-…
    # = =      at 9137874fd9, approved by t_178fe9d5).
    # = =   2. hole 2: a branch named after a REVIEW CARD that approved a
    # = =      DIFFERENT commit. The claim answered `approved`, so the
    # = =      branch printed a bare CLEAN with no verdict line at all
    # = =      (= project/t_5bff7b80-t2-… at 77465d9066, whose newest
    # = =      verdict is t_712673d9's changes_requested).
    # = =   3. F1, the first version of THIS fix: membership in the covering
    # = =      list was checked on the approving path only, while the
    # = =      refusal path still decided by a two-literal whitelist
    # = =      (`no_handoff|contract_error`), so the ONE answer the seven
    # = =      branches actually hit — exit 3, the verdict owed — still
    # = =      vetoed an approved tip (= the named
    # = =      card t_10af78c5 refused an OLDER sha 0b6fcd88e4 while the
    # = =      lookup read CARD t_30847781 approved for tip 31b5c3929a ->
    # = =      rc 3, where the control on the SAME tip, a branch whose name
    # = =      claims nothing (project/t_ce7c0c11-t3-…), read rc 0). Seven
    # = =      live branches sat on that asymmetry, and the only difference
    # = =      between them was the name. The other three non-zero answers
    # = =      did none of this work: = 1 was the second whitelist literal,
    # = =      2 printed `UNREADABLE` from the board-read arm, = 4
    # = =      (`card_absent`) was refused like any unwhitelisted answer
    # = =      (= `review_gate.py:49-50`, = and `main()`'s `return 4`).
    # = =
    # = = The rule those three share is not "check the claim against the
    # = = lookup": it is that a claim decides nothing. Asking it at all was
    # = = the defect, so it is no longer asked (= and an answer nobody can
    # = = use is not kept as a spare).
    # = = A card whose body names its sha OUTSIDE the WHAT TO BUILD claim
    # = = therefore no longer lands by its branch name: AGENTS.md §1.15
    # = = requires the heading, and `review_gate.py:618` (`reviewed_sha`)
    # = = parses the sha out of its FIRST paragraph, so a body that breaks
    # = = that shape is a body defect, not something the gate routes around.
    card="$governing"

    if [[ -z "$card" ]]; then
        if [[ "${lookup_rc:-0}" -eq 2 ]]; then
            # The gate could not read the board, so it could not answer.
            # That is not "no card names this sha": it is "the answer is
            # unknown", and an unknown answer must not read as a pass.
            unreviewed=1
            echo "UNREADABLE $b"
            echo "         the review gate could not read the board"
            continue
        fi
        # No review card resolves this branch. That is NOT "no card to
        # gate": under the one-developer flow the sha lookup is the ONLY
        # lookup, so a miss means the work carries no verdict. A gate that
        # skips its own check silently is the exact defect this gate exists
        # to prevent (= a check that cannot fail).
        unreviewed=1
        echo "UNREVIEWED $b"
        echo "         no review card names the sha this branch points at"
        claimed="$(card_id_of "$b")"
        if [[ -n "$claimed" ]]; then
            # Named for the reader, not for the verdict: the branch's own
            # card id is NOT a verdict on this tip (= findings 1 to 3 above).
            echo "         (the branch name claims $claimed; a claim is not"
            echo "          a verdict on this commit, so it was not asked)"
        fi
        echo "         (the review card's body names the sha under review in"
        echo "          the first paragraph of WHAT TO BUILD; the gate"
        echo "          matches the CHANGE, so a rebased branch still"
        echo "          matches the card that reviewed it)"
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
