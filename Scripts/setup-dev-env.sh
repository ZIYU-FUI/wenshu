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
# The merge drivers live in their own script (= no brew, no swift build),
# so a fresh clone can wire them on their own. This call keeps the ONE
# command that prepares a machine, and the wiring itself has one home.
bash Scripts/install-merge-drivers.sh

echo ">>> wenshu dev environment ready."
echo "    Next: swift test (run the full test suite)"