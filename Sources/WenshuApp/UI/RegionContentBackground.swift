// Sources/WenshuApp/UI/RegionContentBackground.swift
//
// v0.28 followup Boss UX round 31 (Boss 2026-08-29 OOB '你看一下, 素材
// 预览区, 动态区, 这个区的液态玻璃效果和其他区不一样'):
//
// = Single source of truth for per-pane content backgrounds (= the
// background behind the actual content of each pane, NOT the tab bar
// at the top of the pane).
//
// Previously each pane had its OWN ad-hoc background configuration:
//
//   - Preview pane: PreviewTabBackground (.ultraThinMaterial overlay)
//   - Dynamic pane: .background(.ultraThinMaterial) on outer VStack
//   - Editor pane: .background(.regularMaterial) on placeholder
//   - Other panes (sidebar, tools, chat): no explicit background (= transparent)
//
// This meant each pane's content area had a DIFFERENT visual depth (= boss
// observed in screenshot: '素材预览区, 动态区, 这个区的液态玻璃效果
// 和其他区不一样').
//
// Solution = extract a single `RegionContentBackground` view modifier
// that ALL panes use. Now they all have the same visual depth.
//
// Design contract for the single component:
// - Material: .regularMaterial (= Apple canonical Liquid Glass, standard
//   tint, matches the rest of the app's chrome).
// - Why NOT .ultraThinMaterial (= what preview/dynamic were using)?
//   - .ultraThinMaterial = lightest tint (= barely visible blur)
//   - Used to be chosen for "content-heavy" panes (= kanban / preview
//     images) to avoid strong background tint.
//   - But this breaks visual consistency (= other panes had no
//     material, so dynamic/preview looked different).
//   - Per boss OOB: unify all to standard .regularMaterial so all
//     panes look the same depth.
// - Why NOT Color.clear (= what sidebar/tools/chat were using)?
//   - Color.clear = no background (= shows underlying window's .glass
//     material which can render differently in different contexts).
//   - .regularMaterial = explicit Liquid Glass layer (= consistent
//     visual depth regardless of underlying window state).
//
// Why this works:
// - ONE component = ONE render path = ONE visual depth everywhere.
// - Future Liquid Glass tweaks apply to all panes simultaneously
//   (= boss doesn't need to "make each pane's material the same" again).
// - Matches the same single-source-of-truth pattern we used for
//   RegionTabBar + RegionStatusBar in round 30.

import SwiftUI

// MARK: - RegionContentBackground

/// Canonical per-pane content background (= the translucent material
/// behind the actual content of each pane, NOT the tab bar at the top).
///
/// **SINGLE SOURCE OF TRUTH**: Used by all per-pane content views
/// (= `PreviewTabBackground`, `DynamicZoneView` outer VStack, editor
/// placeholder, etc.). All panes now render with the same `.regularMaterial`
/// Liquid Glass depth (= boss's "看起来不一样" issue resolved).
///
/// Visual configuration:
/// - Material: `.regularMaterial` (= Apple canonical Liquid Glass,
///   standard tint, macOS 27 Tahoe).
/// - Same translucency as macOS native per-pane content backgrounds in
///   Pages / Mail / Xcode / Finder.
@MainActor
public struct RegionContentBackground: View {
    public init() {}

    public var body: some View {
        // Apply .regularMaterial to the underlying window's
        // background (= Apple's standard Liquid Glass translucency).
        // Using Color.clear.overlay(.regularMaterial) so the material
        // covers the full available space without disturbing layout.
        Color.clear
            .overlay(.regularMaterial)
    }
}

// MARK: - View extension

/// Convenience View extension: `.regionContentBackground()` applies the
/// canonical RegionContentBackground to any view (= single source of
/// truth for per-pane content backgrounds across the app).
public extension View {
    /// Apply canonical per-pane content background (= single
    /// `.regularMaterial` Liquid Glass layer).
    ///
    /// Usage: `SomeView().regionContentBackground()`
    func regionContentBackground() -> some View {
        self.background(RegionContentBackground())
    }
}