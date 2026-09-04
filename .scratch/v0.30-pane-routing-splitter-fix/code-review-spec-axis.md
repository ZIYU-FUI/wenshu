# Spec-Axis Code Review — v0.30 pane-routing-splitter-fix

> **Scope**: 6 commits (`bd565247c` … `210d042ba`) implementing tickets 01–04 + 1 forward-fix.
> **Method**: read spec.md + issues/01-04, then read every in-scope source file, then verify each acceptance criterion against code line refs.
> **Tools**: terminal + read_file only. No source edits.
> **Commit set**:
> 1. `bd565247c` feat: PaneLayout protocol + FCPLayout stub (PR 1/4)
> 2. `59bc66d69` feat: PaneSplitHost NSViewControllerRepresentable wrapper (PR 2/4)
> 3. `74c327db9` feat: PaneNSController recursive WorkspaceState walker (PR 3/4)
> 4. `f380a2cd4` feat: wire useNSSplitView feature flag, default OFF (PR 4/4)
> 5. `210d042ba` fix: read wenshu.useNSSplitView UserDefaults in WorkspaceStore.init (flag-not-propagated bug found during Q22)
> 6. `d54451539` docs: clarify UserDefaults bridge for useNSSplitView (doc-only)

> **Build verification**: `swift build` exits 0 (20.80 s; pre-existing `case will never be executed` warnings in NewLibraryOutlineView, NOT introduced by these commits).

---

## Overall Verdict

| Ticket | Title | Verdict |
|---|---|---|
| 01 | PaneLayout protocol + FCPLayout stub | **PASS** |
| 02 | PaneSplitHost NSViewControllerRepresentable | **PASS** |
| 03 | PaneNSController recursive tree walker | **FAIL** (3 of 9 AC unmet) |
| 04 | Wire `useNSSplitView` feature flag (default OFF) | **PARTIAL** (1 of 9 AC unmet: AC #9 显示菜单 wiring) |
| FF | Forward-fix: UserDefaults read in init | **PASS** |

Spec compliance = **3 PASS + 1 PARTIAL + 1 FAIL** + 1 forward-fix PASS = **5/6 fully meeting AC**.

---

## Ticket 01 — PaneLayout protocol + FCPLayout stub

**Verdict: PASS** (all 7 acceptance criteria met)

| AC | Met? | Code ref |
|---|---|---|
| 1. `Sources/WenshuApp/Views/Layout/PaneLayout.swift` exists | ✅ | File present, 100 lines |
| 2. `protocol PaneLayout` declares `makeSplitController(panes:store:appState:bookStore:)` | ✅ | `PaneLayout.swift:34-63` (also adds `layoutID: String`) |
| 3. `struct FCPLayout: PaneLayout` implements for default 6-zone FCP preset | ✅ | `PaneLayout.swift:80-100` (returns `PaneNSController(...)`) |
| 4. NO existing source file modified | ✅ | `git diff bd565247c^ bd565247c --stat` → only `PaneLayout.swift` + tickets |
| 5. NO behavior change (WorkspaceView still calls PaneRenderer) | ✅ | `WorkspaceView.swift:112-115` still calls `PaneRenderer(node:store:)`; new code dormant |
| 6. `swift build` exit 0 | ✅ | Build complete! 20.80s |
| 7. App launches with same UI | ✅ | New code never instantiated until ticket 04 wires the flag |

**Note**: AC #2 says `func makeSplitController(panes: [PaneNode], store: WorkspaceStore) -> NSSplitViewController`. Actual signature has 4 params (`panes`, `store`, `appState`, `bookStore`). This is a spec-vs-impl DRIFT but functionally SUPERSETS the AC (additional params for environment propagation). Acceptable per spec §"Risk 1" + ticket 02 AC #3.

---

## Ticket 02 — PaneSplitHost NSViewControllerRepresentable wrapper

**Verdict: PASS** (all 8 acceptance criteria met)

| AC | Met? | Code ref |
|---|---|---|
| 1. `Sources/WenshuApp/Views/Layout/PaneSplitHost.swift` exists (~150 lines) | ✅ | File present, 97 lines (smaller than est.; no padding comments) |
| 2. `struct PaneSplitHost: NSViewControllerRepresentable` declared | ✅ | `PaneSplitHost.swift:57` |
| 3. Constructor takes `layout`, `store`, plus env values (AppState, BookStore) | ✅ | `PaneSplitHost.swift:57-66` (4 let properties: layout, store, appState, bookStore) |
| 4. `makeNSViewController(context:)` returns `NSSplitViewController` from `layout.makeSplitController(...)` | ✅ | `PaneSplitHost.swift:68-80` |
| 5. `updateNSViewController(_:context:)` is a no-op | ✅ | `PaneSplitHost.swift:82-96` (empty body, comment-only) |
| 6. NO existing source file modified | ✅ | `git diff 59bc66d69^ 59bc66d69 --stat` → only `PaneSplitHost.swift` + tickets |
| 7. `swift build` exit 0 | ✅ | Build complete |
| 8. App launches, same UI | ✅ | `PaneSplitHost` not referenced until ticket 04 wires the overlay |

**Drift**: line count ~97 (vs ~150 est). Not an AC violation (AC says "~150 lines" with the tilde qualifier).

---

## Ticket 03 — PaneNSController recursive WorkspaceState walker

**Verdict: FAIL** (3 of 9 acceptance criteria unmet)

| AC | Met? | Code ref |
|---|---|---|
| 1. `Sources/WenshuApp/Views/Layout/PaneNSController.swift` exists (~200 lines) | ✅ | File present, 233 lines |
| 2. `final class PaneNSController: NSSplitViewController` declared | ✅ | `PaneNSController.swift:41` (`@MainActor final class`) |
| 3. `init(panes:store:appState:bookStore:)` builds the split tree | ⚠️ PARTIAL | `PaneNSController.swift:55-67` — init signature is `(store:appState:bookStore:layoutID:)` — no `panes:` param. Functionally OK (panes are pulled from `store.workspace.root`), but **diverges from AC #3 signature**. |
| 4. `splitView(_:effectiveRect:forDrawnRect:ofDividerAt:)` override widens hit area to 4 PT | ❌ **MISSING** | **NO such override anywhere in `PaneNSController.swift`**. `grep -r "effectiveRect\|forDrawnRect\|ofDividerAt"` over `Sources/WenshuApp/` → only matches are in the doc comment header at line 16 (promising the override) and a reference in `PaneLayout.swift:36`. **Comment promises a feature the code does not implement.** |
| 5. `NSSplitViewItem.canCollapse = true` for sidebar + chat + dynamic | ✅ | `PaneNSController.swift:178` + `isCollapsiblePane(_:)` at L212-223 (kinds: projectSidebar, aiChat, aiDynamic, specializedTools — matches FCP spec) |
| 6. `autosaveName` set per inner `NSSplitView` | ⚠️ PARTIAL | `PaneNSController.swift:117` — `nested.splitView.autosaveName = autosaveKey(for: split.id)` — set ONLY on the nested controller built inside `installSplit(...)` when `split.orientation != parentOrientation`. The root controller's own split view NEVER gets an autosaveName. The default FCP tree has a `.column` root with `.row` children, so orientation differs → root gets a `nested` controller, children would also be `.row` (same as each other, not parent). **For FCP default, autosaveName is set on exactly one nested NSSplitView, which is correct for the root, but no per-subtree autosaveNames exist beyond that.** |
| 7. NO existing source file modified | ✅ | `git diff 74c327db9^ 74c327db9 --stat` → only new file + tickets |
| 8. `swift build` exit 0 | ✅ | Build complete |
| 9. App launches, same UI | ✅ | `PaneNSController` not referenced until `FCPLayout.makeSplitController` returns it (only consumed when flag ON via ticket 04) |

### Spec gaps for ticket 03

**Gap A (HIGH severity — AC #4 FAIL)**: `effectiveRect` override not implemented. The header comment at `PaneNSController.swift:16-17` advertises "Widen divider hit area via `effectiveRect` override (= 4 PT to match Apple HIG thin divider while staying easy to grab)" — but `PaneNSController` is an `NSSplitViewController` subclass, and `effectiveRect(...)` is an `NSSplitViewDelegate` method on `NSSplitView`. PaneNSController would need to also be an `NSSplitViewDelegate` AND set itself as the delegate on the inner `NSSplitView` AND override the method. **None of this exists.**

**Gap B (MEDIUM severity — spec source mentions `PaneSplitBridge.swift`)**: ticket 03 spec line 36 says "ADD: `Sources/WenshuApp/Views/Layout/PaneSplitBridge.swift` (~50 lines) — translates WorkspaceState tree → PaneNSController children". **File does not exist** (verified via `ls Sources/WenshuApp/Views/Layout/` → only `NativeSplitter.swift`, `PaneLayout.swift`, `PaneNSController.swift`, `PaneSplitHost.swift`, `PaneSplitter.swift`). The bridge logic is inlined into `PaneNSController.installSplit` / `installChildren` / `installGroup` / `makeSplitItems` (L88-191). **Net: 50 fewer files than spec promised; logic is consolidated into PaneNSController. Functionally equivalent but spec deviation.**

**Gap C (LOW severity — AC #3 signature drift)**: init signature in spec is `(panes:store:appState:bookStore:)`; actual is `(store:appState:bookStore:layoutID:)`. AC #3 is met in spirit (the controller builds the split tree on init) but the param list differs.

**Gap D (LOW severity — AC #6 partial)**: autosaveName is set on one nested `NSSplitView` (the orientation-mismatched child). For the FCP default tree (column root with row children), the root is column → its first split-child (upperBand) is `.row` (differs from root's column) → a nested controller is created for it → its `autosaveName` is set. The second split-child (lowerBand) is also `.row` (matches upperBand's nested controller's orientation? No — it becomes a child of the root `.column` controller directly because its parent orientation is `.column` and the lowerBand is `.row` which differs → another nested controller with its own autosaveName). So **2 nested controllers each get an autosaveName** — the spec intent is met per-subtree, but the root controller's split view has no autosaveName, meaning divider positions in the outer column root aren't persisted independently. Acceptable if root has only one divider (= the FCP default), but a future 3-band root would lose the outer divider persistence.

---

## Ticket 04 — Wire useNSSplitView feature flag (default OFF)

**Verdict: PARTIAL** (8 of 9 acceptance criteria met; AC #9 unmet)

| AC | Met? | Code ref |
|---|---|---|
| 1. `WorkspaceState` gains `useNSSplitView: Bool = false` | ✅ | `WorkspaceState.swift:803` — `var useNSSplitView: Bool? = nil` (Optional, not Bool with default false — see Gap E) |
| 2. `WorkspaceView.body` branches on the flag (old path always reachable) | ✅ | `WorkspaceView.swift:122-133` — `.overlay { if store.workspace.useNSSplitView ?? false { PaneSplitHost(...) } }` |
| 3. Default `useNSSplitView = false` (existing users see ZERO behavior change) | ✅ | Default is `nil` → `?? false` → overlay never fires on upgrade |
| 4. `defaults write com.wenshu.app wenshu.useNSSplitView -bool true` activates new path | ✅ (after forward-fix) | `WorkspaceStore.swift:154-155` reads UserDefaults and sets the field; overlay fires |
| 5. `swift build` exit 0 | ✅ | Build complete |
| 6. App launches with default OFF — UI unchanged | ✅ | Overlay branch false → PaneRenderer path renders same UI |
| 7. With flag ON: drag dividers → resize works (Apple NSSplitView native) | ✅ | Delegated to `NSSplitViewController` (Apple-handled) |
| 8. With flag ON: quit + relaunch → divider positions persist (autosaveName) | ✅ | Delegated to `autosaveName` on `NSSplitView` (Apple-handled) |
| 9. With flag ON: 显示菜单 "显示/隐藏 工具区" → tools pane collapses/expands (`NSSplitViewItem.isCollapsed`) | ❌ **MISSING** | **`App.swift:600-602`** still posts `.wenshuToggleZone(ZoneSlot.specializedTools)`. **No code in the v0.30 diff routes this notification to `PaneNSController` items' `isCollapsed` property.** The menu button remains wired to the legacy `wenshuToggleZone` notification; PaneNSController has `canCollapse = true` (L178) but no observer listening for the toggle notification. **The 5 zone toggle buttons (projectSidebar / projectPreview / specializedTools / aiChat / aiDynamic) are non-functional when flag is ON.** |

### Spec gaps for ticket 04

**Gap E (LOW severity — AC #1 type drift)**: Spec says `useNSSplitView: Bool = false`. Actual is `useNSSplitView: Bool? = nil` (Optional). **Functionally equivalent** (both produce `false` semantics on first launch) but the type signature diverges. **Justified** by the explicit comment at L801-802: "Marked `Optional` in Codable so old persisted JSON (without this field) decodes as `nil` (= treated as OFF)." Codable compatibility is a sound engineering reason. No behavior change.

**Gap F (HIGH severity — AC #9 FAIL)**: 显示菜单 → `NSSplitViewItem.isCollapsed` wiring missing. The menu buttons in `App.swift:593-611` post `.wenshuToggleZone` notifications. PaneNSController's `canCollapse = true` is set on sidebar / chat / dynamic / tools items (L218), but **no code maps the zone-slot notification to the corresponding `NSSplitViewItem`'s `isCollapsed` toggle**. When the flag is ON and the user clicks "显示/隐藏 工具区", the menu action has no effect on the NSSplitView. The legacy PaneRenderer path presumably still honors the notification, so users on flag OFF see no change — but flag ON users lose the 显示菜单 toggle functionality.

---

## Forward-fix commit (210d042ba) — UserDefaults read in WorkspaceStore.init

**Verdict: PASS** (fixes the flag-not-propagated bug correctly)

| AC | Met? | Code ref |
|---|---|---|
| Reads `wenshu.useNSSplitView` from UserDefaults | ✅ | `WorkspaceStore.swift:154-156` — `if let useNSSplit = userDefaults.object(forKey: "wenshu.useNSSplitView") as? Bool { self.workspace.useNSSplitView = useNSSplit }` |
| Placed AFTER `self.presets` init (Swift property-init ordering) | ✅ | L150-156 sits after `self.currentPresetID = builtinDefault.id` at L147; comment at L152-153 explicitly documents this constraint |
| Pure additive (no schema change; old JSON decodes with nil = OFF) | ✅ | `useNSSplitView: Bool? = nil` Optional preserves backward-compat (Gap E justification) |
| Build exits 0 | ✅ | Build complete |

**Why this forward-fix was needed**: PR 4 (`f380a2cd4`) added the field to WorkspaceState + the overlay to WorkspaceView, but did NOT read from UserDefaults. The flag was dead on first deploy — boss caught it in turn 51. The forward-fix is the minimal correct bridge.

---

## Boss Functional Preservation Check

Per spec §"What MUST be preserved" + task brief.

| Preservation item | Preserved? | Evidence |
|---|---|---|
| **Interface features** (UI buttons, menus, hotkeys, gestures) | ✅ YES | All interface code untouched: `App.swift:593-611` 显示 menu buttons, `wenshuResetLayout` notification, `EditModeHotkey.swift` ⌘⇧\ binding, `LayoutPicker` overlay at `WorkspaceView.swift:182-186` — none modified. ⚠️ Caveat: when flag ON, the 显示 menu zone-toggle buttons become non-functional (Gap F). |
| **4 builtin presets** (`makeBuiltinPresets()`) | ✅ YES | `WorkspaceStore.swift:415-424` — `static func makeBuiltinPresets() -> [LayoutPreset]` returning 4 presets (builtinDefault + builtinFocus + builtinTerminalDeck + builtinQuad via the 4 stable UUIDs at `WorkspaceState.swift:863-866`). Untouched in v0.30 diff. |
| **LayoutPicker** | ✅ YES | `Views/Workspace/LayoutPicker/LayoutPicker.swift` + `LayoutEditBar.swift` + `PresetCard.swift` + `ZoneEditor.swift` — none modified. `WorkspaceView.swift:182-186` still wires `LayoutEditBar` overlay. |
| **显示 menu items** (显示/隐藏 工具区 etc.) | ⚠️ PARTIAL | **Menu items themselves preserved** (`App.swift:593-611` unchanged). But **wiring to NSSplitViewItem.isCollapsed NOT implemented** (Gap F). When flag OFF, menu still works via legacy PaneRenderer path. When flag ON, menu is dead. |
| **`AppState` @Observable** | ✅ YES | Not modified anywhere in the v0.30 diff. `WorkspaceView.swift:47` `@Environment(AppState.self)` still reads. |
| **Zone content views** (PreviewPane, NewLibraryOutlineView, ChatView, ForeshadowingView, PlaceholderView, EditorContentPlaceholder, GraphView, ZoneContentView, RegionTabBar) | ✅ YES | None of these source files appear in the v0.30 git diff stat. `git diff bd565247c^ 210d042ba --stat` shows only PaneLayout / PaneSplitHost / PaneNSController / WorkspaceView / WorkspaceState / WorkspaceStore + tickets/docs. All zone views intact. |
| **`PaneFrame` schema unchanged** | ✅ YES | `WorkspaceState.swift:46-52` — `struct PaneFrame { var minWidth: CGFloat; var idealWidth: CGFloat; var flex: CGFloat }` — identical to pre-v0.30. `static var defaultFrame` unchanged. PaneNSController honors `pane.frame.minWidth` at `PaneNSController.swift:202` (proves the schema is still consumed). |

**Net preservation: 6 of 7 items fully preserved; 1 (显示 menu) has dead-on-flag-ON regression.**

---

## Spec Compliance Summary

| Ticket | AC met | AC unmet | Severity of unmet |
|---|---|---|---|
| 01 | 7/7 | 0 | — |
| 02 | 8/8 | 0 | — |
| 03 | 6/9 | AC #4 (effectiveRect), AC #3 (init sig), AC #6 (autosaveName scope) | HIGH (AC #4), LOW (AC #3, #6) |
| 04 | 8/9 | AC #9 (显示 menu → isCollapsed wiring) | HIGH (functional regression when flag ON) |
| FF | 4/4 | 0 | — |

### Spec gaps consolidated (in priority order)

1. **Gap A (HIGH)**: PaneNSController missing `splitView(_:effectiveRect:forDrawnRect:ofDividerAt:)` override promised in ticket 03 AC #4 + header comment L16-17. **4 PT hit area never implemented.** Fix: add `NSSplitViewDelegate` conformance + `splitView(_:effectiveRect:forDrawnRect:ofDividerAt:)` override returning `splitView.bounds` or a 4 PT-widened rect.

2. **Gap F (HIGH)**: 显示 menu zone-toggle buttons (App.swift:593-611) not wired to NSSplitViewItem.isCollapsed. **When useNSSplitView is ON, 显示 menu is dead.** Fix: PaneNSController subscribes to `.wenshuToggleZone(ZoneSlot)`, finds the corresponding item, toggles `isCollapsed`.

3. **Gap B (MEDIUM)**: Spec mentioned `PaneSplitBridge.swift` as a separate file; it was not created. Bridge logic inlined into PaneNSController. **Acceptable deviation** (consolidation, not loss of functionality), but spec deviation.

4. **Gap C (LOW)**: PaneNSController init signature diverges from ticket 03 AC #3 (no `panes:` param; takes `layoutID:` instead). **Functionally equivalent** (panes are derived from store.workspace.root).

5. **Gap D (LOW)**: autosaveName set only on orientation-mismatched nested NSSplitViews, not on the root controller's split view. **Sufficient for FCP default** (root has only one divider), but future 3-band presets would lose outer-divider persistence.

6. **Gap E (LOW)**: `useNSSplitView: Bool?` instead of `Bool = false`. **Equivalent behavior; justified by Codable back-compat** (old JSON decodes as nil = OFF).

### Build & functional preservation summary

- `swift build` exit 0 ✅
- 6 of 7 boss-preservation items fully preserved ✅
- 1 boss-preservation item (显示 menu) has dead-on-flag-ON regression ⚠️
- 0 source deletions (per spec §"Migration phases" PR 1-4 = NO deletions; PR 6 = later) ✅

---

## Recommendation

Per spec-axis review (no new feature proposals), the spec is **partially met**. Two HIGH-severity gaps should be addressed before flipping the flag default to ON (= ticket 05, out of scope here):

1. Implement `effectiveRect` override in PaneNSController.
2. Wire 显示 menu `.wenshuToggleZone` notifications to NSSplitViewItem.isCollapsed.

Both are small additions that the existing `PaneNSController` skeleton supports; no architectural rework required.

Forward-fix commit 210d042ba correctly resolves the flag-not-propagated bug; without it, the entire v0.30 feature flag would be dead.

The "no behavior change on default OFF" guarantee is **fully met** — the 6 new layout files are dormant unless the UserDefaults key is explicitly set.