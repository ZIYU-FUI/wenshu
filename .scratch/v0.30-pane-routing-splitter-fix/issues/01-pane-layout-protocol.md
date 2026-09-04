# 01 - Add PaneLayout protocol + FCPLayout struct (pure additive)

> Parent: v0.30-pane-routing-splitter-fix/spec.md
> Type: feature-additive (no behavior change)
> Estimated diff: ~50 lines ADD, 0 lines REMOVE
> Step: Q34 step 4 / implement

## Question (= what this ticket resolves)

How does the future framework (= Apple NSSplitView) translate `WorkspaceState` (= the existing pane tree data) into a concrete `NSSplitViewController` configuration?

## Decision (= answer ANAN will record on resolution)

The future framework = `PaneLayout` protocol + one struct per preset (= starting with `FCPLayout`). Each preset knows how to construct its `NSSplitViewController` from the pane list.

## Acceptance criteria

1. New file `Sources/WenshuApp/Views/Layout/PaneLayout.swift` exists
2. `protocol PaneLayout` declares: `func makeSplitController(panes: [PaneNode], store: WorkspaceStore) -> NSSplitViewController`
3. `struct FCPLayout: PaneLayout` implements the protocol for the default 6-zone FCP preset (= upper row: sidebar + preview + editor + tools / lower row: chat + dynamic)
4. NO existing source file modified (= pure additive)
5. NO behavior change (= `WorkspaceView` still calls `PaneRenderer(...)`; new code is dormant until PR 4)
6. `swift build` exit 0
7. Existing wenshu app launches with same UI as before this PR

## File changes

- ADD: `Sources/WenshuApp/Views/Layout/PaneLayout.swift` (~50 lines)

## Implementation notes

- `NSSplitViewController` subclass is declared but NOT wired (= added in PR 3)
- `FCPLayout.makeSplitController` returns a stub `NSSplitViewController()` (= real implementation in PR 3)
- `PaneNode` is the existing model (= no schema change)
- `WorkspaceStore` is read-only access (= no writes from this struct)

## Out of scope (= other tickets)

- NSViewControllerRepresentable wrapper (PR 2)
- NSSplitViewController subclass with pane content (PR 3)
- Feature flag wiring (PR 4)

## Verification (= Q22 proof)

- [ ] `swift build` exit 0
- [ ] Launch wenshu, screenshot — UI unchanged from before PR
- [ ] git diff shows ONLY additions, no modifications to existing files
