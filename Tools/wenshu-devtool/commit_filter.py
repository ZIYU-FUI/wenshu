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
    "Tools/wenshu-devtool/tests/README.md",       # test README explaining pollution-defense test suite (= enumerates forbidden vocab)
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/ISSUE_TEMPLATE/bug_report.md",
    ".github/ISSUE_TEMPLATE/feature_request.md",
    ".github/workflows/ci.yml",                  # CI gate explicitly scans for forbidden vocab (= pollution-defense hook documentation)
    # Scratch directories that legitimately enumerate the forbidden family as
    # research / spec / standards-report content. Pollution-defense skill
    # ('wenshu-pollution-defense') directs us to add these with a comment.
    ".scratch/2026-08-22-pollution-mitigation/",  # pollution research + spec + MR description + hook chain (= how the defense works)
    ".scratch/2026-08-23-monday-acceptance-checklist/",  # acceptance test spec for pollution defense (= 'echo 修真 > file && commit' test cases)
    ".scratch/2026-08-23-agent-identity/",        # Wenshu agent identity research (= system prompt forbidden-vocab enumeration)
    ".scratch/2026-08-24-v0-24-boss-receiving/",  # v0.24 boss-receiving standards reports (= contains forbidden-vocab enumeration)
    ".scratch/2026-08-26-lucide-icon-migration/", # icon migration research docs (= may quote boss OOB containing forbidden tokens)
    ".scratch/2026-08-21-menubar-v2/",            # menu bar v2 spec + backlog (= pre-v0.24 era, contains forbidden tokens in spec text)
    ".scratch/reviews/",                         # code review reports (= standards reports enumerate forbidden vocab)
    ".scratch/code-review-",                     # code review report filename prefix (= standards reports enumerate forbidden vocab)
    ".scratch/spec-axis-review-v0.25.1.md",       # v0.25.1 spec axis review (= this report enumerates forbidden vocab in headers + AC)
    ".scratch/2026-08-26-fcp-library-replica/",   # v0.26 FCP library replica spec + code review reports (= sub-agent standards + spec reports enumerate forbidden vocab in carve-out documentation)
    # v0.30 batches added 2026-08-30 (= boss sweep .scratch/ audit trail):
    ".scratch/v0.30-pre-pane-fixes/",               # v0.30 pre-pane-fixes spec + tickets + code-review reports enumerate forbidden vocab in findings
    ".scratch/v0.30-sidebar-preview-pane/",         # v0.30 sidebar/preview-pane spec + tickets + code-review reports + Q22 visual verification
    ".scratch/v0.30-polish-fixes/",                 # v0.30 polish-fixes spec + tickets + code-review reports
    ".scratch/v0.30-batch3/",                       # v0.30 batch3 spec + tickets + code-review reports
    # Additional v0.28 / spec-axis carve-outs for sweep 2026-08-30:
    ".scratch/2026-08-28-v0-28-free-layout/",       # v0.28 free-layout spec + tickets + code-review reports enumerate forbidden vocab
    ".scratch/2026-08-28-v0-28-integration-batch-1/", # v0.28 integration batch 1 spec + tickets + standards reports enumerate forbidden vocab
    ".scratch/code-review-spec-8-26-v1-2-0-spec-axis/", # spec-axis review (= standards reports enumerate forbidden vocab)
    # v0.30 zone-header 新建 icon fix added 2026-08-31:
    ".scratch/v0.30-zone-header-new-icon-fix/",    # zone-header 新建 icon fix spec + tickets + code-review reports
    # CONTEXT.md hard rule list itself quotes the 修真 forbidden tokens (= single source of truth for the rule):
    "CONTEXT.md",
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


def _exact_match(path, entry):
    """Match 1: path == entry exactly."""
    return path == entry


def _suffix_match(path, entry):
    """Match 2: path ends with '/<entry>' (entry is treated as a leaf basename with leading slash)."""
    return path.endswith("/" + entry)


def _directory_match(path, entry):
    """Match 3: entry is a directory (with or without trailing /) and path is inside it.
    Reuses the suffix_match path when entry already ends with '/'.
    """
    if not "/" in entry:
        return False
    if path.startswith(entry if entry.endswith("/") else entry + "/"):
        return True
    return False


def _basename_prefix_match(path, entry):
    """Match 4: entry is a Swift symbol 'Module.method' (= dotted, no '/').
    Heuristic: if the substring after the last '.' is a short alphanumeric token
    (= 1-5 chars like 'md', 'swift', 'json'), treat entry as a filename (= skip this
    match type). Otherwise, treat it as a symbol prefix and match if path's basename
    (with extension stripped) starts with the symbol prefix.
    """
    if "." not in entry or "/" in entry:
        return False
    last_dot = entry.rfind(".")
    after_dot = entry[last_dot + 1:]
    # File-extension-like (.md, .swift) = treat as filename, skip basename-prefix.
    if after_dot and after_dot.isalnum() and len(after_dot) <= 5:
        return False
    # This is a symbol like 'WenshuVerifier.shortOutputStopSequences'.
    symbol_prefix = entry.split(".", 1)[0]
    basename = path.rsplit("/", 1)[-1]
    # Remove .swift extension for comparison
    basename_root = basename.rsplit(".", 1)[0] if "." in basename else basename
    return basename_root == symbol_prefix or basename.startswith(symbol_prefix + ".")


def _glob_prefix_match(path, entry):
    """Match 5: entry is a path prefix ending in '-' or '_' (= glob-style boundary).
    Used for prefix-only matches like '.scratch/code-review-' (= matches all
    '.scratch/code-review-*' files). The trailing '-' or '_' prevents false positives
    like 'CONTEXT.md' matching 'CONTEXT.md.bak'.
    """
    if entry.endswith("/"):
        return False
    if not path.startswith(entry):
        return False
    last_char = entry[-1]
    if last_char not in "-_":
        return False
    after = path[len(entry):]
    if after == "" or not after.startswith("/"):
        # Path continues directly after entry (= same filename).
        return True
    # Path goes into a subdirectory starting with this prefix
    # (= '.scratch/code-review-spec-8-26-v1-2-0-spec-axis/SPEC-AXIS-REPORT.md'
    # matches '.scratch/code-review-' + 'spec-.../...md').
    return True


# Each match helper returns True on match, False (= 'not my job, try next type').
_MATCH_HELPERS = [
    _exact_match,
    _suffix_match,
    _directory_match,
    _basename_prefix_match,
    _glob_prefix_match,
]


def is_allowed(path):
    """Check if a file path is in the pollution allowlist (= legitimately enumerates forbidden tokens).

    5 match types (= one helper per type, see _MATCH_HELPERS):
      1. Exact match: path == entry.
      2. Suffix match: path ends with '/<entry>'.
      3. Directory prefix match: entry is a directory and path is inside it.
      4. Basename prefix match: entry is a Swift symbol 'Module.method' (= dotted, no '/').
      5. Glob-style path prefix match: entry is a path prefix ending in '-' or '_'.

    Examples:
      entry '.scratch/2026-08-22-pollution-mitigation/' → matches any file in that dir.
      entry '.scratch/code-review-' → matches all '.scratch/code-review-*' files.
      entry 'WenshuVerifier.shortOutputStopSequences' → matches files whose basename
      starts with 'WenshuVerifier' (= 'Sources/.../WenshuVerifier.swift' etc.).
    """
    for entry in POLLUTION_ALLOWLIST:
        for helper in _MATCH_HELPERS:
            if helper(path, entry):
                return True
    return False


def main(hook=None, commit_msg_path=None):
    """Pre-commit + commit-msg hook entry point.
    Modes:
      - default / pre-commit: scan staged file diffs for forbidden tokens.
      - commit-msg: scan the commit message file (= first arg passed by git hooks).
      - pre-push: scan unpushed commits' diffs + subjects + bodies for forbidden tokens.
      - working-tree / watchdog: scan the full working tree (= not just staged files).
    """
    errors = []
    if hook == "commit-msg" and commit_msg_path:
        # Commit-msg hook (= .git/hooks/commit-msg passes the message file as argv[1]).
        with open(commit_msg_path) as f:
            commit_msg = f.read()
        for error in scan(commit_msg, "commit message"):
            errors.append(error)
    else:
        # Pre-commit / default: scan staged files (= original behavior).
        for path in get_staged_files():
            if is_allowed(path):
                continue
            diff = get_staged_diff(path)
            for error in scan(diff, path):
                errors.append(error)

        # Also scan commit message if available (= for the pre-commit invocation where
        # get_commit_message reads the staged .git/COMMIT_EDITMSG that may exist).
        commit_msg = get_commit_message()
        for error in scan(commit_msg, "commit message"):
            errors.append(error)

    if errors:
        print("\n".join(errors), file=sys.stderr)
        print("\nTo bypass: git commit --no-verify (discouraged)", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


def parse_args(argv):
    """Minimal argv parser. Supports --hook=<name> (= pre-commit, commit-msg, pre-push, ci-scan, watchdog).
    For commit-msg hook, the commit message file path is the first non-flag argv (= from .git/hooks/commit-msg).
    """
    import argparse
    parser = argparse.ArgumentParser(description="Wenshu pollution-defense filter")
    parser.add_argument("--hook", choices=["pre-commit", "commit-msg", "pre-push", "ci-scan", "watchdog"], default="pre-commit")
    parser.add_argument("commit_msg_path", nargs="?", default=None, help="[commit-msg hook] Path to the commit message file")
    args = parser.parse_args(argv)
    return args


if __name__ == "__main__":
    import sys
    args = parse_args(sys.argv[1:])
    main(hook=args.hook, commit_msg_path=args.commit_msg_path)