//
//  SidebarTreeRowIdentityTests.swift · wenshu
//
//  The tree's rows: a row's identity is its own data, and a row's
//  DRAWING follows its subtree.
//
//  Coverage:
//    1. A row's identity does not change when its children change.
//    2. A row's identity holds EVERY field of its own data (= the id,
//       the kind, the title, the subtitle, the icon and the routing
//       key, = one case each).
//    3. The tree draws one row per row it holds (= the distinct drawn
//       identities against the rows the table holds).
//    4. A tree rebuilt IN PLACE draws the added row, drops the removed
//       row, and shows the renamed row's new title.
//
//  Method: the tree is hosted in a real `NSHostingView`, = and the rows
//  are measured in the table the tree drew into. = ⇒ ⇒ ⇒ The rebuild
//  case re-renders the SAME host (= the box holds the tree), = so a
//  tree that keeps drawing its old subtree is visible here (= a second
//  host would hide it).
//
//  ⇒ ⇒ ⇒ THE PIXELS ARE THE INSTRUMENT: = the text SwiftUI draws is
//  not a view the test can read (= it is painted, = and the drawn row
//  view carries no accessibility label), = so the row's own rectangle
//  is what the test reads. = ⇒ ⇒ ⇒ The pixels are a SOUND reading
//  here: = two trees that differ only in a row's text draw different
//  pixels (= the reading sees the text), = and a tree that did not
//  change draws the same pixels (= the reading is not noise).
//
//  ⇒ ⇒ ⇒ THE HOST SPINS THE RUN LOOP: = the view's own queued work
//  runs there (= the app's run loop), = and a sleep alone would leave
//  the tree's redraw pending (= the reading would see the OLD pixels
//  and call it a freeze).
//

import AppKit
import Foundation
import Observation
import SwiftUI
import Testing
@testable import WenshuApp

/// The tree (= the box holds it, = so the SAME host can be re-rendered
/// with a rebuilt tree).
@MainActor
@Observable
private final class TreeBox {
    var tree = SidebarTree(nodes: [])
    var selection: SidebarNode?
}

/// One row of the tree (= the fixture's own row builder).
private func row(
    id: UUID,
    kind: SidebarNode.Kind = .book,
    title: String = "Book",
    subtitle: String? = nil,
    systemImage: String = "book",
    children: [SidebarNode]? = nil,
    routingKey: String? = nil
) -> SidebarNode {
    SidebarNode(
        id: id,
        kind: kind,
        title: title,
        subtitle: subtitle,
        systemImage: systemImage,
        children: children,
        routingKey: routingKey
    )
}

@MainActor
struct SidebarTreeRowIdentityTests {
    // MARK: - The fixture

    /// The tree's shape (= the ids, = so a rebuild is the same tree
    /// with a different content).
    private struct Shape {
        let shelf = UUID()
        let book = UUID()
        let folder = UUID()
        let added = UUID()

        /// The shelf (= the tree's one parent row).
        var shelfRow: SidebarNode {
            row(
                id: shelf,
                kind: .shelf,
                title: "Shelf",
                systemImage: "books.vertical"
            )
        }

        /// The book (= the row under the shelf).
        var bookRow: SidebarNode {
            row(id: book, title: "Book")
        }

        /// The book's one folder (= the row the rebuild removes).
        var folderRow: SidebarNode {
            row(id: folder, title: "Worldview", systemImage: "globe")
        }

        /// The folder the rebuild adds (= a different row, = so the two
        /// are told apart).
        var addedRow: SidebarNode {
            row(id: added, title: "Outline", systemImage: "square.stack")
        }

        /// The tree as it was drawn first (= the shelf, = the book under
        /// it, = and the book's one folder).
        var before: [SidebarNode] {
            [
                row(
                    id: shelf,
                    kind: .shelf,
                    title: "Shelf",
                    systemImage: "books.vertical",
                    children: [
                        row(
                            id: book,
                            title: "Book",
                            children: [folderRow]
                        ),
                    ]
                ),
            ]
        }

        /// The tree as the service projects it again (= the book is
        /// renamed, = its folder is gone, = and a new folder is under
        /// it).
        ///
        /// ⇒ ⇒ ⇒ THE SHELF'S OWN DATA DID NOT CHANGE: = so the shelf
        /// row compares equal to the one the tree drew, = and only the
        /// subtree's content tells the tree that the rows under it
        /// changed.
        var after: [SidebarNode] {
            [
                row(
                    id: shelf,
                    kind: .shelf,
                    title: "Shelf",
                    systemImage: "books.vertical",
                    children: [
                        row(
                            id: book,
                            title: "Renamed",
                            children: [addedRow]
                        ),
                    ]
                ),
            ]
        }

        /// Every row the "before" tree holds (= the census asks where
        /// each of them is drawn).
        var beforeRows: [SidebarNode] {
            [shelfRow, bookRow, folderRow]
        }
    }

    /// The fields the row's own identity holds (= the card names six:
    /// the id, the kind, the title, the subtitle, the icon and the
    /// routing key).
    private static let ownFields: [(name: String, other: (UUID) -> SidebarNode)] = [
        ("kind", { id in row(id: id, kind: .shelf) }),
        ("title", { id in row(id: id, title: "Other") }),
        ("subtitle", { id in row(id: id, subtitle: "7") }),
        ("systemImage", { id in row(id: id, systemImage: "globe") }),
        ("routingKey", { id in row(id: id, routingKey: "a") }),
    ]

    // MARK: - The host

    /// The hosted tree (= the window, = the host, = and the box the
    /// tree lives in).
    private struct Host {
        let box: TreeBox
        let window: NSWindow
        let host: NSHostingView<AnyView>
    }

    /// The tree, hosted (= the box holds the tree, = so the same host
    /// can be re-rendered with a rebuilt tree).
    private struct HostedTree: View {
        let box: TreeBox
        let workspaceUI: WorkspaceUIState

        var body: some View {
            SidebarTreeView(
                tree: box.tree,
                selection: Binding(
                    get: { box.selection },
                    set: { box.selection = $0 }
                ),
                callbacks: nil
            )
            .environment(workspaceUI)
        }
    }

    private func makeWorkspaceUI() throws -> WorkspaceUIState {
        let suite = "sidebar-row-identity-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return WorkspaceUIState(store: UserDefaultsStore(defaults: defaults))
    }

    /// The tree, hosted with its shelf and its book open.
    private func makeHost(
        tree: [SidebarNode],
        workspaceUI: WorkspaceUIState
    ) -> Host {
        let box = TreeBox()
        box.tree = SidebarTree(nodes: tree)
        let view = HostedTree(box: box, workspaceUI: workspaceUI)
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

    // MARK: - The instrument

    /// The table the tree drew into (= the rows the tree DREW).
    private func table(in host: NSHostingView<AnyView>) -> NSTableView? {
        var found: NSTableView?
        func walk(_ view: NSView) {
            guard found == nil else { return }
            if let table = view as? NSTableView {
                found = table
                return
            }
            view.subviews.forEach(walk)
        }
        walk(host)
        return found
    }

    /// The row views the tree DREW (= the view count, = which cannot
    /// see a row drawn twice).
    private func drawnRowViews(in view: NSView) -> Int {
        var count = 0
        func walk(_ view: NSView) {
            if String(describing: type(of: view)).contains("ListTableRowView") {
                count += 1
            }
            view.subviews.forEach(walk)
        }
        walk(view)
        return count
    }

    /// The row a node is drawn at (= the tree's own selection bridge
    /// answers it, = and -1 = the node is NOT drawn).
    ///
    /// ⇒ ⇒ ⇒ THE BRIDGE IS THE TREE'S OWN ANSWER: = the table says
    /// which of its rows carries the row the tree gave it, = so a tree
    /// that kept its old subtree cannot answer for a row it never
    /// drew.
    private func drawnRow(of node: SidebarNode, in host: Host) -> Int {
        host.box.selection = node
        settle(host)
        return table(in: host.host)?.selectedRow ?? -1
    }

    /// The drawn pixels of one row (= the row's own rectangle, = so the
    /// measurement is the row and not the window).
    ///
    /// ⇒ ⇒ ⇒ THE PIXELS ARE THE DRAWING: = the text SwiftUI draws is
    /// not a view the test can read (= it is painted), = so the row's
    /// own rectangle is what the test reads.
    private func drawnPixels(row: Int, in host: Host) -> [UInt8]? {
        guard let table = table(in: host.host) else { return nil }
        let rowRect = table.rect(ofRow: row)
        guard rowRect.height > 0 else { return nil }
        let rect = table.convert(rowRect, to: host.host).integral
        guard let rep = host.host.bitmapImageRepForCachingDisplay(in: host.host.bounds) else {
            return nil
        }
        host.host.cacheDisplay(in: host.host.bounds, to: rep)
        guard let bytes = rep.bitmapData else { return nil }
        let scale = max(1, rep.pixelsWide / max(1, Int(host.host.bounds.width)))
        let x = Int(rect.minX) * scale
        let y = Int(rect.minY) * scale
        let rowWidth = Int(rect.width) * scale
        let rowHeight = Int(rect.height) * scale
        guard x >= 0, y >= 0, x + rowWidth <= rep.pixelsWide, y + rowHeight <= rep.pixelsHigh else {
            return nil
        }
        var pixels: [UInt8] = []
        pixels.reserveCapacity(rowWidth * rowHeight * 4)
        for line in y ..< (y + rowHeight) {
            let start = line * rep.bytesPerRow + x * 4
            pixels.append(
                contentsOf: UnsafeBufferPointer(
                    start: bytes + start,
                    count: rowWidth * 4
                )
            )
        }
        return pixels
    }

    /// Whether a band holds anything but its own background (= the row's
    /// own ink).
    ///
    /// ⇒ ⇒ ⇒ THE BACKGROUND IS THE BAND'S COMMONEST PIXEL: = the
    /// appearance is the machine's own, = so the ink is what differs
    /// from the background (= not what is brighter than it).
    private func hasInk(_ pixels: [UInt8]) -> Bool {
        guard pixels.count >= 8 else { return false }
        var counts: [UInt32: Int] = [:]
        for index in stride(from: 0, to: pixels.count - 3, by: 4) {
            let key = UInt32(pixels[index]) << 16
                | UInt32(pixels[index + 1]) << 8
                | UInt32(pixels[index + 2])
            counts[key, default: 0] += 1
        }
        guard let background = counts.max(by: { $0.value < $1.value })?.key else { return false }
        for index in stride(from: 0, to: pixels.count - 3, by: 4) {
            let key = UInt32(pixels[index]) << 16
                | UInt32(pixels[index + 1]) << 8
                | UInt32(pixels[index + 2])
            if key != background {
                return true
            }
        }
        return false
    }

    // MARK: - The identity

    @Test("A row's identity does not change when its children change")
    func aRowsIdentityDoesNotChangeWithItsChildren() {
        let shelfID = UUID()
        let book = row(id: UUID(), title: "Book")
        let before = row(
            id: shelfID,
            kind: .shelf,
            title: "Shelf",
            systemImage: "books.vertical",
            children: [book]
        )
        let after = row(
            id: shelfID,
            kind: .shelf,
            title: "Shelf",
            systemImage: "books.vertical",
            children: [
                book,
                row(id: UUID(), title: "Worldview"),
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

    @Test("A row's identity holds every field of its own data")
    func aRowsIdentityHoldsEveryFieldOfItsOwnData() {
        let id = UUID()
        let base = row(id: id)

        // ⇒ ⇒ ⇒ ONE FIELD AT A TIME: = the card names six fields, = and
        // a case that varies only the title pins the title and nothing
        // else (= a row whose equality forgot its kind, its count, its
        // icon or its routing key passed that case).
        for field in Self.ownFields {
            let other = field.other(id)
            #expect(
                base != other,
                """
                a row's identity MUST hold its \(field.name) \
                (= a row whose \(field.name) changed is a new row, = and the tree must draw it again).
                """
            )
        }

        // ⇒ ⇒ ⇒ AND THE ID ITSELF: = a different id is a different row.
        #expect(
            base != row(id: UUID()),
            "a row's identity MUST hold its id (= two rows are never one row)"
        )
    }

    // MARK: - The drawing

    @Test("The tree draws one row per row it holds")
    func theTreeDrawsOneRowPerRowItHolds() throws {
        let shape = Shape()
        let workspaceUI = try makeWorkspaceUI()
        workspaceUI.expandedSidebarRows = [.shelf(shape.shelf), .book(shape.book)]
        let host = makeHost(tree: shape.before, workspaceUI: workspaceUI)
        defer { host.window.orderOut(nil) }

        settle(host)

        let table = try #require(table(in: host.host))
        let rows = table.numberOfRows
        #expect(rows > 0, "the tree MUST hold rows (= the census found none)")

        // ⇒ ⇒ ⇒ THE DISTINCT IDENTITIES: = the tree's own rows are
        // asked where they are drawn (= the tree's selection bridge
        // answers), = and the number of DISTINCT rows they occupy is
        // the number of rows the tree really drew.
        var drawn: Set<Int> = []
        for node in shape.beforeRows {
            let row = drawnRow(of: node, in: host)
            #expect(
                row >= 0,
                "the tree MUST draw the row \"\(node.title)\" (= the bridge found no row for it)"
            )
            drawn.insert(row)
        }
        #expect(
            drawn.count == rows,
            """
            the tree MUST draw one row per row \
            (= it drew \(drawn.count) distinct identities for \(rows) rows; = a row drawn twice shows here).
            """
        )
        #expect(
            drawnRowViews(in: host.host) == rows,
            """
            the tree MUST draw one row view per row \
            (= it drew \(drawnRowViews(in: host.host)) row views for \(rows) rows).
            """
        )
    }

    @Test("A tree rebuilt in place draws the added row and drops the removed one")
    func aTreeRebuiltInPlaceDrawsTheAddedRowAndDropsTheRemovedOne() throws {
        let shape = Shape()
        let workspaceUI = try makeWorkspaceUI()
        workspaceUI.expandedSidebarRows = [.shelf(shape.shelf), .book(shape.book)]
        let host = makeHost(tree: shape.before, workspaceUI: workspaceUI)
        defer { host.window.orderOut(nil) }

        settle(host)

        // The renamed row's own pixels (= the book, = the row under the
        // shelf).
        let before = try #require(drawnPixels(row: 1, in: host))
        #expect(
            hasInk(before),
            "the row's own rectangle MUST hold the row's ink (= the measurement is looking at the background)"
        )

        // The tree is rebuilt (= the service projects it again): = the
        // SAME host, = the rows are new objects, = the book is renamed,
        // = its folder is gone, = and a new folder is under it.
        host.box.tree = SidebarTree(nodes: shape.after)
        settle(host)

        // ⇒ ⇒ ⇒ THE RENAMED ROW SHOWS ITS NEW TITLE: = the row's own
        // pixels are the pixels a tree built with the new title draws
        // (= the tree drew the row, = and the row says what it says).
        let reference = makeHost(tree: shape.after, workspaceUI: workspaceUI)
        defer { reference.window.orderOut(nil) }
        settle(reference)

        // Each window is the key window while its own row is read (= so
        // the two readings are in the same state).
        reference.window.makeKeyAndOrderFront(nil)
        settle(reference)
        let expected = try #require(drawnPixels(row: 1, in: reference))
        host.window.makeKeyAndOrderFront(nil)
        settle(host)
        let after = try #require(drawnPixels(row: 1, in: host))
        #expect(
            hasInk(after),
            "the rebuilt row's own rectangle MUST hold the row's ink (= the measurement is looking at the background)"
        )
        #expect(
            after != before,
            "the rebuilt tree MUST draw the renamed row again (= the row kept the text it had)"
        )
        #expect(
            after == expected,
            "the rebuilt tree MUST draw the renamed row's new title (= the row drew something else)"
        )

        // ⇒ ⇒ ⇒ THE ADDED ROW IS DRAWN: = the tree's own row is asked
        // where it is drawn, = and a tree that kept its old subtree
        // cannot answer.
        let addedRow = drawnRow(of: shape.addedRow, in: host)
        #expect(
            addedRow >= 0,
            "the rebuilt tree MUST draw the row that was added (= the book under the shelf never appeared)"
        )

        // ⇒ ⇒ ⇒ THE REMOVED ROW IS GONE: = the tree's own row is asked
        // where it is drawn, = and a row the tree no longer holds has
        // no place.
        let removedRow = drawnRow(of: shape.folderRow, in: host)
        #expect(
            removedRow < 0,
            "the rebuilt tree MUST NOT draw the row that was removed (= the tree kept its old subtree)"
        )
    }
}
