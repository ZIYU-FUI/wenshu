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
//  - the bar fills the column it is given: the pages divide the width
//    the bar was measured at, = so the bar spans the column instead of
//    hugging its left edge, = and the overflow scrolls.
//
//  Method: the real `ChatZoneTabBar` is hosted in a real `NSHostingView`
//  at a real column width, then the AppKit view tree is walked to the
//  `NSSegmentedControl` the bar draws. A property assertion would not
//  prove either claim: = the defect was a rendering behaviour, = and a
//  control that holds the right labels can still paint them at the
//  wrong width.

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
        /// The width the control claims for itself.
        var claimedWidth: CGFloat
        /// The width of the control's first segment.
        var segmentWidth: CGFloat
        /// The width of every segment (= the segments are equal).
        var segmentWidths: [CGFloat]
        /// The labels the control drew.
        var labels: [String]
        /// The width of the container that clips the control, if any.
        var clipWidth: CGFloat?
    }

    /// Host the real bar at `columnWidth` and measure what it drew.
    private func measure(pages: [ChatScopePage], columnWidth: CGFloat) -> Bar {
        let bar = ChatZoneTabBar(
            pages: pages,
            selectedScope: pages.first?.scope ?? .repository,
            onSelect: { _ in }
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
        settle(window: window, host: host)

        guard let control = Self.findSegmentedControl(in: host) else {
            Issue.record("The chat zone's tab bar did not host an NSSegmentedControl.")
            window.orderOut(nil)
            return Bar(
                columnWidth: columnWidth,
                claimedWidth: 0,
                segmentWidth: 0,
                segmentWidths: [],
                labels: [],
                clipWidth: nil
            )
        }

        let clipWidth = Self.scrollViewport(of: control).map { Self.width(of: $0) }
        let measured = Bar(
            columnWidth: columnWidth,
            claimedWidth: control.intrinsicContentSize.width,
            segmentWidth: control.width(forSegment: 0),
            segmentWidths: (0 ..< control.segmentCount).map { control.width(forSegment: $0) },
            labels: (0 ..< control.segmentCount).map { control.label(forSegment: $0) ?? "" },
            clipWidth: clipWidth
        )
        window.orderOut(nil)
        return measured
    }

    /// Run the run loop so SwiftUI's deferred layout pass completes, then
    /// flush the AppKit side.
    private func settle(window: NSWindow, host: NSView) {
        for _ in 0 ..< 3 {
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
    /// content, NOT merely any ancestor that clips: the hosting view at
    /// the root of the measurement clips too, and counting it would make
    /// an unclipped bar look clipped.
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

    /// Narrowest segment that still shows a name.
    ///
    /// Spelled out here rather than read back from the view, so the
    /// expectation is independent of the value the bar happens to use.
    private static let readableSegmentFloor: CGFloat = 88

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

    // MARK: - The bar fills its column

    @Test("The bar's pages divide the column it is given")
    func thePagesDivideTheColumn() {
        let columnWidth: CGFloat = 600
        let bar = measure(pages: Self.makePages(count: 3), columnWidth: columnWidth)

        #expect(
            abs(bar.claimedWidth - columnWidth) < 1,
            """
            The bar claimed \(bar.claimedWidth) PT in a \(Int(columnWidth)) \
            PT column. = The pages must divide the column, = so the bar \
            spans it instead of hugging its left edge.
            """
        )
        for (index, width) in bar.segmentWidths.enumerated() {
            #expect(
                abs(width - columnWidth / 3) < 1,
                """
                Segment \(index) took \(width) PT; = each of the three \
                pages must take a third of the column \
                (=\(columnWidth / 3) PT).
                """
            )
        }
    }

    @Test("A narrow column still shows a page name")
    func aNarrowColumnStillShowsAName() {
        let bar = measure(pages: Self.makePages(count: 3), columnWidth: 200)

        for (index, width) in bar.segmentWidths.enumerated() {
            #expect(
                width >= Self.readableSegmentFloor - 0.5,
                """
                Segment \(index) took \(width) PT, = narrower than the \
                \(Int(Self.readableSegmentFloor)) PT floor that keeps a page \
                name readable.
                """
            )
        }
    }

    @Test("More pages than the column holds scroll instead of being cut off")
    func overflowScrolls() {
        let columnWidth: CGFloat = 300
        let pageCount = 12
        let bar = measure(pages: Self.makePages(count: pageCount), columnWidth: columnWidth)

        #expect(
            bar.clipWidth != nil,
            """
            A \(pageCount)-page bar in a \(Int(columnWidth)) PT column must \
            sit in a clipping container, = otherwise its tail pages are \
            simply unreachable.
            """
        )
        #expect(
            bar.claimedWidth > columnWidth,
            """
            The scroll container is only doing work if the bar's content is \
            wider than the column (it claims \(bar.claimedWidth) PT, = the \
            column is \(Int(columnWidth)) PT).
            """
        )
        #expect(
            bar.segmentWidths.allSatisfy { $0 >= Self.readableSegmentFloor - 0.5 },
            """
            Each page must keep the \(Int(Self.readableSegmentFloor)) PT \
            readable floor, = and the overflow goes to the scroll container \
            instead of squeezing the names.
            """
        )
    }

    @Test("The bar's segment widths follow the column as it changes")
    func theWidthsFollowTheColumn() {
        for columnWidth in [CGFloat(300), 600, 900] {
            let bar = measure(pages: Self.makePages(count: 3), columnWidth: columnWidth)
            #expect(
                abs(bar.claimedWidth - columnWidth) < 1,
                """
                In a \(Int(columnWidth)) PT column the bar claimed \
                \(bar.claimedWidth) PT. = The bar tracks the column it is \
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
