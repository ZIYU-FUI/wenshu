//
//  SidebarPartSwitchTableIdentityTests.swift · wenshu
//
//  The sidebar's table is rebuilt when the PART changes.
//
//  Coverage:
//    1. A change of PART rebuilds the table (= the rows of the part
//       being left cannot be recycled into the rows of the part being
//       entered).
//    2. A change BELOW the top keeps the table (= the row under the
//       user survives it).
//
//  Method: the tree is hosted in a real `NSHostingView`, = and the
//  table the tree drew into is read by its identity. = ⇒ ⇒ ⇒ The
//  instrument is the table's OBJECT, = because the defect is a table
//  that carried a row of one hierarchy into another (= the row's own
//  pixels, = and not the tree's shape).
//

import AppKit
import Foundation
import Observation
import SwiftUI
import Testing
@testable import WenshuApp

/// The tree (= the box holds it, = so the SAME host can be re-rendered
/// with another tree).
@MainActor
@Observable
private final class TreeBox {
    var tree = SidebarTree(nodes: [])
}

@MainActor
struct SidebarPartSwitchTableIdentityTests {
    // MARK: - The fixture

    private struct Shape {
        let shelf = UUID()
        let book = UUID()
        let folder = UUID()

        /// The shelf tree's one parent row.
        var shelfRow: SidebarNode {
            SidebarNode(
                id: shelf,
                kind: .shelf,
                title: "Shelf",
                subtitle: nil,
                systemImage: "books.vertical",
                children: [bookRow]
            )
        }

        /// The book under the shelf.
        var bookRow: SidebarNode {
            SidebarNode(
                id: book,
                kind: .book,
                title: "Book",
                subtitle: nil,
                systemImage: "book",
                children: [folderRow]
            )
        }

        /// The book's one folder (= the row a subtree change touches).
        var folderRow: SidebarNode {
            SidebarNode(
                id: folder,
                kind: .book,
                title: "Worldview",
                subtitle: nil,
                systemImage: "globe",
                children: nil
            )
        }

        /// The tree of the shelves part.
        var shelves: [SidebarNode] {
            [shelfRow]
        }

        /// The tree of the library part (= another hierarchy, = and its
        /// own rows).
        var library: [SidebarNode] {
            [
                SidebarNode(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    kind: .reference,
                    title: "Library",
                    subtitle: nil,
                    systemImage: "books.vertical",
                    children: [
                        SidebarNode(
                            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                            kind: .tag,
                            title: "Tag",
                            subtitle: nil,
                            systemImage: "tag",
                            children: nil
                        ),
                    ]
                ),
            ]
        }
    }

    private struct Host {
        let box: TreeBox
        let window: NSWindow
        let host: NSHostingView<AnyView>
    }

    /// The tree, hosted (= the box holds the tree, = so the same host
    /// can be re-rendered with another tree).
    private struct HostedTree: View {
        let box: TreeBox
        let workspaceUI: WorkspaceUIState

        var body: some View {
            SidebarTreeView(
                tree: box.tree,
                selection: Binding<SidebarNode?>(
                    get: { nil },
                    set: { _ in }
                ),
                callbacks: nil
            )
            .environment(workspaceUI)
        }
    }

    private func makeWorkspaceUI() throws -> WorkspaceUIState {
        let suite = "sidebar-part-switch-table-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
    }

    private func makeHost(
        tree: [SidebarNode],
        workspaceUI: WorkspaceUIState
    ) -> Host {
        let box = TreeBox()
        box.tree = SidebarTree(nodes: tree)
        let host = NSHostingView(rootView: AnyView(HostedTree(box: box, workspaceUI: workspaceUI)))
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
        return Host(box: box, window: window, host: host)
    }

    /// Let the view's own queued work run (= the run loop, = because
    /// that is where the view's redraw is scheduled).
    private func settle(_ host: Host) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        host.host.layoutSubtreeIfNeeded()
        host.window.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        host.host.layoutSubtreeIfNeeded()
        host.window.displayIfNeeded()
    }

    /// The tables the tree drew into (= every one of them, = because a
    /// table that is still in the hierarchy is a table the tree can
    /// still draw into).
    private func tables(in view: NSView) -> [ObjectIdentifier] {
        var found: [ObjectIdentifier] = []
        func walk(_ view: NSView) {
            if let table = view as? NSTableView {
                found.append(ObjectIdentifier(table))
            }
            view.subviews.forEach(walk)
        }
        walk(view)
        return found
    }

    // MARK: - The claims

    @Test("A change of part rebuilds the table")
    func aChangeOfPartRebuildsTheTable() throws {
        let shape = Shape()
        let workspaceUI = try makeWorkspaceUI()
        let host = makeHost(tree: shape.shelves, workspaceUI: workspaceUI)
        defer { host.window.orderOut(nil) }

        settle(host)

        let before = tables(in: host.host)
        #expect(!before.isEmpty, "the sidebar MUST draw into a table")

        // The part changes (= the tree becomes another hierarchy).
        workspaceUI.currentSidebarPart = .library
        host.box.tree = SidebarTree(nodes: shape.library)
        settle(host)

        let after = tables(in: host.host)
        #expect(!after.isEmpty, "the sidebar MUST draw into a table")

        // ⇒ ⇒ ⇒ THE TABLE OF THE PART BEING LEFT IS GONE: = a table
        // that carried a row of one hierarchy must not be the table
        // the next hierarchy's rows are drawn into (= a recycled cell
        // keeps the row it carried, = and the two rows are drawn on
        // top of each other).
        #expect(
            after.first != before.first,
            """
            a change of part MUST rebuild the table \
            (= the rows of the part being left must not be recycled \
            into the rows of the part being entered); \
            the table before the change was \(before.count) and after it is \(after.count).
            """
        )
    }

    @Test("A change below the top keeps the table")
    func aChangeBelowTheTopKeepsTheTable() throws {
        let shape = Shape()
        let workspaceUI = try makeWorkspaceUI()
        let host = makeHost(tree: shape.shelves, workspaceUI: workspaceUI)
        defer { host.window.orderOut(nil) }

        settle(host)

        let before = tables(in: host.host)
        #expect(!before.isEmpty, "the sidebar MUST draw into a table")

        // The tree's shape changes (= the folder under the book is
        // renamed), = and the part does NOT change.
        var renamed = shape.folderRow
        renamed.title = "Outlook"
        var book = shape.bookRow
        book.children = [renamed]
        var shelf = shape.shelfRow
        shelf.children = [book]
        host.box.tree = SidebarTree(nodes: [shelf])
        settle(host)

        let after = tables(in: host.host)
        #expect(
            after.first == before.first,
            """
            a change below the top MUST keep the table \
            (= the row under the user survives it); \
            the table before the change was \(before.count) and after it is \(after.count).
            """
        )
    }
}
