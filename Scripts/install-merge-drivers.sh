#!/usr/bin/env bash
# install-merge-drivers.sh — wire the repo's merge drivers into git config.
#
# WHY THIS IS ITS OWN SCRIPT
#
# A merge driver has two halves: `.gitattributes` NAMES it (tracked, so it
# ships with the checkout) and `.git/config` DEFINES it (local, so it does
# not). Only the first half travels with a clone. A clone that never ran
# the installer holds an attribute with no driver behind it, and git does
# NOT report that: when `merge=<name>` names a driver git cannot find,
# git falls back to its built-in text merge and prints nothing.
#
# For the two files the repo drives (= the string catalog and the nervous
# file index) that fallback is exactly the collision the driver exists to
# prevent: two cards each adding one key both keep theirs under the driver
# and one of them loses the row under the fallback.
#
# The wiring used to live inside `Scripts/setup-dev-env.sh`, which also
# installs Homebrew and builds the package. That made "wire my merge
# drivers" cost a toolchain install, so a fresh clone, a CI runner, or a
# worktree added before the installer ran kept the silent text merge. This
# script has no dependency beyond git and python3, so the wiring can be
# run on its own, and `setup-dev-env.sh` calls it.
#
# It is SAFE TO RUN MORE THAN ONCE: every setting is written with the same
# value, so the second run changes nothing.
#
# Usage:
#   bash Scripts/install-merge-drivers.sh            # this repo
#   bash Scripts/install-merge-drivers.sh <repo>     # another checkout
#
# Run:  python3 Tools/wenshu-devtool/tests/test_merge_drivers.py
set -euo pipefail

REPO="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found (= the merge drivers are python scripts)." >&2
  exit 1
fi

# The driver path is repo-relative: git runs a merge driver from the top
# of the working tree, so the command names `Scripts/...` and not an
# absolute path. That is what makes it travel with the clone.
git config merge.xcstrings.driver "python3 Scripts/merge-xcstrings.py %O %A %B"
git config merge.nfi-registry.driver "python3 Scripts/merge-nfi-registry.py %O %A %B"

# rerere records how a conflict was resolved once and replays it the next
# time the same conflict appears on the same file. Without it, the recurring
# magnets (the string catalog, the NFI registry, AGENTS.md, Package.swift)
# cost one resolution per card instead of one per wave.
git config rerere.enabled true

echo ">>> merge drivers wired in $REPO"
echo "    merge.xcstrings.driver    = $(git config --get merge.xcstrings.driver)"
echo "    merge.nfi-registry.driver = $(git config --get merge.nfi-registry.driver)"
echo "    rerere.enabled            = $(git config --get rerere.enabled)"
