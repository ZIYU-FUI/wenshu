#!/bin/bash
# setup-dev-env.sh — bootstrap wenshu dev environment on a fresh machine.
#
# Steps:
#   1. Verify brew + swift are installed (exit 1 with hint if missing).
#   2. Run `brew bundle --no-upgrade` (= installs SwiftLint + SwiftFormat
#      at pinned versions per Brewfile).
#   3. Verify tools reachable.
#   4. Verify wenshu builds (= swift build exit 0).
#
# Per AGENTS.md §11.1: "binary tooling via Brewfile + wenshu-devtool hooks chain".

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo ">>> wenshu dev environment setup"

# 1. Verify brew
if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew not found. Install from https://brew.sh first." >&2
    exit 1
fi

# 2. Verify swift
if ! command -v swift >/dev/null 2>&1; then
    echo "ERROR: swift not found. Install Xcode 26+ (Swift 6.4 toolchain) first." >&2
    exit 1
fi

# 3. brew bundle
echo ">>> brew bundle --no-upgrade"
brew bundle --no-upgrade

# 4. Verify tools
echo ">>> verifying tools"
swiftlint --version
swiftformat --version

# 5. Verify wenshu builds (incremental, fast)
echo ">>> swift build"
swift build

# 6. Install the local git settings the parallel-dev workflow needs.
#    These are LOCAL settings (= .git/config, not committed), so a fresh
#    clone has to install them.
echo ">>> installing local git settings"
git config merge.xcstrings.driver "python3 Scripts/merge-xcstrings.py %O %A %B"
git config merge.nfi-registry.driver "python3 Scripts/merge-nfi-registry.py %O %A %B"
# rerere records how a conflict was resolved once and replays it the next
# time the same conflict appears on the same file. Without it, the recurring
# magnets (the string catalog, the NFI registry, AGENTS.md, Package.swift)
# cost one resolution per card instead of one per wave.
git config rerere.enabled true
echo "    merge.xcstrings.driver  = $(git config --get merge.xcstrings.driver)"
echo "    merge.nfi-registry.driver = $(git config --get merge.nfi-registry.driver)"
echo "    rerere.enabled           = $(git config --get rerere.enabled)"

echo ">>> wenshu dev environment ready."
echo "    Next: swift test (run the full test suite)"