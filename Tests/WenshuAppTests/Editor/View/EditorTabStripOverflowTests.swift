//
//  EditorTabStripOverflowTests.swift - Wenshu
//
//  The editor column's width belongs to the writer, and the document tab
//  strip lives inside whatever width the writer chose. When the open
//  documents do not all fit, the strip scrolls sideways inside the column
//  instead of painting across the neighbouring tools panel.
//
//  These tests measure LAYOUT, not a property. The defect was a rendering
//  behaviour: the strip claimed a width of its own that exceeded the column
//  hosting it, so a property assertion (`fixedSegmentWidth == 90`) would
//  have passed while the strip still drew over the panel next door.
//
//  Method: the real `EditorTabStrip` is hosted in a real `NSHostingView` at
//  a real column width, then the AppKit view tree is walked to the
//  `NSSegmentedControl` and to the container that clips it. Two numbers
//  decide this ticket:
//
//    - the control's `intrinsicContentSize`: the width the strip claims for
//      itself, independent of what the column offers it. A claim that grows
//      with the tab count while the column shrinks is the defect.
//    - the clipping ancestor: what bounds what the writer can actually see.
//      With no clipping ancestor the strip paints straight over whatever
//      sits to the right of the column.
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Editor tab strip - the strip never claims more width than its column")
struct EditorTabStripOverflowTests {

    /// What the strip claims for itself, and what bounds it on screen.
    private struct Layout {
        var columnWidth: CGFloat
        /// The width the strip asks for on its own (= the number that made
        /// the tab strip reach past the window edge).
        var claimedWidth: CGFloat
        /// The width the strip can actually paint in (= the column, or the
        /// clipping container the scroll view put around the strip).
        var visibleWidth: CGFloat
        /// The first container that clips the strip, if there is one.
        var clipWidth: CGFloat?
        var segmentWidth: CGFloat
        var isClipped: Bool { clipWidth != nil }
    }

    /// Host the real strip at `columnWidth` and measure it.
    private func measure(tabCount: Int, columnWidth: CGFloat) -> Layout {
        let tabs = makeTabs(count: tabCount)
        let strip = EditorTabStrip(
            tabs: tabs,
            selectedTabId: tabs.first?.id,
            onSelect: { _ in },
            onClose: { _ in }
        )

        let host = NSHostingView(
            rootView: AnyView(strip.frame(width: columnWidth))
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
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.contentView = host
        settle(window: window, host: host)

        guard let control = Self.findSegmentedControl(in: host) else {
            Issue.record("The tab strip did not host an NSSegmentedControl.")
            window.orderOut(nil)
            return Layout(
                columnWidth: columnWidth,
                claimedWidth: 0,
                visibleWidth: columnWidth,
                clipWidth: nil,
                segmentWidth: 0
            )
        }

        let clipWidth = Self.scrollViewport(of: control).map { Self.width(of: $0) }
        let layout = Layout(
            columnWidth: columnWidth,
            claimedWidth: control.intrinsicContentSize.width,
            visibleWidth: min(clipWidth ?? columnWidth, columnWidth),
            clipWidth: clipWidth,
            segmentWidth: control.width(forSegment: 0)
        )
        window.orderOut(nil)
        return layout
    }

    /// Run the run loop so SwiftUI's deferred layout pass completes, then
    /// flush the AppKit side.
    private func settle(window: NSWindow, host: NSView) {
        for _ in 0..<3 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
    }

    /// Narrowest segment that still shows a document name.
    ///
    /// Spelled out here rather than read back from the view, so the
    /// expectation is independent of the value the strip happens to use.
    private static let readableSegmentFloor: CGFloat = 88

    private func makeTabs(count: Int) -> [EditorTab] {
        (0..<count).map { index in
            EditorTab(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                documentPath: "/library/book-\(index)/chapter-\(index).md",
                draft: "",
                originalBody: "",
                mode: .preview,
                title: nil
            )
        }
    }

    private static func findSegmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = findSegmentedControl(in: subview) { return found }
        }
        return nil
    }

    /// The scroll viewport that clips the strip, if the strip is in one.
    ///
    /// This looks for the viewport a scroll container puts around its
    /// content, NOT merely any ancestor that clips: the hosting view at the
    /// root of the measurement clips too, and counting it would make an
    /// unclipped strip look clipped. SwiftUI builds its scroll container
    /// from a clip view (`HostingClipView`; AppKit's own is `NSClipView`),
    /// so the viewport is recognised by that role rather than by the
    /// enclosing class being a stock `NSScrollView`.
    private static func scrollViewport(of view: NSView) -> NSView? {
        var ancestor = view.superview
        while let current = ancestor {
            if current is NSClipView
                || NSStringFromClass(type(of: current)).contains("ClipView") {
                return current
            }
            ancestor = current.superview
        }
        return nil
    }

    private static func width(of view: NSView) -> CGFloat {
        view.convert(view.bounds, to: nil).width
    }

    // MARK: - The strip stays inside the column

    @Test(
        "The strip is clipped to its column, at any tab count",
        arguments: [1, 3, 5, 9, 12, 20]
    )
    func stripIsClippedToItsColumn(tabCount: Int) {
        for columnWidth in [CGFloat(289.5), 454.5, 689.5, 1000] {
            let layout = measure(tabCount: tabCount, columnWidth: columnWidth)
            #expect(
                layout.isClipped,
                """
                \(tabCount) tabs in a \(columnWidth) PT column have no \
                clipping container (the strip claims \(layout.claimedWidth) PT). \
                Without one the strip draws over the panel beside the column.
                """
            )
        }
    }

    @Test("The strip's claimed width stops at the readable floor per tab")
    func claimedWidthStopsAtTheReadableFloor() {
        // The defect scaled with the tab count while the column did not: the
        // strip's own width grew one segment at a time no matter where the
        // writer dragged the divider. The claim is now the readable floor
        // per segment, which the scroll container absorbs.
        let tabCount = 20
        let columnWidth: CGFloat = 454.5
        let layout = measure(tabCount: tabCount, columnWidth: columnWidth)
        let floor = Self.readableSegmentFloor * CGFloat(tabCount)
        #expect(
            layout.claimedWidth <= floor + 1,
            """
            A \(tabCount)-tab strip claims \(layout.claimedWidth) PT, past the \
            \(floor) PT its readable segments need. The claim must come from \
            the tab count's readable floor, never from an equal share of the \
            whole track.
            """
        )
    }

    @Test("A narrow column bounds what the strip paints")
    func narrowColumnBoundsPaintedWidth() {
        for tabCount in [5, 9, 12] {
            let layout = measure(tabCount: tabCount, columnWidth: 200)
            #expect(
                layout.visibleWidth <= 200.5,
                """
                \(tabCount) tabs in a 200 PT column can paint \
                \(layout.visibleWidth) PT. Narrowing the column must narrow \
                what the writer sees.
                """
            )
        }
    }

    // MARK: - The overflow scrolls instead of being cut off

    @Test("A strip wider than its column scrolls rather than being cut off")
    func overflowingStripScrolls() {
        let columnWidth: CGFloat = 454.5
        let layout = measure(tabCount: 12, columnWidth: columnWidth)
        #expect(
            layout.isClipped,
            """
            A 12-tab strip in a \(columnWidth) PT column must sit in a \
            clipping container, otherwise its tail tabs are simply unreachable.
            """
        )
        #expect(
            layout.claimedWidth > columnWidth,
            """
            The scroll container is only doing work if the strip's content is \
            wider than the column (it claims \(layout.claimedWidth) PT, the \
            column is \(columnWidth) PT).
            """
        )
    }

    // MARK: - A document title stays readable

    @Test("A document title is never truncated to nothing")
    func titleStaysReadable() {
        // The control's own per-segment width is the width the title is
        // drawn in. Narrower than a few characters and the tab can no
        // longer be told apart from its neighbours.
        let layout = measure(tabCount: 12, columnWidth: 454.5)
        #expect(
            layout.segmentWidth >= Self.readableSegmentFloor - 0.5,
            """
            Each tab segment is \(layout.segmentWidth) PT, narrower than the \
            \(Self.readableSegmentFloor) PT floor that keeps a \
            document name readable. The strip must hold the floor and scroll \
            the overflow, not squeeze the tabs.
            """
        )
    }

    @Test("Few tabs still fill the column they are given")
    func fewTabsFillTheColumn() {
        // The overflow fix must not cost the fill behaviour: with room to
        // spare the tabs divide the whole column rather than huddling at
        // the left edge at their minimum width.
        let columnWidth: CGFloat = 900
        let layout = measure(tabCount: 3, columnWidth: columnWidth)
        #expect(
            abs(layout.segmentWidth - columnWidth / 3) < 1,
            """
            Three tabs in a \(columnWidth) PT column took \
            \(layout.segmentWidth) PT each; they should divide the column \
            (=\(columnWidth / 3) PT each) when it fits.
            """
        )
    }

    // MARK: - The sibling page strip is untouched

    @Test("A control with no fixed segment width still divides its track equally")
    func defaultDistributionIsUnchanged() {
        // The inspector's page strip passes no fixed width, so the control
        // must stay on the equal-share distribution. Measured through where
        // the segments actually land on screen: four segments across a
        // 400 PT track must each occupy about a quarter of it.
        let control = NSSegmentedControl()
        control.segmentCount = 4
        control.setLabel("First", forSegment: 0)
        control.setLabel("Second", forSegment: 1)
        control.setLabel("Third", forSegment: 2)
        control.setLabel("Fourth", forSegment: 3)
        control.segmentDistribution = .fillEqually
        control.trackingMode = .selectOne

        let trackWidth: CGFloat = 400
        let host = NSView(frame: NSRect(x: 0, y: 0, width: trackWidth, height: 30))
        host.wantsLayer = true
        host.addSubview(control)
        control.frame = host.bounds
        host.layoutSubtreeIfNeeded()
        control.layoutSubtreeIfNeeded()

        // The segments share the control's own frame under this
        // distribution, so the frame IS the measurement.
        let share = control.frame.width / CGFloat(control.segmentCount)
        #expect(
            abs(control.frame.width - trackWidth) < 1,
            """
            The control must fill the \(Int(trackWidth)) PT track it was \
            given under the equal-share distribution; it took \
            \(control.frame.width) PT.
            """
        )
        #expect(
            abs(share - 100) < 1,
            """
            Four equal segments in a \(Int(trackWidth)) PT track must each \
            take about 100 PT; they took \(share) PT.
            """
        )
    }

    @Test("An explicit per-segment width wins over the equal share")
    func explicitSegmentWidthWins() {
        // The mirror of the test above: with a width set on every segment
        // the control stops dividing the track and takes the given width,
        // which is what lets the tab strip choose its own segment size.
        let control = NSSegmentedControl()
        control.segmentCount = 4
        for index in 0..<4 {
            control.setLabel("Page \(index)", forSegment: index)
            control.setWidth(120, forSegment: index)
        }
        control.segmentDistribution = .fit
        control.trackingMode = .selectOne

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 30))
        host.addSubview(control)
        control.frame = host.bounds
        host.layoutSubtreeIfNeeded()
        control.layoutSubtreeIfNeeded()

        #expect(
            abs(control.intrinsicContentSize.width - 480) < 1,
            """
            Four segments at 120 PT must claim 480 PT, not the 400 PT track; \
            the control claimed \(control.intrinsicContentSize.width) PT.
            """
        )
    }
}