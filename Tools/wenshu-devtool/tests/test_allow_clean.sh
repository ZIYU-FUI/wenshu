#!/usr/bin/env bash
# Test: a clean commit message + clean file body passes all three hooks.
# Run from Tools/wenshu-devtool/tests/ directory.

set -e

SCRIPT_PATH="${BASH_SOURCE[0]}"
case "$SCRIPT_PATH" in
    /*) ;;
    *)  SCRIPT_PATH="$(pwd)/$SCRIPT_PATH" ;;
esac
SCRIPT_DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
FILTER_SCRIPT="$SCRIPT_DIR/../commit_filter.py"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

git init -q
git config user.email "test@example.com"
git config user.name "Test"

cp "$FILTER_SCRIPT" .
mkdir -p .git/hooks
for hook in pre-commit commit-msg pre-push; do
    if [ "$hook" = "commit-msg" ]; then
        printf '#!/usr/bin/env bash\nexec python3 %s/commit_filter.py --hook=commit-msg "$1"\n' "$(pwd)" > .git/hooks/$hook
    else
        printf '#!/usr/bin/env bash\nexec python3 %s/commit_filter.py --hook=%s\n' "$(pwd)" "$hook" > .git/hooks/$hook
    fi
    chmod +x .git/hooks/$hook
done

cat > test.md <<EOF
# test
A clean fix commit. Subject uses English only. No forbidden vocab anywhere.
EOF
git add test.md
git commit -m "feat: add test file" -q

echo "PASS: clean commit went through pre-commit + commit-msg without block"
