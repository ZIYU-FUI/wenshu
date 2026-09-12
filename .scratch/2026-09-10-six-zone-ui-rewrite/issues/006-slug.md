# Ticket 006 — land .fullScreenCover for editor focus mode

## Rule
Add `.fullScreenCover(isPresented:)` modifier wrapping EditorEditContent so the user can enter focus mode (= a single immersive editor surface). Per Apple HIG Inventory 2026-09-06 `.fullScreenCover` was 0 hits.

## Diff scope
`Sources/WenshuApp/Views/Workspace/EditorEditContent.swift` or NavigationSplitShell.swift ShellContentColumn. Add a `focusMode` @State + `.fullScreenCover(isPresented:)` modifier + a toolbar button to toggle.

## Why
Apple HIG macOS 14+: 'Use .fullScreenCover for focused single-task experiences'. Editor focus mode = the writing-app canonical feature.

## Verify
- swift build → exit 0
- focus button in editor toolbar → editor fills the screen; Escape returns to layout
