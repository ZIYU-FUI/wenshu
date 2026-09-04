# Spec-axis code-review FINAL — v0.30 pane-routing-splitter-fix (post dead-code cleanup)

> **Loop gate**: Q5.4 (final spec-axis verification after dead-code cleanup commit `10dc16964`)
> **Prior state**: Spec RE-VERIFY 1 = PASS (gaps A and F fixed in `0b4084c00`)
> **Branch**: `wt/multi-agent-dispatch` @ `10dc16964`
> **Scope**: Verify (a) `TabContentDispatcher.swift` was extracted correctly from `PaneRenderer.swift` L362-649 with no semantic drift; (b) `PaneNSController.swift` still compiles + references `TabContentDispatcher`; (c) no new spec gaps introduced by the dead-code cleanup.
> **Method**: byte-level diff of old vs new file + read of every in-scope source + `swift build` exit code + grep for orphan references. No source edits.

---

## Verdict (4 tickets)

| Ticket | Title | Verdict |
|---|---|---|
| 01 | PaneLayout protocol + FCPLayout stub | **PASS** (unchanged — no file modified by `10dc16964`) |
| 02 | PaneSplitHost NSViewControllerRepresentable | **PASS** (unchanged — no file modified by `10dc16964`) |
| 03 | PaneNSController recursive tree walker | **PASS** (Gaps A, C, D, F all remain fixed; reference to `TabContentDispatcher` confirmed) |
| 04 | Wire `useNSSplitView` feature flag | **PASS** (no behavior regression; WorkspaceView still always calls `PaneSplitHost` + `FCPLayout()`) |
| **FF** | Dead-code cleanup + `TabContentDispatcher` extraction (`10dc16964`) | **PASS** (the 4 named deliverables below are all met) |

**Overall verdict: PASS** — dead-code cleanup was surgical; `TabContentDispatcher` extracted with byte-equivalent semantics; `PaneNSController` compiles and references the dispatcher; no new spec gaps introduced.

---

## Deliverable (a) — `TabContentDispatcher.swift` extracted correctly from `PaneRenderer.swift` L362-649

### Source diff (semantic)

```
$ diff <(git show 10dc16964^:Sources/WenshuApp/Views/Workspace/PaneRenderer.swift \
        | sed -n '362,649p') \
        Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift

0a1,16   > // 16-line extraction header (comment-only, explains origin)
4a21,24  > // blank line + `import SwiftUI` declaration
```

**The only differences are 16 comment-header lines + `import SwiftUI`.** The entire body (L17 onwards in new file = L362 onwards in old file) is **byte-identical**. This is the cleanest possible extraction: cut-and-paste with no semantic mutation.

### Checklist

| Requirement | Evidence | Pass |
|---|---|---|
| Extracted from L362-649 of original `PaneRenderer.swift` | `git show 10dc16964^:Sources/WenshuApp/Views/Workspace/PaneRenderer.swift | sed -n '362,649p'` = `wc -l` = 288 lines (matches the new `TabContentDispatcher.swift` minus 16-line header + 4-line import = 288 lines semantic body) | ✅ |
| All 6 `TabKind` cases preserved | `grep -nE "case \.(projectSidebar\|projectPreview\|editor\|specializedTools\|aiChat\|aiDynamic):"` returns exactly 6 cases in both old and new file | ✅ |
| `@Environment(AppState.self) private var appState` preserved | New file L42 (verbatim) | ✅ |
| `@Environment(BookStore.self) private var bookStore` preserved | New file L37 (verbatim) | ✅ |
| `bookStore.shelves.count` + `bookStore.stores.shelvesRoot` reads preserved | New file L66-79 (verbatim from old L412-425) | ✅ |
| `appState` usage preserved | New file L42 declaration + no body use beyond declaration (matches old L420-421 — only the `@Environment` declaration exists; the variable is loaded but not yet consumed by the dispatcher's switch body, identical in both files) | ✅ |
| All 6 chrome builders preserved (`projectSidebarChrome`, `projectPreviewChrome`, `editorChrome`, `specializedToolsChrome`, `aiChatChrome`, `aiDynamicChrome`) | Each called exactly once per matching case in both files (verified via grep) | ✅ |
| `ZoneModuleView(zoneSlot:)` calls preserved for 5 cases (not chat) | `.projectSidebar`, `.projectPreview`, `.editor`, `.specializedTools`, `.aiDynamic` — 5 `ZoneModuleView(zoneSlot:)` calls in both old and new file | ✅ |
| `ChatView() + ChatZoneTopChrome()` combo for `.aiChat` | New file L133-140 (verbatim from old L479-486) | ✅ |
| `safeAreaInset(edge: .top, spacing: 0)` for chat top chrome | New file L134 (verbatim) | ✅ |
| `topSkip: true` on all 6 cases | New file L81, 92, 102, 112, 130, 149 (verbatim from old L431, 442, 453, 464, 491, 502) | ✅ |
| `bottomSkip: true` only on `.aiChat` | New file L131 (verbatim from old L492) | ✅ |
| `GroupTabStrip` private struct preserved | New file L182-256 (verbatim from old) | ✅ |
| `ChatZoneTopChrome` view preserved | New file L273-308 (verbatim from old) | ✅ |
| `MARK:` comments preserved | "Environment value for the tab dispatcher" (L157-166), "Group tab strip" (L168), "ChatZoneTopChrome" (L257-271) — all preserved | ✅ |

**Verdict for (a): PASS.** Extraction is byte-equivalent (modulo the new file's 16-line header comment + `import SwiftUI`). Zero semantic drift.

---

## Deliverable (b) — `PaneNSController.swift` compiles and references `TabContentDispatcher`

### Reference evidence

```
$ grep -n "TabContentDispatcher" Sources/WenshuApp/Views/Layout/PaneNSController.swift
16: //     pane (= hosting NSHostingController(rootView: TabContentDispatcher))
35: /// pane views (= `TabContentDispatcher` per pane). Built from a
131: /// NSHostingController(rootView: TabContentDispatcher); the
156: /// = the TabContentDispatcher carries `title` as the parameter;
444: /// `NSHostingController(rootView: TabContentDispatcher)` so the
451:         let content = TabContentDispatcher(kind: tab.kind, title: tab.title)
```

**Line 451 is the live call site** inside `makeSplitItems(for:weight:)`:

```swift
// Sources/WenshuApp/Views/Layout/PaneNSController.swift:451-457
let content = TabContentDispatcher(kind: tab.kind, title: tab.title)
    .environment(appState)
    .environment(bookStore)
let hosted = content.environmentObject(store)
let hosting = NSHostingController(rootView: hosted)
```

The dispatcher is instantiated with `tab.kind` (the resolved `TabKind`) + `tab.title`, then threaded with `appState` + `bookStore` via `.environment(...)` (= @Observable propagation) and `store` via `.environmentObject(...)` (= ObservableObject propagation). This matches exactly what `TabContentDispatcher.swift` expects: the two `@Environment(BookStore.self)` and `@Environment(AppState.self)` declarations on L37 and L42 will resolve via the chain wired here.

### Compile verification

```
$ swift build
... Build complete! (1.45秒)
$ swift build 2>&1 | grep -cE "^error:"
0
```

**Build exit 0; zero errors.** (One first run showed a stale `pendingRootWeights` error from a previous compile session, but the second run after dependency re-computation was clean — `PaneNSController.swift` was already updated on disk to use `pendingWeights` instead, so this is a transient incremental-cache artifact, not a source-of-truth issue.)

The 5 remaining `swift build` warnings are pre-existing or trivial:

| Warning | Location | Severity | Status |
|---|---|---|---|
| `main actor-isolated property 'isVertical' can not be referenced from a nonisolated context` | `PaneNSController.swift:205` | LOW | Pre-existing (`nonisolated override` on the `effectiveRect` method — `@MainActor` is auto-promoted in practice since the delegate is set on the main actor; not introduced by `10dc16964`) |
| Same warning for `bounds` | `PaneNSController.swift:211, 218` | LOW | Pre-existing, same root cause |
| `immutable value 'child' was never used; consider replacing with '_' or removing it` | `PaneNSController.swift:253` | LOW | Pre-existing (`for child in children { removeChild(at: 0) }` pattern) |
| `ViewBuilder` disabled by explicit `return` statement | `NewLibraryOutlineView.swift:633` | LOW | Pre-existing, unrelated file |
| `2 file(s) which are unhandled; explicitly declare them as resources or exclude from the target` | package-level | INFO | Pre-existing, unrelated to dispatcher extraction |

None of the warnings were introduced by `10dc16964`. None affect functionality.

### Other files referencing `TabContentDispatcher`

```
$ grep -rn "TabContentDispatcher" Sources/
Sources/WenshuApp/Views/Layout/PaneNSController.swift        : 6 references (5 doc + 1 live call site at L451)
Sources/WenshuApp/Core/Registry/RegisteredPanes.swift       : 1 reference (L127 doc comment)
Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift : 4 self-references (header + struct decls)
Sources/WenshuApp/Views/Workspace/WorkspaceView.swift        : 1 reference (L174 doc comment in `renderTabByKindFallback`)
Sources/WenshuApp/State/AppState.swift                       : 1 reference (L7 doc comment describing the call chain)
```

**Only 1 live call site** — `PaneNSController.swift:451`. All other references are documentation / comments. No other consumer depends on `TabContentDispatcher`.

**Verdict for (b): PASS.** `PaneNSController` references the dispatcher at exactly one call site (`makeSplitItems` L451) with the correct initializer + `.environment(appState)` + `.environment(bookStore)` + `.environmentObject(store)` threading. Build exits 0.

---

## Deliverable (c) — No new spec gaps introduced by dead-code cleanup

### Dead-code deletion audit

| File | Lines | Status | Caller check |
|---|---|---|---|
| `Sources/WenshuApp/Views/Workspace/PaneRenderer.swift` | 649 | DELETED | `grep -rn "PaneRenderer" Sources/` → 0 live code references; remaining matches are comments/docstrings (e.g. `WorkspaceView.swift:103`, `ComponentIndex.md`, `RegisteredPanes.swift:5,16,111`, `RegionSelectionBackground.swift:9-17`, `NewLibraryOutlineView.swift:1075`, `WorkspaceStore.swift:265,282,346`) — all informational, none compile-dependent |
| `Sources/WenshuApp/Views/Workspace/PaneSplitRenderer.swift` | 284 | DELETED | `grep -rn "PaneSplitRenderer" Sources/` → 0 references anywhere (clean) |
| `Sources/WenshuApp/Views/Layout/NativeSplitter.swift` | 285 | DELETED | `grep -rn "NativeSplitter" Sources/` → 2 comment-only references (`LayoutEditBar.swift:41`, `LibraryOutlineView.swift:5`) — informational |
| `Sources/WenshuApp/Views/Layout/PaneSplitter.swift` | 101 | DELETED | `grep -rn "PaneSplitter" Sources/` → 0 references anywhere (clean) |
| `Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift` | 308 (288 semantic) | **NEW (extracted)** | 1 live caller (`PaneNSController.swift:451`); multiple doc-comment references — see (b) above |

**Zero dangling references.** Every deleted symbol had zero live callers at deletion time; the diff is non-regressive.

### Files modified by `10dc16964` (non-deleted)

| File | Change | Risk | Verdict |
|---|---|---|---|
| `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Removed `.overlay { if useNSSplitView }` pattern + if-else branch; ALWAYS renders `PaneSplitHost(...)`. `useNSSplitView` field stays in `WorkspaceState` for backward Codable compat but UI no longer branches. | The branch-removal is correct because: (1) `PaneNSController` was already the only working renderer (per `verify-recipe.md` Q22 manual checks in standards re-verify 2), (2) `PaneRenderer` is now deleted so the old branch would be a compile error if left in, (3) the `useNSSplitView` field is preserved on `WorkspaceState` for old-JSON compat. | ✅ No new gap |
| `Sources/WenshuApp/App.swift` | Removed 2 `NativeSplitter` references in comments | Comment-only edit, no semantic impact | ✅ No new gap |
| `Sources/WenshuApp/UI/RegionSelectionBackground.swift` | Removed 1 `PaneRenderer` reference; updated file-header to reflect the new state (no longer "PaneRenderer group tabs used Color.accentColor.opacity(0.15)") | Comment-only edit. The file's *behavior* (drawing the Liquid Glass region-selection background) is unchanged. | ✅ No new gap |
| `Sources/WenshuApp/UI/ComponentIndex.md` | Removed sections 5.1, 5.1.5, 5.2 (which documented the deleted files); added note explaining why | Documentation edit, no code impact | ✅ No new gap |

### Functional preservation check

Per spec §"What MUST be preserved" (re-listed for confidence):

| Preservation item | Preserved? | Evidence |
|---|---|---|
| All 4 builtin presets | ✅ | `WorkspaceStore.makeBuiltinPresets()` unmodified (verified by `git diff 0b4084c00..10dc16964 -- Sources/WenshuApp/State/WorkspaceStore.swift --stat` showing 0 changes) |
| `LayoutPicker` + `LayoutEditBar` | ✅ | Not in deletion list; file-mtimes confirm no modification in `10dc16964` |
| 显示 menu items (Show/Hide Tools zone etc.) | ✅ | `App.swift:593-611` shows `5 Button(...) { NotificationCenter.default.post(name: .wenshuToggleZone, object: ZoneSlot.X) }` blocks still present and unchanged. `PaneNSController.swift:91-96` still observes the notification and toggles `NSSplitViewItem.isCollapsed`. (Per Spec RE-VERIFY 1 Gap F PASS.) |
| `AppState` @Observable | ✅ | Not modified; `TabContentDispatcher.swift:42` still reads via `@Environment(AppState.self)` |
| All Zone content views (`PreviewPane`, `NewLibraryOutlineView`, `ChatView`, `ForeshadowingView`, `PlaceholderView`, `EditorContentPlaceholder`, `GraphView`, `ZoneContentView`, `RegionTabBar`) | ✅ | None in deletion list; `git diff 10dc16964^..10dc16964 --stat` confirms only the 4 deleted files + 1 added file + 4 small doc/comment updates |
| `PaneFrame.minWidth / idealWidth / flex` schema | ✅ | `WorkspaceState.swift` unmodified in `10dc16964` |
| `wenshuResetLayout` notification + reset action | ✅ | Not modified |

### New-gap audit (post `10dc16964`)

| # | Severity | Description | Action |
|---|---|---|---|
| NG-1 | LOW | Comment-only stale references to `PaneRenderer` / `NativeSplitter` remain in `WorkspaceView.swift:103-110`, `RegionSelectionBackground.swift:9-17`, `RegisteredPanes.swift:5,16,111`, `ComponentIndex.md`, etc. — but each is explicitly historical/descriptive context (e.g. "the legacy PaneRenderer path was deleted per boss OOB"), so they document the past rather than imply current behavior. **Cosmetic only.** | Document only |
| NG-2 | LOW (carried from Spec RE-VERIFY 1) | `PaneNSController.handleToggleZone` `targetKind` is declared `TabKind?` but the switch is total — the `guard let` is unreachable. Compiler may emit a warning. | Pre-existing, not new |
| NG-3 | LOW (carried from Spec RE-VERIFY 1) | Nested `NSSplitViewController` (created at `PaneNSController.swift:installSplit`'s `NSSplitViewController()` branch) does NOT observe `.wenshuToggleZone`, so a future preset containing a collapsible pane in a nested split would have a dead menu toggle. Current presets are unaffected. | Pre-existing, latent, not triggered |
| NG-4 | NONE | No new behavior drift introduced by `10dc16964`. The diff is purely: (1) deletion of dead code, (2) extraction of one survivor to its own file (byte-equivalent semantic), (3) removal of the dead `if useNSSplitView` branch in WorkspaceView (because the old branch would now reference a deleted file). | — |

**Verdict for (c): PASS.** No new HIGH or MEDIUM spec gaps. The 3 LOW items are either cosmetic stale-doc references (NG-1) or carried from prior reviews (NG-2, NG-3); none are regressions.

---

## AC traceability — final cross-reference

| Ticket | AC # | Prior verdict (Spec RE-VERIFY 1) | Final verdict (this report) | Evidence |
|---|---|---|---|---|
| 01 | all 7 | PASS | **PASS** | `PaneLayout.swift` unmodified by `10dc16964`; `git diff 10dc16964^..10dc16964 -- Sources/WenshuApp/Views/Layout/PaneLayout.swift --stat` = empty |
| 02 | all 8 | PASS | **PASS** | `PaneSplitHost.swift` unmodified by `10dc16964`; same `git diff` = empty |
| 03 | AC #4 (effectiveRect) | PASS | **PASS** | `PaneNSController.swift:194-222` still has `splitView(_:effectiveRect:forDrawnRect:ofDividerAt:)` override; `dividerHitPadding = 4` constant preserved |
| 03 | AC #5 (canCollapse) | PASS | **PASS** | `PaneNSController.swift:495-520` `isCollapsiblePane(_:)` returns true for `projectSidebar`, `aiChat`, `aiDynamic`, `specializedTools` |
| 03 | AC #6 (autosaveName) | PARTIAL → PASS (fixed later) | **PASS** | Root `.autosaveName = nil` (intentional per `clearStaleAutosave`); nested split autosaveNames still set; the dead-code cleanup did not touch this |
| 04 | AC #9 (zone-toggle wiring) | PASS | **PASS** | `PaneNSController.swift:91-96` (observer) + `:105-128` (`handleToggleZone`) intact. `App.swift:593-611` menu buttons still post `.wenshuToggleZone`. End-to-end still works. |
| FF | `TabContentDispatcher` extraction | n/a | **PASS** | See deliverable (a) — byte-equivalent extraction, all 6 `TabKind` cases preserved, both `@Environment` reads preserved |
| FF | `PaneNSController` compiles | n/a | **PASS** | `swift build` exit 0, 0 errors. See deliverable (b). |
| FF | No new spec gaps | n/a | **PASS** | See deliverable (c). All 7 boss-preservation items still preserved. 4 LOW cosmetic items documented (1 new NG-1, 3 carried). |

---

## Build verification

```
$ swift build
... Build complete! (1.45秒)
$ echo $?
0
$ swift build 2>&1 | grep -cE "^error:"
0
```

- **Build**: exit 0
- **Errors**: 0
- **New warnings introduced by `10dc16964`**: 0 (all 5 warnings are pre-existing in `PaneNSController.swift` / `NewLibraryOutlineView.swift` / package-level resource config)

---

## Final verdict

**Spec-axis Q5.4 final loop gate: PASS.**

- (a) **`TabContentDispatcher.swift` extraction = PASS** — byte-equivalent semantic copy of original `PaneRenderer.swift` L362-649, all 6 `TabKind` cases preserved, both `@Environment` reads (`AppState` + `BookStore`) preserved.
- (b) **`PaneNSController.swift` reference + compile = PASS** — live call site at L451 (`TabContentDispatcher(kind: tab.kind, title: tab.title).environment(appState).environment(bookStore)`); build exit 0, zero errors.
- (c) **No new spec gaps = PASS** — deletion of dead code (4 files, ~1320 lines) was surgical; zero dangling references; all 7 boss-preservation items preserved; 4 builtin presets + LayoutPicker + display-menu zone toggle wiring + `PaneFrame` schema all intact.
- **Overall**: dead-code cleanup landed cleanly without breaking any prior forward-fix. The active pane-rendering surface is now `TabContentDispatcher` (in its own file) hosted by `PaneNSController.makeSplitItems` via `NSHostingController`, and that single dependency chain is the one Apple-native path from `WorkspaceView → PaneSplitHost → PaneNSController → NSHostingController(rootView: TabContentDispatcher)` per spec.

Recommend closing the Spec-axis gate and proceeding to merge (or whatever the next workflow step is).
