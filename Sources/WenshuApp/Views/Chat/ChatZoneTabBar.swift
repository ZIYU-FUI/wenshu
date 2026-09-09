//
//  ChatZoneTabBar.swift · Wenshu · v0.40 apple-001 phase 3 ticket 1b
//
//  Extracted from App.swift (formerly inline `struct ChatZoneTabBar`
//  at line 1455, = 170 LOC). v0.40 apple-001 phase 3 ticket 1
//  (LOW-RISK leg, = the second of two atomic slices).
//
//  v0.21 ticket 43: ChatZoneTabBar = chat-zone top-bar with 3 tabs
// for real switching (boss backlog 20). Apple HIG canonical:
//  Button(.plain) + contentShape(Rectangle()) whole-strip hot area
//  + accent selected state + Apple default animation.
//
// v0.24 bossverificationfix (boss 8/25 fourth OOB): added archive icon at
//  top-right (= 18 PT right padding). Click triggers alert. Confirm
//  archives current session + context, starts new session.
//
//  Apple HIG = one view per file. ChatZoneTabBar is the canonical
//  3-state chat-tab strip (= 1 visible tab today, .chat only,
//  filtered via ForEach with .chat only). matchedGeometryEffect
//  pattern is applied for consistency with DynamicZoneTabBar +
//  ZoneContentTabBar (= if owner later unhides .search / .settings
//  tabs, slide animation already works without retrofit).
//
//  Companion file:
//  - ChatZoneTab.swift (= the enum = module scope after ticket 1a).
//

import SwiftUI

/// v0.21 ticket 43: ChatZoneTabBar = chat zonetop bar 3 tab (backlog 20)
/// Apple HIG: Button(.plain) + contentShape(Rectangle()) (ticket 17 + 21 fix)
/// + .foregroundStyle(.accentColor) in progress + Apple default
/// v0.24 bossverificationfix (Boss 8/25 fourth OOB 'chat zonetop bar 18PT ICON'):
/// Added archive icon at top-right (18 PT right padding). Click triggers
/// alert 'yesno' (yes / cancel). Confirm archives current
/// session + context, starts new session, resets context counter.
struct ChatZoneTabBar: View {
    @Binding var selectedTab: ChatZoneTab
    // v0.24 bossverificationfix (Boss 8/25 OOB ticket 015.014): archive flow state.
    @Binding var showingArchiveAlert: Bool
    // v0.30 boss 8/31 OOB: hover state for the archive button (= passed
    // down from owner struct since SwiftUI @State can't be observed
    // across nested struct boundaries without @Binding).
    @Binding var showingArchiveAlertHover: Bool
    // v0.25.1 (= ticket 013 underline slide animation): owner 2026-08-26
    // [CJK-TRANSLATE] 1 line(s) awaiting manual translation (see git blame for original CJK text)
    // OOB 'changemove yes' =
    // matchedGeometryEffect pattern (= owner wants L/R slide, NOT
    // crossfade). Even though ChatZoneTabBar currently only shows 1
    // visible tab (= .chat, filtered via ForEach with .chat only),
    // the namespace + matchedGeometryEffect pattern is applied for
    // consistency with DynamicZoneTabBar + ZoneContentTabBar. If owner
    // later unhides .search / .settings tabs (= Boss 8/22 sixth OOB
    // ' backlog 20 chat tab 1/2/3 '), the slide animation
    // already works (= no extra retrofit).
    @Namespace private var tabBarNamespace

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                ForEach(ChatZoneTab.allCases.filter { $0 == .chat }) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        // v0.24 bossverificationfix: icon only, no title label.
                        // v0.25.1 (= ticket 021 followup Apple HIG canonical):
                        // Color.clear as BASE (= label intrinsic = 28×28 =
                        // Button hit area), chatZoneTabBarIcon Lucide .bot /
                        // .inbox as .overlay centered. Previous ticket 020
                        // had it inverted (= clipped to 18×18).
                        Color.clear
                            .frame(width: DesignTokens.paneTabHotArea, height: DesignTokens.paneTabHotArea)
                            .overlay(alignment: .center) {
                                chatZoneTabBarIcon(tab.icon)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                                    .foregroundStyle(tab == selectedTab ? Color.accentColor : Color.secondary)
                            }
                            .contentShape(Rectangle())
                            // v0.25.1 (= ticket 018 explicit 28×28 hot zone):
                            // owner 2026-08-26 OOB ' ICON yesyesok
                            // 28×28 ' = ticket
                            // 008's .padding(.all, chatTabHitPad) was still
                            // flaky (= owner reported icons hard to click).
                            // Replace with explicit Color.clear.frame(28, 28)
                            // .contentShape(.rect) = Apple HIG canonical
                            // pattern for plain-style button hot area.
                            // (v0.34 Apple-API-first #3: removed inner
                            // `.buttonStyle(IconButtonStyle())` here = it was
                            // a no-op pass-through superseded by the outer
                            // `.buttonStyle(.plain)` below.)
                            // v0.25.1 (= ticket 010 tab selected-state underline):
                            // owner 2026-08-26 OOB ' tab status ICON
                            // ' = add Apple HIG canonical
                            // selected-tab underline (= 2 PT accent bar at
                            // bottom of selected tab, full button width).
                            .overlay(alignment: .bottom) {
                                if tab == selectedTab {
                                    Rectangle()
                                        .fill(Color.accentColor)
                                        .frame(height: DesignTokens.tabUnderlineHeight)
                                        // v0.28 followup Boss UX (Boss 2026-08-30
                                        // OOB ', '): .clipShape(Capsule())
                                        // for fully rounded ends on the underline.
                                        .clipShape(Capsule())
                                        // v0.25.1 (= ticket 013): matchedGeometryEffect
                                        // namespace ID on the bar Rectangle so
                                        // SwiftUI can slide it between tab
                                        // positions (= replaces ticket 010's
                                        // per-button crossfade with single shared
                                        // bar translating L/R). When owner
                                        // unhides .search / .settings tabs (=
                                        // Boss 8/22 sixth OOB backlog 20), the
                                        // slide animation already works.
                                        .matchedGeometryEffect(id: "tabBarUnderline", in: tabBarNamespace, isSource: true)
                                    .offset(y: 0)  // v0.25.1 ticket 024: offset adjusted for tabUnderlineHeight 1 PT (= underline at y=27-28 PT, flush with toolbar bottom; 1 PT below icon bottom = 2 PT gap)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .background(Color.clear)
                }
            }
            .padding(.leading, DesignTokens.chromePaddingLeading)

            Spacer()

            // v0.24 bossverificationfix (Boss 8/25 fourth OOB ticket 015.014): archive
            // icon at top-right (= Boss image position). 18 PT right
            // padding per Boss spec. Click triggers showingArchiveAlert.
            // v0.25.1 (= ticket 005): right-side chat-zone icon = Lucide
            // .inbox (= owner 2026-08-26 OOB, replacing the prior "archivebox"
            // SF Symbol archive-flow icon). Minimal-impact same helper.
            // v0.25.1 (= ticket 007 chat-zone tab hot area):
            // owner 2026-08-26 OOB 'issue okyes ICON yes
            // need ICON 18×18 regionyes ' = inflate
            // the clickable area from 18×18 to 28×28 PT (= boss 8/11 fix3
            // 'four chat tab height set to 28 PT'). Hot zone paired with
            // .contentShape(.rect()) so the entire 28×28 PT box is the
            // click target (= not the visual glyph only).
            //
            // v0.30 boss 8/31 OOB ' ICON buttoneffect,
            // TEB ': added hover state + .onHover + .background
            // tint (= matches PaneIconTab's hover pattern = Color
            // .accentColor.opacity(0.12) on hover, clipped to rounded
            // rect).
            Button {
                showingArchiveAlert = true
            } label: {
                // v0.25.1 (= ticket 022 chat zone archive button — old
                // ICON removal): owner 2026-08-26 OOB 'chat
                // ICON delete' = previous ticket 021 patch
                // wrapped the archive button label in BOTH chatZoneTabBarIcon
                // ('inbox') AND a redundant Image(systemName: 'archivebox')
                // inside the Color.clear overlay (= 2 icons rendered at
                // the same position, the SF archivebox was the 'old
                // ICON' that boss wanted removed). Fix = use chatZoneTabBarIcon
                // ('inbox') directly as the label (= Lucide .inbox is the
                // canonical archive flow icon per ticket 005), drop the
                // duplicate SF archivebox.
                chatZoneTabBarIcon("inbox")
                    .aspectRatio(contentMode: .fit)
                    .frame(width: DesignTokens.tabIconSize, height: DesignTokens.tabIconSize)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            // v0.30 boss 8/31 OOB: hover tint for the archive button.
            // Matches PaneIconTab + sidebar zone header button pattern.
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(showingArchiveAlertHover
                        ? AnyShapeStyle(.quaternary)
                        : AnyShapeStyle(Color.clear))
            )
            .onHover { hovering in
                showingArchiveAlertHover = hovering
            }
            .help(WenshuI18n.t("auto2.chatzonetabbar.l180.h88771180"))
            .padding(.trailing, DesignTokens.chromePaddingTrailing)
        }
        .frame(maxWidth: .infinity)
        .frame(height: DesignTokens.chromeHeight)
        // v0.40 boss 2026-09-08 OOB 'sweep for remaining background colors: removed the
        // chrome tier background tint + the 1 PT .separator overlay
        // (= the 2 layers that distinguished the chat zone's top tab
        // bar from the pane content = matches the recent v0.40 chrome
        // cleanup of RegionTabBar + RegionStatusBar in Round 2 =
        // boss wants no chrome tier distinction across the app).
        // ChatZoneTabBar is now a bare 30 PT HStack with the
        // archive icon = the top tabs (dialog/search/Settings) inherit the
        // pane's content tier color.
        .animation(.default, value: selectedTab)
    }

    /// v0.25.1 (= ticket 005): Lucide-first view helper for chat-zone toolbar
    /// icons. Same fallback semantics as ZoneIcon: try `Lucide(name:)` first,
    /// fall back to `Image(systemName:)` on nil. Used by both the left tab
    /// button (ForEach filtered to .chat) and the right archive-flow button.
    @ViewBuilder
    private func chatZoneTabBarIcon(_ systemName: String) -> some View {
        // v0.27 boss 8/27 OOB: use the project-wide LucideIcon helper.
        LucideIconSystemFallback(systemName)
    }
}
