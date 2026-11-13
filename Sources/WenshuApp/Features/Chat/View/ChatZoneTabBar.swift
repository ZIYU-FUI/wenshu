// ChatZoneTabBar.swift
//
// The chat zone's top bar (= the session tab bar).
//
// It shows one page per conversation scope: the repository conversation
// first, one page per ordinary book, and the reference-library conversation
// last. The pages come from the library's CURRENT books, so a new book gets
// a page the moment it is created and a deleted book leaves no page behind.
//
// The bar and the directory tree are two views over ONE selection
// (= `workspaceUI.sidebarSelection`), so clicking a page selects the
// matching tree row and clicking a tree row selects the matching page.
//
// The control is the house's `LabelSegmentedControl` (= an AppKit
// `NSSegmentedControl` in the `.valueSelection` role), inside a horizontal
// scroll view: that is the same shape the editor's tab strip uses, and the
// scroll is what keeps a growing page list inside the chat column.
//
// One view per file (per Apple HIG).

import SwiftUI

/// The chat zone's top bar (= one page per conversation scope).
@MainActor
struct ChatZoneTabBar: View {
    /// The pages to render, in display order.
    let pages: [ChatScopePage]

    /// The scope whose page is selected.
    ///
    /// A scope that has no page of its own (= the help book, which is
    /// read-only) names no segment, and the control then draws NO
    /// selection: the drawn selection can never name a different value
    /// than the bound one.
    let selectedScope: ChatScope

    /// Fired when the user picks a different page.
    let onSelect: (ChatScope) -> Void

    /// The bar's only constructor (= PRIVATE, = and that is the point).
    ///
    /// ⇒ ⇒ ⇒ WHY: = the chat zone's bar and the directory tree are TWO
    /// VIEWS over ONE selection, = and the bar's pick is what moves the
    /// tree. = If any file could build the bar, = then any file could
    /// build one whose pick does nothing, = and no guard on the real
    /// chain would see it. = ⇒ ⇒ ⇒ MEASURED (= the review's decoy M1
    /// on this diff): = a helper beside the door built the bar with a
    /// no-op `onSelect`, = and the whole repository stayed GREEN.
    ///
    /// ⇒ ⇒ ⇒ So the bar is built by TWO doors only: = `sessionBar`
    /// (= the production chain, = which writes the tree), = and
    /// `unwired` (= a bar with no pick, = for a test that measures the
    /// bar's own drawing). = ⇒ ⇒ ⇒ And a body that reached for either
    /// of them = would build a bar whose pick moves no tree, = so the
    /// suite that HOSTS the body sees it.
    private init(
        pages: [ChatScopePage],
        selectedScope: ChatScope,
        onSelect: @escaping (ChatScope) -> Void
    ) {
        self.pages = pages
        self.selectedScope = selectedScope
        self.onSelect = onSelect
    }

    /// The width the bar was given (= the chat column's current width).
    @State private var columnWidth: CGFloat = 0

    var body: some View {
        content
    }

    /// The bar's body (= the scroll container + the control).
    private var content: some View {
        ScrollView(.horizontal) {
            LabelSegmentedControl(
                selection: Binding(
                    get: { selectedScope },
                    set: { newScope in onSelect(newScope) }
                ),
                labels: pages.map(\.scope),
                displayStrings: pages.map(\.title),
                iconStyle: .paneTab,
                // The bar divides the column it was given: every page
                // takes one equal share of the measured column width, so
                // the bar's total width tracks the column the writer
                // dragged instead of the number of open pages.
                //
                // The region is what the control's frame is PINNED to
                // (= `LabelSegmentedControl.sizeThatFits`), = and
                // AppKit's `.fillEqually` then divides that frame
                // exactly, at any page count, with no per-cell minimum.
                // A zero width means the column has not been measured
                // yet, so the bar takes its own fitting width until the
                // first measurement lands.
                regionWidth: columnWidth,
                role: .valueSelection,
                // The bar's drawn capsule takes its height from the
                // segmented control the left and right columns already
                // use (= `.small`), = so all four columns' top bands
                // draw the same capsule height.
                controlSize: .small
            )
            // The control keeps its own height (= the `.small` capsule's
            // 20 PT), = the same way the sidebar's and the inspector's
            // switchers keep theirs: AppKit draws the capsule to fill the
            // control's height, = so a control stretched to the band row's
            // height would draw a full-height pill with no air.
            .fixedSize(horizontal: false, vertical: true)
        }
        // Apple's own tab bars scroll the overflow without an indicator,
        // and a floating scroll bar is the one part of this bar that is not
        // a page name. Only the drawing goes: the container still scrolls
        // and still clips.
        .scrollIndicators(.hidden, axes: .horizontal)
        // The bar fills the width it is given, and measures it. The
        // measurement feeds the segment widths above, so the bar tracks
        // the column when the writer resizes it.
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            columnWidth = newWidth
        }
        .frame(height: DesignTokens.paneTabHotArea)
    }
}

extension ChatZoneTabBar {
    /// A bar with no pick (= for a test that measures the bar's own
    /// drawing).
    ///
    /// ⇒ ⇒ ⇒ WHY IT EXISTS: = the bar's `init` is private, = so that
    /// no other file can build a bar whose pick does nothing. = A test
    /// that measures the bar's DRAWING has no tree to move, = so it
    /// needs a bar with no pick, = and this is the one door for that.
    ///
    /// ⇒ ⇒ ⇒ AND A BODY THAT REACHED FOR THIS = would build a bar that
    /// moves no tree, = so the suite that HOSTS the body sees it (= it
    /// clicks the bar the body put on screen, = and the tree must
    /// move).
    static func unwired(
        pages: [ChatScopePage],
        selectedScope: ChatScope
    ) -> ChatZoneTabBar {
        ChatZoneTabBar(
            pages: pages,
            selectedScope: selectedScope,
            onSelect: { _ in }
        )
    }

    /// The chat zone's session bar: = the bar the zone shows, = and the
    /// wiring from its pick to the tree.
    ///
    /// ⇒ ⇒ ⇒ THIS IS THE PRODUCTION CHAIN'S DOOR, = and it is the door
    /// the guard drives. = The view's body builds its bar HERE, = and the
    /// guard builds the same bar HERE, = so every link between the
    /// user's click and the tree's write is inside the thing the guard
    /// holds.
    ///
    /// ⇒ ⇒ ⇒ WHY IT IS A STATIC AND NOT A VIEW: = a guard that calls a
    /// helper BELOW the bar (= the tree's write) holds that helper's
    /// body, = and the link from the bar to it is then unguarded: =
    /// MEASURED (= the review's arms 5 to 10 on this diff): = deleting
    /// the call from the bar's wiring (= so a page's pick no longer
    /// moves the tree at all), = replacing it with the tree's row write
    /// alone (= so the part no longer follows the page), = or swapping
    /// the bar's `onSelect` for a no-op left the WHOLE repository green,
    /// = and the boss's complaint came back with one line:
    /// "切换聊天栏 TEB，没有对应跳转目录树的 teb".
    ///
    /// Internal (= the default access, = and the type's own default is
    /// internal too) so a test can drive the PRODUCTION pick with a real
    /// `WorkspaceUIState` and a real bar.
    ///
    /// - Parameters:
    ///   - pages: The bar's pages (= one per conversation scope).
    ///   - selectedScope: The scope whose page is selected.
    ///   - workspaceUI: The tree's state (= the real one, = so the
    ///     `didSet` that restores a part's remembered row is the one
    ///     that runs).
    ///   - applyScope: The chat's own scope write. = ⇒ ⇒ ⇒ IT IS NOT
    ///     THE ONLY PATH: = the zone's `onChange` on the tree's
    ///     selection delivers the same scope on the next render pass,
    ///     = so this write is the one that lands the scope NOW. = ⇒ ⇒ ⇒
    ///     And that is why a body that handed the door a no-op scope
    ///     write is not a harm: = the scope still follows the tree.
    /// - Returns: The bar, = wired to the tree's write.
    static func sessionBar(
        pages: [ChatScopePage],
        selectedScope: ChatScope,
        in workspaceUI: WorkspaceUIState,
        applyScope: @escaping (ChatScope) -> Void
    ) -> (bar: ChatZoneTabBar, pick: (ChatScope) -> Void) {
        // The pick closure (= the ONE door for the whole chain).
        //
        // ⇒ ⇒ ⇒ AND THE TWO WRITES LIVE HERE, = not in a helper below:
        // = so there is no second name for the chain, = and nothing
        // outside this function can reach the write. = MEASURED (= the
        // review's arm 8 on this diff): = while a `pickHandler` helper
        // existed and the linkage suite called it by name, = inlining
        // the writes left the suite GREEN and the helper ALIVE (= so
        // "the helper is off the production path" was not a mutation
        // anybody could make, = because the helper was still called
        // from the test).
        let pick: (ChatScope) -> Void = { scope in
            // The tree moves with the page (= ONE DOOR: = the two
            // writes live HERE, = so there is no helper below that the
            // production path could bypass).
            //
            // ⇒ ⇒ ⇒ AND THE PART IS SET FIRST: = setting the part
            // restores that part's remembered selection (= the
            // `WorkspaceUIState` `didSet`), = and the selection write
            // below then lands on the row the page names. = A reversed
            // pair leaves the tree on the part's REMEMBERED row instead
            // of the page's row, = so the order is load-bearing.
            workspaceUI.currentSidebarPart = scope.sidebarPart
            workspaceUI.sidebarSelection = scope.treeSelection
            // The chat's own scope follows the tree's selection, so the
            // session and the history are re-read against the new scope.
            applyScope(scope)
        }
        let bar = ChatZoneTabBar(
            pages: pages,
            selectedScope: selectedScope,
            // The bar's pick (= the tree moves with the page, = and the
            // chat's own scope follows it).
            onSelect: pick
        )
        return (bar, pick)
    }
}
