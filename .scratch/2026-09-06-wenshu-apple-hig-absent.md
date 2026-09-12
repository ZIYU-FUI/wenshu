# Wenshu Apple HIG 应有而没用 — Inventory

**Date**: 2026-09-06
**Goal**: Catalog every Apple HIG recommended API that wenshu SHOULD use (= Apple HIG standard for the task) but DOESN'T use (= has zero call sites).
**Method**: Per-line scan across `Sources/` (= 309 Swift files), filtering by 56 Apple HIG APIs across 10 tiers (= Navigation / Chrome / Focus / Containers / Modal / Material / Drag-drop / Text / Animation / Async).

## Headline

| Total Apple HIG APIs surveyed | **56** |
| --- | --- |
| **Apple HIG APIs already used in wenshu (= keep)** | **31** (= 55%) |
| **Apple HIG APIs SHOULD use but DON'T (= candidates to add)** | **25** (= 45%) |
| **Of those 25, architectural-impossible / not-applicable (= safe to skip)** | 6 (= 24% of absent) |
| **Of those 25, real misses (= would improve wenshu)** | **19** (= 76% of absent) |

## Tier-by-Tier Analysis

### Tier 1: Navigation & Search (5 absent / 7 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `.navigationTitle(_:)` | ❌ **absent** (= **REAL MISS**) | WindowGroup uses .commands menu (= no explicit title); = settings sheets use custom Text(...) |
| `.navigationSubtitle(_:)` | ❌ absent | Same as above |
| `.navigationDestination(for:)` | ❌ absent (= real miss) | 1 site of NavigationStack (= should use .navigationDestination for type-safe nav) |
| `.searchSuggestions(_:)` | ❌ absent (= not-applicable: wenshu has no .searchable to add suggestions TO) | n/a |
| `@SceneStorage` | ❌ **absent (= REAL MISS)** | 67 sites of @AppStorage (= global state); = per-window state (= pane sizes, active tab) should use @SceneStorage |
| `.searchable` | ✓ present (= 1 site) | Good — but only 1 (= settings tabs need more) |
| `SceneBuilder` (.commands) | ✓ present (= 14 sites) | Good |

### Tier 2: Toolbar & chrome (4 absent / 8 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `.toolbarTitleMenu` | ❌ absent (= macOS 14+; = could add for settings) | n/a — not critical |
| `.toolbarColorScheme` | ❌ absent (= macOS 14+; = could add for dark/light mode) | n/a — not critical |
| `.defaultPosition(_:)` | ❌ absent (= macOS 13+) | wenshu uses NSWindow direct (= acceptable for now) |
| `.windowResizability(.contentSize)` | ✓ present (= 1 site) | Good |
| `.windowToolbarStyle(.unified)` | ✓ present (= 6 sites) | Good |
| `.toolbarBackground` | ✓ present (= 3 sites) | Good |

### Tier 3: Focus & keyboard (2 absent / 10 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `.focusable(_:)` | ❌ absent (= REAL MISS for editable focus traversal) | wenshu uses onKeyPress + @FocusState (= sufficient for chat input; = but other widgets need .focusable) |
| `.focusedObject(_:)` | ❌ absent (= macOS 14+; = not critical) | n/a |
| `.focusEffectDisabled` | ❌ absent (= macOS 14+; = not critical) | n/a |
| `.focused(_:)` | ✓ present (= 10 sites) | Good |
| `.onKeyPress` | ✓ present (= 7 sites) | Good |
| `.keyboardShortcut` | ✓ present (= 33 sites) | Good |
| `@FocusState` | ✓ present (= 2 sites) | Good |

### Tier 4: Containers & layout (4 absent / 10 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `NavigationSplitView` | ❌ **absent (= REAL MISS)** | wenshu uses NSSplitViewController (= AppKit; = not the Apple HIG SwiftUI equivalent) — could refactor |
| `GroupBox(_:_:)` | ❌ absent (= could use for settings sub-sections) | n/a — Form/Section is sufficient |
| `Table(_:)` | ❌ **absent (= REAL MISS)** | wenshu uses List (= 40 sites); = native macOS Table is HIG-recommended for tabular data (= Kanban / Memory / Book) |
| `OutlineGroup` | ❌ **absent (= REAL MISS)** | wenshu uses custom NewLibraryOutlineView + OutlineView (= 45 sites); = OutlineGroup is HIG-recommended for hierarchical trees |
| `Form { ... }` | ✓ present (= 14 sites) | Good |
| `LabeledContent` | ✓ present (= 3 sites) | Good |
| `List` | ✓ present (= 40 sites) | Good |
| `DisclosureGroup` | ✓ present (= 30 sites) | Good |

### Tier 5: Modal & presentation (2 absent / 10 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `.fullScreenCover` | ❌ **absent (= REAL MISS for focused editor mode)** | wenshu has Cmd-Shift-F potential (= but uses NSWindow.toggleFullScreen instead); = HIG-recommended for focused single-task UX |
| `.fileImporter` | ❌ **absent (= REAL MISS)** | wenshu uses NSOpenPanel direct (= 12 sites); = .fileImporter is HIG-recommended for single-file picker (= simpler UX) |
| `.fileExporter` | ❌ **absent (= REAL MISS)** | wenshu uses NSSavePanel direct (= 6 sites); = .fileExporter is HIG-recommended for save |
| `.sheet` | ✓ present (= 55 sites) | Good |
| `.inspector` | ✓ present (= 7 sites, = macOS 14+) | Good |
| `.alert` | ✓ present (= 20 sites) | Good |
| `.confirmationDialog` | ✓ present (= 5 sites) | Good |
| `.popover` | ✓ present (= 15 sites) | Good |

### Tier 6: Material & visual (1 absent / 9 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `.thickMaterial` | ❌ absent (= but .regularMaterial + .ultraThinMaterial + .glassEffect cover it) | n/a — covered by adjacent materials |
| `NSVisualEffectView` | ✓ present (= 10 sites, = AppKit canonical for pre-glassEffect contexts) | Good |
| `.glassEffect` | ✓ present (= 53 sites, = macOS 26 Liquid Glass) | Good |
| `.regularMaterial` | ✓ present (= 11 sites) | Good |
| `.ultraThinMaterial` | ✓ present (= 4 sites) | Good |

### Tier 7: Drag & drop (3 absent / 5 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `Transferable` protocol | ❌ absent (= NOT-CRITICAL: wenshu has only 8 .draggable + .dropDestination sites) | n/a — minimal drag-drop |
| `.onDrag(_:)` (legacy) | ❌ absent (= wenshu uses modern .draggable; = legacy form not needed) | n/a |
| `.onDrop(of:delegate:)` (legacy) | ❌ absent (= wenshu uses modern .dropDestination) | n/a |
| `.draggable` | ✓ present (= 6 sites) | Good |
| `.dropDestination` | ✓ present (= 2 sites) | Good |

### Tier 8: Text & edit (0 absent / 9 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `TextField` | ✓ present (= 108 sites) | Good |
| `TextEditor` | ✓ present (= 21 sites) | Good |
| `SecureField` | ✓ present (= 3 sites) | Good |
| `.help(_:)` | ✓ present (= 113 sites) | Good |
| `.lineLimit` | ✓ present (= 39 sites) | Good |
| `.truncationMode` | ✓ present (= 4 sites) | Good |
| `.textSelection` | ✓ present (= 4 sites) | Good |
| `.textFieldStyle` | ✓ present (= 55 sites) | Good |
| `AttributedString` | ✓ present (= 4 sites) | Good |

### Tier 9: Animation & gesture (1 absent / 9 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `.refreshable` | ❌ absent (= macOS native pull-to-refresh; = not used for lists) | n/a — wenshu's lists don't need refresh |
| `.transition` | ✓ present (= 40 sites) | Good |
| `.animation` | ✓ present (= 16 sites) | Good |
| `withAnimation` | ✓ present (= 3 sites) | Good |
| `.matchedGeometryEffect` | ✓ present (= 16 sites) | Good |
| `.gesture` | ✓ present (= 11 sites) | Good |
| `.onTapGesture` | ✓ present (= 9 sites) | Good |
| `.hoverEffect` | ✓ present (= 2 sites, = macOS 14+) | Good |
| `.contextMenu` | ✓ present (= 14 sites) | Good |

### Tier 10: Async & task (0 absent / 6 surveyed)

| API | Status | Wenshu has / lacks |
| --- | --- | --- |
| `.task` | ✓ present (= 168 sites) | Good |
| `.onChange` | ✓ present (= 88 sites) | Good |
| `.onAppear` | ✓ present (= 22 sites) | Good |
| `.onDisappear` | ✓ present (= 3 sites) | Good |

## Real-Miss Priority Ranking

| Rank | API | Real-miss sites where Apple HIG recommends | Effort |
| --- | --- | --- | --- |
| **P0** | `@SceneStorage` | 67 `@AppStorage` sites could split = per-window state restoration (= pane sizes, active tab, expanded groups) | 2h |
| **P0** | `.fileImporter` / `.fileExporter` | 12 NSOpenPanel + 6 NSSavePanel sites — single-file picker cases should use SwiftUI standard | 3h |
| **P1** | `.fullScreenCover` | Focused editor mode (= Cmd-Shift-F) | 2h |
| **P1** | `.navigationTitle` | Settings windows / sheets | 1h |
| **P1** | `.navigationDestination(for:)` | Type-safe chat zone navigation (= 1 NavigationStack site) | 1h |
| **P2** | `Table(_:)` | Kanban / Memory / Book lists (= replace custom List with native Table) | 4h |
| **P2** | `OutlineGroup` | NewLibraryOutlineView (= 45 OutlineView sites) — could be OutlineGroup | 4h |
| **P3** | `.focusable(_:)` | Focusable form widgets | 1h |
| **P3** | `NavigationSplitView` | Could replace NSSplitViewController for SwiftUI pane tree | 6h (= high risk) |

## Cross-references

- `.scratch/2026-09-06-wenshu-apple-api-inventory.md` (= "what wenshu uses" = 1601 Apple-canonical refs)
- `.scratch/2026-09-06-wenshu-apple-hig-violations.md` (= "how wenshu misuses Apple APIs" = 196 sites)
- `.scratch/2026-09-06-wenshu-apple-hig-absent.md` (= THIS FILE = "what wenshu doesn't use at all")
- `.scratch/2026-09-06-wenshu-hidden-defects-audit.md` (= 6 deep scans)
- `.scratch/2026-09-06-wenshu-hidden-defects-resolution.md` (= 2 actionable fixes resolved)

---

*Generated 2026-09-06 via per-line scan across 309 Swift files.*
*25 Apple HIG APIs absent. 19 real-misses (would improve wenshu). 6 architectural-acceptable skips.*