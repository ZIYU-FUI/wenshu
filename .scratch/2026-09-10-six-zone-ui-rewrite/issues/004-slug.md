# Ticket 004 — land .searchable on the sidebar List

## Rule
Add `.searchable(text:)` modifier to NewLibraryOutlineView (the sidebar List). Per Apple HIG Inventory 2026-09-06 `.searchable` was 0 hits across the project; = a missing HIG API.

## Diff scope
`Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift` — find the List root and add `.searchable(text: $searchText, placement: .sidebar)` modifier + a file-local `@State private var searchText = ""`.

Filter logic: when `!searchText.isEmpty`, show only rows whose title contains the search text (case-insensitive).

## Why
Apple HIG macOS 26+: 'Use .searchable to let users filter long lists'. Library has shelves + books + folders = user needs filter.

## Verify
- swift build → exit 0
- launch app → search field appears at top of sidebar; type "book1" → list filters to matching rows
