//  ChatZoneTabBarTests.swift - Wenshu
//
//  The chat zone's session tab bar: what it shows, and how wide it is.
//
//  Two claims are measured here, both through the bar's own control:
//
//  - the bar follows the user's door: a book the user creates in the
//    directory tree must show up as a page in the bar, = because the
//    bar's pages are read from the app's shared book collection.
//
//  - the bar divides the column it is given: the pages take one equal
//    share each, = so the bar spans the column instead of hugging its
//    left edge, = and the overflow scrolls.
//
//  The boss's rule (= 2026-11-12) is the browser's mechanism: the
//  region is divided into as many equal shares as there are pages, the
//  bar never exceeds the region, and a page label has NO minimum width
//  (= a page may end up showing not one character, = and that is fine).
//
//  Method: the real `ChatZoneTabBar` is hosted in a real `NSHostingView`
//  at a real column width, then the AppKit view tree is walked to the
//  `NSSegmentedControl` the bar draws. A property assertion would not
//  prove either claim: = the defect was a rendering behaviour, = and a
//  control that holds the right labels can still paint them at the
//  wrong width.
//
//  The bar's DRAWN geometry is read from the control's layer tree: = the
//  cells are the 1 PT hairline layers AppKit draws between them, = and
//  those positions are real pixels, = not an Accessibility frame (= the
//  Accessibility radio-button frame clamps to 24 PT whatever the real
//  width is, = so it cannot answer this question).

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp
import WenshuData

@MainActor
@Suite("The chat zone's session tab bar")
struct ChatZoneTabBarTests {
    // MARK: - The fixture

    /// A library with a real store, and the sidebar's service over it.
    ///
    /// The service is the user's own door (= the one the directory
    /// tree's "new book here" menu opens), = so the test drives the
    /// production path and not a hand-built list.
    private struct Fixture {
        let root: URL
        let service: SidebarService
        let bookStore: BookStore
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-chat-zone-tab-bar-\(UUID().uuidString)")
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
        let service = SidebarService(
            loadShelves: { [] },
            loadAllBooks: { try bookStore.sidebarLoadAllBooks() },
            loadReferences: { [] },
            bookStore: bookStore
        )
        return Fixture(root: root, service: service, bookStore: bookStore)
    }

    private func newBookInput(_ title: String, shelfId: UUID) -> NewBookSheet.NewBookInput {
        NewBookSheet.NewBookInput(
            title: title,
            author: "wenshu",
            shelfId: shelfId,
            icon: "book"
        )
    }

    /// The bar's pages, read from the collection the bar reads.
    private func pages(for fixture: Fixture) -> [ChatScopePage] {
        ChatScope.pageList(
            books: fixture.bookStore.books,
            repositoryTitle: "Wenshu",
            libraryTitle: "Reference Library"
        )
    }

    // MARK: - The measurement

    /// What the bar's control drew, at a given column width.
    private struct Bar {
        /// The width the bar was given.
        var columnWidth: CGFloat
        /// The width the control's FRAME was given (= the column).
        var frameWidth: CGFloat
        /// The width the bar's DRAWN cells occupy.
        var drawnTrackWidth: CGFloat
        /// The drawn cell boundaries (= the 1 PT dividers AppKit draws
        /// between two cells).
        var dividers: [CGFloat]
        /// The drawn CELLS (= one label layer per cell) and the STEP from
        /// one cell to the next (= the width one cell takes).
        ///
        /// The step is measured from the label layers rather than from
        /// the hairline dividers, = because AppKit draws a divider only
        /// between two cells wide enough to hold one (= MEASURED: 3 cells
        /// in a 200 PT region drew ONE divider for THREE cells), = so a
        /// divider count would answer a different question than the one
        /// asked here.
        var drawnCellCount: Int
        var drawnCellSteps: [CGFloat]
        /// The labels the control drew.
        var labels: [String]
        /// The width of the container that clips the control, if any.
        var clipWidth: CGFloat?
    }

    /// The drawn geometry of a segmented control.
    ///
    /// The control's cells are the 1 PT wide hairline layers AppKit draws
    /// between them; the track is the layer they all sit on. Both are
    /// read from the layer tree, so they are real pixels.
    private static func drawnGeometry(
        of control: NSSegmentedControl
    ) -> (track: (CGFloat, CGFloat)?, dividers: [CGFloat], labels: [CGFloat]) {
        var track: (CGFloat, CGFloat)?
        var raw: [CGFloat] = []
        var labelPositions: [CGFloat] = []

        func scan(_ layer: CALayer) {
            let frame = layer.frame
            let name = String(describing: type(of: layer))
            if name == "CGDrawingLayer" {
                // A cell's label. = its x is the cell's x.
                labelPositions.append(frame.origin.x)
            } else if name == "CALayer" {
                // A divider = the hairline between two cells.
                if frame.width == 1, frame.height > 6, frame.height < 18 {
                    raw.append(frame.origin.x)
                }
                // The track = the layer the cells sit on.
                if frame.width > 4, frame.height > 14, frame.height < 22 {
                    if track == nil || frame.width > track!.1 {
                        track = (frame.origin.x, frame.width)
                    }
                }
            }
            for sub in layer.sublayers ?? [] {
                scan(sub)
            }
        }
        if let layer = control.layer {
            scan(layer)
        }

        // Each divider is drawn once per appearance, so the distinct
        // positions are the cell boundaries.
        var dividers: [CGFloat] = []
        for position in raw.sorted()
            where dividers.last.map({ abs($0 - position) > 0.5 }) ?? true
        {
            dividers.append(position)
        }
        return (track, dividers, labelPositions.sorted())
    }

    /// Host the real bar at `columnWidth` and measure what it drew.
    private func measure(pages: [ChatScopePage], columnWidth: CGFloat) -> Bar {
        let bar = ChatZoneTabBar.unwired(
            pages: pages,
            selectedScope: pages.first?.scope ?? .repository
        )

        let host = NSHostingView(
            rootView: AnyView(bar.frame(width: columnWidth))
        )
        host.frame = NSRect(x: 0, y: 0, width: columnWidth, height: 68)
        // An offscreen window gives AppKit the display context it needs to
        // resolve a control's fitting size. It sits far outside the screen
        // so the measurement never shows on the writer's desktop.
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        // The window is ordered FRONT (= offscreen, = so nothing shows on
        // the writer's desktop) because AppKit lays a segmented control's
        // CELLS out during a display pass: = a window that is never
        // ordered front keeps the cells at the width they had when the
        // control was first measured (= the control's own fitting width),
        // = and the bar then measures as if it overflowed. = the real app
        // orders its window front, = so the measurement must too.
        window.orderFront(nil)
        settle(window: window, host: host)
        window.display()

        guard let control = Self.findSegmentedControl(in: host) else {
            Issue.record("The chat zone's tab bar did not host an NSSegmentedControl.")
            window.orderOut(nil)
            return Bar(
                columnWidth: columnWidth,
                frameWidth: 0,
                drawnTrackWidth: 0,
                dividers: [],
                drawnCellCount: 0,
                drawnCellSteps: [],
                labels: [],
                clipWidth: nil
            )
        }

        let geometry = Self.drawnGeometry(of: control)
        let clipWidth = Self.scrollViewport(of: control).map { Self.width(of: $0) }
        // The step from one cell to the next, = measured from the drawn
        // label layers (= one per cell).
        let cellXs = geometry.labels
        let steps = (0 ..< max(cellXs.count - 1, 0)).map { cellXs[$0 + 1] - cellXs[$0] }
        let measured = Bar(
            columnWidth: columnWidth,
            frameWidth: control.frame.width,
            drawnTrackWidth: geometry.track.map { $0.1 } ?? 0,
            dividers: geometry.dividers,
            drawnCellCount: cellXs.count,
            drawnCellSteps: steps,
            labels: (0 ..< control.segmentCount).map { control.label(forSegment: $0) ?? "" },
            clipWidth: clipWidth
        )
        window.orderOut(nil)
        return measured
    }

    /// Run the run loop so SwiftUI's deferred layout pass completes, then
    /// flush the AppKit side.
    private func settle(window: NSWindow, host: NSView) {
        for _ in 0 ..< 12 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
    }

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

    /// The scroll viewport that clips the bar, if the bar is in one.
    ///
    /// This looks for the viewport a scroll container puts around its
    /// content, NOT merely any ancestor that clips: the hosting view at the
    /// root of the measurement clips too, and counting it would make an
    /// unclipped bar look clipped. SwiftUI builds its scroll container
    /// from a clip view (`HostingClipView`; AppKit's own is `NSClipView`),
    /// so the viewport is recognised by that role rather than by the
    /// enclosing class being a stock `NSScrollView`.
    private static func scrollViewport(of view: NSView) -> NSView? {
        var ancestor = view.superview
        while let current = ancestor {
            if current is NSClipView
                || NSStringFromClass(type(of: current)).contains("ClipView")
            {
                return current
            }
            ancestor = current.superview
        }
        return nil
    }

    private static func width(of view: NSView) -> CGFloat {
        view.convert(view.bounds, to: nil).width
    }

    // MARK: - The bar follows the user's door

    @Test("A book the user creates in the tree shows up in the bar")
    func aCreatedBookShowsUpInTheBar() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // Before the door: the bar's two fixed pages and nothing else.
        let before = pages(for: fixture)
        #expect(before.map(\.title) == ["Wenshu", "Reference Library"])

        _ = try fixture.service.createBook(
            input: newBookInput("My Novel", shelfId: BookSessionLifecycle.defaultShelfID)
        )

        // After the door: the bar's pages carry the book the user just
        // created, = and the bar's own control draws them.
        let after = pages(for: fixture)
        #expect(after.map(\.title) == ["Wenshu", "My Novel", "Reference Library"])

        let bar = measure(pages: after, columnWidth: 600)
        #expect(
            bar.labels == ["Wenshu", "My Novel", "Reference Library"],
            """
            The bar's control drew \(bar.labels). = The book the user \
            created must be one of the bar's pages, = because the bar's \
            pages come from the app's shared book collection.
            """
        )
    }

    // MARK: - The bar divides its column

    @Test("The bar's pages divide the column it is given")
    func thePagesDivideTheColumn() {
        let columnWidth: CGFloat = 600
        let bar = measure(pages: Self.makePages(count: 3), columnWidth: columnWidth)

        #expect(
            abs(bar.frameWidth - columnWidth) < 1,
            """
            The bar's frame is \(bar.frameWidth) PT in a \(Int(columnWidth)) \
            PT column. = The bar's frame is pinned to the column, = so the \
            pages divide exactly that width, = and the bar spans the column \
            instead of hugging its left edge.
            """
        )
        #expect(
            bar.drawnCellCount == 3,
            """
            Three pages drew \(bar.drawnCellCount) cells; = every page must \
            be present, = sharing the column.
            """
        )
        let share = columnWidth / 3
        for (index, step) in bar.drawnCellSteps.enumerated() {
            #expect(
                abs(step - share) < 2,
                """
                The step from page \(index + 1) to page \(index + 2) is \
                \(step) PT; = it must be the region's share \
                (= \(Int(columnWidth)) / 3 = \(share) PT), = so every page \
                takes one equal share.
                """
            )
        }
    }

    @Test("A narrow column squeezes the pages instead of hiding them")
    func aNarrowColumnSqueezesThePages() {
        // The boss's rule (= 2026-11-12): the bar divides the column it
        // was given, = and NO page label has a minimum width. = a page
        // narrower than its own title shows less of it, = and a page
        // narrower than one character shows none, = and that is fine.
        //
        // So the floor the bar used to hold (= 88 PT per page, = which
        // made the bar claim more than its column) is gone, = and the
        // bar's frame is PINNED to the column's width, = so the
        // division is exact at any page count.
        let columnWidth: CGFloat = 200
        let bar = measure(pages: Self.makePages(count: 3), columnWidth: columnWidth)

        #expect(
            abs(bar.frameWidth - columnWidth) < 1,
            """
            The bar's frame is \(bar.frameWidth) PT in a \(Int(columnWidth)) \
            PT column. = The bar's frame is pinned to the column, = so the \
            pages divide exactly that width.
            """
        )
        #expect(
            bar.drawnCellCount == 3,
            """
            Three pages in a \(Int(columnWidth)) PT column drew \
            \(bar.drawnCellCount) cells; = it must draw three, = so \
            every page is present and squeezed, = not hidden.
            """
        )
    }

    @Test("More pages than the column holds still fit inside it")
    func overflowFitsInsideTheColumn() {
        // The overflow case is the one the old floor got wrong: twelve
        // pages in a 300 PT column used to claim twelve readable pages'
        // worth of width (= more than the column) and hide the tail
        // behind a scroll container. Now the bar's frame is the
        // column, = and the pages divide it, = so nothing is claimed
        // beyond the column and nothing is unreachable.
        let columnWidth: CGFloat = 300
        let pageCount = 12
        let bar = measure(pages: Self.makePages(count: pageCount), columnWidth: columnWidth)

        #expect(
            abs(bar.frameWidth - columnWidth) < 1,
            """
            A \(pageCount)-page bar's frame is \(bar.frameWidth) PT in a \
            \(Int(columnWidth)) PT column. = The bar never exceeds the \
            column it was given.
            """
        )
        #expect(
            bar.drawnCellCount == pageCount,
            """
            A \(pageCount)-page bar drew \(bar.drawnCellCount) cells; = it \
            must draw \(pageCount), = so every page is present.
            """
        )
        #expect(
            bar.drawnTrackWidth <= columnWidth + 1,
            """
            A \(pageCount)-page bar drew a \(bar.drawnTrackWidth) PT track \
            in a \(Int(columnWidth)) PT column. = The bar's cells must stay \
            inside the column.
            """
        )
        #expect(
            bar.clipWidth != nil,
            """
            A \(pageCount)-page bar in a \(Int(columnWidth)) PT column must \
            sit in a clipping container, = so a control that has not been \
            measured yet can never paint over the panel next door.
            """
        )
    }

    @Test("The bar's segment widths follow the column as it changes")
    func theWidthsFollowTheColumn() {
        for columnWidth in [CGFloat(300), 600, 900] {
            let bar = measure(pages: Self.makePages(count: 3), columnWidth: columnWidth)
            #expect(
                abs(bar.frameWidth - columnWidth) < 1,
                """
                In a \(Int(columnWidth)) PT column the bar's frame is \
                \(bar.frameWidth) PT. = The bar tracks the column it is \
                given, = so resizing the column resizes the bar.
                """
            )
        }
    }

    /// The bar's own pages, for a measurement that does not need a
    /// library on disk.
    private static func makePages(count: Int) -> [ChatScopePage] {
        (0 ..< count).map { index in
            ChatScopePage(
                scope: .book(BookID(rawValue: "00000000-0000-0000-0000-\(String(format: "%012d", index))")),
                title: "Page \(index)"
            )
        }
    }
}
