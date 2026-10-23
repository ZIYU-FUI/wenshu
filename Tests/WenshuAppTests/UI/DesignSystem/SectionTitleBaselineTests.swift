// SectionTitleBaselineTests.swift · Wenshu
//
// The window's top row carries one run of labels: the sidebar's column
// title, the materials column's title, the editor's document tab titles
// and the inspector's column title. The eye reads that run as one line,
// so the labels must share ONE baseline.
//
// MEASURED on a 2x capture of the running app before the fix: the
// editor's document tab label painted its glyphs at 67.5 .. 78.5 PT
// while the column titles painted theirs at 70.5 .. 82.0 PT. The column
// titles therefore sat 3.00 PT BELOW the tab label beside them, and the
// row sagged in the middle.
//
// The measurement is the PAINTED pixels, not the proposed frame: the row
// of labels is rendered into an `NSBitmapImageRep` and the rows whose
// pixels carry ink are read back. A view that proposes one position but
// paints another is caught here. The pattern is the one
// `ChromeBottomFooterHeightTests` and `EditorTabStripSelectedLabelTests`
// already use.
//
// How the ink is found = by LUMINANCE. The row is rendered on a white
// backdrop in the light appearance, and a row carries glyph ink when it
// holds a pixel much darker than the surface the label sits on. That
// finds the label's own glyphs and leaves the segmented control's
// capsule (= a light surface) alone.
//
// The reference label is the app's OWN document tab label, rendered
// through the app's own `EditorTabStrip` (= the component the real tab
// strip is made of), so the test measures the label the app really
// paints and does not restate how that component is configured. The two
// columns are laid out side by side, each starting at its column top,
// exactly as the app's columns do: the app's columns all begin at the
// top of the workspace body, so the difference between the two labels'
// ink rows IS the difference between their baselines.

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Column-top title baseline")
@MainActor
struct SectionTitleBaselineTests {

    // MARK: - The measured facts

    /// The title the column top paints.
    ///
    /// It is a descender-free string (= the app's column titles are
    /// CJK, which is also descender-free), so its ink spans exactly the
    /// cap height (= the ink rows of any column title in the app).
    private static let columnTitle = "Draft"

    /// The document title the editor's tab strip paints.
    ///
    /// The SAME string as the column title, so the two labels are
    /// measured against the same glyphs: what the measurement compares
    /// is then the two baselines and nothing else.
    private static let documentTitle = "Draft"

    /// The two labels may sit at most this far apart, in points.
    ///
    /// MEASURED on a 2x capture of the running app after the fix: the
    /// column title painted its ink at 67.5 .. 79.0 PT and the document
    /// tab label at 67.5 .. 78.5 PT (= 0.00 PT and 0.50 PT apart).
    private static let baselineTolerance: CGFloat = 1

    /// The width of the column that carries the section title, in points.
    private static let titleColumnWidth: CGFloat = 220

    /// The width of the column that carries the document tab strip.
    private static let tabColumnWidth: CGFloat = 320

    /// The height of the rendered row of labels, in points.
    ///
    /// It only has to be taller than the two columns' tops; the columns
    /// are pinned to its top edge.
    private static let hostHeight: CGFloat = 160

    /// A pixel darker than this carries glyph ink.
    ///
    /// The label's glyphs are dark on a light surface; the segmented
    /// control's capsule and the column's backdrop are not.
    private static let glyphLuminanceLimit: Double = 140

    // MARK: - The facts

    @Test("The column title and the document tab label share one baseline")
    func theColumnTitleSharesTheTabLabelBaseline() throws {
        let rendered = render()

        guard let titleInk = glyphRows(
            in: rendered,
            xRange: 0..<Self.titleColumnWidth
        ), let tabInk = glyphRows(
            in: rendered,
            xRange: Self.titleColumnWidth..<(Self.titleColumnWidth + Self.tabColumnWidth)
        ) else {
            Issue.record("The column title or the document tab label painted no ink at all: the top row of the window would show a column with no title in it.")
            return
        }

        #expect(
            abs(titleInk.top - tabInk.top) <= Self.baselineTolerance,
            """
            The column title painted its ink at \(titleInk.top) .. \(titleInk.bottom) PT \
            while the document tab label painted its ink at \(tabInk.top) .. \(tabInk.bottom) PT. \
            Their tops are \(abs(titleInk.top - tabInk.top)) PT apart: the top row of the \
            window reads as a sagging line of labels instead of one straight run.
            """
        )
        #expect(
            abs(titleInk.bottom - tabInk.bottom) <= Self.baselineTolerance,
            """
            The column title painted its ink at \(titleInk.top) .. \(titleInk.bottom) PT \
            while the document tab label painted its ink at \(tabInk.top) .. \(tabInk.bottom) PT. \
            Their bottoms are \(abs(titleInk.bottom - tabInk.bottom)) PT apart: the top row of the \
            window reads as a sagging line of labels instead of one straight run.
            """
        )
    }

    @Test("The column top's divider stays where it was")
    func theColumnTopDividerDoesNotMove() throws {
        // The column top WITHOUT its title text: what is left painted
        // is the divider alone (= the two clear spacers paint nothing).
        let rendered = render(columnTitle: "")

        guard let dividerInk = paintedRows(in: rendered, xRange: 0..<Self.titleColumnWidth) else {
            Issue.record("The column top painted no divider at all: the search row below it would have nothing to key off.")
            return
        }

        // MEASURED on a 2x capture of the running app: the divider under
        // a column title paints at 88 PT, and the column top starts at
        // 52 PT, so it sits 36 PT below the column top. Lifting the
        // title text must not move it, or the search row below the column
        // top moves with it.
        #expect(
            abs(dividerInk.bottom - Self.dividerRowBelowColumnTop) <= Self.baselineTolerance,
            """
            The divider under the column title painted at \(dividerInk.bottom) PT below the column \
            top; it painted at \(Self.dividerRowBelowColumnTop) PT before the title text was \
            lifted. The divider is what the search row below the column top keys off, so \
            moving it moves that row.
            """
        )
    }

    /// Where the divider under a column title paints, measured from the
    /// top of the column that carries it.
    ///
    /// MEASURED on a 2x capture of the running app: the divider painted
    /// at 88 PT with the column top at 52 PT (= 36 PT below the column
    /// top).
    private static let dividerRowBelowColumnTop: CGFloat = 36

    // MARK: - The row of labels

    /// The document tab the strip renders.
    private static let tab = EditorTab(
        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        documentPath: "/tmp/wenshu-baseline-probe.md",
        draft: "",
        originalBody: "",
        mode: .preview,
        title: documentTitle
    )

    // MARK: - The measurement

    /// Render the row of labels and read back the pixels it painted.
    ///
    /// Both columns are hosted in ONE plain `NSView` (not in a
    /// `NSHostingView`): the segmented control only paints its label
    /// when it is a real AppKit subview of a real window, and the two
    /// columns have to land in the SAME bitmap for their ink rows to be
    /// comparable. Each column is then pinned to the top of the host, so
    /// the two labels start where the app's columns start (= the top of
    /// the workspace body).
    private func render(columnTitle: String = SectionTitleBaselineTests.columnTitle) -> NSBitmapImageRep {
        let width = Self.titleColumnWidth + Self.tabColumnWidth
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: Self.hostHeight))

        let titleColumn = NSHostingView(rootView:
            SectionHeader(
                title: columnTitle,
                showsDivider: true,
                trailingInset: false
            )
            .frame(width: Self.titleColumnWidth)
        )
        container.addSubview(titleColumn)

        let tabColumn = NSHostingView(rootView:
            EditorTabStrip(
                tabs: [Self.tab],
                selectedTabId: Self.tab.id,
                onSelect: { _ in },
                onClose: { _ in }
            )
            .frame(width: Self.tabColumnWidth)
        )
        container.addSubview(tabColumn)

        let window = NSWindow(
            contentRect: container.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        // The light appearance on a white backdrop: the app's labels are
        // dark on a light surface there, and the measurement's ink rule
        // depends on it.
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.contentView = container
        window.orderFront(nil)
        container.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        container.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        // Pin each column to the host's TOP (= the app's column top).
        let titleHeight = titleColumn.fittingSize.height
        let tabHeight = tabColumn.fittingSize.height
        titleColumn.frame = NSRect(
            x: 0,
            y: Self.hostHeight - titleHeight,
            width: Self.titleColumnWidth,
            height: titleHeight
        )
        tabColumn.frame = NSRect(
            x: Self.titleColumnWidth,
            y: Self.hostHeight - tabHeight,
            width: Self.tabColumnWidth,
            height: tabHeight
        )
        window.displayIfNeeded()

        let bounds = container.bounds
        let rep = container.bitmapImageRepForCachingDisplay(in: bounds)!
        rep.size = bounds.size
        // Paint the backdrop first, so a row that differs is a row the
        // view drew on.
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        bounds.fill()
        NSGraphicsContext.restoreGraphicsState()
        container.cacheDisplay(in: bounds, to: rep)

        window.orderOut(nil)
        return rep
    }

    /// The rows of a region that carry glyph ink, in points from the top.
    private func glyphRows(
        in rep: NSBitmapImageRep,
        xRange: Range<CGFloat>
    ) -> (top: CGFloat, bottom: CGFloat)? {
        guard let data = rep.bitmapData else { return nil }
        let scale = Self.scale(of: rep)
        let pxStart = Int(xRange.lowerBound * CGFloat(scale))
        let pxEnd = Int(xRange.upperBound * CGFloat(scale))
        var rows: [Int] = []
        for y in 0..<rep.pixelsHigh {
            for x in pxStart..<min(pxEnd, rep.pixelsWide) {
                let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
                let luminance = 0.299 * Double(data[offset])
                    + 0.587 * Double(data[offset + 1])
                    + 0.114 * Double(data[offset + 2])
                if luminance < Self.glyphLuminanceLimit {
                    rows.append(y)
                    break
                }
            }
        }
        guard let first = rows.first, let last = rows.last else { return nil }
        return (top: CGFloat(first) / scale, bottom: CGFloat(last + 1) / scale)
    }

    /// The rows of a region that carry ANY paint, in points from the top.
    ///
    /// This finds the hairline (= the divider) as well as the glyphs: the
    /// divider is a light hairline, so it is too light to be glyph ink.
    private func paintedRows(
        in rep: NSBitmapImageRep,
        xRange: Range<CGFloat>
    ) -> (top: CGFloat, bottom: CGFloat)? {
        guard let data = rep.bitmapData else { return nil }
        let scale = Self.scale(of: rep)
        let pxStart = Int(xRange.lowerBound * CGFloat(scale))
        let pxEnd = Int(xRange.upperBound * CGFloat(scale))
        var rows: [Int] = []
        for y in 0..<rep.pixelsHigh {
            for x in pxStart..<min(pxEnd, rep.pixelsWide) {
                let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
                if data[offset] < 245 || data[offset + 1] < 245 || data[offset + 2] < 245 {
                    rows.append(y)
                    break
                }
            }
        }
        guard let first = rows.first, let last = rows.last else { return nil }
        return (top: CGFloat(first) / scale, bottom: CGFloat(last + 1) / scale)
    }

    /// The device-pixel scale of a rendered bitmap.
    private static func scale(of rep: NSBitmapImageRep) -> Double {
        Double(rep.pixelsHigh) / Double(Self.hostHeight)
    }
}
