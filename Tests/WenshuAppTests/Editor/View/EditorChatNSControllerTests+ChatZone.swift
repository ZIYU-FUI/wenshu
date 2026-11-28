//
//  EditorChatNSControllerTests+ChatZone.swift · WenshuApp
//
//  The chat zone's visibility (= one fact, one owner).
//
//  WHY THIS FILE EXISTS
//  ====================
//
//  The suite's own file is 944 lines (= over the 600-LOC cap), and the
//  cap is a RATCHET: a file over it may only shrink. So this case
//  lives beside it, as an extension of the same suite (= = the house's
//  own precedent: `CitationHonestyTests+Teeth.swift`).
//
//  WHAT THE CASE IS FOR
//  ====================
//
//  "Is the chat zone showing?" has ONE owner: the AppKit split item's
//  own `.isCollapsed` (= = the thing that draws it, animates it,
//  persists it, and reports it). `WorkspaceUIState.chatVisible` is that
//  fact's MIRROR (= = the menu's checkmark, = = the LLM-can-edit gate),
//  and the View menu ASKS rather than writes (= = a collapse animates,
//  = = so no value the menu writes can move the picture).
//
//  So the case pins the ONE writer (= = the AppKit side, reading the
//  split item), the ONE asker (= = the menu), the wake that makes the
//  request reachable (= = the ask must reach the layout pass that
//  answers it), and that the flag's own documentation does not claim a
//  fiction (= = a doc block that lies is the evidence the next reader
//  trusts).
//

import Foundation
import Testing

extension EditorChatNSControllerTests {
    @Test("The chat zone has ONE owner: the split item, and the flag is its mirror")
    func theChatZoneHasOneOwner() throws {
        // It reads the chat zone's own file (= = the suite's read set
        // does not carry it, = = because that set is the suite's
        // PRIVATE business, = = and a file over the loc-cap may only
        // shrink).
        let content = try String(
            contentsOf: SourceLocator.url(
                "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+ChatZone.swift"
            ),
            encoding: .utf8
        )
        let menu = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/App/AppRootScene.swift"),
            encoding: .utf8
        )
        let state = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/State/WorkspaceUIState.swift"),
            encoding: .utf8
        )
        // The menu ASKS; it does not set the fact.
        #expect(menu.contains("workspaceUI.requestChatZoneToggle()"),
                "the View menu must ASK the split to toggle (= = it cannot collapse an AppKit item by writing a value)")
        #expect(!menu.contains("workspaceUI.chatVisible ="),
                "the View menu must NOT write the visibility flag (= = that flag is the split item's mirror, = = and the menu writing it is the defect: pressing (⌥⌘K) moved no pixels while it moved the LLM-can-edit gate)")
        // The AppKit side answers, and it is the only writer.
        #expect(content.contains("answerChatZoneToggleRequestIfAny"),
                "the controller must answer the menu's request (= = the collapse is AppKit's own, with its own animation)")
        #expect(content.contains("ui.chatVisible = visible"),
                "the controller must write the mirror from the split item's own state (= = one fact, one owner)")
        #expect(content.contains("override func splitViewDidResizeSubviews"),
                "the mirror must be written from the split's own report of the subviews moving (= = that report also covers the reader's DRAG and the autosave's RESTORE, = = which a menu-driven write never did)")
        #expect(content.contains("super.splitViewDidResizeSubviews(notification)"),
                "the override must call super (= = Apple's own header: 'Any overrides of NSSplitViewDelegate methods must call super')")
        // The flag's own documentation must not claim the fiction.
        #expect(!state.contains("The macOS menu bar View >"),
                "the flag's own doc must not say the menu writes it (= = that sentence is the evidence the next reader would trust)")
        // And the request must be a COUNTER (= = the reader can ask again
        // and again; a flag would fire once).
        #expect(state.contains("chatZoneToggleRequest &+= 1"),
                "the toggle request must be a counter (= = the same shape as the transcript's own jump-to-newest request)")
    }

    /// The ask must be ANSWERED, and the answer must be reachable.
    ///
    /// The review of the first round found the gap this case closes: the
    /// request was read in the controller's LAYOUT PASS (= = the right
    /// place: the collapse animates, so it must not be answered while
    /// the split is moving), but NOTHING woke that pass (= = the request
    /// sat unread until some unrelated layout happened, = = and if none
    /// did, the View menu row toggled its checkmark and the zone stayed
    /// exactly where it was).
    ///
    /// So the edge has three parts, and each one is pinned here:
    ///
    ///   * the SwiftUI body READS the request (= = so it is re-evaluated
    ///     when the reader asks, = = which is the wake's first half);
    ///   * the host pushes it across and calls the wake (= = the wake's
    ///     second half);
    ///   * the wake schedules the layout pass (= = `needsLayout`, = = the
    ///     platform's own "lay out again"), and the layout pass is where
    ///     the answer is written.
    @Test("The toggle request is ANSWERED: the ask wakes the layout that answers it")
    func theToggleRequestIsAnswered() throws {
        let zone = try String(
            contentsOf: SourceLocator.url(
                "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+ChatZone.swift"
            ),
            encoding: .utf8
        )
        let host = try String(
            contentsOf: SourceLocator.url(
                "Sources/WenshuApp/Features/Editor/View/EditorChatSplitHost.swift"
            ),
            encoding: .utf8
        )
        let root = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/UI/LibraryRootView.swift"),
            encoding: .utf8
        )
        let lifecycle = try String(
            contentsOf: SourceLocator.url(
                "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Lifecycle.swift"
            ),
            encoding: .utf8
        )
        // The body reads the request (= = the wake's first half: the
        // body is re-evaluated when the reader asks).
        #expect(root.contains("chatZoneToggleRequest: workspaceUI.chatZoneToggleRequest"),
                "the body that owns the editor must READ the toggle request (= = a request nobody reads is a request nobody answers; = = and reading it is what re-evaluates the body when the reader asks)")
        // The host pushes it across and calls the wake (= = the second
        // half: the request reaches the controller that owns the split).
        #expect(host.contains("wakeForChatZoneToggleRequestIfPending"),
                "the host must wake the controller when the request changes (= = the controller answers it in a layout pass, = = and nothing else would schedule that pass)")
        // The wake IS the platform's own layout scheduling (= = not a
        // timer, = = not a dispatch, = = not a poll).
        #expect(zone.contains("view.needsLayout = true"),
                "the wake must schedule the layout pass with the platform's own `needsLayout` (= = a timer or a dispatch would answer the request while the split may still be moving)")
        // And the answer is written in that pass (= = the collapse
        // animates, = = so it must not be answered while the split moves).
        #expect(lifecycle.contains("answerChatZoneToggleRequestIfAny()"),
                "the layout pass must answer the request (= = the split must not be collapsing while it is answered)")
        #expect(zone.contains("func wakeForChatZoneToggleRequestIfPending"),
                "the controller must own the wake (= = the AppKit side owns the split, = = and the wake is the platform's own layout scheduling)")
    }

    /// The answer must MOVE the split (= = the effect hop).
    ///
    /// The wake, the request and the mirror can all be right while the
    /// zone never moves, = = so the hop from the answer to the split
    /// item's own collapse is pinned here too: the answer calls the
    /// controller's toggle, and the toggle is the split item's own
    /// animated collapse.
    @Test("The answer MOVES the split: the request reaches the split item's own collapse")
    func theAnswerMovesTheSplit() throws {
        let zone = try String(
            contentsOf: SourceLocator.url(
                "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+ChatZone.swift"
            ),
            encoding: .utf8
        )
        let layout = try String(
            contentsOf: SourceLocator.url(
                "Sources/WenshuApp/Features/Editor/View/EditorChatNSController+Layout.swift"
            ),
            encoding: .utf8
        )
        // The answer calls the toggle (= = the hop from the request to
        // the picture). The CALL is what is asserted, = = the exact
        // code line, = = because this file's own doc block names the
        // function too (= = a substring test would pass on the prose
        // and the test would have no teeth).
        #expect(zone.contains("\n        toggleChatZone()\n"),
                "the answer must CALL the controller's toggle (= = otherwise the request is answered with no effect at all)")
        // And the toggle is the split item's OWN animated collapse (= =
        // AppKit's collapse, with AppKit's animation).
        #expect(layout.contains("item.animator().isCollapsed.toggle()"),
                "the toggle must be the split item's own animated collapse (= = the platform owns the fact and the animation)")
    }
}
