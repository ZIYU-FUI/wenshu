# Plan A++ — replace hand-rolled PaneRenderer/Splitter with NSSplitView (Apple native)

> Captured 2026-08-31 22:30 CST (= 老板 2026-08-31 OOB "用 Apple 官方的 api 实现 FCP 的布局, 之后每一种布局等于定制化开发, 以后再说, 想像 hermes 一样自由布局定制化, 框架不同, 应该无法实现").
> Scope = v0.30 default FCP 6-zone preset ONLY. Other presets deferred per 老板 directive.

## What 老板 actually said (= the core insight)

1. FCP gives the user REAL freedom = hide/show + drag-to-resize. Wenshu must match this.
2. Hermes is Electron = JS-can-do-anything. Wenshu is macOS native = Apple API ceiling.
3. "想自由布局 = Apple API 不可能" → use Apple native NSSplitView, get the maximum freedom the platform offers (= divider drag, sidebar collapse, autosave positions).
4. Each preset = custom dev. No reusable framework beyond Apple's.

## Apple NSSplitView (the API we're porting to)

`NSSplitView` is the macOS-native splitter (= what FCP, Xcode, System Settings, Pages all use). Key features (= all auto-provided by AppKit, no custom code needed):

- `autosaveName: String` = Apple persists divider positions to `UserDefaults` automatically. Zero custom UserDefaults code.
- `dividerStyle: .thin` = 1 PT divider (= wenshu's current hard-coded `hitAreaThickness = 1`)
- `effectiveRect` override = widen hit area (= wenshu's spike attempt 8 PT)
- Each child pane = `NSSplitViewItem` with `canCollapse: Bool` + `isCollapsed: Bool` (= user hide/show via system gesture or programmatic)
- Drag-to-resize = native, AppKit handles gesture + animation
- Toolbar toggle (= show/hide sidebar) = `NSSplitViewItem.isCollapsed = true`
- Customize via `NSSplitViewController` (= modern, lifecycle-managed)

### Reference (verified via web search 2026-08-31)

- `developer.apple.com/documentation/appkit/nssplitview` (= API reference)
- `developer.apple.com/documentation/appkit/nssplitviewcontroller` (= modern container)
- Apple HIG: Sidebars — `developer.apple.com/design/human-interface-guidelines/sidebars`

## Current wenshu pain (= what we're replacing)

| File | Lines | What it does (wrong) |
|---|---|---|
| `Sources/WenshuApp/Views/Workspace/PaneRenderer.swift` | 649 | Hand-rolled split tree walker. Has bugs: (a) only renders 2 of 6 panes in current build, (b) `.frame(width:)` hard-pin prevents splitter from re-flowing, (c) `minChildSize = 200` blocks narrow panes |
| `Sources/WenshuApp/Views/Layout/NativeSplitter.swift` | 285 | Hand-rolled drag gesture. Hit area = 1 PT, drags don't visually resize. Persistence race between drag cache + store. |
| `Sources/WenshuApp/Views/Workspace/PaneSplitRenderer.swift` | 284 | Older alternative path (= probably dead per the legacy dual-route) |
| **Total** | **1218 lines** | **= 1 bug class** |

Plus `WorkspaceStore.swift` `adjustSplitWeights` (drag persistence math) + `dragCache` @State = ~150 more lines.

## Target: A++ = NSSplitView via NSViewControllerRepresentable

Replace the entire 1218-line hand-rolled splitter with:

1. **`PaneSplitHost`** = `NSViewControllerRepresentable` wrapping a `NSSplitViewController`
2. **Pane content** = each pane's SwiftUI view wrapped in `NSHostingController` (= keep all the SwiftUI pane code intact)
3. **Pane model** = `WorkspaceState.root` already has the tree shape (`SplitNode` + `GroupNode`); just translate to `NSSplitView` children at render time
4. **Persistence** = `autosaveName: "wenshu.split.upper"` + `"wenshu.split.lower"` (= Apple handles)
5. **Layout edit mode** = `NSSplitViewItem.canCollapse` + sidebar toggle via menu = `NSSplitViewItem.isCollapsed = !isCollapsed`

### What gets DELETED (= ~1200 lines)

- `PaneRenderer.swift` (649 lines)
- `PaneSplitRenderer.swift` (284 lines)
- `NativeSplitter.swift` (285 lines)
- `WorkspaceStore.adjustSplitWeights` + `dragCache` logic (~150 lines)
- `PaneFrame.minWidth/idealWidth/flex` (= Apple NSSplitView has its own min/max)

### What gets ADDED (= ~300 lines)

- `Sources/WenshuApp/Views/Layout/PaneSplitHost.swift` (~150 lines) = the NSViewControllerRepresentable wrapper
- `Sources/WenshuApp/Views/Layout/PaneNSController.swift` (~150 lines) = NSSplitViewController subclass that walks `WorkspaceState.root`

### Net: -900 lines + bug class eliminated

## User-facing features (= Apple automatically provides)

| Feature | How Apple provides it |
|---|---|
| Drag divider to resize | `NSSplitView` native drag gesture |
| Hide/show sidebar | `NSSplitViewItem.isCollapsed = true/false` (toggle from menu / toolbar button) |
| Persist divider positions | `autosaveName` (= Apple writes to UserDefaults automatically) |
| Thin divider line (= 1 PT) | `dividerStyle = .thin` |
| Wider hit area (= 4-8 PT) | Override `effectiveRect` in subclass |
| Restore positions on relaunch | `autosaveName` reads back automatically |
| Liquid Glass material | `NSSplitView` automatically uses vibrancy when child is non-opaque |
| Animation on collapse | `animator()` modifier on isCollapsed |

These are EXACTLY the FCP / Xcode / System Settings features boss wants.

## What about per-preset customization?

Boss: "每一种布局等于定制化开发" = each future preset (Xcode / Hermes / Quad) = its own `NSSplitViewController` subclass OR its own layout builder function. Reuse via composition (= each preset = a function that builds the NSSplitView tree from the pane list).

```swift
protocol PaneLayout {
    func makeSplitController(panes: [PaneNode]) -> NSSplitViewController
}

struct FCPLayout: PaneLayout {
    func makeSplitController(panes: [PaneNode]) -> NSSplitViewController { ... }
}

struct XcodeLayout: PaneLayout {
    func makeSplitController(panes: [PaneNode]) -> NSSplitViewController { ... }
}
```

Each preset = one struct, one file, ~50 lines. **Custom dev per preset is OK because presets differ structurally (= 2-pane vs 4-pane vs grid).**

## v0.30 scope (= this commit only)

**Goal = wenshu's FCP-style 6-zone preset works as Apple intended:**
1. All 6 panes render (= fixes the "only 2 panes" bug)
2. Drag divider to resize (= Apple handles)
3. Sidebar can collapse/expand via toolbar button (= matches FCP's hide/show)
4. Divider positions persist across launches (= Apple autosaveName handles)
5. Toolbar ↔ pane show/hide via the existing "显示" menu items (`显示/隐藏 工具区`, etc.)

**NOT in this commit (= deferred)**:
- Rename builtin presets to "FCP 均衡 / Xcode 编辑器优先 / Hermes 对话优先"
- Quad 4-pane preset
- User custom layout
- 4th preset (Quad)

## Implementation plan

Per Q34 8-step (= after this spec):

1. Step 3: spec (= this file, current)
2. Step 4: 4 tickets
   - ticket 1: delete hand-rolled PaneRenderer/PaneSplitRenderer/NativeSplitter + dragCache (no functionality regression because A++ replaces)
   - ticket 2: implement `PaneSplitHost` (NSViewControllerRepresentable wrapper)
   - ticket 3: implement `PaneNSController` (NSSplitViewController subclass)
   - ticket 4: wire `WorkspaceState.root` translation to NSSplitView children + autosaveNames
3. Step 5: implement (each ticket = 1 commit)
4. Step 6: dual-axis code review (Standards + Spec)
5. Step 7: CONTEXT.md update (= add "NSSplitView" domain term)
6. Step 8: Q22 真验证 (= boss manually drags splitter + screenshots)

## Pre-flight checklist (= before implementation)

- [ ] Read NSSplitViewController docs (verify macOS 27 Tahoe behavior)
- [ ] Confirm SwiftUI pane views render correctly inside NSHostingController
- [ ] Decide autosaveName strategy (= 1 name for whole tree, or per-pane)
- [ ] Confirm Liquid Glass is honored (= NSSplitView with non-opaque children)
- [ ] Test sidebar collapse animation matches FCP

## Risks (= things to watch)

- **Risk 1**: SwiftUI in NSHostingController loses environment values. Need to pass via `NSHostingController(rootView: paneView.environment(...))`.
- **Risk 2**: NSSplitView autosave + dynamic pane add/remove can desync. May need to reset autosaveName when preset switches.
- **Risk 3**: WorkspaceStore still owns weights for drag delta math (= may need to delete the entire drag delta tracking and let Apple own it).
- **Risk 4**: `PaneFrame` (= minWidth/idealWidth) doesn't map 1:1 to NSSplitViewItem min/max. May need translation layer.

## What this plan does NOT solve (= out of scope per boss)

- Hermes-style free pane placement (= drop pane anywhere, like a window manager). Boss confirmed: "想像 hermes 一样自由布局定制化, 框架不同, 应该无法实现". Punted.
- Per-pane position serialization (= only Apple autosaveName, not custom format).
- Custom divider style (= Liquid Glass line = Apple default).


## Dead-code deletion policy (= boss 2026-08-31 OOB revised)

> 老板 2026-08-31 OOB (revised): "死代码不许删, 这不是我的决策, 如果通过我刚才解释的, 确认了, 以后用不到的代码, 可以删. 我不懂写代码, 我无法给你意见, 所以你要自己决策"

### The rule (= ANAN autonomous decision authority)

**Dead code MAY be deleted** (= no boss confirmation needed), **provided ANAN has reasoned that the code is genuinely unrecoverable in the future framework direction**.

The decision is ANAN's, not the boss's (= boss explicitly says "我不懂写代码"). The boss's role is to define the direction; ANAN's role is to execute.

### What counts as "dead code in future framework" (= ANAN's checklist)

When ANAN encounters code during the NSSplitView migration (= or any future migration), ask:

1. **Was the code written for the OLD hand-rolled PaneRenderer path?** (= e.g. `splitContainer` recursion, `rowChild` / `columnChild` weight math, `dragCache` delta tracking)
   - YES → dead in NSSplitView world → DELETE
   - NO (= generic util) → preserve

2. **Does NSSplitView provide the same feature out of the box?** (= e.g. divider drag, autosave, canCollapse)
   - YES → the wrapper code around it is dead → DELETE
   - NO (= unique feature) → preserve

3. **Is the code a backwards-compat shim for the OLD pane registry / dual-route?** (= e.g. `renderTabByKindFallback`, `RegisteredPanes.renderTabByRegistry` if no caller)
   - YES → no longer needed once NSSplitView is the single path → DELETE after migration completes

4. **Is it a `@available(*, deprecated)` complaint fix from 6+ months ago that the codebase no longer triggers?** (= check git blame for context)
   - YES → delete

5. **Is it referenced only in tests / fixtures / sample code that no longer compiles?**
   - YES → delete

### What MUST be preserved (= the boss's hard requirements)

These are NOT dead code; they are intentional:

1. **All 4 builtin presets** (`WorkspaceStore.makeBuiltinPresets()`) — boss uses these; renaming is out of scope this PR
2. **`LayoutPicker` + `LayoutEditBar`** — preset picker UI; boss uses this to switch presets
3. **显示菜单 items** (显示/隐藏 工具区 etc.) — boss uses these; NSSplitView integration just routes them to `isCollapsed` instead of `NotificationCenter`
4. **`AppState` @Observable** — cross-zone state
5. **All Zone content views** (PreviewPane, NewLibraryOutlineView, etc.) — SwiftUI views stay intact, only the container changes
6. **`PaneFrame.minWidth / idealWidth / flex` schema** — schema stability for user-saved custom presets (even if currently unused)
7. **`wenshuResetLayout` notification + resetLayout action** — boss uses via 显示 menu

### What MAY be deleted (= ANAN judgment)

Based on the future-framework direction (= Apple NSSplitView + feature-flagged migration), these become deletable once NSSplitView is the single path:

| Item | Why dead | When delete |
|---|---|---|
| `PaneSplitRenderer.swift` (284 lines) | Old hand-rolled split tree walker. NSSplitView does this natively. | After PR 5 (= NSSplitView is default ON for 2 stable builds) |
| `NativeSplitter.swift` (285 lines) | Hand-rolled drag gesture. NSSplitView drag is native. | Same as above |
| `PaneRenderer.swift` (649 lines) | Old hand-rolled split tree renderer. | Same as above |
| `WorkspaceStore.adjustSplitWeights` + `dragCache` @State | Drag persistence math. NSSplitView autosaveName handles persistence. | Same as above |
| `RegisteredPanes.renderTabByRegistry` (registered but never called) | Dead per AX trace earlier today. | NOW (= safe; was already dead) |
| `WorkspaceView.renderTabByKindFallback` in RegisteredPanes.swift | Fallback for the dead `renderTabByRegistry`. | Same as above (= already unreachable) |
| Local variable `aiChatW` / `dynamicW` if confirmed unused in spec-axis advisory | Dead per code review. | NOW (= already flagged in spec-axis) |

### What MUST be re-evaluated (= don't blindly delete)

These look deletable but have non-obvious callers — must grep before deleting:

- `PaneFrame` struct (= multiple presets reference `flex` field)
- `LayoutParser` (= if exists; some presets might be loaded from JSON)
- `splitContainer`'s `liveWeights` derivation (= may feed weight display UI)
- Any code path with `@available(*, deprecated, message: ...)` annotation (= usually preserved for backward compat)

### Migration phases (= revised per dead-code deletion authority)

**PR 1** (= this PR): Add `PaneLayout` protocol + `FCPLayout` struct. NO behavior change. NO deletion.
**PR 2**: Add `PaneSplitHost` NSViewControllerRepresentable. NO behavior change. NO deletion.
**PR 3**: Add `PaneNSController` + bridge. NO behavior change. NO deletion.
**PR 4**: Wire `PaneSplitHost` with feature flag `useNSSplitView = false` (= old path still active by default). NO deletion.
**PR 5**: Flip flag to `useNSSplitView = true` (= NSSplitView active). Manually verify drag + persistence work. NO deletion YET.
**PR 6** (= 2 stable builds later, ~1 week): ANAN runs the dead-code checklist above, deletes items marked "When delete = After PR 5". ONE commit with a list of deletions in the commit body.

### Hard rules during dead-code deletion (= PR 6)

1. **Grep first, delete second**: every deletion must show `git grep` evidence of zero callers before the commit
2. **One commit per category**: don't mix deletions with feature changes
3. **Commit body lists each deletion** (= so boss can revert if any was wrong)
4. **Tests still build** (SwiftPM `swift build` exit 0 + unit tests pass)

### When to ask boss (= exceptions to the autonomous rule)

Even with this autonomy, ask boss if:

- Code removal would change USER-VISIBLE behavior (= e.g. menu item disappears)
- Code removal requires new package dependency (= boss decides on libs per AGENTS.md §11.1)
- Code removal touches `AGENTS.md`, `CONTEXT.md`, `README.md`, or `CLAUDE.md` (= doc stability)
- ANAN is uncertain whether the code is dead (= no clear grep evidence)

### 
### Source-tree state after this PR (= visible in `git status`)

```
modified:   Sources/WenshuApp/Views/Workspace/WorkspaceView.swift (only — wires PaneSplitHost with feature flag)
added:      Sources/WenshuApp/Views/Layout/PaneLayout.swift
added:      Sources/WenshuApp/Views/Layout/PaneSplitHost.swift
added:      Sources/WenshuApp/Views/Layout/PaneNSController.swift
added:      Sources/WenshuApp/Views/Layout/PaneSplitBridge.swift
added:      .scratch/v0.30-pane-routing-splitter-fix/spec.md
added:      .scratch/v0.30-pane-routing-splitter-fix/three-reference-layouts.md
added:      .scratch/v0.30-pane-routing-splitter-fix/issues/01-*.md
... (more issues/)
```

NOT modified (= 0 changes):
- `PaneRenderer.swift`
- `PaneSplitRenderer.swift`
- `NativeSplitter.swift`
- `WorkspaceStore.swift` (drag math preserved)
- `PaneFrame.swift` (schema preserved)
- All Zone content views
