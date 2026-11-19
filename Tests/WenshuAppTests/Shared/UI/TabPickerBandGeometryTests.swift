//  TabPickerBandGeometryTests.swift · Wenshu
//
//  What a column's top band hands its page switcher, measured on the
//  rendered control (= a source read proves the wiring and nothing about
//  the pixels).
//
//  Three rulings, one per fact:
//
//  1. THE BAND'S PADDING IS ON PURPOSE. = (2026-11-19 老板:
//     「内边距不要删，那个是有意留的」.) = The switcher starts
//     `spacingRelaxed` in from the column's edge, = and the tree's rows
//     below it line up on the same inset.
//  2. THE SWITCHER FILLS WHAT THE PADDING LEAVES, = AND THE TABS DIVIDE
//     THAT WIDTH EQUALLY. = (the 2026-11-12 ruling, = restated 2026-11-19
//     as 「和聊天区一样就行」.) = The band proposes its own width and the
//     control's frame is pinned to that proposal, = so `.fillEqually`
//     divides the band instead of hugging the labels.
//  3. THE PLATE IS CENTRED IN THE BAND'S 28 PT ROW. = (2026-11-19 老板:
//     「上下的位置有差异，那个也一并改」.) = A component that measured its
//     width with a `GeometryReader` also took the band's whole HEIGHT and
//     placed the control at its top, = which lifted the two side columns'
//     plate 2 PT off the chat zone's line. = The control's height is now
//     the system's own, = so every band centres the same plate on the
//     same line.
//
//  swift test --filter TabPickerBandGeometryTests
//

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@Suite("Tab picker band geometry")
@MainActor
struct TabPickerBandGeometryTests {
    private static let column: CGFloat = 320
    private static let bandWidth: CGFloat = 320 - 2 * DesignTokens.spacingRelaxed

    /// The control's frame in the window's own space, = plus the x of each
    /// tab's drawn label (= the cell's own position), = as the band and the
    /// system leave them.
    ///
    /// = `NSSegmentedControl.width(forSegment:)` is not used: = it answers
    /// "what width did the app set for this cell", = which reads 0 for a
    /// cell the system lays out. = The cells are read off the layers the
    /// control drew instead.
    private func render(
        column: CGFloat
    ) -> (frame: NSRect, centres: [CGFloat], distributesEqually: Bool, segments: Int) {
        let root = AnyView(
            ChromeTopBar(
                horizontalPadding: DesignTokens.spacingRelaxed,
                usesMaterial: false
            ) {
                WenshuTabPicker(
                    selection: Binding(get: { 0 }, set: { _ in }),
                    labels: [0, 1, 2],
                    displayStrings: ["书房", "资料库", "参考书"],
                    controlSize: .small
                )
                .frame(maxWidth: .infinity)
                .frame(height: DesignTokens.paneTabHotArea)
            }
            .frame(height: DesignTokens.paneTabHotArea)
            .frame(width: column)
        )

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: column, height: DesignTokens.paneTabHotArea)
        // An offscreen window gives AppKit the display context it needs to
        // lay a segmented control's cells out (= the same reason the chat
        // zone's suite orders its window front).
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0 ..< 12 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        guard let control = Self.findControl(in: host) else {
            Issue.record("The band did not host an NSSegmentedControl.")
            window.orderOut(nil)
            return (.zero, [], false, 0)
        }
        let frame = control.convert(control.bounds, to: window.contentView)
        let centres = Self.drawnCellCentres(of: control)
        let segments = control.segmentCount
        let equally = control.segmentDistribution == .fillEqually
        window.orderOut(nil)
        return (frame, centres, equally, segments)
    }

    /// The centre of every cell's drawn label.
    ///
    /// = A cell CENTRES its label, = so the label's CENTRE is the cell's
    /// centre whatever the title's width (= its left edge is not: =
    /// measured 6 PT off on 书房 / 资料库). = The tab role draws no hairline
    /// between its cells, = so this is where the cells are.
    ///
    /// The selected cell draws its label twice (= once on the glass plate,
    /// = once on the cell), = so the positions are deduplicated.
    private static func drawnCellCentres(of control: NSSegmentedControl) -> [CGFloat] {
        var found: [CGFloat] = []
        func scan(_ layer: CALayer) {
            if String(describing: type(of: layer)) == "CGDrawingLayer" {
                found.append(layer.frame.midX)
            }
            for sub in layer.sublayers ?? [] { scan(sub) }
        }
        if let layer = control.layer { scan(layer) }
        var centres: [CGFloat] = []
        for position in found.sorted()
            where centres.last.map { abs($0 - position) > 1 } ?? true
        {
            centres.append(position)
        }
        return centres
    }

    private static func findControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for subview in view.subviews {
            if let found = findControl(in: subview) { return found }
        }
        return nil
    }

    @Test("the band keeps its padding, and the switcher fills what the padding leaves")
    func paddingIsKeptAndTheSwitcherFillsTheBand() {
        let (frame, _, _, segments) = render(column: Self.column)
        #expect(segments == 3, "the band lost a tab")
        #expect(
            abs(frame.minX - DesignTokens.spacingRelaxed) < 2,
            "the switcher starts at \(frame.minX), not \(DesignTokens.spacingRelaxed) in"
        )
        #expect(
            abs(frame.width - Self.bandWidth) < 2,
            "the switcher took \(frame.width) in a \(Self.bandWidth) pt band"
        )
    }

    @Test("the tabs divide the band into equal cells")
    func theTabsDivideTheBand() {
        let (_, centres, equally, segments) = render(column: Self.column)
        // The system is the one doing the arithmetic; = this says the
        // switcher asked for it.
        #expect(equally, "the control does not distribute its tabs across its frame")
        guard segments == 3 else { return }
        #expect(centres.count == 3, "the band drew \(centres.count) tab labels for 3 tabs")
        guard centres.count == 3 else { return }
        // A cell centres its label, = so consecutive labels sit one cell
        // apart, = and the cell is the band divided by the tab count.
        let share = Self.bandWidth / 3
        for (index, step) in (1 ..< centres.count).map({ centres[$0] - centres[$0 - 1] }).enumerated() {
            #expect(
                abs(step - share) < 2,
                "tab \(index) is \(step) from the previous one, not its \(share) pt share"
            )
        }
    }

    @Test("the plate is centred in the band's row, so every column's line is one line")
    func thePlateIsCentredInTheBand() {
        let (frame, _, _, _) = render(column: Self.column)
        let middle = DesignTokens.paneTabHotArea / 2
        #expect(
            abs(frame.midY - middle) < 1.5,
            "the plate's centre is \(frame.midY) in a \(DesignTokens.paneTabHotArea) pt band"
        )
        // The band keeps its air: the plate is the system's own height,
        // not a block stretched to the row.
        #expect(
            frame.height < DesignTokens.paneTabHotArea,
            "the plate filled the row (= \(frame.height) pt) instead of leaving air"
        )
    }

    @Test("the band follows the column when the column changes")
    func theBandFollowsTheColumn() {
        let wide = render(column: 480)
        #expect(
            abs(wide.frame.width - (480 - 2 * DesignTokens.spacingRelaxed)) < 2,
            "a 480 pt column gave the switcher \(wide.frame.width)"
        )
    }
}
