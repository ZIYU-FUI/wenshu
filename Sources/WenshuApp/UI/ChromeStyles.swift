//
//  ChromeStyles.swift · Wenshu · CHROME-ARCH-001
//
//  Single source of truth for the chrome (= background + top bar +
//  bottom bar) that wraps every zone's content. Boss 9/7 '搞一个
//  样式组件的文件, 用于管理控件样式, 这个文件类似 css, 这样我们以后
//  也好管理, 功能与样式分离' = abstract the chrome styling into a
//  CSS-like file (= one place to manage visual tokens, no
//  scattered .padding / .frame / Color calls per zone).
//
//  Pattern (= Apple HIG + web CSS inspiration):
//  - `ChromeTopBar` = the unified 30 PT top strip (= icon + zone
//    label + optional trailing actions). Applied via
//    .chromeTopBarStyle(zone:) ViewModifier on a HStack.
//  - `ChromeBottomBar` = the unified 30 PT status strip (=
//    left text + right text + optional right-click). Applied via
//    .chromeBottomBarStyle(...) ViewModifier.
//  - `ChromeZoneBackground` = the per-tier background fill (= Apple
//    HIG chrome tier / content tier distinction per v0.32 boss
//    OOB). Applied via .chromeZoneBackgroundStyle(zone:) modifier.
//
//  Content (= the zone's actual UI = tabs, lists, forms) stays
//  in the calling zone's view (= e.g. NewLibraryOutlineView for
//  sidebar, ZoneContentView for editor's tab bar). This file owns
//  ONLY the chrome (= the visual container around content).
//
//  Usage (= inside ZonePerRegionChrome.body):
//      content()
//          .chromeZoneBackgroundStyle(zone: zone)
//      chromeTopBarStyle(zone: zone) { /* optional trailing actions */ }
//      chromeBottomBarStyle(left: ..., right: ...)
//

import SwiftUI
import Lucide

// MARK: - Top bar (= boss 9/7 CHROME-ARCH-001, simplified round 4)

/// CHROME-ARCH-001 (2026-09-07): the unified parent top bar =
/// 30 PT, = single source of truth for the chrome-level CONTAINER
/// across all 6 zones.
///
/// Boss 9/7 round 4 '不需要标题告诉用户每个区是什么, 因为我们的
/// 功能足够让用户知道每个区功能' = REMOVED the ZoneSlot identity
/// (= icon + label) that I added in the previous round. The
/// chrome top bar is a pure visual container (= 30 PT
/// control-background strip with no title text). Zone identity is
/// already conveyed by:
/// 1. the zone's CONTENT itself (= the user sees what the zone
///    does; = sidebar has tree, editor has markdown, chat has
///    messages, etc.).
/// 2. the zone's 2nd-layer tab strip (= e.g. sidebar's single
///    "书架" item, editor's "📝 大纲 🔗 反链" tabs, etc.).
/// 3. boss 8/12 OOB '我不懂写代码, 你决定' = the user's domain
///    knowledge (= wenshu 6-zone layout has been the same since
///    v0.10 = the user knows which zone is which).
///
/// Repeating the zone name in the chrome top bar was a redundancy
/// (= ponytail rule 7 = '不要重复造轮子' = don't repeat information
/// the user already has). Removed the leading icon + label.
/// Trailing actions (= topActions) stay (= e.g. sidebar's "+ / ↥"
/// for new shelf / new book) = these are FUNCTIONAL actions,
/// not identity, and are not redundant with anything else.
///
/// Apple HIG alignment: this is now an empty header bar (= Apple's
/// standard pattern for window chrome that needs visual padding
/// above content without identity disclosure). We use a plain
/// HStack (= simpler than .toolbar { ... } which requires
/// NavigationStack wrapping and complicates the chrome tier
/// semantic).
///
/// Token usage (= iron-rule 6 = no magic numbers):
/// - height = kZoneToolbarHeight (= 30 PT canonical = matches
///   the chrome tier across the workspace)
/// - horizontal padding = DesignTokens.chromePaddingLeading
///   (= 18 PT = Apple HIG canonical)
struct ChromeTopBar: View {
    /// Optional trailing actions (= per-zone overrides; = e.g.
    /// sidebar's "+ / ↥" buttons for new shelf / new book).
    /// These are FUNCTIONAL actions, not identity (= the boss 9/7
    /// round 4 removal was about the leading identity icon + label,
    /// not about these trailing actions).
    var trailingActions: [ZoneTopAction] = []

    var body: some View {
        HStack(spacing: DesignTokens.chromePaddingSmall) {
            // Leading: intentionally empty (= boss 9/7 round 4
            // '不需要标题'; = zone identity comes from the content
            // itself + 2nd-layer tab strip, not from a duplicated
            // chrome-level label).
            Spacer(minLength: 0)
            // Trailing: optional per-zone actions (= functional,
            // not identity = not redundant with anything else).
            ForEach(trailingActions) { action in
                Button {
                    action.onSelect?()
                } label: {
                    Lucide(action.icon)
                        .frame(width: DesignTokens.iconSmall, height: DesignTokens.iconSmall)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(action.label)
            }
        }
        .padding(.horizontal, DesignTokens.chromePaddingLeading)
        .frame(maxWidth: .infinity)
        .frame(height: kZoneToolbarHeight)
        // Chrome tier background (= Apple HIG "large controls" tier =
        // .controlBackgroundColor; = matches v0.32 boss OOB tier
        // decision for sidebar / tools / editor).
        .background(Color(nsColor: .controlBackgroundColor))
        // Bottom 1 PT separator (= matches old ZoneTopToolbar style;
        // = visual divider between chrome tier and content tier).
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
        }
    }
}

/// View modifier that applies ChromeTopBar above the modified
/// content. Use this inside ZonePerRegionChrome (= or any wrapper
/// that wants the unified chrome top bar).
extension View {
    /// CHROME-ARCH-001 (2026-09-07): render the chrome top bar
    /// (= ChromeTopBar) above this view (= same VStack slot as the
    /// zone content). Pass trailing actions for per-zone buttons
    /// (= e.g. sidebar's "+ / ↥" actions); leave empty for zones
    /// with no trailing actions.
    func chromeTopBarStyle(
        trailingActions: [ZoneTopAction] = []
    ) -> some View {
        VStack(spacing: 0) {
            ChromeTopBar(trailingActions: trailingActions)
            self
        }
    }
}

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
