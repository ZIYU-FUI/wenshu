//
//  SidebarTreeRowIdentityTests.swift · wenshu
//
//  The tree's rows: each row is drawn ONCE, and a row's identity is
//  the row itself (= not its subtree).
//
//  Coverage:
//    1. A row's identity does not change when its children change.
//    2. The tree draws one row view per row (= no row is drawn twice).
//    3. A rebuilt tree still draws one row view per row.
//
//  Method: the tree is hosted in a real `NSHostingView`, and the rows
//  are counted in the DRAWN view tree (= the row views the table
//  materialized) against the rows the table holds. = ⇒ ⇒ ⇒ A row that
//  is drawn twice shows up as more row views than rows, = and a data
//  model that cannot see the drawing cannot answer the question.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
struct SidebarTreeRowIdentityTests {
    // MARK: - The fixture

    /// A shelf with a book under it (= a tree with a container and a
    /// leaf, = so the census has a row that opens and a row that does
    /// not).
    private static func tree(
        shelfID: UUID = UUID(),
        bookID: UUID = UUID()
    ) -> (nodes: [SidebarNode], shelfID: UUID) {
        let nodes = [
            SidebarNode(
                id: shelfID,
                kind: .shelf,
                title: "Shelf",
                subtitle: nil,
                systemImage: "books.vertical",
                children: [
                    SidebarNode(
                        id: bookID,
                        kind: .book,
                        title: "Book",
                        subtitle: nil,
                        systemImage: "book",
                        children: [
                            SidebarNode(
                                id: UUID(),
                                kind: .book,
                                title: "Worldview",
                                subtitle: nil,
                                systemImage: "globe",
                                children: nil
                            ),
                        ]
                    ),
                ]
            ),
        ]
        return (nodes, shelfID)
    }

    /// The row views the tree DREW.
    private func drawnRows(in view: NSView) -> Int {
        var count = 0
        func walk(_ v: NSView) {
            if String(describing: type(of: v)).contains("TableRowView") {
                count += 1
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return count
    }

    /// The rows the table holds (= the data rows).
    private func dataRows(in view: NSView) -> Int? {
        var rows: Int?
        func walk(_ v: NSView) {
            if rows != nil {
                return
            }
            if let table = v as? NSTableView {
                rows = table.numberOfRows
                return
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return rows
    }

    private func makeWorkspaceUI() throws -> WorkspaceUIState {
        let suite = "sidebar-row-identity-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
    }

    /// The tree, hosted with its shelf open.
    private func makeHost(
        nodes: [SidebarNode],
        workspaceUI: WorkspaceUIState
    ) -> (NSWindow, NSHostingView<AnyView>) {
        let view = SidebarTreeView(
            nodes: nodes,
            selection: .constant(nil),
            callbacks: nil
        )
        .environment(workspaceUI)
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = NSRect(x: 0, y: 0, width: 260, height: 600)
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

    /// Let the view's own queued work run (= a sleep, = because the test
    /// body runs on the main actor and a run-loop pass would not let
    /// the actor's queued work run).
    private func settle(host: NSView, window: NSWindow?) async {
        try? await Task.sleep(for: .milliseconds(400))
        host.layoutSubtreeIfNeeded()
        window?.displayIfNeeded()
    }

    // MARK: - The claims

    @Test("A row's identity does not change when its children change")
    func aRowsIdentityDoesNotChangeWithItsChildren() {
        let shelfID = UUID()
        let bookID = UUID()
        let book = SidebarNode(
            id: bookID,
            kind: .book,
            title: "Book",
            subtitle: nil,
            systemImage: "book",
            children: nil
        )
        let before = SidebarNode(
            id: shelfID,
            kind: .shelf,
            title: "Shelf",
            subtitle: nil,
            systemImage: "books.vertical",
            children: [book]
        )
        let after = SidebarNode(
            id: shelfID,
            kind: .shelf,
            title: "Shelf",
            subtitle: nil,
            systemImage: "books.vertical",
            children: [
                book,
                SidebarNode(
                    id: UUID(),
                    kind: .book,
                    title: "Worldview",
                    subtitle: nil,
                    systemImage: "globe",
                    children: nil
                ),
            ]
        )

        // ⇒ ⇒ ⇒ A ROW IS ITS OWN ROW, = NOT ITS SUBTREE: = the tree's
        // rows are matched by identity, = so a row whose children
        // changed (= the tree was rebuilt) is still the same row.
        #expect(
            before == after,
            "a row's identity MUST NOT include its children (= the tree rebuilds the rows under the user)"
        )
        #expect(before.hashValue == after.hashValue)
    }

    @Test("A row's identity changes when its own data changes")
    func aRowsIdentityChangesWithItsOwnData() {
        let shelfID = UUID()
        let before = SidebarNode(
            id: shelfID,
            kind: .shelf,
            title: "Shelf",
            subtitle: nil,
            systemImage: "books.vertical",
            children: nil
        )
        let renamed = SidebarNode(
            id: shelfID,
            kind: .shelf,
            title: "Shelf 2",
            subtitle: nil,
            systemImage: "books.vertical",
            children: nil
        )

        // ⇒ ⇒ ⇒ THE ROW'S OWN DATA IS PART OF ITS IDENTITY: = a row
        // whose title changed is a new row, = so the tree draws the new
        // text. = ⇒ ⇒ ⇒ A row's identity that ignored its own data
        // would freeze the tree's text.
        #expect(
            before != renamed,
            "a row's identity MUST include its own data (= the tree must draw a renamed row)"
        )
    }

    @Test("The tree draws one row view per row")
    func theTreeDrawsOneRowViewPerRow() async throws {
        let fixture = Self.tree()
        let workspaceUI = try makeWorkspaceUI()
        workspaceUI.expandedSidebarRows = [.shelf(fixture.shelfID)]
        let (window, host) = makeHost(nodes: fixture.nodes, workspaceUI: workspaceUI)
        defer { window.orderOut(nil) }

        await settle(host: host, window: window)

        let rows = try #require(dataRows(in: host))
        #expect(rows > 0, "the tree MUST hold rows (= the census found none)")
        #expect(
            drawnRows(in: host) == rows,
            """
            the tree MUST draw one row view per row \
            (= it drew \(drawnRows(in: host)) row views for \(rows) rows; = a row drawn twice shows here).
            """
        )
    }

    @Test("A rebuilt tree still draws one row view per row")
    func aRebuiltTreeStillDrawsOneRowViewPerRow() async throws {
        let fixture = Self.tree()
        let workspaceUI = try makeWorkspaceUI()
        workspaceUI.expandedSidebarRows = [.shelf(fixture.shelfID)]
        let (window, host) = makeHost(nodes: fixture.nodes, workspaceUI: workspaceUI)
        defer { window.orderOut(nil) }

        await settle(host: host, window: window)
        let before = try #require(dataRows(in: host))

        // The tree is rebuilt (= the service projects it again): = the
        // rows are new objects, = but they are the SAME rows (= the same
        // ids), = and the tree must not draw them twice.
        let rebuilt = Self.tree(shelfID: fixture.shelfID)
        let (secondWindow, secondHost) = makeHost(
            nodes: rebuilt.nodes,
            workspaceUI: workspaceUI
        )
        defer { secondWindow.orderOut(nil) }
        await settle(host: secondHost, window: secondWindow)
        let after = try #require(dataRows(in: secondHost))

        #expect(after == before, "a rebuilt tree MUST hold the same rows")
        #expect(
            drawnRows(in: secondHost) == after,
            """
            a rebuilt tree MUST draw one row view per row \
            (= it drew \(drawnRows(in: secondHost)) row views for \(after) rows).
            """
        )
    }
}
