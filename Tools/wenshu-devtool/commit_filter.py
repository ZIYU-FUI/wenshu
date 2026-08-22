#!/usr/bin/env python3
"""
wenshu pre-commit filter. Blocks commits containing forbidden pollution vocabulary.

Forbidden tokens (xianxia novel leakage from base model):
修真 渡劫 筑基 返虚 结丹 金丹 元婴 飞升 天劫 雷劫 心魔 魔障

Allowed tokens (project-mandated literal characters per AGENTS.md §12):
老板 文枢 拍 拍板 ※

Source of truth: .scratch/2026-08-22-pollution-mitigation/spec.md
"""

import re
import subprocess
import sys

FORBIDDEN_TOKENS = [
    "修真", "渡劫", "筑基", "返虚", "结丹", "金丹",
    "元婴", "飞升", "天劫", "雷劫", "心魔", "魔障",
]
PATTERN = re.compile("|".join(re.escape(t) for t in FORBIDDEN_TOKENS))

# Files allowed to mention forbidden vocab (they explicitly enumerate the banned list).
# v0.23 audit #014 added PR + issue templates (which mention the list by name).
POLLUTION_ALLOWLIST = {
    "AGENTS.md",
    "CONTEXT.md",
    "WenshuVerifier.shortOutputStopSequences",  # functional: filter LLM output
    "WenshuAgentIdentity.systemPrompt",         # functional: instruction
    "Tools/wenshu-devtool/commit_filter.py",
    "Tools/wenshu-devtool/tests/test_block_pollution.sh",
    "Tools/wenshu-devtool/tests/test_allow_allowed_tokens.sh",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/ISSUE_TEMPLATE/bug_report.md",
    ".github/ISSUE_TEMPLATE/feature_request.md",
}


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
        # Skip files in pollution allowlist (they legitimately enumerate banned tokens).
        # Match exact path OR path containing allowlist entry (for Sources/.../*).
        if any(
            path == entry or
            path.endswith("/" + entry) or
            (entry.startswith("Sources/") and "/" + entry in path) or
            (entry.startswith("Tools/") and "/" + entry in path)
            for entry in POLLUTION_ALLOWLIST
        ):
            continue
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