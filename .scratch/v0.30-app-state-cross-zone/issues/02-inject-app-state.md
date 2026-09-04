# Ticket 2: Inject AppState at app root

## Goal

Wire AppState into the SwiftUI view hierarchy via `.environment(appState)` at the WiredShell level, owned by `@State` so each WindowGroup gets its own instance.

## Files

- `Sources/WenshuApp/App.swift` — add `@State` + `.environment(appState)` to WiredShell
- `Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift` — verify the env propagates to WorkspaceView

## Implementation

In `App.swift` WenshuApp struct:
```swift
@main
struct WenshuApp: App {
    @State private var appState = AppState()  // NEW: per-window app state
    @State private var bookStore = BookStore.shared
    @State private var workspaceStore: WorkspaceStore?
    @State private var library: WenshuLibrary
    @State private var appearanceMode: AppearanceMode = .auto
    @State private var liquidGlassOpacity: Double = 0.5

    var body: some Scene {
        WindowGroup("") {
            SettingsEnvironmentCapturer(library: library, appearanceMode: appearanceMode)
                .environment(appState)        // NEW
                .environment(bookStore)
                .environment(workspaceStore)
                .environment(liquidGlassOpacity)
                .task { ... }
                .containerBackground(for: .window) { ... }
        }
    }
}
```

## Acceptance criteria

1. `appState` is owned by `WenshuApp` (= per-window, isolated across multiple windows)
2. `.environment(appState)` is on the root view (= all descendants see it)
3. Existing `WorkspaceStore` + `BookStore` still work (= no regression)
4. Build clean

## Verification

- Build exit 0
- Launch APP, click sidebar rows — selection still updates preview pane (= proves env propagation)
- Open second WindowGroup (= `Cmd+N` if wenshu supports it) — second window has its own sidebarSelection state

## Out of scope

- Replacing the @Binding chain (= Ticket 3)
- Persistence (= Ticket 4)