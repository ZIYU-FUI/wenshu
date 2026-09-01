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
    /// v0.30 boss 2026-09-01 OOB (smooth slider, the divider
    /// follow-up): replace the 6-step ladder (= Apple's 6 official
    /// Liquid Glass Materials, one per 1/6 wide range) with a
    /// continuous scale. Boss observed that the 6-step ladder
    /// produced a visually identical tint across most of the
    /// slider range (= Apple's .ultraThinMaterial / .thinMaterial
    /// have alpha values that look identical at desktop distance)
    /// and that "the changes between 0 and 100 are too small;
    /// I want smooth 0 to 100 transition from fully transparent
    /// to opaque".
    ///
    /// Implementation = Apple's `Material.opacity(_:)` API
    /// (= macOS 27 / SwiftUI 27; the only public way to drive a
    /// Material's alpha continuously). The base Material is
    /// `.ultraThinMaterial` (= Apple's lightest Liquid Glass
    /// tier; the minimum opaque base before alpha = 0 is even
    /// considered). At slider = 0, `Material.opacity(0)` =
    /// fully transparent (= the desktop wallpaper shows through
    /// the title bar / tab bar / status bar / pane content). At
    /// slider = 1, `Material.opacity(1)` = the lightest Liquid
    /// Glass tier at full strength (= boss's "opaque" target;
    /// not 100 % black, just the maximum tint).
    ///
    /// The return type is `_OpacityShapeStyle<Material>` (= SwiftUI
    /// internal; transparently a `ShapeStyle`) so every existing
    /// caller (= RegionContentBackground / RegionTabBar /
    /// RegionStatusBar / AppStatusbar / SettingsEnvironmentCapturer
    /// .containerBackground) gets the smooth scale for free
    /// without rewriting its call site.
    ///
    /// Boss can tune in Settings -> 通用 -> 液态玻璃 slider.
    /// Slider value updates immediately via the manual @State mirror
    /// (= no need to restart the app).
    func toLiquidGlassMaterial() -> some ShapeStyle {
        Material.ultraThinMaterial.opacity(self)
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