// Sources/WenshuApp/Editor/EditorTabStrip.swift
//
// Safari-style multi-tab strip for the editor zone. Self-written
// in SwiftUI (= Apple has no 1:1 equivalent for Safari modern
// pill tab; = Safari's tab strip is private to Safari.app). This
// component replaces the ad-hoc HStack in EditorView.swift:140-171
// (= previously showed only the active tab; = no drag reorder /
// close X / overflow scroll / visible inactive tabs).
//
// Scope (= per boss OOB 2026-10-10): editor zone ONLY. The 9
// single-instance Window(id:) panels (= kanban / todo / canvas /
// composer / ...) and the main WindowGroup are not touched.
//
// Design references:
//   - Sources/WenshuApp/UI/PaneTabBar.swift (= the existing
//     Apple HIG per-pane icon tab bar = 28 PT hot area, SF Symbols 6,
//     matchedGeometryEffect selected-state underline). This component
//     extends the same patterns into a per-document tab bar (= title
//     label + close X + overflow scroll + drag reorder).
//   - Apple's Safari.app (= the visual reference: round-pill
//     inactive tabs, accent-tinted active tab with bottom
//     border, small × close button on hover, horizontal scroll
//     when tabs overflow).
//
// API shape: the SwiftUI View exposes 3 state-binding callbacks
// (= onSelect / onClose / onReorder). EditorView stays in charge
// of AppState (= openTabs + activeTabId) so the strip stays a
// pure render surface (= zero internal state mutation outside
// SwiftUI diffing).

import SwiftUI

/// Safari-style multi-tab strip for the editor zone.
@MainActor
struct EditorTabStrip: View {

    /// The tabs to render, in display order (= `openTabs` array order in
    /// AppState). Drag-reorder reorders this view's internal display, then
    /// surfaces the new order back to the caller via `onReorder`.
    let tabs: [EditorTab]

    /// Currently active tab id (= drives the accent-tinted + bottom- border
    /// render on the matching tab). Nil = no tab selected (= the caller should
    /// hide the entire strip in that case).
    let selectedTabId: UUID?

    /// Fired when the user picks a different tab. Caller writes this back to
    /// `AppState.activeTabId`.
    let onSelect: (UUID) -> Void

    /// Fired when the user clicks the close X. Caller routes through
    /// `AppState.closeTab(id:bookStore:)` (= which handles dirty-flush +
    /// confirmation alert in one place).
    let onClose: (UUID) -> Void

    /// Fired after the user drag-reorders tabs. The argument is the new tab id
    /// order (= the caller's job to rewrite `AppState.openTabs` to match and
    /// re-persist).
    let onReorder: ([UUID]) -> Void

    /// SwiftUI namespace for the matchedGeometryEffect underline (= Apple's HIG
    /// convention for the slide animation between tab selected states; = same
    /// pattern as PaneTabBar).
    @Namespace private var tabBarNamespace

    /// Tab id currently being dragged (= E2E drag-reorder source of truth
    /// during the gesture lifetime). = nil on idle.
    @State private var draggingTabId: UUID?

    /// Tab id currently the drop target (= E2E drag-reorder destination
    /// highlight). = nil on idle.
    @State private var dropTargetTabId: UUID?

    /// Tab ids in display order (= tracked separately from `tabs` parameter for
    /// two reasons: (1) drag-reorder mutates the local order before the caller
    /// persists it; (2) SwiftUI ForEach uses this id list for stable identity
    /// across re-renders). Initialized from `tabs` on each render.
    @State private var displayOrder: [UUID] = []

    /// Last seen `tabs` array (= detects when the caller added / removed tabs
    /// externally so we can prune displayOrder).
    @State private var lastSeenTabIds: [UUID] = []
    /// live column width (= the editor column's current width; = updated by
    /// `.onGeometryChange` on the outer `.frame(maxWidth: .infinity, alignment:
    /// .leading)`; = drives the three-stage algorithm's threshold =
    /// `columnWidth / minSegmentWidth` = the max N that fits at
    /// `minSegmentWidth` PT each). When the column width is 0 (= before the
    /// first `.onGeometryChange` fires; = the initial value; = typical at app
    /// launch before layout settles), the algorithm uses `displayOrder.count >
    /// 10` (= a safe default that matches the previous fixed-threshold
    /// behavior).
    @State private var columnWidth: CGFloat = 0

    var body: some View {
        // RATIONALE: per Apple HIG SwiftUI macOS 27 + the Safari
        // modern macOS tab-strip reference, the strip is ALWAYS visible
        // at the top of the editor zone (= even at zero open tabs).
        // The empty-state shape is a single "+ new tab" affordance
        // (= Apple's tab-strip empty-state convention; = Pages /
        // Numbers / Xcode all show a + button in the same position
        // when their document list is empty). Hiding the strip on
        // tabs.isEmpty was the round-21 G2 verdict (= the editor
        // zone's empty-state hint was supposed to fill the body);
        // the round-24 visual audit showed that hides the strip
        // chrome itself (= the user can't tell the multi-tab
        // feature exists; = the + hint is what tells them). The
        // trade-off = the empty-state hint no longer fills the full
        // body; = the + button + the hint coexist in the strip
        // (= both visible simultaneously; = no visual confusion).
        //
        // ASSUMPTION: the caller places this strip at the top of the
        // editor zone's outer VStack (= canonical Pages-style
        // toolbar-above-content placement). If a future caller
        // embeds the strip elsewhere (= e.g. inline with the
        // format toolbar), the + button hint's position semantics
        // shift; = the caller's responsibility, not this view's.
        stripContent
    }

    /// The actual tab strip (= ScrollView of tabs + empty-state + button).
    /// Extracted from `body` so the always-visible policy (= see body
    /// RATIONALE) is centralized in `body` and the shape variation lives here.
    /// The frame height stays at `paneTabHotArea + tabUnderlineHeight` (= 29
    /// PT) regardless of how many tabs the caller passes (= the strip's visual
    /// height is constant; = the + button lives in the same row as the real
    /// tabs would).
    @ViewBuilder
    private var stripContent: some View {
        // RATIONALE: the strip body is a VStack (= tab-pill
        // `HStack` on top + 1 PT `Divider()` below; = the
        // hairline is part of the same group as the tab pills;
        // = the modern Safari tab-strip pattern where the tab
        // row and the bottom hairline are visually fused). The
        // outer `VStack(spacing: 0)` has zero inter-row
        // spacing (= the `Divider()` is glued to the tab-pill
        // row's bottom; = the hairline visually occupies the
        // strip's bottom 1 PT).
        VStack(spacing: 0) {
            // Sync displayOrder with the caller's `tabs` parameter.
            // RATIONALE: `displayOrder` is a separate @State (= the
            // drag-reorder feature mutates it independently of `tabs`;
            // = the source-of-truth for display order is `displayOrder`,
            // not `tabs`). On each body evaluation we re-derive
            // `displayOrder` from the incoming `tabs` array IF the
            // incoming id list differs from the last-seen list (= no
            // sync when the user just drag-reordered; = the order is
            // already correct). The sync is a side effect on @State; =
            // wrapped in `.onChange(of:)` (= Apple HIG SwiftUI canonical
            // pattern for "react to a prop changing"; = the @ViewBuilder
            // body still returns a single ScrollView; = the sync fires
            // only when `tabs` actually changes, not on every body
            // re-evaluation).
            // RATIONALE: the tab strip
            // splits the strip width evenly
            // across all tabs (= the wenshu
            // 1:1 macOS Safari tab bar
            // canonical; = 1 tab fills the
            // strip; = 2 tabs each get 50%;
            // = 8 tabs each get 12.5%;
            // = the title is centered inside
            // the equal-width slot; = long
            // titles truncate in the middle).
            // The wenshu 1:1 implementation
            // uses `EqualWidthLayout` (= the
            // Apple canonical `Layout`
            // protocol; = WWDC22-10056; =
            // `sizeThatFits` + `placeSubviews`
            // respond to NSV drag live).
            // The previous `GeometryReader`
            // approach did NOT respond to
            // NSV drag live (= it captured
            // the size at the parent's
            // `sizeThatFits` pass only).
            // The previous
            // `containerRelativeFrame(.horizontal,
            // count: tabs.count, ...)` attempt
            // (= Apple SwiftUI canonical
            // iOS 17 / macOS 14 API for
            // responsive column-width layouts)
            // caused a window-vanish regression
            // (= `containerRelativeFrame`
            // interacts with the editor's
            // `NavigationSplitView` in a way
            // that pulls the NSWindow off-screen;
            // = the wenshu 1:1 fix is the
            // custom `Layout` protocol; =
            // Layout is the Apple-canonical
            // escape hatch when
            // `containerRelativeFrame` is
            // unsafe in nested `NavigationSplitView`).
            // The trailing `+ new tab` button
            // takes a fixed trailing slot
            // (= does NOT participate in
            // the equal-width split; = the
            // tab strip stays visually
            // balanced; = the + button is
            // the wenshu canonical "always-
            // available new tab" affordance;
            // = matches Safari's own "+"
            // button on the right edge of
            // the tab strip).
            // = this is the same class of bug as the
            // round-22 `b5cf962d1` regression that left
            // the window at `{{232, -2137}, {1456, 3187}}`;
            // = the `containerRelativeFrame` is reverted
            // here pending a deeper investigation by a
            // future ticket; = the
            // `EqualWidthLayout` approach is
            // the wenshu 1:1 implementation
            // for the Safari-style equal-width
            // tabs (= the drag-resize
            // responsiveness during an NSV
            // drag is live; = the tabs
            // re-split via `sizeThatFits`).
            // The `GeometryReader` fallback
            // was NOT as smooth (= the tabs
            // did not re-split live during a
            // drag) but the window stayed
            // on-screen, which is the harder
            // constraint to meet (= NSV
            // `containerRelativeFrame` pulls
            // the NSWindow off-screen; = the
            // custom `Layout` is the
            // Apple-canonical escape hatch).
            // RATIONALE: the canonical
            // solution for the tab-width
            // problem (= drag-resize
            // responsive equal-width tabs
            // inside an NSV detail column)
            // is the `Layout` protocol per
            // "Compose custom layouts with SwiftUI"
            // and developer.apple.com
            // "Composing custom layouts with
            // SwiftUI" is the `Layout`
            // protocol (= `sizeThatFits` +
            // `placeSubviews`). The `Layout`
            // protocol exposes the live parent
            // size as `proposal.width` and
            // `bounds.width` (= the live
            // update propagates from NSV →
            // layout pass → `sizeThatFits` /
            // `placeSubviews` → tabs re-split;
            // = the user can drag the
            // `NavigationSplitView` column
            // divider and the tabs re-split
            // live). The `EqualWidthLayout`
            // (= the wenshu 1:1 Safari-style
            // equal-width tab strip layout)
            // is defined in
            // `Sources/WenshuApp/UI/Layout/EqualWidthLayout.swift`;
            // = it places N subviews with
            // equal `cellWidth = (parentWidth
            // - totalSpacing) / N`. Compared
            // to `containerRelativeFrame` (=
            // the iOS 17+ / macOS 14+ Apple
            // canonical alternative), the
            // `Layout` protocol is the
            // pre-iOS-17 / pre-macOS-14
            // compatible primitive (= works
            // on macOS 13+; = no
            // `containerRelativeFrame`-induced
            // NSV drag-stall regressions; = the
            // wenshu minimum target is macOS 14,
            // but the `Layout` protocol
            // doesn't have the same
            // drag-stall behavior that broke the
            // previous round's window-vanish bug).
            // RATIONALE: the `+ new tab`
            // affordance is removed (= the
            // `newTabButton` private view
            // definition is gone; = the two
            // call sites here are also removed;
            // = the layout only renders the
            // actual tab pills). The empty
            // state now renders a single empty
            // `Color.clear` (so the
            // `EqualWidthLayout` still has a
            // single subview to lay out when
            // `tabs.isEmpty`; = the strip is
            // visually empty; = a future ticket
            // can place a document-open
            // affordance here if needed; = for
            // now the strip is silent).
            // RATIONALE: the tab strip uses
            // `LabelSegmentedControl` (= a
            // SwiftUI `NSViewRepresentable`
            // wrapping macOS 27's native
            // `NSSegmentedControl`; = the
            // underlying `NSSegmentedControl`
            // is configured with
            // `segmentDistribution = .fillEqually`
            // AND `trackingMode = .selectOne`;
            // = the segmented control auto-fills
            // its parent width AND auto-divides
            // that width equally across all
            // segments; = the user gets the
            // intended visual with zero
            // wenshu-invented layout code).
            // generic over `Selection: Hashable`; =
            // we pass `UUID` (= the tab id) so the
            // binding can be wired to the existing
            // `selectedTabId` state. The labels are
            // the tab titles (= `EditorTab.displayTitle`
            // for each tab; = same as the previous
            // round's `Text(EditorTab.displayTitle(tab))`).
            // RATIONALE: double-click on a
            // segment closes the tab (= the
            // wenshu 1:1 macOS Finder / Safari
            // canonical double-click-close-tab
            // behavior; = the
            // `LabelSegmentedControl` is wired
            // with an `NSClickGestureRecognizer`
            // that fires `onDoubleClickSegment`).
            // The callback here translates the
            // segment index back to the tab id
            // (= via `displayOrder[i]`) and calls
            // `onClose` (= the existing close
            // handler; = the wenshu 1:1
            // canonical "double-click a tab to
            // close it" behavior; = the
            // behavior the user expects
            // because macOS Finder / Safari /
            // Terminal all use the same
            // idiom for tabs).
            // 2026-10-14 v3: extract the
            // LabelSegmentedControl as a
            // `let control` so the outer
            // if/else can switch between
            // the plain control and the
            // ScrollView-wrapped control
            // (the boss's "加横向滚动" +
            // "正常还是全宽，然后每打开
            // 文档就分割宽度。然后等
            // 到文档过多，不能再分割
            // 的时候，就触发滚动"
            // requirements). The decision
            // is based on
            // `displayOrder.count`
            // (= 11+ tabs trigger the
            // horizontal scroll; = 1-10
            // tabs use the plain
            // .fillEqually control
            // without a ScrollView
            // wrapper = no "飘"
            // symptom = the NSSegmentedControl
            // is laid out in a single
            // pass by its parent
            // VStack).
            let control = LabelSegmentedControl(
                selection: Binding(
                    get: { selectedTabId ?? UUID() },
                    set: { newId in onSelect(newId) }
                ),
                labels: displayOrder.compactMap { tabId in
                    tabs.first(where: { $0.id == tabId })
                        .map { $0.id }
                },
                displayStrings: displayOrder.compactMap { tabId in
                    tabs.first(where: { $0.id == tabId }).map {
                        EditorTab.displayTitle($0)
                    }
                },
                iconStyle: .paneTab,
                onDoubleClickSegment: { segmentIndex in
                    guard segmentIndex >= 0 && segmentIndex < displayOrder.count else { return }
                    onClose(displayOrder[segmentIndex])
                },
                // 
                // `fixedSegmentWidth = 0`
                // (= the
                // NSSegmentedControl
                // uses
                // `.fit` to
                // auto-size
                // each
                // segment
                // to its
                // label; =
                // the total
                // intrinsic
                // content
                // size is
                // bounded
                // and does
                // NOT
                // inflate
                // the
                // parent
                // column).
                fixedSegmentWidth: 0
            )
            // 2026-10-14 v3: wrap the
            // `control` in a horizontal
            // `ScrollView` (= the boss's
            // "加横向滚动" requirement)
            // when N > 10 (= the
            // overflow threshold). The
            // `ScrollViewReader` auto-
            // scrolls to the last tab
            // when a new tab is added
            // (= the boss's "新开文档
            // 的时候, 能否自动滚动
            // 显示最后一个分段"
            // requirement). The
            // `onChange(of: displayOrder.count)`
            // (= an Int = reliably
            // observed) fires every
            // time a new tab is added
            // (= the count changes by 1).
            // drop the
            //
            // wrap (= the boss
            // 2026-10-14 "tab
            // 现在位置很飘"
            // symptom; = the
            // `ScrollView`
            // introduces a
            // multi-pass
            // layout cycle
            // for the inner
            // `NSViewRepresentable`
            // `NSSegmentedControl`;
            // = the
            // NSSegmentedControl
            // is laid out
            // in a single
            // SwiftUI pass
            // with the
            // outer
            // `.frame(maxWidth: .infinity,
            // alignment: .leading)`
            // proposal;
            // = no position
            // jump = no
            // "飘" symptom).
            // The trade-off
            // (= the boss
            // already signed
            // off on this in
            // the
            // `NSSegmentedControl`
            // with
            // `.fillEqually`
            // + parent
            // `.frame(maxWidth: .infinity)`
            // grows the
            // window to fit
            // all segments
            // when N is
            // large; = the
            // boss accepted
            // that trade-off
            // before; = no
            // horizontal
            // scroll (= the
            // previous
            // 
            // 滚动" feature
            // is dropped in
            // favor of
            // layout
            // stability).
            // The horizontal
            // `ScrollView`
            // was always
            // the source of
            // the position
            // jump (= the
            // inner NSView
            // was re-laid-out
            // on every
            // SwiftUI body
            // re-evaluation);
            // = dropping it
            // restores the
            // 
            // layout.
            control
            // RATIONALE: the tab strip's
            // top padding is 10 PT
            // (= `spacingHero - 10`; = the
            // previous value was 16 PT;
            // = the user's "-6" directive
            // (= 20 - 2 - 2 - 6 = 10 PT)
            // brings the segmented
            // control up to the 10 PT
            // wenshu canonical relaxed
            // top inset).
            .padding(.top, DesignTokens.spacingHero - 10)
            .padding(.bottom, 0)
            // RATIONALE: the manual
            // `Divider()` below the tab
            // pills is removed (= the
            // `NavigationSplitView` detail
            // column already provides its
            // own column divider; = the
            // wenshu 1:1 Pages / Numbers
            // tab strip without an extra
            // hairline).
            // tab strip sits inside the editor
            // column; = the NSV-supplied column
            // divider IS the tab strip's right
            // boundary). The hand-written
            // `Divider()` was redundant; = its
            // removal cleans up the visual
            // hierarchy (= the tab strip is one
            // band of chrome, not two with a hairline
            // between them; = the format toolbar
            // below the tab strip also has its own
            // hand-written `Divider()` for the
            // boundary between the toolbar and the
            // NSTextView; = removing the tab
            // strip's `Divider()` is symmetric with
            // the format toolbar's `Divider()` = the
            // two bands both rely on a single
            // bottom hairline, not two stacked
            // hairlines).
        }
        // RATIONALE: the tab pills
        // auto-compute their width from
        // the editor column's live width
        // (= the outer VStack gets
        // `.frame(maxWidth: .infinity, alignment: .leading)`;
        // = the inner content receives
        // the VStack's width = the live
        // editor column width). The
        // `EqualWidthLayout` then divides
        // the available width across N
        // tabs (= `cellWidth = (parentWidth
        // - totalSpacing) / N`; = the tabs
        // stay equal-width inside the live
        // editor
        // column). Without this outer
        // `.frame(maxWidth: .infinity)`, the VStack
        // would shrink to its content size (= the
        // largest child) and the `GeometryReader`
        // would not see the editor column's full
        // width (= the previous round's 90 PT
        // measurement, before the
        // `.frame(maxWidth: .infinity)` was added on
        // the GeometryReader itself). The
        // `.alignment: .leading` keeps the tab pills
        // left-anchored (= the trailing "+ new tab"
        // button does NOT push the active tab to the
        // right).
        .frame(maxWidth: .infinity, alignment: .leading)
        // capture
        // the live column
        // width via
        // `.onGeometryChange`
        // (= the Apple
        // HIG 1:1 macOS 15+
        // SwiftUI
        // replacement for
        // `GeometryReader`;
        // = the action only
        // fires when the
        // observed value
        // changes; = no
        // 0-width first
        // layout pass; = no
        // "飘" symptom; = the
        // inner
        // `NSSegmentedControl`
        // is laid out in a
        // single SwiftUI
        // layout pass with
        // the correct
        // column width).
        // The captured
        // `columnWidth` is
        // read in the
        // `Group { if useScroll ... }`
        // block above
        // (= the
        // `useScroll`
        // decision uses
        // `columnWidth`).
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            columnWidth = newWidth
        }
        // RATIONALE: the strip background is `Color.clear` (= a
        // transparent SwiftUI background; = the NSWindow
        // background shows through the strip; = the tab pills
        // float over the underlying editor surface without a
        // chrome band beneath). The previous
        // `.background(.regularMaterial)` (= macOS 27 Liquid
        // Glass blurred material; = the visual that was
        // intended to mimic Safari's tab-strip material) is
        // dropped per boss visual diff 2026-10-13 (= the user
        // wants the tab pills to sit on a transparent surface;
        // = the wenshu 6-zone dark background is the visual
        // anchor, not the Liquid Glass material).
        .background(Color.clear)
        // RATIONALE: the strip's frame height = `paneTabHotArea`
        // (= 28 PT = the Apple HIG canonical toolbar hot area; =
        // same height as `PaneTabBar` + `EditorFormatToolbar` +
        // `EditorHeaderView`). The previous round added
        // `+ tabUnderlineHeight` (= 1 PT) to reserve space
        // for a bottom `Divider()`; = the boss asked to
        // remove the divider; = the frame height is back
        // to 28 PT (= the segmented control's own
        // content inset is the source of the 8 PT visual
        // gap below the control; = the strip frame is
        // tight around the segmented control + 8 PT
        // Apple-canonical inset).
        .frame(height: DesignTokens.paneTabHotArea)
        // RATIONALE: boss visual diff 2026-10-13 — add 2 PT
        // outer top spacing to the tab-strip (= the column
        // edge above the tab pills is now 2 PT lower; = the
        // tab strip breathes slightly more before the NSWindow
        // toolbar; = matches the visual diff the boss asked
        // for). The 2 PT value is supplied by
        // `DesignTokens.spacingCaption` (= the canonical wenshu
        // 2 PT caption spacing token; = the same token used by
        // every other wenshu chrome band for the 2 PT caption
        // rhythm; = per `wenshu-comment-policy` 5-forbidden
        // "no magic numbers" rule, raw `2` is replaced with
        // the named token).
        .padding(.top, DesignTokens.spacingCaption)
        .onChange(of: tabs.map(\.id), initial: true) { _, incomingIds in
            // Sync is a no-op if the id list already matches the
            // last-seen list (= drag-reorder left the array equal;
            // = `displayOrder` is already correct; = don't undo the
            // user's drag). If the user adds a new tab externally,
            // `incomingIds` contains a new id (= append to
            // `displayOrder` at the caller's position). If the
            // caller removed a tab (= an id is in `displayOrder` but
            // not in `incomingIds`), drop it.
            // `initial: true` (= Apple HIG SwiftUI macOS 14+
            // canonical) fires the closure once at first mount; =
            // the initial `displayOrder` (= []) gets populated
            // from the caller's `tabs` argument on first render; =
            // the strip renders the existing tabs immediately (=
            // without the initial empty-array glitch).
            if incomingIds != lastSeenTabIds {
                var newOrder: [UUID] = []
                for id in incomingIds {
                    if let existing = displayOrder.first(where: { $0 == id }) {
                        newOrder.append(existing)
                    } else {
                        newOrder.append(id)
                    }
                }
                displayOrder = newOrder
                lastSeenTabIds = incomingIds
            }
        }
    }

    /// Render a single tab (= title label + close X). RATIONALE: the close X is
    /// hidden by default and only appears when the user hovers the tab (= the
    /// wenshu 1:1 macOS Safari / Finder / Mail hover-only close X affordance).
    /// The state `@State private var isHovered: Bool` is scoped to the per-tab
    /// view (= each tab has its own hover state; = hovering one tab does NOT
    /// light up the X on the neighboring tab). The X is conditionally rendered:
    /// when `isHovered == false` the X slot is a transparent `Color.clear` with
    /// the same `tabCloseFrameSize` hit area (= the tab's HStack width stays
    /// constant regardless of hover state; = the X appearing on hover does NOT
    /// shift the tab title left/right; = the user sees a stable tab strip
    /// rhythm). When `isHovered == true` the X is the wenshu `Button` +
    /// `hoverWash` + tooltip combo from the previous round. The `.onHover`
    /// modifier (= Apple SwiftUI canonical hover-detection) flips the `@State`
    /// on mouse enter/leave; = the X is the Apple canonical hover affordance
    /// used by Safari / Finder / Mail for list-row close buttons.
    @ViewBuilder
    private func tabButton(for tab: EditorTab) -> some View {
        let isActive = tab.id == selectedTabId
        let isDropTarget = tab.id == dropTargetTabId && draggingTabId != nil

        TabHoverShell { isHovered in
            // RATIONALE: the title is
            // visually centered inside
            // the tab; = a matching 18 PT
            // leading spacer (= the same
            // width as the trailing X-slot)
            // X-slot always reserves `tabCloseFrameSize` (= 18 PT)
            // of space; = the user asked for a matching 18 PT
            // leading spacer (= the title sits between two equal
            // 18 PT zones; = the title reads visually centered).
            // The leading spacer is always present (= even when
            // the X is hidden; = the title stays centered
            // regardless of hover state; = the tab strip's
            // vertical rhythm is preserved).
            HStack(spacing: DesignTokens.spacingCaption) {
                // Leading 18 PT spacer (= matches the trailing
                // X-slot width; = the title sits between two
                // equal-width zones; = the title is visually
                // centered). `Color.clear` so the spacer takes
                // layout space without rendering any pixel.
                Color.clear
                    .frame(width: DesignTokens.tabCloseFrameSize,
                           height: DesignTokens.tabCloseFrameSize)

                Text(EditorTab.displayTitle(tab))
                    .font(isActive ? .body.weight(.medium) : .body)
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isHovered {
                    // RATIONALE 2026-10-13: the X is only rendered
                    // (= and hit-testable) when the tab is hovered;
                    // = when not hovered, the slot is `Color.clear`
                    // with the same `tabCloseFrameSize` (= the
                    // HStack width stays constant; = the X
                    // appearing/disappearing does NOT shift the
                    // tab title). RATIONALE 2026-10-13 visual
                    // diff: the close X is a `Button` (NOT a
                    // plain `Image`; = the wenshu canonical
                    // hit-area idiom for any icon that responds
                    // to click; = the previous round already
                    // added this). The X glyph is the
                    // Apple HIG "small" tier (= 8 PT
                    // `tabCloseIconPointSize`; = the X sits in
                    // the center of the 18 PT hit area with 5 PT
                    // of optical padding; = the X is optically
                    // smaller than the tab title's body font).
                    Button(action: { onClose(tab.id) }) {
                        SFIcon(
                            "xmark",
                            style: .inlineSmall,
                            color: IconColor.secondary,
                            pointSizeOverride: DesignTokens.tabCloseIconPointSize
                        )
                        .frame(width: DesignTokens.tabCloseFrameSize,
                               height: DesignTokens.tabCloseFrameSize)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // RATIONALE 2026-10-13: the `hoverWash()`
                    // modifier tints the close X with a soft
                    // hover background when the cursor is over
                    // the button (= the user sees the
                    // affordance they are about to activate; =
                    // matches the Safari macOS tab-strip hover
                    // idiom). The hoverWash is in addition to
                    // the tab's outer `.onHover` (= the X gets
                    // a nested hover wash inside the tab-level
                    // hover state).
                    .hoverWash()
                    .help(String(localized: "workspace.editor.close_tab_tooltip"))
                } else {
                    // RATIONALE: the X-slot is a transparent
                    // `Color.clear` when NOT hovered; = the
                    // tab's HStack width stays constant
                    // (= the X appearing on hover does NOT
                    // shift the tab title left/right; = the
                    // user sees a stable tab strip rhythm).
                    // The hit area is the same
                    // `tabCloseFrameSize` (= the slot is
                    // reserved for the X at all times; = no
                    // layout reflow on hover).
                    Color.clear
                        .frame(width: DesignTokens.tabCloseFrameSize,
                               height: DesignTokens.tabCloseFrameSize)
                }
            }
        }
        .padding(.horizontal, DesignTokens.spacingModerate)
        .frame(height: DesignTokens.paneTabHotArea)
        .background {
            // Active tab background (= Safari's accent-tinted
            // active tab). RATIONALE: only the top 2 corners
            // are rounded (= `UnevenRoundedRectangle` with
            // bottom 2 corners at 0); = the bottom edge sits
            // flush against the tab-strip's bottom `Divider()`;
            // = the active tab pill looks like it "grows out
            // of" the divider (= the modern Safari tab-strip
            // visual; = the bottom is squared because the
            // divider line itself defines the visual edge).
            // Non-active tabs render transparent (= no
            // background).
            if isActive {
                UnevenRoundedRectangle(
                    topLeadingRadius: DesignTokens.surfaceCornerRadiusSmallButton,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: DesignTokens.surfaceCornerRadiusSmallButton
                )
                .fill(Color.accentColor.opacity(DesignTokens.accentTintOpacitySubtle))
            }
        }
        .overlay(alignment: .bottom) {
            // Active-state underline (= matchedGeometryEffect for the
            // slide animation when the user picks another tab).
            // Matches the PaneTabBar.paneTabHotArea underline height.
            // RATIONALE: boss visual diff 2026-10-13 — the
            // underline is now flush with the tab-pill's left
            // and right edges (= 0 PT horizontal padding; = the
            // line runs edge-to-edge of the active pill; = the
            // modern Safari tab-strip visual where the active
            // indicator fills the pill width). The previous
            // `spacingHairline` (= 1 PT) padding was dropped
            // per the same boss visual diff (= the 1 PT
            // breathing room was still visible; = the
            // underline now has zero inset on both sides).
            if isActive {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: DesignTokens.tabUnderlineHeight)
                    .matchedGeometryEffect(id: "editorTabUnderline", in: tabBarNamespace, properties: .frame)
                    .clipShape(Capsule())
                    .padding(.horizontal, 0)
            }
        }
        .background {
            // Drop-target highlight (= the user is hovering a tab
            // during a drag-reorder gesture). Renders a hairline
            // outline so the user sees where the dragged tab will
            // land.
            if isDropTarget {
                RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusSmallButton)
                    .strokeBorder(Color.accentColor.opacity(DesignTokens.accentTintOpacitySubtle), lineWidth: DesignTokens.surfaceShadowRadiusButton)
            }
        }
        .contentShape(Rectangle())
        // Tab selection = left-click anywhere on the title row
        // (= excluding the close X; = SwiftUI's gesture system
        // dispatches the close-X Button click first because it's a
        // child control).
        .onTapGesture { onSelect(tab.id) }
        // Drag source (= the entire tab row is draggable; = the
        // user grabs the title or any empty space inside).
        .onDrag {
            draggingTabId = tab.id
            return NSItemProvider(object: tab.id.uuidString as NSString)
        }
        // Drop target (= any tab can be a drop target during a drag
        // gesture). Apple HIG multi-tab pattern: dropping a tab ON a
        // tab reorders to land adjacent to that target (= we insert
        // before the drop target in step 2 of handleDrop).
        .onDrop(of: [.text], delegate: TabDropDelegate(
            tabId: tab.id,
            draggingTabId: $draggingTabId,
            dropTargetTabId: $dropTargetTabId,
            displayOrder: $displayOrder,
            onReorder: onReorder
        ))
    }

    /// Sync `displayOrder` with the caller's `tabs` array when the array's id
    /// list changes (= external add / remove / reorder from AppState).
    /// Drag-reorder mutates `displayOrder` directly, so this sync must not undo
    /// it.
    private func syncDisplayOrderIfNeeded() {
        let incomingIds = tabs.map(\.id)

        // 1. Add new ids (= caller added a tab externally; = append
        // in the position they specified).
        if incomingIds != displayOrder {
            // Filter out stale ids (= displayOrder might contain ids
            // the caller removed; = drop them). Add new ids in their
            // caller-specified position (= covers add-new at any
            // position, not just append).
            var newOrder: [UUID] = []
            for id in incomingIds {
                if let existing = displayOrder.first(where: { $0 == id }) {
                    newOrder.append(existing)
                } else {
                    // New id (= not in previous displayOrder) = add
                    // at the caller's position. This preserves the
                    // caller's `openTabs` ordering exactly.
                    newOrder.append(id)
                }
            }
            // If the caller removed tabs (= ids in displayOrder but
            // not in incomingIds), drop them from newOrder. The
            // above loop already does this (= only iterates incoming).
            displayOrder = newOrder
        }

        lastSeenTabIds = incomingIds
    }
}

/// Drag-and-drop delegate for tab reorder. SwiftUI's `.onDrop(of:delegate:)`
/// pattern requires a delegate (= a NSObject + protocol witness). We use a
/// per-tab delegate (= the closure captures the destination tab id + the
/// binding setters).
@MainActor
private struct TabDropDelegate: DropDelegate {
    let tabId: UUID
    @Binding var draggingTabId: UUID?
    @Binding var dropTargetTabId: UUID?
    @Binding var displayOrder: [UUID]
    let onReorder: ([UUID]) -> Void

    func dropEntered(info: DropInfo) {
        // Highlight the drop target while the drag is over it.
        if draggingTabId != nil && draggingTabId != tabId {
            dropTargetTabId = tabId
        }
    }

    func dropExited(info: DropInfo) {
        // Clear the drop-target highlight when the drag leaves.
        if dropTargetTabId == tabId {
            dropTargetTabId = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            // Reset drag state on drop complete (= success or
            // failure).
            draggingTabId = nil
            dropTargetTabId = nil
        }

        guard let draggingId = draggingTabId else { return false }
        guard draggingId != tabId else { return false }

        // Reorder displayOrder: insert `draggingId` immediately
        // before `tabId` (= the drop target). If `draggingId` is
        // already before `tabId`, no-op.
        guard let draggingIdx = displayOrder.firstIndex(of: draggingId),
              let targetIdx = displayOrder.firstIndex(of: tabId) else {
            return false
        }

        // Remove the dragged tab from its old position.
        let movingId = displayOrder.remove(at: draggingIdx)
        // Recompute the target index (= it may have shifted if the
        // dragged tab was before it).
        let newTargetIdx = displayOrder.firstIndex(of: tabId) ?? displayOrder.count
        displayOrder.insert(movingId, at: newTargetIdx)

        // Surface the new order to the caller (= AppState rewrites
        // openTabs + persists).
        onReorder(displayOrder)
        return true
    }
}

/// Per-tab hover shell. RATIONALE 2026-10-13: the wenshu tab close-X is the
/// Apple SwiftUI canonical hover affordance (Safari / Finder / Mail list-row
/// close buttons). The shell owns the `@State private var isHovered: Bool` (=
/// scoped to the per-tab view; = each tab has its own hover state) and exposes
/// the bool to the content closure via a `Bool` parameter (= the conditional X
/// rendering happens inside the closure). The `.onHover` modifier (= Apple
/// SwiftUI canonical hover detection) flips the `@State` on mouse enter/leave;
/// = the X is rendered iff the cursor is inside the tab's bounds.
private struct TabHoverShell<Content: View>: View {
    @State private var isHovered: Bool = false
    private let content: (Bool) -> Content

    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        content(isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
