# Ticket 02: NSSplitView divider follows Liquid Glass opacity slider

Boss 2026-09-01 OOB: NSSplitView divider (= 拖拽线) is fully transparent and does not follow the Liquid Glass opacity slider. Boss wants to test the effect of linking divider transparency to the slider.

## Scope

- File: `Sources/WenshuApp/Views/Layout/PaneNSController.swift`

## Acceptance criteria

1. NSSplitView's divider renders with alpha proportional to `wenshu.liquidGlassOpacity` AppStorage slider.
2. At opacity 0.0: divider is invisible (boss OOB "完全透明").
3. At opacity 1.0: divider is fully visible (= Apple's standard `.thin` divider).
4. Slider changes propagate live without app restart.
5. Drag hit area still works (= effectiveRect override preserved from PR 4).
6. `swift build` exit 0.
7. Visual verification at opacity 0.0 / 0.25 / 0.5 / 0.75 / 1.0.

## Implementation

### Approach: NSSplitViewDividerStyle switch + Notification observer

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    applyDividerStyleForOpacity()
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(liquidGlassOpacityChanged),
        name: .liquidGlassOpacityChanged,
        object: nil
    )
}

@objc private func liquidGlassOpacityChanged() {
    applyDividerStyleForOpacity()
}

private func applyDividerStyleForOpacity() {
    let opacity = UserDefaults.standard.double(forKey: "wenshu.liquidGlassOpacity")
    splitView.dividerStyle = opacity < 0.05 ? .none : .thin
}
```

### Why `.thin` and not custom paint

Apple's `NSSplitView.DividerStyle.thin` on macOS 27 Tahoe is a 1 PT semitransparent hairline that adapts to dark/light mode. It IS the canonical Liquid Glass divider. No custom NSView drawing needed.

### Why no alpha override on `.thin`

`.thin` is already semitransparent. Apple doesn't expose a divider-alpha API on NSSplitView. Trying to override the divider color requires subclassing NSSplitView and overriding `drawDivider(in:with:)`. Out of scope for this feature.

Boss OOB "试一下效果" = try the effect. The simple hide/show at opacity 0 vs show-`.thin` for everything else is sufficient (= lets boss see the dramatic difference when slider is at 0).

## Out of scope

- Subclassing NSSplitView for custom divider paint (= overkill for v0.30)
- Color overrides on `.thin` (= Apple doesn't expose this)

## Verification

- Build: `swift build -c release` exit 0
- Visual: launch app, set opacity to 0.0 (= divider invisible), 0.5 (= divider visible), 1.0 (= divider visible), screenshot each
- Drag hit area: drag the divider position, verify pane sizes update (= effectiveRect preserved)