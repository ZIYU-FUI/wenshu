# 004 — Pre-commit filter (commit_filter.py + install_hook.sh + tests)

> Parent spec: `.scratch/2026-08-22-pollution-mitigation/spec.md` (commit 4 of 4).
> New files (5):
> - `Tools/wenshu-devtool/commit_filter.py`
> - `Tools/wenshu-devtool/install_hook.sh`
> - `Tools/wenshu-devtool/tests/test_block_pollution.sh`
> - `Tools/wenshu-devtool/tests/test_allow_allowed_tokens.sh`
> - `Tools/wenshu-devtool/tests/README.md`
> 1 commit. Independent of issues 001/002/003.

## What to build

A Python script + shell installer + test fixtures that block commits containing forbidden vocabulary.

## commit_filter.py

```python
#!/usr/bin/env python3
"""
wenshu pre-commit filter. Blocks commits containing forbidden pollution vocabulary.

Forbidden tokens (xianxia novel leakage from base model):
修真 渡劫 筑基 返虚 结丹 金丹 元婴 飞升 天劫 雷劫 心魔 魔障

Allowed tokens (project-mandated literal characters):
老板 文枢 拍 拍板 ※
"""

import re
import subprocess
import sys

FORBIDDEN_TOKENS = [
    "修真", "渡劫", "筑基", "返虚", "结丹", "金丹",
    "元婴", "飞升", "天劫", "雷劫", "心魔", "魔障",
]
PATTERN = re.compile("|".join(re.escape(t) for t in FORBIDDEN_TOKENS))


def get_staged_files():
    """Get list of staged file paths (.md, .swift only)."""
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        capture_output=True, text=True, check=True,
    )
    return [f for f in result.stdout.splitlines() if f.endswith((".md", ".swift"))]


def get_staged_diff(path):
    """Get staged diff for a specific file."""
    result = subprocess.run(
        ["git", "diff", "--cached", "--", path],
        capture_output=True, text=True, check=True,
    )
    return result.stdout


def get_commit_message():
    """Get current commit message from .git/COMMIT_EDITMSG (only when committing)."""
    result = subprocess.run(
        ["git", "diff", "--cached", "--", ".git/COMMIT_EDITMSG"],
        capture_output=True, text=True,
    )
    return result.stdout


def scan(text, source):
    """Scan text for forbidden tokens. Yield error lines."""
    for line_no, line in enumerate(text.splitlines(), 1):
        match = PATTERN.search(line)
        if match:
            context = line.strip()[:80]
            token = match.group(0)
            yield f"ERROR: forbidden vocabulary '{token}' in {source}:{line_no} | {context}"


def main():
    errors = []
    for path in get_staged_files():
        diff = get_staged_diff(path)
        for error in scan(diff, path):
            errors.append(error)

    commit_msg = get_commit_message()
    for error in scan(commit_msg, "commit message"):
        errors.append(error)

    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("\nTo bypass: git commit --no-verify (discouraged)", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
```

## install_hook.sh

```bash
#!/usr/bin/env bash
# Install wenshu pre-commit hook for pollution vocabulary filter.
# Idempotent: re-running overwrites existing hook.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FILTER_SCRIPT="$SCRIPT_DIR/commit_filter.py"

if [ ! -f "$FILTER_SCRIPT" ]; then
    echo "ERROR: $FILTER_SCRIPT not found" >&2
    exit 1
fi

GIT_DIR="$(git rev-parse --git-dir)"
HOOK_PATH="$GIT_DIR/hooks/pre-commit"

mkdir -p "$(dirname "$HOOK_PATH")"

cat > "$HOOK_PATH" <<EOF
#!/usr/bin/env bash
# wenshu pre-commit hook. installed by Tools/wenshu-devtool/install_hook.sh
exec python3 "$FILTER_SCRIPT"
EOF

chmod +x "$HOOK_PATH"

echo "wenshu pre-commit hook installed: $HOOK_PATH"
echo "Filter: $FILTER_SCRIPT"
echo "Test: try a commit with forbidden vocab to verify it blocks."
```

## test_block_pollution.sh

```bash
#!/usr/bin/env bash
# Test: forbidden vocab in staged .md blocks commit.
set -e

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

git init -q
git config user.email "test@example.com"
git config user.name "Test"

# Copy filter + install hook
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cp "$SCRIPT_DIR/commit_filter.py" .
mkdir -p .git/hooks
echo "exec python3 $(pwd)/commit_filter.py" > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Forbidden vocab in staged .md
cat > test.md <<EOF
# test
老板 拍 "修真 渡劫 筑基 test"
EOF
git add test.md

# Commit must fail
if git commit -m "test" 2>/dev/null; then
    echo "FAIL: commit should have been blocked"
    exit 1
fi

echo "PASS: commit blocked by forbidden vocab filter"
```

## test_allow_allowed_tokens.sh

```bash
#!/usr/bin/env bash
# Test: only allowed tokens in staged .md → commit allowed.
set -e

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"

git init -q
git config user.email "test@example.com"
git config user.name "Test"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cp "$SCRIPT_DIR/commit_filter.py" .
mkdir -p .git/hooks
echo "exec python3 $(pwd)/commit_filter.py" > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Only allowed tokens
cat > test.md <<EOF
# test
老板 拍 文枢 wenshu ※ project
EOF
git add test.md

# Commit must succeed
if git commit -m "老板 拍 test" 2>/dev/null; then
    echo "PASS: commit allowed with only project-mandated tokens"
else
    echo "FAIL: commit should have been allowed"
    exit 1
fi
```

## tests/README.md

```markdown
# wenshu pre-commit filter tests

Self-contained bash tests using `mktemp -d` (no impact on real wenshu repo).

## Run

```bash
cd Tools/wenshu-devtool/tests
./test_block_pollution.sh
./test_allow_allowed_tokens.sh
```

Each test exits 0 on PASS, non-0 on FAIL.

## Coverage

- `test_block_pollution.sh` — staged .md with forbidden vocab → commit blocked (exit 1 from hook).
- `test_allow_allowed_tokens.sh` — staged .md with only allowed tokens (`老板`, `文枢`, `拍`, `拍板`, `※`) → commit succeeds.
```

## Acceptance criteria

- [ ] `commit_filter.py` runs as `pre-commit` hook, blocks commit on forbidden vocab in staged .md / .swift / commit message.
- [ ] Allowed tokens do NOT trigger the filter.
- [ ] `install_hook.sh` sets up hook on fresh clone; idempotent on re-run.
- [ ] `test_block_pollution.sh` exits 0 (test passes).
- [ ] `test_allow_allowed_tokens.sh` exits 0 (test passes).
- [ ] Python syntax check passes (`ast.parse`).
- [ ] Bash syntax check passes (`bash -n` for `.sh` files).
- [ ] Code-review 2 axes: Standards (PEP 8 / shellcheck) + Spec.

## Files touched

- `Tools/wenshu-devtool/commit_filter.py` (new)
- `Tools/wenshu-devtool/install_hook.sh` (new)
- `Tools/wenshu-devtool/tests/test_block_pollution.sh` (new)
- `Tools/wenshu-devtool/tests/test_allow_allowed_tokens.sh` (new)
- `Tools/wenshu-devtool/tests/README.md` (new)

## Out of Scope

- CI integration.
- Test fixtures for other wenshu-devtool commands.
- Cleanup of `$TMPDIR` after test (handled by `trap` + `EXIT`).

## Risks

- False positives: forbidden tokens appearing in code references / commit history. Mitigation: allowed-token list covers brand + address. If false positive on actual content, escalate to 老板.
- Bypass: `git commit --no-verify` always works. Mitigation: log to stderr (not enforced, relies on culture).