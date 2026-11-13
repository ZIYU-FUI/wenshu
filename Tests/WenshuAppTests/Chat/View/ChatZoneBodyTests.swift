//
//  ChatZoneBodyTests.swift · WenshuAppTests
//
//  The chat zone's session bar and the directory tree are TWO VIEWS over
//  ONE selection, and this suite holds the ONE link that no other
//  suite can reach: = the VIEW'S OWN BODY.
//
//  ⇒ ⇒ ⇒ WHY THIS SUITE EXISTS (= what it holds that the door's suite
//  does not): = the door's suite drives `ChatZoneTabBar.sessionBar`,
//  = and that holds every link BELOW the door. = But the body decides
//  whether the door is reached AT ALL, = and a body that reaches around
//  it (= through a helper that lives outside the body's own text, = or
//  through a bar with no pick) = leaves every other suite green.
//
//  ⇒ ⇒ ⇒ AND MEASURED (= the review's arm M1 on this diff): = a helper
//  beside the door built the bar with a no-op `onSelect`, = and the
//  WHOLE repository stayed GREEN. = ⇒ ⇒ ⇒ So the body is held HERE, =
//  at the BEHAVIOUR level: = the REAL `ChatZoneView` is hosted, = the
//  REAL `NSSegmentedControl` its body put on screen is found, = a REAL
//  segment is CLICKED, = and the REAL `WorkspaceUIState` must move.
//
//  ⇒ ⇒ ⇒ AND THE HOST IS THE PRODUCTION ONE: = the four
//  `@Environment` objects the zone reads are the production stores
//  (= pointed at a throwaway root, = so no fake can drift out of sync
//  with the protocols), = and the state under test is a real
//  `WorkspaceUIState` (= including the part's own `didSet`, = which
//  restores that part's remembered row).
//
//  ⇒ ⇒ ⇒ AND THIS REPLACES A SOURCE READ: = the earlier attempt held
//  the body by reading its text, = and a spelling has decoys (= a
//  `var` shadow, = a helper outside the window). = MEASURED: = the
//  review's decoys D1 and D3 and the arm M1 all left the repository
//  green under it. = ⇒ ⇒ ⇒ So there is NO source read here: = the
//  behaviour holds the layer, = and the decoys have nothing to hide
//  behind.
//

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp
import WenshuData

@Suite("The chat zone's own body moves the tree")
struct ChatZoneBodyTests {
    // MARK: - The hosted zone

    /// The REAL zone, hosted over the production stores.
    ///
    /// ⇒ ⇒ ⇒ AND THE WINDOW SITS FAR OFFSCREEN: = the hosted zone must
    /// reach the screen's AppKit context (= or the control never
    /// resolves its own size), = and it must never show on the writer's
    /// desktop.
    @MainActor
    private func hostZone(
        workspaceUI: WorkspaceUIState,
        appState: AppState,
        root: URL
    ) throws -> (host: NSHostingView<AnyView>, window: NSWindow, bookStore: BookStore) {
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        let referenceRoot = root.appendingPathComponent("reference", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: referenceRoot, withIntermediateDirectories: true)

        let library = WenshuLibrary(store: FileSystemLibraryStore(rootURL: shelvesRoot))
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceRoot,
            referenceStore: FileSystemReferenceStore(referenceLibraryRoot: referenceRoot)
        )
        let bookStore = BookStore(stores: stores)

        let zone = ChatZoneView()
            .environment(appState)
            .environment(workspaceUI)
            .environment(library)
            .environment(bookStore)

        let host = NSHostingView(rootView: AnyView(zone.frame(width: 500)))
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 400)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0 ..< 20 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return (host, window, bookStore)
    }

    /// A throwaway root for the production stores.
    private func makeRoot() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("chat-zone-body-tests", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// The chat's own scope, as the app outside the view sees it.
    ///
    /// ⇒ ⇒ ⇒ THE ZONE PUBLISHES ITS CHAT'S IDENTITY ONTO THE APP
    /// STATE (= the status page reads it), = so the published session id
    /// is how the chat's scope is SEEN from outside the view. = ⇒ ⇒ ⇒
    /// The repository scope's session is `default`, = and the library
    /// scope's is `library:default`, = so the value really changes.
    @MainActor
    private func chatSession(of appState: AppState) -> SessionID? {
        appState.chatSessionID
    }

    // MARK: - The body's own pick

    @Test("Picking a page in the zone's OWN bar moves the tree (= the body's own wiring)")
    @MainActor
    func theBodiesOwnBarMovesTheTree() throws {
        let defaults = try #require(UserDefaults(suiteName: "chat-zone-body-tests"))
        defaults.removePersistentDomain(forName: "chat-zone-body-tests")
        defer { defaults.removePersistentDomain(forName: "chat-zone-body-tests") }
        let root = try makeRoot()
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        let appState = AppState()

        let (host, window, _) = try hostZone(workspaceUI: state, appState: appState, root: root)
        defer { window.orderOut(nil) }

        // The bar the zone's OWN body put on screen.
        let control = try #require(
            Self.findSegmentedControl(in: host),
            "the zone's body hosted no `NSSegmentedControl` (= the bar is not on screen)"
        )

        // The pages: = the repository conversation, = then one per book
        // (= none, = the throwaway library is empty), = then the
        // reference library.
        #expect(
            control.segmentCount == 2,
            "the zone's bar shows \\(control.segmentCount) pages (= the repository conversation and the reference library)"
        )

        // A REAL click on a REAL segment.
        control.selectedSegment = 1
        control.performClick(nil)
        for _ in 0 ..< 10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        #expect(
            state.currentSidebarPart == .library,
            """
            the zone's own bar moved the tree to \\(state.currentSidebarPart) \\
            (= it must move it to the library, = or the user's click on \\
            the chat's tab strip does nothing).
            """
        )
        #expect(
            state.sidebarSelection == .referenceLibraryRoot,
            """
            the zone's own bar landed the tree on \\(state.sidebarSelection) \
            (= it must land on the row the page names).
            """
        )
        #expect(
            chatSession(of: appState) == ChatScope.library.sessionID,
            """
            the chat's own session is \(String(describing: chatSession(of: appState))) (= it must follow the page: = the library scope's session).
            """
        )
    }

    @Test("The tree's row follows the page (= and the part comes first)")
    @MainActor
    func theTreesRowFollowsThePage() throws {
        let defaults = try #require(UserDefaults(suiteName: "chat-zone-body-tests-order"))
        defaults.removePersistentDomain(forName: "chat-zone-body-tests-order")
        defer { defaults.removePersistentDomain(forName: "chat-zone-body-tests-order") }
        let root = try makeRoot()
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        let appState = AppState()

        // The library part REMEMBERS a different row (= so the ORDER is
        // visible: = the part's `didSet` restores it).
        state.currentSidebarPart = .library
        state.sidebarSelection = .tag("remembered")
        state.currentSidebarPart = .shelves

        let (host, window, _) = try hostZone(workspaceUI: state, appState: appState, root: root)
        defer { window.orderOut(nil) }

        let control = try #require(
            Self.findSegmentedControl(in: host),
            "the zone's body hosted no `NSSegmentedControl` (= the bar is not on screen)"
        )
        control.selectedSegment = 1
        control.performClick(nil)
        for _ in 0 ..< 10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        #expect(
            state.currentSidebarPart == .library,
            "the part must move to the part that holds the row the page names"
        )
        #expect(
            state.sidebarSelection == .referenceLibraryRoot,
            """
            the write must land the tree on the row the page names (= \
            not on the part's remembered row, = which is what a \
            REVERSED pair of the two writes leaves behind).
            """
        )
        #expect(
            chatSession(of: appState) == ChatScope.library.sessionID,
            """
            the chat's own session is \(String(describing: chatSession(of: appState))) (= it must follow the page: = the library scope's session).
            """
        )
    }

    @Test("The tree's own change carries the chat's scope (= the bar's write is not the only path)")
    @MainActor
    func theTreesOwnChangeCarriesTheChatsScope() throws {
        let defaults = try #require(UserDefaults(suiteName: "chat-zone-body-tests-onchange"))
        defaults.removePersistentDomain(forName: "chat-zone-body-tests-onchange")
        defer { defaults.removePersistentDomain(forName: "chat-zone-body-tests-onchange") }
        let root = try makeRoot()
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        let appState = AppState()

        let (host, window, _) = try hostZone(workspaceUI: state, appState: appState, root: root)
        defer { window.orderOut(nil) }

        // The chat starts on the repository scope (= the session `default`).
        #expect(
            chatSession(of: appState) == ChatScope.repository.sessionID,
            """
            the chat starts on \(String(describing: chatSession(of: appState))) (= the repository scope's session).
            """
        )

        // ⇒ ⇒ ⇒ THE TREE MOVES ALONE (= no bar, = no click): = and the
        // chat's scope must follow it. = ⇒ ⇒ ⇒ THIS IS WHY THE BAR'S
        // OWN SCOPE WRITE IS NOT LOAD-BEARING: = the zone's `onChange`
        // on the tree's selection delivers the same scope (= = the
        // bar's write is the one that lands it NOW, = and this is the
        // one that lands it a render pass later). = ⇒ ⇒ ⇒ And THIS
        // TEST IS WHAT MAKES THAT CLAIM A GUARD: = delete the
        // `onChange`, = and the chat's scope stops following the tree
        // (= = and then the bar's own write becomes the only path, = and
        // the arm that was retired below becomes a real harm).
        state.currentSidebarPart = .library
        state.sidebarSelection = .referenceLibraryRoot
        for _ in 0 ..< 10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        #expect(
            chatSession(of: appState) == ChatScope.library.sessionID,
            """
            the chat's own session is \(String(describing: chatSession(of: appState))) (= the tree's own change must carry it: = the library scope's session).
            """
        )
    }

    @Test("The bar's own selection follows the tree (= the link the other way)")
    @MainActor
    func theBarsSelectionFollowsTheTree() throws {
        let defaults = try #require(UserDefaults(suiteName: "chat-zone-body-tests-reverse"))
        defaults.removePersistentDomain(forName: "chat-zone-body-tests-reverse")
        defer { defaults.removePersistentDomain(forName: "chat-zone-body-tests-reverse") }
        let root = try makeRoot()
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        let appState = AppState()

        let (host, window, _) = try hostZone(workspaceUI: state, appState: appState, root: root)
        defer { window.orderOut(nil) }

        // The bar starts on the repository page (= the tree starts on
        // no row, = and the repository scope is what that names).
        let first = try #require(
            Self.findSegmentedControl(in: host),
            "the zone's body hosted no `NSSegmentedControl` (= the bar is not on screen)"
        )
        #expect(
            first.selectedSegment == 0,
            "the bar starts on segment \(first.selectedSegment) (= the repository page)"
        )

        // ⇒ ⇒ ⇒ THE TREE MOVES (= the tree's own selection, = with no
        // bar and no click): = and the BAR's drawn selection must
        // follow it. = ⇒ ⇒ ⇒ THIS IS THE LINK THE OTHER WAY: = the bar
        // and the tree are TWO VIEWS over ONE selection, = so a tree
        // row and a bar page can never name different scopes. = ⇒ ⇒ ⇒
        // MEASURED (= the review's arm M2 on this diff): = freezing
        // `currentScope` (= so the bar's drawn selection stops
        // following the tree) = left the whole repository GREEN, = and
        // the boss's own first complaint was of exactly this shape: = "目录树新建书籍，编辑器的 teb 栏没有同步新建会话".
        state.currentSidebarPart = .library
        state.sidebarSelection = .referenceLibraryRoot
        for _ in 0 ..< 10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        let after = try #require(
            Self.findSegmentedControl(in: host),
            "the zone's body hosted no `NSSegmentedControl` after the tree moved"
        )
        #expect(
            after.selectedSegment == 1,
            """
            the bar's drawn selection is segment \(after.selectedSegment) (= it must follow the tree: = the library page is segment 1).
            """
        )
    }

    @Test("A book the user creates shows up in the zone's own bar (= the page list is the live collection)")
    @MainActor
    func aNewBookGetsAPageInTheBodiesOwnBar() throws {
        let defaults = try #require(UserDefaults(suiteName: "chat-zone-body-tests-pages"))
        defaults.removePersistentDomain(forName: "chat-zone-body-tests-pages")
        defer { defaults.removePersistentDomain(forName: "chat-zone-body-tests-pages") }
        let root = try makeRoot()
        let state = WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
        let appState = AppState()

        let (host, window, bookStore) = try hostZone(
            workspaceUI: state,
            appState: appState,
            root: root
        )
        defer { window.orderOut(nil) }

        // The bar's pages before the book exists (= the repository
        // conversation and the reference library).
        let first = try #require(
            Self.findSegmentedControl(in: host),
            "the zone's body hosted no `NSSegmentedControl` (= the bar is not on screen)"
        )
        #expect(
            first.segmentCount == 2,
            "the zone's bar shows \(first.segmentCount) pages (= the repository conversation and the reference library)"
        )

        // ⇒ ⇒ ⇒ THE USER CREATES A BOOK (= the store's collection
        // grows, = which is what the tree's own "new book" action does).
        bookStore.books.append(
            Book(
                title: "新建的书",
                shelfId: UUID()
            )
        )
        for _ in 0 ..< 10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        // ⇒ ⇒ ⇒ AND THE ZONE'S OWN BAR MUST SHOW IT: = the bar's pages
        // come from the LIVE collection, = so a book the user just made
        // has a page at once. = ⇒ ⇒ ⇒ MEASURED (= the review's arm on
        // this diff): = handing the page list an EMPTY collection = left
        // the whole repository green, = and then a newly created book
        // gets NO page in the chat zone's bar (= the boss's own FIRST
        // complaint: = "目录树新建书籍，编辑器的 teb 栏没有同步新建会话").
        let after = try #require(
            Self.findSegmentedControl(in: host),
            "the zone's body hosted no `NSSegmentedControl` after the book was created"
        )
        #expect(
            after.segmentCount == 3,
            """
            the zone's bar shows \(after.segmentCount) pages after a book was created (= it must show 3: = the repository conversation, = the new book, = and the reference library).
            """
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
