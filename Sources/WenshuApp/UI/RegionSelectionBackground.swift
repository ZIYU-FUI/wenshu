// Sources/WenshuApp/UI/RegionSelectionBackground.swift
//
// v0.28 followup Boss UX round 34 (Boss 2026-08-29 OOB '各区域的完
// 整代码, 关于样式的, 不统一, 你要不盘一下'):
//
// = Single source of truth for "selected row" backgrounds across
// the app. Previously each outline view + the pane renderer used
// DIFFERENT selection style implementations:
//
//   - PaneRenderer.swift (group tabs): Color.accentColor.opacity(0.15)
//   - BookOutlineView.swift (sidebar): Color(nsColor: .controlBackgroundColor)
//   - WorldOutlineView.swift (sidebar): Color(nsColor: .controlBackgroundColor)
//   - CharacterOutlineView.swift (sidebar): Color(nsColor: .controlBackgroundColor)
//   - ReferenceLibraryOutlineView.swift: Color(nsColor: .controlBackgroundColor).opacity(0.5)
//
// Inconsistency root cause = 4 sidebar outline views used the SOLID
// NSColor `.controlBackgroundColor` (= opaque gray = NOT Liquid
// Glass), while PaneRenderer used `.accentColor.opacity(0.15)` (= a
// translucent Apple accent tint = true Liquid Glass). Sidebar rows
// looked visibly different from selected pane group tabs.
//
// Solution = extract a single RegionSelectionBackground component
// that ALL selection sites use. Now all selection rows show the same
// translucent Apple accent tint.
//
// Why `.accentColor.opacity(0.15)` (= what this component uses):
// - Apple HIG canonical selected row background style on macOS 27
//   Tahoe (= same color as selected Finder sidebar items, Mail
//   message rows, Messages conversation items).
// - Translucent over any background (= works with both opaque and
//   transparent parent backgrounds).
// - Distinguishable from hover state (= hover uses slightly lighter
//   wash, selected uses accent tint).
//
// Design contract for the single component:
// - Background tint: Color.accentColor at opacity 0.15 (= Apple HIG).
// - Shape: caller-provided (= RoundedRectangle for buttons, Rectangle
//   for full-width rows, etc.).
// - One place to change selection style = entire app updates.

import SwiftUI

// MARK: - RegionSelectionBackground

/// Canonical "selected row" background fill (= single source of truth
/// for all selection styles across the app).
///
/// **SINGLE SOURCE OF TRUTH**: Used by PaneRenderer group tabs, sidebar
/// outline views (= Book / World / Character / Reference rows), etc.
/// All selection rows now render with the same translucent Apple accent
/// tint (= boss's "样式不统一" issue resolved for selection backgrounds).
///
/// Visual configuration:
/// - Tint: `Color.accentColor.opacity(0.15)` (= Apple HIG canonical
///   selected row background on macOS 27 Tahoe).
/// - Applied as a `ShapeStyle` (= caller wraps in their desired shape:
///   `Rectangle().fill(RegionSelectionBackgroundStyle)` or
///   `RoundedRectangle(cornerRadius: 4).fill(RegionSelectionBackgroundStyle)`).
///
/// Usage examples:
/// ```swift
/// // 1. Full-width row
/// Rectangle().fill(RegionSelectionBackgroundStyle)
///
/// // 2. Rounded card
/// RoundedRectangle(cornerRadius: 4)
///     .fill(RegionSelectionBackgroundStyle)
///
/// // 3. Background modifier
/// .background(RegionSelectionBackgroundStyle)
/// ```
/// Canonical "selected row" background fill (= single source of truth
/// for all selection styles across the app).
///
/// **SINGLE SOURCE OF TRUTH**: Used by PaneRenderer group tabs, sidebar
/// outline views (= Book / World / Character / Reference rows), etc.
/// All selection rows now render with the same translucent Apple accent
/// tint (= boss's "样式不统一" issue resolved for selection backgrounds).
///
/// Visual configuration:
/// - Tint: `Color.accentColor.opacity(0.15)` (= Apple HIG canonical
///   selected row background on macOS 27 Tahoe).
/// - Applied as a `ShapeStyle` (= caller wraps in their desired shape:
///   `Rectangle().fill(RegionSelectionBackgroundStyle)` or
///   `RoundedRectangle(cornerRadius: 4).fill(RegionSelectionBackgroundStyle)`).
///
/// Usage examples:
/// ```swift
/// // 1. Full-width row
/// Rectangle().fill(RegionSelectionBackgroundStyle())
///
/// // 2. Rounded card
/// RoundedRectangle(cornerRadius: 4)
///     .fill(RegionSelectionBackgroundStyle())
///
/// // 3. Background modifier
/// .background(RegionSelectionBackgroundStyle())
/// ```
public struct RegionSelectionBackgroundStyle: ShapeStyle {
    public init() {}

    public func resolve(in environment: EnvironmentValues) -> Color {
        Color.accentColor.opacity(0.15)
    }
}

// MARK: - Convenience extension

public extension ShapeStyle where Self == RegionSelectionBackgroundStyle {
    /// Apply canonical per-row selection background tint.
    /// Usage: `.fill(.regionSelection)`
    static var regionSelection: RegionSelectionBackgroundStyle {
        get { RegionSelectionBackgroundStyle() }
    }
}

public extension View {
    /// Apply canonical per-row selection background (= Apple accent
    /// tint at 0.15 opacity).
    ///
    /// Usage: `SomeView().regionSelectionBackground()`
    func regionSelectionBackground() -> some View {
        self.background(RegionSelectionBackgroundStyle())
    }
}