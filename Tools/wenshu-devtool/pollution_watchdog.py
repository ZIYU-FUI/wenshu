#!/usr/bin/env python3
"""
wenshu pollution watchdog — scans the working tree for forbidden vocab in any
untracked + modified files. Designed to be run by cron / a periodic watcher.

Exits 0 if no pollution found.
Exits 1 if pollution found — prints the offending paths to stdout (cron can pipe
to a notification channel).

Usage:
    python3 pollution_watchdog.py /path/to/repo

Why a separate script from commit_filter.py:
- commit_filter.py scans staged content (pre-commit) or unpushed commits (pre-push)
- this script scans the FULL working tree, including untracked files that haven't
  been `git add`ed yet. Catches pollution in draft docs before they reach git.
"""

import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from commit_filter import FORBIDDEN_TOKENS, PATTERN, is_allowed, scan  # noqa: E402


def list_all_md_files(repo):
    """Find all .md files in repo, including untracked ones."""
    result = subprocess.run(
        ["git", "-C", repo, "ls-files", "--others", "--exclude-standard", "--modified",
         "--deleted", "--exclude-standard", "--full-name", "-z"],
        capture_output=True, check=True,
    )
    tracked = subprocess.run(
        ["git", "-C", repo, "ls-files", "-z"],
        capture_output=True, check=True,
    )
    files = set()
    for blob in result.stdout.split(b"\x00"):
        if blob:
            files.add(blob.decode("utf-8"))
    for blob in tracked.stdout.split(b"\x00"):
        if blob:
            files.add(blob.decode("utf-8"))
    return sorted(f for f in files if f.endswith((".md", ".swift", ".txt", ".json", ".yaml", ".yml")))


def _scan_for_pollution(repo: str, files: list[str]) -> list[str]:
    """Return a flat list of scan()-emitted error strings for each file.

    Filters out:
      - paths missing on disk (= deleted between ls-files + open).
      - paths allowed by commit_filter.is_allowed (= legitimate enumerations
        of the forbidden vocab, e.g. AGENTS.md + commit_filter.py itself).
      - non-utf-8 / non-readable files (= binary blobs, missing perms).

    Returns the raw error strings (= caller formats them for stdout vs
    cron output vs exit code).
    """
    errors: list[str] = []
    for relpath in files:
        abspath = os.path.join(repo, relpath)
        if not os.path.isfile(abspath):
            continue
        if is_allowed(relpath):
            continue
        try:
            with open(abspath, "r", encoding="utf-8") as f:
                text = f.read()
        except (UnicodeDecodeError, PermissionError):
            continue
        errors.extend(scan(text, relpath))
    return errors


def _report_and_exit(repo: str, errors: list[str]) -> int:
    """Print either the OK banner or the pollution report. Returns exit code."""
    if errors:
        print(f"POLLUTION DETECTED in {repo}:")
        for err in errors:
            print(f"  {err}")
        print(f"\nTotal: {len(errors)} forbidden-vocab hits across the working tree.")
        return 1
    print(f"OK: 0 forbidden-vocab hits in {repo}")
    return 0


def main():
    if len(sys.argv) < 2:
        print("Usage: pollution_watchdog.py /path/to/repo", file=sys.stderr)
        sys.exit(2)
    repo = os.path.abspath(sys.argv[1])
    if not os.path.isdir(os.path.join(repo, ".git")):
        print(f"Not a git repo: {repo}", file=sys.stderr)
        sys.exit(2)

    files = list_all_md_files(repo)
    errors = _scan_for_pollution(repo, files)
    sys.exit(_report_and_exit(repo, errors))


if __name__ == "__main__":
    main()
