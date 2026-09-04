# Ticket 1: AppState global @Observable store

## Goal

Add a single `AppState` @Observable class in `Sources/WenshuApp/State/AppState.swift` to centralize cross-zone UI state, replacing the 4-layer @Binding chain introduced by commit d845fe9c9.

## Files

- New file: `Sources/WenshuApp/State/AppState.swift`

## Implementation

See `spec.md` for full design. Implementation:

```swift
import Observation
import SwiftUI

@Observable
@MainActor
final class AppState {
    var sidebarSelection: SidebarItem? = nil
    var selectedEntity: Reference? = nil
    var selectedEntityCategory: EntityCategory? = nil
    var previewSortOrder: EntitySortOrder = .pinyinFirstLetter

    init() {}
}
```

## Acceptance criteria

1. Compiles clean
2. Per-window ownership (= each WindowGroup gets its own AppState via `@State`)
3. No behavioral changes (= other tickets in this batch wire it up)

## Out of scope

- Wiring (= Ticket 2)
- Persistence (= Ticket 3)
- Cleanup of old @Binding chain (= Ticket 4)

## Verification

Build `swift build` exit 0 after this ticket.