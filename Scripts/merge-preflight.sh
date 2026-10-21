#!/usr/bin/env bash
# merge-preflight.sh — answer "will this card branch conflict with main?"
# WITHOUT merging.
#
# git merge-tree --write-tree does a real 3-way merge in memory and writes
# unreferenced objects only: no branch moves, no index changes, no file in
# the working tree changes. Its exit code is the answer.
#
#   0 = clean, land it
#   1 = conflict, and the conflicting paths are printed
#
# The card branch usually also needs a rebase first (= it is behind main).
# That is drift, not a conflict: the rebase is what makes the landing a
# fast-forward, and it belongs in the card's OWN worktree so a conflict
# cannot destroy a sibling session's staged work.
#
# Usage:
#   merge-preflight.sh <card-branch> [<card-branch> ...]
#   merge-preflight.sh --all          # every project/ branch on the repo
set -uo pipefail

REPO="${WENSHU_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO" || exit 2

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

conflict=0
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
done

exit $conflict
