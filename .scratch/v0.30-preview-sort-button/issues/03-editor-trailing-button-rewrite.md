# Ticket 3: rewrite EditorExpandShrinkTrailingButton to match NewButtonWithHover pattern

## Goal
Same fix as Ticket 02 (= replace Color.clear + .overlay icon pattern
with plain Button + LucideIcon + .frame(width: 28, height: 28) +
.onHover + .background tint).

## Root cause (= bug pattern)
The editor's expand/shrink button used `Color.clear.frame(...)` as the
Button label base + `.overlay(alignment: .center) { icon }` to render
the icon. While the icon overlay rendered correctly, the Color.clear
base meant:
- No hover tint visible (= hover tinting applies to the entire Button,
  but Color.clear doesn't accept the tint fill)
- The hit area was technically invisible to the user (= matches the
  icon size, but no visual feedback on hover)
- The implementation was inconsistent with sidebar's NewButtonWithHover
  pattern (= which DOES have visible hover tint)

After PaneTabBar fix in Ticket 01, the button DOES render at the right
edge. But the Color.clear base = no hover feedback.

## Fix
Replace Color.clear + overlay with plain Button + LucideIcon +
.frame(width: 28, height: 28) + .onHover + .background tint.

## Acceptance criteria
1. `swift build` exit 0.
2. Expand/shrink icon visible at right edge of editor pane top bar.
3. Hover shows accent color tint (= matches sidebar NewButtonWithHover).
4. Click cycles between expand ↔ shrink icons.

## Files touched
- `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` —
  `EditorExpandShrinkTrailingButton` struct (~15 lines change).

## Diff summary
```swift
// before: Color.clear + .overlay(alignment: .center) icon
Button {
    editorMaximized.toggle()
} label: {
    Color.clear
        .frame(width: LayoutTokens.chatTabHotArea, height: LayoutTokens.chatTabHotArea)
        .overlay(alignment: .center) {
            if let lucide = Lucide(...) { lucide.aspectRatio(...).frame(...)... }
        }
        .contentShape(Rectangle())
}
.buttonStyle(.plain)
.help(editorMaximized ? "恢复 (shrink)" : "展开 (expand)")

// after: plain Button + LucideIcon + hover tint
Button {
    editorMaximized.toggle()
} label: {
    if let lucide = Lucide(editorMaximized ? "shrink" : "expand") {
        lucide
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .foregroundStyle(Color.secondary)
    } else {
        Image(systemName: ...)
            .frame(width: 28, height: 28)
            ...
    }
}
.buttonStyle(.plain)
.onHover { hovering in isHover = hovering }
.background(
    RoundedRectangle(cornerRadius: 4)
        .fill(isHover ? Color.accentColor.opacity(0.12) : Color.clear)
)
.help(editorMaximized ? "恢复 (shrink)" : "展开 (expand)")
```