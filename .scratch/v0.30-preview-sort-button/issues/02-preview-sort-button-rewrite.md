# Ticket 2: rewrite PreviewSortMenuButton to match NewButtonWithHover pattern

## Goal
Replace the Menu + .menuStyle(.button) + .menuIndicator(.hidden)
implementation with a plain Button + cycle-through sort order pattern,
matching the sidebar's `NewButtonWithHover` (= which renders correctly
in ZoneContentView's trailing slot).

## Root cause (= bug pattern)
SwiftUI's `Menu` view doesn't render its label inside an `AnyView`
wrapper (= which is what ZoneContentView's trailingButton slot uses
to type-erase the trailing view). The previous implementation used:

```swift
Menu { ... ForEach(EntitySortOrder.allCases) { ... } ... }
    .menuStyle(.button)  // tries to make label visible
    .menuIndicator(.hidden)  // hides the chevron-down indicator
```

`.menuStyle(.button)` is supposed to render the label visually like
a normal toolbar button. But inside `AnyView` wrapping, the label
collapses to zero size.

## Fix
Use plain `Button` + `LucideIcon` + `.frame(width: 28, height: 28)` +
`.onHover` + `.background` tint (= exact `NewButtonWithHover` pattern
from sidebar's `zoneHeaderButtons`, which DOES render correctly).

Cycle through 3 sort orders on tap (= no dropdown needed; click to
rotate). Icon updates to reflect current order via
`sortOrder.menuIcon`.

## Acceptance criteria
1. `swift build` exit 0.
2. Sort icon visible at right edge of preview pane top bar.
3. Click on sort icon cycles through 3 sort orders.
4. Sort change re-renders preview pane cards in new order.
5. Hover on sort icon shows accent color tint.
6. Lucide icon = `list-ordered` (= matches Boss 8/30 OOB).

## Files touched
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` —
  `PreviewSortMenuButton` struct (~20 lines change).

## Diff summary
```swift
// before: Menu + .menuStyle(.button) + .menuIndicator(.hidden)
Menu { ForEach(EntitySortOrder.allCases) { ... } } label: {
    HStack(spacing: 4) {
        Text(sortOrder.rawValue) ...
        LucideIcon(sortOrder.menuIcon, size: 16) ...
    } ...
}
.menuStyle(.button)
.menuIndicator(.hidden)
.help("排序方式: \(sortOrder.rawValue)")

// after: plain Button + LucideIcon + cycle-through pattern
Button {
    switch sortOrder {
    case .pinyinFirstLetter: sortOrder = .createdAt
    case .createdAt: sortOrder = .modifiedAt
    case .modifiedAt: sortOrder = .pinyinFirstLetter
    }
} label: {
    LucideIcon(sortOrder.menuIcon, size: 18)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .foregroundStyle(.tint)
}
.buttonStyle(.plain)
.onHover { hovering in isHover = hovering }
.background(
    RoundedRectangle(cornerRadius: 4)
        .fill(isHover ? Color.accentColor.opacity(0.12) : Color.clear)
)
.help("排序方式: \(sortOrder.rawValue)")
```

## Why cycle-through instead of dropdown menu?
Boss OOB says "排序功能的 icon 没有实现" (= an icon for sort, not a
dropdown). The icon itself is the affordance; click to rotate. The
rawValue text label is removed (= icon is sufficient visual feedback
+ tooltip shows current sort name on hover). Three sort options cycle
through: pinyinFirstLetter → createdAt → modifiedAt → pinyinFirstLetter.