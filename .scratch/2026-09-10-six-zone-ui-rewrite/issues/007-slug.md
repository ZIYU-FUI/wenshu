# Ticket 007 — land @SceneStorage for per-window state restoration

## Rule
Replace the per-app @AppStorage state in AppRootScene with @SceneStorage where appropriate (= per-window state like `inspectorVisible`). Per Apple HIG Inventory 2026-09-06 `@SceneStorage` was 0 hits.

## Diff scope
`Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift` — change `@State private var inspectorVisible: Bool = false` to `@SceneStorage("wenshu.inspectorVisible") private var inspectorVisible: Bool = false`.

## Why
Apple HIG macOS 11+: 'Use @SceneStorage for per-window state restoration'. Currently wenshu uses @State (= not persisted). Per-window state should persist independently per scene.

## Verify
- swift build → exit 0
- open 2 windows → toggle inspector in window 1; close window 1; window 2 still shows its own inspector state
