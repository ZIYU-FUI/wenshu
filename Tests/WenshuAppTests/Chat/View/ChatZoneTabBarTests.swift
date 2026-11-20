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
        /// The drawn CELLS (= one per page) and the STEP from one cell to
        /// the next (= the width one cell takes).
        ///
        /// The step is measured from the label layers rather than from
        /// the hairline dividers, = because the tab style draws no
        /// dividers at all (= MEASURED: = zero divider layers under the
        /// tab role), = and because the SELECTED cell draws its label
        /// twice (= once on the plate, = once on the cell), = so the
        /// positions are deduplicated before the steps are taken.
        var drawnCellCount: Int
        var drawnCellSteps: [CGFloat]
        /// The labels the control drew.
        var labels: [String]
        /// The width of the container that clips the control, if any.
        var clipWidth: CGFloat?
    }

    /// The drawn geometry of the control.
    ///
    /// The cells are counted off the CONTROL (`segmentCount`, one per
    /// page), not off the layer tree: = the system's tab style draws more
    /// label layers than it has segments (= 3 pages drew 4 label layers),
    /// = so a layer count answers a different question than the one the
    /// bar asks. The layer scan stays for the track and the clip, = which
    /// only the drawing knows.
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
        // The selected cell draws its label twice (= on the plate and on
        // the cell), = so the positions are deduplicated: = a duplicate
        // would read as a cell of zero width.
        var labels: [CGFloat] = []
        for position in labelPositions.sorted()
            where labels.last.map({ abs($0 - position) > 1 }) ?? true
        {
            labels.append(position)
        }
        return (track, dividers, labels)
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
            // The segments the control carries, = read off the control.
            drawnCellCount: control.segmentCount,
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

    // MARK: - The bar carries the system's switcher

    @Test("The bar carries one segment per page")
    func theBarCarriesOneSegmentPerPage() {
        // The switcher is Apple's own tab control (= `WenshuTabPicker` =
        // an `NSSegmentedControl` in the macOS 27 tab role, = because
        // SwiftUI's own `.tabs` picker sizes itself to its content and no
        // modifier stretches it), = so the fact the app owns is the
        // CONTENT of the segments: = one per page, = in page order, = with
        // the page's title on it.
        //
        // The cells are read off the CONTROL, = because the system's tab
        // style draws more label layers than it has segments (= MEASURED
        // 2026-11-19: = 3 pages drew 4 label layers), = and a layer count
        // would then count the drawing and not the pages.
        for pageCount in [3, 12] {
            let bar = measure(pages: Self.makePages(count: pageCount), columnWidth: 600)
            #expect(
                bar.drawnCellCount == pageCount,
                """
                A \(pageCount)-page bar carries \(bar.drawnCellCount) segments. = \
                Every page must have one, = and no page may share or invent one.
                """
            )
            #expect(
                bar.labels == Self.makePages(count: pageCount).map(\.title),
                """
                The bar's segments read \(bar.labels). = They must read the \
                page titles, in page order.
                """
            )
        }
    }

    @Test("The switcher fills the column and the tabs divide it")
    func theSwitcherFillsTheColumnAndTheTabsDivideIt() {
        // The bar divides the column it is given, = and every page takes one
        // equal share.
        //
        // The switcher is Apple's own tab control (= `WenshuTabPicker`),
        // and the system does NOT size it to its content (= MEASURED
        // 2026-11-19: = a SwiftUI `.tabs` picker measured 207 PT in a
        // 600 PT column, = centred, = and no SwiftUI modifier stretched
        // it), = so the app pins the control's frame to the band and the
        // system's own `.fillEqually` divides it.
        for columnWidth in [CGFloat(600), 300] {
            let bar = measure(pages: Self.makePages(count: 3), columnWidth: columnWidth)
            #expect(
                abs(bar.frameWidth - columnWidth) < 1,
                """
                In a \(Int(columnWidth)) PT column the switcher's frame is \
                \(bar.frameWidth) PT. = The frame is pinned to the column, = so the \
                tabs divide it instead of hugging their own content.
                """
            )
            let share = columnWidth / 3
            for (index, step) in bar.drawnCellSteps.enumerated() {
                #expect(
                    abs(step - share) < 2,
                    """
                    The step from page \(index + 1) to page \(index + 2) is \
                    \(step) PT; = it must be the column's share \
                    (= \(Int(columnWidth)) / 3 = \(share) PT), = so every page takes \
                    one equal share.
                    """
                )
            }
        }
    }

    @Test("The bar's band follows the column as it changes")
    func theBandFollowsTheColumn() {
        for columnWidth in [CGFloat(300), 600, 900] {
            let bar = measure(pages: Self.makePages(count: 3), columnWidth: columnWidth)
            #expect(
                abs(bar.frameWidth - columnWidth) < 1,
                """
                In a \(Int(columnWidth)) PT column the switcher's frame is \
                \(bar.frameWidth) PT. = The bar tracks the column it is given, = so \
                resizing the column resizes the bar.
                """
            )
        }
    }

    @Test("A narrow column keeps every page and clips the paint")
    func aNarrowColumnKeepsEveryPage() {
        // The page list never loses a page to a narrow column: = the
        // system keeps every segment, = and the band clips the paint.
        //
        // The clip is not decoration: = AppKit gives every cell AT LEAST
        // its title's width (= MEASURED 2026-11-19: = 12 pages in a
        // 300 PT column measured 29 PT per cell against a 25 PT share,
        // = so the row ran 48 PT past the frame = 12 x 29 - 300), = and a
        // row that paints past the column would paint over the panel next
        // door.
        let columnWidth: CGFloat = 200
        let bar = measure(pages: Self.makePages(count: 3), columnWidth: columnWidth)

        #expect(
            bar.drawnCellCount == 3,
            """
            Three pages in a \(Int(columnWidth)) PT column drew \(bar.drawnCellCount) \
            segments; = it must draw three, = so every page is present.
            """
        )
        #expect(
            bar.clipWidth != nil,
            """
            A \(Int(columnWidth)) PT column must still clip the bar, = so a row \
            that asks for more than the column cannot paint past it.
            """
        )
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
