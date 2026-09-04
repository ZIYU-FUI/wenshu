# 02 - Add PaneSplitHost NSViewControllerRepresentable wrapper

> Parent: v0.30-pane-routing-splitter-fix/spec.md
> Deps: ticket 01 (= needs PaneLayout protocol)
> Type: feature-additive (no behavior change)
> Estimated diff: ~150 lines ADD, 0 lines REMOVE
> Step: Q34 step 4 / implement

## Question

How does SwiftUI embed an AppKit `NSSplitViewController` (= the future container) without breaking the SwiftUI environment chain (= @Environment(AppState.self), @Environment(BookStore.self), etc.)?

## Decision

Use `NSViewControllerRepresentable` (= SwiftUI's official AppKit bridge). Pass SwiftUI environment values down via `NSHostingController(rootView: paneView.environment(...))`.

## Acceptance criteria

1. New file `Sources/WenshuApp/Views/Layout/PaneSplitHost.swift` exists (~150 lines)
2. `struct PaneSplitHost: NSViewControllerRepresentable` declared
3. Constructor takes `layout: PaneLayout`, `store: WorkspaceStore`, plus the SwiftUI environment values needed (= AppState, BookStore)
4. `makeNSViewController(context:)` returns `NSSplitViewController` from `layout.makeSplitController(...)`
5. `updateNSViewController(_:context:)` is a no-op (= content is static for now)
6. NO existing source file modified
7. `swift build` exit 0
8. App launches, same UI

## File changes

- ADD: `Sources/WenshuApp/Views/Layout/PaneSplitHost.swift` (~150 lines)

## Implementation notes

- `PaneSplitHost` is NOT yet referenced from WorkspaceView (= dormant code, like ticket 01)
- The wrapper demonstrates the AppKit bridge works (= proves the pattern before PR 4 wires it)
- Environment values passed explicitly (= no `@Environment` magic; we pass what we know the panes need)

## Out of scope

- NSSplitViewController subclass (ticket 03)
- Feature flag wiring (ticket 04)

## Verification (= Q22)

- [ ] `swift build` exit 0
- [ ] Launch wenshu, screenshot — UI unchanged
- [ ] `git diff --stat` shows only ADD, no MODIFY
