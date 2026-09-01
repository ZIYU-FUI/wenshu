// Sources/WenshuApp/UI/LiquidGlassOpacity.swift
//
// v0.28 followup Boss UX round 49 (Boss 2026-08-29 OOB '在设置里加一个功能,
// 液态玻璃透明度调节'): Liquid Glass opacity environment value.
//
// Lets any view in the SwiftUI tree read the user's Liquid Glass
// opacity preference (= 0.0 = fully transparent / 1.0 = strong tint).
// Set by the Settings panel slider (= `SettingView.liquidGlassOpacity`
// AppStorage key) and propagated via SwiftUI environment to all
// per-pane chrome components (RegionContentBackground, RegionTabBar,
// RegionStatusBar).
//
// Usage:
// 1. Read environment in any view:
//    @Environment(\.liquidGlassOpacity) var opacity
// 2. Apply opacity to material strength:
//    Color.clear.overlay(opacity > 0.5 ? .regularMaterial : .ultraThinMaterial)

import SwiftUI

// MARK: - Environment key

/// Environment key for the user's Liquid Glass opacity preference
/// (= 0.0 = fully transparent / 1.0 = strong tint, default 0.5).
private struct LiquidGlassOpacityKey: EnvironmentKey {
    static let defaultValue: Double = 0.5
}

// MARK: - Public API

public extension EnvironmentValues {
    /// User's Liquid Glass opacity preference (= 0.0 to 1.0).
    /// Set by `SettingView.liquidGlassOpacity` AppStorage.
    /// Read by `RegionContentBackground` (= per-pane content tint).
    var liquidGlassOpacity: Double {
        get { self[LiquidGlassOpacityKey.self] }
        set { self[LiquidGlassOpacityKey.self] = newValue }
    }
}

// MARK: - View modifier

public extension View {
    /// Inject the Liquid Glass opacity value into the SwiftUI
    /// environment so all descendant views can read it via
    /// `@Environment(\.liquidGlassOpacity)`.
    ///
    /// Usage: `ContentView().liquidGlassOpacityEnvironment(0.75)`
    func liquidGlassOpacityEnvironment(_ value: Double) -> some View {
        self.environment(\.liquidGlassOpacity, value)
    }
}

// MARK: - Material mapping helper

public extension Double {
    /// v0.30 boss 2026-09-01 OOB (6-step ladder follow-up to the
    /// titlebar-liquidglass scope fix): replace the prior 4-step
    /// mapping with the canonical 6-step ladder (= Apple's 6
    /// official Liquid Glass Materials, all from
    /// `developer.apple.com/documentation/swiftui/material`).
    ///
    /// Prior 4-step ladder collapsed the 0.00-0.49 range to
    /// `.ultraThinMaterial` (= 2 adjacent slider positions looked
    /// identical) and capped at `.thickMaterial` (= Apple also
    /// ships `.ultraThickMaterial` + `.barMaterial` which the prior
    /// ladder ignored). The new 6-step ladder uses ALL of Apple's
    /// official Materials with equal-width ranges; each slider
    /// position now produces a visibly distinct Material.
    ///
    /// Apple does NOT provide a programmatic "Material-for-fraction"
    /// helper; this ladder is the canonical workaround (= Apple API
    /// complete, custom mapping is the unavoidable part per boss
    /// "不和 Apple 标准冲突不考虑自定义" since the API itself does
    /// not collide with Apple's API surface).
    ///
    /// 6 equal-width ranges, each 1/6 ≈ 0.1667 wide:
    /// - [0.000, 0.166) → .ultraThinMaterial
    /// - [0.166, 0.333) → .thinMaterial
    /// - [0.333, 0.500) → .regularMaterial
    /// - [0.500, 0.666) → .thickMaterial
    /// - [0.666, 0.833) → .ultraThickMaterial
    /// - [0.833, 1.000] → .bar
    ///
    /// Boss can tune in Settings -> 通用 -> 液态玻璃 slider.
    /// Slider value updates immediately via the manual @State mirror
    /// (= no need to restart the app).
    func toLiquidGlassMaterial() -> Material {
        if self < 1.0/6.0 {
            return .ultraThinMaterial
        } else if self < 2.0/6.0 {
            return .thinMaterial
        } else if self < 3.0/6.0 {
            return .regularMaterial
        } else if self < 4.0/6.0 {
            return .thickMaterial
        } else if self < 5.0/6.0 {
            return .ultraThickMaterial
        } else {
            return .bar
        }
    }

    /// v0.30 boss 2026-09-01 OOB (6-step ladder + divider line): the
    /// AppKit divider line (= `WenshuSplitView.drawDivider`) cannot
    /// use SwiftUI Material directly (= it draws via `NSColor`). This
    /// helper returns the `CGFloat` alpha for `NSColor.separatorColor`
    /// matched to the same 6-step ladder (= same range boundaries
    /// as `toLiquidGlassMaterial()`; the divider line alpha scales
    /// with the slider so it stays consistent with the surrounding
    /// chrome).
    ///
    /// 6 alpha outputs:
    /// - [0.000, 0.166) → 0.5  (ultraThin; barely visible)
    /// - [0.166, 0.333) → 0.6
    /// - [0.333, 0.500) → 0.7  (regular)
    /// - [0.500, 0.666) → 0.85 (thick)
    /// - [0.666, 0.833) → 1.0  (ultraThick; fully opaque)
    /// - [0.833, 1.000] → 1.0  (bar; fully opaque)
    func toLiquidGlassDividerAlpha() -> CGFloat {
        if self < 1.0/6.0 {
            return 0.5
        } else if self < 2.0/6.0 {
            return 0.6
        } else if self < 3.0/6.0 {
            return 0.7
        } else if self < 4.0/6.0 {
            return 0.85
        } else if self < 5.0/6.0 {
            return 1.0
        } else {
            return 1.0
        }
    }
}

// MARK: - AppStorage bridge

public extension Notification.Name {
    /// Posted when the user changes the Liquid Glass opacity in
    /// Settings (= slider value updated). Components that want to
    /// react to the change (= even outside the Settings view's
    /// environment scope) can observe this notification.
    static let liquidGlassOpacityChanged = Notification.Name("wenshu.liquidGlassOpacityChanged")
}