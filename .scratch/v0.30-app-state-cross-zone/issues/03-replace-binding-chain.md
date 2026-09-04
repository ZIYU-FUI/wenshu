# Ticket 3: Replace @Binding chain with @Environment(AppState.self)

## Goal

Replace the 4-layer @Binding sidebarSelection chain (= WorkspaceView → PaneRenderer → TabContentDispatcher → ZoneModuleView → NewLibraryOutlineView, added by commit d845fe9c9) with a single `@Environment(AppState.self)` lookup. Same for selectedEntity / selectedEntityCategory.

## Files

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`
- `Sources/WenshuApp/Views/Workspace/PPaneRenderer.swift`
- `Sources/WenshuApp/Views/Library/NewLibraryOutlineView.swift`

## Implementation

### WorkspaceView (remove `@Binding` threads + `@State` sidebarSelection source)

Currently:
```swift
@State private var sidebarSelection: SidebarItem? = nil
@Binding var sidebarSelection: SidebarItem?
@Binding var selectedEntityCategory: EntityCategory?
@Binding var selectedEntity: Reference?
```

Replace with:
```swift
@Environment(AppState.self) private var appState

// previewScope stays (= computed from appState.sidebarSelection)
private var previewScope: PreviewScope { ... }
```

### PaneRenderer / TabContentDispatcher

Currently:
```swift
@Binding var sidebarSelection: SidebarItem?
```

Replace with:
```swift
@Environment(AppState.self) private var appState
```

### NewLibraryOutlineView

Currently:
```swift
@Binding var sidebarSelection: SidebarItem?
```

Replace with:
```swift
@Environment(AppState.self) private var appState
```

The `List(selection:)` binding then becomes:
```swift
List(selection: Binding(
    get: { appState.sidebarSelection },
    set: { appState.sidebarSelection = $0 }
))
```

The `.onChange(of: sidebarSelection)` block (= which forwards to bookStore.selectedBookId + selectedEntityCategory) stays — just rename `sidebarSelection` to `appState.sidebarSelection`.

### ZoneModuleView (also remove duplicate previewScope)

Currently:
```swift
@Binding var sidebarSelection: SidebarItem?
private var previewScope: PreviewScope { ... }  // duplicated
```

Replace with:
```swift
@Environment(AppState.self) private var appState
```

(`previewScope` is removed — read from `appState.sidebarSelection` at use site.)

## Acceptance criteria

1. Sidebar click → preview pane updates (= scope dispatch still works)
2. 资料库 category click → preview pane shows that category's entities
3. Click book/folder rows → preview pane shows .md docs
4. No `@Binding sidebarSelection` remaining (= grep returns 0 hits)
5. Build clean

## Verification

- Build exit 0
- Launch APP, click each sidebar row type, verify preview pane content matches
- Compare visual to current (= no regression)

## Out of scope

- Persistence (= Ticket 4 — `.onChange` block in WorkspaceView persists sidebarSelection to @AppStorage)