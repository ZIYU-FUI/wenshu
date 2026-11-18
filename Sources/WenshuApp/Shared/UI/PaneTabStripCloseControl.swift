// PaneTabStripCloseControl.swift
//
// The segmented control that carries the Safari-style close X inside a pane
// tab.
//
// WHY IT IS ONE VIEW
//
// ⇒ ⇒ ⇒ The X is NOT a SwiftUI button per tab: = that shape crashed this
// app (= the window's "Update Constraints in Window" pass count), and the
// shape that survived is ONE `NSSegmentedControl`. = The X lives inside
// that one view: = drawn by AppKit's own per-segment interior hook, =
// hovered by the control's own tracking areas, = and clicked by the
// control's own mouse handling.
//
// WHAT IT DOES
//
// 1. It knows which segment the pointer is over (= one tracking area per
// segment, = which is AppKit's own hover mechanism and needs no
// window-level mouse-moved setting). 2. It draws the X in the hovered
// segment (= inside `drawSegment(_:inFrame:with:)`, = which is MEASURED to
// reach the pixels), = and it gives the hovered segment's TITLE the X's
// room (= so the title shortens instead of running under the X, which is
// what Safari does). 3. It reports a click on the X (= and swallows it, =
// so the click does not also SELECT the segment it closes).

import AppKit

// MARK: - The cell (= the X's drawing)

/// The cell that draws the X inside a segment.
final class PaneTabStripCloseCell: NSSegmentedCell {
    /// The segment the X is drawn in (= -1 = no segment).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE SELECTED ONE: = the boss's ruling (= only the
    /// SELECTED tab carries the X), = so the X follows the selection (= and
    /// NOT the pointer).
    ///
    /// ⇒ ⇒ ⇒ AND IT CARRIES ITS OWN NAME: = AppKit's own control already
    /// owns `selectedSegment`, = and a stored property cannot override it.
    var closeSegmentIndex: Int = -1

    /// The X's mark (= nil = no X at all, = a strip with no close path
    /// draws no X).
    var closeGlyph: NSImage?

    /// Whether the POINTER is on the X (= the hover).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS A WASH, NOT A NEW MARK: = the mark stays the SAME
    /// symbol (= the boss's own `xmark.circle`), and the hover paints a
    /// translucent circle BEHIND it (= and the filled variant is NOT used,
    /// = for the boss's own measured reason: = on the accent ground it read
    /// as a plain white disc).
    var closeHovered: Bool = false

    /// The frame AppKit gave each segment (= the geometry the X is placed
    /// in, = and the only geometry that is TRUE: = the control's own frame
    /// can be shorter than the cells it draws, = and the X must sit where
    /// the cell actually is).
    private(set) var segmentFrames: [NSRect] = []

    /// The frame of a segment (= .zero when it has not been drawn).
    func frame(ofSegment segment: Int) -> NSRect? {
        guard segment >= 0, segment < segmentFrames.count else { return nil }
        return segmentFrames[segment]
    }

    /// ⇒ ⇒ ⇒ The Swift name is `drawSegment(_:inFrame:with:)`: = the
    /// Objective-C selector's `withView:` was renamed in Swift 3, = and the
    /// OLD label compiles as a method of its own, = which would never be
    /// called (= and the X would never be drawn).
    override func drawSegment(_ segment: Int, inFrame frame: NSRect, with controlView: NSView) {
        // ⇒ ⇒ ⇒ AND THE FRAME LANDS AT ITS OWN INDEX: = appending would put
        // a segment's frame at the END (= when the hook fires out of
        // order), = so the array grows to the segment's index when it must.
        if segmentFrames.count <= segment {
            segmentFrames.append(contentsOf: repeatElement(.zero, count: segment - segmentFrames.count + 1))
        }
        segmentFrames[segment] = frame
        super.drawSegment(segment, inFrame: frame, with: controlView)
        guard segment == closeSegmentIndex, let closeGlyph else { return }
        // ⇒ ⇒ ⇒ AND THE HOVER'S WASH GOES UNDER THE MARK: = the wash is a
        // translucent WHITE circle (= Apple's own rule on a coloured
        // ground: = a white mark and a light wash), = and the selected
        // tab's own accent still shows through it.
        if closeHovered {
            NSColor.white
                .withAlphaComponent(PaneTabStripClose.hoverWashAlpha)
                .setFill()
            NSBezierPath(ovalIn: PaneTabStripClose.hoverWashRect(in: frame)).fill()
        }
        // ⇒ ⇒ ⇒ AND THE HOOK'S OWN FRAME IS THE TRUTH: = Apple's own header
        // says the frame "has been adjusted to content area", = and it IS
        // the cell's own frame (= the collapsed tab's own width), = so the
        // X lands in the tab it belongs to.
        let ink = PaneTabStripClose.glyphRect(in: frame)
        // ⇒ ⇒ ⇒ AND THE MARK IS THE SELECTED TAB'S OWN WHITE: = the
        // selected tab's ground is the accent colour, = and Apple's own
        // rule on a coloured ground is a WHITE mark, = (and the badge's own
        // X hole then shows the accent through it).
        //
        // ⇒ ⇒ ⇒ AND THE MARK CARRIES ITS OWN COLOUR: = a TEMPLATE image
        // drawn into a context paints its OWN mask (= the black
        // silhouette), = so the X's ink was black on a dark strip and the X
        // was invisible. = Apple's own answer is the PALETTE configuration
        // (= `NSImageSymbolConfiguration` with
        // `configurationWithPaletteColors:`, = macOS 12+), = and the
        // palette must be applied AFTER the size (= Apple's own rule: = the
        // last colour configuration wins).
        let configuration = NSImage.SymbolConfiguration(
            pointSize: PaneTabStripClose.glyphPointSize,
            weight: .regular,
            scale: .medium
        ).applying(
            NSImage.SymbolConfiguration(paletteColors: [.white])
        )
        let symbol = closeGlyph.withSymbolConfiguration(configuration)
        // ⇒ ⇒ ⇒ AND THE WHOLE MARK IS DRAWN: = `draw(in:from:...)` takes
        // the PART of the image to draw (= and an EMPTY rectangle (=
        // `.zero`) draws NOTHING
        guard let symbol else { return }
        symbol.draw(
            in: ink,
            from: NSRect(origin: .zero, size: symbol.size),
            operation: .sourceOver,
            fraction: 1
        )
    }
}

// MARK: - The control

/// A segmented control that draws and handles the Safari-style close X.
final class PaneTabStripCloseControl: NSSegmentedControl {
    /// The cell that draws the X.
    let closeCell = PaneTabStripCloseCell()

    /// Fired when the pointer clicks the X (= the segment's index).
    var onCloseSegment: ((Int) -> Void)?
    /// Every segment's width (= the WIDTHS THIS CONTROL SET, = and not
    /// AppKit's own report).
    ///
    /// ⇒ ⇒ ⇒ AND APPKIT'S REPORT IS NOT THE SOURCE: = `width(forSegment:)`
    /// reads the width that was SET (= and 0 when none was set), = and it
    /// is NOT the width the cell was laid out with.
    private func laidOutWidths() -> [CGFloat] {
        guard segmentWidths.count == segmentCount else {
            // ⇒ ⇒ ⇒ AND WITH NO WIDTHS SET, = the equal share is the
            // answer.
            let share = bounds.width / CGFloat(max(segmentCount, 1))
            return Array(repeating: share, count: segmentCount)
        }
        return segmentWidths
    }

    /// The selected segment (= -1 = none).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE ONE THAT CARRIES THE X: = the X follows the
    /// selection, = so it needs no hover and no tracking area (= and a
    /// tracking area per segment was the one thing that made the control's
    /// geometry stale).
    private(set) var closeSegmentIndex: Int = -1

    /// The titles the segments carry (= the whole titles, = and the ladder
    /// decides what is drawn).
    private var displayStrings: [String] = []

    /// The share one segment takes (= the region's width over the segment
    /// count).
    private var share: CGFloat = 0

    /// The font the control draws its labels with.
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE STRIP'S OWN FONT: = so the width the control
    /// draws is the width the scroll walks (= and the two cannot disagree).
    private var labelFont = PaneTabStripClose.titleFont()

    /// The X's mark (= nil = the strip has no close path).
    private var closeGlyph: NSImage?

    /// Whether the strip answers a right-click with a menu.
    ///
    /// ⇒ ⇒ ⇒ AND IT IS OPT-IN: = the editor's tab strip asks for it (= and
    /// only it does), = and the chat zone's session bar and the inspector's
    /// switcher keep their own shape (= the boss's own ruling: = the
    /// editor's area only).
    var showsContextMenu: Bool = false

    /// The tracking area that watches the X (= nil = none yet).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS ONE AREA, NOT ONE PER TAB: = the X lives in ONE tab
    /// (= the selected one), = so the pointer's business is ONE rectangle.
    private var closeTrackingArea: NSTrackingArea?

    /// Whether the pointer is on the X.
    private var closeHovered: Bool = false

    // MARK: Setup

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        cell = closeCell
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used: this control is created in code.")
    }

    // MARK: The layout

    /// ⇒ ⇒ ⇒ AND THE WIDTHS ARE LAID OUT WITH THE CONTROL'S OWN FRAME: the
    /// widths are a share of the column, = and the column is the control's
    /// OWN frame (= the frame AppKit divides), = and the width the SwiftUI
    /// caller handed over can be a STALE one (= the caller's region is
    /// written on every SwiftUI update, = and the frame is laid out after),
    /// =
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // ⇒ ⇒ ⇒ AND THE WIDTHS FOLLOW THE CONTROL'S OWN FRAME: = the
        // collapse divides the COLUMN, = and the column is the control's
        // OWN frame (= the one AppKit divides).
        applyCollapse(columnWidth: newSize.width, selectedSegment: closeSegmentIndex)
    }

    // MARK: The titles

    /// Set the titles the segments carry (= the whole titles).
    ///
    /// The ladder decides what each segment DRAWS, = and the ladder's
    /// answer depends on whether the segment is hovered (= the X takes its
    /// room from the title), = so the drawing is owned here and not by the
    /// caller.
    func setDisplayStrings(
        _ strings: [String],
        share newShare: CGFloat,
        font newFont: NSFont,
        closeGlyph newCloseGlyph: NSImage?
    ) {
        displayStrings = strings
        share = newShare
        labelFont = newFont
        closeGlyph = newCloseGlyph
        closeCell.closeGlyph = newCloseGlyph
        applyTitles()
    }

    /// ⇒ ⇒ ⇒ AND EVERY SEGMENT'S LABEL IS THE ONE ITS OWN CELL FITS:
    /// AppKit's own cell honours a label's own width plus the segment's own
    /// inset (= MEASURED: = a cell is `label + 20.5 PT`), = so a label
    /// wider than its cell makes the cell wider than its cell (= and the
    /// strip overflows the column), = and the ladder's answer is the label
    /// that FITS (=
    ///
    /// The title a segment draws (= the ladder's answer).
    ///
    /// ⇒ ⇒ ⇒ AND THE LADDER IS THE ONE THAT NARROWS A TITLE: =
    /// `PaneTabStripTitle.fitted` (= it keeps the start of the title, = and
    /// when even the ellipsis does not fit, = it shows the FIRST CHARACTER
    /// (= the boss's own rule), = so a narrow tab shows its first character
    /// on its own, = and no separate rule is needed here.
    func drawnTitle(forSegment segment: Int) -> String {
        guard segment >= 0, segment < displayStrings.count else { return "" }
        let selected = segment == closeSegmentIndex && closeGlyph != nil
        return PaneTabStripTitle.fitted(
            displayStrings[segment],
            share: PaneTabStripClose.titleShare(
                share: share(forSegment: segment),
                selected: selected
            ),
            font: labelFont
        )
    }

    /// The width one segment takes (= POINTS).
    ///
    /// ⇒ ⇒ ⇒ AND THE SELECTED TAB TAKES THE ROOM: = the collapse (the
    /// boss's ruling), = so each segment's own width is read from the
    /// collapse model.
    private func share(forSegment segment: Int) -> CGFloat {
        guard segment >= 0, segment < segmentWidths.count else { return share }
        return segmentWidths[segment]
    }

    /// Every segment's own width (= the collapse model's answer).
    private(set) var segmentWidths: [CGFloat] = []

    /// Apply the collapse (= the selected tab takes the room, = the others
    /// collapse to one character).
    ///
    /// ⇒ ⇒ ⇒ AND THE WIDTHS ARE SET ON THE CONTROL: = AppKit's own
    /// `setWidth(_:forSegment:)` (= MEASURED: = the control honours the
    /// width exactly, = 24 PT comes back as 24 PT, = and the sum of the
    /// widths is the control's own frame).
    func applyCollapse(columnWidth: CGFloat, selectedSegment: Int) {
        // ⇒ ⇒ ⇒ AND THE TITLES ARE FITTED AGAIN: = the collapse changed
        // every segment's width, = so the title each one draws changed with
        // it.
        defer { applyTitles() }
        guard segmentCount > 0, columnWidth > 0 else {
            segmentWidths = []
            return
        }
        // ⇒ ⇒ ⇒ AND THE STRIP COLLAPSES ONLY WHEN IT MUST: = the boss's
        // ruling (= the strip folds only when it must: the equal share is
        // kept as long as every title fits in it), = so the equal share is
        // kept as long as every title FITS in it.
        let equal = columnWidth / CGFloat(segmentCount)
        let selectedTitle = displayStrings.indices.contains(selectedSegment)
            ? displayStrings[selectedSegment]
            : ""
        let selectedFits = PaneTabStripClose.selectedTitleFits(
            title: selectedTitle,
            share: equal,
            font: labelFont
        )
        var widths: [CGFloat] = []
        if selectedFits {
            // ⇒ ⇒ ⇒ AND THE EQUAL SHARE IS APPLE'S OWN RULE: = the region
            // is divided into as many equal shares as there are tabs (= the
            // strip's own 2026-11-12 rule).
            //
            // ⇒ ⇒ ⇒ AND NO WIDTH IS SET: = AppKit's own `.fillEqually`
            // divides the control's frame and TRUNCATES a label that does
            // not fit (= and that is the ONLY way the track stays exactly
            // the column's width (= MEASURED: =
            for _ in 0 ..< segmentCount {
                widths.append(equal)
            }
            // ⇒ ⇒ ⇒ AND THE PREVIOUS WIDTHS ARE CLEARED: = a width set
            // earlier (= the collapsed one) STAYS on the control, = and the
            // strip would keep the old widths (=
            for segment in 0 ..< segmentCount {
                setWidth(0, forSegment: segment)
            }
        } else {
            // ⇒ ⇒ ⇒ AND THE OTHERS SHARE WHAT IS LEFT BY THEIR OWN TITLES'
            // LENGTH: = the boss's formula (= the remaining width over the
            // remaining tabs, weighted by their own titles' length), = and
            // no tab is crushed to a fixed width.
            let formula = PaneTabStripClose.collapsedWidths(
                columnWidth: columnWidth,
                titles: displayStrings,
                font: labelFont,
                selectedSegment: selectedSegment
            )
            guard let formula else {
                // ⇒ ⇒ ⇒ AND THE COLUMN CANNOT HOLD THE COLLAPSED TABS: the
                // cells would blow up (=
                for _ in 0 ..< segmentCount {
                    widths.append(equal)
                }
                // ⇒ ⇒ ⇒ AND THE PREVIOUS WIDTHS ARE CLEARED HERE TOO: = a
                // width set by an EARLIER collapse STAYS on the control, = so
                // the strip would keep the old widths, = draw past the
                // column, = and the X would be PAINTED in one place and HIT
                // in another (= MEASURED: = the review's own probe, =
                // 2026-11-18).
                for segment in 0 ..< segmentCount {
                    setWidth(0, forSegment: segment)
                }
                segmentWidths = widths
                applyTitles()
                return
            }
            for segment in 0 ..< segmentCount {
                let width = segment < formula.count ? formula[segment] : equal
                widths.append(width)
                setWidth(width, forSegment: segment)
            }
        }
        segmentWidths = widths
        // ⇒ ⇒ ⇒ AND THE WIDTHS MOVED THE X: = so the pointer's rectangle
        // follows it (= and it is the X's own tap target that moved).
        updateTrackingAreas()
    }

    /// Re-apply every segment's title (= after a selection change, = or
    /// after the titles or the share changed).
    private func applyTitles() {
        for segment in 0 ..< segmentCount {
            setLabel(drawnTitle(forSegment: segment), forSegment: segment)
        }
    }

    // MARK: The selection

    /// The frame a segment owns, = from the control's OWN geometry.
    ///
    /// ⇒ ⇒ ⇒ AND THIS IS THE ONE GEOMETRY THE X, THE HIT TEST AND THE
    /// TRACKING AREA ALL READ: = the frame captured in the draw hook is
    /// only true while that segment is being redrawn, = and a segment that
    /// is not on screen keeps its last frame (= or none at all), = so an X
    /// placed from it lands in the WRONG segment.
    func frame(ofSegment segment: Int) -> NSRect {
        PaneTabStripClose.segmentFrame(
            ofSegment: segment,
            inControlBounds: bounds,
            segmentCount: segmentCount,
            widths: laidOutWidths()
        )
    }

    /// The selected segment (= -1 = none).
    ///
    /// Internal (= not private) so a test can drive the PRODUCTION
    /// selection path with a real control, = the same path the app's own
    /// selection takes.
    func setSelectedSegment(_ segment: Int) {
        guard segment != closeSegmentIndex else { return }
        closeSegmentIndex = segment
        closeCell.closeSegmentIndex = segment
        // ⇒ ⇒ ⇒ AND THE WIDTHS FOLLOW THE SELECTION: = the collapse reads
        // the SELECTED tab (= the one that carries the X, = and the one
        // that keeps its own room), = so a selection change moves the
        // widths with it.
        //
        // ⇒ ⇒ ⇒ AND THIS IS NOT THE FRAME'S BUSINESS: = the frame arrives
        // at its own time (= MEASURED: = in the hosted strip the frame's
        // size lands BEFORE the selection, = and the strip kept the equal
        // share it was laid out with), = so the selection re-runs the
        // collapse itself.
        applyCollapse(columnWidth: bounds.width, selectedSegment: segment)
        // ⇒ ⇒ ⇒ AND THE X MOVED, = so the hover goes with it (= the pointer
        // is not on the new X yet, = and the area follows the X's new
        // place).
        setCloseHovered(false)
        updateTrackingAreas()
    }

    // MARK: The hover

    /// ⇒ ⇒ ⇒ AND THE POINTER'S BUSINESS IS ONE RECTANGLE: = the X's own tap
    /// target (= the HIG's 28 PT minimum), and NOT the whole strip (= and
    /// not one area per tab = and a tracking area per tab is what made this
    /// control's geometry go stale).
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let closeTrackingArea {
            removeTrackingArea(closeTrackingArea)
            self.closeTrackingArea = nil
        }
        guard closeGlyph != nil, closeSegmentIndex >= 0, closeSegmentIndex < segmentCount else { return }
        let segment = frame(ofSegment: closeSegmentIndex)
        guard !segment.isEmpty else { return }
        // ⇒ ⇒ ⇒ AND THE AREA IS AN EXPLICIT RECT: = `.inVisibleRect` would
        // ignore this rect and track the view's own visible rect (= and the
        // whole tab strip).
        let area = NSTrackingArea(
            rect: PaneTabStripClose.hitRect(in: segment),
            options: [.activeInKeyWindow, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        closeTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        setCloseHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setCloseHovered(false)
    }

    /// Turn the X's hover on or off.
    ///
    /// Internal (= not private) so a test can drive the PRODUCTION hover
    /// path with a real control, = the same path the pointer takes.
    func setCloseHovered(_ hovered: Bool) {
        guard hovered != closeHovered else { return }
        closeHovered = hovered
        closeCell.closeHovered = hovered
        needsDisplay = true
    }

    // MARK: The context menu

    /// The segment under a point (= -1 = none).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE POINTER'S OWN TAB: = the segment under the
    /// pointer (= and NOT the selected one), = so a writer can close a tab
    /// they did not switch to.
    func segment(at point: NSPoint) -> Int {
        for segment in 0 ..< segmentCount {
            let frame = frame(ofSegment: segment)
            guard !frame.isEmpty else { continue }
            if frame.contains(point) {
                return segment
            }
        }
        return -1
    }

    /// The right-click menu (= nil = no menu).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE POINTER'S OWN TAB: = the menu is built from the
    /// event's own place, = and the boss's own reason (= every editor tab
    /// closes from the menu, = so a writer never has to switch to a tab
    /// first to close it).
    ///
    /// ⇒ ⇒ ⇒ AND THE MENU'S CLOSE IS THE X'S OWN CLOSE: = the same callback
    /// (= and the same tab), = so the two paths cannot drift apart.
    override func menu(for event: NSEvent) -> NSMenu? {
        guard showsContextMenu else { return super.menu(for: event) }
        let point = convert(event.locationInWindow, from: nil)
        let segment = segment(at: point)
        guard segment >= 0 else { return nil }
        let menu = NSMenu()
        let close = NSMenuItem(
            title: String(localized: "editor.tab.context_menu.close"),
            action: #selector(closeSegmentFromMenu(_:)),
            keyEquivalent: ""
        )
        close.target = self
        close.representedObject = segment
        menu.addItem(close)
        return menu
    }

    @objc private func closeSegmentFromMenu(_ sender: NSMenuItem) {
        guard let segment = sender.representedObject as? Int else { return }
        onCloseSegment?(segment)
    }

    // MARK: The click

    /// The segment whose X the point is inside (= -1 = none).
    ///
    /// ⇒ ⇒ ⇒ AND IT IS THE SELECTED SEGMENT ONLY: = = the X is PAINTED in
    /// the selected segment alone, = = so a hit test over every segment
    /// would answer "yes" where nothing is drawn, = = and a plain left
    /// click on a NON-selected tab's leading edge would close that tab
    /// (= = with no X there, = = and the click swallowed) (= MEASURED: = =
    /// the review's own probe, = = 2026-11-18).
    func closeSegment(at point: NSPoint) -> Int {
        guard closeGlyph != nil, segmentCount > 0 else { return -1 }
        guard closeSegmentIndex >= 0, closeSegmentIndex < segmentCount else { return -1 }
        // The segment's frame comes from the CELL (= the frame AppKit drew
        // it in), = and not from the control's own bounds: = the control's
        // frame can be shorter than the cells it draws (= MEASURED in the
        // hosted strip, = where the control's frame height was 0 while its
        // cells were 28 PT tall), = so a hit test built on the bounds would
        // land on nothing.
        let frame = frame(ofSegment: closeSegmentIndex)
        guard !frame.isEmpty else { return -1 }
        guard PaneTabStripClose.hitRect(in: frame).contains(point) else { return -1 }
        return closeSegmentIndex
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let segment = closeSegment(at: point)
        guard segment >= 0 else {
            super.mouseDown(with: event)
            return
        }
        // The click landed on the X: = it closes that tab, = and it is
        // swallowed (= so the click does not also SELECT the tab it closes,
        // = which is what Safari does).
        onCloseSegment?(segment)
    }
}
