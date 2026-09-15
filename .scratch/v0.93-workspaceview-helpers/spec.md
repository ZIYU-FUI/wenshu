# v0.93 WorkspaceView helper struct tests · Spec

**Branch**: `wt/v0.93-workspaceview-helpers-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

WorkspaceView.swift (= 2,139 LOC = health score 4.15 = lowest in the
repo) hosts 3 separate SwiftUI structs (= WorkspaceView + ZoneModuleView
+ EditorPlaceholder + EditorPaperCanvas). v0.88 ticket 002 verified
all 4 struct declarations in `WorkspaceViewTests.declaresFourStructs`
but did not deep-test the 3 helpers.

Per boss OOB "A": ship the helper struct tests.

## Scope (= 3 tickets, 1 file 1 commit each per Q112)

| # | Ticket | File(s) | Tests | Status |
|---|---|---|---|---|
| 1 | `001-editor-paper-canvas` | `Tests/WenshuAppTests/Views/Workspace/EditorPaperCanvasTests.swift` | 8 tests | ✅ done |
| 2 | `002-zone-module-view` | `Tests/WenshuAppTests/Views/Workspace/ZoneModuleViewTests.swift` | 6 tests | ✅ done |
| 3 | `003-editor-placeholder` | `Tests/WenshuAppTests/Views/Workspace/EditorPlaceholderTests.swift` | 8 tests | ✅ done |

Total v0.93 = **3 new test files**, **22 tests** added.

Out of scope (= explicit):

- ViewInspector behavior tests on the 3 helpers (= per v0.77 spec
  deferral; = requires ~150-200 LOC of mock scaffolding for each)
- WorkspaceView's body (= renderTabByKind, openCardInEditor, etc.; =
  v0.88 already tested previewScope + renderTab dispatcher)
- Tests for the `EditorMode` enum (= lives in AppState.swift;
  = covered by other suites)

## Per-ticket acceptance criteria

### Ticket 001 — EditorPaperCanvas

- 8/8 tests pass isolated
- Verifies: generic struct over Content: View, ScrollView wrapper
  with horizontal + vertical axes, paperWidth = 595 PT (= A4),
  paperMargin = 72 PT (= 1 inch), Color.white background,
  shadow, defaultScrollAnchor(.center) (= boss 2026-09-10 OOB),
  minHeight 842 (= A4 height)

### Ticket 002 — ZoneModuleView

- 6/6 tests pass isolated
- Verifies: struct conformance to View, 2 @Binding params, @Environment
  reads for AppState + BookStore, previewScope computed property
  (= mirrors WorkspaceView; = duplicated for self-containment),
  init defaults (= .constant(nil) for non-workspace callers), body
  switch on zoneSlot with all 6 ZoneSlot cases (= exhaustive)

### Ticket 003 — EditorPlaceholder

- 8/8 tests pass isolated
- Verifies: struct conformance to View, @Environment reads for
  AppState + BookStore, mode reads from active tab (= v0.34 B-24
  Safari behavior), 2 @State vars (= selectedText + isApplyingParagraphAI),
  public setSelection(_:) bridge entry point (= P2 #19), body uses
  VStack + Safari-style tab strip (= v1.0.0-m1 OOB), dirty-discard
  confirm alert with destructive + cancel roles (= v0.34 ticket 09),
  activeTabIdString fallback to 'wenshu-editor-no-tab' (= v0.39 ticket 001)

## Cross-references

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (= the
  source-of-truth file containing all 3 helper structs)
- `Sources/WenshuApp/App.swift:270` (= the `ZoneSlot` enum with
  6 cases)
- `.scratch/v0.77-workspaceview-tests/spec.md` (= the upstream deferral
  decision that v0.93 partially implements)
- `.scratch/v0.88-workspaceview-main/spec.md` (= v0.88 ticket 002
  which verified all 4 struct declarations exist)

## Validation (= per Q34 step 4)

1. `swift test --filter "EditorPaperCanvas"` = 8/8 pass isolated
2. `swift test --filter "ZoneModuleView"` = 6/6 pass isolated
3. `swift test --filter "EditorPlaceholder"` = 8/8 pass isolated
4. `swift build` = BUILD COMPLETE (= 7s)
5. All 3 suites combined run independently (no shared state)