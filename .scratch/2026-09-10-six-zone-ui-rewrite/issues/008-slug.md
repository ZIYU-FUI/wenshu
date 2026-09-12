# Ticket 008 — land .navigationSubtitle for window title status

## Rule
Add `.navigationSubtitle("...")` modifier to LibraryRootView (= root of NSV). Per Apple HIG Inventory 2026-09-06 `.navigationSubtitle` was 0 hits.

## Diff scope
`Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift` — add `.navigationSubtitle(appState.subtitleText)` next to existing `.navigationTitle("")`.

## Why
Apple HIG macOS 11+: 'Use .navigationTitle and .navigationSubtitle to display the document title'.

## Verify
- swift build → exit 0
- window title shows library name + subtitle below (= Apple canonical Pages / Numbers look)
