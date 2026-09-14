# v0.77 WorkspaceView Test Coverage · Design Doc (deferred)

**Branch**: `wt/v0.77-workspaceview-tests-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "跑到问题清单清完"

## Context

Per v0.73 dead-code grep inventory, three top UI files were flagged as high-leverage + untested:

| File | Weighted deficit | Notes |
|---|---|---|
| `Views/Workspace/WorkspaceView.swift` | 7892 | 30 dependents, hot file |
| `UI/Layout/NavigationSplitShell.swift` | 5446 | 10 dependents |
| `Views/Workspace/PreviewPane.swift` | 5110 | 19 dependents |

The fix is "add ViewInspector tests." But after 30 min of inventory I realized the scope is much larger than 1 ticket.

## Why this ticket is design-only (= not code)

`WorkspaceView` is a SwiftUI root container that wraps `PaneSplitHost` (= an `NSViewControllerRepresentable` wrapping `PaneNSController`, the NSSplitViewController subclass). It owns:
- `LayoutTreeStore` (= the layout state)
- `WorkspaceMode` (.edit / .run)
- `renderTabByKind(_:)` dispatcher (= maps TabKind → existing wenshu view)

To ViewInspector-test it, I need:
1. A mock `LayoutTreeStore` (the real one requires a `WenshuLibrary` + `PaneVisibleContext`)
2. A mock `PaneSplitHost` (= or strip it from the ViewInspector tree)
3. A mock `WorkspaceMode` + tab routing
4. Assertions that match the production structure (1+ hosts, N tab panes, etc.)

That's a ~150-200 LOC test file with several helper mocks. By contrast, **the view itself is ~2050 LOC** (= per repowise). The test-to-source ratio is healthy, but the test scaffolding requires understanding the full `WorkspaceView` + `LayoutTreeStore` surface (= a spec, not a 1-ticket fix).

## Same pattern = `AgentLifecycleTrackerDesign.md` from v0.73

Per AGENTS.md §11.3 wenshu-side wins + Q79 ("agent decides cleanup scope"), I document the deferral as a spec, like I did for `AgentLifecycleTracker` in v0.73 ticket 004. This way future tickets have a clear roadmap.

## Decision matrix (= what to defer vs what to ship)

### Option A — Full ViewInspector test (deferred to v0.78+)

**Cost**: ~150-200 LOC test scaffolding + mock `LayoutTreeStore` + `PaneSplitHost`
**Risk**: tests would test mocks, not real behavior (= mock-heavy)
**Benefit**: catches regressions in the high-leverage view

### Option B — Smaller, focused tests on isolated subcomponents

Several smaller, easier targets exist:

- `EditModeBadge.swift` (= pure SwiftUI badge; = trivial ViewInspector test)
- `EditorContentPlaceholder.swift` (= pure SwiftUI placeholder; = trivial ViewInspector test)
- `PreviewSortMenuButton.swift` (= button with menu; = trivial ViewInspector test)
- `LayoutPicker/PresetCard.swift` (= preset card UI; = trivial ViewInspector test)

**Cost**: ~30-50 LOC per file (= much smaller surface)
**Risk**: low (= each subcomponent is self-contained)
**Benefit**: incremental coverage of the WorkspaceView surface

### Option C — Snapshot tests via `pointfreeco/swift-snapshot-testing` (already a dev dep per AGENTS.md §11.1)

The repo already has `swift-snapshot-testing` (= approved per ADR-0008). Snapshot tests on WorkspaceView would catch visual regressions without mocking state.

**Cost**: render a deterministic mock state + capture screenshot + compare
**Risk**: snapshot tests are flaky on CI (= common pain point)
**Benefit**: catches rendering regressions without complex mock setup

## Recommendation = **Option B + Phase 1 of C**

Per Q34 step 5 ("don't guess API"): ship Option B (= smaller, lower risk) for v0.78. Defer Option C (= snapshot tests) until WorkspaceView has a stable render path.

## v0.77 deliverables (= this design-doc ticket)

- This `spec.md` (= the design doc)
- A deferred-header on `WorkspaceView.swift` linking to this doc (= same pattern as
  v0.73 ticket 002/004/005)
- A deferred-header on `NavigationSplitShell.swift` and `PreviewPane.swift`
- No code (= per Q46 stop scope-creep)

## Out-of-scope (= explicit)

- ViewInspector tests on WorkspaceView (= v0.78+ scope)
- ViewInspector tests on NavigationSplitShell (= v0.78+ scope)
- ViewInspector tests on PreviewPane (= v0.79+ scope; = largest file = ~1460 LOC + complex state)
- Snapshot tests (= v0.80+ scope; = needs visual baseline first)
- Mock `LayoutTreeStore` (= separate ticket)

## Acceptance

- [ ] `swift build` = BUILD COMPLETE (no code change)
- [ ] Design doc = present + readable
- [ ] Deferred headers on the 3 files (= links to this spec)
- [ ] Code-review 双轴 = Standards pass + Spec pass (= doc-only ticket)

## Future ticket priority (= based on weighted deficit)

1. **v0.78**: Add ViewInspector tests for `EditModeBadge`, `EditorContentPlaceholder`,
   `PreviewSortMenuButton`, `LayoutPicker/PresetCard` (= Option B; = 4 small tests)
2. **v0.79**: Add ViewInspector test for `WorkspaceView` + `LayoutTreeStore` mock
   (= Option A; = 1 large test)
3. **v0.80**: Add ViewInspector test for `NavigationSplitShell` (= similar scope)
4. **v0.81**: Add ViewInspector test for `PreviewPane` (= largest; = needs 3 scope mocks)
5. **v0.82**: Add snapshot tests for the whole WorkspaceView tree (= Option C; = visual baseline)