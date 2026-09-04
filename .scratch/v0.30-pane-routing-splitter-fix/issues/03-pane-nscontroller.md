# 03 - Add PaneNSController (NSSplitViewController subclass + WorkspaceState translation)

> Parent: v0.30-pane-routing-splitter-fix/spec.md
> Deps: tickets 01 + 02
> Type: feature-additive (no behavior change)
> Estimated diff: ~200 lines ADD, 0 lines REMOVE
> Step: Q34 step 4 / implement

## Question

How does `FCPLayout.makeSplitController` actually build the `NSSplitViewController` (= children, dividers, autosaveName, canCollapse) from a `[PaneNode]`?

## Decision

`PaneNSController` is an `NSSplitViewController` subclass that:
1. Walks `WorkspaceState.root` (= SplitNode tree) recursively
2. For each `SplitNode`, creates an `NSSplitView` child with `isVertical = (orientation == .row)` + divider style `.thin` + `autosaveName = "wenshu.split.<uuid>"`
3. For each `GroupNode`, creates an `NSSplitViewItem` per pane, hosting `NSHostingController(rootView: ZoneContentView(...).environment(AppState).environment(BookStore))`
4. Each `NSSplitViewItem.canCollapse = true` (= sidebar etc. can hide)

## Acceptance criteria

1. New file `Sources/WenshuApp/Views/Layout/PaneNSController.swift` exists (~200 lines)
2. `final class PaneNSController: NSSplitViewController` declared
3. `init(panes: [PaneNode], store: WorkspaceStore, appState: AppState, bookStore: BookStore)` builds the split tree
4. `func splitView(_:effectiveRect:forDrawnRect:ofDividerAt:)` overrides the hit area to 4 PT (= Apple HIG thin divider but easier to grab)
5. `NSSplitViewItem.canCollapse` true for sidebar + chat + dynamic (= hideable side panels)
6. `autosaveName` set per inner `NSSplitView` (= Apple auto-persists divider positions)
7. NO existing source file modified
8. `swift build` exit 0
9. App launches, same UI

## File changes

- ADD: `Sources/WenshuApp/Views/Layout/PaneNSController.swift` (~200 lines)
- ADD: `Sources/WenshuApp/Views/Layout/PaneSplitBridge.swift` (~50 lines) — translates WorkspaceState tree → PaneNSController children

## Implementation notes

- This is the **riskiest** ticket (= AppKit + SwiftUI interop + environment propagation)
- If environment propagation breaks, panes render blank but build green (= need Q22 visual check)
- If autosaveName clashes between presets (= switching preset would corrupt saved positions), use preset-prefixed autosaveName

## Out of scope

- Feature flag wiring (ticket 04)
- Deletion of old PaneRenderer (= PR 6, only after 2 stable builds)

## Verification (= Q22)

- [ ] `swift build` exit 0
- [ ] Launch wenshu, screenshot — UI unchanged
- [ ] `git diff --stat` shows only ADD, no MODIFY
- [ ] All 6 panes render correctly when PaneSplitHost is manually wired (= smoke test before PR 4)
