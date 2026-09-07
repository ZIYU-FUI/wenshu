//
//  ChromeStyles.swift · Wenshu · CHROME-ARCH-001 round 5
//
//  Single source of truth for the chrome (= background + bottom bar)
//  that wraps every zone's content. Boss 9/7 '搞一个样式组件的
//  文件, 用于管理控件样式, 这个文件类似 css, 这样我们以后也好管理,
//  功能与样式分离' = abstract the chrome styling into a CSS-like
//  file (= one place to manage visual tokens, no scattered
//  .padding / .frame / Color calls per zone).
//
//  Pattern (= Apple HIG + web CSS inspiration):
//  - `ChromeBottomBar` = the unified 30 PT status strip (= left
//    text + right text + optional right-click). Applied via
//    .chromeBottomBarStyle(...) ViewModifier.
//  - `ChromeZoneBackground` = the per-tier background fill (= Apple
//    HIG chrome tier / content tier distinction per v0.32 boss
//    OOB). Applied via .chromeZoneBackgroundStyle(zone:) modifier.
//
//  History (= what was removed):
//  - `ChromeTopBar` (= the 30 PT unified top bar with ZoneSlot
//    identity = icon + label) was added in CHROME-ARCH-001
//    commit 198362679, simplified in round 4 (= boss 9/7
//    '不需要标题' = removed the icon + label leaving an empty
//    30 PT strip), and REMOVED entirely in round 5 (= boss 9/7
//    '标题栏好像被空白栏加高了' = the empty 30 PT strip was visual
//    debt that wasted vertical space). The trailing actions
//    parameter (= sidebar's "+ / ↥" buttons for new shelf /
//    new book) is preserved as the `topActions` parameter on
//    ZonePerRegionChrome (= rendered inline if a caller passes
//    them; = not dead code = still functional).
//
//  Content (= the zone's actual UI = tabs, lists, forms) stays
//  in the calling zone's view (= e.g. NewLibraryOutlineView for
//  sidebar, ZoneContentView for editor's tab bar). This file owns
//  ONLY the chrome (= the visual container around content).
//
//  Usage (= inside ZonePerRegionChrome.body):
//      content()
//          .chromeZoneBackgroundStyle(zone: zone)
//      chromeBottomBarStyle(left: ..., right: ...)
//

import SwiftUI
import Lucide

// MARK: - Bottom bar

/// CHROME-ARCH-001 (2026-09-07): the unified parent bottom bar =
/// 30 PT, = status text (left + right) + optional right-click
/// handler. Wraps the existing PaneStatusBar (= re-exported for
/// API consistency with chromeTopBarStyle).
///
/// Apple HIG alignment: matches FCP's per-pane status bar pattern.
/// Token usage (= iron-rule 6):
/// - height = kZoneToolbarHeight (= 30 PT canonical)
/// - background = Color(nsColor: .controlBackgroundColor)
/// - bottom 1 PT separator (= matches top bar)
struct ChromeBottomBar: View {
    let left: String
    let right: String
    let rightOnTap: (@Sendable () -> Void)?

    var body: some View {
        PaneStatusBar(
            leftText: left,
            rightText: right,
            rightOnTap: rightOnTap
        )
    }
}

extension View {
    /// CHROME-ARCH-001 (2026-09-07): render the chrome bottom bar
    /// below this view (= status text + right-click). Pass empty
    /// strings for no text (= zone has no status).
    func chromeBottomBarStyle(
        left: String = "",
        right: String = "",
        rightOnTap: (@Sendable () -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            self
            ChromeBottomBar(left: left, right: right, rightOnTap: rightOnTap)
        }
    }
}

// MARK: - Zone background

/// CHROME-ARCH-001 (2026-09-07): per-zone background (= chrome tier
/// vs content tier per v0.32 boss OOB). Wraps the existing
/// RegionContentBackground (= re-exported for API consistency).
///
/// Apple HIG alignment: per-pane background that distinguishes
/// the chrome tier (= top/bottom bars = controlBackgroundColor) from
/// the content tier (= windowBackgroundColor = one tier darker in
/// dark mode = matches FCP viewer depth).
struct ChromeZoneBackground: View {
    let zone: ZoneSlot?

    var body: some View {
        if let zone = zone {
            return AnyView(RegionContentBackground(zone: zone))
        } else {
            // Legacy callers / previews: chrome tier fallback
            // (= matches the original RegionContentBackground()
            // default = controlBackgroundColor per v0.32 boss OOB).
            return AnyView(
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }
}

extension View {
    /// CHROME-ARCH-001 (2026-09-07): apply the per-zone chrome tier
    /// background fill. Use this on the content (= between the top
    /// and bottom chrome bars).
    func chromeZoneBackgroundStyle(zone: ZoneSlot?) -> some View {
        if let zone = zone {
            return self.background(ChromeZoneBackground(zone: zone))
        } else {
            return self.background(ChromeZoneBackground(zone: nil))
        }
    }
}
