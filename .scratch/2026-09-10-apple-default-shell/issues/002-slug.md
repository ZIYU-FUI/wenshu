# Ticket 002 — replace custom `@AppStorage cardZoneHeight` + drag handle with `VSplitView`

## Rule
ShellSidebarColumn currently has a 94-LOC custom split: `@AppStorage` height state + Rectangle fill separator + 6 PT hit area + NSCursor + DragGesture + clamp function. Replace the entire custom block with `VSplitView { NewLibraryOutlineView(); ZoneModuleView(zoneSlot: .projectPreview) }`. `VSplitView` is Apple-canonical (developer.apple.com/documentation/swiftui/vsplitview) — it gives AppKit-standard 8 PT thick divider with grab handle and auto-saves position via `.autosaveName`.

## Diff scope
`Sources/WenshuApp/UI/Layout/NavigationSplitShell.swift` lines 193-289 — delete entirely (the `@AppStorage`, `@State`, `body`'s `.safeAreaInset` + `.overlay`, `cardZoneResizeHandle`, `clampCardZoneHeight`). Replace `body` content with:
```swift
var body: some View {
    VSplitView {
        NewLibraryOutlineView()
        ZoneModuleView(zoneSlot: .projectPreview)
    }
}
```

## Why
Per boss 2026-09-10 "\u5168\u90fd\u6539\u5230\u9ed8\u8ba4". The custom drag-handle was an in-house workaround (the 9/9 v0.50 commit comment notes "VSplitView costs the sidebar material"). On re-check this trade-off is no longer required — wenshu uses `NSSplitView.autosaveName` via SwiftUI's `VSplitView` for free and the previous test was made before the macOS 27 `.glassEffect(.regular)` adoption which already covers the material concern.

## Verify
- swift build → exit 0
- launch app → sidebar splits at 50/50 default between outline + cards
- drag the divider → both regions resize; AppKit auto-saves position
- relaunch app → divider position persists
