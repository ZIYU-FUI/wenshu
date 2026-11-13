//
//  EditorTabStripOverflowTests.swift - Wenshu
//
//  The editor column's width belongs to the writer, and the document tab
//  strip lives inside whatever width the writer chose.
//
//  The boss's rule (= 2026-11-12) is the browser's mechanism: the
//  region is divided into as many equal shares as there are tabs, the
//  strip never exceeds the region, and a tab label has NO minimum width
//  (= a tab may end up showing not one character, = and that is fine).
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
//    - the control's FRAME: the width the strip was given, = which the
//      frame pin (`LabelSegmentedControl.sizeThatFits`) makes equal to
//      the column at any tab count.
//    - the DRAWN TRACK: the width AppKit laid the segments out in. = the
//      control's own frame is the width SwiftUI gave it; = the track is
//      where the cells actually sit, = and the two differ when AppKit
//      keeps a cell at its label's own width. = the track is what says
//      whether the strip stayed inside its column.
//
//  The drawn track is measured from the control's layer tree: the cells
//  are the 1 PT hairline layers AppKit draws between them, = and those
//  positions are real pixels, = not an Accessibility frame (= the
//  Accessibility radio-button frame clamps to 24 PT whatever the real
//  width is, = so it cannot answer this question).
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Editor tab strip - the strip divides the column it was given")
struct EditorTabStripOverflowTests {
    /// What the strip claimed for itself, and where its cells landed.
    private struct Layout {
        var columnWidth: CGFloat
        /// The width the control's frame was given (= the column).
        var frameWidth: CGFloat
        /// The width the strip's DRAWN cells occupy.
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
        /// The number of CELLS the control has (= AppKit's own count,
        /// = `NSSegmentedControl.segmentCount`).
        ///
        /// MEASURED WHY THIS EXISTS: a cell whose label is the
        /// NOTHING MARKER draws no text at all, = and a cell with no
        /// text has no label layer, = so the number of PAINTED label
        /// layers is no longer the number of cells. = And a cell that
        /// paints nothing is the boss's rule, = not a missing tab:
        /// "缩到一定程度，那个...就没有意义了，不如只能显示...的时候，连...都不显示"
        /// (= once it shrinks so far that only the '…' would show, = that
        /// '…' has no meaning, = so show nothing at all). = ⇒ So "is
        /// the tab present" is asked of AppKit's own cell count, = and
        /// "did the cells divide the region" is asked of the drawn
        /// track and the drawn steps.
        var cellCount: Int
        /// The first container that clips the strip, if there is one.
        var clipWidth: CGFloat?
        var isClipped: Bool {
            clipWidth != nil
        }

        /// The width one cell takes (= the region's share).
        var share: CGFloat {
            columnWidth / CGFloat(max(dividers.count + 1, 1))
        }
    }

    /// The drawn geometry of a segmented control.
    ///
    /// AppKit draws one layer per cell's LABEL (= the `CGDrawingLayer`
    /// that paints the text) and one hairline between two cells. = the
    /// label layers' positions are the cells' positions, = so the step
    /// between two of them is the width one cell takes. = the track is
    /// the layer the cells sit on.
    ///
    /// Everything is read from the layer tree, = so it is real pixels, =
    /// not an Accessibility frame (= the Accessibility radio-button frame
    /// clamps to 24 PT whatever the real width is, = so it cannot answer
    /// this question).
    private static func drawnGeometry(
        of control: NSSegmentedControl
    ) -> (track: (CGFloat, CGFloat)?, labels: [CGFloat], dividers: [CGFloat]) {
        var track: (CGFloat, CGFloat)?
        var labelPositions: [CGFloat] = []
        var rawDividers: [CGFloat] = []

        func scan(_ layer: CALayer) {
            let frame = layer.frame
            let name = String(describing: type(of: layer))
            if name == "CGDrawingLayer" {
                // A cell's label. = its x is the cell's x.
                labelPositions.append(frame.origin.x)
            } else if name == "CALayer" {
                // A divider = the hairline between two cells.
                if frame.width == 1, frame.height > 6, frame.height < 18 {
                    rawDividers.append(frame.origin.x)
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
        for position in rawDividers.sorted()
            where dividers.last.map({ abs($0 - position) > 0.5 }) ?? true
        {
            dividers.append(position)
        }
        return (track, labelPositions.sorted(), dividers)
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
        // so the measurement never shows on the writer's desktop. The
        // window is ordered FRONT (= offscreen, = so nothing shows on the
        // writer's desktop) because AppKit lays a segmented control's CELLS
        // out during a display pass: = a window that is never ordered front
        // keeps the cells at the width they had when the control was first
        // measured (= the control's own fitting width), = and the strip
        // then measures as if it overflowed. = the real app orders its
        // window front, = so the measurement must too.
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        settle(window: window, host: host)
        window.display()

        guard let control = Self.findSegmentedControl(in: host) else {
            Issue.record("The tab strip did not host an NSSegmentedControl.")
            window.orderOut(nil)
            return Layout(
                columnWidth: columnWidth,
                frameWidth: 0,
                drawnTrackWidth: 0,
                dividers: [],
                drawnCellCount: 0,
                drawnCellSteps: [],
                cellCount: 0,
                clipWidth: nil
            )
        }

        let geometry = Self.drawnGeometry(of: control)
        let clipWidth = Self.scrollViewport(of: control).map { Self.width(of: $0) }
        // The step from one cell to the next, = measured from the drawn
        // label layers (= one per cell).
        let cellXs = geometry.labels
        let steps = (0 ..< max(cellXs.count - 1, 0)).map { cellXs[$0 + 1] - cellXs[$0] }
        let layout = Layout(
            columnWidth: columnWidth,
            frameWidth: control.frame.width,
            drawnTrackWidth: geometry.track.map { $0.1 } ?? 0,
            dividers: geometry.dividers,
            drawnCellCount: cellXs.count,
            drawnCellSteps: steps,
            cellCount: control.segmentCount,
            clipWidth: clipWidth
        )
        window.orderOut(nil)
        return layout
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

    private func makeTabs(count: Int) -> [EditorTab] {
        (0 ..< count).map { index in
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

    // MARK: - The strip divides the column it was given

    @Test(
        "The strip's frame is the column it was given",
        arguments: [1, 3, 5, 9, 12, 20, 30]
    )
    func theFramesTheColumn(tabCount: Int) {
        // The defect scaled with the tab count while the column did not:
        // the strip's own width grew one segment at a time no matter where
        // the writer dragged the divider.
        //
        // The boss's rule (= 2026-11-12) is the browser's mechanism: the
        // region is divided into as many equal shares as there are tabs,
        // the strip never exceeds the region, and a tab label has no
        // minimum width (= a tab may end up showing not one character).
        //
        // So the strip's frame IS the column, = at any tab count.
        let columnWidth: CGFloat = 454.5
        let layout = measure(tabCount: tabCount, columnWidth: columnWidth)
        #expect(
            abs(layout.frameWidth - columnWidth) < 1,
            """
            A \(tabCount)-tab strip's frame is \(layout.frameWidth) PT in a \
            \(columnWidth) PT column. = The strip's frame is pinned to the \
            column, = so the tabs divide exactly that width, = and the strip \
            never exceeds the region.
            """
        )
    }

    @Test(
        "The tabs divide the column equally",
        arguments: [3, 5, 9, 12, 20]
    )
    func theTabsDivideTheColumn(tabCount: Int) {
        // The equal division, = measured from the drawn cells (= the
        // label layers AppKit paints one per cell). = each cell takes one
        // share of the region, = and no cell is wider than the share, = so
        // the strip cannot overflow.
        //
        // The boundary is measured from the drawn cells rather than from
        // the hairline dividers: = AppKit draws a divider only between two
        // cells that are wide enough to hold one (= MEASURED: 3 cells in a
        // 200 PT region drew ONE divider for THREE cells), = so a divider
        // count would answer a different question than the one asked here.
        let columnWidth: CGFloat = 454.5
        let layout = measure(tabCount: tabCount, columnWidth: columnWidth)
        let share = columnWidth / CGFloat(tabCount)

        #expect(
            layout.drawnCellCount == tabCount,
            """
            A \(tabCount)-tab strip drew \(layout.drawnCellCount) cells. = \
            Every tab must be present, = squeezed to its share, = not \
            hidden.
            """
        )

        for (index, step) in layout.drawnCellSteps.enumerated() {
            #expect(
                abs(step - share) < 2,
                """
                The step from cell \(index + 1) to cell \(index + 2) is \
                \(step) PT; = it must be the region's share \
                (= \(columnWidth) / \(tabCount) = \(share) PT), = so every \
                cell takes one equal share.
                """
            )
        }
    }

    @Test(
        "A narrow column squeezes the tabs instead of hiding them",
        arguments: [5, 9, 12]
    )
    func aNarrowColumnSqueezesTheTabs(tabCount: Int) {
        // The boss's rule (= 2026-11-12): the strip divides the column it
        // was given, = and NO tab label has a minimum width. = a tab
        // narrower than its own title shows less of it, = and a tab
        // narrower than one character shows none, = and that is fine.
        //
        // So the floor the strip used to hold (= 88 PT per tab, = which
        // made the strip claim more than its column) is gone, = and the
        // strip's frame is PINNED to the column's width, = so the
        // division is exact at any tab count.
        let columnWidth: CGFloat = 200
        let layout = measure(tabCount: tabCount, columnWidth: columnWidth)

        #expect(
            abs(layout.frameWidth - columnWidth) < 1,
            """
            A \(tabCount)-tab strip's frame is \(layout.frameWidth) PT in a \
            \(Int(columnWidth)) PT column. = The strip's frame is pinned to \
            the column, = so the tabs divide exactly that width.
            """
        )
        // The tab's PRESENCE is AppKit's own cell count, = and not the
        // number of painted label layers: = a cell that is squeezed
        // past the width of one character paints NOTHING (= the boss's
        // rule), = and a cell with no text has no label layer to
        // count. = So the painted count would answer a different
        // question than the one asked here.
        #expect(
            layout.cellCount == tabCount,
            """
            A \(tabCount)-tab strip in a \(Int(columnWidth)) PT column has \
            \(layout.cellCount) cells; = it must have \(tabCount), = so \
            every tab is present and squeezed, = not hidden.
            """
        )
        // And the cells stay inside the column they were given.
        #expect(
            layout.drawnTrackWidth <= columnWidth + 1,
            """
            A \(tabCount)-tab strip in a \(Int(columnWidth)) PT column drew a \
            \(layout.drawnTrackWidth) PT track. = The strip's cells must stay \
            inside the column they were given.
            """
        )
    }

    @Test("The strip's drawn cells stay inside its column")
    func theDrawnCellsStayInside() {
        // The drawn track = where the cells actually sit. = it must not
        // be wider than the column, = or the strip paints over the panel
        // next door.
        //
        // This is the assertion that caught the real defect: = AppKit's
        // own `.fillEqually` distribution does NOT divide a cell narrower
        // than that cell's own label, = and a 3-tab strip in a 200 PT
        // column came out 239 PT wide (= 39 PT over the column) because of
        // it. = the strip sets each cell's width EXPLICITLY, = so the
        // cells divide the region and the label is clipped to its cell.
        for tabCount in [3, 5, 9, 12] {
            for columnWidth in [CGFloat(200), 454.5] {
                let layout = measure(tabCount: tabCount, columnWidth: columnWidth)
                #expect(
                    layout.drawnTrackWidth <= columnWidth + 1,
                    """
                    \(tabCount) tabs in a \(columnWidth) PT column drew a \
                    \(layout.drawnTrackWidth) PT track. = The strip's cells \
                    must stay inside the column they were given.
                    """
                )
            }
        }
    }

    @Test("The strip is clipped to its column, at any tab count")
    func stripIsClippedToItsColumn() {
        for columnWidth in [CGFloat(289.5), 454.5, 689.5, 1000] {
            let layout = measure(tabCount: 9, columnWidth: columnWidth)
            #expect(
                layout.isClipped,
                """
                A 9-tab strip in a \(columnWidth) PT column has no clipping \
                container. = Without one the strip draws over the panel \
                beside the column.
                """
            )
        }
    }

    @Test("Few tabs still fill the column they are given")
    func fewTabsFillTheColumn() {
        // The fix must not cost the fill behaviour: with room to spare the
        // tabs divide the whole column rather than huddling at the left
        // edge at their minimum width.
        let columnWidth: CGFloat = 900
        let layout = measure(tabCount: 3, columnWidth: columnWidth)
        #expect(
            abs(layout.frameWidth - columnWidth) < 1,
            """
            Three tabs in a \(Int(columnWidth)) PT column took a \
            \(layout.frameWidth) PT frame; they should take the column \
            (=\(Int(columnWidth)) PT).
            """
        )
        #expect(
            layout.drawnCellCount == 3,
            """
            Three tabs in a \(Int(columnWidth)) PT column drew \
            \(layout.drawnCellCount) cells; = there must be three.
            """
        )
    }

    // MARK: - The width rule is shared

    @Test("The share is the region's width over the tab count, with no floor")
    func theShareHasNoFloor() {
        // The rule itself, = measured as a pure function: = the share is
        // the region's width divided by the tab count, = and it is NEVER
        // floored. = a tab count that would push the share under the old
        // 88 PT floor still returns the plain share.
        for tabCount in [1, 5, 12, 20, 30] {
            let share = PaneTabStripWidth.segmentWidth(
                columnWidth: 454.5,
                segmentCount: tabCount
            )
            #expect(
                abs(share - 454.5 / CGFloat(tabCount)) < 0.001,
                """
                \(tabCount) tabs in a 454.5 PT column took \(share) PT each; \
                the share must be 454.5 / \(tabCount) PT, = with no floor.
                """
            )
        }
        // The floor that used to live here (= 88 PT) is gone: = 30 tabs
        // in a 454.5 PT column take 15.15 PT each, = which is far below
        // the old floor and is exactly what the boss asked for.
        #expect(
            PaneTabStripWidth.segmentWidth(columnWidth: 454.5, segmentCount: 30) < 88,
            """
            The share must not be floored: = the boss's rule is that a tab \
            may end up showing not one character.
            """
        )
    }

    @Test("An unmeasured column yields no share")
    func anUnmeasuredColumnYieldsNoShare() {
        // A zero column width (= the strip has not been measured yet) and
        // a zero tab count both yield zero, = which leaves the control on
        // its own fitting width until the first measurement lands.
        #expect(PaneTabStripWidth.segmentWidth(columnWidth: 0, segmentCount: 5) == 0)
        #expect(PaneTabStripWidth.segmentWidth(columnWidth: 454.5, segmentCount: 0) == 0)
    }
}
