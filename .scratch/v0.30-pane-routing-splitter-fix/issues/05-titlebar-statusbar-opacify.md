# Ticket 01: Title bar + status bar follow Liquid Glass opacity slider

Boss 2026-09-01 OOB: title bar (= 标题栏) is fully transparent and does not follow the Liquid Glass opacity slider in Settings. Status bar has the same issue.

## Scope

- File: `Sources/WenshuApp/UI/RegionTabBar.swift`
- File: `Sources/WenshuApp/UI/LiquidGlassOpacity.swift`
- File: `Sources/WenshuApp/UI/RegionContentBackground.swift`

## Acceptance criteria

1. `RegionTabBar.body` reads `@Environment(\.liquidGlassOpacity)`.
2. `RegionTabBar.body` replaces `.background(.regularMaterial)` with a 4-step mapping (= same as RegionContentBackground).
3. `RegionStatusBar.body` reads `@Environment(\.liquidGlassOpacity)` and applies the same 4-step mapping.
4. New helper `regionChromeMaterial(opacity:)` in `LiquidGlassOpacity.swift` returns the Material for the given opacity.
5. `RegionContentBackground` refactored to use the new helper (= dedupe).
6. `swift build` exit 0.
7. Visual verification at opacity 0.0 / 0.25 / 0.5 / 0.75 / 1.0.

## Implementation

### Step 1: Add helper to LiquidGlassOpacity.swift

```swift
public extension LiquidGlassOpacity {
    /// Map the opacity slider (0.0 to 1.0) to a SwiftUI Material
    /// (= 4 discrete levels matching Apple's Liquid Glass
    /// translucency ladder). Used by RegionContentBackground,
    /// RegionTabBar, RegionStatusBar (= three surfaces that
    /// need the same opacity behavior).
    ///
    /// - 0.00 - 0.24: .ultraThinMaterial-or-clear (= nearly invisible)
    /// - 0.25 - 0.49: .ultraThinMaterial (= subtle glass tint)
    /// - 0.50 - 0.74: .regularMaterial (= standard glass tint)
    /// - 0.75 - 1.00: .thickMaterial (= strong tint)
    ///
    /// Return type: SwiftUI Material (= opaque type-erased wrapper).
    static func regionChromeMaterial(opacity: Double) -> Material {
        if opacity < 0.25 {
            return .ultraThinMaterial
        } else if opacity < 0.5 {
            return .ultraThinMaterial
        } else if opacity < 0.75 {
            return .regularMaterial
        } else {
            return .thickMaterial
        }
    }
}
```

### Step 2: Refactor RegionContentBackground

Replace the inline if/else with `regionChromeMaterial(opacity: liquidGlassOpacity)`.

### Step 3: Apply to RegionTabBar + RegionStatusBar

In each body's `.background(...)` modifier:
```swift
.background(LiquidGlassOpacity.regionChromeMaterial(opacity: liquidGlassOpacity))
```

Where `liquidGlassOpacity` is `@Environment(\\.liquidGlassOpacity) private var liquidGlassOpacity: Double`.

## Out of scope (= separate tickets)

- NSSplitView divider transparency (ticket 02)
- AppStorage wiring (already done in v0.28 followup round 49)

## Verification

- Build: `swift build` exit 0
- Visual: launch app, set opacity to 0.0 / 0.25 / 0.5 / 0.75 / 1.0, screenshot each