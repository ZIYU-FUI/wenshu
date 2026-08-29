# v0.28 followup — Hermes pane-shell architecture verbatim port

**Author**: pocock agent · 2026-08-29 · Boss OOB '深度看 hermes, 不要抄表面, 盘机制, 完整机制, 看整体框架设计'

## Goal

Refactor Wenshu's v0.28 free-layout system (= WorkspaceView + WorkspaceStore + builtinDefault + 3 other builtin presets) to match Hermes Desktop pane-shell's full architecture verbatim. Boss OOB observed my prior work (= decorator pattern) was "抄表面, 没盘机制" — the right approach is to port Hermes's actual mechanism.

## Sources (= hermes pane-shell)

Read 2026-08-29 from `/Volumes/ANAN/.hermes/hermes-agent/apps/desktop/`:

| File | LOC | Purpose |
|---|---|---|
| `AGENTS.md` | 270 | Hermes Desktop engineering guide (= principles) |
| `DESIGN.md` | 300 | Hermes Desktop design system (= visual + interaction) |
| `src/components/pane-shell/index.ts` | 1 | Cross-surface pane-toggle reveal event |
| `src/components/pane-shell/geometry.ts` | 350 | AABB intersection + native window controls rect + publishWorkspaceGeometry CSS vars |
| `src/components/pane-shell/pane-lifecycle.ts` | 200 | 3-state pane lifecycle: visible / hot-hidden / parked (DEFAULT_HOT_HIDDEN_PANE_CAP=2, keepAlive opt) |
| `src/components/pane-shell/pane-visibility.ts` | 100 | PANE_HIDDEN_ATTR, hiddenPaneProps, PaneVisibleContext/Lifecycle/Group contexts |
| `src/components/pane-shell/workspace-scope.ts` | 150 | $workspaceMode (sessions/bots), $workspaceOwnerKey, setWorkspaceScope |
| `src/components/pane-shell/edit-mode.tsx` | 100 | Cmd+Shift+\\ layout edit mode hotkey |
| `src/components/pane-shell/tree/model.ts` | 600 | LayoutNode (SplitNode + GroupNode), normalize(), pure operations |
| `src/components/pane-shell/tree/presets.ts` | 200 | Layout presets via contribution registry (LAYOUTS_AREA) |
| `src/components/pane-shell/tree/store.ts` | 1800 | $layoutTree atom, persistence, all tree operations, pane registry |
| `src/components/pane-shell/tree/grid-model.ts` | 400 | FancyZones grid model 1:1 port |
| `src/components/pane-shell/tree/grid-to-tree.ts` | 200 | Grid → tree conversion (= ZoneEditor submit) |
| `src/components/pane-shell/tree/zone-editor.tsx` | 200 | FancyZones ZoneEditor (canvas + zone drag) |
| `src/components/pane-shell/tree/zones-engine.ts` | 700 | FancyZones engine verbatim (= drag/highlight internals) |
| `src/components/pane-shell/tree/renderer/index.tsx` | 150 | LayoutTreeRoot = composition root |
| `src/components/pane-shell/tree/renderer/tree-split.tsx` | 400 | Split node renderer, 1px seam = sash |
| `src/components/pane-shell/tree/renderer/tree-group.tsx` | 600 | Group node renderer, zone + tabs + zone menu |
| `src/components/pane-shell/tree/renderer/tree-node.tsx` | 100 | Recursive node dispatch |
| `src/components/pane-shell/tree/renderer/track-model.ts` | 350 | Sizing model (fixed / flex / all-fixed-absorber) |
| `src/components/pane-shell/tree/renderer/layout-picker.tsx` | 200 | Preset picker UI |
| `src/components/pane-shell/tree/renderer/edit-bar.tsx` | 100 | Edit mode floating palette |
| `src/components/pane-shell/tree/renderer/drag-session.ts` | 300 | FancyZones-style drag (layout stays fixed, zones light up) |
| `src/components/pane-shell/tree/renderer/strip-visibility.ts` | 80 | AUTO tab strip (function of what zone holds) |
| `src/components/pane-shell/tree/renderer/floating-rect.ts` | 200 | Floating panes placement |
| `src/app/shell/titlebar.ts` + `titlebar-controls.tsx` | 600 | App-root titlebar + tools (= toggle buttons, badges) |
| `src/app/shell/statusbar-controls.tsx` | 400 | App-root statusbar items |
| `src/app/contrib/panes.tsx` | 180 | Real panes (FilesPane, ReviewPane, LogsPane) + bar items as DATA contributions |
| `src/app/contrib/controller.tsx` | 1500 | AppController = composition root (titlebar + statusbar + tree) |
| `src/app/contrib/surfaces.tsx` | 400 | Memoized surfaces (sidebar, statusbar, terminal) |
| `src/app/contrib/wiring.tsx` | 200 | Lazy views + overlay routes |
| `src/contrib/registry.ts` | 200 | ContributionRegistry (area-keyed, area-scoped invalidation, stable refs) |
| `src/contrib/types.ts` | 150 | Contribution interface |
| `src/store/layout.ts` | 200 | $sidebarOpen, $panesFlipped, $fileBrowserOpen, setSidebarOpen, setFileBrowserOpen |
| `src/store/panes.ts` | 400 | $paneStates (per-pane widthOverride/heightOverride, sash drag persistence) |
| `src/store/statusbar-prefs.ts` | 200 | $statusbarVisible, $statusbarHiddenIds, setStatusbarItemVisible, resetStatusbarLayout |

**Total Hermes pane-shell LOC**: ~10,400. Already ported to Wenshu in v0.28 batch 1 + followup (~3,800 LOC across WorkspaceView, WorkspaceStore, LayoutPicker, ZoneEditor, GridModel). Remaining gap = ~6,600 LOC.

## Hermes pane-shell architecture (= mechanism, NOT surface)

### 1. **Three visibility mechanisms** (= for different pane semantics)

| Mechanism | What it does | Used by |
|---|---|---|
| `$hiddenTreePanes` Set | Zone collapses to nothing; content stays mounted (= scroll preserved) | Sidebar, file browser (= ⌘B / ⌘G) |
| `markCollapsePane()` Set | Zone collapses to rail (= tab stays, body collapsed) — IntelliJ/VS-Code model | Terminal, logs |
| `$dismissedPanes` Set | Zone removed from tree; re-reveal = re-add to tree | Files pane close-X |

### 2. **Chrome ↔ tree binding pattern**

```ts
// hide-style pane (= sidebar):
bindPaneVisibility(paneId, $sidebarOpen, close, open)

// tool panel (= terminal):
bindToolPaneCollapse(paneId, $terminalOpen, close, open)
```

Both register an `open()` + `close()` pair. The tree reads from the binding (= source of truth = the togglestore), not the tree directly.

### 3. **Pane lifecycle** (= 3-state cache for inactive tabs)

| State | Meaning | Mounted? |
|---|---|---|
| `visible` | Foreground tab | Yes, full |
| `hot-hidden` | Recently visible inactive tab; capped at 2 by default | Yes, but render budget reduced |
| `parked` | Beyond cap | No (= unmounted) |

**Boss's v0.25.1 "expand editor" = `GroupNode.minimized = true` (= group collapses to header strip, tab stays).**

### 4. **App-root composition**

Hermes app root composition:
```
[Titlebar (fixed)]  ← $sidebarOpen, $panesFlipped, $fileBrowserOpen (chrome-wide)
[LayoutTree (flex)] ← tree of panes (zones)
[Statusbar (fixed)] ← $statusbarHiddenIds (per-item visibility)
[Overlays]          ← settings/command-center/cron/profiles (route overlays)
```

Tree = **only panes**. Titlebar + Statusbar = **outside tree** (= always at fixed positions).

### 5. **Contribution registry** (= 1 uniform API for every surface)

```ts
registry.register({
  area: 'panes',           // or 'statusBar.left' / 'statusBar.right' / 'titlebar.left' / 'titlebar.right' / 'layouts'
  id: 'files-pane',
  source: 'core' | 'user' | 'plugin:foo',
  title: 'Files',
  order: 100,
  render: () => <FilesPane />,
  data: {...},  // for layout presets
  when: () => sidebarOpen,  // dynamic visibility (= note: stale until next mutation)
})
```

Hosts consume via `useContributions('panes')` (= stable ref per area, only invalidates when THAT area mutates).

### 6. **Pane-aware zoom-out policy** (= Wenshu's "5 zone visibility flags" → $hiddenTreePanes Set)

Wenshu's v0.27 LayoutShellView has 5 separate `@AppStorage("wenshu.zoneVisible.X")` flags — one per zone. Each flag has 3 problems:
1. **Bound to a specific zone** (= sidebarVisible ≠ projectPreviewVisible) — adding a new zone = new flag
2. **Doesn't survive preset switch** (= if builtinDefault has sidebar, but the flag is false, sidebar hidden)
3. **No centralized enum** (= individual booleans scattered in UserDefaults)

Hermes pattern: **`$hiddenTreePanes: Set<PaneID>` (= opaque ids, semantic-agnostic)**. The titlebar/statusbar controls bind via `bindPaneVisibility(paneId, $open, close, open)`. Adding a new zone = register 1 pane + bind 1 visibility store. No new flag.

### 7. **Tab strip = `'always' | 'never'`** (NOT `headerHidden` boolean)

Hermes explicitly retired the v1 `headerHidden` boolean because:
- Wrote by both user choice AND layout repairs (= repair overwrote choice)
- Couldn't read back (= `false` meant either "user wants no strip" OR "repair pinned it visible")
- Solution = `tabStrip: TabStripMode?` (= `undefined` = AUTO, only user writes it)

Wenshu already has this right (`Sources/WenshuApp/State/WorkspaceState.swift:209`).

### 8. **Pane sash = 1px seam = junction-owned**

Hermes: `tree-split.tsx` renders 1px seam between siblings = the resize sash. **No doubled borders** = `<div class="border-l">` on the right pane + `<div class="border-r">` on the left pane would draw 2px. **One sash per junction only.**

Wenshu today: separate `Splitter` (= 1 per zone boundary, hardcoded positions). Fix: make split renderer own 1px seam + drag-resize handle in one junction element.

### 9. **`applyTree` = deep-clone** (= live edits never mutate preset)

Hermes: `applyLayoutPreset(id, tree) = applyTree(structuredClone(tree), id)`. Built-in presets are immutable templates; the user's tree is a fresh deep-clone.

Wenshu today: `applyTree()` may mutate. Fix: `applyTree(_ tree: LayoutNode) = deepCopy(tree)`.

### 10. **Native window controls aware** (= traffic lights + drag strip)

Hermes: `geometry.ts` computes the native controls rect (macOS traffic lights top-left / Windows overlay top-right). Chrome reserves drag strip = where the titlebar/zone edge meets the controls rect. Publishes `--workspace-left/right` CSS vars = chrome in plain CSS aligns to main pane geometry.

Wenshu: traffic lights = macOS native window controls (= NSWindow draws them). Wenshu's content view starts at y=0 = **overlaps traffic lights**. Fix: `Geometry.nativeControlsRect(window)` + `contentView` offsets by the rect height (= 34 PT for traffic lights band).

## Wenshu current state (= already ported in v0.28 batch 1 + followup)

✅ `WorkspaceStore` (ObservableObject, schema-versioned, persistence)
✅ `WorkspaceState` (LayoutNode = SplitNode + GroupNode)
✅ `normalize()` (canonical form)
✅ `PaneNode` / `PaneID` / `TabSpec` / `TabID` / `PaneFrame`
✅ 4 builtin presets (= builtinDefault + builtinFocus + builtinTerminalDeck + builtinQuad)
✅ `LayoutPicker` / `LayoutEditBar` / `ZoneEditor` (= FancyZones verbatim)
✅ `GridModel.swift` (= FancyZones grid model)
✅ `PaneRenderer.swift` + `WorkspaceView.swift` (= tree renderer)
✅ `applyTree()`, `markActivePreset()`
✅ `GroupNode.minimized` (= v0.25.1 expand/shrink equivalent)
✅ `GroupNode.tabStrip: TabStripMode?` (= hermes verbatim)

## Wenshu gap (= what's missing for full parity)

| Gap | LOC est | Hermes source | Wenshu target |
|---|---|---|---|
| ❌ `$hiddenTreePanes` Set | ~100 | `pane-shell/tree/store.ts` | `WorkspaceStore.hiddenTreePanes` |
| ❌ `$dismissedPanes` Set | ~80 | `pane-shell/tree/store.ts` | `WorkspaceStore.dismissedPanes` |
| ❌ `markCollapsePane()` registry | ~30 | `pane-shell/tree/store.ts` | `WorkspaceStore.collapsePanes` |
| ❌ `bindPaneVisibility()` + `bindToolPaneCollapse()` | ~150 | `pane-shell/tree/store.ts` | `WorkspaceStore.bind()` |
| ❌ `pane-lifecycle.ts` (3-state cache) | ~200 | `pane-shell/pane-lifecycle.ts` | `PaneLifecycle.swift` |
| ❌ `pane-visibility.ts` (PaneVisibleContext etc.) | ~100 | `pane-shell/pane-visibility.ts` | `PaneVisibleContext.swift` |
| ❌ `workspace-scope.ts` ($workspaceMode, ownerKey) | ~150 | `pane-shell/workspace-scope.ts` | `WorkspaceScope.swift` |
| ❌ `geometry.ts` (native controls rect) | ~150 | `pane-shell/geometry.ts` | `Geometry.swift` |
| ❌ Titlebar AppRoot component | ~400 | `app/shell/titlebar.tsx` + `titlebar-controls.tsx` | `AppTitlebar.swift` |
| ❌ Statusbar AppRoot component | ~300 | `app/shell/statusbar-controls.tsx` | `AppStatusbar.swift` |
| ❌ Contribution registry (panes + bar items) | ~250 | `contrib/registry.ts` + `contrib/types.ts` | `ContributionRegistry.swift` |
| ❌ Pane registration via contributions | ~100 | `app/contrib/panes.tsx` | `RegisteredPanes.swift` |
| ❌ `$paneStates` (per-pane width/height overrides) | ~150 | `store/panes.ts` | `WorkspaceStore.paneStates` |
| ❌ `$statusbarHiddenIds` (per-item visibility) | ~80 | `store/statusbar-prefs.ts` | `WorkspaceStore.statusbarHiddenIds` |
| ❌ 1px seam = sash (= replace separate Splitter) | ~150 | `tree-split.tsx` | `PaneSplitRenderer.swift` |
| ❌ `applyTree` deep-clone | ~30 | `tree/presets.ts` | `WorkspaceStore.applyTree()` |
| ❌ Re-register panes via registry (= replace switch in PaneRenderer) | ~80 | `tree-group.tsx` render via `ContribRender` | `PaneRenderer.dispatch` via `useContributions` |
| ❌ Tests for all above | ~400 | Various `*.test.ts` | Various `*.swift` |

**Total gap**: ~2,900 LOC. Phased plan:

### Phase 1: foundation (= 1 commit, ~600 LOC)

- `ContributionRegistry.swift` (= `area: 'panes'`, 'statusBar', 'titlebar'; `register`/`useContributions`/`getArea` with area-scoped invalidation)
- `WorkspaceScope.swift` (= `workspaceMode`, `ownerKey`, `setWorkspaceScope`)
- `PaneLifecycle.swift` (= 3-state cache, reconcilePaneLifecycle pure func)
- `PaneVisibleContext.swift` (= SwiftUI Environment values for visibility/lifecycle/group)
- `Geometry.swift` (= nativeControlsRect on macOS)

### Phase 2: visibility mechanisms (= 1 commit, ~400 LOC)

- Add to `WorkspaceStore`:
  - `hiddenTreePanes: Set<PaneID>`
  - `dismissedPanes: Set<PaneID>`
  - `collapsePanes: Set<PaneID>` (= tool panel flag)
  - `paneStates: [PaneID: PaneSizeSnapshot]`
  - `statusbarHiddenIds: Set<String>`
- Add functions: `bindPaneVisibility(paneId, isOpen, close, open)`, `bindToolPaneCollapse(paneId, isOpen, close, open)`, `isPaneVisible(paneId)`, `togglePaneVisible(paneId)`, `dismissTreePane(paneId)`, `revealTreePane(paneId)`, `removeTreePane(paneId)`

### Phase 3: titlebar + statusbar (= 1 commit, ~700 LOC)

- `AppTitlebar.swift` (= AppRoot component, fixed top 30 PT, reads `$sidebarOpen` etc.)
- `AppStatusbar.swift` (= AppRoot component, fixed bottom 24 PT, per-item visibility)
- Move 5 zone visibility flags (`@AppStorage("wenshu.zoneVisible.X")`) → `bindPaneVisibility()` calls

### Phase 4: registered panes (= 1 commit, ~250 LOC)

- `RegisteredPanes.swift` (= real panes: editor, sidebar, file browser, terminal)
- Replace `PaneRenderer` switch with `ContributionRegistry.getArea('panes')` lookup
- New pane = register 1 contribution (no edit to renderer)

### Phase 5: sash + sizing (= 1 commit, ~400 LOC)

- `PaneSplitRenderer.swift` (= 1px seam = sash, owned by split = not by child)
- Remove separate `Splitter` component
- `applyTree` deep-clone (= live edits never mutate preset)

### Phase 6: tests (= 1 commit, ~600 LOC)

- One test file per phase: `ContributionRegistryTests.swift`, `PaneLifecycleTests.swift`, `BindPaneVisibilityTests.swift`, `TitlebarStatusbarTests.swift`, `PaneSashTests.swift`
- `132/132 + 50 = 182/182` test target

### Phase 7: commit + push + verify (= 1 commit, ~0 LOC)

- Single atomic commit per phase (= 6 commits)
- `swift build` exit 0 + full test suite exit 0
- CUA verify with `WENSHU_DEBUG_INMEMORY_KEYCHAIN=1`: 6区 builtinDefault shows with titlebar (30 PT) + statusbar (24 PT) + 6 zone body
- Pushed to `wt/multi-agent-dispatch`

## Acceptance criteria

**Phase 1 + 2 (foundation + visibility) done**:
- [ ] `ContributionRegistry.register/remove/getArea` passes tests
- [ ] `PaneLifecycle.reconcilePaneLifecycle` cap=2 keeps 2 most-recent inactive panes
- [ ] `WorkspaceStore.hiddenTreePanes/dismissedPanes/collapsePanes` round-trip via Codable
- [ ] `bindPaneVisibility(paneId, $open, close, open)` writes $hiddenTreePanes when $open flips

**Phase 3 (titlebar + statusbar) done**:
- [ ] `AppTitlebar` renders at top of `AppRoot`, 30 PT, with 8 buttons
- [ ] `AppStatusbar` renders at bottom of `AppRoot`, 24 PT, with current model label
- [ ] Titlebar ⌘B / ⌘G toggle visibility of projectSidebar / file browser via `bindPaneVisibility`

**Phase 4 (registered panes) done**:
- [ ] `PaneRenderer.dispatch(kind)` looks up via `ContributionRegistry.getArea('panes')` (NOT switch)
- [ ] New pane = `registry.register({ ... })` = appears in tree

**Phase 5 (sash + sizing) done**:
- [ ] `PaneSplitRenderer` renders 1px seam = sash = 0 doubled borders
- [ ] `applyTree` deep-clones (live edits never mutate preset)

**Phase 6 (tests) done**:
- [ ] `swift test` 182/182 (= 132 baseline + 50 new) exit 0

**Phase 7 (push + verify) done**:
- [ ] 6 commits pushed to `wt/multi-agent-dispatch`
- [ ] CUA screenshot of Wenshu main UI shows titlebar + statusbar + 6区 body

## Out of scope (= deferred)

- Floating panes (= non-tiling)
- Narrow viewport overlays (= phone-sized window)
- Plugin pane registration (= plugin API)
- Per-session tile (= sidebar session drag-into-tree)
- Composer pop-out (= standalone window)
- Resize min/enforce (= minimum pane size enforcement)

## Risk

- **Phase 4 PaneRenderer refactor** = biggest risk (= current `switch` is hot-path). Mitigation = keep dispatch via ContributionRegistry BUT fallback to switch when no contribution registered (= backward compat).
- **Phase 5 sash refactor** = visual regression risk (= bug in sash = cannot resize zones). Mitigation = run `DragRegressionTests` after each commit (= already in pre-commit hook).
- **Phase 3 statusbar** = 24 PT height may not match user's window. Mitigation = `LayoutTokens.statusBarHeight: CGFloat = 24` (= central constant).

## Decision needed

Boss picks **A** (single big followup), **B** (split into phases 1-3 only), **C** (just phase 1+2 foundation), or **D** (skip, leave v0.28 free-layout as-is).

**My recommendation**: **A** (= all phases) — Herms pane-shell is the canonical desktop app layout architecture; missing pieces will keep causing "boss wants X but builtin templates don't auto-include" complaints. Estimated 7 commits + 2,900 LOC + 50 new tests + CUA verify.

## Rollback plan

- All work in branch `wt/multi-agent-dispatch` (= feature branch, not main)
- Each phase is 1 atomic commit (= rollback = revert that commit)
- Current v0.28 free-layout commits (= 12 commits) stay intact (= additive layering)
- No delete or rewrite of v0.28 work (= additive only)

## Cross-references

- v0.28 free-layout chain (= `8acaff0ee` → `857e492cd` + followup `daec822e9`)
- Batch 3 hermes-port chain (= 9 tickets, `aa37b4d04` → `01e0b35ff`)
- Keychain backend unification (= `7d559ba1a`)
- v0.28 followup AC#8/9/10/11 (= `d9511a949`)

## Why this is NOT a "decorator pattern"

My earlier attempt (= `LayoutDecorator.swift` + `ToolbarContentView.swift` + `StatusBarContentView.swift`) was wrong:
1. ❌ It tried to wrap tree with toolbar/statusbar at render time (= heavy runtime overhead)
2. ❌ It used a `protocol` with composition (= over-engineered for what is essentially a fixed-position AppRoot component)
3. ❌ It duplicated the 5 zone visibility flags as `@AppStorage` (= doesn't survive preset switch)
4. ❌ It invented new `TabKind` cases (`.toolbar`, `.statusBar`) (= wrong layer — these are AppRoot, not tree)

Hermes approach is cleaner:
1. ✅ Titlebar + Statusbar = AppRoot components (= fixed position, outside tree)
2. ✅ Zone visibility = `$hiddenTreePanes` Set (= opaque, semantic-agnostic)
3. ✅ Panes registered via contribution (= 1 uniform API for every surface)
4. ✅ Tab strip = `tabStrip: 'always' | 'never'` (already done in Wenshu)
5. ✅ Visibility binding via `bindPaneVisibility()` (= the chrome ↔ tree protocol)

The pattern Hermes uses is **separation of concerns**:
- **Tree** owns pane layout (= which panes go where, weights, splits)
- **Chrome** (titlebar/statusbar) owns surface-level toggles (= which panes are visible, per-item hide)
- **Contributions** own what can be added (= panes, bar items, presets)
- **Bindings** connect chrome ↔ tree without direct coupling

Each layer can evolve independently. Adding a new feature = "1 contribution + 1 binding", not "edit every preset".