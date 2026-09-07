//
//  IconStyles.swift · Wenshu · STYLES-002
//
//  Canonical Lucide icon styling (= size + color preset).
//  Companion to:
//  - ChromeStyles.swift (= chrome-level styling)
//  - ContentStyles.swift (= content-level styling)
//
//  Boss 9/7 'ui 与功能分离' = abstract the icon styling into one
//  file (= the same pattern as the other styles files; = all
//  Lucide icon usages in the codebase can reference one
//  canonical size + color = single source of truth).
//
//  Ponytail principle 'use stdlib / Apple-native / existing
//  dependencies before writing new code': this file wraps the
//  existing Lucide component (= ke-case-per-icon, see
//  ke3zhen1/grape's Lucide library) and adds 3 size presets +
//  3 color treatments. No new icon rendering primitive = no
//  library re-implementation.
//
//  Usage:
//      Lucide(\"square-pen\")
//          .iconStyle(.chrome)        // = 14 PT + secondary color
//      Lucide(\"library\")
//          .iconStyle(.editorLarge)   // = 32 PT + tint
//      Lucide(\"send\")
//          .iconStyle(.actionButton)  // = 18 PT + accentColor
//

import SwiftUI
import Lucide

// MARK: - Icon size presets

/// STYLES-002 (2026-09-07): canonical Lucide icon size presets
/// (= each maps to a DesignTokens value; = no magic numbers in
/// the calling code per iron-rule 6).
///
/// Why presets (= not raw CGFloat):
/// - "small" (14 PT) = chrome toolbar icons (= Apple HIG standard
///   for inline toolbar glyphs).
/// - "medium" (18 PT) = tab bar / action button icons (= matches
///   `tabIconSize` in DesignTokens).
/// - "large" (24 PT) = card / prominent control icons.
/// - "xlarge" (32 PT) = editor zone entity-type badges / hero icons.
/// - "custom(CGFloat)" = escape hatch (= not common).
enum IconSize {
    case small         // 14 PT — chrome toolbar / inline icons
    case medium        // 18 PT — tab bar / action button
    case large         // 24 PT — card / prominent control
    case xlarge        // 32 PT — entity badge / hero icon
    case custom(CGFloat)

    /// STYLES-002 (2026-09-07): @MainActor because DesignTokens
    /// is MainActor-isolated (= Swift 6 strict concurrency =
    /// static let CGFloat on a non-Sendable type). The iconStyle
    /// modifier is called from SwiftUI body (= already @MainActor
    /// context) so this never blocks.
    @MainActor
    var value: CGFloat {
        switch self {
        case .small:            return DesignTokens.iconSmall
        case .medium:           return DesignTokens.tabIconSize
        case .large:            return DesignTokens.iconLargeSize
        case .xlarge:           return 32
        case .custom(let v):    return v
        }
    }
}

// MARK: - Icon color treatments

/// STYLES-002 (2026-09-07): canonical Lucide icon color
/// treatments (= each maps to a SwiftUI / AppKit semantic color
/// per iron-rule 1 = no hardcoded RGB / hex).
///
/// Apple HIG alignment: all colors are semantic (= .primary /
/// .secondary / .tint / .accentColor / NSColor.*) = the colors
/// automatically adapt to light / dark mode + tint settings without
/// any custom color logic.
enum IconColor {
    case primary         // .primary (= main text color)
    case secondary       // .secondary (= secondary text)
    case tint            // .tint (= app accent color = boss 9/2 '区域 tint')
    case accent          // .accentColor (= explicit accent)
    case control         // Color(nsColor: .controlTextColor)
}

extension Lucide {
    /// STYLES-002 (2026-09-07): apply a canonical icon style (= size
    /// + color in one call). Replaces scattered `.frame(width:N,
    /// height:N).foregroundStyle(...)` chains.
    ///
    /// Usage:
    /// ```swift
    /// Lucide("library").iconStyle(.chrome)
    /// // = 14 PT icon in .secondary color (= chrome top bar identity)
    /// ```
    @ViewBuilder
    func iconStyle(_ size: IconSize = .medium, color: IconColor = .primary) -> some View {
        self.frame(width: size.value, height: size.value)
            .modifier(IconColorModifier(color: color))
    }
}

/// STYLES-002 (2026-09-07): internal helper that applies a
/// SwiftUI / AppKit semantic color (= no hardcoded colors per
/// iron-rule 1).
private struct IconColorModifier: ViewModifier {
    let color: IconColor

    func body(content: Content) -> some View {
        switch color {
        case .primary:   content.foregroundStyle(Color.primary)
        case .secondary: content.foregroundStyle(Color.secondary)
        case .tint:      content.foregroundStyle(Color(nsColor: .controlAccentColor))
        case .accent:    content.foregroundStyle(Color.accentColor)
        case .control:   content.foregroundStyle(Color(nsColor: .controlTextColor))
        }
    }
}

// MARK: - Convenience presets (= common combinations)

/// STYLES-002 (2026-09-07): combined icon presets (= the most
/// common icon usages in the workspace). Use these instead of
/// `IconSize + IconColor` when you want the canonical combination.
enum IconStyle {
    /// Chrome top bar identity icon (= the zone icon in
    /// ChromeStyles.swift's ChromeTopBar).
    case chrome
    /// Tab bar icon (= PaneIconTab / PaneTabBar items).
    case tab
    /// Action button icon (= send button, paperclip, etc.).
    case action
    /// Card / entity type badge icon (= large prominent).
    case card
}

extension Lucide {
    /// STYLES-002 (2026-09-07): apply a combined icon style (= size
    /// + color + optional border, = the canonical preset for each
    /// common use case). Replaces one-off size + color combinations.
    @ViewBuilder
    func iconStyle(_ preset: IconStyle) -> some View {
        switch preset {
        case .chrome:  self.iconStyle(.small, color: .secondary)
        case .tab:     self.iconStyle(.medium, color: .primary)
        case .action:  self.iconStyle(.medium, color: .accent)
        case .card:    self.iconStyle(.xlarge, color: .tint)
        }
    }
}
