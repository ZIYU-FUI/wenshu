# Ticket 001 — migrate card zone from sidebar bottom to middle column bottom

## Rule
Boss 2026-09-10 second OOB: cards belong in the middle column (= the baseline 8/30 red-line drawing), not the sidebar. Move PreviewPane (= current sidebar bottom = `ZoneModuleView(zoneSlot: .projectPreview)`) out of the sidebar VSplitView and into the middle column's bottom sub-area.

Sidebar bottom becomes an empty placeholder (= Color.clear) — the v0.49 sidebar card-zone pattern is reverted. This restores the 8/30 boss-approved layout.

## Diff scope
`Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift`:
- ShellSidebarColumn VSplitView: bottom sub-area changes from `ZoneModuleView(zoneSlot: .projectPreview)` to `Color.clear` (or removed entirely — depends on ticket 009's literal-strip audit)
- ShellMiddleColumn: replace the hardcoded `Text("\u5361\u7247")` placeholder with `PreviewPane(...)`

## Why
Boss 9/10 OOB 'cards into middle column sub-area' restores the 8/30 red-line drawing. The 9/9 v0.49 sidebar card-zone was a temporary hold; the final layout has cards in the middle column.

## Verify
- swift build → exit 0
- launch app → sidebar = outline only; middle = outline (top) + card grid (bottom); visually 5 columns
