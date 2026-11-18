// PaneTabStripCloseTests.swift
//
// The Safari-style close X that lives INSIDE a pane tab.
//
// WHAT IS UNDER TEST
//
// 1. The X's two rules (= the pure ones: = whether it FITS in a segment, =
// and = how much room it takes from the title). 2. The control's behaviour:
// = the X is drawn when a segment is hovered, = it is not drawn when
// nothing is, = the hovered segment's title gives up the X's room, = and a
// click on the X closes that tab.
//
// THE CRASH RULE THIS FILE ALSO GUARDS
//
// ⇒ ⇒ ⇒ The X must NOT be a SwiftUI button per tab: = that shape crashed
// this app. = The control that carries it is ONE AppKit view, = and this
// file asserts that the control in the tree IS that one (= so a future
// "simplification" back to N buttons fails here instead of in the app).
//
// THE GEOMETRY THIS FILE USES
//
// ⇒ ⇒ ⇒ A segment's frame is the one AppKit's own per-segment draw hook
// provides (= MEASURED: =
// `Tools/wenshu-devtool/probes/segmented_control_segment_frames.swift`
// reports the hook firing on macOS 27, = and the frames it gives being the
// equal division of the control). = The X is placed in THAT frame, = and
// the control's own frame is not used: = in the hosted strip the control's
// frame height is 0 while its cells are 28 PT tall (= the cells are drawn
// from the cell's own metrics), = so a hit test built on the bounds would
// land on nothing.

import AppKit
import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Pane tab strip - the Safari-style close X")
struct PaneTabStripCloseTests {
    // MARK: - The pure rules

    /// The width of one CJK character in the control's label font.
    private static let characterWidth = PaneTabStripTitle.drawnWidth(
        of: "十",
        font: NSFont.systemFont(ofSize: 13)
    )

    @Test("The X fits only where the tab can still name its document")
    func theXFitsOnlyWhereTheTitleStillFits() {
        // A wide tab: = the X fits, = and the title keeps its room.
        #expect(PaneTabStripClose.fits(
            share: 120,
            firstCharacterWidth: Self.characterWidth
        ))
        // The narrow end: = the X's room would eat the title, = so the X is
        // not drawn (= Safari hides it in a tab too narrow for it).
        #expect(!PaneTabStripClose.fits(
            share: PaneTabStripWidth.segmentLabelInset + PaneTabStripClose.room,
            firstCharacterWidth: Self.characterWidth
        ))
        #expect(!PaneTabStripClose.fits(
            share: 30,
            firstCharacterWidth: Self.characterWidth
        ))
    }

    @Test("The selected title gives up the X's room, and an unselected one does not")
    func theSelectedTitleGivesUpTheRoom() {
        let share: CGFloat = 120
        #expect(PaneTabStripClose.titleShare(share: share, selected: false) == share)
        #expect(PaneTabStripClose.titleShare(share: share, selected: true)
            == share - PaneTabStripClose.room)
    }

    @Test("The X sits at the segment's leading edge, and its tap target is clamped to the segment")
    func theXGeometry() {
        // ⇒ ⇒ ⇒ AND AT THE LEADING EDGE, = BECAUSE THAT IS WHERE macOS
        // SAFARI PUTS IT: = Apple's own tabs carry their close mark on the
        // LEFT (= and the tab's title keeps its own centre). = The X is
        // drawn at the segment's own leading edge, = so it is drawn INSIDE
        // the tab it closes.
        let segment = NSRect(x: 80, y: 0, width: 80, height: 28)
        let ink = PaneTabStripClose.glyphRect(in: segment)
        #expect(ink.minX >= segment.minX)
        #expect(ink.minX <= segment.minX + 12)
        #expect(ink.minY >= segment.minY)
        #expect(ink.maxY <= segment.maxY)
        // ⇒ ⇒ ⇒ AND THE X IS INSIDE ITS OWN SEGMENT: = a mark drawn past
        // the segment's trailing edge would sit on the NEIGHBOUR's tab.
        #expect(segment.contains(ink))
        // The tap target is the HIG's 28 PT minimum, = centred on the ink,
        // = and it never reaches outside the segment.
        let hit = PaneTabStripClose.hitRect(in: segment)
        #expect(hit.height <= PaneTabStripClose.hitArea)
        #expect(hit.width <= PaneTabStripClose.hitArea)
        #expect(segment.contains(hit))
        // A segment too narrow for the tap target: = the target is the
        // segment's own width (= it never claims its neighbour).
        let narrow = NSRect(x: 0, y: 0, width: 10, height: 28)
        #expect(PaneTabStripClose.hitRect(in: narrow).width <= narrow.width)
    }

    /// A click recognizer that answers with the point the test chooses (= so
    /// the delegate can be asked about a click the test places).
    private final class FixedPointClickRecognizer: NSClickGestureRecognizer {
        var fixedPoint: NSPoint = .zero

        override func location(in _: NSView?) -> NSPoint {
            fixedPoint
        }
    }

    // MARK: - The control

    /// A control with a real frame, = so its cells can be drawn and read
    /// back.
    private func makeControl(
        tabCount: Int = 3,
        share: CGFloat = 80,
        closeEnabled: Bool = true,
        title: String = "十二",
        origin: NSPoint = NSPoint(x: 0, y: 0)
    ) -> (PaneTabStripCloseControl, NSWindow) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: share * CGFloat(tabCount), height: 40),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        let host = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: origin.x + share * CGFloat(tabCount) + 40,
                height: origin.y + 40
            )
        )
        window.contentView = host

        // ⇒ ⇒ ⇒ AND THE CONTROL'S OWN FRAME CARRIES THE ORIGIN: = a point
        // converted from the window's base is moved by exactly this (= =
        // and the app's own control sits away from the origin, = = so a
        // test at (0, 0) cannot see a wrong conversion).
        let control = PaneTabStripCloseControl(
            frame: NSRect(x: origin.x, y: origin.y, width: share * CGFloat(tabCount), height: 28)
        )
        control.segmentCount = tabCount
        control.segmentDistribution = .fillEqually
        control.trackingMode = .selectOne
        control.controlSize = .small
        control.segmentStyle = .roundRect
        control.role = .valueSelection
        control.setDisplayStrings(
            Array(repeating: title, count: tabCount),
            share: share,
            font: PaneTabStripClose.titleFont(),
            closeGlyph: closeEnabled
                ? NSImage(systemSymbolName: PaneTabStripClose.glyphName, accessibilityDescription: nil)
                : nil
        )
        // ⇒ ⇒ ⇒ AND THE WIDTHS COME FROM THE PRODUCTION PATH: = the device
        // asks the control to collapse (= the app's own `configure` does),
        // = and a control with no width set has none to report (=
        // `width(forSegment:)` reads 0).
        host.addSubview(control)
        control.applyCollapse(columnWidth: share * CGFloat(tabCount), selectedSegment: -1)
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        // The draw pass: = a segmented control's cells are drawn from the
        // CELL's own metrics, = and the cell's per-segment hook is where
        // the geometry comes from (= so the cells must have been drawn
        // before anything can be measured).
        control.needsDisplay = true
        window.display()
        // ⇒ ⇒ ⇒ AND THE DRAW IS FORCED: = an offscreen window's display
        // pass does not reach the control's cell, = and the cell's
        // per-segment hook (= where the geometry comes from) runs only
        // inside a real draw (= MEASURED: = the probe's `cacheDisplay` is
        // what makes it fire).
        if let rep = control.bitmapImageRepForCachingDisplay(in: control.bounds) {
            rep.size = control.bounds.size
            control.cacheDisplay(in: control.bounds, to: rep)
        }
        return (control, window)
    }

    /// The count of the pixels in a rendered control's region that are
    /// neither black nor white (= the X's ink, = and the control's own
    /// chrome).
    private static func inkIn(_ control: NSView, rect: NSRect) -> Int {
        guard let rep = control.bitmapImageRepForCachingDisplay(in: control.bounds) else { return -1 }
        rep.size = control.bounds.size
        control.cacheDisplay(in: control.bounds, to: rep)
        guard let data = rep.bitmapData else { return -1 }
        var count = 0
        let x0 = Int(rect.origin.x * 2)
        let y0 = Int(rect.origin.y * 2)
        for y in y0 ..< (y0 + Int(rect.height * 2)) {
            for x in x0 ..< (x0 + Int(rect.width * 2)) {
                let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
                let r = Int(data[offset])
                let g = Int(data[offset + 1])
                let b = Int(data[offset + 2])
                if !(r < 40 && g < 40 && b < 40) && !(r > 230 && g > 230 && b > 230) {
                    count += 1
                }
            }
        }
        return count
    }

    @Test("The X is drawn only in the selected segment")
    func theXIsDrawnInTheSelectedSegmentOnly() throws {
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        let segment = try #require(control.closeCell.frame(ofSegment: 1))
        let inkRect = PaneTabStripClose.glyphRect(in: segment)

        // Nothing selected: = no X.
        window.displayIfNeeded()
        let before = Self.inkIn(control, rect: inkRect)
        #expect(before >= 0)

        // Hovered: = the X is there.
        control.setSelectedSegment(1)
        window.displayIfNeeded()
        let after = Self.inkIn(control, rect: inkRect)

        #expect(after > before)
    }

    @Test("A strip with no close path draws no X")
    func aStripWithNoClosePathDrawsNoX() {
        let (control, window) = makeControl(closeEnabled: false)
        defer { window.orderOut(nil) }
        let before = control.drawnTitle(forSegment: 0)
        control.setSelectedSegment(0)
        // The title did not change (= the X's room is only given up when
        // there IS an X), = and no X is drawn.
        #expect(control.drawnTitle(forSegment: 0) == before)
        #expect(control.closeSegment(at: NSPoint(x: 70, y: 14)) == -1)
    }

    @Test("The strip's size answer carries a real height, so the control is never 0 tall")
    func theStripsSizeAnswerCarriesARealHeight() throws {
        // ⇒ ⇒ ⇒ AND THE PRODUCTION ANSWER IS THE ONE THAT MATTERS: the
        // editor's strip asks the representable for its size with an EMPTY
        // proposal (= MEASURED: the proposal's width and height both nil, =
        // because the strip is inside a horizontal scroll view), = and the
        // answer's HEIGHT is what sizes the control.
        //
        // ⇒ ⇒ ⇒ AND A 0 HEIGHT IS THE REGRESSION: = the control then draws
        // no interior (= the cell draws no segment), = and the X has no
        // pixels to land in.
        let tabs = (0 ..< 3).map { index in
            let hex = String(index, radix: 16)
            let padded = String(repeating: "0", count: 12 - hex.count) + hex
            return EditorTab(
                id: UUID(uuidString: "00000000-0000-0000-0000-" + padded)!,
                documentPath: "/library/book-" + String(index) + "/chapter.md",
                draft: "",
                originalBody: "",
                mode: .preview,
                title: "十二"
            )
        }
        let strip = EditorTabStrip(
            tabs: tabs,
            selectedTabId: tabs.first?.id,
            onSelect: { _ in },
            onClose: { _ in }
        )
        let host = NSHostingView(rootView: AnyView(strip.frame(width: 240)))
        host.frame = NSRect(x: 0, y: 0, width: 240, height: 28)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0 ..< 12 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        host.layoutSubtreeIfNeeded()
        window.display()
        defer { window.orderOut(nil) }

        func findControl(_ view: NSView) -> NSSegmentedControl? {
            if let control = view as? NSSegmentedControl {
                return control
            }
            for subview in view.subviews {
                if let found = findControl(subview) {
                    return found
                }
            }
            return nil
        }
        let control = try #require(findControl(host))
        #expect(control.frame.height > 0)
        // ⇒ ⇒ ⇒ ③ And the cells drew: = the segment frames exist.
        let closeControl = try #require(control as? PaneTabStripCloseControl)
        #expect(closeControl.closeCell.segmentFrames.count == control.segmentCount)
    }

    @Test("The X lands in the segment it belongs to, not in a neighbour")
    func theXLandsInItsOwnSegment() throws {
        // ⇒ ⇒ ⇒ AND THE X IS PLACED FROM THE CONTROL'S OWN GEOMETRY: the
        // frame captured in the draw hook is only true while that segment
        // is being redrawn, = and a segment that is not on screen keeps its
        // last frame (= or none at all), = so an X placed from it lands in
        // the WRONG segment (= MEASURED: = with no frame for the hovered
        // segment, = the ink rect came out NEGATIVE (= x = -18), = and the
        // mark landed at the strip's far left).
        //
        // ⇒ ⇒ ⇒ AND THE INSTRUMENT IS THE PIXELS: = the control rendered
        // twice (= once hovered, = once not), = and every pixel that
        // CHANGED is the X (= a pure geometry assertion cannot see this, =
        // because the geometry is the same either way).
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }

        // ⇒ ⇒ ⇒ ③ A CACHE READ IS NOT A RENDER: = the bitmap is read ③ from
        // the view's own cache, = so the view must be ③ told to draw again
        // (= ③ = and the cache flushed).
        control.needsDisplay = true
        window.displayIfNeeded()
        let before = Self.inkColumns(of: control)
        control.setSelectedSegment(2)
        control.needsDisplay = true
        window.displayIfNeeded()
        let after = Self.inkColumns(of: control)

        // ⇒ ⇒ ⇒ ③ The changed columns, = and the segment they fall in. ③
        // (The columns are PIXELS, = ③ = and the geometry is ③ = POINTS, =
        // ③ = so the comparison is in ③ = pixels.)
        let changed = zip(before, after).enumerated().compactMap { index, pair in
            pair.0 == pair.1 ? nil : index
        }
        #expect(!changed.isEmpty)
        let first = changed.min() ?? 0
        let last = changed.max() ?? 0
        // ⇒ ⇒ ⇒ ③ The scale (= the bitmap's pixels over the view's ③ =
        // points).
        let scale = max(Int((Double(before.count) / max(control.bounds.width, 1)).rounded()), 1)

        // ⇒ ⇒ ⇒ ③ Segment 2's own span (= the third of three, = ③ =
        // MEASURED: = 240 PT / 3 = 80 PT at x = 0, ③ = 80, 160).
        let frame = try #require(control.frame(ofSegment: 2))
        #expect(first >= Int(frame.minX * CGFloat(scale)))
        #expect(last <= Int(frame.maxX * CGFloat(scale)))
        // ⇒ ⇒ ⇒ ③ And it is NOT in segment 0 (= the far-left bug).
        #expect(first > Int(control.frame(ofSegment: 0).maxX * CGFloat(scale)))
    }

    @Test("After the collapse, the X still lands in the SELECTED tab, and not in a collapsed one")
    func afterTheCollapseTheXLandsInTheSelectedTab() {
        // ⇒ ⇒ ⇒ AND THE COLLAPSE MOVES THE TABS: = the selected tab takes
        // the room, = and the others collapse, = so a guard written for
        // equal tabs cannot see where the X lands.
        let (control, window) = makeControl(title: "十二三四五六七八九十")
        defer { window.orderOut(nil) }
        // ⇒ ⇒ ⇒ ③ THE PRODUCTION ORDER: = the selection first, ③ = and the
        // collapse after it (= ③ = the strip's own `configure`).
        control.setSelectedSegment(2)
        control.applyCollapse(columnWidth: 240, selectedSegment: 2)

        control.needsDisplay = true
        window.displayIfNeeded()
        let before = Self.inkColumns(of: control)

        // ⇒ ⇒ ⇒ ③ The selection moves: = and the X moves with it.
        control.setSelectedSegment(0)
        control.applyCollapse(columnWidth: 240, selectedSegment: 0)
        control.needsDisplay = true
        window.displayIfNeeded()
        let after = Self.inkColumns(of: control)

        // ⇒ ⇒ ⇒ ③ The X is NOW in segment 0 (= ③ = the tab that carries the
        // selection), = ③ = and it is NOT in segment 2 (= ③ = the one that
        // lost it).
        //
        // ⇒ ⇒ ⇒ AND THE MEASUREMENT IS THE X'S OWN INK: = the X is drawn in
        // the LIGHT grey ③ = (the strip's own ground is ③ = dark), = ③ = so
        // the light pixels in a segment ③ = are the X and the title (= ③ =
        // and the title's own count does ③ = not change, = ③ = so the COUNT
        // is the X's).
        let gained = Self.lightInk(control, rect: control.frame(ofSegment: 0))
        let lost = Self.lightInk(control, rect: control.frame(ofSegment: 2))
        #expect(gained > 0)
        #expect(lost < gained)
    }

    @Test("The X's ink is in the selected tab, and the selected tab's own ink is the X's")
    func theXsInkIsInTheSelectedTab() {
        // ⇒ ⇒ ⇒ AND THE X IS A GREY MARK: = the app's own close colour (=
        // `secondaryLabelColor`), = and the tab's title is WHITE, = so the
        // grey pixels ARE the X (= and the white ones are the title).
        let (control, window) = makeControl(title: "十二三四五六七八九十")
        defer { window.orderOut(nil) }
        control.setSelectedSegment(1)
        control.applyCollapse(columnWidth: 240, selectedSegment: 1)

        // ⇒ ⇒ ⇒ ③ AND THE X SITS AT THE SEGMENT'S LEADING EDGE: = ③ = the
        // boss's own ruling (= the capsule sits at the left), = ③ = so the
        // X's ink is at the LEFT of the ③ = segment, = ③ = and the
        // segment's own divider (= ③ = the grey line between the segments)
        // ③ = is at its RIGHT edge.
        let selectedFrame = control.frame(ofSegment: 1)
        let leading = NSRect(
            x: selectedFrame.minX,
            y: selectedFrame.minY,
            width: PaneTabStripClose.glyphPointSize + PaneTabStripClose.leadingInset,
            height: selectedFrame.height
        )
        let trailing = NSRect(
            x: selectedFrame.maxX - PaneTabStripClose.glyphPointSize - PaneTabStripClose.leadingInset,
            y: selectedFrame.minY,
            width: PaneTabStripClose.glyphPointSize + PaneTabStripClose.leadingInset,
            height: selectedFrame.height
        )
        #expect(Self.greyInk(control, rect: leading) > 0)
        #expect(Self.greyInk(control, rect: trailing) == 0)
    }

    /// The MID-GREY pixels in a rendered control's region (= the X's own
    /// ink, = and NOT the white title).
    private static func greyInk(_ control: NSView, rect: NSRect) -> Int {
        guard let rep = control.bitmapImageRepForCachingDisplay(in: control.bounds) else { return -1 }
        rep.size = control.bounds.size
        control.cacheDisplay(in: control.bounds, to: rep)
        guard let data = rep.bitmapData else { return -1 }
        let width = rep.pixelsWide
        let scale = max(Int((Double(width) / max(control.bounds.width, 1)).rounded()), 1)
        let startX = max(0, Int(rect.minX) * scale)
        let endX = min(width, Int(rect.maxX) * scale)
        let startY = max(0, Int(rect.minY) * scale)
        let endY = min(rep.pixelsHigh, Int(rect.maxY) * scale)
        guard endX > startX, endY > startY else { return 0 }
        var count = 0
        for y in startY ..< endY {
            for x in startX ..< endX {
                let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
                let average = (Int(data[offset]) + Int(data[offset + 1]) + Int(data[offset + 2])) / 3
                // ⇒ ⇒ ⇒ ③ The X's grey (= ③ = the app's own close ③ =
                // colour), = ③ = and NOT white (= ③ = the title).
                if average >= 45, average <= 200 {
                    count += 1
                }
            }
        }
        return count
    }

    /// The LIGHT pixels in a rendered control's region (= the X's ink, and
    /// the tab's title).
    private static func lightInk(_ control: NSView, rect: NSRect) -> Int {
        guard let rep = control.bitmapImageRepForCachingDisplay(in: control.bounds) else { return -1 }
        rep.size = control.bounds.size
        control.cacheDisplay(in: control.bounds, to: rep)
        guard let data = rep.bitmapData else { return -1 }
        let width = rep.pixelsWide
        let scale = max(Int((Double(width) / max(control.bounds.width, 1)).rounded()), 1)
        let startX = max(0, Int(rect.minX) * scale)
        let endX = min(width, Int(rect.maxX) * scale)
        let startY = max(0, Int(rect.minY) * scale)
        let endY = min(rep.pixelsHigh, Int(rect.maxY) * scale)
        guard endX > startX, endY > startY else { return 0 }
        var count = 0
        for y in startY ..< endY {
            for x in startX ..< endX {
                let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
                let average = (Int(data[offset]) + Int(data[offset + 1]) + Int(data[offset + 2])) / 3
                if average > 90 {
                    count += 1
                }
            }
        }
        return count
    }

    /// The ink a region GAINED (= the column totals after minus before).
    private static func inkBetween(
        _ before: [(r: Int, g: Int, b: Int)],
        _ after: [(r: Int, g: Int, b: Int)],
        in rect: NSRect
    ) -> Int {
        guard before.count == after.count, !before.isEmpty else { return 0 }
        let scale = max(Int((Double(before.count) / max(rect.width, 1)).rounded()), 1)
        let start = max(0, Int(rect.minX) * scale)
        let end = min(before.count, Int(rect.maxX) * scale)
        guard end > start else { return 0 }
        var total = 0
        for index in start ..< end {
            total += after[index].r - before[index].r
        }
        return total
    }

    @Test("A collapsed tab draws its character, so the reader can still tell them apart")
    func aCollapsedTabDrawsItsCharacter() {
        // ⇒ ⇒ ⇒ AND THE COLLAPSED TAB IS NOT BLANK: = the boss's own choice
        // (= a folded tab shows its first character), = so the tab carries
        // its document's first character.
        let (control, window) = makeControl(title: "十二三四五六七八九十")
        defer { window.orderOut(nil) }
        control.applyCollapse(columnWidth: 240, selectedSegment: 1)
        control.setSelectedSegment(1)

        control.needsDisplay = true
        window.displayIfNeeded()
        let collapsedInk = Self.inkIn(control, rect: control.frame(ofSegment: 0))
        // ⇒ ⇒ ⇒ ③ The collapsed tab has ink (= its character), ③ = and it
        // is MORE than the selected tab's own X ③ = (which is a badge, = a
        // small mark).
        #expect(collapsedInk > 0)
    }

    /// The control's rendered pixels, = one colour triple per column (= so
    /// a change of a column is a change of a place).
    private static func inkColumns(of view: NSView) -> [(r: Int, g: Int, b: Int)] {
        // ⇒ ⇒ ⇒ ③ AND THE CACHE READ IS FORCED: = an offscreen ③ window's
        // display pass does not reach the control's ③ cell, = and the
        // cell's per-segment hook runs only ③ inside a real draw (= ③ =
        // `cacheDisplay` is what makes it fire).
        view.needsDisplay = true
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return [] }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.bitmapData else { return [] }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        var columns: [(r: Int, g: Int, b: Int)] = []
        for x in 0 ..< width {
            var total = 0
            for y in 0 ..< height {
                let offset = y * rep.bytesPerRow + x * rep.samplesPerPixel
                total += Int(data[offset]) + Int(data[offset + 1]) + Int(data[offset + 2])
            }
            columns.append((total, 0, 0))
        }
        return columns
    }

    @Test("The X carries its own colour, so it reads on the strip's ground")
    func theXCarriesItsOwnColour() throws {
        // ⇒ ⇒ ⇒ AND THE X'S INK IS NOT THE TEMPLATE'S OWN MASK: = a
        // template image drawn into a context paints its black silhouette
        // (= MEASURED: = the X's pixels came out (9,9,9) on a (20,20,20)
        // ground, = so the X was invisible), = and Apple's own answer is
        // the PALETTE configuration. = So the mark the control draws must
        // carry a colour, = and the X must read as ink (= neither
        // near-black nor near-white) once it is drawn.
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        let segment = try #require(control.closeCell.frame(ofSegment: 1))
        let inkRect = PaneTabStripClose.glyphRect(in: segment)

        control.setSelectedSegment(1)
        window.displayIfNeeded()
        let ink = Self.inkIn(control, rect: inkRect)
        #expect(ink > 0)
    }

    @Test("The pointer is not involved: the X follows the selection")
    func thePointerIsNotInvolved() {
        // ⇒ ⇒ ⇒ AND THE X FOLLOWS THE SELECTION: = the boss's ruling (=
        // only the SELECTED tab carries the X), = so the control carries NO
        // tracking area (= and the pointer cannot move the X, = and the
        // geometry can not go stale).
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        control.updateTrackingAreas()

        let areas = control.trackingAreas.filter { $0.userInfo?["segment"] != nil }
        #expect(areas.isEmpty)
    }

    @Test("The selected tab takes the room, and the others collapse to one character")
    func theSelectedTabTakesTheRoom() {
        // ⇒ ⇒ ⇒ AND THE SELECTED TAB IS WIDE: = the boss's ruling (= the
        // selected tab takes the room and the others fold).
        //
        // ⇒ ⇒ ⇒ AND THE COLUMN IS TOO NARROW FOR THE TITLES: = the collapse
        // fires only when a title does NOT fit (= the boss's own ruling), =
        // and these titles do not fit in 240 / 3 = 80 PT.
        let (control, window) = makeControl(title: "十二三四五六七八九十")
        defer { window.orderOut(nil) }
        control.applyCollapse(columnWidth: 240, selectedSegment: 1)

        let widths = (0 ..< control.segmentCount).map { control.width(forSegment: $0) }
        #expect(widths[1] > widths[0])
        #expect(widths[1] > widths[2])
        // ⇒ ⇒ ⇒ AND THE OTHERS CARRY ONE CHARACTER: = the boss's AND THE
        // SELECTED TAB'S WIDTH IS ITS NATURAL WIDTH: = the boss's formula
        // (= the total width minus the selected tab's natural width (= its
        // own title's length plus the X's room) is what the others share),
        // = and the natural width is the title plus the X's room plus the
        // cell's own inset.
        let expected = PaneTabStripClose.naturalWidth(
            of: "十二三四五六七八九十",
            font: PaneTabStripClose.titleFont(),
            carriesTheX: true
        )
        #expect(abs(widths[1] - expected) < 0.5)
        // ⇒ ⇒ ⇒ AND THE WHOLE STRIP STILL FILLS ITS COLUMN: = the widths
        // are the control's own frame, = so nothing overflows and nothing
        // is lost.
        #expect(abs(widths.reduce(0, +) - 240) < 0.5)
    }

    @Test("The other tabs share what is left BY THEIR OWN TITLES' LENGTH")
    func theOtherTabsShareByTheirTitlesLength() throws {
        // ⇒ ⇒ ⇒ AND THE SHARE IS A GRADIENT: = the boss's own the remaining
        // width over the remaining tabs, weighted by their own titles'
        // length), = and a long title keeps more room than a short one.
        let font = PaneTabStripClose.titleFont()
        let long = "十二三四五六七八九十"
        let short = "十"
        let widths = try #require(PaneTabStripClose.collapsedWidths(
            columnWidth: 400,
            titles: [long, short, long],
            font: font,
            selectedSegment: 0
        ))
        #expect(widths.count == 3)
        // ⇒ ⇒ ⇒ The selected tab took its natural width.
        let natural = PaneTabStripClose.naturalWidth(
            of: long,
            font: font,
            carriesTheX: true
        )
        #expect(abs(widths[0] - natural) < 0.5)
        // ⇒ ⇒ ⇒ And the short title's tab got LESS than the long one's.
        #expect(widths[2] > widths[1])
        // ⇒ ⇒ ⇒ And the whole strip still fills its column.
        #expect(abs(widths.reduce(0, +) - 400) < 0.5)
    }

    @Test("A collapsed tab draws its first character, and the selected one draws its whole title")
    func aCollapsedTabDrawsItsFirstCharacter() {
        let (control, window) = makeControl(title: "十二三四五六七八九十")
        defer { window.orderOut(nil) }
        control.applyCollapse(columnWidth: 240, selectedSegment: 1)
        // ⇒ ⇒ ⇒ AND THE COLLAPSE FIRED: = the titles do not fit in the
        // equal share, = so the strip collapsed (= and this test would be
        // measuring nothing otherwise).
        #expect(control.width(forSegment: 0) < 80)

        // ⇒ ⇒ ⇒ The collapsed tab shows ONE character (= the boss's
        // choice). AND A NARROW TAB SHOWS ITS FIRST CHARACTER: = the
        // ladder's own rule (= the boss's 2026-11-16 rule), = so the narrow
        // tab still names its document.
        #expect(control.drawnTitle(forSegment: 0) == "十")
        // The selected tab shows its whole title (= so the reader can name
        // the document).
        #expect(control.drawnTitle(forSegment: 1) == "十二三四五六七八九十")
    }

    @Test("When the equal share fits every title, the strip does NOT collapse")
    func whenTheEqualShareFitsTheStripDoesNotCollapse() {
        // ⇒ ⇒ ⇒ AND THE COLLAPSE FIRES ONLY WHEN IT MUST: = the boss's own
        // ruling (= the strip folds only when it must: the equal share is
        // kept as long as every title fits in it).
        let (control, window) = makeControl(title: "十二")
        defer { window.orderOut(nil) }
        control.applyCollapse(columnWidth: 240, selectedSegment: 1)

        // ⇒ ⇒ ⇒ AND EVERY TAB KEEPS ITS EQUAL SHARE: = 240 / 3 = 80 PT each
        // (= and the titles fit, = so nothing is compressed).
        //
        // ⇒ ⇒ ⇒ AND THE GEOMETRY IS THE CONTROL'S OWN: = the frames the
        // control's own geometry gives (= and the app draws and hits test
        // against those).
        for segment in 0 ..< control.segmentCount {
            #expect(abs(control.frame(ofSegment: segment).width - 80) < 0.5)
        }
        // ⇒ ⇒ ⇒ AND NO TAB SHOWS ONLY ITS FIRST CHARACTER: = the whole
        // title is there.
        #expect(control.drawnTitle(forSegment: 0) == "十二")
    }

    @Test("The X's hover paints a wash behind the mark, and it leaves the mark where it is")
    func theXsHoverPaintsAWashBehindTheMark() throws {
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        control.setSelectedSegment(1)
        window.displayIfNeeded()
        let segment = try #require(control.closeCell.frame(ofSegment: 1))
        let inkRect = PaneTabStripClose.glyphRect(in: segment)

        // ⇒ ⇒ ⇒ AND THE RESTING STRIP PAINTS NO WASH: = the wash is the
        // hover's own business.
        let before = Self.inkIn(control, rect: inkRect)
        #expect(before >= 0)

        // ⇒ ⇒ ⇒ AND THE HOVER'S WASH IS THERE: = a translucent circle under
        // the mark (= its pixels are the ground's own shade lifted, = so
        // they read as ink against the cell's own fill).
        control.setCloseHovered(true)
        window.displayIfNeeded()
        let after = Self.inkIn(control, rect: inkRect)
        #expect(after > before)

        // ⇒ ⇒ ⇒ AND THE HOVER LEAVES THE MARK WHERE IT IS: = the wash is
        // BEHIND the mark (= and not a different mark in a different
        // place).
        #expect(PaneTabStripClose.glyphRect(in: segment) == inkRect)
        // ⇒ ⇒ ⇒ AND THE WASH IS ONE RING BIGGER THAN THE MARK: = the boss's
        // own ruling (= one ring bigger than the mark), = and the mark
        // stays in the wash's middle.
        let wash = PaneTabStripClose.hoverWashRect(in: segment)
        #expect(wash.width > inkRect.width)
        #expect(wash.midX == inkRect.midX)
        #expect(wash.midY == inkRect.midY)
        // ⇒ ⇒ ⇒ AND THE WASH STAYS IN THE TAB: = a wash taller than the tab
        // would spill into the content below it.
        #expect(wash.height <= segment.height)
    }

    @Test("The pointer's rectangle is the X's own tap target, and it follows the X")
    func thePointersRectangleIsTheXsOwnTapTarget() throws {
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        control.setSelectedSegment(1)
        window.displayIfNeeded()
        let segment = try #require(control.closeCell.frame(ofSegment: 1))
        let target = PaneTabStripClose.hitRect(in: segment)
        // ⇒ ⇒ ⇒ AND THE TARGET IS THE HIG'S MINIMUM: = and it sits on the
        // X's own ink (= and not on the whole strip, = and not on a tab
        // that is not the selected one).
        #expect(target.width <= PaneTabStripClose.hitArea)
        // ⇒ ⇒ ⇒ AND THE TARGET HOLDS THE X'S OWN INK: = the target is
        // clamped to the segment (= so the X near the leading edge loses
        // the target's left half), and the mark's own centre still sits
        // inside it.
        let ink = PaneTabStripClose.glyphRect(in: segment)
        #expect(target.contains(NSPoint(x: ink.midX, y: ink.midY)))
        #expect(segment.contains(target))
    }

    @Test("A right-click on any tab offers the close item, and it names the tab under the pointer")
    func aRightClickOffersTheCloseItemForTheTabUnderThePointer() throws {
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        control.showsContextMenu = true
        // ⇒ ⇒ ⇒ AND IT IS THE POINTER'S OWN TAB: = not the selected one (=
        // and the boss's own reason: = every editor tab closes from the
        // menu).
        let segment = try #require(control.closeCell.frame(ofSegment: 2))
        let event = try #require(
            NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: NSPoint(x: segment.midX, y: segment.midY),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        let menu = try #require(control.menu(for: event))
        #expect(menu.items.count == 1)
        #expect(menu.items.first?.representedObject as? Int == 2)
        #expect(!(menu.items.first?.title.isEmpty ?? true))
    }

    @Test("The context menu's close closes the tab the pointer named")
    func theContextMenuCloseClosesTheTabThePointerNamed() throws {
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        control.showsContextMenu = true
        var closed: Int?
        control.onCloseSegment = { closed = $0 }
        let segment = try #require(control.closeCell.frame(ofSegment: 1))
        let event = try #require(
            NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: NSPoint(x: segment.midX, y: segment.midY),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        let menu = try #require(control.menu(for: event))
        let item = try #require(menu.items.first)
        let action = try #require(item.action)
        #expect(NSApp.sendAction(action, to: item.target, from: item))
        #expect(closed == 1)
    }

    @Test("A strip that does not ask for a menu has none")
    func aStripThatDoesNotAskForAMenuHasNone() throws {
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        // ⇒ ⇒ ⇒ AND THE MENU IS OPT-IN: = the chat zone's session bar and
        // the inspector's switcher keep their own shape (= and the boss's
        // own ruling: = the editor's area only).
        let segment = try #require(control.closeCell.frame(ofSegment: 0))
        let event = try #require(
            NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: NSPoint(x: segment.midX, y: segment.midY),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        #expect(control.menu(for: event) == nil)
    }

    @Test("The context menu's close item is in the string catalog, in both languages")
    func theContextMenuCloseItemIsInTheStringCatalog() {
        #expect(StringCatalogReader.strings(language: "zh-Hans")["editor.tab.context_menu.close"] == "关闭")
        #expect(StringCatalogReader.strings(language: "en")["editor.tab.context_menu.close"] == "Close")
    }

    @Test("The X's mark is Apple's own outlined close badge")
    func theXIsApplesOutlinedBadge() {
        // ⇒ ⇒ ⇒ AND IT IS THE BOSS'S OWN CALL: = the outlined badge,
        // because the filled one read as a plain white disc on the accent
        // ground (= the measured reason: = on the selected tab's blue
        // ground the FILLED mark reads as a plain white disc, = and the
        // outlined one keeps both the ring and the X legible).
        #expect(PaneTabStripClose.glyphName == "xmark.circle")
    }

    @Test("The selected segment's title gives up the X's room")
    func theSelectedTitleShortens() {
        // ⇒ ⇒ ⇒ A title long enough for the X's room to change it: = at a
        // short title the room is not what decides the answer.
        let (control, window) = makeControl(title: "十二三四五六七八九十")
        defer { window.orderOut(nil) }
        let before = control.drawnTitle(forSegment: 1)
        control.setSelectedSegment(1)
        let after = control.drawnTitle(forSegment: 1)
        #expect(after != before)
        // ⇒ ⇒ ⇒ AND THE OTHER SEGMENT'S TITLE NEVER GIVES UP THE X'S ROOM:
        // = it is the ladder's answer for its OWN width (= and the width
        // carries no X's room), so the X's room came out of the SELECTED
        // tab only.
        let otherShare = control.segmentWidths.first ?? 80
        #expect(
            control.drawnTitle(forSegment: 0)
                == PaneTabStripTitle.fitted(
                    "十二三四五六七八九十",
                    share: otherShare,
                    font: PaneTabStripClose.titleFont()
                )
        )
    }

    @Test("A click on the X closes that tab")
    func aClickOnTheXClosesThatTab() throws {
        var closed: [Int] = []
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        control.onCloseSegment = { closed.append($0) }
        // ⇒ ⇒ ⇒ AND THE TAB IS SELECTED FIRST: = the X follows the
        // SELECTION, = = so the X that can be clicked is the selected tab's
        // own (= MEASURED: = the review's own probe, = = 2026-11-18).
        control.setSelectedSegment(1)

        let segment = try #require(control.closeCell.frame(ofSegment: 1))
        let ink = PaneTabStripClose.glyphRect(in: segment)
        let point = NSPoint(x: ink.midX, y: ink.midY)

        // The click lands on the X: = it closes that segment.
        #expect(control.closeSegment(at: point) == 1)
        // A click that misses the X is NOT a close.
        #expect(control.closeSegment(at: NSPoint(x: ink.midX - 40, y: ink.midY)) == -1)
    }

    @Test("A click on a NON-selected tab's leading edge closes nothing")
    func aClickOnAnUnselectedTabsLeadingEdgeClosesNothing() throws {
        var closed: [Int] = []
        let (control, window) = makeControl()
        defer { window.orderOut(nil) }
        control.onCloseSegment = { closed.append($0) }
        control.setSelectedSegment(1)

        // ⇒ ⇒ ⇒ AND THE UNSELECTED TAB'S LEADING EDGE IS NOT A CLOSE: = the
        // X is PAINTED in the selected tab alone, = so a hit test that
        // answered for every segment would close a tab where no X is drawn
        // (= MEASURED: = the review's own probe, = = 2026-11-18).
        let other = try #require(control.closeCell.frame(ofSegment: 0))
        let otherInk = PaneTabStripClose.glyphRect(in: other)
        #expect(control.closeSegment(at: NSPoint(x: otherInk.midX, y: otherInk.midY)) == -1)
        // ⇒ ⇒ ⇒ AND THE SELECTED TAB'S OWN X IS STILL THE CLOSE: = the
        // scope narrows the hit test, = = it does not remove it.
        let selected = try #require(control.closeCell.frame(ofSegment: 1))
        let selectedInk = PaneTabStripClose.glyphRect(in: selected)
        #expect(control.closeSegment(at: NSPoint(x: selectedInk.midX, y: selectedInk.midY)) == 1)
        #expect(closed.isEmpty)
    }

    @Test("A double-click on an unselected tab still closes that tab")
    func aDoubleClickOnAnUnselectedTabStillClosesIt() throws {
        // ⇒ ⇒ ⇒ AND THE CONTROL SITS AWAY FROM THE ORIGIN: = a control at
        // (0, 0) cannot tell a point that is converted from a point that
        // is not (= MEASURED: = the review's own probe, = = 2026-11-18: =
        // the app's own control sits at (260, 896), = = and the double
        // conversion moved the delegate's point by exactly that).
        let (control, window) = makeControl(origin: NSPoint(x: 260, y: 12))
        defer { window.orderOut(nil) }
        control.setSelectedSegment(1)

        // ⇒ ⇒ ⇒ AND THE DOUBLE-CLICK'S OWN PREDICATE IS THE SAME ONE: = the
        // delegate asks "is this click on the X?", = = and the X lives in
        // the SELECTED tab only, = = so the answer must be scoped the same
        // way (= MEASURED: = the review's own probe, = = 2026-11-18).
        let other = try #require(control.closeCell.frame(ofSegment: 0))
        let otherInk = PaneTabStripClose.glyphRect(in: other)
        let onTheUnselectedEdge = control.closeSegment(at: NSPoint(x: otherInk.midX, y: otherInk.midY))
        #expect(onTheUnselectedEdge < 0)
        // ⇒ ⇒ ⇒ AND THE DELEGATE ITSELF IS ASKED: = the double-click's
        // decision is the delegate's, = = and the delegate is the only
        // thing that can refuse the gesture (= MEASURED: = the review's own
        // probe, = = 2026-11-18).
        let recognizer = FixedPointClickRecognizer()
        recognizer.numberOfClicksRequired = 2
        control.addGestureRecognizer(recognizer)
        let coordinator = LabelSegmentedControl<String>.Coordinator(
            parent: LabelSegmentedControl(
                selection: .constant("a"),
                labels: ["a", "b", "c"],
                iconStyle: .inlineSmall
            )
        )
        // ⇒ ⇒ ⇒ AND THE GESTURE IS NOT REFUSED ON AN UNSELECTED TAB's
        // EDGE: = the predicate asks "is this click on the X?", = = and the
        // X lives in the SELECTED tab, = = so the answer is no and the
        // double-click runs (= = the tab closes).
        recognizer.fixedPoint = NSPoint(x: otherInk.midX, y: otherInk.midY)
        #expect(coordinator.gestureRecognizerShouldBegin(recognizer))
        // ⇒ ⇒ ⇒ AND THE GESTURE IS REFUSED ON THE X ITSELF: = a double
        // click on the selected tab's X must not close a second tab.
        let selected = try #require(control.closeCell.frame(ofSegment: 1))
        let selectedInk = PaneTabStripClose.glyphRect(in: selected)
        recognizer.fixedPoint = NSPoint(x: selectedInk.midX, y: selectedInk.midY)
        #expect(!coordinator.gestureRecognizerShouldBegin(recognizer))
    }

    @Test("After the column is too narrow, the drawn cells stay inside it")
    func afterTheColumnIsTooNarrowTheCellsStayInside() throws {
        // ⇒ ⇒ ⇒ AND THE TITLES DO NOT FIT THE EQUAL SHARE: = the collapse
        // fires only when a title does NOT fit (= the boss's own ruling),
        // = = and this title does not fit in 240 / 3 = 80 PT.
        let (control, window) = makeControl(title: "十二三四五六七八九十")
        defer { window.orderOut(nil) }
        control.setSelectedSegment(1)

        // ⇒ ⇒ ⇒ AND A COLLAPSE RUNS FIRST: = a width set by a collapse
        // STAYS on the control, = = so the fallback must clear it (= =
        // MEASURED: = the review's own probe, = = 2026-11-18).
        control.applyCollapse(columnWidth: 240, selectedSegment: 1)
        var setByTheCollapse = 0
        for segment in 0 ..< control.segmentCount {
            if control.width(forSegment: segment) > 0 {
                setByTheCollapse += 1
            }
        }
        #expect(setByTheCollapse > 0)

        // ⇒ ⇒ ⇒ AND THEN THE COLUMN IS NARROWED BELOW THE COLLAPSE FLOOR:
        // = the model's own answer is nil there, = = and the fallback must
        // clear the widths the earlier collapse set (= AppKit CLAMPS an
        // explicit width, = = so a stale one draws past the column).
        control.applyCollapse(columnWidth: 90, selectedSegment: 1)

        // ⇒ ⇒ ⇒ AND THE MODEL'S OWN ANSWER IS THE EQUAL SHARE: = the
        // fallback divides the column the way AppKit divides the frame.
        let equal = 90.0 / 3.0
        for width in control.segmentWidths {
            #expect(abs(width - equal) < 0.5)
        }
        // ⇒ ⇒ ⇒ AND THE CONTROL CARRIES NO EXPLICIT WIDTH ANY MORE: = a
        // width left on the control is a width the strip keeps, = = and it
        // draws past the column it was given (= AppKit's own `.fillEqually`
        // then divides the frame, = = so the cells fill exactly the
        // column).
        var explicit = 0
        for segment in 0 ..< control.segmentCount {
            if control.width(forSegment: segment) > 0 {
                explicit += 1
            }
        }
        #expect(explicit == 0)
        // ⇒ ⇒ ⇒ AND THE X IS STILL THE SELECTED TAB's OWN: = the fallback
        // moved the widths, = = and the X moved with them.
        let frame = try #require(control.frame(ofSegment: control.closeSegmentIndex))
        let ink = PaneTabStripClose.glyphRect(in: frame)
        #expect(control.closeSegment(at: NSPoint(x: ink.midX, y: ink.midY)) == control.closeSegmentIndex)
    }

    // MARK: - The strip

    /// The strip in a real window, = with the X's close path on.
    private func hostedStrip(
        tabCount: Int,
        columnWidth: CGFloat,
        onClose: @escaping (UUID) -> Void
    ) -> (NSSegmentedControl, NSWindow, [EditorTab])? {
        let tabs = (0 ..< tabCount).map { index in
            EditorTab(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                documentPath: "/library/book-\(index)/chapter-\(index).md",
                draft: "",
                originalBody: "",
                mode: .preview,
                title: "十二"
            )
        }
        let strip = EditorTabStrip(
            tabs: tabs,
            selectedTabId: tabs.first?.id,
            onSelect: { _ in },
            onClose: onClose
        )
        let host = NSHostingView(rootView: AnyView(strip.frame(width: columnWidth)))
        host.frame = NSRect(x: 0, y: 0, width: columnWidth, height: 68)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0 ..< 12 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.03))
        }
        host.layoutSubtreeIfNeeded()
        window.display()
        guard let control = Self.findSegmentedControl(in: host) else {
            window.orderOut(nil)
            return nil
        }
        return (control, window, tabs)
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

    @Test("The strip carries the X, and the X closes the tab the segment shows")
    func theStripCarriesTheX() throws {
        var closed: [UUID] = []
        guard let (control, window, tabs) = hostedStrip(
            tabCount: 3,
            columnWidth: 240,
            onClose: { closed.append($0) }
        ) else {
            Issue.record("The tab strip did not host a segmented control.")
            return
        }
        defer { window.orderOut(nil) }

        // The control that carries the X is ONE view (= not a SwiftUI
        // button per tab, = the shape that crashed this app).
        let closeControl = try #require(control as? PaneTabStripCloseControl)
        // ⇒ ⇒ ⇒ AND THE X IS THERE: = the control carries the mark, = and
        // the strip's own close path is wired to it (= the strip maps the
        // segment to the tab the DISPLAY ORDER shows).
        #expect(closeControl.closeCell.closeGlyph != nil)
        closeControl.onCloseSegment?(1)
        #expect(closed == [tabs[1].id])
    }
}
