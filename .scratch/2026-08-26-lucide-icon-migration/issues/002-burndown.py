#!/usr/bin/env python3
"""
ticket-002 burndown driver — pure text substitutions into the 9 view files.

This is NOT a code generator. It's a documented log of every textual change
made during ticket 002 (= 一次性替换, owner 2026-08-26 grill). After running,
verify with `swift build` + the acceptance greps in
.scratch/2026-08-26-lucide-icon-migration/issues/002-substitution-table.md.

Usage:
    python3 .scratch/2026-08-26-lucide-icon-migration/issues/002-burndown.py
"""

import re, sys, pathlib, shutil

ROOT = pathlib.Path("/Volumes/ANAN/Engineering/wenshu")
VIEWS = ROOT / "Sources/WenshuApp/Views"
APPSWIFT = ROOT / "Sources/WenshuApp/App.swift"

# ---- 1. Static literal substitutions ----------------------------------------
# Each tuple: (file, search_text, replace_text). search_text must match EXACTLY
# (whitespace and all) so it can be applied with the patch tool. We do the
# editing here in one Python pass so the substitutions are auditable.
#
# Format chosen: `WenshuIcon.<case>.image(size:, foregroundStyle:)` instance
# form (= type-safe path, NEVER goes through Layer 3).
#
# Substitution table cross-checked against
# `.scratch/2026-08-26-lucide-icon-migration/issues/002-substitution-table.md`.

STATIC = [
    # App.swift
    (
        APPSWIFT,
        'Image(systemName: providersWithKeys.contains(p.slug) ? "key.fill" : "key")',
        'providersWithKeys.contains(p.slug)\n                            ? WenshuIcon.keyFill.image(size: 14, foregroundStyle: AnyShapeStyle(.green))\n                            : WenshuIcon.key.image(size: 14, foregroundStyle: AnyShapeStyle(.secondary))',
    ),
    (
        APPSWIFT,
        'Image(systemName: hasKey ? "key.fill" : "key")',
        'hasKey\n                ? WenshuIcon.keyFill.image(size: 14, foregroundStyle: AnyShapeStyle(.green))\n                : WenshuIcon.key.image(size: 14, foregroundStyle: AnyShapeStyle(.secondary))',
    ),
    # App.swift: 488, 601, 2040 = three sites using "checkmark"
    # App.swift: 1157 = "doc.badge.plus"
    # App.swift: 1163 = "folder"
    # App.swift: 1169 = "square.and.arrow.down"
    # App.swift: 1197 = "sidebar.left"
    # App.swift: 1208 = "eye.fill"
    # App.swift: 1217 = "wrench.and.screwdriver"
    # App.swift: 1224 = "bubble.left"
    # App.swift: 1231 = "chart.bar"
    # App.swift: 1238 = "square.and.arrow.up"
    # App.swift: 2054 = "cpu"
    # App.swift: 2059 = "chevron.up.chevron.down"
    # App.swift: 2178 = "archivebox"
    #
    # The simplest way is unique-match the surrounding line for each.

    # LibraryOutlineView.swift ternary
    (
        VIEWS / "Library" / "LibraryOutlineView.swift",
        'Image(systemName: firstShelfHasBooks ? "books.vertical" : "books.vertical.fill")',
        'firstShelfHasBooks\n                ? WenshuIcon.booksVertical.image(size: 16)\n                : WenshuIcon.booksVerticalFill.image(size: 16)',
    ),
]

# ---- 2. Dynamic-string substitutions ---------------------------------------
# These route through `WenshuIcon.image(name:)` = Layer 3 fallback path.

DYNAMIC = [
    # ChatView.swift: 420 — Image(systemName: sourceIcon)
    # DynamicZoneView.swift: 78 — Image(systemName: tab.icon)
    # ZoneContentView.swift: 132 — Image(systemName: item.icon)
    # App.swift: 696 — Image(systemName: task.icon)
    # App.swift: 2158 — Image(systemName: tab.icon)
    # App.swift: 2207 — Image(systemName: icon)
]


def main():
    """Report (not auto-apply): print the planned diffs and exit."""
    print("Static substitutions planned:")
    for path, search, replace in STATIC:
        try:
            text = path.read_text()
        except FileNotFoundError:
            print(f"  MISSING: {path}")
            continue
        n = text.count(search)
        if n == 0:
            print(f"  NO MATCH: {path.name}: '{search[:60]}...'")
        elif n > 1:
            print(f"  AMBIGUOUS ({n}x): {path.name}: '{search[:60]}...'")
        else:
            print(f"  OK: {path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
