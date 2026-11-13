//
//  ChatZonePickTests.swift · WenshuAppTests
//
//  The chat zone's session bar and the directory tree are TWO VIEWS over
//  ONE selection, and this suite holds the PRODUCTION pick: = the door
//  the bar's segment actually goes through.
//
//  WHY THIS SUITE EXISTS (= what it holds that the model-level suite
//  does not):
//
//  - `ChatScopeLinkageTests` holds the tree WRITE (= the two statements,
//    = and their order). = That is a guard on the WRITE's contents.
//  - MEASURED (= the review's arms 5 to 10 on this diff): = a guard on
//    that helper alone stays GREEN under every one of them, = because
//    the LINK from the bar's pick to the helper is then unguarded. =
//    Delete the link (= so a page's pick no longer moves the tree at
//    all), = or replace it with the tree's row write alone (= so the
//    part no longer follows the page), = or swap the bar's `onSelect`
//    for a no-op, = and the whole repository stays green. = That is the
//    boss's complaint verbatim: = "切换聊天栏 TEB，没有对应跳转目录树的
//    teb".
//
//  ⇒ ⇒ ⇒ SO THE GUARD DRIVES THE PRODUCTION DOOR: = the suite builds
//  the zone's bar through `ChatZoneTabBar.sessionBar` (= the same door
//  the view's body builds its bar through) = and calls that bar's own
//  `pick` closure (= the one the bar runs), = and a second test hosts
//  the REAL `ChatZoneTabBar` and CLICKS its real segment (= so the bar's
//  own `onSelect` wiring is held too).
//
//  ⇒ ⇒ ⇒ AND THE BODY'S OWN WIRING IS HELD ELSEWHERE, = at the
//  BEHAVIOUR level: = `ChatZoneBodyTests` hosts the REAL zone, = finds
//  the REAL `NSSegmentedControl` its body put on screen, = CLICKS a real
//  segment, = and asserts the REAL `WorkspaceUIState` moved. = ⇒ ⇒ ⇒
//  A SOURCE READ WAS TRIED HERE FIRST, = and it is retired: = it holds
//  a SPELLING, = and MEASURED (= the review's decoys D1 and D3 and the
//  arm M1 on this diff) = three shapes left the WHOLE repository green
//  under it. = ⇒ ⇒ ⇒ And SwiftUI's own premise (= "no body a test can
//  drive") = is FALSE: = the body CAN be hosted.
//
//  ⇒ ⇒ ⇒ AND THE STATE IS A REAL `WorkspaceUIState`: = the part's own
//  `didSet` restores that part's remembered row, = so the ORDER of the
//  two writes only means something against that class.

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp
import WenshuData

@Suite("The chat zone's pick moves the tree")
struct ChatZonePickTests {
    // MARK: - The state under the pick

    /// A real state, over its own defaults suite (= so the user's own
    /// selection never moves).
    @MainActor
    private func makeState() throws -> (WorkspaceUIState, UserDefaults) {
        let defaults = try #require(UserDefaults(suiteName: "chat-zone-pick-tests"))
        defaults.removePersistentDomain(forName: "chat-zone-pick-tests")
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        return (state, defaults)
    }

    // MARK: - The production door

    /// Picking the 资料库 page moves the tree to the 资料库 part AND
    /// to the row the page names.
    ///
    /// ⇒ ⇒ ⇒ AND THE ORDER IS THE ASSERTION: = the suite seeds the
    /// 资料库 part with a DIFFERENT remembered row, = because
    /// `currentSidebarPart`'s `didSet` restores that remembered row, = so
    /// a reversed pair would land the tree on the remembered row instead
    /// of the page's row.
    @Test("Picking the 资料库 page moves the tree to the 资料库 part and its row")
    @MainActor
    func pickingTheLibraryPageMovesTheTree() throws {
        let (state, defaults) = try makeState()
        defer { defaults.removePersistentDomain(forName: "chat-zone-pick-tests") }
        let pages = [
            ChatScopePage(scope: .repository, title: "文枢"),
            ChatScopePage(scope: .library, title: "资料库"),
        ]

        // The 资料库 part REMEMBERS a different row.
        state.currentSidebarPart = .library
        state.sidebarSelection = .tag("remembered")
        state.currentSidebarPart = .shelves

        ChatZoneTabBar.sessionBar(
            pages: pages,
            selectedScope: .repository,
            in: state,
            applyScope: { _ in }
        ).pick(.library)

        #expect(
            state.currentSidebarPart == .library,
            "the pick must move the tree's part to the part that holds the row the page names"
        )
        #expect(
            state.sidebarSelection == .referenceLibraryRoot,
            """
            the pick must land the tree on the row the page names (= the \
            reference-library root), = not on the part's remembered row \
            ('\(String(describing: state.sidebarSelection))'). = The ORDER is \
            load-bearing: = setting the part restores the remembered \
            selection, = so the row write must come after it.
            """
        )
    }

    /// Picking the 文枢 page moves the tree to the HIDDEN "全部分段"
    /// row (= a row the tree does not draw).
    @Test("Picking the 文枢 page moves the tree to the HIDDEN 全部分段 row")
    @MainActor
    func pickingTheRepositoryPageMovesTheTreeToTheHiddenRow() throws {
        let (state, defaults) = try makeState()
        defer { defaults.removePersistentDomain(forName: "chat-zone-pick-tests") }
        let pages = [
            ChatScopePage(scope: .repository, title: "文枢"),
            ChatScopePage(scope: .library, title: "资料库"),
        ]

        ChatZoneTabBar.sessionBar(
            pages: pages,
            selectedScope: .repository,
            in: state,
            applyScope: { _ in }
        ).pick(.repository)

        #expect(state.currentSidebarPart == .shelves, "the 文枢 page's row lives in the 书房 part")
        #expect(
            state.sidebarSelection == .allLibrary,
            "the 文枢 page must land the tree on the HIDDEN 全部分段 row"
        )
    }

    /// Picking a book's page moves the tree to that book's own row.
    @Test("Picking a book's page moves the tree to that book's row")
    @MainActor
    func pickingABookPageMovesTheTreeToThatBook() throws {
        let (state, defaults) = try makeState()
        defer { defaults.removePersistentDomain(forName: "chat-zone-pick-tests") }
        let pages = [
            ChatScopePage(scope: .repository, title: "文枢"),
            ChatScopePage(scope: .library, title: "资料库"),
        ]
        let bookID = try #require(UUID(uuidString: "aaaaaaaa-0000-0000-0000-000000000000")) // swiftlint:disable:this force_try

        ChatZoneTabBar.sessionBar(
            pages: pages,
            selectedScope: .repository,
            in: state,
            applyScope: { _ in }
        ).pick(.book(BookID(rawValue: bookID.uuidString)))

        #expect(state.currentSidebarPart == .shelves, "a book's row lives in the 书房 part")
        #expect(
            state.sidebarSelection == .book(bookID),
            "the pick must land the tree on that book's own row"
        )
    }

    /// The pick also moves the CHAT's own scope (= so the session and
    /// the history are re-read against the new scope).
    ///
    /// ⇒ ⇒ ⇒ AND THE TREE GOES FIRST: = the chat's scope write runs
    /// AFTER the tree's, = so the chat reads what the tree now shows.
    @Test("The pick moves the tree FIRST, = then the chat's own scope")
    @MainActor
    func thePickMovesTheTreeBeforeTheChatScope() throws {
        let (state, defaults) = try makeState()
        defer { defaults.removePersistentDomain(forName: "chat-zone-pick-tests") }
        let pages = [
            ChatScopePage(scope: .repository, title: "文枢"),
            ChatScopePage(scope: .library, title: "资料库"),
        ]

        var order: [String] = []
        ChatZoneTabBar.sessionBar(
            pages: pages,
            selectedScope: .repository,
            in: state
        ) { _ in
            order.append(
                state.currentSidebarPart == .library && state.sidebarSelection == .referenceLibraryRoot
                    ? "chat"
                    : "chat-before-the-tree"
            )
        }.pick(.library)

        #expect(
            order == ["chat"],
            "the chat's own scope must follow the tree's (= the tree is already where the page named it)"
        )
    }

    // MARK: - The bar's own wiring

    /// The REAL bar, clicked for real, moves the REAL tree.
    ///
    /// ⇒ ⇒ ⇒ THIS IS THE WIRING THE PICK GOES THROUGH: = the bar hosts
    /// a real `NSSegmentedControl`, = and clicking its segment is what
    /// runs `onSelect`, = which is what the view wires to the pick. = A
    /// bar whose `onSelect` is a no-op (= so the pick reaches nothing)
    /// must leave the tree where it was, = and this suite says so.
    @Test("Clicking the REAL bar's segment moves the REAL tree")
    @MainActor
    func clickingTheRealBarMovesTheRealTree() throws {
        let (state, defaults) = try makeState()
        defer { defaults.removePersistentDomain(forName: "chat-zone-pick-tests") }

        let pages = [
            ChatScopePage(scope: .repository, title: "文枢"),
            ChatScopePage(scope: .library, title: "资料库"),
        ]
        // The bar's own pick, wired to the PRODUCTION door (= the same
        // call the view makes, = so the wiring under test is the
        // production one).
        let bar = ChatZoneTabBar.sessionBar(
            pages: pages,
            selectedScope: .repository,
            in: state,
            applyScope: { _ in }
        ).bar

        let host = NSHostingView(rootView: AnyView(bar.frame(width: 400)))
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 68)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0 ..< 12 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        guard let control = Self.findSegmentedControl(in: host) else {
            Issue.record("The chat zone's tab bar did not host an NSSegmentedControl.")
            window.orderOut(nil)
            return
        }

        // Click the 资料库 page's segment (= segment 1) for real.
        control.selectedSegment = 1
        control.performClick(nil)
        for _ in 0 ..< 6 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        window.orderOut(nil)

        #expect(
            state.currentSidebarPart == .library,
            "the pick that came through the real bar's segment must move the tree's part"
        )
        #expect(
            state.sidebarSelection == .referenceLibraryRoot,
            "the pick that came through the real bar's segment must land the tree on the page's row"
        )
    }

    /// The bar's own `onSelect` is the door: = a bar wired to a no-op
    /// moves nothing, = and the tree stays where it was.
    ///
    /// ⇒ ⇒ ⇒ THIS IS THE ARM THAT A HELPER-LEVEL GUARD MISSES: = it is
    /// the same production code, = with the ONE link that makes the pick
    /// reach the tree removed.
    @Test("A bar wired to a no-op moves nothing (= the pick's own door)")
    @MainActor
    func aBarWiredToANoOpMovesNothing() throws {
        let (state, defaults) = try makeState()
        defer { defaults.removePersistentDomain(forName: "chat-zone-pick-tests") }

        let pages = [
            ChatScopePage(scope: .repository, title: "文枢"),
            ChatScopePage(scope: .library, title: "资料库"),
        ]
        let bar = ChatZoneTabBar.unwired(
            pages: pages,
            selectedScope: .repository
        )

        let host = NSHostingView(rootView: AnyView(bar.frame(width: 400)))
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 68)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0 ..< 12 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        guard let control = Self.findSegmentedControl(in: host) else {
            Issue.record("The chat zone's tab bar did not host an NSSegmentedControl.")
            window.orderOut(nil)
            return
        }

        control.selectedSegment = 1
        control.performClick(nil)
        for _ in 0 ..< 6 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        window.orderOut(nil)

        #expect(
            state.currentSidebarPart == .shelves,
            "a bar whose onSelect is a no-op must leave the tree where it was"
        )
        #expect(
            state.sidebarSelection == nil,
            "a bar whose onSelect is a no-op must not select a row"
        )
    }

    // MARK: - The helpers

    private static func findSegmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl {
            return control
        }
        for subview in view.subviews {
            if let found = findSegmentedControl(in: subview) {
                return found
            }
        }
        return nil
    }
}
