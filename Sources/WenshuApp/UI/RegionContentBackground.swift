// Sources/WenshuApp/UI/RegionContentBackground.swift
//
// v0.28 followup Boss UX round 31-32 (Boss 2026-08-29 OOB '素材预览区,
// 动态区, 那种透明的程度, 和其他区域不一样, 我说的是背景, 你仔细
// 对比一下'):
//
// = Single source of truth for per-pane content backgrounds (= the
// background behind the actual content of each pane, NOT the tab bar
// at the top of the pane).
//
// Initially (round 31) tried to use `.regularMaterial` (= a layered
// material that adds blur to whatever is behind it). But this is
// OPAQUE-ISH — it BLOCKS the underlying window's `.glass` material
// from showing through. Sidebar / Tools / Chat panes have NO
// explicit background (= transparent), so they SHOW the window's
// `.glass` (= truly see-through to the desktop wallpaper).
//
// Round 32 fix: changed RegionContentBackground to `.glass` (= Apple's
// window-level glass material that matches what the window's
// containerBackground uses in App.swift). This way ALL panes have
// the SAME visual depth (= the window's `.glass` material shows
// through everywhere).
//
// Why `.glass` (= SwiftUICore.Glass.regular):
// - Matches the WindowGroup's `.containerBackground(for: .window)
//   { Rectangle.glassEffect(.regular) }` (= exact same material =
//   visually identical when stacked).
// - Renders the same regardless of where it's applied (= single
//   source of truth = identical visual depth across all panes).
// - Apple HIG canonical per-pane content background style on macOS
//   27 Tahoe (= Pages, Mail, Xcode all use this pattern).
//
// Why NOT `.regularMaterial` (= what round 31 used):
// - `.regularMaterial` is a DIFFERENT material from `.glass`
//   (= layered material vs. window material).
// - Renders as semi-opaque blur (= blocks the window's .glass).
// - Sidebar / Tools / Chat have NO background, so they showed
//   window's `.glass` (= more transparent than the panes that had
//   `.regularMaterial`).
// - Boss's observation in round 32: 'preview pane + dynamic pane look
//   less transparent than other panes' — this was because of
//   `.regularMaterial` blocking the window's glass.
//
// Solution = change RegionContentBackground to `.glass` (= window-
// level material = identical visual depth everywhere).

import SwiftUI

// MARK: - RegionContentBackground

/// Canonical per-pane content background (= the translucent material
/// behind the actual content of each pane, NOT the tab bar at the top).
///
/// **SINGLE SOURCE OF TRUTH**: Used by all per-pane content views
/// (= `PreviewTabBackground`, `DynamicZoneView` outer VStack, editor
/// placeholder, etc.). All panes now render with the same `.glass`
/// window-level material (= matches the Wenshu window's own
/// `.containerBackground(.glass)` so every pane shows the same
/// see-through desktop wallpaper).
///
/// Visual configuration:
/// - Material: `.glass` (= Apple SwiftUICore.Glass.regular, the same
///   canonical Liquid Glass used by the window's containerBackground).
/// - Truly transparent (= desktop wallpaper shows through, same as
///   Sidebar / Tools / Chat panes which have no explicit background).
@MainActor
public struct RegionContentBackground: View {
    public init() {}

    public var body: some View {
        // v0.28 followup Boss UX round 47 (Boss 2026-08-29 OOB
        // '项目管理区总是很特别, 项目管理区和素材预览区中间的分隔线
        // 和其他区域都不同' = the .regularMaterial / .thickMaterial
        // overlays were covering the divider lines between panes.
        // Tried lowering to .regularMaterial (= round 47) = still
        // covered the divider.
        //
        // Round 48 (this commit): REMOVED the material overlay entirely.
        // The pane background is now plain Color.clear (= truly
        // transparent). Pane visibility comes from the window-level
        // .glass containerBackground (= set in App.swift round 41) +
        // the 1 PT .separator at the bottom of RegionTabBar/RegionStatusBar
        // (= pane boundaries visible via the tab/status bars' separators).
        // Divider lines between panes (rendered by NativeSplitter at
        // 1 PT Apple .separator ShapeStyle) are now FULLY visible
        // from top to bottom (= no material covering them).
        Color.clear
    }
}

// MARK: - View extension

/// Convenience View extension: `.regionContentBackground()` applies the
/// canonical RegionContentBackground to any view (= single source of
/// truth for per-pane content backgrounds across the app).
public extension View {
    /// Apply canonical per-pane content background (= single
    /// `.glass` window-level Liquid Glass layer).
    ///
    /// Usage: `SomeView().regionContentBackground()`
    func regionContentBackground() -> some View {
        self.background(RegionContentBackground())
    }
}