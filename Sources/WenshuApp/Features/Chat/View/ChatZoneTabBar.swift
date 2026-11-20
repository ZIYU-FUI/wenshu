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
// The control is Apple's own tab switcher (= `WenshuTabPicker`, = the
// macOS 27 tab role), inside a horizontal scroll view: the scroll is what
// keeps a growing page list inside the chat column, and the system owns
// the selected plate and how it moves.
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

    /// The bar's body (= the switcher in its clipping band).
    ///
    /// The scroll container is what keeps the paint inside the column: =
    /// the switcher's frame is pinned to the column, = but the system gives
    /// every cell AT LEAST its own width (= MEASURED 2026-11-19: = 12
    /// pages in a 300 PT column measured a 29 PT cell, = so the row ran
    /// 48 PT past the frame = 12 x 29 - 300), = and a control that paints
    /// past the column would paint over the panel next door.
    ///
    /// The width is measured OUTSIDE the container (= a geometry reader
    /// inside a horizontal scroll view reads the content's ideal width,
    /// = not the viewport's), = so the switcher divides the column it is
    /// given (= the 2026-11-12 ruling).
    private var content: some View {
        ScrollView(.horizontal) {
            WenshuTabPicker(
                selection: Binding(
                    get: { selectedScope },
                    set: { newScope in onSelect(newScope) }
                ),
                labels: pages.map(\.scope),
                displayStrings: pages.map(\.title),
                // The bar's drawn plate takes its height from the switcher
                // the other columns' top bands already use (= `.small`), =
                // so the three columns that wear the tab role draw the
                // same plate height.
                controlSize: .small,
                regionWidth: columnWidth > 0 ? columnWidth : nil
            )
        }
        // Apple's own tab bars scroll the overflow without an indicator,
        // and a floating scroll bar is the one part of this bar that is
        // not a page name. Only the drawing goes: the container still
        // scrolls and still clips.
        .scrollIndicators(.hidden, axes: .horizontal)
        // The band fills the width it is given, = and measures it: = the
        // measurement feeds the switcher's pinned width above.
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            columnWidth = newWidth
        }
        .frame(height: DesignTokens.paneTabHotArea)
        // The bar closes its band with the SHARED hairline (= the same mark
        // the sidebar's, the assets column's, the inspector column's and the
        // editor zone's bands close theirs with), = so the bar reads as a
        // chrome band above the chat body and not as the top of one
        // undifferentiated plane.
        //
        // The hairline rides the band's HEIGHT frame, = so it lands on the
        // band's bottom edge (= the same edge the other columns' hairlines
        // land on), = and it is an OVERLAY (= not a row of its own), = so it
        // costs the band no height and the capsule's own line does not move.
        .bandBottomHairline()
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
            // The tree opens the path to the row the page names (= the
            // conversation shows where it lives). The request is its
            // own signal (= the selection's value can be the same as
            // the one the tree already has, = and then a tree that
            // watched the value would hear nothing).
            workspaceUI.requestReveal()
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
