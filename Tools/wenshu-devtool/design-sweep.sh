#!/usr/bin/env bash
# design-sweep.sh - the mobile view sweep (AGENTS.md 7.3).
#
# It answers one question about the changed Swift files: does a view
# spell a value that belongs to the token file or the icon factory?
#
#   naked glyph       Image(systemName: "x")        -> SFIcon
#   inline radius     .cornerRadius(8)              -> DesignTokens
#   inline font size  .font(.system(size: 13))      -> DesignTokens
#   magic spacing     .padding(13) / .spacing(13)   -> DesignTokens
#
# The factory and the token file are exempt: they are where the values
# are allowed to be written down.
#
# Usage: design-sweep.sh [file ...]
#        design-sweep.sh            (= the files changed against main)
#
# The client (Mobile/) is the subject of this sweep: it carries the icon
# factory and the token file, so its paths are the ones in scope here.
set -uo pipefail

REPO="${WENSHU_MOBILE_REPO:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$REPO" || exit 2

EXEMPT='(Shared/UI/(SFIcon|DesignTokens)\.swift)$'

files=()
if [[ $# -gt 0 ]]; then
    files=("$@")
else
    while IFS= read -r f; do
        [[ -n "$f" ]] && files+=("$f")
    done < <(git diff --name-only main...HEAD -- 'Mobile/Sources/**.swift' 'Mobile/Tests/**.swift' 2>/dev/null)
fi

if [[ ${#files[@]} -eq 0 ]]; then
    echo "design sweep: no changed Swift files"
    exit 0
fi

scan() {
    local label="$1" pattern="$2"
    local hits=0
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        [[ "$f" =~ $EXEMPT ]] && continue
        local n
        n=$(grep -nE "$pattern" "$f" | grep -vE 'SFIcon\.|DesignTokens\.' | wc -l | tr -d ' ')
        if [[ "$n" -gt 0 ]]; then
            # The report goes to stderr, the count to stdout: the caller
            # captures stdout into a number, and a report line in that
            # stream made the total an arithmetic error (= the sweep died
            # instead of reporting the violation it had just found).
            echo "  ! $label: $f ($n)" >&2
            grep -nE "$pattern" "$f" | grep -vE 'SFIcon\.|DesignTokens\.' | sed 's/^/      /' | head -5 >&2
            hits=$((hits + n))
        fi
    done
    echo "$hits"
}

total=0
echo "design sweep on ${#files[@]} file(s)"
for spec in "naked glyph:Image\(systemName:" \
            "inline radius:\.cornerRadius\([0-9]" \
            "inline font size:\.font\(\.system\(size:" \
            "magic spacing:\.(padding|spacing)\([0-9]"; do
    label="${spec%%:*}"
    pattern="${spec#*:}"
    n=$(scan "$label" "$pattern")
    total=$((total + n))
done

if [[ "$total" -gt 0 ]]; then
    echo "=== $total design violation(s): route the value through SFIcon or DesignTokens ==="
    exit 1
fi
echo "design sweep clean"
exit 0
