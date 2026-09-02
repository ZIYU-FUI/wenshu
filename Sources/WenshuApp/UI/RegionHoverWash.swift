// Sources/WenshuApp/UI/RegionHoverWash.swift
//
// v0.28 followup Boss UX round 35 (Boss 2026-08-29 OOB '各区域的完
// 整代码, 关于样式的, 不统一, 你要不盘一下'):
//
// = Single source of truth for hover/pressed wash backgrounds across
// the app. Previously each site independently chose its own wash
// material:
//
//   - TitlebarStatusbarPolish.swift: Color.clear.overlay(.thinMaterial)
//   - LayoutEditBar.swift: .fill(.thinMaterial)
//
// Inconsistency root cause = each site hand-implemented the same
// "translucent wash" pattern. Visual consistency was OK but code
// maintenance was not (= adding new hover sites means re-discovering
// the canonical pattern each time).
//
// Solution = extract a single RegionHoverWash component (= canonical
// .thinMaterial translucent wash) that ALL hover/pressed sites use.
//
// Why .thinMaterial (= what this component uses):
// - Lightest Liquid Glass tint (= barely-there wash = perfect for
//   hover/pressed feedback without overwhelming the underlying
//   content).
// - Apple HIG canonical hover wash style on macOS 27 Tahoe
//   (= Pages, Mail, Finder all use .thinMaterial for hover).
// - Matches Apple's hover behavior on macOS (= smooth, subtle).
//
// Design contract:
// - Material: .thinMaterial (= lightest Liquid Glass tint).
// - Caller provides the ShapeStyle binding (= works with both
//   `.fill(RegionHoverWashStyle)` and `.background(RegionHoverWashStyle)`).

import SwiftUI

// MARK: - RegionHoverWashStyle

/// Canonical "hover/pressed wash" ShapeStyle (= single source of truth
/// for all hover/pressed backgrounds across the app).
///
/// **SINGLE SOURCE OF TRUTH**: Used by TitlebarStatusbarPolish (×2
/// hover/pressed wash), LayoutEditBar (selected preset highlight),
/// and any future hover sites.
///
/// Visual configuration:
/// - Tint: `.thinMaterial` (= Apple HIG canonical hover wash on macOS
///   27 Tahoe = lightest Liquid Glass tint = subtle feedback).
///
/// Usage examples:
/// ```swift
/// // 1. Hover fill
/// RoundedRectangle(cornerRadius: 4)
///     .fill(RegionHoverWashStyle())
///
/// // 2. Hover background
/// .background(RegionHoverWashStyle())
/// ```
public struct RegionHoverWashStyle: ShapeStyle {
    public init() {}

    public func resolve(in environment: EnvironmentValues) -> Material {
        .thinMaterial
    }
}

// MARK: - Convenience extension

public extension ShapeStyle where Self == RegionHoverWashStyle {
    /// Apply canonical per-row hover/pressed wash.
    /// Usage: `.fill(.regionHoverWash)`
    static var regionHoverWash: RegionHoverWashStyle {
        get { RegionHoverWashStyle() }
    }
}

public extension View {
    /// Apply canonical per-row hover/pressed wash (= .thinMaterial).
    ///
    /// Usage: `SomeView().regionHoverWashBackground()`
    func regionHoverWashBackground() -> some View {
        self.background(RegionHoverWashStyle())
    }
}