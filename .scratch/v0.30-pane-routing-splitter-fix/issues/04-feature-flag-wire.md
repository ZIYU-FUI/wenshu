# 04 - Wire PaneSplitHost with feature flag useNSSplitView, default OFF

> Parent: v0.30-pane-routing-splitter-fix/spec.md
> Deps: tickets 01 + 02 + 03
> Type: feature-toggle (opt-in, default OFF)
> Estimated diff: ~30 lines MODIFY (WorkspaceView), 0 lines REMOVE
> Step: Q34 step 4 / implement

## Question

How does wenshu switch between the existing `PaneRenderer` path (= the safe baseline) and the new `PaneSplitHost` path (= the future) without breaking either?

## Decision

Add `useNSSplitView: Bool` to `WorkspaceState` (= new field, default `false`). `WorkspaceView.body` reads the flag and dispatches:
- `useNSSplitView == false` (default) → renders existing `PaneRenderer(node: store.workspace.root, store: store)` (= unchanged behavior)
- `useNSSplitView == true` (opt-in) → renders `PaneSplitHost(layout: FCPLayout(), store: store, appState: ..., bookStore: ...)`

The flag is settable via `defaults write com.wenshu.app wenshu.useNSSplitView -bool true` (= easy rollback by flipping back to `false`).

## Acceptance criteria

1. `WorkspaceState` gains one new optional field: `useNSSplitView: Bool = false`
2. `WorkspaceView.body` branches on the flag (= old path always reachable)
3. Default `useNSSplitView = false` (= existing users see ZERO behavior change on app upgrade)
4. When `defaults write com.wenshu.app wenshu.useNSSplitView -bool true`, the new path activates (= all 6 panes render via NSSplitView)
5. `swift build` exit 0
6. App launches with default OFF — UI unchanged from before
7. With flag ON: drag dividers → resize works (= Apple NSSplitView native)
8. With flag ON: quit + relaunch → divider positions persist (= Apple autosaveName)
9. With flag ON: 显示菜单 "显示/隐藏 工具区" → tools pane collapses/expands (= NSSplitViewItem.isCollapsed)

## File changes

- MODIFY: `Sources/WenshuApp/State/WorkspaceStore.swift` (+5 lines for the field + UserDefaults read/write)
- MODIFY: `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` (+25 lines for the if/else branch)

## Rollback

If new path crashes or has regressions: `defaults delete com.wenshu.app wenshu.useNSSplitView` → app reverts to old path on next launch (= zero rebuild needed).

## Out of scope

- Flipping default to true (= ticket 05)
- Deletion of old PaneRenderer (= PR 6)

## Verification (= Q22)

- [ ] `swift build` exit 0
- [ ] Launch with default OFF — screenshot matches pre-PR state
- [ ] Set flag ON, relaunch — screenshot shows 6 panes (fixes the "only 2 panes" bug)
- [ ] Drag a divider — pane width changes
- [ ] Quit, relaunch — divider position preserved
- [ ] Toggle 显示菜单 "显示/隐藏 工具区" — tools pane collapses
- [ ] Toggle flag OFF, relaunch — old path works (= rollback verified)
