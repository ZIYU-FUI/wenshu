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
    /// v0.30 boss 2026-09-01 OOB: extend Liquid Glass opacity
    /// slider mapping from just the pane content background
    /// (= RegionContentBackground, committed in v0.28 followup
    /// round 49) to ALSO cover the per-pane title bar / status
    /// bar / divider (= three surfaces that should follow the
    /// same slider). Returns the SwiftUI Material for a given
    /// opacity (= 4 discrete steps, matching Apple's Liquid
    /// Glass translucency ladder).
    ///
    /// - 0.00 - 0.24: .ultraThinMaterial (= nearly invisible)
    /// - 0.25 - 0.49: .ultraThinMaterial (= subtle glass tint)
    /// - 0.50 - 0.74: .regularMaterial (= standard glass tint)
    /// - 0.75 - 1.00: .thickMaterial (= strong tint)
    ///
    /// Boss can tune in Settings -> 通用 -> 液态玻璃 slider.
    /// Slider value updates immediately via @AppStorage (= no
    /// need to restart the app).
    func toLiquidGlassMaterial() -> Material {
        if self < 0.25 {
            return .ultraThinMaterial
        } else if self < 0.5 {
            return .ultraThinMaterial
        } else if self < 0.75 {
            return .regularMaterial
        } else {
            return .thickMaterial
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