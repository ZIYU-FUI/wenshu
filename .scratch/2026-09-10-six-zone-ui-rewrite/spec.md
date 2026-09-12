# Wenshu Six-Zone UI Rewrite

**Date**: 2026-09-10
**Branch**: `wt/m1/navigation-split-shell`
**Trigger**: boss 2026-09-10 OOB 'ui \u91cd\u6784' + boss 2026-09-10 second OOB clarification = 'NAV default 3 columns + each column's sub-areas. Visually it's 5 columns.' middle column = upper outline + lower card grid (= 2 sub-areas inside 1 NSV column).
**Goal**: Land the middle column (= ShellMiddleColumn) as a real VSplitView of outline (top) + card grid (bottom). Drop hardcoded Text() placeholders. Keep the existing 3 NSV columns + sidebar VSplitView + detail VSplitView + inspector Tools/Dynamic toggle — all already Apple-canonical after the 2026-09-10-apple-default-shell 5-ticket batch.

## Boss 2026-09-10 second OOB clarification (this rewrite's source of truth)

Boss on the grill clarification: 'now it's NAV default 3 columns + each column's sub-areas. Visually it's 5 columns.' middle column's sub-area = card grid (move from sidebar bottom into middle column bottom).

This means:
- 3 NSV columns stay (sidebar / content / detail) + .inspector() trailing panel
- Each column has its own sub-areas:
  - sidebar = VSplitView { outline-tree; (cards removed) } — cards migrate out
  - middle (content) = VSplitView { outline-for-selected-book (top); card-grid (bottom) }
  - detail = VSplitView { editor (top); chat (bottom) }
  - inspector = Picker toggle { tools / dynamic }
- Visually 5 panels total because middle has 2 sub-areas + sidebar has 1 sub-area + detail has 2 + inspector 1

## Why this matches the boss's 2026-08-30 design baseline

The boss's red-line drawing on 8/30 had the same shape:
- left column = directory tree (1 zone)
- middle column = outline above + cards below (2 zones, with the cards in the middle = not in the sidebar)
- right column = editor above + chat below (2 zones)

The current state after the 2026-09-10-apple-default-shell batch kept the v0.50 sidebar card-zone pattern (= cards were in the sidebar). Boss now says move cards back to the middle column = restore the 8/30 baseline.

## ComponentIndex.md reconciliation (= the architecture contradiction)

ComponentIndex.md §2.1 describes ZonePerRegionChrome as a 3-row VStack wrapper, but ChromeStubs.swift currently makes it a Plan A pass-through (= no chrome). Boss 9/10 second OOB 'NAV default 3 columns' = Plan A remains (= no custom chrome wrappers). This rewrite does NOT touch ZonePerRegionChrome / ChromeStubs / ComponentIndex.md. The middle column uses bare SwiftUI VSplitView (= same pattern as sidebar + detail columns).

## What this rewrite targets

| # | Zone | Current state | Rewrite target |
|---|---|---|---|
| 1 | Sidebar | VSplitView { NewLibraryOutlineView; ZoneModuleView(.projectPreview) } | VSplitView { NewLibraryOutlineView; Color.clear (cards removed) } |
| 2 | Middle top | Hardcoded Text("\u5927\u7eb2") + ForEach(appState.openTabs) | OutlineForSelectedBook (= new component = real chapters list) |
| 3 | Middle bottom | Hardcoded Text("\u5361\u7247") placeholder | PreviewPane (= existing 1240 LOC, moved from sidebar) |
| 4 | Detail | VSplitView { EditorPlaceholder; ChatZoneView } | Kept (Apple-canonical) |
| 5 | Inspector | Group { switch tools/dynamic } + Picker toolbar | Kept |
| 6 | 6 missing HIG APIs | 1/6 done (.inspector) | Land .searchable + .fileImporter + .fullScreenCover + @SceneStorage + .navigationSubtitle |
| 7 | Strip magic numbers | NavigationSplitShell.swift has hardcoded Text paddings | Route through DesignTokens / ContentStyles / IconStyles |

## Scope boundary (NOT touched)

- ChromeStubs.swift (Plan A pass-through, stays as-is)
- ComponentIndex.md (architecture document, stays as-is; the rewrite does not change the chrome-vs-pass-through decision)
- PaneSplitHost (legacy NSSplitView tree path)
- TabContentDispatcher, ZoneModuleView, EditorPlaceholder, ChatZoneView
- LLM / provider / connector stack
- 5 apple-default-shell commits already shipped (inspector false default + sidebar VSplitView + InspectorCommands drop + 7 menu items drop + ⌘K drop)

## Acceptance criteria

1. swift build exits 0
2. Middle column body = VSplitView with 2 sub-areas: top = outline, bottom = PreviewPane (= existing card grid)
3. Sidebar no longer contains PreviewPane (cards migrated to middle column)
4. .searchable on sidebar List, .fileImporter replaces NSOpenPanel in onboarding, .fullScreenCover for editor focus mode, @SceneStorage on per-window state, .navigationSubtitle on root view
5. Zero hardcoded CGFloat / Color / font-size literals in NavigationSplitShell.swift
6. Zero new files (= existing files only); zero schema additions; zero new third-party libs

## Out of scope (future tickets)

- OutlineForSelectedBook chapter extraction (= new component; deferred until boss review of layout)
- LayoutTreeState / LayoutTreeStore Codable migration
- Drag and drop / wiki-link editor features (= editor features; boss拍 required)
- PreviewPane sidebar migration cleanup (= when sidebar card-zone is finally deleted)

---

*Spec by pocock single agent · boss 2026-09-10 second OOB clarification = visual 5 columns · English-only per AGENTS.md §11 · project root /Volumes/ANAN/Engineering/wenshu/*
