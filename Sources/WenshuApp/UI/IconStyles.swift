//
//  IconStyles.swift · Wenshu · STYLES-002
//
//  Canonical SF Symbols icon styling (= size + rendering mode +
//  color preset). Companion to:
//  - ChromeStyles.swift (= chrome-level styling)
//  - ContentStyles.swift (= content-level styling)
//
//  Boss 9/7 'UI and function separated' = abstract the icon
//  styling into one file (= the same pattern as the other styles
//  files; = all icon usages in the codebase reference one
//  canonical size + rendering mode + color = single source of truth).
//
//  v1.0.0-m1-shell boss 2026-09-15 OOB 'remove Lucide, use SF
//  Symbols 6 (3rd generation) with palette rendering': rewritten
//  from Lucide (third-party library) to Apple SF Symbols 6
//  (= built into macOS 27 = zero SPM dependency). The token
//  system (IconSize / IconColor / IconStyle) is preserved from
//  the Lucide era so callers don't need to change their
//  IconSize references; the underlying rendering primitive
//  changes from LucideIcon View to Image(systemName:).
//
//  SF Symbols 6 (3rd generation) supports three rendering modes
//  per Apple developer docs (developer.apple.com/sf-symbols):
//  - .monochrome (= single color, default; = boss-approved
//    fallback for symbols without palette support)
//  - .hierarchical (= single color + depth via opacity; = the
//    canonical Apple HIG icon mode for toolbars / chrome)
//  - .palette (= per-layer colors up to 3 layers; = the
//    boss-approved primary mode for prominent icons like the
//    editor zone identity badge)
//
//  Usage:
//      SFIcon("books.vertical", size: .medium, color: .secondary)
//      SFIcon("wand.and.stars", rendering: .palette(.tint, .secondary))
//

import SwiftUI

// MARK: - Icon size presets

/// STYLES-002 (2026-09-07, refreshed 2026-09-15): canonical
/// SF Symbols icon size presets. Numeric values unchanged from
/// the Lucide era (= the iconography token layer is library-
/// agnostic; only the rendering primitive changed).
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
    /// is MainActor-isolated (= Swift 6 strict concurrency).
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

/// STYLES-002 (2026-09-07, refreshed 2026-09-15): canonical
/// SF Symbols color treatments. Each maps to a SwiftUI semantic
/// color per Apple HIG (= no hardcoded RGB / hex; = auto-adapts
/// to light / dark mode + tint settings).
///
/// Apple HIG alignment: all colors are semantic (= .primary /
/// .secondary / .tint / .accentColor) = the colors automatically
/// adapt to light / dark mode + tint settings without any custom
/// color logic.
enum IconColor {
    case primary         // .primary (= main text color)
    case secondary       // .secondary (= secondary text)
    case tint            // .tint (= app accent color = boss 9/2 'zone tint')
    case accent          // .accentColor (= explicit accent)
    case control         // Color.primary
}

// MARK: - SF Symbols rendering mode

/// STYLES-002 (refreshed 2026-09-15): canonical SF Symbols 6
/// rendering mode (= which of the 3 Apple-supported glyph
/// rendering paths the icon uses). Boss-approved rule: prefer
/// .palette for prominent icons, .hierarchical for chrome,
/// .monochrome as fallback.
///
/// Reference: developer.apple.com/sf-symbols (SF Symbols 6 /
/// iOS 17+ / macOS 14+).
enum IconRendering {
    /// Single-color icon (= .foregroundStyle(...) = no per-layer
    /// depth). Use this for symbols that don't support palette
    /// or hierarchical rendering in SF Symbols 6.
    case monochrome

    /// Single-color icon with depth via opacity layers. Apple
    /// canonical mode for chrome toolbars / inspector tabs.
    case hierarchical

    /// Per-layer colored icon (up to 3 layers). Use for prominent
    /// icons where multi-color depth communicates function
    /// (e.g. editor zone identity badge).
    case palette

    /// Palette with explicit primary + secondary layer colors.
    /// The (Color, Color) tuple maps to .foregroundStyle(layer0,
    /// layer1) on the Image (= Apple's two-layer palette API).
    case paletteLayers(Color, Color)
}

// MARK: - SFIcon helper (= canonical SF Symbols renderer)

/// STYLES-002 (refreshed 2026-09-15): canonical SF Symbols 6
/// icon renderer. Renders an SF Symbol glyph at the given size,
/// rendering mode, and color treatment. Replaces the Lucide-era
/// `LucideIcon(...)` helper.
///
/// Apple HIG weight rule (boss 2026-09-15 '细体' = 'thin body'):
/// weight = .regular (= the canonical macOS 27 toolbar glyph
/// weight, paired with palette / hierarchical rendering for
/// color depth without boldness).
///
/// Usage:
/// ```swift
/// SFIcon("books.vertical", size: .medium, color: .secondary)
/// SFIcon("wand.and.stars", size: .large, rendering: .palette,
///        color: .tint)
/// ```
@ViewBuilder
public func SFIcon(
    _ name: String,
    size: IconSize = .medium,
    rendering: IconRendering = .hierarchical,
    color: IconColor = .primary
) -> some View {
    let pointSize = size.value
    let base = Image(systemName: name)
        .font(.system(size: pointSize, weight: .regular))

    switch rendering {
    case .monochrome:
        base.foregroundStyle(semanticColor(color))

    case .hierarchical:
        base.symbolRenderingMode(.hierarchical)
            .foregroundStyle(semanticColor(color))

    case .palette:
        // Default palette: primary + tint layers (= boss 9/2
        // 'zone tint' = the canonical two-layer depth).
        base.symbolRenderingMode(.palette)
            .foregroundStyle(semanticColor(color), semanticColor(.tint))

    case .paletteLayers(let layer0, let layer1):
        base.symbolRenderingMode(.palette)
            .foregroundStyle(layer0, layer1)
    }
}

/// STYLES-002 (refreshed 2026-09-15): maps IconColor enum case
/// to the matching SwiftUI semantic Color (= no hardcoded RGB).
@MainActor
private func semanticColor(_ color: IconColor) -> Color {
    switch color {
    case .primary:   return Color.primary
    case .secondary: return Color.secondary
    case .tint:      return Color.accentColor
    case .accent:    return Color.accentColor
    case .control:   return Color.primary
    }
}

// MARK: - Convenience presets (= common combinations)

/// STYLES-002 (2026-09-07, refreshed 2026-09-15): combined icon
/// presets (= the most common icon usages in the workspace).
/// Use these instead of `IconSize + IconColor` when you want the
/// canonical combination.
///
/// Apple HIG boss rule (refreshed 2026-09-15):
/// - chrome: .hierarchical + .secondary (= toolbars, inspector
///   tabs; = the canonical Apple HIG macOS 27 chrome weight).
/// - tab: .hierarchical + .primary (= selected/unselected tab
///   distinction via color depth, not weight).
/// - action: .palette + .accent (= the action button's "I'm
///   clickable" affordance via two-layer depth).
/// - card: .palette + .tint (= editor zone identity badge;
///   = boss's 9/2 'zone tint' canonical badge).
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

extension View {
    /// STYLES-002 (refreshed 2026-09-15): apply a combined icon
    /// style (= size + rendering mode + color) to an `Image`.
    /// Replaces one-off size + color combinations.
    ///
    /// Usage:
    /// ```swift
    /// Image(systemName: "books.vertical").iconStyle(.chrome)
    /// // = 14 PT hierarchical .secondary icon (= chrome top bar)
    /// ```
    @ViewBuilder
    func iconStyle(_ preset: IconStyle) -> some View {
        switch preset {
        case .chrome:  self.iconStyle(.small, color: .secondary)
        case .tab:     self.iconStyle(.medium, color: .primary)
        case .action:  self.iconStyle(.medium, color: .accent)
        case .card:    self.iconStyle(.xlarge, color: .tint)
        }
    }

    /// STYLES-002 (refreshed 2026-09-15): apply a canonical icon
    /// style (= size + color) to an `Image` with explicit
    /// rendering mode + preset pair. Default rendering mode =
    /// .hierarchical (= canonical Apple HIG chrome mode).
    @ViewBuilder
    func iconStyle(_ size: IconSize = .medium, color: IconColor = .primary) -> some View {
        let pointSize = size.value
        let sfImage = self.font(.system(size: pointSize, weight: .regular))
        switch color {
        case .primary:
            sfImage.symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.primary)
        case .secondary:
            sfImage.symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.secondary)
        case .tint, .accent:
            sfImage.symbolRenderingMode(.palette)
                .foregroundStyle(Color.primary, Color.accentColor)
        case .control:
            sfImage.symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.primary)
        }
    }
}

// MARK: - SFLabel (= for segmented controls / Menu labels)

/// STYLES-002 (refreshed 2026-09-15): Label whose icon is an SF
/// Symbol. Use inside `Picker(.segmented)`, `Menu`, and toolbar
/// items (= these AppKit-backed SwiftUI controls require `Text`
/// or `Image` in their labels; = SF Symbols are first-class
/// `Image` and tint to the control's accent).
///
/// Replaces LucideLabel (which rasterized a Lucide glyph to
/// NSImage via ImageRenderer; = SF Symbols don't need that
/// bridge because they're native `Image`).
public struct SFLabel: View {
    private let title: String
    private let icon: String
    private let size: CGFloat

    public init(_ title: String, icon: String, size: CGFloat = 16) {
        self.title = title
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: size, weight: .regular))
        }
    }
}
