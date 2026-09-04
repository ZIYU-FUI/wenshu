# Ticket 4: Persistence + domain-modeling commit

## Goal

1. Make sure `sidebarSelection` (and any other user-visible AppState signals) persist across launches via the existing `@AppStorage("wenshu.sidebarSelection")` mechanism (= already wired in commit a82397943).
2. Update `CONTEXT.md` with `AppState` as a new domain word (Q34 step 7).
3. Add a test (= sanity that AppState reads/writes work).

## Files

- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` — verify `.onAppear` + `.onChange` use `appState.sidebarSelection`
- `CONTEXT.md` — add `AppState (v0.30 cross-zone @Observable)` row

## Implementation

In WorkspaceView body (already wired from commit a82397943 + d845fe9c9):
```swift
.onAppear {
    if appState.sidebarSelection == nil,
       !persistedSidebarSelection.isEmpty,
       let data = persistedSidebarSelection.data(using: .utf8),
       let item = try? JSONDecoder().decode(SidebarItem.self, from: data) {
        appState.sidebarSelection = item
    }
}
.onChange(of: appState.sidebarSelection) { _, newValue in
    if let item = newValue,
       let data = try? JSONEncoder().encode(item),
       let json = String(data: data, encoding: .utf8) {
        persistedSidebarSelection = json
    } else {
        persistedSidebarSelection = ""
    }
}
```

Update `CONTEXT.md` (= add the AppState row).

## Acceptance criteria

1. Close APP, reopen → sidebar selection restored (= last clicked)
2. `CONTEXT.md` has AppState row (= alphabetical insertion)
3. Build clean

## Verification

- Build exit 0
- Manual: click shelf row → close → reopen → shelf still highlighted + preview pane shows same scope
- `git diff CONTEXT.md` shows the new row