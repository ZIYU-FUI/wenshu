//
//  SidebarTreeReloadTests.swift · wenshu
//
//  The sidebar tree is rebuilt when the LIBRARY changes, = and not when
//  the SELECTION moves.
//
//  Coverage:
//    1. A selection change does not re-read the library (= the tree is
//       not rebuilt under the user), = and the view DID see the
//       selection (= the reveal opened the row above it).
//    2. A library change does re-read the library.
//
//  Method: the real `AppleSidebarView` is hosted in a real
//  `NSHostingView` over a service whose loaders COUNT the reads. = ⇒
//  A property assertion would not prove either claim: = the defect was
//  a behaviour (= the view asked for a rebuild on every selection), =
//  and a behaviour is measured on the view that has it.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
struct SidebarTreeReloadTests {
    // MARK: - The fixture

    /// The reads the service's loaders counted.
    private final class ReadCounter {
        private(set) var count = 0
        func record() {
            count += 1
        }
    }

    private struct Fixture {
        let root: URL
        let suite: String
        let counter: ReadCounter
        let service: SidebarService
        let bookStore: BookStore
        let workspaceUI: WorkspaceUIState
        let sheetRequests: SheetRequestState
        let appState: AppState
        let shelfID: UUID
        let bookID: UUID
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-sidebar-tree-reload-\(UUID().uuidString)")
        let referenceLibraryRoot = root.appendingPathComponent("reference-library", isDirectory: true)
        try FileManager.default.createDirectory(
            at: referenceLibraryRoot,
            withIntermediateDirectories: true
        )
        let shelvesRoot = root.appendingPathComponent("shelves", isDirectory: true)
        try FileManager.default.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)

        let store = FileSystemReferenceStore(referenceLibraryRoot: referenceLibraryRoot)
        let stores = LibraryStores(
            shelvesRoot: shelvesRoot,
            referenceLibraryRoot: referenceLibraryRoot,
            referenceStore: store
        )
        let bookStore = BookStore(stores: stores)
        // The tree has a row to select: = a shelf with a book under it,
        // = so the selection names a row whose path the reveal opens.
        let shelfID = UUID()
        let bookID = UUID()
        let shelf = Bookshelf(id: shelfID, name: "Shelf")
        let book = Book(id: bookID, title: "Book", shelfId: shelfID)
        let counter = ReadCounter()
        let service = SidebarService(
            loadShelves: {
                counter.record()
                return [shelf]
            },
            loadAllBooks: {
                counter.record()
                return [book]
            },
            loadReferences: {
                counter.record()
                return []
            },
            bookStore: bookStore
        )
        let suite = "sidebar-tree-reload-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return Fixture(
            root: root,
            suite: suite,
            counter: counter,
            service: service,
            bookStore: bookStore,
            workspaceUI: WorkspaceUIState(store: UserDefaultsStore(defaults: defaults)),
            sheetRequests: SheetRequestState(),
            appState: AppState(),
            shelfID: shelfID,
            bookID: bookID
        )
    }

    // MARK: - The hosting

    /// The sidebar, hosted over the fixture's own service.
    private func makeHost(_ fixture: Fixture) -> (NSWindow, NSHostingView<AnyView>) {
        let view = AppleSidebarView(service: fixture.service)
            .environment(fixture.bookStore)
            .environment(fixture.workspaceUI)
            .environment(fixture.sheetRequests)
            .environment(fixture.appState)
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = NSRect(x: 0, y: 0, width: 260, height: 600)
        // The window sits far outside the screen (= offscreen, = so
        // nothing shows on the writer's desktop) and is ordered front
        // (= AppKit lays the tree out during a display pass).
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        return (window, host)
    }

    /// Let the view's own queued work run.
    ///
    /// ⇒ ⇒ ⇒ A SLEEP, = NOT A RUN-LOOP PASS: = the test body runs ON
    /// the main actor, = so the actor is busy while the test runs, = and
    /// a run-loop pass would not let the actor's own queued work (= the
    /// view's reload task) run at all. = ⇒ ⇒ ⇒ A sleep suspends the
    /// test, = and the queued work runs while the actor is free.
    private func settle(host: NSView, window: NSWindow?) async {
        try? await Task.sleep(for: .milliseconds(500))
        host.layoutSubtreeIfNeeded()
        window?.displayIfNeeded()
    }

    private func cleanup(_ fixture: Fixture, window: NSWindow) {
        // The window is ordered OUT (= hidden, = and still alive): = the
        // hosting view must outlive the test, = because SwiftUI still
        // holds it while its own deferred work drains.
        window.orderOut(nil)
        UserDefaults.standard.removePersistentDomain(forName: fixture.suite)
        try? FileManager.default.removeItem(at: fixture.root)
    }

    // MARK: - The claims

    @Test("The selection does not rebuild the tree")
    func theSelectionDoesNotRebuildTheTree() async throws {
        let fixture = try makeFixture()
        let (window, host) = makeHost(fixture)
        defer { cleanup(fixture, window: window) }

        await settle(host: host, window: window)

        // The view's own task has loaded the tree (= the app's first
        // read is the baseline the claim is measured against).
        let afterFirstLoad = fixture.counter.count
        #expect(afterFirstLoad > 0, "the sidebar MUST read the library when it appears")

        fixture.workspaceUI.sidebarSelection = .book(fixture.bookID)
        await settle(host: host, window: window)

        // ⇒ ⇒ ⇒ THE VIEW SAW THE SELECTION: = the reveal opened the
        // row above the selected one. = ⇒ ⇒ ⇒ Without this the claim
        // would pass on a view that never looked at the selection.
        #expect(
            fixture.workspaceUI.expandedSidebarRows.contains(.shelf(fixture.shelfID)),
            """
            the sidebar MUST see the selection (= the reveal opens the row above it); \
            the open rows are \\(fixture.workspaceUI.expandedSidebarRows).
            """
        )

        // ⇒ ⇒ ⇒ THE SELECTION IS A SCOPE, = NOT A CHANGE OF THE TREE:
        // = rebuilding the tree here is what made the rows jump under
        // = the user (= the tree was replaced, = and the row he had
        // = clicked became a new row).
        #expect(
            fixture.counter.count == afterFirstLoad,
            """
            the selection MUST NOT re-read the library \
            (= the tree is the library's shape, = and a scope change does not change it); \
            the reads went from \(afterFirstLoad) to \(fixture.counter.count).
            """
        )
    }

    @Test("A library change rebuilds the tree")
    func aLibraryChangeRebuildsTheTree() async throws {
        let fixture = try makeFixture()
        let (window, host) = makeHost(fixture)
        defer { cleanup(fixture, window: window) }

        await settle(host: host, window: window)

        let afterFirstLoad = fixture.counter.count
        #expect(afterFirstLoad > 0, "the sidebar MUST read the library when it appears")

        NotificationCenter.default.post(name: .wenshuLibraryDidChange, object: nil)
        await settle(host: host, window: window)

        // ⇒ ⇒ ⇒ THE LIBRARY IS WHAT THE TREE SHOWS: = so a change to
        // = it rebuilds the tree (= and that is the only thing that
        // = does).
        #expect(
            fixture.counter.count > afterFirstLoad,
            """
            a library change MUST re-read the library (= the tree is the library's shape); \
            the reads went from \(afterFirstLoad) to \(fixture.counter.count).
            """
        )
    }
}
