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
//  3. THE PLATE IS CENTRED IN THE BAND'S 28 PT ROW, = AND EVERY COLUMN
//     DRAWS THAT PLATE ON ONE LINE. = (2026-11-19 老板: 「上下的位置有
//     差异，那个也一并改」.) = A component that measured its width with a
//     `GeometryReader` also took the band's whole HEIGHT and placed the
//     control at its top, = which lifted the two side columns' plate 2 PT
//     off the chat zone's line. = The control's height is now the system's
//     own, = so every band centres the same plate on the same line.
//
//  ⇒ ⇒ ⇒ THE PLATE IS MEASURED, NOT THE CONTROL'S FRAME. = The frame
//  is where the app PUT the control; = the plate is what the user SEES,
//  = and it is a layer the system draws (= the `CABackdropLayer` inside
//  the cell's `SDFLayer`). = A test that reads the frame answers a
//  different question than the one the ruling asks, = and MEASURED
//  2026-11-19 the two answers differ: = the plate's own rect sits 4 PT
//  below the control's own top edge (= the frame's top is 2 PT below the
//  band's, = the plate's is 4), = so a frame-only test would have called
//  the chat zone's band centred while its PLATE sat half a line lower.
//
//  ⇒ ⇒ ⇒ AND THE CHAT ZONE'S BAND IS MEASURED AS ITSELF. = The chat
//  zone's bar is a `ScrollView(.horizontal)` with the switcher inside
//  it, = so it is NOT the side columns' band with a different label: = it
//  is a different container, = and a test that measures only the side
//  columns' band never touched it. = So the chat zone's REAL bar (= the
//  `ChatZoneTabBar` the app draws, = in the app's own scroll container)
//  is measured here too, = and the two bands' plates are compared.
//
//  ⇒ ⇒ ⇒ AND THE SIDE COLUMNS ARE THE CHAT ZONE'S REFERENCE. = The
//  boss ruled the chat zone's bar the correct one (= 「聊天区的最正确」),
//  = so the line to hit is the chat zone's, = and the two side columns
//  are measured against it.
//
//  swift test --filter TabPickerBandGeometryTests
//

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp
import WenshuData

@Suite("Tab picker band geometry")
@MainActor
struct TabPickerBandGeometryTests {
    private static let column: CGFloat = 320
    private static let bandWidth: CGFloat = 320 - 2 * DesignTokens.spacingRelaxed

    /// What a band drew, read off the real view tree.
    ///
    /// - The control's frame: = where the app PUT the control.
    /// - The plate's rect: = the glass the system drew UNDER the
    ///   selected tab (= the layer that carries `CABackdropLayer`), = in
    ///   the band's own coordinates. = This is the thing the user sees.
    private struct Drawing {
        /// The control's frame in the band's coordinates.
        let controlFrame: CGRect
        /// The drawn glass plate's rect in the band's coordinates.
        let plateFrame: CGRect
        /// The band's own height.
        let bandHeight: CGFloat
        /// The x of each tab's drawn label (= the cell's own position).
        let cellCentres: [CGFloat]
        /// Whether the system distributed the tabs equally.
        let distributesEqually: Bool
        /// How many tabs the control carries.
        let segments: Int
    }

    /// Host a band and measure what it drew.
    ///
    /// = `NSSegmentedControl.width(forSegment:)` is not used: = it answers
    /// "what width did the app set for this cell", = which reads 0 for a
    /// cell the system lays out. = The cells are read off the layers the
    /// control drew instead.
    private func render(
        column: CGFloat
    ) -> Drawing {
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

        let (host, window) = Self.host(root, width: column, height: DesignTokens.paneTabHotArea)
        defer { window.orderOut(nil) }

        guard let control = Self.findControl(in: host) else {
            Issue.record("The band did not host an NSSegmentedControl.")
            return Drawing(
                controlFrame: .zero,
                plateFrame: .zero,
                bandHeight: host.bounds.height,
                cellCentres: [],
                distributesEqually: false,
                segments: 0
            )
        }
        let controlFrame = control.convert(control.bounds, to: host)
        let plateFrame = Self.plateRect(of: control).map { control.convert($0, to: host) } ?? .zero
        return Drawing(
            controlFrame: controlFrame,
            plateFrame: plateFrame,
            bandHeight: host.bounds.height,
            cellCentres: Self.drawnCellCentres(of: control),
            distributesEqually: control.segmentDistribution == .fillEqually,
            segments: control.segmentCount
        )
    }

    /// Host the chat zone's REAL band and measure what it drew.
    ///
    /// = The chat zone's bar is its own container (= a horizontal scroll
    /// view around the switcher), = so it is measured here as the app
    /// builds it, = and not as a relabelled side band.
    private func renderChatBand(
        column: CGFloat,
        pages: Int
    ) -> Drawing {
        let pageList = (0 ..< pages).map { index in
            ChatScopePage(
                scope: .book(BookID(rawValue: "00000000-0000-0000-0000-\(String(format: "%012d", index))")),
                title: "Page \(index)"
            )
        }
        let bar = ChatZoneTabBar.unwired(
            pages: pageList,
            selectedScope: pageList[0].scope
        )
        let root = AnyView(bar.frame(width: column))
        let (host, window) = Self.host(root, width: column, height: 68)
        defer { window.orderOut(nil) }

        guard let control = Self.findControl(in: host) else {
            Issue.record("The chat zone's bar did not host an NSSegmentedControl.")
            return Drawing(
                controlFrame: .zero,
                plateFrame: .zero,
                bandHeight: host.bounds.height,
                cellCentres: [],
                distributesEqually: false,
                segments: 0
            )
        }
        let controlFrame = control.convert(control.bounds, to: host)
        let plateFrame = Self.plateRect(of: control).map { control.convert($0, to: host) } ?? .zero
        return Drawing(
            controlFrame: controlFrame,
            plateFrame: plateFrame,
            bandHeight: host.bounds.height,
            cellCentres: Self.drawnCellCentres(of: control),
            distributesEqually: control.segmentDistribution == .fillEqually,
            segments: control.segmentCount
        )
    }

    /// Host a view in a real window and let AppKit draw it.
    ///
    /// = An offscreen window gives AppKit the display context it needs to
    /// lay a segmented control's cells out (= the same reason the chat
    /// zone's suite orders its window front). = It sits far outside the
    /// screen, = so nothing shows on the writer's desktop.
    private static func host<V: View>(
        _ view: V,
        width: CGFloat,
        height: CGFloat
    ) -> (NSHostingView<AnyView>, NSWindow) {
        let host = NSHostingView(rootView: AnyView(view))
        host.frame = CGRect(x: 0, y: 0, width: width, height: height)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(CGPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0 ..< 12 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return (host, window)
    }

    /// The drawn glass plate's rect, in the control's own coordinates.
    ///
    /// = The plate is the layer that carries `CABackdropLayer` (= the
    /// system's own liquid glass, = drawn inside the selected cell's
    /// `SDFLayer`). = There is no other way to see where the glass is, = so
    /// this is the layer the ruling is about.
    private static func plateRect(of control: NSSegmentedControl) -> CGRect? {
        guard let root = control.layer else { return nil }
        var found: CALayer?
        func scan(_ layer: CALayer) {
            if found != nil {
                return
            }
            if String(describing: type(of: layer)) == "CABackdropLayer" {
                found = layer
                return
            }
            for sublayer in layer.sublayers ?? [] {
                scan(sublayer)
            }
        }
        scan(root)
        guard let plate = found else { return nil }
        return root.convert(plate.bounds, from: plate)
    }

    /// The centre of every cell's drawn label.
    ///
    /// = A cell CENTRES its label, = so the label's CENTRE is the cell's
    /// centre whatever the title's width (= its left edge is not: =
    /// measured 6 PT off on 书房 / 资料库). = The tab role draws no hairline
    /// between its cells, = so this is where the cells are.
    ///
    /// The selected cell draws its label twice (= once on the glass plate,
    /// once on the cell), = so the positions are deduplicated.
    private static func drawnCellCentres(of control: NSSegmentedControl) -> [CGFloat] {
        guard let root = control.layer else { return [] }
        var found: [CGFloat] = []
        func scan(_ layer: CALayer) {
            if String(describing: type(of: layer)) == "CGDrawingLayer" {
                found.append(layer.frame.midX)
            }
            for sublayer in layer.sublayers ?? [] {
                scan(sublayer)
            }
        }
        scan(root)
        var centres: [CGFloat] = []
        for position in found.sorted() {
            if centres.last.map({ abs($0 - position) > 1 }) ?? true {
                centres.append(position)
            }
        }
        return centres
    }

    private static func findControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl {
            return control
        }
        for subview in view.subviews {
            if let found = findControl(in: subview) {
                return found
            }
        }
        return nil
    }

    @Test("the band keeps its padding, and the switcher fills what the padding leaves")
    func paddingIsKeptAndTheSwitcherFillsTheBand() {
        let drawing = render(column: Self.column)
        #expect(drawing.segments == 3, "the band lost a tab")
        #expect(
            abs(drawing.controlFrame.minX - DesignTokens.spacingRelaxed) < 2,
            "the switcher starts at \(drawing.controlFrame.minX), not \(DesignTokens.spacingRelaxed) in"
        )
        #expect(
            abs(drawing.controlFrame.width - Self.bandWidth) < 2,
            "the switcher took \(drawing.controlFrame.width) in a \(Self.bandWidth) pt band"
        )
    }

    @Test("the tabs divide the band into equal cells")
    func theTabsDivideTheBand() {
        let drawing = render(column: Self.column)
        // The system is the one doing the arithmetic; = this says the
        // switcher asked for it.
        #expect(drawing.distributesEqually, "the control does not distribute its tabs across its frame")
        guard drawing.segments == 3 else { return }
        #expect(
            drawing.cellCentres.count == 3,
            "the band drew \(drawing.cellCentres.count) tab labels for 3 tabs"
        )
        guard drawing.cellCentres.count == 3 else { return }
        // A cell centres its label, = so consecutive labels sit one cell
        // apart, = and the cell is the band divided by the tab count.
        let share = Self.bandWidth / 3
        for (index, step) in (1 ..< drawing.cellCentres.count)
            .map({ drawing.cellCentres[$0] - drawing.cellCentres[$0 - 1] })
            .enumerated()
        {
            #expect(
                abs(step - share) < 2,
                "tab \(index) is \(step) from the previous one, not its \(share) pt share"
            )
        }
    }

    @Test("the plate is centred in the band's row, so every column's line is one line")
    func thePlateIsCentredInTheBand() {
        let drawing = render(column: Self.column)
        let bandMiddle = drawing.bandHeight / 2
        // The PLATE, = not the control's frame: = the frame is where the
        // app put the control, = the plate is what the user sees.
        #expect(
            drawing.plateFrame.height > 0,
            "the band drew no glass plate (= the system's own backdrop layer is missing)"
        )
        #expect(
            abs(drawing.plateFrame.midY - bandMiddle) < 1,
            "the plate's centre is \(drawing.plateFrame.midY) in a \(drawing.bandHeight) pt band"
        )
        // The band keeps its air: the plate is the system's own height,
        // not a block stretched to the row.
        #expect(
            drawing.plateFrame.height < drawing.bandHeight,
            "the plate filled the row (= \(drawing.plateFrame.height) pt) instead of leaving air"
        )
    }

    @Test("the chat zone's band draws its plate on the same line as the side columns'")
    func theChatBandDrawsTheSameLine() {
        // The chat zone's bar is the reference: = the boss ruled it the
        // correct one (= 「聊天区的最正确」).
        let chat = renderChatBand(column: Self.column, pages: 3)
        let side = render(column: Self.column)
        #expect(chat.plateFrame.height > 0, "the chat zone's band drew no glass plate")
        #expect(side.plateFrame.height > 0, "the side band drew no glass plate")
        // The two bands sit at different heights in the window, = so the
        // line that matters is the plate's offset from ITS OWN band's
        // middle. = The boss's ruling is that the two are the same.
        let chatOffset = chat.plateFrame.midY - chat.bandHeight / 2
        let sideOffset = side.plateFrame.midY - side.bandHeight / 2
        // The measured deltas are PRINTED, = not only reported on failure:
        // the record states the number these two bands actually measure,
        // = so a green run has to reproduce it (= a bound alone does not).
        print(
            "the plate's offset from its band's middle: the chat zone's \(chatOffset) pt, "
                + "the side column's \(sideOffset) pt"
        )
        #expect(
            abs(chatOffset - sideOffset) < 1,
            "the chat zone's plate sits \(chatOffset) pt off its band's middle, the side column's \(sideOffset) pt"
        )
    }

    @Test("the chat zone's band centres its plate at any page count")
    func theChatBandCentresItsPlateAtAnyPageCount() {
        // A band's row does not grow with the number of tabs in it, = so
        // the plate must land on the same line at 3 pages and at 12.
        for pages in [3, 12] {
            let drawing = renderChatBand(column: Self.column, pages: pages)
            #expect(drawing.plateFrame.height > 0, "the \(pages)-page bar drew no glass plate")
            #expect(
                abs(drawing.plateFrame.midY - drawing.bandHeight / 2) < 1,
                "the \(pages)-page bar's plate sits at \(drawing.plateFrame.midY) in a \(drawing.bandHeight) pt band"
            )
        }
    }

    @Test("the band follows the column when the column changes")
    func theBandFollowsTheColumn() {
        let wide = render(column: 480)
        #expect(
            abs(wide.controlFrame.width - (480 - 2 * DesignTokens.spacingRelaxed)) < 2,
            "a 480 pt column gave the switcher \(wide.controlFrame.width)"
        )
    }
}
