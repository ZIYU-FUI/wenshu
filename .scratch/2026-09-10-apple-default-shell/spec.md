# Wenshu Apple-Default Shell Rewrite

**Date**: 2026-09-10
**Branch**: `wt/m1/navigation-split-shell`
**Trigger**: boss 2026-09-10 OOB — "\u4e09\u680f\u5e03\u5c40\u5b9e\u9645\u662f\u628a\u4e09\u680f\u7684\u6240\u6709\u9644\u52a0\u680f\u5168\u5199\u51fa\u6765\u4e86，\u6211\u5e0c\u671b\u539f\u5382\u5e26\u7684\u6240\u6709\u680f\u76ee\u663e\u9690\u63a7\u5236，\u5bbd\u5ea6\u63a7\u5236，\u5168\u7528\u9ed8\u8ba4"
**Goal**: Reduce all wenshu NSV three-column chrome (visibility, width, menu items, custom state) to Apple API defaults. No wenshu-authored `InspectorCommands`, no wenshu-authored `SidebarCommands`, no `@AppStorage` for sidebar heights, no custom drag handles, no `@State var inspectorVisible = true` hardcoded.

## Apple HIG canonical baseline (macOS 27 Tahoe, wenshu target platform)

Apple ships these affordances automatically for `NavigationSplitView`:
- **Sidebar visibility**: `NavigationSplitView` adds a sidebarToggle toolbar item; user can also drag the column header. Cannot be removed via `toolbar(removing:)`.
- **Inspector visibility**: `.inspector(isPresented:)` modifier auto-renders a column-header toolbar button and a chevron in the column edge.
- **Column widths**: SwiftUI's own `min` / `ideal` / `max` defaults; user drags the column header to resize; no manual `.navigationSplitViewColumnWidth` modifier needed unless overrides required.
- **Vertical sub-areas inside one column**: `VSplitView` (SwiftUI, Apple-canonical) — what Mail uses for inbox/message stack.

Apple does NOT ship:
- A "Reset Default Layout" menu item (apps implement their own if they want one).
- Toggle menu items for individual zones (apps implement their own).

## What wenshu currently does that is NOT Apple default (the 5 cleanup targets)

| # | Pattern | File | Action |
|---|---|---|---|
| 1 | `@State var inspectorVisible: Bool = true` hardcoded | `UI/Layout/NavigationSplitShell.swift:71` | Change to default `@State` (no initial value) — SwiftUI uses `false` default for inspector when not bound |
| 2 | `@AppStorage("wenshu.sidebar.cardZoneHeight") var cardZoneHeight: Double = 260` + custom drag handle (Rectangle + DragGesture + NSCursor) | `UI/Layout/NavigationSplitShell.swift:196-289` | Replace with `VSplitView { NewLibraryOutlineView(); ZoneModuleView(zoneSlot: .projectPreview) }` — Apple-native vertical split |
| 3 | `InspectorCommands()` in `.commands` block | `App/AppRootScene.swift:92` | Delete — boss says "\u5e9f\u5f03\u7684\u83dc\u5355\u9879\u8981\u5220". NSV inspector chevron still works |
| 4 | Custom View menu items: toggle_project_sidebar / toggle_project_preview / toggle_specialized_tools / toggle_ai_chat / toggle_ai_dynamic + Reset Layout + Layout Edit Mode | `App/AppRootScene.swift:166-228` | Delete all 7 menu items |
| 5 | Custom File > ⌘K Command Palette menu item (replaces `.newItem`) | `App/AppRootScene.swift:120-124` | Delete — revert `.newItem` to macOS default New File behavior |

## Scope boundary (NOT touched by this rewrite)

- Three-column NSV structure (Sidebar / Content / Detail) = kept
- `.inspector(isPresented: $inspectorVisible)` API call site = kept, only the `@State` initialization changes
- Detail column body `VSplitView { EditorPlaceholder; ChatZoneView }` = kept (already Apple-canonical)
- `Settings { SettingView() }` scene + macOS-default Cmd+, binding = kept
- `.windowToolbarStyle(.unified)` 52 PT Liquid Glass chrome = kept
- `PaneSplitHost` (legacy NSSplitView tree path) = NOT touched (different code path; out of M1 scope)

## Acceptance criteria

1. `swift build` exits 0
2. App launches; three columns render; sidebar toggle works via NSV header drag; inspector toggle works via NSV inspector chevron
3. View menu has NO wenshu-authored zone toggles; NO Reset Layout; NO Edit Mode; NO Command Palette; macOS-standard Settings... item remains (auto-generated from Settings scene)
4. Sidebar card region resizes via `VSplitView` drag handle (= Apple AppKit default 8 PT thick divider with grab handle)
5. `.state(false)` for `inspectorVisible` (or omit init entirely = SwiftUI default false)
6. Zero new files in this rewrite (= existing files only); zero schema additions

## Out of scope (future tickets)

- Real OutlineView + CardGridView content for middle column (= M2 content migration)
- Real specialized tools + dynamic content for right column (= M2 content migration)
- `PaneSplitHost` deprecation (= old tree path; M3 ticket)

---

*Spec by pocock single agent · Apple HIG canonical baseline · English-only per AGENTS.md §11 · project root /Volumes/ANAN/Engineering/wenshu*
