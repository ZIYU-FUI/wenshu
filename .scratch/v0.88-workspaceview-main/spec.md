# v0.88 WorkspaceView main tests · Spec

**Branch**: `wt/v0.88-workspaceview-main-2026-09-14`
**Generated**: 2026-09-14
**Methodology**: PO v1.1 main-flow 5 steps (Q34) + boss voice trigger Q146 + boss 2026-09-14 OOB "按优先级推" + "A"

## Context

WorkspaceView.swift (= the customizable-layout root SwiftUI view) =
2,139 LOC with health score 4.15 (= lowest in the repo per repowise
health deficit). Per boss OOB "按优先级推" + "A": cover the main file.

Per v0.77 spec decision (= see .scratch/v0.77-workspaceview-tests/spec.md):
ViewInspector behavior tests on this view require ~150-200 LOC of mock
scaffolding (= LayoutTreeStore + PaneSplitHost + WorkspaceMode); =
exceeds 1-ticket scope per Q112.

v0.88 = 3 source-level structural test files (= header+state /
previewScope computed / renderTab dispatcher).

## Scope (= 3 tickets, 1 file 1 commit each per Q112)

| # | Ticket | File(s) | Tests | Status |
|---|---|---|---|---|
| 1 | `001-workspaceview-header-state` | New `Tests/WenshuAppTests/Views/Workspace/WorkspaceViewTests.swift` | 6 tests | ✅ done |
| 2 | `002-preview-scope-mapping` | New `Tests/WenshuAppTests/Views/Workspace/WorkspaceViewPreviewScopeTests.swift` | 8 tests | ✅ done |
| 3 | `003-render-tab-dispatcher` | New `Tests/WenshuAppTests/Views/Workspace/WorkspaceViewRenderTabTests.swift` | 8 tests | ✅ done |

Total v0.88 = **22 tests across 3 suites**, **all passing isolated**.

Out of scope (= explicit):

- ViewInspector behavior tests for WorkspaceView (= per v0.77 spec;
  = deferred until mock-scaffolding budget is allocated)
- Tests for the 3 helper structs inside WorkspaceView.swift
  (= ZoneModuleView, EditorPlaceholder, EditorPaperCanvas) — they are
  exercised by the existing PreviewPane / NewLibraryOutlineView
  ViewInspector tests in v0.82-83 + their own test files in
  LayoutPicker/. Defer.

## Per-ticket acceptance criteria

### Ticket 001 — WorkspaceView header + state

- 6/6 tests pass isolated
- Verifies: source imports, struct conformance to View, @ObservedObject
  store, @State fields (= selectedEntityCategory / selectedEntity /
  previewSortOrder), @Environment reads (= AppState / BookStore),
  editMode hoist from appState, DEFERRED header documents v0.77
  spec decision per Q57 (= "NOT dead code")

### Ticket 002 — previewScope computed mapping

- 8/8 tests pass isolated
- Verifies: computed-property declaration, all 4 SidebarSelection
  cases (.book / .folder / .shelf / .referenceCategory), __root__
  special-case, EntityCategory lookup pattern, defensive .empty
  fallback, nil selection → .empty
- Per boss 2026-08-31 OOB spec: .shelf → .shelfScope(shelfId:),
  NOT .empty (= previous FAIL flagged by spec sub-agent)

### Ticket 003 — renderTabByKind dispatcher

- 8/8 tests pass isolated
- Verifies: 4-case switch on TabKind (= .projectSidebar /
  .projectPreview / .editor / .specializedTools), each ZoneContentView
  call with canonical zoneSlug, PreviewPane wired with previewScope,
  renderTab wrapper forwards to renderTabByKind, uniform ZoneContentView
  chrome across all 4 zones (= v0.34 30 PT alignment invariant),
  4 struct declarations (= WorkspaceView / ZoneModuleView /
  EditorPlaceholder / EditorPaperCanvas)

## Cross-references

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (= this branch's
  target)
- `.scratch/v0.77-workspaceview-tests/spec.md` (= the original deferral
  decision; = this branch's ticket 001 explicitly verifies the deferral
  header per Q57)
- `Sources/WenshuApp/State/LayoutTreeState.swift:55-58` (= TabKind enum)
- `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift:62-76`
  (= SidebarSelection enum, internal)

## Validation (= per Q34 step 4)

1. `swift build` = BUILD COMPLETE (= 67s)
2. `swift test --filter "WorkspaceView"` (= all 3 suites combined)
   = 22/22 pass isolated
3. Cross-suite isolation verified (= each suite passes when run alone)

## Out-of-scope (= explicit)

- The other 3 helper structs (= ZoneModuleView, EditorPlaceholder,
  EditorPaperCanvas) — verified to exist in ticket 003 (= 4 struct
  declarations test) but not deep-tested in this branch
- ViewInspector behavior tests (= per v0.77 spec deferral)